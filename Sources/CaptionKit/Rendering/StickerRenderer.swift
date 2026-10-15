//
//  StickerRenderer.swift
//  CaptionKit
//
//  Created by David Sherlock on 2026.
//
//  Draws placed stickers: each picture aspect-fitted into the box the placer
//  chose, moved by its entrance and loop — pure functions of time, so the
//  preview and the export draw the same frame.
//

import CoreGraphics
import Foundation

/// A sticker's motion at one instant, relative to its box at rest. Offsets
/// are pixels in drawing coordinates (y up); rotation in radians.
public struct StickerMotion: Equatable, Sendable {
    public var alpha: Double = 1
    public var scale: Double = 1
    public var dx: Double = 0
    public var dy: Double = 0
    public var rotation: Double = 0
}

public enum StickerRenderer {

    /// How long an entrance takes, in seconds.
    public static let entranceDuration: TimeInterval = 0.35

    /// The motion of `sticker` at `time` (source seconds), for a box
    /// `travel` pixels tall (how far movements reach).
    public static func motion(of sticker: PlacedSticker, at time: TimeInterval, travel: Double) -> StickerMotion {
        var motion = StickerMotion()
        let elapsed = max(0, time - sticker.start)
        let progress = min(1, elapsed / entranceDuration)
        switch sticker.entrance {
        case .none:
            break
        case .spin:
            let eased = 1 - pow(1 - progress, 3)
            motion.rotation = -(1 - eased) * 2 * .pi
            motion.scale = max(0.02, eased)
            motion.alpha = min(1, progress * 3)
        default:
            let curve = CaptionRenderer.stickerEntrance(sticker.entrance.wordAnimation, progress: progress, travel: travel)
            motion.alpha = curve.alpha
            motion.scale = curve.scale
            motion.dx = curve.dx
            motion.dy = curve.dy
            motion.rotation = curve.rotation
        }
        switch sticker.loop {
        case .none:
            break
        case .bounce:
            motion.dy += abs(sin(2 * .pi * elapsed * 0.9)) * 0.08 * travel
        case .float:
            motion.dy += sin(2 * .pi * elapsed * 0.5) * 0.06 * travel
        case .spin:
            motion.rotation -= 2 * .pi * 0.5 * elapsed
        case .shake:
            motion.dx += sin(2 * .pi * elapsed * 9) * 0.03 * travel
        case .pulse:
            motion.scale *= 1 + 0.06 * sin(2 * .pi * elapsed * 1.4)
        }
        return motion
    }

    /// The box of `sticker` in drawing coordinates (y up) on `size`.
    static func box(_ sticker: PlacedSticker, size: CGSize) -> CGRect {
        CGRect(x: sticker.rect.minX * size.width, y: (1 - sticker.rect.maxY) * size.height,
               width: sticker.rect.width * size.width, height: sticker.rect.height * size.height)
    }

    /// Draws every sticker of `document` on screen at `time`.
    static func draw(document: CaptionDocument, in context: CGContext, at time: TimeInterval) {
        guard document.trackEnabled(.stickers), let stickers = document.placedStickers, !stickers.isEmpty else { return }
        let size = document.renderConfig.size
        for sticker in stickers where sticker.isVisible(at: time) {
            guard let media = StickerMedia.frames(for: sticker.source),
                  let image = media.frame(at: time - sticker.start) else { continue }
            let box = box(sticker, size: size)
            let motion = motion(of: sticker, at: time, travel: Double(box.height))
            guard motion.alpha > 0.001, motion.scale > 0.001 else { continue }

            // The picture aspect-fitted inside the box, centred.
            let fit = min(box.width / CGFloat(image.width), box.height / CGFloat(image.height))
            let drawn = CGSize(width: CGFloat(image.width) * fit, height: CGFloat(image.height) * fit)

            context.saveGState()
            context.setAlpha(CGFloat(min(1, motion.alpha)))
            context.translateBy(x: box.midX + CGFloat(motion.dx), y: box.midY + CGFloat(motion.dy))
            context.rotate(by: CGFloat(motion.rotation))
            context.scaleBy(x: CGFloat(motion.scale), y: CGFloat(motion.scale))
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: -drawn.width / 2, y: -drawn.height / 2, width: drawn.width, height: drawn.height))
            context.restoreGState()
        }
    }
}
