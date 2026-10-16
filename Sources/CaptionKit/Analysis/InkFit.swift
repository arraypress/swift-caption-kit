//
//  InkFit.swift
//  CaptionKit
//
//  Created by David Sherlock on 2026.
//
//  Keeps everything a caption draws — the letters, their outline, the box
//  or pill behind them, a speaker label — inside a rectangle, measured on
//  the drawn pixels. The layout keeps the text block inside the safe area;
//  a pill's padding, an outline or a drop shadow reaches past it. Against a
//  platform's buttons that difference is the part that ends up under them.
//

import CoreGraphics
import Foundation
import Legibility

public enum InkFit {

    /// The bounds of what `card` draws at its settled moment, normalized
    /// `0…1` top-left; `nil` when it draws nothing.
    public static func inkRect(of card: CaptionCard, in document: CaptionDocument, scale: CGFloat = 0.25) -> CGRect? {
        var alone = document
        alone.cards = [card]
        alone.hook = nil
        alone.placedStickers = nil
        alone.letterbox = nil
        alone.videoBorder = nil
        alone.progressBar = nil
        let style = document.resolvedStyle(for: card)
        let time = (SettledMoment.settled(card, style: style) ?? (card.start + card.end) / 2) + document.captionTimingOffset
        // Drawn twice, the second kept: a drop shadow is drawn directly the
        // first time a card's shape is seen and baked (blurred once, cached)
        // from then on — what nearly every exported frame shows.
        _ = CaptionRenderer.renderOverlay(document: alone, at: time, scale: scale, layers: .captions)
        guard let overlay = CaptionRenderer.renderOverlay(document: alone, at: time, scale: scale, layers: .captions) else { return nil }
        return InkBox.normalizedBounds(of: overlay)
    }

    /// How far the cards' ink reaches past `safe` on each side (normalized),
    /// and how many cards reach past it at all.
    public struct Overflow: Equatable, Sendable {
        public var top: CGFloat = 0
        public var bottom: CGFloat = 0
        public var left: CGFloat = 0
        public var right: CGFloat = 0
        public var cards = 0
    }

    /// Every card of `document` measured against `safe` (normalized top-left).
    public static func overflow(_ document: CaptionDocument, inside safe: CGRect, tolerance: CGFloat = 0.003) -> Overflow {
        var result = Overflow()
        for card in document.cards {
            guard let ink = inkRect(of: card, in: document) else { continue }
            let top = safe.minY - ink.minY, bottom = ink.maxY - safe.maxY
            let left = safe.minX - ink.minX, right = ink.maxX - safe.maxX
            result.top = max(result.top, top)
            result.bottom = max(result.bottom, bottom)
            result.left = max(result.left, left)
            result.right = max(result.right, right)
            if max(top, bottom, left, right) > tolerance { result.cards += 1 }
        }
        return result
    }

    /// Pulls `document`'s caption safe area (and the block's width) in until
    /// every card's ink is inside `safe`, measuring after each step. Returns
    /// the cards still outside — 0 unless a card is too big to fit at all.
    @discardableResult
    public static func fit(_ document: inout CaptionDocument, inside safe: CGRect, attempts: Int = 8) -> Int {
        var measured = overflow(document, inside: safe)
        var attempt = 0
        while measured.cards > 0, attempt < attempts {
            attempt += 1
            let step: CGFloat = 0.004
            var config = document.renderConfig
            if measured.top > 0 { config.safeAreaTop += measured.top + step }
            if measured.bottom > 0 { config.safeAreaBottom += measured.bottom + step }
            if measured.left > 0 { config.safeAreaLeft += measured.left + step }
            if measured.right > 0 { config.safeAreaRight += measured.right + step }
            config.safeAreaTop = min(config.safeAreaTop, 0.45)
            config.safeAreaBottom = min(config.safeAreaBottom, 0.45)
            config.safeAreaLeft = min(config.safeAreaLeft, 0.4)
            config.safeAreaRight = min(config.safeAreaRight, 0.4)
            document.renderConfig = config
            let clear = max(0.1, 1 - config.safeAreaLeft - config.safeAreaRight)
            document.style.maxWidthFraction = min(document.style.maxWidthFraction, clear)
            for index in document.cards.indices {
                guard var override = document.cards[index].styleOverride else { continue }
                override.maxWidthFraction = min(override.maxWidthFraction, clear)
                document.cards[index].styleOverride = override
            }
            measured = overflow(document, inside: safe)
        }
        return measured.cards
    }
}
