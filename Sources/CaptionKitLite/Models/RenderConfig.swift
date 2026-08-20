//
//  RenderConfig.swift
//  CaptionKitLite
//
//  Created by David Sherlock on 2026.
//

import CoreGraphics
import Foundation

/// The output canvas: resolution, frame rate, and the safe area captions must
/// stay inside.
///
/// The renderer always works at this pixel size; the preview *displays* the
/// result scaled, it never re-renders at a different size. That is half of
/// the preview/export parity guarantee (the other half is the single
/// `render` function).
public struct RenderConfig: Codable, Equatable, Sendable {

    /// Output width in pixels.
    public var width: Int

    /// Output height in pixels.
    public var height: Int

    /// Export frame rate. Playback previews at the player's own rate.
    public var framesPerSecond: Double

    /// Normalized insets (fractions of width/height) that captions are
    /// clamped inside — keeps text clear of TikTok/Reels/Shorts UI.
    public var safeAreaTop: CGFloat
    public var safeAreaBottom: CGFloat
    public var safeAreaLeft: CGFloat
    public var safeAreaRight: CGFloat

    public init(
        width: Int = 1080,
        height: Int = 1920,
        framesPerSecond: Double = 30,
        safeAreaTop: CGFloat = 0.10,
        safeAreaBottom: CGFloat = 0.12,
        safeAreaLeft: CGFloat = 0.05,
        safeAreaRight: CGFloat = 0.05
    ) {
        self.width = width
        self.height = height
        self.framesPerSecond = framesPerSecond
        self.safeAreaTop = safeAreaTop
        self.safeAreaBottom = safeAreaBottom
        self.safeAreaLeft = safeAreaLeft
        self.safeAreaRight = safeAreaRight
    }

    /// The canvas size in pixels.
    public var size: CGSize {
        CGSize(width: width, height: height)
    }

    /// The pixel rect captions must stay inside, in **top-left-origin**
    /// coordinates.
    public var safeAreaRect: CGRect {
        let w = CGFloat(width)
        let h = CGFloat(height)
        return CGRect(
            x: w * safeAreaLeft,
            y: h * safeAreaTop,
            width: w * (1 - safeAreaLeft - safeAreaRight),
            height: h * (1 - safeAreaTop - safeAreaBottom)
        )
    }

    // MARK: - Presets

    /// 1080×1920 (9:16) at 30 fps — TikTok / Reels / Shorts.
    public static let reel = RenderConfig()

    /// 1080×1080 (1:1) at 30 fps.
    public static let square = RenderConfig(width: 1080, height: 1080)

    /// 1920×1080 (16:9) at 30 fps.
    public static let landscape = RenderConfig(width: 1920, height: 1080, safeAreaBottom: 0.08)
}
