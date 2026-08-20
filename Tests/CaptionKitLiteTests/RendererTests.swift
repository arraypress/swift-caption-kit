//
//  RendererTests.swift
//  CaptionKitLiteTests
//
//  Created by David Sherlock on 2026.
//
//  The renderer must be exercisable headless — that's the library-boundary
//  test from the spec: captioned pixels with no UI anywhere.

import CoreGraphics
import Foundation
import Testing
@testable import CaptionKitLite

private func makeDocument(highlightMode: HighlightMode = .karaoke) -> CaptionDocument {
    let words = [
        Word(text: "Hello", start: 0.0, end: 0.4),
        Word(text: "beautiful", start: 0.4, end: 0.9),
        Word(text: "world.", start: 0.9, end: 1.3),
    ]
    var style = CaptionStyle()
    style.highlightMode = highlightMode
    style.background = BackgroundStyle()
    return CaptionDocument(
        cards: CaptionGrouper.group(words),
        style: style,
        renderConfig: RenderConfig(width: 540, height: 960)
    )
}

/// Counts pixels with non-zero alpha in an RGBA image.
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

@Suite("Card shadow cache")
struct CardShadowTests {

    @Test("Shadowed karaoke: same state renders visually identical; shadow draws")
    func shadowedKaraoke() throws {
        var style = CaptionStyle()
        style.highlightMode = .karaoke
        style.activeWordColor = .yellow
        style.shadow = ShadowStyle(color: .black, radius: 12, offsetX: 4, offsetY: 6)
        let doc = CaptionDocument(
            cards: [CaptionCard(words: [
                Word(text: "SHADOW", start: 0, end: 1),
                Word(text: "WORDS", start: 1, end: 2),
            ], start: 0, end: 2)],
            style: style,
            renderConfig: RenderConfig(width: 480, height: 360, framesPerSecond: 30,
                                       safeAreaTop: 0, safeAreaBottom: 0, safeAreaLeft: 0, safeAreaRight: 0)
        )
        // Mid-karaoke: several renders of the identical state — mixed implicit
        // and baked paths depending on cache pressure, all must look the same.
        let renders = try (0..<4).map { _ in try #require(CaptionRenderer.renderOverlay(document: doc, at: 0.5)) }
        let reference = px(renders[0])
        for other in renders.dropFirst() {
            let bytes = px(other)
            var maxDiff = 0
            var bigDiffs = 0
            for i in 0..<min(reference.count, bytes.count) {
                let d = abs(Int(reference[i]) - Int(bytes[i]))
                if d > maxDiff { maxDiff = d }
                if d > 3 { bigDiffs += 1 }
            }
            #expect(maxDiff <= 16, "same-state renders differ too much (peak \(maxDiff))")
            #expect(bigDiffs < reference.count / 200, "same-state renders differ on too many bytes (\(bigDiffs))")
        }

        // The shadow actually draws…
        var plain = doc
        plain.style.shadow = nil
        let noShadow = try #require(CaptionRenderer.renderOverlay(document: plain, at: 0.5))
        #expect(px(renders[0]) != px(noShadow))
        // …and a different karaoke fraction still changes the render.
        let later = try #require(CaptionRenderer.renderOverlay(document: doc, at: 0.8))
        #expect(px(renders[0]) != px(later))
    }

    private func px(_ image: CGImage) -> [UInt8] {
        let w = image.width, h = image.height
        var data = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return [] }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return data
    }
}
