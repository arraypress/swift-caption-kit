//
//  StyleError.swift
//  CaptionStyles
//
//  Created by David Sherlock on 2026.
//

import Foundation
import RecipeKit

/// Why a style could not be made.
public enum StyleError: Error, Sendable, Equatable, LocalizedError {

    /// No preset has this name; `suggestions` are close ones.
    case unknownStyle(String, suggestions: [String])

    /// A `--var` the preset does not have, or one given empty.
    case slot(SlotError)

    /// A slot value that is not a colour (or colours) it can read.
    case badColor(slot: String, value: String)

    /// A colour in a style that does not read: `textColor` is `#GGG`.
    case badStyleColor(path: String, value: String)

    /// A style that does not decode, with the field that stopped it.
    case invalidStyle(String)

    public var errorDescription: String? {
        switch self {
        case .unknownStyle(let name, let suggestions):
            suggestions.isEmpty ? "no caption style is called \(name); see `caption styles`"
                : "no caption style is called \(name) — did you mean \(suggestions.joined(separator: ", "))? See `caption styles`"
        case .slot(let error): error.errorDescription
        case .badColor(let slot, let value):
            "\(slot) is a colour — a name (\(ColorShorthand.names.map(\.name).joined(separator: ", "))), "
                + "#RRGGBB or #RRGGBBAA, with @alpha if you like; not \(value)"
        case .badStyleColor(let path, let value):
            "\(path) is not a colour: \(value) (try yellow, #00E676 or black@0.4)"
        case .invalidStyle(let message): message
        }
    }
}
