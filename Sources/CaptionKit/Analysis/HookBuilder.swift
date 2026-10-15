//
//  HookBuilder.swift
//  CaptionKit
//
//  Created by David Sherlock on 2026.
//

import CoreGraphics
import Foundation

/// Builds a hook title that needs no one to look at it: placed by rule and
/// measured.
///
/// - **Where.** Inside the platform safe zone (``PlatformZones``) within the
///   canvas safe area, clear of every face found in the frames it covers and
///   of every caption on screen with it, as near the upper third as that
///   allows. When it does not fit, the type steps down in size; when even the
///   smallest size cannot clear everything, the least-overlapping height is
///   used and the report says so.
/// - **Contrast.** The footage behind the title is measured (WCAG relative
///   luminance, the worst-case 90th — or for dark text 10th — percentile over
///   the sampled frames). Below WCAG's 3:1 for large text, a plate goes behind
///   the type, just dark (or light) enough to reach 4.5:1.
///
/// Everything it decided is in the ``HookReport``, which `caption check`
/// prints and tests assert against.
public enum HookBuilder {

    /// The default time on screen, in seconds of output.
    public static let defaultDuration: TimeInterval = 2.5

    /// The type sizes tried, as fractions of the template's, largest first.
    static let scales: [CGFloat] = [1, 0.9, 0.8, 0.7, 0.6]

    /// How far a face is kept from the title, normalized.
    static let facePadding: CGFloat = 0.03

    /// How far a caption block is kept from the title, normalized.
    static let captionPadding: CGFloat = 0.015

    /// A hook titled `text` in `template`'s look for `document`.
    ///
    /// - Parameters:
    ///   - text: The title.
    ///   - template: Its look. Default ``HookTemplates/defaultName``.
    ///   - document: The built document — its captions, canvas, crop, cuts
    ///     and video are what the title is placed against.
    ///   - duration: Seconds of output on screen.
    ///   - platform: Whose interface to keep clear of; `nil` keeps clear of
    ///     every platform's on a 9:16 canvas, and only the canvas safe area
    ///     on any other shape.
    public static func build(
        text: String,
        template: HookTemplate? = nil,
        document: CaptionDocument,
        duration: TimeInterval = defaultDuration,
        platform: Platform? = nil
    ) async -> (hook: HookTitle, report: HookReport) {
        let template = template ?? HookTemplates.named(HookTemplates.defaultName) ?? HookTemplates.all[0]
        let config = document.renderConfig
        let timeMap = document.timeMap
        let start = timeMap.sourceTime(forOutput: 0)
        let end = max(start + 0.1, timeMap.sourceTime(forOutput: max(0.1, duration)))
        let safe = safeRect(config: config, platform: platform)

        var style = HookTemplates.style(of: template)
        style.maxWidthFraction = usableWidth(safe)
        let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        var hook = HookTitle(text: words.joined(separator: " "), start: start, end: end, style: style, safeRect: safe,
                             lineBreaks: HookText.lineBreaks(for: words))

        // What is on screen with it.
        let samples = (0..<5).map { start + (end - start) * (Double($0) + 0.5) / 5 }
        let frames = await CanvasFrames.frames(for: document, at: samples)
        let faces = frames.flatMap { CanvasFrames.faces(in: $0.image) }.map { HookPlacement.padded($0, by: facePadding) }
        var captions: [CGRect] = []
        var time = start
        while time < end {
            if let block = CaptionRenderer.captionBlockRect(document: document, at: time) {
                captions.append(HookPlacement.padded(block, by: captionPadding))
            }
            time += 0.1
        }
        let obstacles = faces + captions

        // Place, measure contrast, and when a plate goes on, place again — a
        // plate's padding makes the title larger.
        var placement = place(&hook, baseSize: style.fontSize, safe: safe, obstacles: obstacles, config: config)
        var contrast = measureContrast(hook, frames: frames, config: config)
        var plateAlpha: Double?
        if contrast.ratio < Contrast.largeTextMinimum, hook.style.background == nil {
            let alpha = Contrast.plateAlpha(text: contrast.text, background: contrast.background) ?? Contrast.maximumPlateAlpha
            let plate = Contrast.plateLuminance(forText: contrast.text) == 0 ? StyleColor.black : StyleColor.white
            hook.style.background = BackgroundStyle(color: plate.withAlpha(alpha), cornerRadius: 16,
                                                    paddingHorizontal: 30, paddingVertical: 14, mode: .block)
            placement = place(&hook, baseSize: style.fontSize, safe: safe, obstacles: obstacles, config: config)
            contrast = measureContrast(hook, frames: frames, config: config)
            plateAlpha = alpha
        }

        let rect = CaptionRenderer.hookRect(hook, config: config) ?? .zero
        let report = HookReport(
            text: hook.text, template: template.name, start: start, end: end,
            safeRect: safe, titleRect: rect,
            insideSafeZone: safe.insetBy(dx: -0.001, dy: -0.001).contains(rect),
            faces: faces.count, faceOverlap: Double(HookPlacement.overlapFraction(of: rect, with: faces)),
            captionOverlap: Double(HookPlacement.overlapFraction(of: rect, with: captions)),
            contrast: contrast.ratio, plateAlpha: plateAlpha, scale: Double(placement.scale),
            placed: placement.clear, framesSampled: frames.count
        )
        return (hook, report)
    }

    /// The share (`0…1`) of `hook`'s words that on-device text recognition
    /// reads back off the finished frame — footage, captions and title
    /// together, as the export draws them — once the title has settled.
    /// `nil` when the frame cannot be drawn.
    public static func readBack(_ hook: HookTitle, document: CaptionDocument) async -> Double? {
        let time = hook.start + (hook.end - hook.start) * 0.6
        var document = document
        document.hook = hook
        guard let rect = CaptionRenderer.hookRect(hook, config: document.renderConfig),
              let frame = await CanvasFrames.frames(for: document, at: [time], width: document.renderConfig.width).first,
              let overlay = CaptionRenderer.renderOverlay(document: document, at: time),
              let composed = composite(frame.image, overlay) else { return nil }
        return TextLegibility.readFraction(of: hook.text, in: composed, rect: HookPlacement.padded(rect, by: 0.01))
    }

    /// `overlay` drawn over `footage`, both at `footage`'s size.
    static func composite(_ footage: CGImage, _ overlay: CGImage) -> CGImage? {
        let width = footage.width, height = footage.height
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        context.draw(footage, in: bounds)
        context.draw(overlay, in: bounds)
        return context.makeImage()
    }

    /// The rectangle a title is kept inside: the platform's safe zone (every
    /// platform's on a 9:16 canvas when none is named) within the canvas safe
    /// area. Normalized, top-left.
    public static func safeRect(config: RenderConfig, platform: Platform?) -> CGRect {
        let size = config.size
        let canvasSafe = CGRect(x: config.safeAreaRect.minX / size.width, y: config.safeAreaRect.minY / size.height,
                                width: config.safeAreaRect.width / size.width, height: config.safeAreaRect.height / size.height)
        let vertical = size.height > 0 && abs(size.width / size.height - 9.0 / 16.0) < 0.02
        let zone: CGRect
        if let platform {
            zone = PlatformZones.safeRect(for: platform)
        } else if vertical {
            zone = PlatformZones.safeRectForAll
        } else {
            return canvasSafe
        }
        let both = canvasSafe.intersection(zone)
        return both.isNull ? canvasSafe : both
    }

    // MARK: - Steps

    /// The widest a title may be and still sit centred in `safe` — or the
    /// whole safe width, when centring would leave less than 60% of the frame.
    static func usableWidth(_ safe: CGRect) -> CGFloat {
        let centred = 2 * min(0.5 - safe.minX, safe.maxX - 0.5)
        return centred >= 0.6 ? centred : safe.width
    }

    /// Sizes and positions `hook`: the largest scale whose block fits clear
    /// of `obstacles`, or the least-overlapping spot at the smallest scale.
    @discardableResult
    static func place(_ hook: inout HookTitle, baseSize: CGFloat, safe: CGRect, obstacles: [CGRect],
                      config: RenderConfig) -> (scale: CGFloat, clear: Bool) {
        let widest = usableWidth(safe)
        for scale in scales {
            hook.style.fontSize = baseSize * scale
            hook.style.position = NormalizedPoint(x: 0.5, y: 0.5)
            fitWidth(&hook, within: widest, config: config)
            guard let size = CaptionRenderer.hookRect(hook, config: config)?.size else { continue }
            if let center = HookPlacement.center(size: size, safe: safe, obstacles: obstacles) {
                hook.style.position = NormalizedPoint(x: center.x, y: center.y)
                return (scale, true)
            }
        }
        let smallest = scales.last ?? 1
        hook.style.fontSize = baseSize * smallest
        hook.style.position = NormalizedPoint(x: 0.5, y: 0.5)
        fitWidth(&hook, within: widest, config: config)
        let size = CaptionRenderer.hookRect(hook, config: config)?.size ?? .zero
        let center = HookPlacement.leastOverlapping(size: size, safe: safe, obstacles: obstacles)
        hook.style.position = NormalizedPoint(x: center.x, y: center.y)
        return (smallest, false)
    }

    /// Narrows the text block until the whole title — plate padding and
    /// outline included — is no wider than `width`. The layout fits the text
    /// alone to ``CaptionStyle/maxWidthFraction``, so the padding is taken off it.
    static func fitWidth(_ hook: inout HookTitle, within width: CGFloat, config: RenderConfig) {
        hook.style.maxWidthFraction = width
        guard let measured = CaptionRenderer.hookRect(hook, config: config)?.width, measured > width else { return }
        hook.style.maxWidthFraction = max(0.1, width - (measured - width) - 0.002)
    }

    /// The title's text luminance, the worst-case footage luminance behind
    /// it (a plate composited in), and their WCAG ratio.
    static func measureContrast(_ hook: HookTitle, frames: [CanvasFrames.Frame],
                                config: RenderConfig) -> (text: Double, background: Double, ratio: Double) {
        let text = Contrast.luminance(hook.style.textColor)
        let light = Contrast.plateLuminance(forText: text) == 0
        var background: Double
        if let rect = CaptionRenderer.hookRect(hook, config: config) {
            let values = frames.flatMap { Contrast.luminances(in: $0.image, rect: CanvasFrames.pixels(rect, in: $0.image)) }
            // Light text fails on the brightest footage, dark text on the darkest.
            background = Contrast.percentile(values, light ? 0.9 : 0.1) ?? (light ? 1 : 0)
        } else {
            background = light ? 1 : 0
        }
        if let plate = hook.style.background {
            background = Contrast.composited(background: background, plate: Contrast.luminance(plate.color),
                                             alpha: plate.color.alpha)
        }
        return (text, background, Contrast.ratio(text, background))
    }
}
