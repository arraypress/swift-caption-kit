//
//  TranslationRetimer.swift
//  CaptionKit
//
//  Created by David Sherlock on 2026.
//

import Foundation
import NaturalLanguage

/// Keeps a translated transcript in time with the original speech.
///
/// Translation changes the word count, so word-level timing cannot be copied
/// across. Instead each line keeps its original spoken span and the
/// translated words share it out in proportion to their length — karaoke
/// fills, word entrances and the active-word pop all keep working in the new
/// language, paced to the speech they replace.
///
/// Translation itself is not done here (the fleet's `translate` tool does
/// it); this is only the timing. A words list in which any entry holds a
/// phrase — `{"start": 0.48, "end": 1.26, "text": "Así que esto es gratis"}` —
/// goes through ``expanded(_:)`` and comes out one timed word per word.
public enum TranslationRetimer {

    /// `words` with every entry that holds more than one word spread into
    /// timed words across its own span. An entry of one word is returned
    /// exactly as it was, so a per-word transcript passes through untouched.
    public static func expanded(_ words: [Word]) -> [Word] {
        var result: [Word] = []
        result.reserveCapacity(words.count)
        for word in words {
            let parts = segments(of: word.text)
            guard parts.count > 1, word.end > word.start else {
                result.append(word)
                continue
            }
            result += spread(parts, from: word.start, to: word.end).map { piece in
                var piece = piece
                piece.confidence = word.confidence
                piece.style = word.style
                piece.speaker = word.speaker
                return piece
            }
        }
        return result
    }

    /// `text`'s words spread across `start..<end`, each given time in
    /// proportion to its length (plus one, so a very short word still gets a
    /// beat). The first starts at `start`, the last ends at `end`.
    public static func words(_ text: String, from start: TimeInterval, to end: TimeInterval) -> [Word] {
        spread(segments(of: text), from: start, to: end)
    }

    /// Rebuilds a card around translated text: the card's original spoken
    /// span is shared out across the new words, and its line count is kept by
    /// rebalancing on character weight. The card keeps its id, window, style
    /// and position; the words keep the first original word's speaker.
    public static func retimed(card: CaptionCard, translatedText: String) -> CaptionCard {
        let texts = segments(of: translatedText)
        guard !texts.isEmpty, let spanStart = card.words.first?.start, let spanEnd = card.words.last?.end,
              spanEnd > spanStart else { return card }
        let speaker = card.words.first?.speaker
        var result = card
        result.words = spread(texts, from: spanStart, to: spanEnd).map { word in
            var word = word
            word.speaker = speaker
            return word
        }
        result.lineBreaks = rebalancedLineBreaks(texts: texts, lineCount: card.lineBreaks.count + 1)
        return result
    }

    /// Splits text into caption words. Spaced languages split on whitespace,
    /// punctuation staying attached. Text in a script written without spaces
    /// (Chinese, Japanese, Thai, Lao, Khmer, Myanmar, Tibetan) goes through
    /// on-device word segmentation instead, so a highlight moves word by word
    /// rather than lighting the whole line at once. Anything else that reads
    /// as one word stays one word — `don't`, `U.S.` and `e-mail` are never cut.
    public static func segments(of text: String) -> [String] {
        let spaced = text.split(whereSeparator: \.isWhitespace).map(String.init)
        guard spaced.count == 1, writtenWithoutSpaces(text) else { return spaced }

        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var tokens: [String] = []
        var pending = ""   // punctuation before the first token glues to it
        var lastEnd = text.startIndex
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let gap = String(text[lastEnd..<range.lowerBound])
            if !gap.isEmpty {
                if tokens.isEmpty { pending += gap } else { tokens[tokens.count - 1] += gap }
            }
            tokens.append(pending + String(text[range]))
            pending = ""
            lastEnd = range.upperBound
            return true
        }
        if lastEnd < text.endIndex, !tokens.isEmpty {
            tokens[tokens.count - 1] += String(text[lastEnd...])
        }
        return tokens.isEmpty ? spaced : tokens
    }

    /// Splits `texts` into `lineCount` lines of roughly equal character
    /// weight, returning the starting word indexes of lines 2 onwards (the
    /// form ``CaptionCard/lineBreaks`` takes).
    public static func rebalancedLineBreaks(texts: [String], lineCount: Int) -> [Int] {
        guard lineCount > 1, texts.count > 1 else { return [] }
        let lines = min(lineCount, texts.count)
        let totalChars = texts.reduce(0) { $0 + $1.count + 1 }
        let perLine = Double(totalChars) / Double(lines)

        var breaks: [Int] = []
        var running = 0.0
        for (index, text) in texts.enumerated() {
            if index > 0, running >= perLine * Double(breaks.count + 1), breaks.count < lines - 1 {
                breaks.append(index)
            }
            running += Double(text.count + 1)
        }
        return breaks
    }

    // MARK: - Helpers

    private static func spread(_ texts: [String], from start: TimeInterval, to end: TimeInterval) -> [Word] {
        guard !texts.isEmpty else { return [] }
        let weights = texts.map { Double($0.count + 1) }
        let total = weights.reduce(0, +)
        let span = max(0, end - start)
        var words: [Word] = []
        var used = 0.0
        for (index, (text, weight)) in zip(texts, weights).enumerated() {
            let wordStart = start + span * used / total
            used += weight
            // The last word ends exactly on the span's end, whatever the
            // floating-point sum of the shares came to.
            let wordEnd = index == texts.count - 1 ? end : start + span * used / total
            words.append(Word(text: text, start: wordStart, end: wordEnd))
        }
        return words
    }

    /// Whether `text` is in a script written without spaces between words.
    static func writtenWithoutSpaces(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x0E00...0x0EFF,   // Thai, Lao
                 0x0F00...0x0FFF,   // Tibetan
                 0x1000...0x109F,   // Myanmar
                 0x1780...0x17FF,   // Khmer
                 0x3040...0x30FF,   // Hiragana, Katakana
                 0x3400...0x4DBF,   // CJK extension A
                 0x4E00...0x9FFF,   // CJK unified ideographs
                 0xF900...0xFAFF:   // CJK compatibility ideographs
                return true
            default:
                return false
            }
        }
    }
}
