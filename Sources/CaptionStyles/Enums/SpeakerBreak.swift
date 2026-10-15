//
//  SpeakerBreak.swift
//  CaptionStyles
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What a change of speaker does to grouping (see
/// ``GroupingRules/speakerBreak``). Words with no speaker never break.
public enum SpeakerBreak: String, Codable, CaseIterable, Sendable {

    /// A new speaker starts a new card — one speaker per caption.
    case card

    /// A new speaker starts a new line, and a card holds at most two
    /// speakers' lines — the streaming-subtitle layout.
    case line
}
