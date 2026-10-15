//
//  WordStyle.swift
//  CaptionStyles
//
//  Created by David Sherlock on 2026.
//

import CoreGraphics
import Foundation

/// Sparse style overrides for one specific word *instance* — "make THIS word
/// bigger", "pop this one on", "turn this one green".
///
/// Every field is optional; `nil` inherits from the card/global style. The
/// override lives on the ``Word`` itself, so it survives regrouping and
/// timeline edits. (To style every occurrence of a word by text, use
/// ``HighlightRule`` instead.)
///
/// ```swift
/// document.cards[2].words[1].style = WordStyle(color: .green, sizeMultiplier: 1.4)
/// ```
public struct WordStyle: Codable, Equatable, Hashable, Sendable {

    /// The word's base fill color (highlights still apply on top).
    public var color: StyleColor?

    /// Multiplier on the style's font size for this word. Layout reserves
    /// the extra space — a `1.5` word genuinely occupies more of the line.
    public var sizeMultiplier: CGFloat?

    /// A different font family for this word.
    public var fontFamily: String?

    /// A different font weight for this word.
    public var fontWeight: FontWeight?

    /// A linear gradient clipped inside just this word's glyphs (e.g. one
    /// keyword goes metallic gold). Applies at rest; a spoken-word highlight
    /// still recolors solid on top. Takes precedence over ``color``. `nil` =
    /// no per-word gradient.
    public var gradient: GradientFill?

    /// A photo/image clipped inside just this word's glyphs, cropped to the
    /// word's frame. Takes precedence over ``gradient`` and ``color``. `nil` =
    /// no per-word image fill.
    public var imageFill: ImageFill?

    /// A different outline color for just this word (e.g. one word gets a red
    /// outline while the rest are black). Uses ``strokeWidth`` if set, else the
    /// global width. `nil` inherits the global stroke.
    public var strokeColor: StyleColor?

    /// A different outline width for this word, in reference points. `nil`
    /// inherits the global width.
    public var strokeWidth: CGFloat?

    /// Stacked outlines for just this word (the "sticker" look on one keyword).
    /// When set and non-empty, replaces every other stroke for this word.
    /// `nil` inherits the global stroke.
    public var strokeLayers: [StrokeLayer]?

    /// A hard offset drop for just this word (the colored "sticker depth").
    /// `nil` inherits the global ``CaptionStyle/hardShadow``.
    public var hardShadow: HardShadowStyle?

    /// A solid 3D extrusion for just this word (e.g. one number goes chunky and
    /// metallic). `nil` inherits the global ``CaptionStyle/extrude``.
    public var extrude: ExtrudeStyle?

    /// A static tilt for this word, in radians (CG convention:
    /// counterclockwise-positive; SwiftUI surfaces negate). The word rotates
    /// about its own center inside its reserved slot, on top of any entrance
    /// animation — the "every keyword kicked at an angle" meme-caption look.
    /// `nil`/`0` = level.
    public var rotation: CGFloat?

    /// Synthetic italic for just this word: a rightward glyph shear
    /// (`0.25` ≈ a classic oblique), independent of the global
    /// ``CaptionStyle/slant``. Works with any font — no italic face needed.
    /// `nil` inherits the global slant.
    public var slant: CGFloat?

    /// A vertical nudge for this word, in reference points (positive = up).
    /// Lets one word ride above or below the shared baseline — the stacked
    /// "Genius / Level" offset look — without disturbing its neighbours.
    /// `nil`/`0` = on the baseline.
    public var baselineOffset: CGFloat?

    /// A persistent underline bar beneath this word in the given color —
    /// always on, independent of the spoken-word highlight (that one is
    /// ``HighlightMode/activeUnderline``). `nil` = none.
    public var underline: StyleColor?

    /// A different entrance animation for this word.
    public var animation: WordAnimation?

    /// An inline emoji rendered right after the word, inside the caption
    /// line — it pops on with the word ("we made money 💰"). Layout
    /// reserves its space like any glyph.
    public var emoji: String?

    /// Per-word censor override (a tri-state on top of the global auto-censor):
    /// `true` forces a bleep + black bar on this word, `false` protects it from
    /// the profanity list (fixes false positives), `nil` defers to the global
    /// ``CaptionStyle/censorProfanity`` toggle.
    public var censored: Bool?

    public init(
        color: StyleColor? = nil,
        gradient: GradientFill? = nil,
        imageFill: ImageFill? = nil,
        sizeMultiplier: CGFloat? = nil,
        fontFamily: String? = nil,
        fontWeight: FontWeight? = nil,
        strokeColor: StyleColor? = nil,
        strokeWidth: CGFloat? = nil,
        strokeLayers: [StrokeLayer]? = nil,
        hardShadow: HardShadowStyle? = nil,
        extrude: ExtrudeStyle? = nil,
        rotation: CGFloat? = nil,
        slant: CGFloat? = nil,
        baselineOffset: CGFloat? = nil,
        underline: StyleColor? = nil,
        animation: WordAnimation? = nil,
        emoji: String? = nil,
        censored: Bool? = nil
    ) {
        self.color = color
        self.gradient = gradient
        self.imageFill = imageFill
        self.sizeMultiplier = sizeMultiplier
        self.fontFamily = fontFamily
        self.fontWeight = fontWeight
        self.strokeColor = strokeColor
        self.strokeWidth = strokeWidth
        self.strokeLayers = strokeLayers
        self.hardShadow = hardShadow
        self.extrude = extrude
        self.rotation = rotation
        self.slant = slant
        self.baselineOffset = baselineOffset
        self.underline = underline
        self.animation = animation
        self.emoji = emoji
        self.censored = censored
    }

    /// Whether every field inherits (an empty override).
    public var isEmpty: Bool {
        self == WordStyle()
    }
}
