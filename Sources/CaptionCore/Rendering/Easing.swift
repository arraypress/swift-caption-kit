//
//  Easing.swift
//  CaptionCore
//
//  Created by David Sherlock on 2026.
//

import CoreGraphics
import Foundation

/// Pure easing curves for caption animation.
///
/// The renderer is a deterministic function of time — there are no
/// `CAAnimation`s anywhere. Every animated property is computed from a word's
/// timestamps through these curves, which is what makes preview and export
/// pixel-identical by construction.
@_spi(CaptionEngine) public enum Easing {

    /// Clamps to `0…1`.
    @_spi(CaptionEngine) public static func clamp01(_ x: Double) -> Double {
        min(1, max(0, x))
    }

    /// Normalized progress of `time` through `start ..< start + duration`.
    @_spi(CaptionEngine) public static func progress(_ time: TimeInterval, from start: TimeInterval, duration: TimeInterval) -> Double {
        guard duration > 0 else { return time >= start ? 1 : 0 }
        return clamp01((time - start) / duration)
    }

    /// Decelerating cubic ease-out.
    @_spi(CaptionEngine) public static func easeOutCubic(_ x: Double) -> Double {
        let t = clamp01(x)
        return 1 - pow(1 - t, 3)
    }

    /// Ease-out with a slight overshoot past 1 — the "pop".
    @_spi(CaptionEngine) public static func easeOutBack(_ x: Double) -> Double {
        let t = clamp01(x)
        let c1 = 1.70158
        let c3 = c1 + 1
        return 1 + c3 * pow(t - 1, 3) + c1 * pow(t - 1, 2)
    }

    /// Ball-drop bounce settling at 1.
    @_spi(CaptionEngine) public static func easeOutBounce(_ x: Double) -> Double {
        var t = clamp01(x)
        let n1 = 7.5625
        let d1 = 2.75
        if t < 1 / d1 {
            return n1 * t * t
        } else if t < 2 / d1 {
            t -= 1.5 / d1
            return n1 * t * t + 0.75
        } else if t < 2.5 / d1 {
            t -= 2.25 / d1
            return n1 * t * t + 0.9375
        } else {
            t -= 2.625 / d1
            return n1 * t * t + 0.984375
        }
    }

    /// Damped elastic spring entrance: starts at 0, overshoots, wobbles, and
    /// settles at 1 by `x == 1`.
    @_spi(CaptionEngine) public static func spring(_ x: Double) -> Double {
        let t = clamp01(x)
        if t == 0 || t == 1 { return t }
        return 1 - exp(-6 * t) * cos(2 * .pi * 2.2 * t)
    }
}
