//
//  WordLook.swift
//  CaptionStyles
//
//  Created by David Sherlock on 2026.
//
//  The one-tap per-word looks, shared by every app shell.
//

import CoreGraphics
import Foundation

/// One-click per-word style presets for the Word inspector's "Looks" row —
/// each sets the whole selected word's ``WordStyle`` at once; a `nil` style
/// clears it. `WordLook.genius` is also what Auto-Emphasize (Genius Look)
/// stamps onto every word the emphasis suggester picks.
public enum WordLook {
    public static let gold = StyleColor(red: 1, green: 0.82, blue: 0.12)
    public static let amber = StyleColor(red: 0.95, green: 0.45, blue: 0.05)
    public static let red = StyleColor(red: 0.92, green: 0.12, blue: 0.15)
    public static let darkGold = StyleColor(red: 0.45, green: 0.30, blue: 0.02)

    public static let genius = WordStyle(
        color: gold,
        strokeLayers: [StrokeLayer(color: red, width: 24), StrokeLayer(color: .black, width: 10)],
        hardShadow: HardShadowStyle(color: red, offsetX: 8, offsetY: 9),
        rotation: 0.12,
        slant: 0.18
    )
    public static let gold3D = WordStyle(
        gradient: GradientFill(colors: [.white, gold], angle: 90),
        extrude: ExtrudeStyle(color: darkGold, depth: 18, angle: -45, fade: 0.45)
    )
    public static let gradient = WordStyle(
        gradient: GradientFill(colors: [gold, amber], angle: 90)
    )
    public static let pop = WordStyle(
        color: .white,
        strokeLayers: [StrokeLayer(color: red, width: 18), StrokeLayer(color: .black, width: 8)],
        rotation: -0.10
    )

    /// (label, style) pairs for the preset buttons; a `nil` style clears.
    public static let all: [(name: String, style: WordStyle?)] = [
        ("Genius", genius),
        ("Gold 3D", gold3D),
        ("Gradient", gradient),
        ("Pop", pop),
        ("Clear", nil),
    ]
}
