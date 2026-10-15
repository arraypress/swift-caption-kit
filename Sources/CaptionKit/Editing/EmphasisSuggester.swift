//
//  EmphasisSuggester.swift
//  CaptionKit
//
//  Created by David Sherlock on 2026.
//

import CoreGraphics
import Foundation
import NaturalLanguage

/// Automatic emphasis: picks the word that carries each caption — a number,
/// a noun, an adjective — by on-device part-of-speech tagging, and gives it a
/// colour from a rotating palette as an ordinary per-word ``WordStyle``.
///
/// Blind by design: the choice is a rule over the transcript, the same input
/// always gives the same words, and the result is checkable as data (which
/// words, how many per card) rather than by eye. A word already given a
/// colour — by a recipe's `words.emphasis`, say — is left alone.
public enum EmphasisSuggester {

    /// The default palette: green, orange, pink, sky blue — each clears
    /// white text and dark footage alike.
    public static let defaultPalette: [StyleColor] = [
        .green, .orange, .pink, StyleColor(hex: "#4FD8FF") ?? .blue,
    ]

    /// The lowest score a word must reach to be emphasized: an adjective.
    /// Verbs and function words never carry a card on their own.
    public static let minimumScore = 2.2

    /// Emphasizes at most one word per card.
    ///
    /// - Parameters:
    ///   - cards: The caption cards.
    ///   - palette: Colours rotated across emphasized words.
    ///   - sizeMultiplier: A size boost for emphasized words (`1` = colour only).
    ///   - underline: Also underline each emphasized word in its colour.
    /// - Returns: The updated cards and how many words were emphasized.
    public static func emphasize(
        cards: [CaptionCard],
        palette: [StyleColor] = defaultPalette,
        sizeMultiplier: CGFloat = 1,
        underline: Bool = false
    ) -> (cards: [CaptionCard], count: Int) {
        guard !palette.isEmpty else { return (cards, 0) }
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        var updated = cards
        var emphasized = 0

        for cardIndex in updated.indices {
            let words = updated[cardIndex].words
            guard words.count > 1, let best = carryingWord(in: words, tagger: tagger) else { continue }

            var style = words[best].style ?? WordStyle()
            style.color = palette[emphasized % palette.count]
            if sizeMultiplier != 1, style.sizeMultiplier == nil { style.sizeMultiplier = sizeMultiplier }
            if underline, style.underline == nil { style.underline = style.color }
            updated[cardIndex].words[best].style = style
            emphasized += 1
        }
        return (updated, emphasized)
    }

    /// The index of the word that carries `words`, or `nil` when none scores
    /// ``minimumScore``. Ties go to the earlier word.
    static func carryingWord(in words: [Word], tagger: NLTagger) -> Int? {
        // Join with single spaces, remembering where each word starts.
        var offsets: [Int] = []
        var joined = ""
        for word in words {
            offsets.append(joined.utf16.count)
            joined += word.text + " "
        }
        tagger.string = joined

        var best: (index: Int, score: Double)?
        tagger.enumerateTags(in: joined.startIndex..<joined.endIndex, unit: .word, scheme: .lexicalClass,
                             options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            let offset = joined.utf16.distance(from: joined.utf16.startIndex, to: range.lowerBound)
            guard let index = offsets.lastIndex(where: { $0 <= offset }) else { return true }
            let word = words[index]
            // A word somebody already coloured is theirs.
            guard word.style?.color == nil, word.style?.censored != true else { return true }
            let score = Self.score(tag: tag, key: word.matchKey)
            if score > (best?.score ?? 0) { best = (index, score) }
            return true
        }
        guard let best, best.score >= minimumScore else { return nil }
        return best.index
    }

    /// How strongly a word carries a line: numbers most, then nouns,
    /// adjectives and verbs; a long word a little more; a word under three
    /// letters never.
    static func score(tag: NLTag?, key: String) -> Double {
        guard key.count >= 3 else { return 0 }
        var score: Double
        switch tag {
        case .some(.number): score = 4
        case .some(.noun): score = 3
        case .some(.adjective): score = 2.2
        case .some(.verb): score = 1.5
        default: score = 0
        }
        if key.count >= 6, score > 0 { score += 0.5 }
        return score
    }

    /// Removes colour emphasis from every word. Size and animation overrides
    /// stay; a coloured word also loses its underline (colour and underline
    /// were applied together), while an underline on an uncoloured word is
    /// somebody's own and survives. Empty styles collapse away.
    public static func clearEmphasis(cards: [CaptionCard]) -> [CaptionCard] {
        var updated = cards
        for cardIndex in updated.indices {
            for wordIndex in updated[cardIndex].words.indices {
                guard var style = updated[cardIndex].words[wordIndex].style else { continue }
                if style.color != nil { style.underline = nil }
                style.color = nil
                updated[cardIndex].words[wordIndex].style = style.isEmpty ? nil : style
            }
        }
        return updated
    }
}
