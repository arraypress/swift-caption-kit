//
//  SubjectCoverage.swift
//  CaptionKit
//
//  Created by David Sherlock on 2026.
//

import CoreGraphics
import Foundation

/// How much of each caption word the speaker would hide if the captions went
/// behind them — measured on the footage, not guessed — and which cards can
/// go behind without losing their words.
///
/// Each card is sampled at three moments (just after it appears, its middle,
/// just before it goes); at each, the person is segmented (``SubjectMasker``,
/// the same masks the export draws with) and every word's share under the
/// person is taken. A word's coverage is its worst moment; a card's is its
/// worst word.
public enum SubjectCoverage {

    /// The most of any word the person may cover for its card to go behind.
    ///
    /// Measured, not chosen. Captions in six presets were drawn behind four
    /// generated portraits at twenty heights each, and every frame read back
    /// with on-device text recognition, in front and behind: 26,181 words
    /// that read in front. Behind the person, words covered 0–2% read back
    /// 96–100% of the time and 2–5% read 98%; at 5–8% it fell to 84%, at
    /// 8–10% to 80%, at 10–12% to 63%, and past 25% to under 10%. Five per
    /// cent is the knee.
    public static let maximumCoverage: Double = 0.05

    /// One card's measurement.
    public struct Card: Codable, Equatable, Sendable {
        /// The card measured.
        public var id: UUID
        /// Each word's worst share under the person, `0…1`, in word order.
        public var words: [Double]
        /// The card's worst word.
        public var coverage: Double { words.max() ?? 0 }

        public init(id: UUID, words: [Double]) {
            self.id = id
            self.words = words
        }
    }

    /// Every card of `document` measured against its video. Cards that cannot
    /// be measured (no frame decodes) come back fully covered, so they stay
    /// in front.
    public static func measure(_ document: CaptionDocument) async -> [Card] {
        let masker = SubjectMasker()
        var cards: [Card] = []
        for card in document.cards {
            let times = moments(of: card).map { $0 + document.captionTimingOffset }
            let frames = await CanvasFrames.frames(for: document, at: times, width: 360)
            var worst = [Double](repeating: frames.isEmpty ? 1 : 0, count: card.words.count)
            for frame in frames {
                guard let rects = CaptionRenderer.wordRects(document: document, at: frame.time),
                      rects.cardID == card.id else { continue }
                guard let mask = masker.mask(of: frame.image) else { continue }
                for (index, rect) in rects.rects where index < worst.count {
                    worst[index] = max(worst[index], SubjectMasker.coverage(of: rect, in: mask))
                }
            }
            cards.append(Card(id: card.id, words: worst))
        }
        return cards
    }

    /// The cards whose worst word is covered no more than `limit`.
    public static func behindCards(_ cards: [Card], limit: Double = maximumCoverage) -> Set<UUID> {
        Set(cards.filter { $0.coverage <= limit }.map(\.id))
    }

    /// The three moments a card is sampled at, in caption time.
    static func moments(of card: CaptionCard) -> [TimeInterval] {
        let span = max(0, card.end - card.start)
        let edge = min(0.1, span / 4)
        return [card.start + edge, card.start + span / 2, card.end - edge]
    }
}
