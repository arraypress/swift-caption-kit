//
//  SlotKind.swift
//  CaptionStyles
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What a preset's `{slot}` takes.
public enum SlotKind: String, Codable, Sendable, CaseIterable {

    /// One colour: `yellow`, `#00E676`, `black@0.4`.
    case color

    /// Colours separated by commas: `#2ECC40,#FFDC00` — a palette, or one.
    case colors
}
