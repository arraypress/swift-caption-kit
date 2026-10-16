//
//  MeasurementTests.swift
//  CaptionKitTests
//
//  Created by David Sherlock on 2026.
//
//  The measurements that stand in for an eye: the settled sample moment,
//  caption contrast, the footage stage and its checks, hidden fillers, the
//  hook that would only repeat the first caption, and the caption offset.
//

import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import Legibility
import Testing
@testable import CaptionKit

private func words(_ text: String, from start: TimeInterval = 0, step: TimeInterval = 0.3) -> [Word] {
    text.split(separator: " ").enumerated().map { index, word in
        Word(text: String(word), start: start + Double(index) * step, end: start + Double(index + 1) * step)
    }
}

/// A `width`×`height` sRGB image filled by `paint`.
private func image(width: Int, height: Int, _ paint: (CGContext) -> Void) -> CGImage {
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    paint(context)
    return context.makeImage()!
}

private func portrait() throws -> CGImage {
    let url = try #require(Bundle.module.url(forResource: "portrait", withExtension: "jpg", subdirectory: "Resources"))
    let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
    return try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
}

@Suite struct SettledMomentTests {

    @Test func waitsForTheLastEntranceToFinish() throws {
        var style = CaptionStyle()
        style.wordAnimation = .popOn
        style.animationDuration = 0.2
        let card = CaptionCard(words: words("one two three", from: 1, step: 0.3))
        let settled = try #require(SettledMoment.settled(card, style: style))
        // The last word starts at 1.6 and takes 0.2 s to arrive.
        #expect(abs(settled - (1.6 + 0.2 + SettledMoment.grace)) < 1e-9)
    }

    @Test func aStaticStyleIsSettledAtOnceAndACardTooShortIsNot() throws {
        let card = CaptionCard(words: words("one two", from: 2))
        #expect(try #require(SettledMoment.settled(card, style: CaptionStyle())) == 2 + SettledMoment.grace)
        var exiting = CaptionStyle()
        exiting.wordAnimation = .popOn
        exiting.exitAnimation = .popOn
        exiting.animationDuration = 0.5
        #expect(SettledMoment.settled(CaptionCard(words: words("one two", from: 0, step: 0.2)), style: exiting) == nil)
    }

    @Test func picksTheBusiestCardAndFollowsTheOffset() {
        var style = CaptionStyle()
        style.wordAnimation = .stomp
        style.animationDuration = 0.14
        var document = CaptionDocument(cards: [
            CaptionCard(words: words("hi", from: 0)),
            CaptionCard(words: words("the busiest card of all", from: 3)),
        ], style: style)
        let moment = SettledMoment.moment(in: document)
        #expect(abs(moment - (3 + 4 * 0.3 + 0.14 + SettledMoment.grace)) < 1e-9)
        // Captions shown 0.1 s early reach the same look 0.1 s sooner.
        document.captionTimingOffset = -0.1
        #expect(abs(SettledMoment.moment(in: document) - (moment - 0.1)) < 1e-9)
    }
}

@Suite struct CaptionOffsetTests {

    @Test func aNegativeOffsetShowsTheFirstCaptionEarly() {
        var document = CaptionDocument(cards: [CaptionCard(words: words("hello there", from: 1))])
        document.captionTimingOffset = -0.25
        #expect(CaptionRenderer.captionBlockRect(document: document, at: 0.8) != nil)
        #expect(CaptionRenderer.captionBlockRect(document: document, at: 0.7) == nil)
        let first = FootageCheck.firstCaption(document, near: 1)
        #expect(first.map { abs($0 - 0.75) < 0.011 } == true)
    }
}

@Suite struct FillerHidingTests {

    @Test func dropsFillersAndKeepsEveryOtherWordsTiming() {
        let spoken = words("so um this uh, works")
        let result = FillerHiding.hidden(spoken)
        #expect(result.kept.map(\.text) == ["so", "this", "works"])
        #expect(result.hidden.map(\.text) == ["um", "uh,"])
        #expect(result.kept[1] == spoken[2])
    }
}

@Suite struct HookRepeatTests {

    @Test func aHookThatOpensTheFirstCaptionRepeatsIt() {
        let card = CaptionCard(words: words("stop scrolling here are three habits"))
        #expect(HookText.repeatsCaption("Stop scrolling here", firstCard: card))
        #expect(HookText.repeatsCaption("stop scrolling here are three habits", firstCard: card))
        // A first sentence that runs past the first card says more than it.
        #expect(!HookText.repeatsCaption("stop scrolling here are three habits that changed me", firstCard: card))
        #expect(!HookText.repeatsCaption("Three habits", firstCard: card))
        #expect(!HookText.repeatsCaption("anything", firstCard: nil))
    }
}

@Suite struct ContrastMeasureTests {

    /// A 60×60 frame: `background`, with a 20×20 block of `text` letters
    /// ringed by a 3-pixel `outline` (or none).
    private func frame(text: CGFloat, background: CGFloat, outline: CGFloat?) -> (CGImage, [Bool]) {
        let picture = image(width: 60, height: 60) { context in
            context.setFillColor(gray: background, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: 60, height: 60))
            if let outline {
                context.setFillColor(gray: outline, alpha: 1)
                context.fill(CGRect(x: 17, y: 17, width: 26, height: 26))
            }
            context.setFillColor(gray: text, alpha: 1)
            context.fill(CGRect(x: 20, y: 20, width: 20, height: 20))
        }
        let letters = (0..<3600).map { index in (20..<40).contains(index % 60) && (20..<40).contains(index / 60) }
        return (picture, letters)
    }

    @Test func whiteOnWhiteIsOneToOneAndAnOutlineLiftsIt() throws {
        let (bare, letters) = frame(text: 1, background: 1, outline: nil)
        let flat = try #require(LetterRing.measure(composite: bare, letters: letters, referenceScale: 1))
        #expect(abs(flat.ratio - 1) < 0.01)
        let (outlined, _) = frame(text: 1, background: 1, outline: 0)
        let ringed = try #require(LetterRing.measure(composite: outlined, letters: letters, referenceScale: 1))
        #expect(ringed.ratio > 20)
        let (dark, _) = frame(text: 1, background: 0, outline: nil)
        #expect(try #require(LetterRing.measure(composite: dark, letters: letters, referenceScale: 1)).ratio > 20)
    }

    @Test func aLowQuartileUnderThreeIsLow() {
        func card(_ ratio: Double) -> CaptionContrast.Card {
            CaptionContrast.Card(time: 0, text: "", ratio: ratio, textLuminance: 1, surroundLuminance: 0)
        }
        #expect(CaptionContrast.Report(cards: [card(1.2), card(2), card(8), card(9)]).isLow)
        #expect(!CaptionContrast.Report(cards: [card(3.2), card(8), card(9), card(12)]).isLow)
        #expect(CaptionContrast.Report(cards: [card(1.2), card(8), card(9)]).below == 1)
    }

    @Test func theScrimDarkensTheEdgeTheCaptionsSitOn() {
        let white = CIImage(color: CIColor(red: 1, green: 1, blue: 1)).cropped(to: CGRect(x: 0, y: 0, width: 100, height: 100))
        let scrim = CaptionContrast.scrimOverlay(color: .black, opacity: 0.85, lower: true)
        let out = CIContext().createCGImage(GradientOverlayFilter(scrim).apply(white), from: white.extent)!
        let rows = Pixels.luminances(of: out)
        // Top-left-first rows: the bottom row (lower captions) is darkest.
        #expect(rows[95 * 100 + 50] < 0.3 && rows[5 * 100 + 50] > 0.8)
    }
}

@Suite struct FootageMeasureTests {

    @Test func theFootageStageMirrorsExactly() throws {
        let picture = try portrait()
        var document = CaptionDocument(renderConfig: RenderConfig(width: 180, height: 320))
        let plain = try #require(FootageStage.compose(picture, document: document, at: 0, width: 180, height: 320))
        document.mirrorHorizontal = true
        #expect(FootageStage.changesFootage(document))
        let mirrored = try #require(FootageStage.compose(picture, document: document, at: 0, width: 180, height: 320))
        let flipped = try #require(FootageCheck.Detail.flipped(plain))
        #expect(try #require(FootageCheck.Detail.meanDifference(mirrored, flipped)) < 0.005)
        #expect(!FootageStage.changesFootage(CaptionDocument()))
    }

    @Test func aBackgroundBlurTakesDetailFromTheBackgroundAndLeavesThePerson() throws {
        let picture = try portrait()
        let width = 360, height = 640
        var document = CaptionDocument(renderConfig: RenderConfig(width: width, height: height))
        let before = try #require(FootageStage.compose(picture, document: document, at: 0, width: width, height: height))
        document.backgroundBlur = 60
        let after = try #require(FootageStage.compose(picture, document: document, at: 0, width: width, height: height))
        let person = try #require(SubjectMasker().mask(of: before).flatMap { FootageCheck.personMask($0, width: width, height: height) })
        let b = FootageCheck.Detail.laplacian(of: before), a = FootageCheck.Detail.laplacian(of: after)
        let background = try #require(FootageCheck.Detail.ratio(a, b, where: person.map { !$0 }))
        let subject = try #require(FootageCheck.Detail.ratio(a, b, where: person))
        #expect(background < 0.8)
        #expect(subject > 0.9)
    }

    @Test func aFaceCoverTakesTheDetailOutOfTheFace() async throws {
        let picture = try portrait()
        let width = 360, height = 640
        var document = CaptionDocument(renderConfig: RenderConfig(width: width, height: height))
        let before = try #require(FootageStage.compose(picture, document: document, at: 0, width: width, height: height))
        let drawn = CIContext().createCGImage(CIImage(cgImage: picture), from: CGRect(x: 0, y: 0, width: picture.width, height: picture.height))!
        let face = try #require(await CanvasFrames.faces(in: [drawn])[0].first)
        document.faceCensor = FaceCensor(mode: .blur, keyframes: [
            FaceRectKeyframe(time: 0, center: NormalizedPoint(x: face.midX, y: face.midY), width: face.width, height: face.height),
        ])
        let after = try #require(FootageStage.compose(picture, document: document, at: 0, width: width, height: height))
        let box = try #require(await CanvasFrames.faces(in: [before])[0].first)
        let mask = FootageCheck.mask(of: CanvasFrames.pixels(box, in: before), width: width, height: height)
        let ratio = try #require(FootageCheck.Detail.ratio(FootageCheck.Detail.laplacian(of: after),
                                                           FootageCheck.Detail.laplacian(of: before), where: mask))
        #expect(ratio < 0.5)
        #expect(await CanvasFrames.faces(in: [after])[0].isEmpty)
    }
}

@Suite struct ReframePanTests {

    @Test func aFaceCentreBecomesTheOffsetThatCentresIt() {
        let source = CGSize(width: 1920, height: 1080), canvas = CGSize(width: 1080, height: 1920)
        // A 9:16 crop shows 0.316 of a 16:9 source's width.
        let visible = (1080.0 / 1920.0) * (1080.0 / 1920.0)
        let pan = FaceTrack.pan(center: NormalizedPoint(x: 0.3, y: 0.4), source: source, canvas: canvas)
        #expect(abs(Double(pan.x) - (0.3 - visible / 2) / (1 - visible)) < 1e-9)
        #expect(pan.y == 0.5, "no vertical overflow, so no vertical pan")
        // Placed with that offset, the face lands in the middle of the canvas.
        let placed = Reframe.placement(source: source, canvas: canvas, offset: pan)
        let faceOnCanvas = placed.origin.x + 0.3 * placed.size.width
        #expect(abs(faceOnCanvas - canvas.width / 2) < 0.5)
        // Near an edge the crop stops at the edge.
        #expect(FaceTrack.pan(center: NormalizedPoint(x: 0.05, y: 0.5), source: source, canvas: canvas).x == 0)
        #expect(FaceTrack.pan(center: NormalizedPoint(x: 0.97, y: 0.5), source: source, canvas: canvas).x == 1)
    }
}
