//
//  BehindSubjectTests.swift
//  CaptionKitTests
//
//  Created by David Sherlock on 2026.
//
//  Captions behind the speaker, the parts that need no footage: the split
//  draw adds up to the whole one, coverage is the mask's share of a rect,
//  and only cards under the measured limit go behind.

import CoreGraphics
import Foundation
import Testing
@testable import CaptionKit

private func bytes(of image: CGImage) -> [UInt8] {
    var data = [UInt8](repeating: 0, count: image.width * image.height * 4)
    let context = CGContext(data: &data, width: image.width, height: image.height, bitsPerComponent: 8,
                            bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    return data
}

@Suite struct BehindSubjectTests {

    /// Captions, then titles, drawn into one context are the single draw.
    @Test func theTwoPassDrawIsTheOneDraw() throws {
        let words = ["Three", "things", "nobody", "tells", "you"].enumerated().map {
            Word(text: $1, start: Double($0) * 0.3, end: Double($0) * 0.3 + 0.25)
        }
        var document = CaptionDocument(cards: CaptionGrouper.group(words), style: try StylePresets.style(named: "karaoke"),
                                       renderConfig: RenderConfig(width: 360, height: 640))
        document.progressBar = ProgressBarStyle()
        document.videoDuration = 2
        document.hook = HookTitle(text: "Watch this", start: 0, end: 2, style: HookTemplates.style(of: HookTemplates.all[0]))
        // Warm the caches first: a card's very first render takes its shadow
        // by a different route than every later one (an older quirk, kept —
        // changing it changes frames), so compare like with like.
        // The caches are process-wide and other suites render in parallel, so
        // one may evict this card's shadow between the two draws; a pass is
        // the two draws agreeing on one attempt with the cache held still.
        var agreed = false
        var lastWhole: CGImage?
        for _ in 0..<3 where !agreed {
            _ = CaptionRenderer.renderOverlay(document: document, at: 0.9)
            let one = try #require(CaptionRenderer.renderOverlay(document: document, at: 0.9))
            let context = try #require(CaptionRenderer.makeBitmapContext(width: 360, height: 640))
            CaptionRenderer.draw(document: document, in: context, at: 0.9, layers: .captions)
            CaptionRenderer.draw(document: document, in: context, at: 0.9, layers: .titles)
            agreed = bytes(of: try #require(context.makeImage())) == bytes(of: one)
            lastWhole = one
        }
        #expect(agreed)
        let whole = try #require(lastWhole)
        // And each pass draws something the other does not.
        let captions = try #require(CaptionRenderer.renderOverlay(document: document, at: 0.9, layers: .captions))
        #expect(bytes(of: captions) != bytes(of: whole))
    }

    @Test func coverageIsTheMasksShareOfTheRect() throws {
        // Left half white (person), right half black, 100×50.
        let context = CGContext(data: nil, width: 100, height: 50, bitsPerComponent: 8, bytesPerRow: 100,
                                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        context.setFillColor(gray: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 100, height: 50))
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 50, height: 50))
        let mask = try #require(context.makeImage())
        #expect(SubjectMasker.coverage(of: CGRect(x: 0, y: 0, width: 1, height: 1), in: mask) == 0.5)
        #expect(SubjectMasker.coverage(of: CGRect(x: 0, y: 0.2, width: 0.25, height: 0.5), in: mask) == 1)
        #expect(SubjectMasker.coverage(of: CGRect(x: 0.6, y: 0, width: 0.4, height: 1), in: mask) == 0)
        #expect(abs(SubjectMasker.coverage(of: CGRect(x: 0.25, y: 0, width: 0.5, height: 1), in: mask) - 0.5) < 1e-9)
    }

    @Test func onlyCardsUnderTheLimitGoBehind() {
        let a = UUID(), b = UUID(), c = UUID()
        let measured = [
            SubjectCoverage.Card(id: a, words: [0, 0.02, 0]),
            SubjectCoverage.Card(id: b, words: [0, SubjectCoverage.maximumCoverage + 0.01]),
            SubjectCoverage.Card(id: c, words: [SubjectCoverage.maximumCoverage]),
        ]
        #expect(SubjectCoverage.behindCards(measured) == [a, c])
    }

    @Test func onlyTheListedCardIsBehind() {
        let first = CaptionCard(words: [Word(text: "one", start: 0, end: 1)])
        let second = CaptionCard(words: [Word(text: "two", start: 1, end: 2)])
        var document = CaptionDocument(cards: [first, second])
        #expect(!document.captionIsBehindSubject(at: 0.5))
        document.behindSubject = BehindSubject(cards: [second.id])
        #expect(!document.captionIsBehindSubject(at: 0.5))
        #expect(document.captionIsBehindSubject(at: 1.5))
        document.disabledTracks = [.captions]
        #expect(!document.captionIsBehindSubject(at: 1.5))
    }

    @Test func momentsSitInsideTheCard() {
        let card = CaptionCard(words: [Word(text: "hi", start: 2, end: 3)])
        let moments = SubjectCoverage.moments(of: card)
        #expect(moments.count == 3)
        #expect(moments.allSatisfy { $0 > card.start && $0 < card.end })
    }
}
