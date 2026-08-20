//
//  EditingTests.swift
//  CaptionKitLiteTests
//
//  Created by David Sherlock on 2026.
//

import CoreGraphics
import Foundation
import Testing
@testable import CaptionKitLite

@Suite("Card resize clamps to neighbors")
struct CardResizeTests {

    private func document() -> CaptionDocument {
        let cards = [
            CaptionCard(words: [Word(text: "one", start: 0, end: 1)], start: 0, end: 1),
            CaptionCard(words: [Word(text: "two", start: 2, end: 3)], start: 2, end: 3),
            CaptionCard(words: [Word(text: "three", start: 4, end: 5)], start: 4, end: 5),
        ]
        return CaptionDocument(cards: cards, style: CaptionStyle(), renderConfig: RenderConfig(width: 540, height: 960))
    }

    @Test("Stretching an end edge stops at the next card's start")
    func endClampsToNext() {
        var doc = document()
        doc.resizeCard(id: doc.cards[0].id, newEnd: 2.9)
        #expect(doc.cards[0].end == 2)          // clamped at card two's start
        #expect(doc.cards[1].start == 2)        // the neighbor is untouched
    }

    @Test("Stretching a start edge stops at the previous card's end")
    func startClampsToPrevious() {
        var doc = document()
        doc.resizeCard(id: doc.cards[1].id, newStart: 0.4)
        #expect(doc.cards[1].start == 1)        // clamped at card one's end
        #expect(doc.cards[0].end == 1)
    }

    @Test("Edges without a neighbor resize freely, keeping minimum duration")
    func freeEdges() {
        var doc = document()
        doc.resizeCard(id: doc.cards[2].id, newEnd: 9)
        #expect(doc.cards[2].end == 9)
        doc.resizeCard(id: doc.cards[0].id, newStart: -5)
        #expect(doc.cards[0].start == 0)        // floors at zero
        doc.resizeCard(id: doc.cards[0].id, newEnd: 0.05)
        #expect(doc.cards[0].end == 0.2)        // minimum duration holds
    }
}

@Suite("Time map")
struct TimeMapTests {

    @Test("Output→source mapping skips cut ranges")
    func outputToSource() {
        let map = TimeMap(cuts: [Cut(start: 1, end: 2), Cut(start: 5, end: 6)])
        #expect(map.sourceTime(forOutput: 0.5) == 0.5)
        #expect(map.sourceTime(forOutput: 1.5) == 2.5)
        #expect(map.sourceTime(forOutput: 4.2) == 6.2)
    }

    @Test("Source→output mapping collapses cuts")
    func sourceToOutput() {
        let map = TimeMap(cuts: [Cut(start: 1, end: 2), Cut(start: 5, end: 6)])
        #expect(map.outputTime(forSource: 0.5) == 0.5)
        #expect(map.outputTime(forSource: 2.5) == 1.5)
        #expect(map.outputTime(forSource: 1.5) == 1.0) // inside cut → cut point
        #expect(map.outputTime(forSource: 6.2) == 4.2)
    }

    @Test("Round trip through kept material is identity")
    func roundTrip() {
        let map = TimeMap(cuts: [Cut(start: 3, end: 4.5), Cut(start: 10, end: 11)])
        for output in stride(from: 0.0, to: 20.0, by: 0.7) {
            let source = map.sourceTime(forOutput: output)
            #expect(abs(map.outputTime(forSource: source) - output) < 1e-9)
        }
    }

    @Test("Overlapping cuts merge; kept ranges cover the remainder")
    func normalization() {
        let map = TimeMap(cuts: [Cut(start: 2, end: 4), Cut(start: 3, end: 5), Cut(start: 8, end: 8)])
        #expect(map.cuts == [Cut(start: 2, end: 5)])
        #expect(map.keptRanges(sourceDuration: 10) == [Cut(start: 0, end: 2), Cut(start: 5, end: 10)])
        #expect(map.removedDuration == 3)
    }
}

@Suite("Filler cutting")
struct FillerCutterTests {

    @Test("Removes transcribed fillers and proposes padded cuts")
    func fillers() {
        let words = [
            Word(text: "So", start: 0.0, end: 0.3),
            Word(text: "um,", start: 0.5, end: 0.9),
            Word(text: "this", start: 1.2, end: 1.5),
            Word(text: "Uh", start: 1.8, end: 2.1),
            Word(text: "works", start: 2.4, end: 2.8),
        ]
        let result = FillerCutter.detect(in: words)
        #expect(result.keptWords.map(\.text) == ["So", "this", "works"])
        #expect(result.removedWords.map(\.text) == ["um,", "Uh"])
        #expect(result.cuts.count == 2)
        // Padded around the filler but clamped out of kept words.
        #expect(result.cuts[0].start >= 0.3)
        #expect(result.cuts[0].end <= 1.2)
    }

    @Test("Long silences are cut when enabled, keeping edge padding")
    func silences() {
        let words = [
            Word(text: "before", start: 0.0, end: 0.5),
            Word(text: "after", start: 4.0, end: 4.4),
        ]
        let rules = FillerCutRules(trimSilencesLongerThan: 1.0, silenceKeep: 0.25)
        let result = FillerCutter.detect(in: words, rules: rules)
        #expect(result.keptWords.count == 2)
        #expect(result.cuts == [Cut(start: 0.75, end: 3.75)])
    }

    @Test("Leading and trailing silence trim when duration is known")
    func edgeSilence() {
        let words = [
            Word(text: "hello", start: 1.4, end: 1.8),
            Word(text: "world", start: 1.9, end: 2.3),
        ]
        let rules = FillerCutRules(trimSilencesLongerThan: 1.0, silenceKeep: 0.25)
        let result = FillerCutter.detect(in: words, rules: rules, sourceDuration: 10)
        #expect(result.cuts == [
            Cut(start: 0, end: 1.15),      // lead: start right before "hello"
            Cut(start: 2.55, end: 10),     // tail: nothing after "world"
        ])

        // Without a duration, only the lead is trimmed.
        let withoutDuration = FillerCutter.detect(in: words, rules: rules)
        #expect(withoutDuration.cuts == [Cut(start: 0, end: 1.15)])
    }

    @Test("Real words are never treated as fillers by default")
    func conservativeDefaults() {
        let words = [
            Word(text: "Oh", start: 0, end: 0.2),
            Word(text: "my", start: 0.2, end: 0.4),
            Word(text: "goodness,", start: 0.4, end: 0.8),
        ]
        let result = FillerCutter.detect(in: words)
        #expect(result.removedWords.isEmpty)
        #expect(result.cuts.isEmpty)
    }
}

@Suite("Speaker assignment")
struct SpeakerAssignTests {

    @Test("Words take the most-overlapping turn's speaker")
    func overlap() {
        let words = [
            Word(text: "hi", start: 0.0, end: 0.5),
            Word(text: "there", start: 0.5, end: 1.0),
            Word(text: "hello", start: 3.0, end: 3.5),
            Word(text: "back", start: 3.5, end: 4.0),
        ]
        let turns = [
            SpeakerAssign.Turn(speaker: 0, start: 0, end: 1.2),
            SpeakerAssign.Turn(speaker: 1, start: 2.8, end: 4.2),
        ]
        let assigned = SpeakerAssign.assign(words: words, turns: turns)
        #expect(assigned.map(\.speaker) == [0, 0, 1, 1])
        #expect(SpeakerAssign.speakerCount(turns: turns) == 2)
    }

    @Test("Gap words inherit the nearest turn's speaker")
    func gaps() {
        let words = [Word(text: "um", start: 1.5, end: 1.7)]
        let turns = [
            SpeakerAssign.Turn(speaker: 0, start: 0, end: 1.0),
            SpeakerAssign.Turn(speaker: 1, start: 1.9, end: 3.0),
        ]
        let assigned = SpeakerAssign.assign(words: words, turns: turns)
        #expect(assigned[0].speaker == 1) // 0.2s to turn 1 vs 0.5s to turn 0
    }
}

