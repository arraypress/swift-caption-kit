//
//  ColorShorthand.swift
//  CaptionStyles
//
//  Created by David Sherlock on 2026.
//
//  Colours as people write them: `yellow`, `#00E676` (the # optional),
//  `#00E676CC`, and any
//  of those with an alpha after an @: `black@0.4`. A name is exactly the
//  `StyleColor` constant of that name, so a preset written `yellow` is the
//  same colour it was in Swift.
//

import Foundation

public enum ColorShorthand {

    /// The colours known by name, in listing order.
    public static let names: [(name: String, color: StyleColor)] = [
        ("white", .white), ("black", .black), ("yellow", .yellow), ("green", .green), ("red", .red),
        ("blue", .blue), ("purple", .purple), ("orange", .orange), ("pink", .pink), ("clear", .clear),
    ]

    /// The colour `text` names, or `nil` when it reads as none: a name (any
    /// case) or hex, then optionally `@` and an alpha from 0 to 1.
    public static func color(_ text: String) -> StyleColor? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        var base = trimmed
        var alpha: Double?
        if let at = trimmed.lastIndex(of: "@") {
            guard let value = Double(trimmed[trimmed.index(after: at)...].trimmingCharacters(in: .whitespaces)),
                  (0...1).contains(value) else { return nil }
            base = String(trimmed[..<at]).trimmingCharacters(in: .whitespaces)
            alpha = value
        }
        let lowered = base.lowercased()
        let color: StyleColor
        if let named = names.first(where: { $0.name == lowered }) {
            color = named.color
        } else if let components = StyleColorHex.components(base) {
            color = StyleColor(red: components.red, green: components.green, blue: components.blue, alpha: components.alpha)
        } else {
            return nil
        }
        return alpha.map(color.withAlpha) ?? color
    }

    /// Colours separated by commas; `nil` when any part does not read or there are none.
    public static func colors(_ text: String) -> [StyleColor]? {
        let parts = text.split(separator: ",").map(String.init)
        guard !parts.isEmpty else { return nil }
        let colors = parts.compactMap(color)
        return colors.count == parts.count ? colors : nil
    }
}
