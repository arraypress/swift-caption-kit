//
//  BehindSubject.swift
//  CaptionKit
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Captions drawn behind the speaker — the person laid back over the text,
/// so the words sit in the scene rather than on top of it.
///
/// Only the cards listed go behind. ``SubjectCoverage`` decides which: a card
/// whose words the person would cover more than
/// ``SubjectCoverage/maximumCoverage`` stays in front, because past that
/// share text recognition — measured, not judged — stops reading the words.
public struct BehindSubject: Codable, Equatable, Sendable {

    /// The cards drawn behind the person.
    public var cards: Set<UUID>

    public init(cards: Set<UUID>) {
        self.cards = cards
    }
}
