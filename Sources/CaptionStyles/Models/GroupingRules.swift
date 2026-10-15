//
//  GroupingRules.swift
//  CaptionStyles
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// The knobs that control how a word stream is grouped into caption cards.
///
/// Defaults produce the familiar short-form look: two lines, a few words per
/// line, broken at sentences and natural pauses.
public struct GroupingRules: Codable, Equatable, Sendable {

    /// Maximum lines shown on screen at once (per card).
    public var maxLinesPerCard: Int

    /// Maximum words on a single line.
    public var maxWordsPerLine: Int

    /// Maximum characters on a single line (spaces included). A single word
    /// longer than this still gets its own line rather than being split.
    public var maxCharactersPerLine: Int

    /// A silence of at least this many seconds between two words forces a
    /// card break.
    public var pauseThreshold: TimeInterval

    /// Cards stay on screen at least this long (extended into trailing
    /// silence, never overlapping the next card).
    public var minCardDuration: TimeInterval

    /// After its last word ends, a card may linger at most this long waiting
    /// for the next card.
    public var maxHoldAfterLastWord: TimeInterval

    /// What a change of speaker does: start a card, start a line, or (`nil`)
    /// nothing — speakers are ignored.
    public var speakerBreak: SpeakerBreak? = nil

    public init(
        maxLinesPerCard: Int = 2,
        maxWordsPerLine: Int = 4,
        maxCharactersPerLine: Int = 20,
        pauseThreshold: TimeInterval = 0.6,
        minCardDuration: TimeInterval = 0.9,
        maxHoldAfterLastWord: TimeInterval = 0.5
    ) {
        self.maxLinesPerCard = max(1, maxLinesPerCard)
        self.maxWordsPerLine = max(1, maxWordsPerLine)
        self.maxCharactersPerLine = max(1, maxCharactersPerLine)
        self.pauseThreshold = pauseThreshold
        self.minCardDuration = minCardDuration
        self.maxHoldAfterLastWord = maxHoldAfterLastWord
    }
}
