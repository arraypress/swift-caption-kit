//
//  StylePreset.swift
//  CaptionStyles
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One built-in caption style, as the catalogue holds it.
///
/// `style` lists only what differs from `CaptionStyle()`, with `{slot}`
/// markers where a slot's value goes; ``StylePresets`` turns it into a
/// `CaptionStyle`.
public struct StylePreset: Codable, Sendable, Equatable {

    /// Kebab-case, as `--style` takes it: `clean-pop`.
    public let name: String

    /// For a picker: `Clean Pop`.
    public let title: String

    /// On the curated shelf a gallery shows first.
    public let featured: Bool?

    /// One line on what it looks like.
    public let about: String?

    /// The knobs `--var` can turn.
    public let slots: [PresetSlot]?

    /// How the style wants words grouped into cards, when not the defaults.
    public let grouping: GroupingRules?

    /// The fields that differ from `CaptionStyle()`.
    public let style: [String: JSONValue]
}
