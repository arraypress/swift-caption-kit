//
//  StickerCheck.swift
//  CaptionKit
//
//  Created by David Sherlock on 2026.
//
//  Placed stickers measured, not looked at: whether each sits inside the
//  safe zone, how much of it covers a face, the captions or the hook title,
//  and whether it was actually drawn — the pixels inside its box with and
//  without it, at several moments while it is up. Recomputed from the
//  document and the footage, independently of the placer.
//

import CoreGraphics
import Foundation
import Legibility

/// One sticker's measurements.
public struct StickerReport: Codable, Equatable, Sendable {

    public var name: String
    /// The emoji, or the file's name.
    public var source: String
    /// On screen, source seconds.
    public var start: TimeInterval
    public var end: TimeInterval
    /// Its box at rest, normalized, top-left origin.
    public var rect: CGRect
    /// Its width, as a fraction of the frame's.
    public var size: Double
    /// The rectangle it must stay inside.
    public var safeRect: CGRect
    public var insideSafeZone: Bool
    /// Faces found in the frames it covers.
    public var faces: Int
    /// Shares (`0…1`) of its box covered by a head (the face box grown to
    /// take in the forehead and hair), the caption block (at any
    /// moment it is up) and the hook title.
    public var faceOverlap: Double
    public var captionOverlap: Double
    public var hookOverlap: Double
    /// The smallest share (`0…1`) of its box's pixels that change when it is
    /// drawn, over the moments sampled; above 0 means it was drawn every time.
    public var drawn: Double
    /// The source seconds the drawing was checked at.
    public var drawnAt: [TimeInterval]

    /// Whether every rule held and it was drawn.
    public var ok: Bool {
        insideSafeZone && faceOverlap == 0 && captionOverlap == 0 && hookOverlap == 0 && drawn > 0
    }
}

public enum StickerCheck {

    /// A pixel counts as changed when a channel moves by more than this (of 255).
    static let pixelTolerance = 8

    /// The overlay scale the drawing is checked at.
    static let checkScale: CGFloat = 0.5

    /// Measures every placed sticker of `document`.
    ///
    /// - Parameter platform: Whose safe zone; as ``StickerPlacer/place(_:in:platform:rules:)``.
    public static func measure(_ document: CaptionDocument, platform: Platform? = nil) async -> [StickerReport] {
        guard let stickers = document.placedStickers, !stickers.isEmpty else { return [] }
        let config = document.renderConfig
        let safe = HookBuilder.safeRect(config: config, platform: platform)
        let hookRect = document.hook.flatMap { CaptionRenderer.hookRect($0, config: config) }
        var reports: [StickerReport] = []

        for sticker in stickers {
            let samples = (0..<5).map { sticker.start + (sticker.end - sticker.start) * (Double($0) + 0.5) / 5 }
            // Heads, not just the brow-to-chin face box (``StickerPlacer/head(of:)``).
            let frames = await CanvasFrames.frames(for: document, at: samples)
            let faces = await CanvasFrames.faces(in: frames.map(\.image)).joined().map(StickerPlacer.head(of:))
            var captions: [CGRect] = []
            var time = sticker.start
            while time < sticker.end {
                if let block = CaptionRenderer.captionBlockRect(document: document, at: time) { captions.append(block) }
                time += StickerPlacer.captionSampling
            }
            var hookOverlap = 0.0
            if let hook = document.hook, let hookRect, hook.start < sticker.end, hook.end > sticker.start {
                hookOverlap = Double(HookPlacement.overlapFraction(of: sticker.rect, with: [hookRect]))
            }
            let moments = drawMoments(sticker)
            let drawn = moments.map { changedShare(of: sticker, in: document, at: $0) }.min() ?? 0

            reports.append(StickerReport(
                name: sticker.name, source: sticker.source.label, start: sticker.start, end: sticker.end,
                rect: sticker.rect, size: sticker.size, safeRect: safe,
                insideSafeZone: safe.insetBy(dx: -0.001, dy: -0.001).contains(sticker.rect),
                faces: faces.count,
                faceOverlap: Double(HookPlacement.overlapFraction(of: sticker.rect, with: faces)),
                captionOverlap: Double(HookPlacement.overlapFraction(of: sticker.rect, with: captions)),
                hookOverlap: hookOverlap, drawn: drawn, drawnAt: moments))
        }
        return reports
    }

    /// Three moments while `sticker` is up: just after its entrance, its
    /// middle, and just before it goes.
    static func drawMoments(_ sticker: PlacedSticker) -> [TimeInterval] {
        let span = sticker.end - sticker.start
        let settled = min(sticker.start + StickerRenderer.entranceDuration + 0.02, sticker.start + span * 0.4)
        return [settled, sticker.start + span * 0.5, sticker.end - min(0.05, span * 0.1)]
    }

    /// The share of `sticker`'s box whose pixels differ between the overlay
    /// with every sticker and the overlay without this one, at `time`.
    public static func changedShare(of sticker: PlacedSticker, in document: CaptionDocument, at time: TimeInterval) -> Double {
        var without = document
        without.placedStickers = document.placedStickers?.filter { $0.id != sticker.id }
        guard let with = CaptionRenderer.renderOverlay(document: document, at: time, scale: checkScale),
              let bare = CaptionRenderer.renderOverlay(document: without, at: time, scale: checkScale),
              let a = Pixels.rgba(of: with), let b = Pixels.rgba(of: bare) else { return 0 }
        let width = with.width, height = with.height
        let box = CanvasFrames.pixels(sticker.rect, in: with).integral
            .intersection(CGRect(x: 0, y: 0, width: width, height: height))
        guard !box.isNull, box.width >= 1, box.height >= 1 else { return 0 }
        var changed = 0, total = 0
        for y in Int(box.minY)..<Int(box.maxY) {
            for x in Int(box.minX)..<Int(box.maxX) {
                let offset = (y * width + x) * 4
                total += 1
                for channel in 0..<4 where abs(Int(a[offset + channel]) - Int(b[offset + channel])) > pixelTolerance {
                    changed += 1
                    break
                }
            }
        }
        return total > 0 ? Double(changed) / Double(total) : 0
    }
}
