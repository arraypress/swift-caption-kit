//
//  PlatformZones.swift
//  CaptionKit
//
//  Created by David Sherlock on 2026.
//
//  Which parts of a 9:16 frame each platform's own interface covers, and the
//  rectangle left clear. The numbers came over from the caption studio's
//  pre-publish overlay: measured off the apps' layouts and rounded to whole
//  percents — "keep important text out of here", not a pixel-exact copy of
//  anyone's chrome.
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
                ScreenZone(rect: CGRect(x: 0.86, y: 0.42, width: 0.14, height: 0.42), label: "Actions"),
                ScreenZone(rect: CGRect(x: 0, y: 0.82, width: 0.80, height: 0.12), label: "Caption & audio"),
                ScreenZone(rect: CGRect(x: 0, y: 0.95, width: 1, height: 0.05), label: "Tab bar"),
            ]
        case .tiktok:
            return [
                ScreenZone(rect: CGRect(x: 0.22, y: 0.03, width: 0.56, height: 0.06), label: "Feed tabs"),
                ScreenZone(rect: CGRect(x: 0.86, y: 0.35, width: 0.14, height: 0.47), label: "Actions"),
                ScreenZone(rect: CGRect(x: 0, y: 0.80, width: 0.78, height: 0.13), label: "Caption & sound"),
                ScreenZone(rect: CGRect(x: 0, y: 0.94, width: 1, height: 0.06), label: "Tab bar"),
            ]
        case .shorts:
            return [
                ScreenZone(rect: CGRect(x: 0.70, y: 0.02, width: 0.30, height: 0.07), label: "Search & camera"),
                ScreenZone(rect: CGRect(x: 0.86, y: 0.42, width: 0.14, height: 0.42), label: "Actions"),
                ScreenZone(rect: CGRect(x: 0, y: 0.83, width: 0.80, height: 0.11), label: "Title & channel"),
                ScreenZone(rect: CGRect(x: 0, y: 0.94, width: 1, height: 0.06), label: "Tab bar"),
            ]
        }
    }

    /// The rectangle no zone covers — a conservative "keep text inside here"
    /// box, normalized top-left: below the lowest top band, above the highest
    /// bottom band, and left of the tall action rail. The rail (narrow and
    /// tall) only limits the right edge; every other zone limits the top or
    /// the bottom by which half of the frame it sits in.
    public static func safeRect(for platform: Platform) -> CGRect {
        safeRect(clearOf: zones(for: platform))
    }

    /// The rectangle clear of every platform at once: text inside it is safe
    /// wherever the video is posted.
    public static var safeRectForAll: CGRect {
        Platform.allCases.map(safeRect(for:)).reduce(CGRect(x: 0, y: 0, width: 1, height: 1)) { $0.intersection($1) }
    }

    /// The rectangle clear of `zones` (see ``safeRect(for:)``).
    public static func safeRect(clearOf zones: [ScreenZone]) -> CGRect {
        let isRail = { (zone: ScreenZone) in zone.rect.width < 0.5 && zone.rect.height >= 0.2 }
        let rail = zones.filter(isRail)
        let bands = zones.filter { !isRail($0) }
        let top = bands.filter { $0.rect.midY < 0.5 }.map(\.rect.maxY).max() ?? 0
        let bottom = bands.filter { $0.rect.midY >= 0.5 }.map(\.rect.minY).min() ?? 1
        let right = rail.map(\.rect.minX).min() ?? 1
        return CGRect(x: 0, y: top, width: right, height: max(0, bottom - top))
    }
}
