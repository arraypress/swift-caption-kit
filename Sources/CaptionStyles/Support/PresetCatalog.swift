//
//  PresetCatalog.swift
//  CaptionStyles
//
//  Created by David Sherlock on 2026.
//
//  The built-in presets: decoded once from ``PresetCatalogText`` and checked
//  — names kebab-case and unique (RecipeKit's rules, shared with imagine and
//  song), every style key a field, every marker a slot and every slot used,
//  every default a colour that reads, every preset a style that decodes. A
//  test requires no problems, so a bad entry fails the tests, not a run.
//  Also the pure steps from a preset and `--var` values to a style.
//

import Foundation
import RecipeKit

public enum PresetCatalog {

    /// What a parse found, and every problem in it.
    public struct Result: Sendable {
        public var presets: [StylePreset] = []
        public var problems: [String] = []
    }

    /// Every preset in `texts` (JSON groups), with every problem found.
    public static func parse(_ texts: [String]) -> Result {
        let decoded = StyleCatalogs.decoded(texts, as: StylePreset.self, name: \.name)
        var result = Result(presets: decoded.styles, problems: decoded.problems)
        for preset in decoded.styles {
            result.problems += StyleSchema.unknownKeys(in: preset.style).map { "\(preset.name): \($0) is not a style field" }
            result.problems += StyleCatalogs.slotProblems(style: preset.name, markers: StyleJSON.markers(in: .object(preset.style)),
                                                          slots: slots(of: preset))
            do { _ = try style(of: preset, values: [:]) } catch {
                result.problems.append("\(preset.name): \(error.errorDescription ?? "does not decode")")
            }
        }
        return result
    }

    static let parsed = parse(PresetCatalogText.all)

    // MARK: Slots

    /// A preset's slots as RecipeKit's: a colour slot knows the named
    /// colours, and its default when that is a hex value.
    public static func slots(of preset: StylePreset) -> [StyleSlot] {
        (preset.slots ?? []).map { slot in
            var known = slot.kind == .color ? ColorShorthand.names.filter { $0.name != "clear" }.map { StyleSlot.Value(name: $0.name) } : []
            if !known.contains(where: { $0.name == slot.defaultValue }) { known.append(StyleSlot.Value(name: slot.defaultValue)) }
            return StyleSlot(name: slot.name, defaultValue: slot.defaultValue, known: known)
        }
    }

    /// A slot's value as the JSON its markers become: one colour, or a list.
    public static func json(of value: String, for slot: PresetSlot) throws(StyleError) -> JSONValue {
        switch slot.kind {
        case .color:
            guard ColorShorthand.color(value) != nil else { throw .badColor(slot: slot.name, value: value) }
            return .string(value.trimmingCharacters(in: .whitespaces))
        case .colors:
            guard ColorShorthand.colors(value) != nil else { throw .badColor(slot: slot.name, value: value) }
            return .array(value.split(separator: ",").map { .string($0.trimmingCharacters(in: .whitespaces)) })
        }
    }

    // MARK: Styles

    /// The style `preset` makes with these `--var` values (names checked;
    /// any slot not given takes its default).
    public static func style(of preset: StylePreset, values: [String: String]) throws(StyleError) -> CaptionStyle {
        let resolved: [String: String]
        do { resolved = try SlotFilling.resolved(values, for: slots(of: preset), style: preset.name) } catch {
            throw .slot(error)
        }
        var fills: [String: JSONValue] = [:]
        for slot in preset.slots ?? [] {
            fills[slot.name] = try json(of: resolved[slot.name] ?? slot.defaultValue, for: slot)
        }
        guard case .object(let filled) = StyleJSON.filled(.object(preset.style), with: fills) else { return CaptionStyle() }
        return try StyleJSON.style(from: filled)
    }

    /// The preset `name` names: exact, or with case, spaces, hyphens and
    /// underscores forgiven (`Clean Pop`, `cleanpop`, `clean_pop`).
    public static func preset(named name: String, in presets: [StylePreset]) -> StylePreset? {
        let wanted = loose(name)
        return presets.first { $0.name == name } ?? presets.first { loose($0.name) == wanted }
    }

    /// Close names for one that is not a preset: the nearest by edits, else
    /// up to three sharing a word.
    public static func suggestions(for name: String, among names: [String]) -> [String] {
        if let close = FieldPaths.closest(name.lowercased(), among: names) { return [close] }
        return StyleCatalogs.suggestions(for: name, among: names)
    }

    static func loose(_ text: String) -> String {
        text.lowercased().filter { !" -_".contains($0) }
    }
}
