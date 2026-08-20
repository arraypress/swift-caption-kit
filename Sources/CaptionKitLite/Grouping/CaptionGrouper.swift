//
//  CaptionGrouper.swift
//  CaptionKitLite
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Turns a flat word stream into caption cards: the layout engine.
///
/// The grouper decides *which words appear together* (breaking on sentence
/// ends, pauses, and capacity) and *how they split across lines* (respecting
/// word/character limits, never orphaning a single word on a line when it can
/// be avoided). It also gives every card a readable dwell time.
///
/// ```swift
/// let cards = CaptionGrouper.group(words, rules: GroupingRules())
/// ```
///
/// Re-run ``group(_:rules:)`` after the user changes the limits, or
/// ``reflowLines(of:rules:)`` after they edit a single card's text.
public enum CaptionGrouper {

    // MARK: - Grouping

    /// Groups a word stream into caption cards.
    ///
    /// - Parameters:
    ///   - words: The word stream, in spoken order.
    ///   - rules: The grouping knobs.
    /// - Returns: Cards in chronological order, line breaks assigned, dwell
    ///   times applied.
    public static func group(_ words: [Word], rules: GroupingRules = GroupingRules()) -> [CaptionCard] {
        guard !words.isEmpty else { return [] }

        var cards: [CaptionCard] = []
        var current: [Word] = []

        func flush() {
            guard !current.isEmpty else { return }
            var card = CaptionCard(words: current)
            card.lineBreaks = splitLines(current, rules: rules)
            cards.append(card)
            current = []
        }

        for word in words {
            if let last = current.last {
                let pause = word.start - last.end
                if last.endsSentence
                    || pause >= rules.pauseThreshold
                    || !fits(current + [word], rules: rules) {
                    flush()
                }
            }
            current.append(word)
        }
        flush()

        applyDwell(to: &cards, rules: rules)
        return cards
    }

    /// Recomputes a single card's line breaks (after a text edit or a rules
    /// change) without regrouping the whole document.
    public static func reflowLines(of card: CaptionCard, rules: GroupingRules) -> CaptionCard {
        var updated = card
        updated.lineBreaks = splitLines(card.words, rules: rules)
        return updated
    }

    // MARK: - Line Splitting

    /// Whether the words can be laid out within the card's line capacity.
    private static func fits(_ words: [Word], rules: GroupingRules) -> Bool {
        lineRanges(words, rules: rules).count <= rules.maxLinesPerCard
    }

    /// Splits words into lines and returns the ``CaptionCard/lineBreaks``
    /// representation (start index of each line after the first).
    static func splitLines(_ words: [Word], rules: GroupingRules) -> [Int] {
        var ranges = lineRanges(words, rules: rules)
        fixOrphan(&ranges, words: words, rules: rules)
        return ranges.dropFirst().map(\.lowerBound)
    }

    /// Greedy fill: words go on the current line until adding one would
    /// exceed the word or character limit.
    private static func lineRanges(_ words: [Word], rules: GroupingRules) -> [Range<Int>] {
        var ranges: [Range<Int>] = []
        var lineStart = 0
        var lineChars = 0
        var lineWords = 0

        for (index, word) in words.enumerated() {
            let length = word.text.count
            let joined = lineWords == 0 ? length : lineChars + 1 + length
            if lineWords > 0 && (lineWords + 1 > rules.maxWordsPerLine || joined > rules.maxCharactersPerLine) {
                ranges.append(lineStart..<index)
                lineStart = index
                lineChars = length
                lineWords = 1
            } else {
                lineChars = joined
                lineWords += 1
            }
        }
        if lineStart < words.count {
            ranges.append(lineStart..<words.count)
        }
        return ranges
    }

    /// If the last line holds a single word and the previous line can spare
    /// one, move the previous line's last word down so no line shows a lone
    /// orphan word.
    private static func fixOrphan(_ ranges: inout [Range<Int>], words: [Word], rules: GroupingRules) {
        guard ranges.count >= 2,
              let last = ranges.last, last.count == 1,
              let previous = ranges.dropLast().last, previous.count >= 2 else { return }

        let moved = previous.upperBound - 1
        // The rebalanced last line must still respect the character limit;
        // two words is always within any sane word limit if chars fit.
        let newLastChars = words[moved].text.count + 1 + words[last.lowerBound].text.count
        guard newLastChars <= rules.maxCharactersPerLine else { return }

        ranges[ranges.count - 2] = previous.lowerBound..<moved
        ranges[ranges.count - 1] = moved..<last.upperBound
    }

    // MARK: - Dwell

    /// Extends each card's display window into trailing silence so it stays
    /// readable: it lingers `maxHoldAfterLastWord` past its final word, at
    /// least `minCardDuration` in total, but never into the next card.
    private static func applyDwell(to cards: inout [CaptionCard], rules: GroupingRules) {
        for index in cards.indices {
            let wordEnd = cards[index].words.last?.end ?? cards[index].end
            var end = max(wordEnd + rules.maxHoldAfterLastWord,
                          cards[index].start + rules.minCardDuration)
            if index + 1 < cards.count {
                end = min(end, cards[index + 1].start)
            }
            cards[index].end = max(end, wordEnd)
        }
    }
}
