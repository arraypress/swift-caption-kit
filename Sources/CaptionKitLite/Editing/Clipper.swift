//
//  Clipper.swift
//  CaptionKitLite
//
//  Cutting a long video into pieces, at places a sentence survives.
//

import AVFoundation
import Foundation

/// Cuts a video into segments, choosing boundaries that do not land mid-word.
///
/// The cutting itself is not the interesting part — `AVAssetExportSession` has
/// done that for years. What matters is WHERE: a clip that opens halfway
/// through "compres—" is unusable, and the timestamp a caller names is almost
/// never a silence. Given word timings, every boundary is nudged to the
/// nearest gap between words.
public enum Clipper {

    /// A piece to cut.
    public struct Segment: Equatable, Sendable {
        public let start: TimeInterval
        public let end: TimeInterval

        public init(start: TimeInterval, end: TimeInterval) {
            self.start = start
            self.end = end
        }

        public var duration: TimeInterval { end - start }
    }

    /// What a cut produced.
    public struct Cut: Equatable, Sendable {
        public let url: URL
        public let start: TimeInterval
        public let end: TimeInterval
        /// How far the boundary moved to avoid splitting a word, in seconds.
        public let startAdjustment: TimeInterval
        public let endAdjustment: TimeInterval
        public let words: Int

        public var duration: TimeInterval { end - start }
    }

    public enum ClipError: Error, LocalizedError, Equatable, Sendable {
        case noVideoTrack(String)
        case phraseNotFound(String)
        case emptySegment(start: TimeInterval, end: TimeInterval)
        case exportFailed(String)

        public var errorDescription: String? {
            switch self {
            case .noVideoTrack(let name):
                return "\(name) has no video track to cut"
            case .phraseNotFound(let phrase):
                return "\"\(phrase)\" is not in the transcript"
            case .emptySegment(let start, let end):
                return String(format: "a segment from %.2fs to %.2fs has no length", start, end)
            case .exportFailed(let reason):
                return "the export failed: \(reason)"
            }
        }
    }

    // MARK: Choosing where to cut

    /// Moves `time` to the nearest silence between words.
    ///
    /// "Nearest" is measured to the GAP, not to a word: the safe place to cut
    /// is between the end of one word and the start of the next, and the
    /// midpoint of that gap is the safest point in it. With no words at all
    /// the time is returned unchanged — an honest no-op beats inventing a
    /// boundary from nothing.
    public static func snap(_ time: TimeInterval, to words: [Word]) -> TimeInterval {
        guard !words.isEmpty else { return time }

        // Before the first word or after the last: those edges are already
        // silence, so nothing needs moving.
        if time <= words[0].start || time >= words[words.count - 1].end { return time }

        var best = time
        var bestDistance = Double.infinity

        for index in 0..<(words.count - 1) {
            let gapStart = words[index].end
            let gapEnd = words[index + 1].start
            // A gap can be zero or negative where a recogniser butts two words
            // together; the midpoint is still the least-bad point.
            let candidate = (gapStart + max(gapEnd, gapStart)) / 2
            let distance = abs(candidate - time)
            if distance < bestDistance {
                bestDistance = distance
                best = candidate
            }
        }
        return best
    }

    /// Segments at fixed intervals, each snapped to word boundaries.
    public static func every(
        _ interval: TimeInterval, upTo duration: TimeInterval, words: [Word]
    ) -> [Segment] {
        guard interval > 0, duration > 0 else { return [] }
        var segments: [Segment] = []
        var start = 0.0
        while start < duration {
            let rawEnd = min(start + interval, duration)
            // The final boundary is the end of the file and must not move.
            let end = rawEnd >= duration ? duration : snap(rawEnd, to: words)
            if end > start { segments.append(Segment(start: start, end: end)) }
            start = end
        }
        return segments
    }

    /// A segment of `length` centred on the first occurrence of `phrase`.
    ///
    /// Matched case- and diacritic-insensitively across word boundaries, so
    /// "the compressor release" finds three consecutive words rather than
    /// requiring one token to contain the whole phrase.
    public static func around(
        phrase: String, length: TimeInterval, words: [Word], duration: TimeInterval
    ) throws -> Segment {
        let needle = normalise(phrase)
        guard !needle.isEmpty else { throw ClipError.phraseNotFound(phrase) }

        let terms = needle.split(separator: " ").map(String.init)
        let haystack = words.map { normalise($0.text) }

        for index in haystack.indices where index + terms.count <= haystack.count {
            let window = Array(haystack[index..<(index + terms.count)])
            guard window == terms else { continue }

            let hitStart = words[index].start
            let hitEnd = words[index + terms.count - 1].end
            let centre = (hitStart + hitEnd) / 2
            var start = max(0, centre - length / 2)
            var end = min(duration, start + length)
            // Clamped at the tail, the clip would otherwise come up short.
            start = max(0, end - length)

            start = start <= 0 ? 0 : snap(start, to: words)
            end = end >= duration ? duration : snap(end, to: words)
            // The hit itself must survive the snapping, or the clip is of the
            // wrong moment — which is the one thing this verb promises.
            start = min(start, hitStart)
            end = max(end, hitEnd)
            return Segment(start: start, end: end)
        }
        throw ClipError.phraseNotFound(phrase)
    }

    /// Lowercased, unpunctuated, diacritic-folded — so "Compressor," matches
    /// "compressor".
    private static func normalise(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .components(separatedBy: CharacterSet.alphanumerics.union(.whitespaces).inverted)
            .joined()
            .split(separator: " ")
            .joined(separator: " ")
    }

    // MARK: Cutting

    /// Exports one segment to `output`.
    ///
    /// Passthrough where the source allows it: re-encoding a clip costs time
    /// and a generation of quality for no benefit when the bytes can simply be
    /// copied.
    public static func cut(
        _ segment: Segment,
        from videoURL: URL,
        to output: URL,
        words: [Word] = []
    ) async throws -> Cut {

        let asset = AVURLAsset(url: videoURL)
        guard try await !asset.loadTracks(withMediaType: .video).isEmpty else {
            throw ClipError.noVideoTrack(videoURL.lastPathComponent)
        }
        let duration = try await asset.load(.duration).seconds

        let start = max(0, min(segment.start, duration))
        let end = max(start, min(segment.end, duration))
        guard end - start > 0.01 else {
            throw ClipError.emptySegment(start: start, end: end)
        }

        guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough)
                ?? AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            throw ClipError.exportFailed("no export session for \(videoURL.lastPathComponent)")
        }

        try? FileManager.default.removeItem(at: output)
        let scale = CMTimeScale(600)
        export.timeRange = CMTimeRange(
            start: CMTime(seconds: start, preferredTimescale: scale),
            end: CMTime(seconds: end, preferredTimescale: scale)
        )

        do {
            try await export.export(to: output, as: fileType(for: output))
        } catch {
            throw ClipError.exportFailed(error.localizedDescription)
        }

        let inside = words.filter { $0.start >= start && $0.end <= end }.count
        return Cut(url: output, start: start, end: end,
                   startAdjustment: start - segment.start,
                   endAdjustment: end - segment.end,
                   words: inside)
    }

    private static func fileType(for url: URL) -> AVFileType {
        switch url.pathExtension.lowercased() {
        case "mov": return .mov
        case "m4v": return .m4v
        default: return .mp4
        }
    }
}
