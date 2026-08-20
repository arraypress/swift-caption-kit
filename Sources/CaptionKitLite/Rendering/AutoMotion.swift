//
//  AutoMotion.swift
//  CaptionKitLite
//
//  Created by David Sherlock on 2026.
//

import CoreGraphics
import Foundation

/// Subtle automatic camera motion for static talking-head footage: a slow
/// breathing zoom, plus punch-ins that land on emphasized words.
///
/// Pure functions of time — the preview's composition handler and the
/// exporter compute the identical scale for any instant.
public struct AutoMotionStyle: Codable, Equatable, Sendable {

    /// Slow-drift zoom intensity (`0` off … `1` = ±2% breathing).
    public var drift: Double

    /// Punch in on emphasized words (the ones with a color override —
    /// pair this with Auto-Emphasize).
    public var punchOnEmphasis: Bool

    /// Peak punch scale (`1.05` = +5%).
    public var punchScale: Double

    public init(drift: Double = 0.6, punchOnEmphasis: Bool = true, punchScale: Double = 1.05) {
        self.drift = drift
        self.punchOnEmphasis = punchOnEmphasis
        self.punchScale = punchScale
    }
}

public enum AutoMotion {

    /// The moments punches land: every word carrying a color override.
    public static func emphasisTimes(in cards: [CaptionCard]) -> [TimeInterval] {
        cards.flatMap(\.words)
            .filter { $0.style?.color != nil }
            .map(\.start)
            .sorted()
    }

    /// The motion scale at a source-time instant.
    public static func scale(
        at time: TimeInterval,
        style: AutoMotionStyle,
        emphasisTimes: [TimeInterval]
    ) -> CGFloat {
        var scale = 1.0

        // Breathing drift: a slow sine so the frame never sits dead still.
        if style.drift > 0 {
            scale += 0.02 * min(1, max(0, style.drift)) * (0.5 + 0.5 * sin(2 * .pi * time / 14))
        }

        // Emphasis punch: jump in at the word, relax over 0.45s.
        if style.punchOnEmphasis, style.punchScale > 1 {
            for start in emphasisTimes where time >= start && time < start + 0.45 {
                let progress = (time - start) / 0.45
                let eased = 1 - pow(1 - progress, 3)
                scale += (style.punchScale - 1) * (1 - eased)
            }
        }
        return CGFloat(scale)
    }
}
