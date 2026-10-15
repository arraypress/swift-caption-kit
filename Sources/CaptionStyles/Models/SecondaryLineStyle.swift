//
//  SecondaryLineStyle.swift
//  CaptionStyles
//
//  Created by David Sherlock on 2026.
//

import CoreGraphics
import Foundation

/// A second line drawn small above the caption — the other language of a
/// bilingual caption (see ``CaptionStyle/secondaryLine``). The text is the
/// document's `secondaryWords` that fall in the card's span, on one line,
/// shrunk to fit the frame.
public struct SecondaryLineStyle: Codable, Equatable, Hashable, Sendable {

    /// Its size as a fraction of the caption's font size.
    public var scale: CGFloat

    /// Its colour. `nil` = the caption's text colour at 85 % opacity.
    public var color: StyleColor?

    /// Its weight. `nil` = the caption's.
    public var fontWeight: FontWeight?

    /// The gap between it and the caption, in reference points.
    public var gap: CGFloat

    public init(scale: CGFloat = 0.6, color: StyleColor? = nil, fontWeight: FontWeight? = nil, gap: CGFloat = 14) {
        self.scale = scale
        self.color = color
        self.fontWeight = fontWeight
        self.gap = gap
    }

    /// Tolerant: a key left out takes its default.
    public init(from decoder: Decoder) throws {
        let defaults = SecondaryLineStyle()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        scale = try container.decodeIfPresent(CGFloat.self, forKey: .scale) ?? defaults.scale
        color = try container.decodeIfPresent(StyleColor.self, forKey: .color)
        fontWeight = try container.decodeIfPresent(FontWeight.self, forKey: .fontWeight)
        gap = try container.decodeIfPresent(CGFloat.self, forKey: .gap) ?? defaults.gap
    }

    private enum CodingKeys: String, CodingKey { case scale, color, fontWeight, gap }
}
