//
//  AutomaticPassTests.swift
//  CaptionKitTests
//
//  Created by David Sherlock on 2026.
//
//  The passes that run with nobody looking — emphasis, emoji, translation
//  re-timing — checked as data: which words, how many, and when.

import Foundation
import NaturalLanguage
import Testing
@testable import CaptionKit

private func words(_ text: String, from start: TimeInterval = 0, step: TimeInterval = 0.3) -> [Word] {
    text.split(separator: " ").enumerated().map { index, word in
        Word(text: String(word), start: start + Double(index) * step, end: start + Double(index + 1) * step)
    }
}

@Suite struct EmphasisTests {

    @Test func picksTheNumberOrNounThatCarriesTheCard() {
        let cards = [
            CaptionCard(words: words("we made 500 dollars")),
            CaptionCard(words: words("the coffee was cold", from: 2)),
        ]
        let result = EmphasisSuggester.emphasize(cards: cards)
        #expect(result.count == 2)
        #expect(result.cards[0].words[2].style?.color == EmphasisSuggester.defaultPalette[0])   // 500
        #expect(result.cards[1].words[1].style?.color == EmphasisSuggester.defaultPalette[1])   // coffee
        // One word per card, nothing else touched.
        #expect(result.cards.allSatisfy { $0.words.filter { $0.style?.color != nil }.count == 1 })
    }

    @Test func leavesAWordSomebodyColouredAlone() {
        var card = CaptionCard(words: words("we made 500 dollars"))
        card.words[3].style = WordStyle(color: .red)
        let result = EmphasisSuggester.emphasize(cards: [card])
        #expect(result.cards[0].words[3].style?.color == .red)
        #expect(result.cards[0].words[2].style?.color == EmphasisSuggester.defaultPalette[0])
    }

    @Test func aCardOfFunctionWordsGetsNothing() {
        let result = EmphasisSuggester.emphasize(cards: [CaptionCard(words: words("and so it is"))])
        #expect(result.count == 0)
        #expect(result.cards[0].words.allSatisfy { $0.style == nil })
    }

    @Test func isTheSameEveryRun() {
        let cards = (0..<6).map { CaptionCard(words: words("the best camera for travel photos", from: Double($0) * 3)) }
        let first = EmphasisSuggester.emphasize(cards: cards).cards.map { $0.words.map(\.style) }
        let second = EmphasisSuggester.emphasize(cards: cards).cards.map { $0.words.map(\.style) }
        #expect(first == second)
    }

    @Test func clearingTakesTheColourAndItsUnderline() {
        let cards = EmphasisSuggester.emphasize(cards: [CaptionCard(words: words("we made 500 dollars"))], underline: true).cards
        #expect(cards[0].words[2].style?.underline != nil)
        let cleared = EmphasisSuggester.clearEmphasis(cards: cards)
        #expect(cleared[0].words.allSatisfy { $0.style == nil })
    }
}

@Suite struct EmojiTests {

    @Test func catalogueHasNoProblems() {
        #expect(EmojiCatalog.problems.isEmpty, "\(EmojiCatalog.problems)")
        #expect(EmojiCatalog.map.count > 200)
    }

    @Test func catalogueRefusesWhatItShould() {
        let bad = EmojiCatalog.parse(#"[{"emoji": "ab", "words": ["Money", "cash"]}, {"emoji": "💵", "words": ["cash"]}]"#)
        #expect(bad.problems.count == 3)
    }

    @Test func aKeywordGetsItsEmojiInline() {
        let result = EmojiSuggester.suggest(cards: [CaptionCard(words: words("we made so much money today"))])
        #expect(result.count == 1)
        // "money" comes before "today": one per card, the first that matches.
        #expect(result.cards[0].words[4].style?.emoji == "💰")
        #expect(result.cards[0].words[5].style?.emoji == nil)
    }

    @Test func pluralsAreForgivenAndCaseIgnored() {
        #expect(EmojiCatalog.emoji(for: Word(text: "Dollars!", start: 0, end: 1).matchKey) == "💰")
        #expect(EmojiCatalog.emoji(for: "is") == nil)
    }

    @Test func emojiKeepTheirDistance() {
        // A keyword every 1.5 s: with the 4 s gap only every third one lands.
        let cards = (0..<9).map { CaptionCard(words: words("more coffee", from: Double($0) * 1.5)) }
        let result = EmojiSuggester.suggest(cards: cards)
        let times = result.cards.flatMap(\.words).filter { $0.style?.emoji != nil }.map(\.start)
        #expect(result.count == times.count)
        #expect(zip(times, times.dropFirst()).allSatisfy { $1 - $0 >= EmojiSuggester.defaultMinimumGap })
        #expect(result.count == 3)
    }

    @Test func aCensoredWordGetsNone() {
        var card = CaptionCard(words: words("free money"))
        card.words[0].style = WordStyle(censored: true)
        let result = EmojiSuggester.suggest(cards: [card])
        #expect(result.cards[0].words[0].style?.emoji == nil)
        #expect(result.cards[0].words[1].style?.emoji == "💰")
    }
}

@Suite struct TranslationRetimerTests {

    /// The brief's case: a four-word English line becomes a six-word Spanish one.
    @Test func aTranslatedLineKeepsItsSpanWhateverTheWordCount() {
        let line = Word(text: "Así que esto es gratis hoy", start: 0.48, end: 1.26)
        let spread = TranslationRetimer.expanded([line])
        #expect(spread.count == 6)
        #expect(spread.first?.start == 0.48)
        #expect(spread.last?.end == 1.26)
        // Back to back, in order, and each share in proportion to its length.
        #expect(zip(spread, spread.dropFirst()).allSatisfy { abs($0.end - $1.start) < 1e-9 })
        let total = spread.reduce(0.0) { $0 + Double($1.text.count + 1) }
        for word in spread {
            #expect(abs(word.duration - 0.78 * Double(word.text.count + 1) / total) < 1e-9)
        }
    }

    @Test func aPerWordFileIsUntouched() {
        let original = words("so this is free money, don't U.S. e-mail")
        #expect(TranslationRetimer.expanded(original) == original)
    }

    @Test func linesSpreadIndependentlyAndKeepTheirSpeaker() {
        var first = Word(text: "Hola a todos", start: 0, end: 1)
        first.speaker = 2
        let second = Word(text: "bienvenidos", start: 1.5, end: 2)
        let spread = TranslationRetimer.expanded([first, second])
        #expect(spread.map(\.text) == ["Hola", "a", "todos", "bienvenidos"])
        #expect(spread[0..<3].allSatisfy { $0.speaker == 2 && $0.end <= 1 })
        #expect(spread[3] == second)
    }

    @Test func unspacedScriptsAreSegmented() {
        let parts = TranslationRetimer.segments(of: "今日はとても良い天気です")
        #expect(parts.count > 1)
        #expect(parts.joined() == "今日はとても良い天気です")
    }

    @Test func aCardKeepsItsLineCount() {
        let card = CaptionCard(words: words("one two three four five six"), lineBreaks: [3])
        let retimed = TranslationRetimer.retimed(card: card, translatedText: "uno dos tres cuatro cinco seis siete")
        #expect(retimed.words.count == 7)
        #expect(retimed.lineBreaks.count == 1)
        #expect(retimed.id == card.id)
        #expect(retimed.words.first?.start == card.words.first?.start)
        #expect(retimed.words.last?.end == card.words.last?.end)
    }
}
