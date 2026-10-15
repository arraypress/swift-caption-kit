//
//  StylePresets.swift
//  CaptionStyles
//
//  Created by David Sherlock on 2026.
//
//  The built-in caption style catalogue — data (``PresetCatalogText``), not
//  code. The renderer's tests draw every preset so one can never silently
//  stop rendering.
//

import Foundation
import RecipeKit

/// One-click looks. Applying keeps the user's caption position.
public enum StylePresets {

    /// Every preset, in gallery order.
    public static var catalog: [StylePreset] { PresetCatalog.parsed.presets }

    /// What is wrong with the catalogue; a test requires none.
    public static var problems: [String] { PresetCatalog.parsed.problems }

    /// Every preset as a style, its slots at their defaults: (name, style).
    public static let all: [(name: String, style: CaptionStyle)] = catalog.compactMap { preset in
        (try? PresetCatalog.style(of: preset, values: [:])).map { (preset.name, $0) }
    }

    /// The curated shelf a gallery shows by default — the strongest, most
    /// distinct looks. Everything else stays one "Show All" away.
    public static var featured: [String] { catalog.filter { $0.featured == true }.map(\.name) }

    /// The presets that also change how words are grouped, by name.
    public static var groupingHints: [String: GroupingRules] {
        catalog.reduce(into: [:]) { hints, preset in if let rules = preset.grouping { hints[preset.name] = rules } }
    }

    /// The preset `name` names, case and separators forgiven.
    public static func named(_ name: String) -> StylePreset? {
        PresetCatalog.preset(named: name, in: catalog)
    }

    /// The preset `name` names, or the error that suggests close ones.
    public static func require(_ name: String) throws(StyleError) -> StylePreset {
        if let preset = named(name) { return preset }
        throw .unknownStyle(name, suggestions: PresetCatalog.suggestions(for: name, among: catalog.map(\.name)))
    }

    /// The style preset `name` makes with `--var` values.
    public static func style(named name: String, vars: [String: String] = [:]) throws(StyleError) -> CaptionStyle {
        try require(name).style(vars: vars)
    }
}
