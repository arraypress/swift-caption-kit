//
//  HookTitleTests.swift
//  CaptionKitTests
//
//  Created by David Sherlock on 2026.
//
//  The hook title, verified without looking: the catalogue checks, the
//  placement geometry, the contrast arithmetic, the safe zones, and the
//  pixels the renderer draws landing where `hookRect` says.

import CoreGraphics
import Foundation
import Testing
@testable import CaptionKit

private func alphaBounds(of image: CGImage) -> CGRect? {
    let width = image.width, height = image.height
    var data = [UInt8](repeating: 0, count: width * height * 4)
    guard let context = CGContext(data: &data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    var minX = width, minY = height, maxX = -1, maxY = -1
    for y in 0..<height {
        for x in 0..<width where data[(y * width + x) * 4 + 3] > 0 {
            minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
        }
    }
    guard maxX >= 0 else { return nil }
    // Memory row 0 is the top of the image.
    return CGRect(x: Double(minX) / Double(width), y: Double(minY) / Double(height),
                  width: Double(maxX - minX + 1) / Double(width), height: Double(maxY - minY + 1) / Double(height))
}

@Suite struct HookTitleTests {

    @Test func templatesHaveNoProblems() {
        #expect(HookTemplates.problems.isEmpty, "\(HookTemplates.problems)")
        #expect(HookTemplates.all.map(\.name) == ["bold", "boxed", "clean"])
        for template in HookTemplates.all {
            #expect(HookTemplates.style(of: template).highlightMode == .none)
        }
    }

    @Test func automaticTextIsTheOpeningSentence() {
        let words = ["Stop", "scrolling.", "This", "is", "free."].enumerated().map {
            Word(text: $1, start: Double($0) * 0.3, end: Double($0) * 0.3 + 0.25)
        }
        #expect(HookText.automatic(from: words) == "Stop scrolling")
        let long = (0..<20).map { Word(text: "word\($0)", start: Double($0) * 0.3, end: Double($0) * 0.3 + 0.25) }
        #expect(HookText.automatic(from: long)?.split(separator: " ").count == HookText.maximumWords)
        let question = [Word(text: "Ready?", start: 0, end: 0.4), Word(text: "Go", start: 0.5, end: 0.8)]
        #expect(HookText.automatic(from: question) == "Ready?")
        // No punctuation (Apple's recogniser often gives none): the first card.
        let bare = ["Stop", "scrolling", "here", "are", "three", "habits"].enumerated().map {
            Word(text: $1, start: Double($0) * 0.3, end: Double($0) * 0.3 + 0.25)
        }
        #expect(HookText.automatic(from: bare, firstCard: CaptionCard(words: Array(bare.prefix(2)))) == "Stop scrolling")
        #expect(HookText.automatic(from: bare) == "Stop scrolling here are three habits")
        #expect(HookText.automatic(from: []) == nil)
    }

    @Test func placementAvoidsObstaclesAndStaysInside() {
        let safe = CGRect(x: 0.05, y: 0.10, width: 0.81, height: 0.70)
        let size = CGSize(width: 0.6, height: 0.1)
        // Clear frame: the preferred height, centred.
        let free = HookPlacement.center(size: size, safe: safe, obstacles: [])
        #expect(free == CGPoint(x: 0.5, y: HookPlacement.preferredCenterY))
        // A face across the upper third pushes it below.
        let face = CGRect(x: 0.3, y: 0.12, width: 0.4, height: 0.3)
        let placed = try! #require(HookPlacement.center(size: size, safe: safe, obstacles: [face]))
        let block = HookPlacement.rect(center: placed, size: size)
        #expect(!block.intersects(face))
        #expect(safe.contains(block))
        // Nothing fits: no centre, and the least-overlapping spot is still inside.
        let wall = CGRect(x: 0, y: 0, width: 1, height: 1)
        #expect(HookPlacement.center(size: size, safe: safe, obstacles: [wall]) == nil)
        let fallback = HookPlacement.leastOverlapping(size: size, safe: safe, obstacles: [wall])
        #expect(safe.contains(HookPlacement.rect(center: fallback, size: size)))
    }

    @Test func overlapIsMeasuredAsAShareOfTheTitle() {
        let block = CGRect(x: 0, y: 0, width: 1, height: 1)
        #expect(HookPlacement.overlapFraction(of: block, with: [CGRect(x: 0, y: 0, width: 0.5, height: 1)]) == 0.5)
        #expect(HookPlacement.overlapFraction(of: block, with: []) == 0)
    }

    @Test func contrastIsWCAGs() {
        #expect(abs(Contrast.ratio(1, 0) - 21) < 1e-9)
        #expect(abs(Contrast.luminance(.white) - 1) < 1e-9)
        // White on a white sky needs a plate; the plate found reaches 4.5:1.
        let alpha = try! #require(Contrast.plateAlpha(text: 1, background: 0.9))
        #expect(alpha > 0 && alpha <= Contrast.maximumPlateAlpha)
        #expect(Contrast.ratio(1, Contrast.composited(background: 0.9, plate: 0, alpha: alpha)) >= Contrast.normalTextMinimum)
        #expect(Contrast.plateAlpha(text: 1, background: 0.05) == 0)
        #expect(Contrast.plateLuminance(forText: 0) == 1)
    }

    @Test func platformZonesClearTheirOwnInterface() {
        for platform in Platform.allCases {
            let safe = PlatformZones.safeRect(for: platform)
            #expect(safe.width > 0.5 && safe.height > 0.5)
            for zone in PlatformZones.zones(for: platform) {
                #expect(safe.intersection(zone.rect).width * safe.intersection(zone.rect).height < 1e-9 || zone.rect.isEmpty,
                        "\(platform) \(zone.label)")
            }
        }
        let all = PlatformZones.safeRectForAll
        #expect(abs(all.minX) < 1e-9 && abs(all.minY - 0.10) < 1e-9 && abs(all.maxX - 0.86) < 1e-9 && abs(all.maxY - 0.80) < 1e-9)
    }

    @Test func theRendererDrawsTheTitleWhereHookRectSaysAndOnlyWhileVisible() {
        let config = RenderConfig(width: 540, height: 960)
        var style = HookTemplates.style(of: HookTemplates.named("boxed")!)
        style.position = NormalizedPoint(x: 0.5, y: 0.3)
        var hook = HookTitle(text: "Three things nobody tells you", start: 0, end: 2, style: style,
                             safeRect: HookBuilder.safeRect(config: config, platform: nil),
                             lineBreaks: HookText.lineBreaks(for: ["Three", "things", "nobody", "tells", "you"]))
        HookBuilder.fitWidth(&hook, within: HookBuilder.usableWidth(hook.safeRect), config: config)
        var document = CaptionDocument(renderConfig: config)
        document.hook = hook

        let rect = try! #require(CaptionRenderer.hookRect(hook, config: config))
        let drawn = try! #require(alphaBounds(of: CaptionRenderer.renderOverlay(document: document, at: 1.5)!))
        // The plate is drawn: its pixels sit inside the measured rect.
        #expect(rect.insetBy(dx: -0.01, dy: -0.01).contains(drawn), "drawn \(drawn) rect \(rect)")
        #expect(drawn.width > rect.width * 0.8)
        #expect(HookBuilder.safeRect(config: config, platform: nil).insetBy(dx: -0.001, dy: -0.001).contains(rect))
        // Gone once its time is up, and absent when the titles track is off.
        #expect(alphaBounds(of: CaptionRenderer.renderOverlay(document: document, at: 2.1)!) == nil)
        document.disabledTracks = [.titles]
        #expect(alphaBounds(of: CaptionRenderer.renderOverlay(document: document, at: 1.5)!) == nil)
    }

    @Test func aDocumentWithAHookRoundTrips() throws {
        var document = CaptionDocument(cards: [CaptionCard(words: [Word(text: "hi", start: 0, end: 1)])])
        document.hook = HookTitle(text: "Watch this", style: CaptionStyle())
        let decoded = try CaptionDocument.deserialize(from: document.serialized())
        #expect(decoded == document)
        #expect(decoded.preserved.isEmpty)
    }

    @Test func safeRectFollowsTheCanvasShape() {
        let vertical = HookBuilder.safeRect(config: .reel, platform: nil)
        #expect(abs(vertical.minX - 0.05) < 1e-9 && abs(vertical.maxX - 0.86) < 1e-9)
        #expect(abs(vertical.minY - 0.10) < 1e-9 && abs(vertical.maxY - 0.80) < 1e-9)
        let wide = HookBuilder.safeRect(config: .landscape, platform: nil)
        #expect(abs(wide.minX - 0.05) < 1e-9 && abs(wide.maxY - 0.92) < 1e-9)
        let tiktok = HookBuilder.safeRect(config: .reel, platform: .tiktok)
        #expect(abs(tiktok.maxY - 0.80) < 1e-9)
    }
}
