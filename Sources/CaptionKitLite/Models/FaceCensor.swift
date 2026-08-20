//
//  FaceCensor.swift
//  CaptionKitLite
//
//  Created by David Sherlock on 2026.
//

import CoreGraphics
import Foundation

/// One sampled face box on the source timeline (normalized, top-left origin) —
/// the track that drives the face cover.
public struct FaceRectKeyframe: Codable, Equatable, Sendable {

    /// Source time in seconds.
    public var time: TimeInterval
    /// Face-box center, `0…1` per axis, top-left semantics.
    public var center: NormalizedPoint
    /// Face-box size as a fraction of the frame.
    public var width: Double
    public var height: Double

    public init(time: TimeInterval, center: NormalizedPoint, width: Double, height: Double) {
        self.time = time
        self.center = center
        self.width = width
        self.height = height
    }
}

/// Privacy cover for a talking head that doesn't want to be on camera: blur,
/// pixelate, or an emoji, tracked to the detected face. Runs in the shared CI
/// pipeline so preview and export match.
public struct FaceCensor: Codable, Equatable, Sendable {

    public enum Mode: String, Codable, Sendable, CaseIterable {
        case blur, pixelate, emoji
    }

    /// How the face is hidden.
    public var mode: Mode
    /// Blur softness / pixel size (`0…1`).
    public var intensity: Double
    /// The emoji used in `.emoji` mode.
    public var emoji: String
    /// How much larger than the detected box to cover (`0` = exact … `1` = 2×).
    public var padding: Double
    /// The tracked face boxes over time.
    public var keyframes: [FaceRectKeyframe]

    public init(
        mode: Mode = .blur,
        intensity: Double = 0.6,
        emoji: String = "😎",
        padding: Double = 0.35,
        keyframes: [FaceRectKeyframe] = []
    ) {
        self.mode = mode
        self.intensity = intensity
        self.emoji = emoji
        self.padding = padding
        self.keyframes = keyframes
    }
}

/// Linear interpolation over the face track — clamped at both ends.
public enum FaceCensorTrack {

    /// The interpolated face box at `time` (normalized, top-left), or `nil`
    /// when there are no keyframes.
    public static func rect(at time: TimeInterval, keyframes: [FaceRectKeyframe])
        -> (cx: Double, cy: Double, w: Double, h: Double)? {
        guard let first = keyframes.first, let last = keyframes.last else { return nil }
        if time <= first.time { return (Double(first.center.x), Double(first.center.y), first.width, first.height) }
        if time >= last.time { return (Double(last.center.x), Double(last.center.y), last.width, last.height) }
        for (from, to) in zip(keyframes, keyframes.dropFirst()) where time < to.time {
            let span = max(0.0001, to.time - from.time)
            let t = (time - from.time) / span
            let fx = Double(from.center.x), fy = Double(from.center.y)
            let tx = Double(to.center.x), ty = Double(to.center.y)
            return (
                fx + (tx - fx) * t,
                fy + (ty - fy) * t,
                from.width + (to.width - from.width) * t,
                from.height + (to.height - from.height) * t
            )
        }
        return (Double(last.center.x), Double(last.center.y), last.width, last.height)
    }
}
