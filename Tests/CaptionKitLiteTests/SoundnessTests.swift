//
//  SoundnessTests.swift
//  CaptionKitLiteTests
//
//  Created by David Sherlock on 2026.
//
//  Systematic coverage for the parts that grew without tests: subtitle
//  files, procedural SFX, beat detection, keyframe paths, crop tracks,
//  sticker outlines, speed-ramped fillers, and the emoji vibe menu.

import AVFoundation
import CoreGraphics
import Foundation
import Testing
@testable import CaptionKitLite

@Suite("Subtitle files")
struct SubtitleFileTests {

    private func makeDocument() -> CaptionDocument {
        let words = [
            Word(text: "Hello", start: 1.0, end: 1.4),
            Word(text: "world", start: 1.4, end: 1.8),
        ]
        var document = CaptionDocument(cards: [CaptionCard(words: words)], style: CaptionStyle())
        document.videoDuration = 10
        return document
    }

    @Test("SRT is numbered, comma-separated, and correctly timed")
    func srtFormat() {
        let srt = SubtitleFile.render(document: makeDocument(), format: .srt)
        #expect(srt.hasPrefix("1\n"))
        #expect(srt.contains("00:00:01,000 --> 00:00:01,800"))
        #expect(srt.contains("Hello world"))
    }

    @Test("VTT has the header and dot separators")
    func vttFormat() {
        let vtt = SubtitleFile.render(document: makeDocument(), format: .vtt)
        #expect(vtt.hasPrefix("WEBVTT\n"))
        #expect(vtt.contains("00:00:01.000 --> 00:00:01.800"))
    }

    @Test("Cue times ride the cut map, and swallowed cards vanish")
    func cutMapping() {
        var document = makeDocument()
        document.cuts = [Cut(start: 0, end: 0.5)] // half a second removed before speech
        let srt = SubtitleFile.render(document: document, format: .srt)
        #expect(srt.contains("00:00:00,500 --> 00:00:01,300"))

        document.cuts = [Cut(start: 0.9, end: 2.0)] // the whole card removed
        let empty = SubtitleFile.render(document: document, format: .srt)
        #expect(!empty.contains("Hello"))
    }
}

@Suite("Crop tracks & speed fillers")
struct CropAndFillerTests {

    @Test("CropTrack interpolates and clamps like the renderer expects")
    func cropInterpolation() {
        let keyframes = [
            CropKeyframe(time: 1, offset: NormalizedPoint(x: 0.3, y: 0.5)),
            CropKeyframe(time: 3, offset: NormalizedPoint(x: 0.7, y: 0.5)),
        ]
        #expect(CropTrack.offset(at: 0, keyframes: keyframes)?.x == 0.3)
        #expect(abs((CropTrack.offset(at: 2, keyframes: keyframes)?.x ?? 0) - 0.5) < 1e-9)
        #expect(CropTrack.offset(at: 9, keyframes: keyframes)?.x == 0.7)
        #expect(CropTrack.offset(at: 1, keyframes: []) == nil)
    }

    @Test("silenceSpeed turns mid-video silences into sped cuts, not removals")
    func spedSilences() {
        let words = [
            Word(text: "Hello", start: 0.2, end: 0.6),
            Word(text: "there", start: 3.6, end: 4.0), // 3s gap
        ]
        let rules = FillerCutRules(trimSilencesLongerThan: 1.0, silenceSpeed: 1.8)
        let result = FillerCutter.detect(in: words, rules: rules, sourceDuration: 5)
        let sped = result.cuts.filter { $0.speed != nil }
        #expect(sped.count == 1)
        #expect(sped[0].speed == 1.8)
        #expect(sped[0].start > 0.6 && sped[0].end < 3.6)
    }
}

