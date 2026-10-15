//
//  EmojiSuggester.swift
//  CaptionKit
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Automatic emoji: a word from ``EmojiCatalog`` — "money", "coffee",
/// "birthday" — gets its emoji inline, right after it in the caption line,
/// popping on with the word (``WordStyle/emoji``).
///
/// Blind by design: the table is data, the spacing is a rule (one per card at
/// most, and a minimum gap between them), the same transcript always gives the
/// same emoji, and the result is checkable as data. A word that already has
/// an emoji, or is censored, is left alone.
public enum EmojiSuggester {

    /// The default minimum gap between two emoji, in seconds. Four seconds is
    /// about two caption cards: frequent enough to read as a style, sparse
    /// enough that a keyword-dense clip does not drown in them.
    public static let defaultMinimumGap: TimeInterval = 4

    /// Adds inline emoji to `cards`.
    ///
    /// - Parameters:
    ///   - cards: The caption cards.
    ///   - map: Keyword → emoji. Default the built-in ``EmojiCatalog/map``.
    ///   - minimumGap: The least time between two emoji, in seconds.
    /// - Returns: The updated cards and how many emoji were placed.
    public static func suggest(
        cards: [CaptionCard],
        map: [String: String] = EmojiCatalog.map,
        minimumGap: TimeInterval = defaultMinimumGap
    ) -> (cards: [CaptionCard], count: Int) {
        var updated = cards
        var placed = 0
        var lastTime = -TimeInterval.infinity

        // Emoji the cards already carry count toward the spacing.
        let existing = cards.flatMap(\.words).filter { $0.style?.emoji?.isEmpty == false }.map(\.start)

        for cardIndex in updated.indices {
            guard !updated[cardIndex].words.contains(where: { $0.style?.emoji?.isEmpty == false }) else { continue }
            for wordIndex in updated[cardIndex].words.indices {
                let word = updated[cardIndex].words[wordIndex]
                guard word.style?.censored != true,
                      let emoji = EmojiCatalog.emoji(for: word.matchKey, in: map),
                      word.start - lastTime >= minimumGap,
                      !existing.contains(where: { abs($0 - word.start) < minimumGap }) else { continue }
                var style = word.style ?? WordStyle()
                style.emoji = emoji
                updated[cardIndex].words[wordIndex].style = style
                lastTime = word.start
                placed += 1
                break   // one per card
            }
        }
        return (updated, placed)
    }
}
