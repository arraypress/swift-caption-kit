//
//  SpeakerLabelStyle.swift
//  CaptionStyles
//
//  Created by David Sherlock on 2026.
//

import CoreGraphics
import Foundation

/// The speaker's name shown with their caption (see
/// ``CaptionStyle/speakerLabel``). Drawn only when the card's words carry a
/// speaker; the name is the document's, or "Speaker 1", "Speaker 2", ….
public struct SpeakerLabelStyle: Codable, Equatable, Hashable, Sendable {

    /// Where the name goes.
    public enum Mode: String, Codable, CaseIterable, Sendable {
        /// A bold line just above the caption text, inside its background —
        /// the broadcast lower third's name over the words.
        case above
        /// A small filled chip above the caption, in the speaker's colour.
        case chip
    }

    public var mode: Mode

    /// The name's size as a fraction of the caption's font size.
    public var scale: CGFloat

    /// The name's weight.
    public var fontWeight: FontWeight

    /// The name's text colour. `nil`: for ``Mode/above`` the speaker's
    /// colour (else the style's active-word colour); for ``Mode/chip`` near
    /// black or white, whichever reads on the chip.
    public var color: StyleColor?

    /// Uppercase the name. `nil`/`false` = as written.
    public var uppercase: Bool?

    public init(mode: Mode = .above, scale: CGFloat = 0.5, fontWeight: FontWeight = .heavy,
                color: StyleColor? = nil, uppercase: Bool? = nil) {
        self.mode = mode
        self.scale = scale
        self.fontWeight = fontWeight
        self.color = color
        self.uppercase = uppercase
    }

    /// Tolerant: a key left out takes its default, so a recipe can write
    /// `{"mode": "chip"}` and nothing else.
    public init(from decoder: Decoder) throws {
        let defaults = SpeakerLabelStyle()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mode = try container.decodeIfPresent(Mode.self, forKey: .mode) ?? defaults.mode
        scale = try container.decodeIfPresent(CGFloat.self, forKey: .scale) ?? defaults.scale
        fontWeight = try container.decodeIfPresent(FontWeight.self, forKey: .fontWeight) ?? defaults.fontWeight
        color = try container.decodeIfPresent(StyleColor.self, forKey: .color)
        uppercase = try container.decodeIfPresent(Bool.self, forKey: .uppercase)
    }

    private enum CodingKeys: String, CodingKey { case mode, scale, fontWeight, color, uppercase }
}
