//
//  StylePresetTests.swift
//  CaptionKitTests
//
//  Created by David Sherlock on 2026.
//
//  The preset catalog is data, and data rots silently: a style field can be
//  renamed, a gradient emptied, or a font dropped without any compile error
//  in the catalog itself. These tests render EVERY preset through the real
//  renderer and require visible ink, so a broken preset fails loudly here
//  instead of shipping as a blank swatch.
//

import CoreGraphics
import Foundation
import Testing
@testable import CaptionKit

@Suite("Style presets")
struct StylePresetTests {

    /// A small document showing one card mid-word, in the given style.
    private func document(style: CaptionStyle) -> CaptionDocument {
        var style = style
        style.position = NormalizedPoint(x: 0.5, y: 0.5)
        let words = [
            Word(text: "Every", start: 0, end: 0.5),
            Word(text: "preset", start: 0.5, end: 1.0),
            Word(text: "renders", start: 1.0, end: 1.5),
        ]
        var card = CaptionCard(words: words)
        card.start = 0
        card.end = 2
        return CaptionDocument(
            cards: [card],
            style: style,
            renderConfig: RenderConfig(width: 540, height: 960)
        )
    }

    /// Renders at `time` and reports whether any non-transparent pixels landed.
    private func rendersInk(style: CaptionStyle, at time: TimeInterval = 0.75) -> Bool {
        guard let image = CaptionRenderer.renderOverlay(document: document(style: style), at: time) else {
            return false
        }
        guard let data = image.dataProvider?.data as Data? else { return false }
        // Any alpha byte above a noise floor counts as ink (RGBA premultiplied).
        var index = 3
        while index < data.count {
            if data[index] > 8 { return true }
            index += 4
        }
        return false
    }

    @Test("Catalog names are unique and non-empty")
    func uniqueNames() {
        let names = StylePresets.all.map(\.name)
        #expect(!names.isEmpty)
        #expect(Set(names).count == names.count)
        #expect(names.allSatisfy { !$0.isEmpty })
    }

    @Test("Every preset in the catalog renders visible ink")
    func everyPresetRenders() {
        for (name, style) in StylePresets.all {
            #expect(rendersInk(style: style), "Preset \(name) rendered blank")
        }
    }

    @Test("Featured shelf only lists presets that exist")
    func featuredResolve() {
        let names = Set(StylePresets.all.map(\.name))
        #expect(StylePresets.featured.count >= 20)
        for name in StylePresets.featured {
            #expect(names.contains(name), "Featured references unknown preset \(name)")
        }
    }

    @Test("Grouping hints only reference presets that exist")
    func groupingHintNamesResolve() {
        let names = Set(StylePresets.all.map(\.name))
        for key in StylePresets.groupingHints.keys {
            #expect(names.contains(key), "Grouping hint for unknown preset \(key)")
        }
    }

    @Test("Word looks: every named look changes a word's appearance")
    func wordLooksRender() {
        // A look must render, and render DIFFERENTLY from the unstyled word —
        // otherwise the button is a no-op. Styles the FIRST word (settled by
        // the sample time): per-word gradients are deliberately suppressed
        // while a word is mid-entrance, so styling the active word would
        // false-fail gradient looks.
        func render(wordStyle: WordStyle?) -> Data? {
            var doc = document(style: CaptionStyle())
            doc.cards[0].words[0].style = wordStyle
            guard let image = CaptionRenderer.renderOverlay(document: doc, at: 0.75) else { return nil }
            return image.dataProvider?.data as Data?
        }
        let plain = render(wordStyle: nil)
        #expect(plain != nil)
        for (name, style) in WordLook.all where style != nil {
            let styled = render(wordStyle: style)
            #expect(styled != nil, "Word look \(name) failed to render")
            #expect(styled != plain, "Word look \(name) is a visual no-op")
        }
    }
}
