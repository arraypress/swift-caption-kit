//
//  WordStyleTests.swift
//  CaptionKit
//
//  Per-word graphic styling: rotation, slant, baseline offset, layered
//  strokes, per-word fills, and depth — the "advanced subtitle" look where
//  individual words carry their own treatment.
//

import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@_spi(CaptionEngine) @testable import CaptionCore
@testable import CaptionKitLite

/// Writes a small two-tone PNG to a temp file and returns its URL, so the
/// image-fill path has a real file to read.
private func makeTempImage(_ name: String) throws -> URL {
    let w = 64, h = 64
    let ctx = try #require(CGContext(
        data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ))
    ctx.setFillColor(CGColor(srgbRed: 0.1, green: 0.5, blue: 0.9, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
    ctx.setFillColor(CGColor(srgbRed: 0.95, green: 0.75, blue: 0.1, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h / 2))
    let image = try #require(ctx.makeImage())
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).png")
    let dest = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(dest, image, nil)
    #expect(CGImageDestinationFinalize(dest))
    return url
}

/// A three-word document whose middle word ("BIG") can be styled per word.
private func makeDocument(
    style tuneStyle: (inout CaptionStyle) -> Void = { _ in },
    word tuneWord: (inout WordStyle) -> Void = { _ in }
) -> CaptionDocument {
    var middle = WordStyle()
    tuneWord(&middle)
    let words = [
        Word(text: "the", start: 0.0, end: 0.4),
        Word(text: "BIG", start: 0.4, end: 0.9, style: middle.isEmpty ? nil : middle),
        Word(text: "one", start: 0.9, end: 1.3),
    ]
    var style = CaptionStyle()
    style.highlightMode = .none
    style.background = nil
    tuneStyle(&style)
    return CaptionDocument(
        cards: CaptionGrouper.group(words),
        style: style,
        renderConfig: RenderConfig(width: 540, height: 960)
    )
}

private func rawPixels(_ image: CGImage) -> Data? {
    image.dataProvider?.data as Data?
}

/// The vertical extent (in rows) of the opaque ink — grows when a warp lifts
/// glyphs off the baseline.
private func opaqueVerticalExtent(_ image: CGImage) -> Int {
    let w = image.width, h = image.height
    var data = [UInt8](repeating: 0, count: w * h * 4)
    guard let ctx = CGContext(
        data: &data, width: w, height: h, bitsPerComponent: 8,
        bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return 0 }
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    var minRow = h, maxRow = -1
    for y in 0..<h {
        for x in 0..<w where data[(y * w + x) * 4 + 3] > 0 {
            minRow = min(minRow, y); maxRow = max(maxRow, y); break
        }
    }
    return maxRow >= minRow ? maxRow - minRow : 0
}

private func opaqueCount(_ image: CGImage) -> Int {
    let w = image.width, h = image.height
    var data = [UInt8](repeating: 0, count: w * h * 4)
    guard let ctx = CGContext(
        data: &data, width: w, height: h, bitsPerComponent: 8,
        bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return 0 }
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    var count = 0
    for i in stride(from: 3, to: data.count, by: 4) where data[i] > 0 { count += 1 }
    return count
}

@Suite("Per-word styling — geometry")
struct WordStyleGeometryTests {

    @Test("Per-word rotation tilts only its own word and changes the render")
    func perWordRotation() throws {
        let level = makeDocument()
        let tilted = makeDocument(word: { $0.rotation = 0.2 })
        let a = try #require(CaptionRenderer.renderOverlay(document: level, at: 0.6))
        let b = try #require(CaptionRenderer.renderOverlay(document: tilted, at: 0.6))
        #expect(rawPixels(a) != rawPixels(b))

        // The tilt is a draw-time transform, so the reserved layout is untouched
        // — neighbours don't reflow.
        let l1 = try #require(CaptionLayout.layout(card: level.cards[0], style: level.style, config: level.renderConfig))
        let l2 = try #require(CaptionLayout.layout(card: tilted.cards[0], style: tilted.style, config: tilted.renderConfig))
        for (x, y) in zip(l1.words, l2.words) {
            #expect(abs(x.frame.origin.x - y.frame.origin.x) < 1)
            #expect(abs(x.frame.width - y.frame.width) < 1)
        }
    }

    @Test("Per-word slant leans one word without reflowing the line")
    func perWordSlant() throws {
        let upright = makeDocument()
        let slanted = makeDocument(word: { $0.slant = 0.3 })
        let uprightLayout = try #require(CaptionLayout.layout(card: upright.cards[0], style: upright.style, config: upright.renderConfig))
        let slantedLayout = try #require(CaptionLayout.layout(card: slanted.cards[0], style: slanted.style, config: slanted.renderConfig))
        for (a, b) in zip(uprightLayout.words, slantedLayout.words) {
            #expect(abs(a.frame.origin.x - b.frame.origin.x) < 1)
            #expect(abs(a.frame.origin.y - b.frame.origin.y) < 1)
        }
        let a = try #require(CaptionRenderer.renderOverlay(document: upright, at: 0.6))
        let b = try #require(CaptionRenderer.renderOverlay(document: slanted, at: 0.6))
        #expect(rawPixels(a) != rawPixels(b))
    }

    @Test("Per-word baseline offset lifts one word off the shared baseline")
    func perWordBaselineOffset() throws {
        let flat = makeDocument()
        let raised = makeDocument(word: { $0.baselineOffset = 40 })
        let a = try #require(CaptionRenderer.renderOverlay(document: flat, at: 0.6))
        let b = try #require(CaptionRenderer.renderOverlay(document: raised, at: 0.6))
        #expect(rawPixels(a) != rawPixels(b))
    }
}

@Suite("Per-word styling — strokes")
struct WordStyleStrokeTests {

    @Test("A per-word outline recolors and thickens only its own word")
    func perWordStroke() throws {
        let base = makeDocument()
        let outlined = makeDocument(word: {
            $0.strokeColor = .init(red: 1, green: 0, blue: 0)
            $0.strokeWidth = 22
        })
        let a = try #require(CaptionRenderer.renderOverlay(document: base, at: 0.6))
        let b = try #require(CaptionRenderer.renderOverlay(document: outlined, at: 0.6))
        #expect(rawPixels(a) != rawPixels(b))
        // A thicker outline on one word covers strictly more pixels than the
        // default 6pt stroke.
        #expect(opaqueCount(b) > opaqueCount(a))
    }

    @Test("Global layered strokes stack widest-first and add a colored halo")
    func layeredStrokes() throws {
        let single = makeDocument { $0.strokeLayers = [StrokeLayer(color: .black, width: 8)] }
        let stacked = makeDocument {
            $0.strokeLayers = [
                StrokeLayer(color: .init(red: 1, green: 0, blue: 0), width: 26), // wide red, drawn first
                StrokeLayer(color: .black, width: 8),                            // black over it
            ]
        }
        let a = try #require(CaptionRenderer.renderOverlay(document: single, at: 0.6))
        let b = try #require(CaptionRenderer.renderOverlay(document: stacked, at: 0.6))
        #expect(rawPixels(a) != rawPixels(b))
        #expect(opaqueCount(b) > opaqueCount(a)) // the wide red layer grows the silhouette
    }

    @Test("Per-word stroke layers override the global stroke for one word")
    func perWordLayeredStrokes() throws {
        let base = makeDocument { $0.strokeLayers = [StrokeLayer(color: .black, width: 8)] }
        let oneWord = makeDocument(
            style: { $0.strokeLayers = [StrokeLayer(color: .black, width: 8)] },
            word: {
                $0.strokeLayers = [
                    StrokeLayer(color: .init(red: 1, green: 0.85, blue: 0), width: 28),
                    StrokeLayer(color: .black, width: 8),
                ]
            }
        )
        let a = try #require(CaptionRenderer.renderOverlay(document: base, at: 0.6))
        let b = try #require(CaptionRenderer.renderOverlay(document: oneWord, at: 0.6))
        #expect(rawPixels(a) != rawPixels(b))
        #expect(opaqueCount(b) > opaqueCount(a))
    }
}

@Suite("Per-word styling — fills")
struct WordStyleFillTests {

    @Test("A per-word gradient fills only its word and changes the render")
    func perWordGradient() throws {
        let solid = makeDocument()
        let ramped = makeDocument(word: {
            $0.gradient = GradientFill(colors: [.init(red: 1, green: 0.85, blue: 0),
                                                .init(red: 0.9, green: 0.4, blue: 0)], angle: 90)
        })
        let a = try #require(CaptionRenderer.renderOverlay(document: solid, at: 0.6))
        let b = try #require(CaptionRenderer.renderOverlay(document: ramped, at: 0.6))
        #expect(rawPixels(a) != rawPixels(b))
        // Deterministic: same inputs, same output.
        let again = try #require(CaptionRenderer.renderOverlay(document: ramped, at: 0.6))
        #expect(rawPixels(b) == rawPixels(again))
    }

    @Test("A global image fill masks a photo into every glyph")
    func globalImageFill() throws {
        let url = try makeTempImage("wm-global-fill")
        let plain = makeDocument()
        let photo = makeDocument { $0.imageFill = ImageFill(url: url) }
        let a = try #require(CaptionRenderer.renderOverlay(document: plain, at: 0.6))
        let b = try #require(CaptionRenderer.renderOverlay(document: photo, at: 0.6))
        #expect(rawPixels(a) != rawPixels(b))
    }

    @Test("A per-word image fill crops a photo into one word only")
    func perWordImageFill() throws {
        let url = try makeTempImage("wm-word-fill")
        let plain = makeDocument()
        let photo = makeDocument(word: { $0.imageFill = ImageFill(url: url) })
        let a = try #require(CaptionRenderer.renderOverlay(document: plain, at: 0.6))
        let b = try #require(CaptionRenderer.renderOverlay(document: photo, at: 0.6))
        #expect(rawPixels(a) != rawPixels(b))
    }

    @Test("A spoken-word highlight paints solid over a per-word gradient")
    func highlightOverridesGradient() throws {
        // With active-word highlighting, the middle word recolors solid while
        // spoken — so at its active moment it must differ from the resting
        // gradient render.
        func doc() -> CaptionDocument {
            makeDocument(
                style: { $0.highlightMode = .activeWord; $0.activeWordColor = .init(red: 1, green: 0, blue: 0) },
                word: { $0.gradient = GradientFill(colors: [.white, .init(red: 0, green: 0, blue: 1)], angle: 90) }
            )
        }
        let resting = try #require(CaptionRenderer.renderOverlay(document: doc(), at: 0.1)) // before "BIG"
        let active = try #require(CaptionRenderer.renderOverlay(document: doc(), at: 0.6))   // during "BIG"
        #expect(rawPixels(resting) != rawPixels(active))
    }
}

@Suite("Per-word styling — hard shadow")
struct WordStyleHardShadowTests {

    @Test("A global hard drop adds a crisp offset silhouette")
    func globalHardShadow() throws {
        let plain = makeDocument { $0.hardShadow = nil }
        let dropped = makeDocument {
            $0.hardShadow = HardShadowStyle(color: .init(red: 1, green: 0, blue: 0), offsetX: 10, offsetY: 10)
        }
        let a = try #require(CaptionRenderer.renderOverlay(document: plain, at: 0.6))
        let b = try #require(CaptionRenderer.renderOverlay(document: dropped, at: 0.6))
        #expect(rawPixels(a) != rawPixels(b))
        #expect(opaqueCount(b) > opaqueCount(a)) // the offset copy adds ink
    }

    @Test("A per-word hard drop overrides the global one for its word")
    func perWordHardShadow() throws {
        let base = makeDocument {
            $0.hardShadow = HardShadowStyle(color: .init(red: 0, green: 0, blue: 0), offsetX: 4, offsetY: 4)
        }
        let overridden = makeDocument(
            style: { $0.hardShadow = HardShadowStyle(color: .black, offsetX: 4, offsetY: 4) },
            word: { $0.hardShadow = HardShadowStyle(color: .init(red: 1, green: 0, blue: 0), offsetX: 16, offsetY: 16) }
        )
        let a = try #require(CaptionRenderer.renderOverlay(document: base, at: 0.6))
        let b = try #require(CaptionRenderer.renderOverlay(document: overridden, at: 0.6))
        #expect(rawPixels(a) != rawPixels(b))
        #expect(opaqueCount(b) > opaqueCount(a)) // larger offset on one word = more ink
    }
}

@Suite("Per-word styling — extrude")
struct WordStyleExtrudeTests {

    @Test("A per-word extrusion builds solid depth behind one word")
    func perWordExtrude() throws {
        let flat = makeDocument()
        let deep = makeDocument(word: {
            $0.extrude = ExtrudeStyle(color: .init(red: 0.4, green: 0.3, blue: 0),
                                      depth: 20, angle: -45, fade: 0.4)
        })
        let a = try #require(CaptionRenderer.renderOverlay(document: flat, at: 0.6))
        let b = try #require(CaptionRenderer.renderOverlay(document: deep, at: 0.6))
        #expect(rawPixels(a) != rawPixels(b))
        #expect(opaqueCount(b) > opaqueCount(a)) // the depth wall adds ink
    }

    @Test("Deeper extrusion covers strictly more pixels")
    func deeperExtrudeMoreInk() throws {
        let shallow = makeDocument { $0.extrude = ExtrudeStyle(color: .black, depth: 8, angle: -45, fade: nil) }
        let deep = makeDocument { $0.extrude = ExtrudeStyle(color: .black, depth: 28, angle: -45, fade: nil) }
        let a = try #require(CaptionRenderer.renderOverlay(document: shallow, at: 0.6))
        let b = try #require(CaptionRenderer.renderOverlay(document: deep, at: 0.6))
        #expect(opaqueCount(b) > opaqueCount(a))
    }

    @Test("Extrusion is deterministic frame to frame")
    func extrudeDeterministic() throws {
        let doc = makeDocument { $0.extrude = ExtrudeStyle(color: .init(red: 0.5, green: 0.4, blue: 0), depth: 18) }
        let a = try #require(CaptionRenderer.renderOverlay(document: doc, at: 0.6))
        let b = try #require(CaptionRenderer.renderOverlay(document: doc, at: 0.6))
        #expect(rawPixels(a) == rawPixels(b))
    }
}

@Suite("Title warp — text on a path")
struct TextWarpTests {

    @Test("An arc warp bends the caption, spreading ink vertically")
    func arcBends() throws {
        let straight = makeDocument()
        let arched = makeDocument { $0.textWarp = TextWarp(shape: .arc, amount: 0.3) }
        let a = try #require(CaptionRenderer.renderOverlay(document: straight, at: 0.6))
        let b = try #require(CaptionRenderer.renderOverlay(document: arched, at: 0.6))
        #expect(rawPixels(a) != rawPixels(b))
        // The arch lifts the middle glyphs off the baseline, so the ink covers
        // more vertical rows than a straight line of the same words.
        #expect(opaqueVerticalExtent(b) > opaqueVerticalExtent(a))
    }

    @Test("Warp is a draw-time bend — it never reflows the layout")
    func warpKeepsLayout() throws {
        let straight = makeDocument()
        let warped = makeDocument { $0.textWarp = TextWarp(shape: .wave, amount: 0.2, waves: 2) }
        let l1 = try #require(CaptionLayout.layout(card: straight.cards[0], style: straight.style, config: straight.renderConfig))
        let l2 = try #require(CaptionLayout.layout(card: warped.cards[0], style: warped.style, config: warped.renderConfig))
        for (a, b) in zip(l1.words, l2.words) {
            #expect(abs(a.frame.origin.x - b.frame.origin.x) < 1)
            #expect(abs(a.frame.width - b.frame.width) < 1)
        }
    }

    @Test("The selection block rect follows the warp (rises above the straight one)")
    func warpBlockRectFollowsCurve() throws {
        let straight = makeDocument()
        let arched = makeDocument { $0.textWarp = TextWarp(shape: .arc, amount: 0.3) }
        // captionBlockRect is normalized top-left; a taller box under warp means
        // a smaller top-y and/or larger height than the straight one.
        let flat = try #require(CaptionRenderer.captionBlockRect(document: straight, at: 0.6))
        let bent = try #require(CaptionRenderer.captionBlockRect(document: arched, at: 0.6))
        #expect(bent.height > flat.height) // the arc adds vertical span the box must cover
    }

    @Test("Per-word hit rects follow the warp")
    func warpWordRectsFollowCurve() throws {
        let straight = makeDocument()
        let arched = makeDocument { $0.textWarp = TextWarp(shape: .arc, amount: 0.3) }
        let flat = try #require(CaptionRenderer.wordRects(document: straight, at: 0.6))
        let bent = try #require(CaptionRenderer.wordRects(document: arched, at: 0.6))
        // At least one word's rect moves off its straight position once bent.
        let moved = zip(flat.rects, bent.rects).contains { abs($0.rect.minY - $1.rect.minY) > 0.005 }
        #expect(moved)
    }

    @Test("A background under a warp covers the bent text")
    func warpBackgroundCovers() throws {
        // With a block background + a strong arc, the pill must grow to cover the
        // lifted glyphs — so the render differs from the same doc unwarped.
        let flat = makeDocument { $0.background = BackgroundStyle(mode: .block) }
        let bent = makeDocument {
            $0.background = BackgroundStyle(mode: .block)
            $0.textWarp = TextWarp(shape: .arc, amount: 0.3)
        }
        let a = try #require(CaptionRenderer.renderOverlay(document: flat, at: 0.6))
        let b = try #require(CaptionRenderer.renderOverlay(document: bent, at: 0.6))
        #expect(opaqueVerticalExtent(b) > opaqueVerticalExtent(a))
    }

    @Test("Wave and arc are different curves")
    func waveDiffersFromArc() throws {
        let arc = makeDocument { $0.textWarp = TextWarp(shape: .arc, amount: 0.25) }
        let wave = makeDocument { $0.textWarp = TextWarp(shape: .wave, amount: 0.25, waves: 2) }
        let a = try #require(CaptionRenderer.renderOverlay(document: arc, at: 0.6))
        let b = try #require(CaptionRenderer.renderOverlay(document: wave, at: 0.6))
        #expect(rawPixels(a) != rawPixels(b))
    }

    @Test("Extrude and glow now render under a warp")
    func warpExtrudeAndGlow() throws {
        let plain = makeDocument { $0.textWarp = TextWarp(shape: .arc, amount: 0.2) }
        let extruded = makeDocument {
            $0.textWarp = TextWarp(shape: .arc, amount: 0.2)
            $0.extrude = ExtrudeStyle(color: .init(red: 0.3, green: 0.2, blue: 0), depth: 20, angle: -45, fade: nil)
        }
        let glowed = makeDocument {
            $0.textWarp = TextWarp(shape: .arc, amount: 0.2)
            $0.glow = GlowStyle(color: .white, radius: 22, intensity: 1, scope: .allWords)
        }
        let base = try #require(CaptionRenderer.renderOverlay(document: plain, at: 0.6))
        let withExtrude = try #require(CaptionRenderer.renderOverlay(document: extruded, at: 0.6))
        let withGlow = try #require(CaptionRenderer.renderOverlay(document: glowed, at: 0.6))
        #expect(opaqueCount(withExtrude) > opaqueCount(base)) // depth adds ink under warp
        #expect(opaqueCount(withGlow) > opaqueCount(base))    // glow blooms under warp
    }

    @Test("A warped background pill bends with the curve (not a flat rect)")
    func warpBentPill() throws {
        // The bent pill traces the arc, so its ink spreads more vertically than
        // a straight block pill behind the same (unwarped) words.
        let straightPill = makeDocument { $0.background = BackgroundStyle(mode: .block) }
        let bentPill = makeDocument {
            $0.background = BackgroundStyle(mode: .block)
            $0.textWarp = TextWarp(shape: .arc, amount: 0.35)
        }
        let a = try #require(CaptionRenderer.renderOverlay(document: straightPill, at: 0.6))
        let b = try #require(CaptionRenderer.renderOverlay(document: bentPill, at: 0.6))
        #expect(opaqueVerticalExtent(b) > opaqueVerticalExtent(a))
        #expect(rawPixels(a) != rawPixels(b))
    }

    @Test("A warped title still takes a gradient fill and an outline")
    func warpWithGradientAndStroke() throws {
        let doc = makeDocument {
            $0.textWarp = TextWarp(shape: .arc, amount: 0.25)
            $0.textGradient = GradientFill(colors: [.init(red: 0.2, green: 0.6, blue: 0.9),
                                                    .init(red: 0.9, green: 0.7, blue: 0.2)], angle: 0)
            $0.strokeLayers = [StrokeLayer(color: .white, width: 10)]
        }
        let a = try #require(CaptionRenderer.renderOverlay(document: doc, at: 0.6))
        let b = try #require(CaptionRenderer.renderOverlay(document: doc, at: 0.6))
        #expect(rawPixels(a) == rawPixels(b)) // deterministic
        #expect(opaqueCount(a) > 0)
    }
}
