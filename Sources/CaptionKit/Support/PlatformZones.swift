//
//  PlatformZones.swift
//  CaptionKit
//
//  Created by David Sherlock on 2026.
//
//  Which parts of each platform's frame its own interface covers, and the
//  rectangle left clear. Every number has a source (measured 2026-10-15):
//
//  - tiktok — TikTok for Business's official safe-zone template, "In-Feed
//    Standard" (Feed.png, 2880×5120, labels on a 720×1280 canvas): top 160 px,
//    sides 80 px, bottom 440 px, right action rail 120 px wide from y 560
//    (ads.tiktok.com/help/article/video-ads-specifications). The labels and
//    the measured pixels agree exactly.
//  - reel — Meta Ads Guide, Instagram Reels: "leave at least 14% of the top,
//    35% of the bottom, and 6% on each side … free"; the button notch (21%
//    wide, 40% tall at the bottom right) from the diagram in Meta Business
//    Help 980593475366490, measured to within 1% of its labels.
//  - shorts — Google Ads' vertical video safe zone (help 9128498 / 13547298,
//    "in-stream, in-feed, and YouTube Shorts"): top 288, bottom 672, left
//    48, right 192 px of 1080×1920; Google's overlay PNG measures the same.
//  - youtube (16:9) — no official number for the player: the controls and
//    progress bar are 72 px plus 5–8 px in YouTube's own player stylesheet
//    (0.108 of a 720p player), the title gradient 48 px (0.067); the sides
//    are EBU R 95's 5% graphics-safe margin.
//  - story — carried over from the retired caption studio, unsourced.
//
//  The three vertical numbers are the platforms' guidance for ADS, the only
//  guidance they publish: an ad adds a call-to-action line, so they are the
//  conservative bound for an ordinary post too.
//

import CoreGraphics
import Foundation

public enum PlatformZones {

    /// The regions `platform`'s interface covers, top to bottom.
    public static func zones(for platform: Platform) -> [ScreenZone] {
        switch platform {
        case .story:
            return [
                ScreenZone(rect: CGRect(x: 0, y: 0, width: 1, height: 0.10), label: "Progress & profile"),
                ScreenZone(rect: CGRect(x: 0, y: 0.90, width: 1, height: 0.10), label: "Reply bar"),
            ]
        case .reel:
            return [
                ScreenZone(rect: CGRect(x: 0, y: 0, width: 1, height: 0.14), label: "Top bar"),
                ScreenZone(rect: CGRect(x: 0, y: 0, width: 0.06, height: 1), label: "Left margin"),
                ScreenZone(rect: CGRect(x: 0.94, y: 0, width: 0.06, height: 1), label: "Right margin"),
                ScreenZone(rect: CGRect(x: 0.79, y: 0.60, width: 0.21, height: 0.40), label: "Actions"),
                ScreenZone(rect: CGRect(x: 0, y: 0.65, width: 1, height: 0.35), label: "Caption, audio & call to action"),
            ]
        case .tiktok:
            return [
                ScreenZone(rect: CGRect(x: 0, y: 0, width: 1, height: 0.125), label: "Top bar"),
                ScreenZone(rect: CGRect(x: 0, y: 0, width: 0.111, height: 1), label: "Left margin"),
                ScreenZone(rect: CGRect(x: 0.889, y: 0, width: 0.111, height: 1), label: "Right margin"),
                ScreenZone(rect: CGRect(x: 0.722, y: 0.4375, width: 0.278, height: 0.5625), label: "Actions"),
                ScreenZone(rect: CGRect(x: 0, y: 0.656, width: 1, height: 0.344), label: "Caption, sound & call to action"),
            ]
        case .shorts:
            return [
                ScreenZone(rect: CGRect(x: 0, y: 0, width: 1, height: 0.15), label: "Top bar"),
                ScreenZone(rect: CGRect(x: 0, y: 0, width: 0.044, height: 1), label: "Left margin"),
                ScreenZone(rect: CGRect(x: 0.822, y: 0, width: 0.178, height: 1), label: "Actions"),
                ScreenZone(rect: CGRect(x: 0, y: 0.65, width: 1, height: 0.35), label: "Title & channel"),
            ]
        case .youtube:
            return [
                ScreenZone(rect: CGRect(x: 0, y: 0, width: 1, height: 0.067), label: "Title"),
                ScreenZone(rect: CGRect(x: 0, y: 0, width: 0.05, height: 1), label: "Left margin"),
                ScreenZone(rect: CGRect(x: 0.95, y: 0, width: 0.05, height: 1), label: "Right margin"),
                ScreenZone(rect: CGRect(x: 0, y: 0.892, width: 1, height: 0.108), label: "Controls & progress"),
            ]
        }
    }

    /// The rectangle no zone covers — a conservative "keep text inside here"
    /// box, normalized top-left: below the lowest top band, above the highest
    /// bottom band, and between the tall side zones (a margin or an action
    /// rail). A tall narrow zone limits the side it sits on; every other zone
    /// limits the top or the bottom by which half of the frame it sits in.
    public static func safeRect(for platform: Platform) -> CGRect {
        safeRect(clearOf: zones(for: platform))
    }

    /// The rectangle clear of every 9:16 platform at once: text inside it is
    /// safe wherever a vertical video is posted.
    public static var safeRectForAll: CGRect {
        Platform.vertical.map(safeRect(for:)).reduce(CGRect(x: 0, y: 0, width: 1, height: 1)) { $0.intersection($1) }
    }

    /// The rectangle clear of `zones` (see ``safeRect(for:)``).
    public static func safeRect(clearOf zones: [ScreenZone]) -> CGRect {
        let isSide = { (zone: ScreenZone) in zone.rect.width < 0.5 && zone.rect.height >= 0.2 }
        let sides = zones.filter(isSide)
        let bands = zones.filter { !isSide($0) }
        let top = bands.filter { $0.rect.midY < 0.5 }.map(\.rect.maxY).max() ?? 0
        let bottom = bands.filter { $0.rect.midY >= 0.5 }.map(\.rect.minY).min() ?? 1
        let left = sides.filter { $0.rect.midX < 0.5 }.map(\.rect.maxX).max() ?? 0
        let right = sides.filter { $0.rect.midX >= 0.5 }.map(\.rect.minX).min() ?? 1
        return CGRect(x: left, y: top, width: max(0, right - left), height: max(0, bottom - top))
    }
}

extension PlatformZones {

    /// `config` with its caption safe area widened to keep clear of
    /// `platform`'s interface: each margin is the larger of the canvas's own
    /// and the platform's (``safeRect(for:)``). A canvas of the other shape
    /// (a 16:9 canvas for a 9:16 platform) is returned unchanged — the zones
    /// are measured on the platform's own frame.
    public static func renderConfig(_ config: RenderConfig, clearOf platform: Platform) -> RenderConfig {
        guard config.height > 0 else { return config }
        let vertical = config.width < config.height
        guard vertical == platform.isVertical else { return config }
        let safe = safeRect(for: platform)
        var cleared = config
        cleared.safeAreaTop = max(config.safeAreaTop, safe.minY)
        cleared.safeAreaBottom = max(config.safeAreaBottom, 1 - safe.maxY)
        cleared.safeAreaLeft = max(config.safeAreaLeft, safe.minX)
        cleared.safeAreaRight = max(config.safeAreaRight, 1 - safe.maxX)
        return cleared
    }
}
