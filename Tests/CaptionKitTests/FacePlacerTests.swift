//
//  FacePlacerTests.swift
//  CaptionKitTests
//
//  Created by David Sherlock on 2026.
//
//  Face placement verified on the drawn captions: below the chin when there
//  is room, above the head when a safe area shuts the space below (the Reels
//  case that put captions on a selfie's mouth), and on the face only when
//  neither side has room — measured, never assumed.

import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import CaptionKit

private let canvas = RenderConfig(width: 360, height: 640)

/// The generated portrait (no real person) in the lower two thirds of a
/// black 360×640 frame, leaving room above the head as well as below it.
private func smallPortraitVideo() async throws -> URL {
    let resource = try #require(Bundle.module.url(forResource: "portrait", withExtension: "jpg", subdirectory: "Resources"))
    let source = try #require(CGImageSourceCreateWithURL(resource as CFURL, nil))
    let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    return try await writeVideo(width: 360, height: 640, frames: 45, alpha: false) { context, _ in
        context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 360, height: 640))
        context.draw(image, in: CGRect(x: 60, y: 0, width: 240, height: 421))   // CG origin is bottom-left
    }
}

private func document(video: URL) -> CaptionDocument {
    let words = ["captions", "that", "stay", "off", "the", "face", "please"].enumerated().map {
        Word(text: $1, start: 0.1 + Double($0) * 0.18, end: 0.25 + Double($0) * 0.18)
    }
    return CaptionDocument(videoURL: video, cards: CaptionGrouper.group(words), renderConfig: canvas)
}

private func inks(_ document: CaptionDocument) -> [CGRect] {
    document.cards.compactMap { InkFit.inkRect(of: $0, in: document) }
}

@Suite(.timeLimit(.minutes(3)))
struct FacePlacerTests {

    @Test func theHeadIsFoundWithChinAndHair() async throws {
        let base = document(video: try await smallPortraitVideo())
        let head = try #require(await FacePlacer.head(in: base, samples: 6))
        #expect(head.frames >= 2)
        // The chin is never above the face box's bottom, nor the top of the
        // head below its top: landmarks and the person mask only extend it.
        #expect(head.chin >= head.face.maxY - 0.001, "\(head)")
        #expect(head.top <= head.face.minY + 0.001, "\(head)")
        #expect(head.face.minY > 0.25, "the portrait sits in the lower two thirds: \(head)")
    }

    @Test func belowTheChinWhenThereIsRoom() async throws {
        var base = document(video: try await smallPortraitVideo())
        let head = try #require(await FacePlacer.head(in: base, samples: 6))
        let placement = try #require(FacePlacer.place(&base, head: head, safe: CGRect(x: 0, y: 0, width: 1, height: 1)))
        #expect(placement.side == .below)
        #expect(placement.faceOverlap == 0, "\(placement)")
        for ink in inks(base) { #expect(ink.minY >= head.chin + FacePlacer.gap - 0.006, "\(ink) vs chin \(head.chin)") }
    }

    @Test func aboveTheHeadWhenTheSafeAreaShutsTheSpaceBelow() async throws {
        var base = document(video: try await smallPortraitVideo())
        let head = try #require(await FacePlacer.head(in: base, samples: 6))
        // A safe area ending just under the chin, as Reels' 35% bottom band
        // does in a selfie: no room below, so the captions go over the head.
        let safe = CGRect(x: 0.06, y: 0.02, width: 0.88, height: head.chin + 0.01 - 0.02)
        base.renderConfig.safeAreaTop = safe.minY
        base.renderConfig.safeAreaBottom = 1 - safe.maxY
        let placement = try #require(FacePlacer.place(&base, head: head, safe: safe))
        #expect(placement.side == .above, "\(placement)")
        #expect(placement.faceOverlap == 0, "\(placement)")
        for ink in inks(base) {
            #expect(ink.maxY <= head.top + 0.006, "\(ink) vs top of head \(head.top)")
            #expect(ink.minY >= safe.minY - 0.006, "\(ink) inside \(safe)")
        }
    }

    @Test func onTheFaceOnlyWhenNeitherSideHasRoomAndSaysSo() async throws {
        var base = document(video: try await smallPortraitVideo())
        let head = try #require(await FacePlacer.head(in: base, samples: 6))
        // A safe area inside the face: nowhere to go but over it.
        let face = head.faceToChin
        let safe = CGRect(x: 0.06, y: face.minY + 0.02, width: 0.88, height: face.height - 0.04)
        base.renderConfig.safeAreaTop = safe.minY
        base.renderConfig.safeAreaBottom = 1 - safe.maxY
        let placement = try #require(FacePlacer.place(&base, head: head, safe: safe))
        #expect(placement.side == .over)
        #expect(placement.faceOverlap > 0, "the overlap is measured and reported, not hidden: \(placement)")
        for ink in inks(base) { #expect(safe.insetBy(dx: -0.006, dy: -0.006).contains(ink), "\(ink) inside \(safe)") }
    }

    @Test func noFaceLeavesTheCaptionsAlone() async throws {
        let video = try await writeVideo(width: 360, height: 640, frames: 30, alpha: false) { context, _ in
            context.setFillColor(CGColor(srgbRed: 0.2, green: 0.4, blue: 0.8, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: 360, height: 640))
        }
        #expect(await FacePlacer.head(in: document(video: video), samples: 6) == nil)
    }
}
