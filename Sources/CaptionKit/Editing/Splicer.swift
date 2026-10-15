//
//  Splicer.swift
//  CaptionKit
//
//  Keeping some ranges of a recording and joining them, with nothing else
//  changed — what removing fillers and dead air comes to once the captions
//  are taken away. Clipper keeps ONE range; this keeps many.
//
//  Measured before it was written, on a synthetic talk whose every frame
//  stated its own number in black and white blocks:
//
//  - Video goes through untouched. A passthrough export of the joined
//    ranges showed the right frame at 30 of 30 sampled times, with the cut
//    landing mid-GOP. It does so by storing the frames back to each range's
//    keyframe and hiding them with an edit list — 379 stored for 337 shown —
//    which AVFoundation, QuickTime and ffmpeg honour.
//  - Audio-only cannot pass through into `.m4a`: AVFoundation refuses a
//    composition there ("not supported for this media"), from an
//    afconvert-made m4a and an AVFoundation-made one alike. So AAC is
//    re-encoded once, at Apple's M4A preset; WAV and AIFF pass through.
//  - The output's length matched the kept ranges to the millisecond, video
//    and audio both.
//

import AVFoundation
import Foundation

/// Joins the kept ranges of a recording into a new file.
public enum Splicer {

    /// What a splice produced.
    public struct Result: Equatable, Sendable {
        /// The file written.
        public let url: URL
        /// The recording's length before, in seconds.
        public let sourceDuration: TimeInterval
        /// The total length of the ranges kept — what the output should be.
        public let plannedDuration: TimeInterval
        /// The output's length as written.
        public let outputDuration: TimeInterval
        /// Whether the audio had to be re-encoded (an `.m4a` out).
        public let reencoded: Bool
        /// Whether the recording has pictures.
        public let hasVideo: Bool

        /// How far the written length is from the planned one, in seconds.
        public var durationError: TimeInterval { abs(outputDuration - plannedDuration) }
    }

    /// Why a splice could not be made.
    public enum SpliceError: Error, LocalizedError, Equatable, Sendable {
        case noTracks(String)
        case nothingKept
        case exportFailed(String)

        public var errorDescription: String? {
            switch self {
            case .noTracks(let name): return "\(name) has no audio or video to cut"
            case .nothingKept: return "the cuts would remove the whole recording"
            case .exportFailed(let reason): return "the export failed: \(reason)"
            }
        }
    }

    /// The extensions this reads as sound alone.
    public static let audioExtensions: Set<String> = ["m4a", "mp3", "wav", "aif", "aiff", "aac", "caf"]

    /// The extension a spliced copy of a recording is written with.
    ///
    /// A video keeps its container. Sound keeps WAV or AIFF, which pass
    /// through; everything else becomes `.m4a`, the one compressed audio
    /// container AVFoundation writes — an MP3 cannot be written back.
    ///
    /// - Parameters:
    ///   - source: The recording.
    ///   - hasVideo: Whether it has pictures.
    /// - Returns: The extension, without a dot.
    public static func outputExtension(for source: URL, hasVideo: Bool) -> String {
        let ext = source.pathExtension.lowercased()
        if hasVideo { return ["mov", "mp4", "m4v"].contains(ext) ? ext : "mp4" }
        switch ext {
        case "wav": return "wav"
        case "aif", "aiff": return "aiff"
        default: return "m4a"
        }
    }

    /// The container and preset an output extension calls for.
    static func export(for ext: String) -> (fileType: AVFileType, preset: String) {
        switch ext {
        case "mov": return (.mov, AVAssetExportPresetPassthrough)
        case "m4v": return (.m4v, AVAssetExportPresetPassthrough)
        case "mp4": return (.mp4, AVAssetExportPresetPassthrough)
        case "wav": return (.wav, AVAssetExportPresetPassthrough)
        case "aiff": return (.aiff, AVAssetExportPresetPassthrough)
        default: return (.m4a, AVAssetExportPresetAppleM4A)
        }
    }

    /// Writes the kept ranges of a recording, in order, as one file.
    ///
    /// - Parameters:
    ///   - ranges: What to keep, on the source's timeline, in order —
    ///     ``TimeMap/keptRanges(sourceDuration:)`` gives them. Speeds are
    ///     ignored: a splice keeps or drops, it does not ramp.
    ///   - source: The recording.
    ///   - output: Where to write it; its extension should come from
    ///     ``outputExtension(for:hasVideo:)``.
    /// - Returns: What was written, including its measured length.
    /// - Throws: ``SpliceError``.
    public static func keep(_ ranges: [Cut], of source: URL, to output: URL) async throws -> Result {
        let asset = AVURLAsset(url: source)
        let tracks = try await asset.load(.tracks).filter { $0.mediaType == .video || $0.mediaType == .audio }
        guard !tracks.isEmpty else { throw SpliceError.noTracks(source.lastPathComponent) }
        let sourceDuration = try await asset.load(.duration).seconds
        let hasVideo = tracks.contains { $0.mediaType == .video }

        let kept = ranges.map { Cut(start: max(0, $0.start), end: min(sourceDuration, $0.end)) }
            .filter { $0.duration > 0.001 }
        guard !kept.isEmpty else { throw SpliceError.nothingKept }

        let composition = AVMutableComposition()
        let scale = CMTimeScale(600)
        for track in tracks {
            guard let joined = composition.addMutableTrack(withMediaType: track.mediaType,
                                                           preferredTrackID: kCMPersistentTrackID_Invalid) else { continue }
            var cursor = CMTime.zero
            for range in kept {
                let timeRange = CMTimeRange(start: CMTime(seconds: range.start, preferredTimescale: scale),
                                            end: CMTime(seconds: range.end, preferredTimescale: scale))
                do {
                    try joined.insertTimeRange(timeRange, of: track, at: cursor)
                } catch {
                    throw SpliceError.exportFailed(error.localizedDescription)
                }
                cursor = cursor + timeRange.duration
            }
            if track.mediaType == .video {
                joined.preferredTransform = try await track.load(.preferredTransform)
            }
        }

        let plan = export(for: output.pathExtension.lowercased())
        guard let session = AVAssetExportSession(asset: composition, presetName: plan.preset) else {
            throw SpliceError.exportFailed("no export session for \(output.lastPathComponent)")
        }
        try? FileManager.default.removeItem(at: output)
        do {
            try await session.export(to: output, as: plan.fileType)
        } catch {
            throw SpliceError.exportFailed(error.localizedDescription)
        }

        return Result(url: output, sourceDuration: sourceDuration,
                      plannedDuration: kept.reduce(0) { $0 + $1.duration },
                      outputDuration: try await AVURLAsset(url: output).load(.duration).seconds,
                      reencoded: plan.preset != AVAssetExportPresetPassthrough,
                      hasVideo: hasVideo)
    }
}
