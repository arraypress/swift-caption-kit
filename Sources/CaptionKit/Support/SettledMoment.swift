//
//  SettledMoment.swift
//  CaptionKit
//
//  Created by David Sherlock on 2026.
//
//  The moment a caption has finished arriving: every word's entrance done,
//  the card's own entrance and a drawn-on background complete, and its exit
//  not yet begun. A sample frame taken earlier shows a style mid-flight — a
//  stomp overshooting the frame, a typewriter box holding one letter — which
//  says nothing true about the style.
//

import Foundation

public enum SettledMoment {

    /// How long a drawn-on background takes to sweep in (the renderer's).
    static let drawOnDuration: TimeInterval = 0.45

    /// A frame's grace after the last animation ends.
    static let grace: TimeInterval = 0.02

    /// The first moment, in caption time, at which `card` drawn in `style`
    /// has settled: every word's entrance (and letter cascade) finished, the
    /// card's entrance and any draw-on background complete. `nil` when the
    /// card ends — or starts its exit — before that.
    public static func settled(_ card: CaptionCard, style: CaptionStyle) -> TimeInterval? {
        let duration = max(0.01, style.animationDuration)
        var time = card.start
        if style.cardAnimation != .none { time = max(time, card.start + duration * 1.5) }
        if style.background?.drawOn == true { time = max(time, card.start + drawOnDuration) }
        for word in card.words {
            let entrance = word.style?.animation ?? style.wordAnimation
            guard entrance != .none else { continue }
            let cascade = (style.letterStagger ?? 0) * Double(word.text.count)
            time = max(time, word.start + duration + max(0, cascade))
        }
        time += grace
        let exitStart = (style.exitAnimation ?? .none) != .none ? card.end - duration : card.end
        return time < exitStart ? time : nil
    }

    /// The source-time moment that shows `document`'s look best: the settled
    /// moment of the card with the most words, preferring cards that do
    /// settle; a card too short to settle gives the instant before it ends.
    /// `0.5` for a document without cards.
    public static func moment(in document: CaptionDocument) -> TimeInterval {
        let ranked = document.cards.enumerated().sorted { lhs, rhs in
            lhs.element.words.count != rhs.element.words.count
                ? lhs.element.words.count > rhs.element.words.count
                : lhs.offset < rhs.offset
        }.map(\.element)
        guard let busiest = ranked.first else { return 0.5 }
        let captionTime: TimeInterval
        if let card = ranked.first(where: { settled($0, style: document.resolvedStyle(for: $0)) != nil }),
           card.words.count == busiest.words.count || card.words.count * 2 >= busiest.words.count,
           let time = settled(card, style: document.resolvedStyle(for: card)) {
            captionTime = time
        } else {
            captionTime = max(busiest.start, busiest.end - 0.05)
        }
        // The renderer shows the caption for source time t at t + offset.
        return max(0, captionTime + document.captionTimingOffset)
    }
}
