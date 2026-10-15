//
//  ExportSettings.swift
//  CaptionCore
//
//  Created by David Sherlock on 2026.
//

import AVFoundation
import Foundation

/// Encoder settings for a caption export.
///
/// Resolution and frame geometry come from the document's ``RenderConfig``;
/// these settings only control the codec side.
public struct ExportSettings: Sendable {

    /// The video codec.
    public enum Codec: String, Sendable, CaseIterable {
        case hevc
        case h264

        @_spi(CaptionEngine) public var avCodec: AVVideoCodecType {
            switch self {
            case .hevc: return .hevc
            case .h264: return .h264
            }
        }
    }

    /// How much bitrate to spend, as a share of what the picture needs.
    ///
    /// A fixed bitrate is the wrong unit: 12 Mbps is generous at 1080×1920 and
    /// wasteful at 720×1280, where it produced a 21 MB file for fifteen
    /// seconds. What actually governs quality is bits *per pixel per second*,
    /// so that is what these tiers name — the encoder's budget then scales
    /// with resolution and frame rate on its own.
    public enum Quality: String, Sendable, CaseIterable {

        /// Visibly compressed. For drafts, or a preview you will re-render.
        case draft

        /// Small files that still look clean on a phone. Good for messaging.
        case small

        /// The default. Indistinguishable from the source for talking-head
        /// footage at normal viewing size.
        case balanced

        /// Headroom for footage that compresses badly — heavy grain, confetti,
        /// fast motion — or for re-encoding downstream.
        case high

        /// Near-transparent. Larger than anything a social platform will keep
        /// after its own re-encode.
        case maximum

        /// Bits per pixel per second, before the codec adjustment.
        ///
        /// Derived from what vertical social video actually needs rather than
        /// from a table: 1080×1920 at 30 fps is 62.2 M pixels/second, and
        /// ``balanced`` puts that at roughly 6 Mbps — about half the old fixed
        /// default, and above what the platforms keep.
        var bitsPerPixel: Double {
            switch self {
            case .draft: return 0.035
            case .small: return 0.06
            case .balanced: return 0.10
            case .high: return 0.16
            case .maximum: return 0.24
            }
        }
    }

    /// The output codec. Default HEVC.
    public var codec: Codec

    /// The bitrate budget. See ``Quality``.
    public var quality: Quality

    /// An explicit average bitrate in bits per second, overriding ``quality``.
    ///
    /// `nil` derives one from the canvas, the frame rate and the codec, which
    /// is nearly always the better answer — a number chosen without knowing
    /// the resolution cannot be right for every resolution.
    public var averageBitRate: Int?

    /// The container. Default `.mp4`.
    public var fileType: AVFileType

    /// Whether to carry the source's audio track through unchanged.
    public var includeAudio: Bool

    /// Replacement audio for the export — e.g. the cleaned track from
    /// ``AudioCleaner``. Must match the source timeline (same duration);
    /// cuts apply to it identically. `nil` uses the video's own audio.
    public var audioOverrideURL: URL?

    /// Multiplies the canvas resolution at export. `1` = the document's
    /// canvas (e.g. 1080×1920); `2` doubles it to ~4K. The renderer is
    /// resolution-independent, so captions/effects stay crisp.
    public var resolutionScale: CGFloat

    public init(
        codec: Codec = .hevc,
        quality: Quality = .balanced,
        averageBitRate: Int? = nil,
        fileType: AVFileType = .mp4,
        includeAudio: Bool = true,
        audioOverrideURL: URL? = nil,
        resolutionScale: CGFloat = 1
    ) {
        self.codec = codec
        self.quality = quality
        self.averageBitRate = averageBitRate
        self.fileType = fileType
        self.includeAudio = includeAudio
        self.audioOverrideURL = audioOverrideURL
        self.resolutionScale = resolutionScale
    }

    // MARK: - Resolved bitrate

    /// The bitrate to hand the encoder for a given canvas.
    ///
    /// ``averageBitRate`` wins when set. Otherwise the budget is
    /// `pixels × frameRate × bitsPerPixel`, adjusted for the codec: H.264
    /// needs roughly half again what HEVC does for the same picture.
    ///
    /// Clamped at the bottom so a very small canvas still gets enough bitrate
    /// to avoid blocking, since captions are hard edges over flat colour and
    /// show compression before the footage does.
    public func resolvedBitRate(width: Int, height: Int, frameRate: Double) -> Int {
        if let averageBitRate { return max(100_000, averageBitRate) }

        let pixelsPerSecond = Double(width * height) * max(1, frameRate)
        let codecFactor: Double = codec == .h264 ? 1.5 : 1
        let budget = pixelsPerSecond * quality.bitsPerPixel * codecFactor
        return max(600_000, Int(budget))
    }
}

/// Errors thrown by ``CaptionExporter``.
public enum ExportError: Error, LocalizedError, Sendable {
    case missingVideoURL
    case noVideoTrack
    case cannotCreateBuffer
    case readerFailed(String)
    case writerFailed(String)

    public var errorDescription: String? {
        switch self {
        case .missingVideoURL: return "The document has no video URL."
        case .noVideoTrack: return "The source file has no video track."
        case .cannotCreateBuffer: return "Could not allocate a pixel buffer."
        case .readerFailed(let reason): return "Reading the source failed: \(reason)"
        case .writerFailed(let reason): return "Writing the export failed: \(reason)"
        }
    }
}
