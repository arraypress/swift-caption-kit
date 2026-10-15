//
//  FaceTrack.swift
//  CaptionCore
//
//  Created by David Sherlock on 2026.
//

import AVFoundation
import CaptionStyles
import CoreGraphics
import Foundation
import Vision

/// A moment on the source timeline where the aspect-fill crop should be
/// centered — the building block of face-tracked reframing.
public struct CropKeyframe: Codable, Equatable, Sendable {

    /// Source time in seconds.
    public var time: TimeInterval

    /// The crop center, `0…1` per axis, top-left semantics (same space as
    /// the document's `cropOffset`).
    public var offset: CaptionStyles.NormalizedPoint

    /// Extra zoom at this moment (`1` = no zoom, `1.5` = punched in 50%) —
    /// lets a manual camera path punch in and pan, not just pan.
    public var scale: CGFloat

    public init(time: TimeInterval, offset: CaptionStyles.NormalizedPoint, scale: CGFloat = 1) {
        self.time = time
        self.offset = offset
        self.scale = scale
    }
}

/// Interpolation over crop keyframes — linear, clamped at both ends.
public enum CropTrack {

    public static func offset(at time: TimeInterval, keyframes: [CropKeyframe]) -> CaptionStyles.NormalizedPoint? {
        guard let first = keyframes.first, let last = keyframes.last else { return nil }
        if time <= first.time { return first.offset }
        if time >= last.time { return last.offset }
        for (from, to) in zip(keyframes, keyframes.dropFirst()) where time < to.time {
            let span = max(0.0001, to.time - from.time)
            let progress = (time - from.time) / span
            return CaptionStyles.NormalizedPoint(
                x: from.offset.x + (to.offset.x - from.offset.x) * progress,
                y: from.offset.y + (to.offset.y - from.offset.y) * progress
            )
        }
        return last.offset
    }

    /// The interpolated zoom at `time` — `1` when there are no keyframes.
    public static func scale(at time: TimeInterval, keyframes: [CropKeyframe]) -> CGFloat {
        guard let first = keyframes.first, let last = keyframes.last else { return 1 }
        if time <= first.time { return first.scale }
        if time >= last.time { return last.scale }
        for (from, to) in zip(keyframes, keyframes.dropFirst()) where time < to.time {
            let span = max(0.0001, to.time - from.time)
            let progress = CGFloat((time - from.time) / span)
            return from.scale + (to.scale - from.scale) * progress
        }
        return last.scale
    }
}

/// Follows the largest face through the video and produces smoothed crop
/// keyframes — so a single wide source can be batch-exported to 9:16, 1:1,
/// and 16:9 with the speaker always in frame. On-device Vision throughout.
public enum FaceTrack {

    /// The two speakers' horizontal positions in a static two-person shot
    /// (podcast framing): samples the video, collects face centers from
    /// frames where TWO faces appear, and returns the left/right cluster
    /// means. `nil` when a two-face arrangement isn't found.
    public static func twoFaceSides(videoURL: URL) async throws -> (left: CGFloat, right: CGFloat)? {
        let asset = AVURLAsset(url: videoURL)
        let duration = try await asset.load(.duration).seconds
        guard duration > 0 else { return nil }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 480, height: 480)
        generator.requestedTimeToleranceBefore = .positiveInfinity
        generator.requestedTimeToleranceAfter = .positiveInfinity

        let sampleCount = 14
        let step = duration / Double(sampleCount + 1)
        let times = (1...sampleCount).map { CMTime(seconds: Double($0) * step, preferredTimescale: 600) }

        var lefts: [CGFloat] = []
        var rights: [CGFloat] = []
        for await result in generator.images(for: times) {
            guard let frame = try? result.image else { continue }
            let request = VNDetectFaceRectanglesRequest()
            let handler = VNImageRequestHandler(cgImage: frame)
            try? handler.perform([request])
            let faces = (request.results ?? [])
                .sorted { $0.boundingBox.width > $1.boundingBox.width }
                .prefix(2)
                .map { $0.boundingBox.midX }
            guard faces.count == 2 else { continue }
            lefts.append(min(faces[0], faces[1]))
            rights.append(max(faces[0], faces[1]))
        }
        guard lefts.count >= 3 else { return nil }
        return (
            lefts.reduce(0, +) / CGFloat(lefts.count),
            rights.reduce(0, +) / CGFloat(rights.count)
        )
    }

    /// Samples ~2 fps, detects the largest face per sample, smooths the
    /// path (moving average), and thins it to meaningful moves.
    public static func track(videoURL: URL) async throws -> [CropKeyframe] {
        let asset = AVURLAsset(url: videoURL)
        let duration = try await asset.load(.duration).seconds
        guard duration > 0 else { return [] }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 480, height: 480)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.2, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.2, preferredTimescale: 600)

        let times = stride(from: 0.25, to: duration, by: 0.5)
            .map { CMTime(seconds: $0, preferredTimescale: 600) }

        var samples: [(time: TimeInterval, x: CGFloat, y: CGFloat)] = []
        for await result in generator.images(for: times) {
            guard let frame = try? result.image else { continue }
            let request = VNDetectFaceRectanglesRequest()
            let handler = VNImageRequestHandler(cgImage: frame)
            try? handler.perform([request])
            guard let face = request.results?.max(by: { $0.boundingBox.width < $1.boundingBox.width }) else { continue }
            // Vision boxes are normalized with a bottom-left origin.
            samples.append((
                result.requestedTime.seconds,
                face.boundingBox.midX,
                1 - face.boundingBox.midY
            ))
        }
        guard samples.count >= 2 else { return [] }

        // Smooth (±2-sample moving average), then thin to real moves so
        // the crop glides instead of jittering.
        var keyframes: [CropKeyframe] = []
        for index in samples.indices {
            let lower = max(0, index - 2)
            let upper = min(samples.count - 1, index + 2)
            let window = samples[lower...upper]
            keyframes.append(CropKeyframe(
                time: samples[index].time,
                offset: CaptionStyles.NormalizedPoint(
                    x: window.map(\.x).reduce(0, +) / CGFloat(window.count),
                    y: window.map(\.y).reduce(0, +) / CGFloat(window.count)
                )
            ))
        }
        var thinned = [keyframes[0]]
        for keyframe in keyframes.dropFirst() {
            let last = thinned[thinned.count - 1]
            if abs(keyframe.offset.x - last.offset.x) > 0.015
                || abs(keyframe.offset.y - last.offset.y) > 0.015 {
                thinned.append(keyframe)
            }
        }
        if thinned.count == 1, let final = keyframes.last {
            thinned.append(final)
        }
        return thinned
    }

    /// Samples ~4 fps and records the largest face's full bounding BOX (not
    /// just its center) as a normalized, top-left face track — used to drive
    /// the privacy face cover. Denser than ``track`` and unthinned so the
    /// blur/emoji glides smoothly rather than snapping between key moves.
    public static func trackRects(videoURL: URL) async throws -> [FaceRectKeyframe] {
        let asset = AVURLAsset(url: videoURL)
        let duration = try await asset.load(.duration).seconds
        guard duration > 0 else { return [] }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 480, height: 480)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.12, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.12, preferredTimescale: 600)

        let times = stride(from: 0.1, to: duration, by: 0.25)
            .map { CMTime(seconds: $0, preferredTimescale: 600) }

        var samples: [FaceRectKeyframe] = []
        for await result in generator.images(for: times) {
            guard let frame = try? result.image else { continue }
            let request = VNDetectFaceRectanglesRequest()
            let handler = VNImageRequestHandler(cgImage: frame)
            try? handler.perform([request])
            guard let face = request.results?.max(by: { $0.boundingBox.width < $1.boundingBox.width }) else { continue }
            let box = face.boundingBox
            // Vision boxes are normalized, bottom-left origin → flip Y to top-left.
            samples.append(FaceRectKeyframe(
                time: result.requestedTime.seconds,
                center: CaptionStyles.NormalizedPoint(x: box.midX, y: 1 - box.midY),
                width: Double(box.width),
                height: Double(box.height)
            ))
        }
        guard samples.count >= 1 else { return [] }

        // Light ±2-sample smoothing so the cover doesn't jitter frame to frame.
        var smoothed: [FaceRectKeyframe] = []
        for index in samples.indices {
            let lower = max(0, index - 2)
            let upper = min(samples.count - 1, index + 2)
            let window = samples[lower...upper]
            let n = window.count
            smoothed.append(FaceRectKeyframe(
                time: samples[index].time,
                center: CaptionStyles.NormalizedPoint(
                    x: window.map(\.center.x).reduce(0, +) / CGFloat(n),
                    y: window.map(\.center.y).reduce(0, +) / CGFloat(n)
                ),
                width: window.map(\.width).reduce(0, +) / Double(n),
                height: window.map(\.height).reduce(0, +) / Double(n)
            ))
        }
        return smoothed
    }
}
