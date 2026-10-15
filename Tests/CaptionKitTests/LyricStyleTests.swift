//
//  LyricStyleTests.swift
//  CaptionKitTests
//
//  Created by David Sherlock on 2026.
//
//  The lyric-video feature set: glow, slant, gradient fills, scanlines,
//  chromatic aberration, hollow text, timing offset, text-sticker titles
//  (front and behind-person layers), and translation retiming.

import CoreGraphics
import Foundation
import Testing
@_spi(CaptionEngine) @testable import CaptionCore
@testable import CaptionKit

private func makeDocument(_ tune: (inout CaptionStyle) -> Void = { _ in }) -> CaptionDocument {
    let words = [
        Word(text: "Success", start: 0.0, end: 0.5),
        Word(text: "is", start: 0.5, end: 0.7),
        Word(text: "like", start: 0.7, end: 1.2),
    ]
    var style = CaptionStyle()
    style.highlightMode = .none
    style.background = nil
    tune(&style)
    return CaptionDocument(
        cards: CaptionGrouper.group(words),
        style: style,
        renderConfig: RenderConfig(width: 540, height: 960)
    )
}

private func opaquePixelCount(of image: CGImage) -> Int {
    let width = image.width, height = image.height
    var data = [UInt8](repeating: 0, count: width * height * 4)
    guard let context = CGContext(
        data: &data, width: width, height: height, bitsPerComponent: 8,
        bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return 0 }
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    var count = 0
    for pixel in stride(from: 3, to: data.count, by: 4) where data[pixel] > 0 {
        count += 1
    }
    return count
}

private func pixels(_ image: CGImage) -> Data? {
    image.dataProvider?.data as Data?
}

@Suite("Glow, slant & text effects")
struct LyricEffectTests {

    @Test("Glow blooms extra pixels around every word")
    func glowAllWords() throws {
        let plain = makeDocument()
        let glowing = makeDocument { $0.glow = GlowStyle(color: .white, radius: 20, intensity: 1, scope: .allWords) }
        let without = try #require(CaptionRenderer.renderOverlay(document: plain, at: 0.6))
        let with = try #require(CaptionRenderer.renderOverlay(document: glowing, at: 0.6))
        #expect(opaquePixelCount(of: with) > opaquePixelCount(of: without) + 500)
    }

    @Test("Spoken-word glow follows the active word over time")
    func glowActiveWord() throws {
        let document = makeDocument { style in
            style.glow = GlowStyle(color: .white, radius: 18, intensity: 1, scope: .activeWord)
        }
        let first = try #require(CaptionRenderer.renderOverlay(document: document, at: 0.2))
        let later = try #require(CaptionRenderer.renderOverlay(document: document, at: 1.0))
        #expect(pixels(first) != pixels(later))
    }

    @Test("Slant leans the glyphs without moving the layout")
    func slantStableLayout() throws {
        let upright = makeDocument()
        let slanted = makeDocument { $0.slant = 0.25 }

        let uprightLayout = try #require(CaptionLayout.layout(
            card: upright.cards[0], style: upright.style, config: upright.renderConfig))
        let slantedLayout = try #require(CaptionLayout.layout(
            card: slanted.cards[0], style: slanted.style, config: slanted.renderConfig))
        // A shear leaves advances (near-)untouched — word frames stay put to
        // within a pixel, so slanting never reflows a caption.
        for (upright, slanted) in zip(uprightLayout.words, slantedLayout.words) {
            #expect(abs(upright.frame.origin.x - slanted.frame.origin.x) < 1)
            #expect(abs(upright.frame.origin.y - slanted.frame.origin.y) < 1)
            #expect(abs(upright.frame.width - slanted.frame.width) < 1)
        }

        let uprightRender = try #require(CaptionRenderer.renderOverlay(document: upright, at: 0.6))
        let slantedRender = try #require(CaptionRenderer.renderOverlay(document: slanted, at: 0.6))
        #expect(pixels(uprightRender) != pixels(slantedRender))
    }

    @Test("Gradient fill replaces the flat color")
    func gradientFill() throws {
        let solid = makeDocument()
        let gradient = makeDocument { $0.textGradient = GradientFill(colors: [.yellow, .pink], angle: 90) }
        let flat = try #require(CaptionRenderer.renderOverlay(document: solid, at: 0.6))
        let ramped = try #require(CaptionRenderer.renderOverlay(document: gradient, at: 0.6))
        #expect(pixels(flat) != pixels(ramped))
        // Still deterministic.
        let again = try #require(CaptionRenderer.renderOverlay(document: gradient, at: 0.6))
        #expect(pixels(ramped) == pixels(again))
    }

    @Test("Scanlines and chromatic aberration each change the render")
    func scanlinesAndFringe() throws {
        let plain = try #require(CaptionRenderer.renderOverlay(document: makeDocument(), at: 0.6))
        let scanned = try #require(CaptionRenderer.renderOverlay(
            document: makeDocument { $0.scanlineIntensity = 1 }, at: 0.6))
        let fringed = try #require(CaptionRenderer.renderOverlay(
            document: makeDocument { $0.chromaticAberration = 5 }, at: 0.6))
        #expect(pixels(plain) != pixels(scanned))
        #expect(pixels(plain) != pixels(fringed))
        // Fringes paint beyond the glyphs; scanlines only darken inside them.
        #expect(opaquePixelCount(of: fringed) > opaquePixelCount(of: plain))
    }

    @Test("Hollow text renders stroke-only, and karaoke fills it in")
    func hollowText() throws {
        // No shadow in either document, so painted-pixel counts compare the
        // letterforms themselves.
        let hollow = makeDocument { style in
            style.textColor = StyleColor.white.withAlpha(0)
            style.strokeColor = .white
            style.strokeWidth = 4
            style.shadow = nil
            style.highlightMode = .karaoke
            style.activeWordColor = .white
        }
        let filled = makeDocument { style in
            style.strokeColor = nil
            style.shadow = nil
        }
        let outline = try #require(CaptionRenderer.renderOverlay(document: hollow, at: 0.05))
        let solid = try #require(CaptionRenderer.renderOverlay(document: filled, at: 0.05))
        // An outline ring paints real pixels and reads differently from a
        // solid fill. (Ring vs fill AREA isn't comparable — half the stroke
        // lands outside the glyph, so counts can go either way.)
        #expect(opaquePixelCount(of: outline) > 500)
        #expect(pixels(outline) != pixels(solid))

        // Karaoke pours fill into the hollow letters as time advances.
        let poured = try #require(CaptionRenderer.renderOverlay(document: hollow, at: 1.1))
        #expect(opaquePixelCount(of: poured) > opaquePixelCount(of: outline) + 200)
    }

    @Test("Caption timing offset shifts captions and nothing else")
    func timingOffset() throws {
        var early = makeDocument { $0.highlightMode = .karaoke }
        early.captionTimingOffset = -0.1
        let unshifted = makeDocument { $0.highlightMode = .karaoke }
        // Offset -100ms at t means the captions look like t+(-0.1)... i.e.
        // rendering the offset document at 0.6 equals the plain one at 0.5.
        let offsetRender = try #require(CaptionRenderer.renderOverlay(document: early, at: 0.6))
        let plainRender = try #require(CaptionRenderer.renderOverlay(document: unshifted, at: 0.5))
        #expect(pixels(offsetRender) == pixels(plainRender))
    }
}

@Suite("Speed-ramped cuts")
struct SpeedRampTests {

    @Test("Mapping through a sped range is exact and invertible")
    func spedMapping() {
        let map = TimeMap(cuts: [Cut(start: 10, end: 14, speed: 2)])
        // Four seconds of source hurry by in two seconds of output.
        #expect(abs(map.removedDuration - 2) < 1e-9)
        #expect(abs(map.outputTime(forSource: 12) - 11) < 1e-9)
        #expect(abs(map.outputTime(forSource: 14) - 12) < 1e-9)
        #expect(abs(map.outputTime(forSource: 20) - 18) < 1e-9)
        #expect(abs(map.sourceTime(forOutput: 11) - 12) < 1e-9)
        #expect(abs(map.sourceTime(forOutput: 18) - 20) < 1e-9)
        // A speed ramp is bijective — round-trips hold everywhere.
        for time in stride(from: 0.0, through: 25, by: 0.7) {
            let output = map.outputTime(forSource: time)
            #expect(abs(map.sourceTime(forOutput: output) - time) < 1e-6)
        }
    }

    @Test("Removed and sped cuts coexist; segments carry the treatment")
    func mixedCuts() {
        let map = TimeMap(cuts: [
            Cut(start: 2, end: 4),
            Cut(start: 10, end: 13, speed: 1.5),
        ])
        #expect(abs(map.removedDuration - 3) < 1e-9) // 2s removed + 1s saved
        let segments = map.playbackSegments(sourceDuration: 20)
        #expect(segments.count == 4) // 0–2, 4–10, 10–13 @1.5×, 13–20
        #expect(segments[2].speed == 1.5)
        #expect(segments.filter { $0.speed == nil }.count == 3)
        // Time inside the sped range maps proportionally.
        #expect(abs(map.outputTime(forSource: 11.5) - 9) < 1e-9) // 8 plain + 1.5/1.5
    }

    @Test("Old cut JSON without speed still decodes as full removal")
    func tolerantDecode() throws {
        let json = #"{"start": 3.0, "end": 5.0}"#.data(using: .utf8)!
        let cut = try JSONDecoder().decode(Cut.self, from: json)
        #expect(cut.speed == nil)
        #expect(cut.outputDuration == 0)
    }
}

/// A recognizably-styled override for the preservation test.
private enum StylePresetsFixture {
    static var styled: CaptionStyle {
        var style = CaptionStyle()
        style.textColor = .pink
        style.slant = 0.2
        style.glow = GlowStyle()
        return style
    }
}

@Suite("Layout centering")
struct LayoutCenteringTests {

    @Test("A centered style centers cards of every width — narrow ones too")
    func centeredMeansCentered() throws {
        let config = RenderConfig(width: 1080, height: 1920)
        var style = CaptionStyle()
        style.position = NormalizedPoint(x: 0.5, y: 0.75)

        for text in [["INSTAGRAM."], ["SO", "I", "FINALLY", "PLUGGED"], ["A"]] {
            var start = 0.0
            let words = text.map { word -> Word in
                defer { start += 0.3 }
                return Word(text: word, start: start, end: start + 0.3)
            }
            let card = CaptionCard(words: words)
            let layout = try #require(CaptionLayout.layout(card: card, style: style, config: config))
            let center = layout.blockRect.midX / config.size.width
            #expect(abs(center - 0.5) < 0.005, "card \(text.joined(separator: " ")) center = \(center)")
        }
    }

    @Test("An off-center anchor shows honestly on narrow cards (clamps only at edges)")
    func offCenterAnchor() throws {
        let config = RenderConfig(width: 1080, height: 1920)
        var style = CaptionStyle()
        style.position = NormalizedPoint(x: 0.62, y: 0.75)
        let card = CaptionCard(words: [Word(text: "HI", start: 0, end: 0.4)])
        let layout = try #require(CaptionLayout.layout(card: card, style: style, config: config))
        // The narrow card sits at the anchor — this is BY DESIGN; the fix
        // for "why is one word off to the right" is resetting the anchor,
        // not the math.
        #expect(abs(layout.blockRect.midX / config.size.width - 0.62) < 0.01)
    }
}
