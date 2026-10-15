//
//  HookText.swift
//  CaptionKit
//
//  Created by David Sherlock on 2026.
//
//  The words of a hook title: chosen from the transcript when asked for
//  `auto`, and broken into balanced lines.
//

import Foundation

public enum HookText {

    /// The most words an automatic hook keeps. A title is read in a glance;
    /// past about eight words it is a caption.
    public static let maximumWords = 8

    /// The opening line, as a hook: the first sentence when the transcript
    /// marks one within ``maximumWords`` words, otherwise the first caption
    /// card's words (grouping already broke it at a pause or a line limit),
    /// cut to ``maximumWords``. Trailing commas and full stops go; a question
    /// or exclamation mark stays. `nil` when there are no words.
    public static func automatic(from words: [Word], firstCard: CaptionCard? = nil) -> String? {
        guard !words.isEmpty else { return nil }
        var picked = Array(words.prefix(maximumWords))
        if let end = picked.firstIndex(where: \.endsSentence) {
            picked = Array(picked[...end])
        } else if let card = firstCard, !card.words.isEmpty {
            picked = Array(card.words.prefix(maximumWords))
        }
        var text = picked.map(\.text).joined(separator: " ")
        while let last = text.last, ".,;:…".contains(last) { text.removeLast() }
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Line breaks for a title of `words`: as few lines as keep each under
    /// `maximumCharacters`, split where the lines come out most even.
    public static func lineBreaks(for words: [String], maximumCharacters: Int = 16) -> [Int] {
        let characters = words.reduce(0) { $0 + $1.count } + max(0, words.count - 1)
        let lines = min(words.count, max(1, Int((Double(characters) / Double(max(1, maximumCharacters))).rounded(.up))))
        return TranslationRetimer.rebalancedLineBreaks(texts: words, lineCount: lines)
    }
}
