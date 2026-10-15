//
//  StyleJSON.swift
//  CaptionStyles
//
//  Created by David Sherlock on 2026.
//
//  A partial style made whole, as pure functions: `{slot}` markers filled,
//  shorthand colours (`yellow`, `#00E676`, `black@0.4`) turned into colour
//  objects at the keys that hold colours, and the result laid over
//  `CaptionStyle()` key by key — a key set to null clears an optional
//  field — before decoding. Everything stays JSON until the last step, read
//  and written by Foundation's coders, so a number keeps its exact value.
//

import Foundation

public enum StyleJSON {

    /// The keys whose values are colours, or lists of them.
    public static let colorKeys: Set<String> = [
        "color", "colors", "textColor", "strokeColor", "activeWordColor", "activeBoxTextColor", "knockoutPlate",
        "wordColorPalette", "fringeColors", "chipColors", "underline", "speakerColors", "activeWordPalette",
    ]

    /// `CaptionStyle()` as JSON: the base every partial style is laid over.
    public static let defaults: [String: JSONValue] = {
        guard let data = try? JSONEncoder().encode(CaptionStyle()),
              case .object(let object)? = try? JSONDecoder().decode(JSONValue.self, from: data) else { return [:] }
        return object
    }()

    /// A colour as its JSON object.
    public static func json(_ color: StyleColor) -> JSONValue {
        .object(["red": .number(color.red), "green": .number(color.green), "blue": .number(color.blue),
                 "alpha": .number(color.alpha)])
    }

    /// `partial` laid over `CaptionStyle()` and decoded.
    public static func style(from partial: [String: JSONValue], path: String = "style") throws(StyleError) -> CaptionStyle {
        var object = defaults
        for (key, value) in partial {
            let expanded = try expandingColors(value, key: key, path: path + "." + key)
            if expanded == .null { object.removeValue(forKey: key) } else { object[key] = expanded }
        }
        do {
            return try JSONDecoder().decode(CaptionStyle.self, from: JSONEncoder().encode(JSONValue.object(object)))
        } catch let DecodingError.typeMismatch(_, context) {
            throw .invalidStyle("\(field(context.codingPath, in: path)) has the wrong type")
        } catch let DecodingError.keyNotFound(key, context) {
            throw .invalidStyle("\(field(context.codingPath + [key], in: path)) cannot be null")
        } catch let DecodingError.valueNotFound(_, context) {
            throw .invalidStyle("\(field(context.codingPath, in: path)) cannot be null")
        } catch let DecodingError.dataCorrupted(context) {
            throw .invalidStyle("\(field(context.codingPath, in: path)) is not a value it can hold")
        } catch {
            throw .invalidStyle("\(path) does not read: \(error.localizedDescription)")
        }
    }

    /// `value` with every shorthand colour under a colour key made an object.
    public static func expandingColors(_ value: JSONValue, key: String, path: String) throws(StyleError) -> JSONValue {
        let isColor = colorKeys.contains(key)
        switch value {
        case .string(let text) where isColor:
            guard let color = ColorShorthand.color(text) else { throw .badStyleColor(path: path, value: text) }
            return json(color)
        case .array(let items):
            var result: [JSONValue] = []
            for (index, item) in items.enumerated() {
                result.append(try expandingColors(item, key: key, path: path + ".\(index)"))
            }
            return .array(result)
        case .object(let object) where !isColor:
            var result: [String: JSONValue] = [:]
            for (child, item) in object {
                result[child] = try expandingColors(item, key: child, path: path + "." + child)
            }
            return .object(result)
        default:
            return value
        }
    }

    /// `value` with every string that is exactly a `{name}` marker replaced.
    public static func filled(_ value: JSONValue, with values: [String: JSONValue]) -> JSONValue {
        switch value {
        case .string(let text) where text.hasPrefix("{") && text.hasSuffix("}"):
            return values[String(text.dropFirst().dropLast())] ?? value
        case .array(let items): return .array(items.map { filled($0, with: values) })
        case .object(let object): return .object(object.mapValues { filled($0, with: values) })
        default: return value
        }
    }

    /// The names of every `{marker}` in `value`'s strings.
    public static func markers(in value: JSONValue) -> Set<String> {
        switch value {
        case .string(let text):
            guard text.contains("{") else { return [] }
            var names = Set<String>()
            var open: String?
            for character in text {
                if character == "{" { open = "" } else if character == "}" {
                    if let name = open { names.insert(name) }
                    open = nil
                } else { open?.append(character) }
            }
            return names
        case .array(let items): return items.reduce(into: []) { $0.formUnion(markers(in: $1)) }
        case .object(let object): return object.values.reduce(into: []) { $0.formUnion(markers(in: $1)) }
        default: return []
        }
    }

    /// A decoding path as a dotted field name under `root`.
    static func field(_ keys: [any CodingKey], in root: String) -> String {
        ([root] + keys.map { $0.intValue.map(String.init) ?? $0.stringValue }).joined(separator: ".")
    }
}
