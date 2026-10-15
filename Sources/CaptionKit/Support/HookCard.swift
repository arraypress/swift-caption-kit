//
//  HookCard.swift
//  CaptionKit
//
//  Created by David Sherlock on 2026.
//
//  A hook title as the renderer draws it: a caption card whose words all
//  arrive at once, laid out against a document whose safe area is the
//  title's own safe rectangle. The title goes through the one drawing path
//  the captions use — no second renderer.
//

import CoreGraphics
import Foundation

enum HookCard {

    /// The card `hook` draws as.
    static func card(for hook: HookTitle) -> CaptionCard {
        let words = hook.text.split(whereSeparator: \.isWhitespace).map {
            Word(text: String($0), start: hook.start, end: hook.end)
        }
        return CaptionCard(id: hook.id, words: words, start: hook.start, end: hook.end, lineBreaks: hook.lineBreaks)
    }

    /// A document holding only the title's style, on `config` with its safe
    /// area narrowed to the title's safe rectangle — so the layout's own
    /// clamp keeps the title where the placement put it. Document-wide word
    /// rules (keyword highlights, speaker colours, censoring) do not reach it.
    static func document(for hook: HookTitle, config: RenderConfig) -> CaptionDocument {
        var config = config
        let safe = hook.safeRect.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        if !safe.isNull, safe.width > 0, safe.height > 0 {
            config.safeAreaLeft = safe.minX
            config.safeAreaTop = safe.minY
            config.safeAreaRight = 1 - safe.maxX
            config.safeAreaBottom = 1 - safe.maxY
        }
        return CaptionDocument(style: hook.style, renderConfig: config)
    }

    /// Whether `hook` is on screen at `time`.
    static func isVisible(_ hook: HookTitle, at time: TimeInterval) -> Bool {
        time >= hook.start && time < hook.end
    }
}
