//
//  GroupingTests.swift
//  CaptionKitTests
//
//  Created by David Sherlock on 2026.
//

import Foundation
import Testing
@testable import CaptionKit

/// Builds an evenly-timed word stream: one word every `step` seconds, each
/// spoken for `spoken` seconds.
private func makeWords(_ texts: [String], step: TimeInterval = 0.4, spoken: TimeInterval = 0.3) -> [Word] {
    texts.enumerated().map { index, text in
        let start = TimeInterval(index) * step
        return Word(text: text, start: start, end: start + spoken)
    }
}

@Suite("Caption grouping")
struct GroupingTests {

    @Test("Breaks cards on sentence boundaries")
    func sentenceBreaks() {
        let words = makeWords(["Hello", "there.", "Welcome", "back"])
        let cards = CaptionGrouper.group(words, rules: GroupingRules())
        #expect(cards.count == 2)
        #expect(cards[0].text == "Hello there.")
        #expect(cards[1].text == "Welcome back")
    }

    @Test("Breaks cards on pauses")
    func pauseBreaks() {
        var words = makeWords(["one", "two"])
        // A long silence, then more speech.
        words.append(Word(text: "three", start: 5.0, end: 5.3))
        words.append(Word(text: "four", start: 5.4, end: 5.7))
        let cards = CaptionGrouper.group(words, rules: GroupingRules(pauseThreshold: 0.6))
        #expect(cards.count == 2)
        #expect(cards[0].text == "one two")
        #expect(cards[1].text == "three four")
    }

    @Test("Respects card capacity and line limits")
    func capacity() {
        let words = makeWords(Array(repeating: "word", count: 20))
        let rules = GroupingRules(maxLinesPerCard: 2, maxWordsPerLine: 4)
        let cards = CaptionGrouper.group(words, rules: rules)
        for card in cards {
            #expect(card.lines.count <= rules.maxLinesPerCard)
            for line in card.lines {
                #expect(line.count <= rules.maxWordsPerLine)
            }
        }
        #expect(cards.flatMap(\.words).count == 20)
    }

    @Test("Respects the character limit per line")
    func characterLimit() {
        let words = makeWords(["extraordinary", "circumstances", "require", "extraordinary", "responses"])
        let rules = GroupingRules(maxLinesPerCard: 2, maxWordsPerLine: 4, maxCharactersPerLine: 16)
        let cards = CaptionGrouper.group(words, rules: rules)
        for card in cards {
            for line in card.lines {
                let text = line.map(\.text).joined(separator: " ")
                // A single word may exceed the limit (never split mid-word);
                // multi-word lines must respect it.
                if line.count > 1 {
                    #expect(text.count <= rules.maxCharactersPerLine)
                }
            }
        }
    }

    @Test("Never orphans a single word on the last line when avoidable")
    func orphanFix() {
        let words = makeWords(["alpha", "beta", "gamma"])
        let rules = GroupingRules(maxLinesPerCard: 2, maxWordsPerLine: 2, maxCharactersPerLine: 20)
        let cards = CaptionGrouper.group(words, rules: rules)
        #expect(cards.count == 1)
        let lines = cards[0].lines
        #expect(lines.count == 2)
        // Greedy would produce [alpha beta][gamma]; the orphan fix rebalances.
        #expect(lines[0].count == 1)
        #expect(lines[1].count == 2)
    }

    @Test("Cards get a readable dwell time and never overlap")
    func dwell() {
        var words = makeWords(["quick."])
        words.append(Word(text: "Next", start: 4.0, end: 4.3))
        let rules = GroupingRules(minCardDuration: 0.9, maxHoldAfterLastWord: 0.5)
        let cards = CaptionGrouper.group(words, rules: rules)
        #expect(cards.count == 2)
        #expect(cards[0].duration >= rules.minCardDuration)
        #expect(cards[0].end <= cards[1].start)
    }

    @Test("Empty input produces no cards")
    func empty() {
        #expect(CaptionGrouper.group([], rules: GroupingRules()).isEmpty)
    }

    @Test("Line breaks reflow after a rules change")
    func reflow() {
        let words = makeWords(["one", "two", "three", "four"])
        let cards = CaptionGrouper.group(words, rules: GroupingRules(maxWordsPerLine: 4))
        #expect(cards[0].lines.count == 1)
        let reflowed = CaptionGrouper.reflowLines(of: cards[0], rules: GroupingRules(maxWordsPerLine: 2))
        #expect(reflowed.lines.count == 2)
    }
}

@Suite("Caption model")
struct ModelTests {

    @Test("Document round-trips through JSON")
    func serialization() throws {
        let words = makeWords(["Hello", "world."])
        var document = CaptionDocument(cards: CaptionGrouper.group(words))
        document.style.highlightMode = .karaoke
        document.highlightRules = [HighlightRule(keywords: ["world"], color: .green)]

        let data = try document.serialized()
        let restored = try CaptionDocument.deserialize(from: data)
        #expect(restored == document)
    }

    @Test("Active word tracks time")
    func activeWord() {
        let card = CaptionCard(words: makeWords(["a", "b", "c"]))
        #expect(card.activeWordIndex(at: 0.05) == 0)
        #expect(card.activeWordIndex(at: 0.45) == 1)
        #expect(card.activeWordIndex(at: 2.0) == 2)
    }

    @Test("Highlight rules match case- and punctuation-insensitively")
    func highlightMatching() {
        let rule = HighlightRule(keywords: ["money"], color: .green)
        #expect(rule.matches(Word(text: "Money,", start: 0, end: 1)))
        #expect(rule.matches(Word(text: "MONEY!", start: 0, end: 1)))
        #expect(!rule.matches(Word(text: "moneyball", start: 0, end: 1)))
    }
}
