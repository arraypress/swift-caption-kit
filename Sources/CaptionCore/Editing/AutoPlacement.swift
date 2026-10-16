//
//  AutoPlacement.swift
//  CaptionCore
//
//  Created by David Sherlock on 2026.
//

@preconcurrency import AVFoundation
import CaptionStyles
import CoreGraphics
import Foundation

/// Face-aware caption placement: samples frames across the video, detects
/// faces on-device with Vision, and suggests a caption position just below
/// the speaker's face — never over it.
///
/// ```swift
/// if let position = try await AutoPlacement.faceAwarePosition(videoURL: url) {
///     document.style.position = position
/// }
/// ```
public enum AutoPlacement {

    /// A face-avoiding caption position, or `nil` when no face is found in
    /// enough sampled frames.
    ///
    /// - Parameters:
    ///   - videoURL: The video to analyze.
    ///   - sampleCount: How many frames to sample across the duration.
    ///   - margin: Normalized gap between the chin line and the caption
    ///     center.
    public static func faceAwarePosition(
        videoURL: URL,
        sampleCount: Int = 12,
        margin: CGFloat = 0.12
    ) async throws -> CaptionStyles.NormalizedPoint? {
        let asset = AVURLAsset(url: videoURL)
        let duration = try await asset.load(.duration).seconds
        guard duration > 0 else { return nil }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 640, height: 640)
        generator.requestedTimeToleranceBefore = .positiveInfinity
        generator.requestedTimeToleranceAfter = .positiveInfinity

        let step = duration / Double(sampleCount + 1)
        let times = (1...sampleCount).map { CMTime(seconds: Double($0) * step, preferredTimescale: 600) }

        var faceBottoms: [CGFloat] = []
        for await result in generator.images(for: times) {
            guard let frame = try? result.image else { continue }
            if let face = largest(await FaceBoxes.find(in: frame)) {
                // Vision rects are normalized with a bottom-left origin; our
                // coordinates are top-left. The face box's bottom edge:
                faceBottoms.append(1 - face.minY)
            }
        }

        // Demand a face in at least a third of the sampled frames — a brief
        // face shouldn't pin the layout.
        guard faceBottoms.count >= max(2, sampleCount / 3) else { return nil }
        let chin = median(of: faceBottoms)

        // Center the caption a margin below the chin, clamped to stay off
        // the very bottom (platform-UI territory).
        let y = min(0.82, max(0.5, chin + margin))
        return CaptionStyles.NormalizedPoint(x: 0.5, y: y)
    }

    /// The median horizontal center of the face across sampled frames
    /// (`0…1`, left-to-right), for auto-reframing a wide source into a
    /// vertical canvas. `nil` when no face is found often enough.
    public static func faceHorizontalCenter(
        videoURL: URL,
        sampleCount: Int = 12
    ) async throws -> CGFloat? {
        let asset = AVURLAsset(url: videoURL)
        let duration = try await asset.load(.duration).seconds
        guard duration > 0 else { return nil }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 640, height: 640)
        generator.requestedTimeToleranceBefore = .positiveInfinity
        generator.requestedTimeToleranceAfter = .positiveInfinity

        let step = duration / Double(sampleCount + 1)
        let times = (1...sampleCount).map { CMTime(seconds: Double($0) * step, preferredTimescale: 600) }

        var centers: [CGFloat] = []
        for await result in generator.images(for: times) {
            guard let frame = try? result.image else { continue }
            if let face = largest(await FaceBoxes.find(in: frame)) {
                centers.append(face.midX) // Vision x is already left-to-right
            }
        }
        guard centers.count >= max(2, sampleCount / 3) else { return nil }
        return median(of: centers)
    }

    /// The face with the largest area.
    private static func largest(_ faces: [CGRect]) -> CGRect? {
        faces.max { $0.width * $0.height < $1.width * $1.height }
    }

    private static func median(of values: [CGFloat]) -> CGFloat {
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }
}
