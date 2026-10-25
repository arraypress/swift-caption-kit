//
//  StickerTests.swift
//  CaptionKitTests
//
//  Created by David Sherlock on 2026.
//
//  Stickers verified without looking: the model's JSON, timing from a word,
//  the restraint rules, placement clear of faces, captions and the hook,
//  shrinking and then refusing, and the pixels — an emoji, a transparent
//  PNG, the frames of a GIF and of a video with alpha — actually drawn.

@preconcurrency import AVFoundation
import CoreGraphics
import Foundation
import Legibility
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import CaptionKit

private let canvas = RenderConfig(width: 360, height: 640)

private func words(_ texts: [String], from start: Double = 0.2, step: Double = 0.4) -> [Word] {
    texts.enumerated().map { Word(text: $1, start: start + Double($0) * step, end: start + Double($0) * step + 0.3) }
}

private func document(_ texts: [String], style: CaptionStyle = CaptionStyle()) -> CaptionDocument {
    CaptionDocument(cards: CaptionGrouper.group(words(texts)), style: style, renderConfig: canvas)
}

private func folder() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("stickers-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

/// A `width`×`height` RGBA picture drawn by `paint`, written as `type`.
private func picture(width: Int, height: Int, paint: (CGContext) -> Void) -> CGImage {
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    paint(context)
    return context.makeImage()!
}

private func write(_ images: [CGImage], delay: Double, as type: UTType, to url: URL) throws {
    let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, images.count, nil))
    for image in images {
        let properties: [CFString: Any] = type == .gif
            ? [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]]
            : [:]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
    }
    #expect(CGImageDestinationFinalize(destination))
}

private func solid(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> CGImage {
    picture(width: 64, height: 64) { context in
        context.setFillColor(CGColor(srgbRed: red, green: green, blue: blue, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
    }
}

/// The RGBA at normalized top-left point `point` of `image`.
private func pixel(_ image: CGImage, at point: CGPoint) -> [UInt8] {
    let bytes = Pixels.rgba(of: image)!
    let x = min(image.width - 1, Int(point.x * CGFloat(image.width)))
    let y = min(image.height - 1, Int(point.y * CGFloat(image.height)))
    let offset = (y * image.width + x) * 4
    return Array(bytes[offset..<offset + 4])
}

@Suite struct StickerTests {

    // MARK: Model

    @Test func requestsAndPlacementsRoundTripAsJSON() throws {
        let request = StickerRequest(name: "fire", source: .emoji("🔥"), timing: .word("money", occurrence: 2, duration: 1.5),
                                     size: 0.2, entrance: .bounce, loop: .spin, anchor: .upperRight)
        let data = try JSONEncoder().encode(request)
        #expect(try JSONDecoder().decode(StickerRequest.self, from: data) == request)
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains(#""emoji":"🔥""#) && text.contains(#""anchor":"upper-right""#) && text.contains(#""word":"money""#))

        let span = try JSONDecoder().decode(StickerTiming.self, from: Data(#"{"start":1,"end":2.5}"#.utf8))
        #expect(span == .span(start: 1, end: 2.5))
        let file = try JSONDecoder().decode(StickerSource.self, from: Data(#"{"animated":"file:///tmp/a.gif"}"#.utf8))
        #expect(file == .animated(URL(string: "file:///tmp/a.gif")!))
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(StickerSource.self, from: Data("{}".utf8)) }
    }

    @Test func placedStickersHaveTheirOwnKeyAndTheLegacyKeySurvives() throws {
        let legacy = Data(#"{"cards":[],"stickers":[{"id":"A1","emoji":"🔥","start":1.0,"end":2.0}]}"#.utf8)
        var document = try CaptionDocument.deserialize(from: legacy)
        #expect(document.placedStickers == nil)
        document.placedStickers = [PlacedSticker(name: "a", source: .emoji("✨"), start: 1, end: 2,
                                                 rect: CGRect(x: 0.1, y: 0.2, width: 0.2, height: 0.1), size: 0.2)]
        let saved = try document.serialized()
        let object = try #require(JSONSerialization.jsonObject(with: saved) as? [String: Any])
        #expect((object["stickers"] as? [[String: Any]])?.first?["id"] as? String == "A1")
        #expect((object["placedStickers"] as? [Any])?.count == 1)
        #expect(try CaptionDocument.deserialize(from: saved).placedStickers == document.placedStickers)
    }

    // MARK: Timing

    @Test func aWordTimesTheStickerAndAMissingOneIsRefused() throws {
        let said = words(["free", "money", "is", "money", "Money!"])
        let second = try StickerPlacer.timeSpan(of: StickerRequest(source: .emoji("💰"), timing: .word("money", occurrence: 2)),
                                                name: "cash", words: said)
        #expect(second.start == said[3].start && abs(second.end - (said[3].start + StickerRules.defaultHold)) < 1e-9)
        let third = try StickerPlacer.timeSpan(of: StickerRequest(source: .emoji("💰"), timing: .word("MONEY", occurrence: 3, duration: 0.5)),
                                               name: "cash", words: said)
        #expect(third.start == said[4].start && abs(third.end - third.start - 0.5) < 1e-9)
        #expect(throws: StickerError.wordNotFound(sticker: "cash", word: "gold")) {
            try StickerPlacer.timeSpan(of: StickerRequest(source: .emoji("💰"), timing: .word("gold")), name: "cash", words: said)
        }
        #expect(throws: StickerError.occurrenceMissing(sticker: "cash", word: "money", occurrence: 4, found: 3)) {
            try StickerPlacer.timeSpan(of: StickerRequest(source: .emoji("💰"), timing: .word("money", occurrence: 4)),
                                       name: "cash", words: said)
        }
        #expect(throws: StickerError.badSpan(sticker: "cash", start: 2, end: 1)) {
            try StickerPlacer.timeSpan(of: StickerRequest(source: .emoji("💰"), timing: .span(start: 2, end: 1)),
                                       name: "cash", words: said)
        }
    }

    // MARK: Restraint

    @Test func stickersKeepTheirDistanceUnlessTheRulesSayOtherwise() async throws {
        let base = document(["one", "two"])
        let first = StickerRequest(name: "a", source: .emoji("🔥"), timing: .span(start: 0, end: 1))
        let soon = StickerRequest(name: "b", source: .emoji("✨"), timing: .span(start: 2, end: 3))
        let together = StickerRequest(name: "c", source: .emoji("✨"), timing: .span(start: 0.5, end: 1.5))

        await #expect(throws: StickerError.self) { try await StickerPlacer.place([first, soon], in: base) }
        do {
            _ = try await StickerPlacer.place([first, soon], in: base)
        } catch let error as StickerError {
            #expect(error.errorDescription?.contains("1.00 s after") == true)
        } catch { Issue.record("\(error)") }
        await #expect(throws: StickerError.self) { try await StickerPlacer.place([first, together], in: base) }

        let relaxed = try await StickerPlacer.place([first, soon], in: base, rules: StickerRules(maxOnScreen: 1, minimumGap: 0.5))
        #expect(relaxed.map(\.name) == ["a", "b"])
        // Two on screen at once when allowed — and never on top of each other.
        let pair = try await StickerPlacer.place([first, together], in: base, rules: StickerRules(maxOnScreen: 2, minimumGap: 0))
        #expect(pair.count == 2 && !pair[0].rect.intersects(pair[1].rect))
    }

    // MARK: Placement

    @Test func placementClearsTheCaptionsAndTheHookInsideTheSafeZone() async throws {
        var base = document(["this", "is", "free", "money", "for", "you"])
        base.hook = HookTitle(text: "Free money", start: 0, end: 3, style: HookTemplates.style(of: HookTemplates.all[0]),
                              safeRect: CGRect(x: 0.05, y: 0.1, width: 0.9, height: 0.78))
        let placed = try await StickerPlacer.place(
            [StickerRequest(name: "cash", source: .emoji("💰"), timing: .word("money")),
             StickerRequest(name: "top", source: .emoji("⭐️"), timing: .span(start: 5, end: 6), anchor: .top)],
            in: base, platform: .tiktok)
        base.placedStickers = placed
        let safe = PlatformZones.safeRect(for: .tiktok)
        for sticker in placed {
            #expect(safe.insetBy(dx: -0.001, dy: -0.001).contains(sticker.rect))
        }
        let reports = await StickerCheck.measure(base, platform: .tiktok)
        #expect(reports.count == 2)
        for report in reports {
            #expect(report.ok, "\(report)")
            #expect(report.captionOverlap == 0 && report.hookOverlap == 0 && report.drawn > 0.1)
        }
        // The anchor is honoured: the `top` sticker sits in the upper part.
        #expect(placed[1].rect.midY < 0.35)
    }

    @Test(.timeLimit(.minutes(3))) func placementKeepsOffAFace() async throws {
        let video = try await portraitVideo()
        var base = CaptionDocument(videoURL: video, cards: [], renderConfig: canvas)
        base.cards = CaptionGrouper.group(words(["look", "at", "this"]))
        let frames = await CanvasFrames.frames(for: base, at: [0.5])
        let faces = await CanvasFrames.faces(in: frames.map(\.image)).joined()
        #expect(!faces.isEmpty, "the generated portrait has a face Vision finds")
        // Anchored on the centre, where the face is: the rules move it off.
        let placed = try await StickerPlacer.place(
            [StickerRequest(name: "wow", source: .emoji("😮"), timing: .span(start: 0.2, end: 1.2), size: 0.2, anchor: .center)],
            in: base)
        base.placedStickers = placed
        let report = try #require(await StickerCheck.measure(base).first)
        #expect(report.faces > 0 && report.faceOverlap == 0 && report.captionOverlap == 0 && report.drawn > 0, "\(report)")
        for face in faces { #expect(!face.intersects(placed[0].rect)) }
    }

    @Test func aStickerShrinksToFitThenIsRefused() async throws {
        let base = document(["one"])
        // Wider than the TikTok safe zone at full size; fits a step down.
        let shrunk = try await StickerPlacer.place([StickerRequest(name: "big", source: .emoji("🔥"), timing: .span(start: 0, end: 1),
                                                                    size: 0.95)], in: base, platform: .tiktok)
        #expect(shrunk[0].size < 0.95 && shrunk[0].size >= 0.95 * 0.55)

        // A picture ten times taller than wide fits nowhere at any size.
        let folder = try folder()
        let tall = folder.appendingPathComponent("tall.png")
        try write([picture(width: 20, height: 200) { $0.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)); $0.fill(CGRect(x: 0, y: 0, width: 20, height: 200)) }],
                  delay: 0, as: .png, to: tall)
        do {
            _ = try await StickerPlacer.place([StickerRequest(name: "pole", source: .file(tall), timing: .span(start: 0, end: 1),
                                                              size: 0.5)], in: base)
            Issue.record("a sticker that fits nowhere was placed")
        } catch let error as StickerError {
            guard case .noRoom(let name, let blockedBy) = error else { Issue.record("\(error)"); return }
            #expect(name == "pole" && blockedBy.first?.contains("safe zone") == true)
        } catch { Issue.record("\(error)") }

        // Captions filling the frame block every spot; the error says so.
        var crowded = CaptionStyle()
        crowded.fontSize = 400
        crowded.position = NormalizedPoint(x: 0.5, y: 0.5)
        var full = CaptionDocument(cards: CaptionGrouper.group(words(["WWW", "MMM", "WWW", "MMM"], step: 0.1),
                                                               rules: GroupingRules(maxLinesPerCard: 4, maxWordsPerLine: 1)),
                                   style: crowded, renderConfig: canvas)
        full.style.maxWidthFraction = 1
        do {
            _ = try await StickerPlacer.place([StickerRequest(name: "crowd", source: .emoji("🔥"), timing: .span(start: 0.2, end: 0.6),
                                                              size: 0.6)], in: full)
            Issue.record("placed under captions that fill the frame")
        } catch let error as StickerError {
            guard case .noRoom(_, let blockedBy) = error else { Issue.record("\(error)"); return }
            #expect(blockedBy.contains("the captions"), "\(blockedBy)")
        } catch { Issue.record("\(error)") }
    }

    @Test func spotsOffThePersonComeFirstAndTheHeadIsKeptClear() throws {
        // A mask: the left half is the person.
        let mask = picture(width: 100, height: 160) { context in
            context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: 50, height: 160))
        }
        let grid = try #require(PersonGrid(masks: [mask]))
        #expect(abs(grid.coverage(of: CGRect(x: 0, y: 0, width: 0.5, height: 1)) - 1) < 0.02)
        #expect(grid.coverage(of: CGRect(x: 0.5, y: 0, width: 0.5, height: 1)) < 0.02)
        let safe = CGRect(x: 0.05, y: 0.1, width: 0.9, height: 0.8)
        let first = try #require(StickerPlacer.candidates(size: CGSize(width: 0.2, height: 0.1), safe: safe, anchor: nil,
                                                          person: grid).first)
        #expect(first.x - 0.1 >= 0.5 - 0.02, "the first spot tried is off the person: \(first)")
        // A face box grows into a head: up into the hair, out to the ears.
        let head = StickerPlacer.head(of: CGRect(x: 0.4, y: 0.3, width: 0.2, height: 0.2))
        #expect(abs(head.minY - 0.18) < 1e-9 && abs(head.minX - 0.37) < 1e-9 && abs(head.maxY - 0.5) < 1e-9)
    }

    // MARK: Drawing

    @Test func anEmojiIsDrawnWhereItWasPlaced() throws {
        var base = document(["hello"])
        let rect = CGRect(x: 0.6, y: 0.2, width: 0.2, height: 0.1125)
        base.placedStickers = [PlacedSticker(name: "a", source: .emoji("🔴"), start: 0, end: 2, rect: rect, size: 0.2, entrance: .none)]
        let overlay = try #require(CaptionRenderer.renderOverlay(document: base, at: 1))
        #expect(pixel(overlay, at: CGPoint(x: rect.midX, y: rect.midY))[3] > 200)
        #expect(pixel(overlay, at: CGPoint(x: 0.2, y: 0.2))[3] == 0)
        #expect(StickerCheck.changedShare(of: base.placedStickers![0], in: base, at: 1) > 0.3)
        // Off its span, nothing.
        #expect(StickerCheck.changedShare(of: base.placedStickers![0], in: base, at: 2.5) == 0)
        // And a disabled sticker track draws none.
        var off = base
        off.disabledTracks = [.stickers]
        #expect(StickerCheck.changedShare(of: base.placedStickers![0], in: off, at: 1) == 0)
    }

    @Test func noStickersDrawsTheSameAsBefore() throws {
        // Warm the caches: a card's very first render takes its shadow by a
        // different route (see BehindSubjectTests), so compare like with
        // like. Under load another suite could evict the shadow between the
        // draws (4 failures in about 90 runs, five suites at once); an
        // empty sticker list that really changed the drawing would differ on
        // every attempt.
        let base = document(["same", "pixels", "please"])
        let agreed = try agreesOnSomeAttempt {
            var document = base
            _ = CaptionRenderer.renderOverlay(document: document, at: 0.7)
            let before = try #require(CaptionRenderer.renderOverlay(document: document, at: 0.7))
            document.placedStickers = []
            let after = try #require(CaptionRenderer.renderOverlay(document: document, at: 0.7))
            return Pixels.rgba(of: before) == Pixels.rgba(of: after)
        }
        #expect(agreed)
    }

    @Test func aTransparentPNGKeepsItsTransparency() throws {
        let folder = try folder()
        let url = folder.appendingPathComponent("half.png")
        // Left half opaque green, right half clear.
        try write([picture(width: 100, height: 100) { context in
            context.setFillColor(CGColor(srgbRed: 0, green: 1, blue: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: 50, height: 100))
        }], delay: 0, as: .png, to: url)
        #expect(StickerSource.file(url) == .image(url))
        var base = document(["x"])
        let rect = CGRect(x: 0.2, y: 0.3, width: 0.4, height: 0.225)
        base.placedStickers = [PlacedSticker(name: "p", source: .file(url), start: 0, end: 2, rect: rect, size: 0.4, entrance: .none)]
        let overlay = try #require(CaptionRenderer.renderOverlay(document: base, at: 1))
        let left = pixel(overlay, at: CGPoint(x: rect.minX + rect.width * 0.25, y: rect.midY))
        let right = pixel(overlay, at: CGPoint(x: rect.minX + rect.width * 0.75, y: rect.midY))
        #expect(left[1] > 200 && left[3] > 200, "\(left)")
        #expect(right[3] == 0, "\(right)")
    }

    @Test func anAnimatedGIFChangesFrameWithTimeAndLoops() throws {
        let folder = try folder()
        let url = folder.appendingPathComponent("rgb.gif")
        try write([solid(1, 0, 0), solid(0, 1, 0), solid(0, 0, 1)], delay: 0.1, as: .gif, to: url)
        #expect(StickerMedia.isAnimated(url))
        #expect(StickerSource.file(url) == .animated(url))
        let media = try #require(StickerMedia.frames(for: .animated(url)))
        #expect(media.frames.count == 3 && abs(media.duration - 0.3) < 0.011)

        var base = document(["x"])
        let rect = CGRect(x: 0.3, y: 0.3, width: 0.3, height: 0.16875)
        base.placedStickers = [PlacedSticker(name: "g", source: .animated(url), start: 1, end: 3, rect: rect, size: 0.3, entrance: .none)]
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let colours = try [1.05, 1.15, 1.25, 1.35].map { time -> [UInt8] in
            pixel(try #require(CaptionRenderer.renderOverlay(document: base, at: time)), at: center)
        }
        #expect(colours[0][0] > 200 && colours[0][1] < 60, "red first: \(colours[0])")
        #expect(colours[1][1] > 200 && colours[1][0] < 60, "then green: \(colours[1])")
        #expect(colours[2][2] > 200 && colours[2][1] < 60, "then blue: \(colours[2])")
        #expect(colours[3] == colours[0], "and round again")
    }

    @Test(.timeLimit(.minutes(3))) func aVideoStickerKeepsItsAlpha() async throws {
        let url = try await alphaVideo()
        let media = try #require(await StickerMedia.prepare(.animated(url)))
        #expect(media.frames.count >= 5)
        let first = try #require(media.frames.first)
        #expect(pixel(first, at: CGPoint(x: 0.05, y: 0.05))[3] < 10, "the corner is clear")
        #expect(pixel(first, at: CGPoint(x: 0.5, y: 0.5))[3] > 240, "the middle is opaque")
        #expect(StickerMedia.frames(for: .animated(url)) === media, "decoded once, then cached")
    }

    // MARK: Motion

    @Test func entrancesSettleAndLoopsMove() {
        let pop = PlacedSticker(name: "p", source: .emoji("🔥"), start: 1, end: 3, rect: .zero, size: 0.2, entrance: .pop)
        #expect(StickerRenderer.motion(of: pop, at: 1.02, travel: 100).scale < 0.6)
        #expect(StickerRenderer.motion(of: pop, at: 1.5, travel: 100) == StickerMotion())
        let spin = PlacedSticker(name: "s", source: .emoji("🔥"), start: 0, end: 3, rect: .zero, size: 0.2, entrance: .none, loop: .spin)
        let a = StickerRenderer.motion(of: spin, at: 1.0, travel: 100).rotation
        let b = StickerRenderer.motion(of: spin, at: 1.5, travel: 100).rotation
        #expect(abs(abs(b - a) - .pi / 2) < 1e-9)
        let float = PlacedSticker(name: "f", source: .emoji("🔥"), start: 0, end: 3, rect: .zero, size: 0.2, entrance: .none, loop: .float)
        #expect(StickerRenderer.motion(of: float, at: 0.5, travel: 100).dy != 0)
        // Deterministic: the same instant, the same motion.
        #expect(StickerRenderer.motion(of: float, at: 0.77, travel: 100) == StickerRenderer.motion(of: float, at: 0.77, travel: 100))
    }

    // MARK: Fixtures

    /// 0.5 s of ProRes 4444: a clear frame with an opaque square that moves.
    private func alphaVideo() async throws -> URL {
        try await writeVideo(width: 128, height: 128, frames: 15, alpha: true) { context, index in
            context.clear(CGRect(x: 0, y: 0, width: 128, height: 128))
            context.setFillColor(CGColor(srgbRed: 1, green: 0.5, blue: 0, alpha: 1))
            context.fill(CGRect(x: 34 + index % 3, y: 34, width: 60, height: 60))
        }
    }
}
