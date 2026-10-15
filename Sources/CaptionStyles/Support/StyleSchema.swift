//
//  StyleSchema.swift
//  CaptionStyles
//
//  Created by David Sherlock on 2026.
//
//  The keys a style's JSON may hold, read off the types themselves (their
//  stored properties are their coding keys), so a field added to
//  `CaptionStyle` is a field the catalogue and recipes accept without a
//  list to keep in step. JSONDecoder ignores a key it does not know; these
//  lists are what lets a misspelt `"fontSzie"` be refused instead.
//

import Foundation

public enum StyleSchema {

    /// `CaptionStyle`'s keys.
    public static let fields: [String] = names(of: CaptionStyle())

    /// The objects inside a style, by dotted path (`*` for every item of an
    /// array), and the keys each may hold.
    public static let sections: [(path: String, keys: [String])] = [
        ("shadow", names(of: ShadowStyle())),
        ("hardShadow", names(of: HardShadowStyle())),
        ("extrude", names(of: ExtrudeStyle())),
        ("glow", names(of: GlowStyle())),
        ("background", names(of: BackgroundStyle())),
        ("textGradient", names(of: GradientFill())),
        ("activeBoxGradient", names(of: GradientFill())),
        ("imageFill", names(of: ImageFill(url: URL(fileURLWithPath: "/")))),
        ("textWarp", names(of: TextWarp())),
        ("mixedLetters", names(of: MixedLetterStyle())),
        ("position", names(of: NormalizedPoint(x: 0, y: 0))),
        ("strokeLayers.*", names(of: StrokeLayer())),
    ]

    /// Every key in `style` that is not a style field, as a dotted path —
    /// at the top and in each object inside.
    public static func unknownKeys(in style: [String: JSONValue]) -> [String] {
        var unknown = style.keys.filter { !fields.contains($0) }.sorted()
        for section in sections {
            for (path, value) in values(at: section.path, in: .object(style)) {
                guard case .object(let object) = value else { continue }
                unknown += object.keys.filter { !section.keys.contains($0) }.sorted().map { path + "." + $0 }
            }
        }
        return unknown
    }

    /// The stored properties of `value`, which synthesized `Codable` uses as keys.
    static func names(of value: Any) -> [String] {
        Mirror(reflecting: value).children.compactMap(\.label)
    }

    /// The values at a dotted path, `*` stepping into every item of an array.
    static func values(at path: String, in root: JSONValue) -> [(path: String, value: JSONValue)] {
        var found: [(path: [String], value: JSONValue)] = [([], root)]
        for key in path.split(separator: ".").map(String.init) {
            found = found.flatMap { step -> [(path: [String], value: JSONValue)] in
                if key == "*" {
                    guard case .array(let items) = step.value else { return [] }
                    return items.enumerated().map { (step.path + [String($0.offset)], $0.element) }
                }
                guard case .object(let object) = step.value, let value = object[key] else { return [] }
                return [(step.path + [key], value)]
            }
        }
        return found.map { ($0.path.joined(separator: "."), $0.value) }
    }
}
