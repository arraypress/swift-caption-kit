//
//  CaptionCard.swift
//  CaptionCore
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A group of words shown together on screen, split across one or more lines.
///
/// Cards are produced by ``CaptionGrouper`` and edited by the user on the
/// timeline. A card's display window (``start``/``end``) is initialized from
/// its words but is independently adjustable — the grouper extends it for
/// minimum dwell time, and the user can drag it on the timeline.
public struct CaptionCard: Codable, Equatable, Identifiable, Sendable {

    /// A stable identity for selection and editing.
    public var id: UUID

    /// The words shown on this card, in spoken order.
    public var words: [Word]

    /// When the card appears on screen, in seconds.
    public var start: TimeInterval

    /// When the card leaves the screen, in seconds.
    public var end: TimeInterval

    /// Word indexes that begin each line *after* the first — `[]` means one
    /// line, `[3]` means words `0..<3` on line one and `3...` on line two.
    ///
    /// Stored (not computed) so the layout survives user edits and re-flows
    /// only when the grouper is asked to.
    public var lineBreaks: [Int]

    /// A full style override for this card, or `nil` to use the document's
    /// global style.
    public var styleOverride: CaptionStyle?

    /// Places just this card somewhere else (normalized center, `0…1` from
    /// top-left) — one caption at the top while the rest sit at the bottom —
    /// without forking the whole style. Wins over both the global style's
    /// and a style override's position.
    public var positionOverride: NormalizedPoint?

    /// Creates a card. `start`/`end` default to the word-span bounds.
    public init(
        id: UUID = UUID(),
        words: [Word],
        start: TimeInterval? = nil,
        end: TimeInterval? = nil,
        lineBreaks: [Int] = [],
        styleOverride: CaptionStyle? = nil,
        positionOverride: NormalizedPoint? = nil
    ) {
        self.id = id
        self.words = words
        self.start = start ?? words.first?.start ?? 0
        self.end = end ?? words.last?.end ?? 0
        self.lineBreaks = lineBreaks
        self.styleOverride = styleOverride
        self.positionOverride = positionOverride
    }

    /// The card's display duration in seconds.
    public var duration: TimeInterval {
        max(0, end - start)
    }

    /// The card's words split into lines according to ``lineBreaks``.
    public var lines: [[Word]] {
        guard !words.isEmpty else { return [] }
        var result: [[Word]] = []
        var previous = 0
        for breakIndex in lineBreaks where breakIndex > previous && breakIndex < words.count {
            result.append(Array(words[previous..<breakIndex]))
            previous = breakIndex
        }
        result.append(Array(words[previous...]))
        return result
    }

    /// The card's full text with single spaces between words.
    public var text: String {
        words.map(\.text).joined(separator: " ")
    }

    /// Whether the card is on screen at the given time.
    public func contains(time: TimeInterval) -> Bool {
        time >= start && time < end
    }

    /// The index of the word being spoken at `time` — the last word whose
    /// start is at or before `time` — or `nil` if the first word hasn't
    /// started yet.
    public func activeWordIndex(at time: TimeInterval) -> Int? {
        var active: Int?
        for (index, word) in words.enumerated() where word.start <= time {
            active = index
        }
        return active
    }
}
