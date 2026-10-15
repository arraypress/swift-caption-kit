//
//  NewStyleTests.swift
//  CaptionKitTests
//
//  Created by David Sherlock on 2026.
//
//  The renderer pieces behind the 2026-10 presets, each measured rather than
//  looked at: stacked line widths, seeded tilts, speaker dashes and breaks,
//  the second-language line, held weight ramps, key-word highlights, speaker
//  names and colours, sentence capitals, the slide-in and the colour cycle.

import CoreGraphics
import Foundation
import Testing
@_spi(CaptionEngine) @testable import CaptionCore
@testable import CaptionKit

private let canvas = RenderConfig(width: 540, height: 960)

/// RGBA bytes of an image, top row first.
private func pixels(of image: CGImage) -> [UInt8] {
    var data = [UInt8](repeating: 0, count: image.width * image.height * 4)
    let context = CGContext(data: &data, width: image.width, height: image.height, bitsPerComponent: 8,
                            bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    return data
}

/// The summed alpha of every pixel in `rect` (normalized, top-left).
private func ink(_ image: CGImage, in rect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)) -> Int {
    let data = pixels(of: image)
    let x0 = Int(rect.minX * CGFloat(image.width)), x1 = Int(rect.maxX * CGFloat(image.width))
    let y0 = Int(rect.minY * CGFloat(image.height)), y1 = Int(rect.maxY * CGFloat(image.height))
    var sum = 0
    for y in max(0, y0)..<min(image.height, y1) {
        for x in max(0, x0)..<min(image.width, x1) { sum += Int(data[(y * image.width + x) * 4 + 3]) }
    }
    return sum
}

/// Opaque pixels within `tolerance` of `color` in `rect` (normalized, top-left).
private func count(_ color: StyleColor, in image: CGImage, rect: CGRect, tolerance: Int = 24) -> Int {
    let data = pixels(of: image)
    let target = [color.red, color.green, color.blue].map { Int(($0 * 255).rounded()) }
    let x0 = Int(rect.minX * CGFloat(image.width)), x1 = Int(rect.maxX * CGFloat(image.width))
    let y0 = Int(rect.minY * CGFloat(image.height)), y1 = Int(rect.maxY * CGFloat(image.height))
    var hits = 0
    for y in max(0, y0)..<min(image.height, y1) {
        for x in max(0, x0)..<min(image.width, x1) {
            let i = (y * image.width + x) * 4
            guard data[i + 3] > 240 else { continue }
            if abs(Int(data[i]) - target[0]) <= tolerance, abs(Int(data[i + 1]) - target[1]) <= tolerance,
               abs(Int(data[i + 2]) - target[2]) <= tolerance { hits += 1 }
        }
    }
    return hits
}

/// A plain style with no outline or shadow, so colours measure cleanly.
private func flatStyle() -> CaptionStyle {
    var style = CaptionStyle()
    style.strokeColor = nil
    style.strokeWidth = 0
    style.shadow = nil
    style.activeWordScale = 1
    return style
}

@Suite("New style pieces")
struct NewStyleTests {

    // MARK: Stacked

    @Test("Stacked: every line is scaled to the widest line's width, up to the cap")
    func stackedLinesShareAWidth() throws {
        let words = [Word(text: "MONEY", start: 0, end: 0.4), Word(text: "TRAVEL", start: 0.4, end: 0.8),
                     Word(text: "ON", start: 0.8, end: 1.0)]
        let card = CaptionCard(words: words, lineBreaks: [1, 2])
        var plain = flatStyle()
        plain.maxWidthFraction = 1
        var stacked = plain
        stacked.fitLinesToWidth = true
        let base = try #require(CaptionLayout.layout(card: card, style: plain, config: canvas))
        let fitted = try #require(CaptionLayout.layout(card: card, style: stacked, config: canvas))
        let target = base.lines.map(\.frame.width).max()!
        for (index, line) in fitted.lines.enumerated() {
            let wanted = min(target, base.lines[index].frame.width * CaptionStyle.maximumLineFitScale)
            #expect(abs(line.frame.width - wanted) / wanted < 0.03, "line \(index): \(line.frame.width) vs \(wanted)")
        }
        // "ON" is narrower than 1/2.4 of the widest: it stops at the cap.
        #expect(fitted.lines[2].frame.width < target * 0.95)
        // Taller lines: the scaled lines are taller than the plain ones.
        #expect(fitted.blockRect.height > base.blockRect.height * 1.2)
    }

    // MARK: Tilt

    @Test("Card tilt: seeded per card, deterministic, within the bound, and not all the same")
    func cardTiltIsSeeded() {
        var style = flatStyle()
        style.cardTilt = 0.07
        let cards = (0..<8).map { CaptionCard(words: [Word(text: "W\($0)", start: Double($0), end: Double($0) + 0.5)]) }
        let tilts = cards.map { CaptionRenderer.blockRotation(for: $0, style: style) }
        #expect(tilts == cards.map { CaptionRenderer.blockRotation(for: $0, style: style) })
        #expect(tilts.allSatisfy { abs($0) <= 0.07 + 1e-9 })
        #expect(Set(tilts.map { Int(($0 * 1000).rounded()) }).count >= 5)
        style.cardTilt = nil
        #expect(cards.allSatisfy { CaptionRenderer.blockRotation(for: $0, style: style) == 0 })
    }

    // MARK: Speakers

    @Test("Grouping: speakerBreak line breaks a line at a new speaker; card breaks the card")
    func speakerBreaks() {
        var words = ["one", "two", "three", "four", "five", "six"].enumerated().map {
            Word(text: $0.element, start: Double($0.offset) * 0.3, end: Double($0.offset) * 0.3 + 0.25)
        }
        for i in words.indices { words[i].speaker = i < 3 ? 0 : 1 }
        var rules = GroupingRules(maxLinesPerCard: 2, maxWordsPerLine: 12, maxCharactersPerLine: 42)
        #expect(CaptionGrouper.group(words, rules: rules).map(\.lineBreaks) == [[]])
        rules.speakerBreak = .line
        let lined = CaptionGrouper.group(words, rules: rules)
        #expect(lined.count == 1)
        #expect(lined[0].lineBreaks == [3])
        rules.speakerBreak = .card
        #expect(CaptionGrouper.group(words, rules: rules).map { $0.words.count } == [3, 3])
        // A third speaker turn cannot share the card: it starts a new one.
        words.append(Word(text: "seven", start: 1.8, end: 2.0))
        words[6].speaker = 0
        rules.speakerBreak = .line
        #expect(CaptionGrouper.group(words, rules: rules).map { $0.words.count } == [6, 1])
    }

    @Test("Speaker dash: a dash opens each line only when two speakers share the card")
    func speakerDash() {
        var words = ["Hello", "there", "Hi", "back"].enumerated().map {
            Word(text: $0.element, start: Double($0.offset), end: Double($0.offset) + 0.5)
        }
        words[0].speaker = 0; words[1].speaker = 0; words[2].speaker = 1; words[3].speaker = 1
        let two = CaptionCard(words: words, lineBreaks: [2])
        var style = flatStyle()
        style.speakerDash = true
        #expect(CaptionLayout.displayTexts(for: two, style: style) == ["- Hello", "there", "- Hi", "back"])
        let one = CaptionCard(words: Array(words.prefix(2)))
        #expect(CaptionLayout.displayTexts(for: one, style: style) == ["Hello", "there"])
        style.speakerDash = nil
        #expect(CaptionLayout.displayTexts(for: two, style: style) == ["Hello", "there", "Hi", "back"])
    }

    @Test("Speaker colours: the style's palette colours a speaker; the document's wins")
    func speakerColoursFromStyle() throws {
        let cyan = StyleColor(red: 0, green: 0.85, blue: 1, alpha: 1)
        let red = StyleColor(red: 1, green: 0.1, blue: 0.1, alpha: 1)
        var style = flatStyle()
        style.highlightMode = .none
        style.speakerColors = [StyleColor.white, cyan]
        var word = Word(text: "COLOUR", start: 0, end: 1)
        word.speaker = 1
        var document = CaptionDocument(cards: [CaptionCard(words: [word])], style: style, renderConfig: canvas)
        let styled = try #require(CaptionRenderer.renderOverlay(document: document, at: 0.5))
        let whole = CGRect(x: 0, y: 0, width: 1, height: 1)
        #expect(count(cyan, in: styled, rect: whole) > 500)
        document.speakerColors = [StyleColor.white, red]
        let overridden = try #require(CaptionRenderer.renderOverlay(document: document, at: 0.5))
        #expect(count(cyan, in: overridden, rect: whole) == 0)
        #expect(count(red, in: overridden, rect: whole) > 500)
    }

    @Test("Speaker label: the name is drawn above the block only when the words carry a speaker")
    func speakerLabel() throws {
        var style = flatStyle()
        style.speakerLabel = SpeakerLabelStyle(mode: .chip, scale: 0.5)
        style.speakerColors = [.yellow, .white]
        var word = Word(text: "HELLO", start: 0, end: 1)
        var document = CaptionDocument(cards: [CaptionCard(words: [word])], style: style, renderConfig: canvas)
        var layout = try #require(CaptionLayout.layout(card: document.cards[0], style: style, config: canvas))
        #expect(CaptionRenderer.cardExtras(card: document.cards[0], style: style, layout: layout, document: document).label == nil)

        word.speaker = 0
        document.cards = [CaptionCard(words: [word])]
        document.speakerNames = ["Maya"]
        layout = try #require(CaptionLayout.layout(card: document.cards[0], style: style, config: canvas))
        let extras = CaptionRenderer.cardExtras(card: document.cards[0], style: style, layout: layout, document: document)
        let chip = try #require(extras.chip)
        #expect(chip.rect.minY >= layout.blockRect.maxY)          // above the block (CG is y-up)
        #expect(chip.color == .yellow)                             // in the speaker's colour
        #expect(chip.rect.height < layout.blockRect.height)
        #expect(CaptionRenderer.speakerName(0, document: document) == "Maya")
        #expect(CaptionRenderer.speakerName(1, document: document) == "Speaker 2")
        // The chip is in the overlay: yellow pixels above the caption block.
        let overlay = try #require(CaptionRenderer.renderOverlay(document: document, at: 0.5))
        let block = try #require(CaptionRenderer.captionBlockRect(document: document, at: 0.5))
        let above = CGRect(x: 0, y: block.minY, width: 1, height: max(0.001, block.height * 0.35))
        #expect(count(.yellow, in: overlay, rect: above) > 100)
    }

    // MARK: Bilingual

    @Test("Second line: the overlapping secondary words, smaller, above the caption")
    func secondaryLine() throws {
        var style = flatStyle()
        style.secondaryLine = SecondaryLineStyle(scale: 0.6)
        let words = [Word(text: "Hello", start: 1, end: 1.5), Word(text: "world", start: 1.5, end: 2)]
        var document = CaptionDocument(cards: [CaptionCard(words: words)], style: style, renderConfig: canvas)
        document.secondaryWords = [Word(text: "Hola", start: 1, end: 1.4), Word(text: "mundo", start: 1.4, end: 1.9),
                                   Word(text: "después", start: 5, end: 6)]
        let layout = try #require(CaptionLayout.layout(card: document.cards[0], style: style, config: canvas))
        #expect(CaptionRenderer.secondaryWords(for: document.cards[0], in: document.secondaryWords!).map(\.text) == ["Hola", "mundo"])
        let extras = CaptionRenderer.cardExtras(card: document.cards[0], style: style, layout: layout, document: document)
        let line = try #require(extras.secondary)
        #expect(line.rect.minY >= layout.blockRect.maxY)
        #expect(line.rect.height < layout.blockRect.height * 0.8)
        // With no secondary words there is no line, and the overlay is the plain caption's.
        let with = try #require(CaptionRenderer.renderOverlay(document: document, at: 1.6))
        document.secondaryWords = nil
        let without = try #require(CaptionRenderer.renderOverlay(document: document, at: 1.6))
        #expect(ink(with) > ink(without))
    }

    // MARK: Weight sweep

    @Test("Held weight ramp: a word already said stays bold; without hold it returns")
    func heldWeightRamp() throws {
        var style = flatStyle()
        style.fontWeight = .light
        style.activeWordWeightRamp = .black
        style.highlightMode = .none
        let words = [Word(text: "heavy", start: 0, end: 0.5), Word(text: "after", start: 0.6, end: 1.2)]
        func inkOfFirstWord(holds: Bool) throws -> Int {
            var held = style
            held.weightRampHolds = holds ? true : nil
            let document = CaptionDocument(cards: [CaptionCard(words: words)], style: held, renderConfig: canvas)
            let image = try #require(CaptionRenderer.renderOverlay(document: document, at: 1.0))
            let rects = try #require(CaptionRenderer.wordRects(document: document, at: 1.0)).rects
            return ink(image, in: rects[0].rect.insetBy(dx: -0.01, dy: -0.01))
        }
        let held = try inkOfFirstWord(holds: true)
        let released = try inkOfFirstWord(holds: false)
        #expect(Double(held) > Double(released) * 1.25, "held \(held) vs released \(released)")
    }

    // MARK: Key words

    @Test("Key-word highlight: the marker sits on the emphasised word, not the spoken one")
    func keyWordHighlight() throws {
        let pastel = StyleColor(red: 1, green: 0.91, blue: 0.54, alpha: 1)
        var style = flatStyle()
        style.highlightMode = .activeBox
        style.activeWordColor = pastel
        style.activeBoxShape = .marker
        style.highlightKeyWords = true
        var words = [Word(text: "save", start: 0, end: 0.4), Word(text: "the", start: 0.4, end: 0.6),
                     Word(text: "money", start: 0.6, end: 1.0)]
        var emphasis = WordStyle()
        emphasis.color = .yellow
        words[2].style = emphasis
        var document = CaptionDocument(cards: [CaptionCard(words: words)], style: style, renderConfig: canvas)
        let image = try #require(CaptionRenderer.renderOverlay(document: document, at: 0.2))   // "save" spoken
        let rects = try #require(CaptionRenderer.wordRects(document: document, at: 0.2)).rects
        #expect(count(pastel, in: image, rect: rects[2].rect) > 200)
        #expect(count(pastel, in: image, rect: rects[0].rect) == 0)
        // No emphasis on the card: the voice leads again.
        document.cards[0].words[2].style = nil
        let voiced = try #require(CaptionRenderer.renderOverlay(document: document, at: 0.2))
        #expect(count(pastel, in: voiced, rect: rects[0].rect) > 200)
    }

    // MARK: Text

    @Test("Sentence case: capitals at the card's start and after a sentence ends; the rest as written")
    func sentenceCase() {
        var style = flatStyle()
        style.textTransform = .sentence
        let words = ["so", "this", "works.", "then", "Paris", "iPhone"].enumerated().map {
            Word(text: $0.element, start: Double($0.offset), end: Double($0.offset) + 0.5)
        }
        #expect(CaptionLayout.displayTexts(for: CaptionCard(words: words), style: style)
                == ["So", "this", "works.", "Then", "Paris", "iPhone"])
    }

    // MARK: Motion and colour

    @Test("Slide in from the left: the block starts left of where it settles")
    func slideInLeft() throws {
        var style = flatStyle()
        style.cardAnimation = .slideInLeft
        style.animationDuration = 0.2
        let document = CaptionDocument(cards: [CaptionCard(words: [Word(text: "SLIDE", start: 0, end: 2)])],
                                       style: style, renderConfig: canvas)
        func centroid(_ time: Double) throws -> Double {
            let data = pixels(of: try #require(CaptionRenderer.renderOverlay(document: document, at: time)))
            var total = 0.0, weight = 0.0
            for i in stride(from: 0, to: data.count, by: 4) where data[i + 3] > 0 {
                total += Double((i / 4) % canvas.width) * Double(data[i + 3]); weight += Double(data[i + 3])
            }
            return weight > 0 ? total / weight : -1
        }
        let early = try centroid(0.08), settled = try centroid(1.0)
        #expect(early < settled - 40, "early \(early) settled \(settled)")
        #expect(abs(settled - Double(canvas.width) / 2) < 20)
    }

    @Test("Colour-cycling highlight: consecutive spoken words take consecutive palette colours")
    func activeWordPalette() throws {
        let palette = [StyleColor(red: 1, green: 0.1, blue: 0.1, alpha: 1), StyleColor(red: 0.1, green: 0.9, blue: 0.2, alpha: 1)]
        var style = flatStyle()
        style.highlightMode = .activeWord
        style.activeWordPalette = palette
        let words = [Word(text: "ONE", start: 0, end: 0.5), Word(text: "TWO", start: 0.5, end: 1)]
        let document = CaptionDocument(cards: [CaptionCard(words: words)], style: style, renderConfig: canvas)
        let whole = CGRect(x: 0, y: 0, width: 1, height: 1)
        func colour(at time: Double) throws -> Int? {
            let image = try #require(CaptionRenderer.renderOverlay(document: document, at: time))
            return palette.indices.first { count(palette[$0], in: image, rect: whole) > 200 }
        }
        let first = try #require(try colour(at: 0.25)), second = try #require(try colour(at: 0.75))
        #expect(first != second)
    }

    // MARK: Data

    @Test("Document: speaker names and secondary words survive a save and a load")
    func documentRoundTrip() throws {
        var document = CaptionDocument(cards: [CaptionCard(words: [Word(text: "a", start: 0, end: 1)])])
        document.speakerNames = ["Maya", "Jon"]
        document.secondaryWords = [Word(text: "uno", start: 0, end: 1)]
        let back = try CaptionDocument.deserialize(from: document.serialized())
        #expect(back.speakerNames == ["Maya", "Jon"])
        #expect(back.secondaryWords == document.secondaryWords)
        #expect(back.preserved.isEmpty)
    }

    @Test("Schema: the new style fields are fields, and an inline style with them decodes")
    func schemaKnowsNewFields() throws {
        for field in ["speakerColors", "speakerLabel", "speakerDash", "fitLinesToWidth", "cardTilt", "secondaryLine",
                      "activeWordPalette", "activeBoxShape", "highlightKeyWords", "weightRampHolds"] {
            #expect(StyleSchema.fields.contains(field), "\(field)")
        }
        let inline: [String: JSONValue] = [
            "speakerLabel": .object(["mode": .string("chip"), "scale": .number(0.4)]),
            "secondaryLine": .object(["scale": .number(0.6), "color": .string("white@0.8")]),
            "speakerColors": .array([.string("yellow"), .string("#4FD8FF")]),
            "textTransform": .string("sentence"), "cardAnimation": .string("slide-in-left"), "fontWeight": .string("light"),
        ]
        #expect(StyleSchema.unknownKeys(in: inline).isEmpty)
        let style = try StyleJSON.style(from: inline)
        #expect(style.speakerLabel?.mode == .chip)
        #expect(style.speakerColors?.count == 2)
        #expect(style.cardAnimation == .slideInLeft)
        #expect(style.textTransform == .sentence)
    }

    @Test("Raw values are kebab-case throughout the style vocabulary")
    func kebabRawValues() {
        let all = WordAnimation.allCases.map(\.rawValue) + CardAnimation.allCases.map(\.rawValue)
            + HighlightMode.allCases.map(\.rawValue) + CutStyle.allCases.map(\.rawValue)
            + BackgroundStyle.Mode.allCases.map(\.rawValue) + GlowStyle.Scope.allCases.map(\.rawValue)
            + TrackKind.allCases.map(\.rawValue)
        for value in all {
            #expect(value.allSatisfy { $0.isLowercase || $0 == "-" }, "\(value)")
        }
        #expect(HighlightMode.activeBox.rawValue == "active-box")
        #expect(CutStyle.dipToBlack.rawValue == "dip-to-black")
    }

    @Test("Every new preset draws, and the two renamed ones answer to their new names only")
    func newPresetsDraw() throws {
        let names = ["weight-sweep", "subtitle", "lower-third", "two-speaker", "stacked", "extruded", "marker",
                     "glitch", "bilingual", "soft-highlight", "tilted-bounce", "color-box", "thumbnail"]
        var words = ["Save", "money", "on", "travel", "and", "hotels"].enumerated().map {
            Word(text: $0.element, start: Double($0.offset) * 0.4, end: Double($0.offset) * 0.4 + 0.35)
        }
        for i in words.indices { words[i].speaker = i < 3 ? 0 : 1 }
        for name in names {
            let preset = try StylePresets.require(name)
            var document = CaptionDocument(cards: CaptionGrouper.group(words, rules: preset.grouping ?? GroupingRules()),
                                           style: try preset.style(), renderConfig: canvas)
            document.secondaryWords = [Word(text: "Ahorra dinero", start: 0, end: 1)]
            let image = try #require(CaptionRenderer.renderOverlay(document: document, at: 1.0))
            #expect(ink(image) > 10_000, "\(name) drew nothing")
        }
        #expect(StylePresets.named("hormozi") == nil)
        #expect(StylePresets.named("beast") == nil)
    }
}
