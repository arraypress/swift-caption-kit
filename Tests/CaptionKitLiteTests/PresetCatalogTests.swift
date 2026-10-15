//
//  PresetCatalogTests.swift
//  CaptionKitLiteTests
//
//  Created by David Sherlock on 2026.
//
//  The presets are JSON data now, and data is checked: the catalogue has no
//  problems (names, keys, slots, colours), `--var` fills a slot, refuses a
//  slot the preset does not have and a colour that does not read, and a
//  misspelt style key is caught rather than ignored.
//

import CoreGraphics
import Foundation
import RecipeKit
import Testing
@testable import CaptionStyles

@Suite("Preset catalogue")
struct PresetCatalogTests {

    @Test("The built-in catalogue has no problems")
    func noProblems() {
        #expect(StylePresets.problems == [])
        #expect(StylePresets.catalog.count == 50)
        #expect(StylePresets.all.count == StylePresets.catalog.count)
    }

    @Test("Names are kebab-case and found however they are spelled", arguments: ["clean-pop", "Clean Pop", "cleanpop", "clean_pop"])
    func names(spelling: String) {
        #expect(StylePresets.named(spelling)?.name == "clean-pop")
    }

    @Test("An unknown name suggests a close one")
    func unknownName() {
        #expect(throws: StyleError.unknownStyle("hormozzi", suggestions: ["hormozi"])) {
            try StylePresets.require("hormozzi")
        }
    }

    @Test("A colour slot takes a name, hex, or alpha, and defaults to the designed colour")
    func colorSlot() throws {
        let karaoke = try #require(StylePresets.named("karaoke"))
        #expect(try karaoke.style().activeWordColor == .yellow)
        #expect(try karaoke.style(vars: ["accent": "#00E676"]).activeWordColor == StyleColor(hex: "#00E676"))
        #expect(try karaoke.style(vars: ["ACCENT": "Pink"]).activeWordColor == .pink)
        #expect(try karaoke.style(vars: ["accent": "red@0.5"]).activeWordColor == StyleColor.red.withAlpha(0.5))
    }

    @Test("A colours slot takes a comma list")
    func colorsSlot() throws {
        let style = try StylePresets.style(named: "hormozi", vars: ["accent": "#00E676"])
        #expect(style.wordColorPalette == [StyleColor(hex: "#00E676")!])
        let two = try StylePresets.style(named: "hormozi", vars: ["accent": "green, #FF4136"])
        #expect(two.wordColorPalette == [.green, StyleColor(hex: "#FF4136")!])
    }

    @Test("A gradient preset's two stops are two slots, and `from` also tints the active word")
    func gradientSlots() throws {
        let style = try StylePresets.style(named: "sunset", vars: ["from": "blue", "to": "#000000"])
        #expect(style.activeWordColor == .blue)
        #expect(style.activeBoxGradient?.colors == [.blue, .black])
    }

    @Test("A slot the preset does not have is refused, naming its slots")
    func unknownSlot() {
        #expect(throws: StyleError.slot(.unknownSlot(style: "karaoke", slot: "font", slots: ["accent"]))) {
            try StylePresets.style(named: "karaoke", vars: ["font": "Georgia"])
        }
    }

    @Test("A colour that does not read is refused")
    func badColor() {
        #expect(throws: StyleError.badColor(slot: "accent", value: "#GGG")) {
            try StylePresets.style(named: "karaoke", vars: ["accent": "#GGG"])
        }
        #expect(throws: StyleError.badColor(slot: "accent", value: "green,nope")) {
            try StylePresets.style(named: "hormozi", vars: ["accent": "green,nope"])
        }
    }

    @Test("Colour shorthand reads names, hex and alpha exactly")
    func shorthand() {
        #expect(ColorShorthand.color("yellow") == .yellow)
        #expect(ColorShorthand.color("black@0.4") == StyleColor.black.withAlpha(0.4))
        #expect(ColorShorthand.color("#0A2540@0.6") == StyleColor(hex: "#0A2540")!.withAlpha(0.6))
        #expect(ColorShorthand.color("#00000080") == StyleColor(hex: "#00000080"))
        #expect(ColorShorthand.color("white@2") == nil)
        #expect(ColorShorthand.color("chartreuse") == nil)
        #expect(ColorShorthand.colors("") == nil)
    }

    @Test("A partial style lays over the defaults; null clears an optional")
    func partial() throws {
        let style = try StyleJSON.style(from: ["fontSize": .number(90), "shadow": .null, "textColor": .string("pink")])
        var expected = CaptionStyle()
        expected.fontSize = 90
        expected.shadow = nil
        expected.textColor = .pink
        #expect(style == expected)
    }

    @Test("A wrong type or a null for a required field is named")
    func badStyle() {
        #expect(throws: StyleError.invalidStyle("style.fontSize has the wrong type")) {
            try StyleJSON.style(from: ["fontSize": .string("big")])
        }
        #expect(throws: StyleError.invalidStyle("style.fontSize cannot be null")) {
            try StyleJSON.style(from: ["fontSize": .null])
        }
    }

    @Test("A misspelt key is found at the top and inside objects")
    func unknownKeys() {
        let style: [String: JSONValue] = [
            "fontSzie": .number(3),
            "shadow": .object(["radius": .number(2), "blur": .number(1)]),
            "strokeLayers": .array([.object(["width": .number(2), "colour": .string("red")])]),
        ]
        #expect(StyleSchema.unknownKeys(in: style) == ["fontSzie", "shadow.blur", "strokeLayers.0.colour"])
    }

    @Test("Every field of CaptionStyle is a schema field")
    func schemaCoversTheType() throws {
        let data = try JSONEncoder().encode(StylePresets.style(named: "karaoke"))
        let keys = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any]).keys
        #expect(Set(keys).isSubset(of: Set(StyleSchema.fields)))
        #expect(StyleSchema.fields.contains("activeBoxGradient"))
    }

    @Test("A broken catalogue reports every problem")
    func brokenCatalogue() {
        let text = #"""
        [{"name": "Bad Name", "title": "x", "style": {}},
         {"name": "two", "title": "x", "slots": [{"name": "tint", "kind": "color", "default": "nope"}],
          "style": {"textColor": "{tint}", "fontSzie": 3, "activeWordColor": "{glow}"}},
         {"name": "two", "title": "x", "style": {"fontSize": "big"}}]
        """#
        let problems = PresetCatalog.parse([text]).problems
        #expect(problems.contains("Bad Name: not a kebab-case name"))
        #expect(problems.contains("two: listed twice"))
        #expect(problems.contains("two: fontSzie is not a style field"))
        #expect(problems.contains("two: {glow} is not a slot"))
        #expect(problems.contains("two: style.fontSize has the wrong type"))
        #expect(problems.contains { $0.hasPrefix("two: tint is a colour") })
    }
}
