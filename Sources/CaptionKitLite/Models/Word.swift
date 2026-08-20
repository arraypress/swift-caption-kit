//
//  Word.swift
//  CaptionKitLite
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A single spoken word with word-level timing.
///
/// The atomic unit of the caption model. Every downstream feature — karaoke
/// fills, active-word highlighting, grouping, timeline placement — derives
/// from these timestamps, so they must be word-level (not sentence-level).
///
/// ```swift
/// let word = Word(text: "hello", start: 1.24, end: 1.61)
/// ```
public struct Word: Codable, Equatable, Hashable, Sendable {

    /// The word text, including any attached punctuation (e.g. `"hello,"`).
    public var text: String

    /// The moment the word starts being spoken, in seconds from video start.
    public var start: TimeInterval

    /// The moment the word finishes, in seconds from video start.
    public var end: TimeInterval

    /// The recognizer's confidence in this word (`0…1`). `1` when unknown.
    public var confidence: Float

    /// Style overrides for this specific word instance, or `nil` to inherit
    /// everything. Travels with the word through regrouping.
    public var style: WordStyle?

    /// Which speaker said this word (diarization), or `nil` when unknown.
    public var speaker: Int?

    /// The spoken duration in seconds (`end - start`, never negative).
    public var duration: TimeInterval {
        max(0, end - start)
    }

    /// Creates a word.
    ///
    /// - Parameters:
    ///   - text: The word text, punctuation attached.
    ///   - start: Start time in seconds.
    ///   - end: End time in seconds.
    ///   - confidence: Recognizer confidence (`0…1`). Default `1`.
    ///   - style: Per-word style overrides. Default `nil` (inherit).
    public init(text: String, start: TimeInterval, end: TimeInterval, confidence: Float = 1, style: WordStyle? = nil) {
        self.text = text
        self.start = start
        self.end = end
        self.confidence = confidence
        self.style = style
    }

    /// The text lowercased with leading/trailing punctuation stripped —
    /// what keyword highlight rules match against.
    public var matchKey: String {
        text.trimmingCharacters(in: .punctuationCharacters.union(.symbols)).lowercased()
    }

    /// Whether the text ends a sentence (`.`, `!`, `?`, `…`).
    public var endsSentence: Bool {
        guard let last = text.unicodeScalars.last else { return false }
        return last == "." || last == "!" || last == "?" || last == "…"
    }
}
