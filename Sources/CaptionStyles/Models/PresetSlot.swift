//
//  PresetSlot.swift
//  CaptionStyles
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A knob a preset offers to `--var`: its name, what it takes, and the
/// value the preset was designed with.
///
/// As JSON: `{"name": "accent", "kind": "color", "default": "yellow"}`.
public struct PresetSlot: Codable, Sendable, Equatable {

    /// Lower-case, as `--var` takes it: `accent`.
    public let name: String

    /// One colour or a list of them.
    public let kind: SlotKind

    /// The value used when none is given.
    public let defaultValue: String

    public init(name: String, kind: SlotKind, defaultValue: String) {
        self.name = name
        self.kind = kind
        self.defaultValue = defaultValue
    }

    enum CodingKeys: String, CodingKey {
        case name, kind
        case defaultValue = "default"
    }
}
