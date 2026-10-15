//
//  CaptionRenderer.swift
//  CaptionKit
//
//  Created by David Sherlock on 2026.
//

@_spi(CaptionEngine) import CaptionCore
import CoreGraphics
import CoreImage
import CoreText
import Foundation
import ImageIO

/// Draws captions. The **only** place in the entire system where a caption is
/// rendered.
///
/// ``draw(document:in:at:)`` is a pure, deterministic function of
/// `(document, time)`: no `CATextLayer`, no `CAAnimation`, no
/// `AVVideoCompositionCoreAnimationTool`, no hidden state. The preview calls
/// it every display frame; the exporter calls it for every video frame. Both
/// consumers therefore produce identical pixels by construction — this is the
/// parity guarantee the whole product rests on. Never add a second drawing
/// path.
public enum CaptionRenderer {

    // MARK: - Public API

    /// Draws the caption state at `time` into a CoreGraphics context sized to
    /// the document's render config.
    ///
    /// The context uses standard CG coordinates (origin bottom-left). The
    /// exporter passes a context wrapping the output pixel buffer;
    /// ``renderOverlay(document:at:)`` passes a fresh transparent bitmap.
    public static func draw(document: CaptionDocument, in context: CGContext, at time: TimeInterval) {
        draw(document: document, in: context, at: time, layers: .all)
    }

    /// Which part of the overlay to draw. A caption that goes behind the
    /// speaker is drawn in two passes — ``captions``, then the person laid
    /// back over it, then ``titles`` — so the hook title and the frame chrome
    /// stay in front. Every other consumer draws ``all``.
    public enum Layers: Sendable {
        /// Everything, in order.
        case all
        /// The letterbox and the caption card.
        case captions
        /// What sits above the captions: the hook title, the progress bar and the border.
        case titles
    }

    /// Draws one part of the caption state at `time` (see ``Layers``).
    public static func draw(document: CaptionDocument, in context: CGContext, at time: TimeInterval, layers: Layers) {
        if layers != .titles {
            // Letterbox bars sit under the captions/stickers so a caption can rest
            // on the lower bar (the classic cinematic subtitle placement).
            if let ratio = document.letterbox, ratio > 0 {
                drawLetterbox(ratio: CGFloat(ratio), size: document.renderConfig.size, in: context)
            }
            // The timing offset shifts CAPTIONS only (negative = slightly early,
            // the "snappy" trick); stickers and the progress bar stay absolute.
            let captionTime = time - document.captionTimingOffset
            if document.trackEnabled(.captions), let card = document.card(at: captionTime) {
                drawCard(card, document: document, in: context, at: captionTime)
            }
        }
        guard layers != .captions else { return }
        // The hook title rides above the captions, on the footage's clock.
        if document.trackEnabled(.titles), let hook = document.hook, HookCard.isVisible(hook, at: time) {
            drawCard(HookCard.card(for: hook), document: HookCard.document(for: hook, config: document.renderConfig),
                     in: context, at: time)
        }
        // Stickers, placed by rule, on the footage's clock like the hook.
        StickerRenderer.draw(document: document, in: context, at: time)
        drawProgressBar(document: document, in: context, at: time)
        // Border frame is the outermost layer — a clean edge around everything.
        if let border = document.videoBorder, border.width > 0 {
            drawBorder(border, size: document.renderConfig.size, in: context)
        }
    }

    private static func drawBorder(_ border: BorderStyle, size: CGSize, in context: CGContext) {
        let width = border.width * (size.height / CaptionLayout.referenceHeight)
        guard width > 0.5 else { return }
        context.setFillColor(border.color.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: size.width, height: width))                 // bottom
        context.fill(CGRect(x: 0, y: size.height - width, width: size.width, height: width)) // top
        context.fill(CGRect(x: 0, y: 0, width: width, height: size.height))                // left
        context.fill(CGRect(x: size.width - width, y: 0, width: width, height: size.height)) // right
    }

    private static func drawLetterbox(ratio: CGFloat, size: CGSize, in context: CGContext) {
        let canvasAspect = size.width / size.height
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        if ratio > canvasAspect {
            // Wider target → horizontal bars top and bottom.
            let bar = (size.height - size.width / ratio) / 2
            guard bar > 0.5 else { return }
            context.fill(CGRect(x: 0, y: 0, width: size.width, height: bar))
            context.fill(CGRect(x: 0, y: size.height - bar, width: size.width, height: bar))
        } else if ratio < canvasAspect {
            // Narrower target → pillar bars left and right.
            let bar = (size.width - size.height * ratio) / 2
            guard bar > 0.5 else { return }
            context.fill(CGRect(x: 0, y: 0, width: bar, height: size.height))
            context.fill(CGRect(x: size.width - bar, y: 0, width: bar, height: size.height))
        }
    }

    private static func drawProgressBar(document: CaptionDocument, in context: CGContext, at time: TimeInterval) {
        guard let bar = document.progressBar,
              let duration = document.videoDuration, duration > 0 else { return }
        let size = document.renderConfig.size
        let referenceScale = size.height / CaptionLayout.referenceHeight
        let height = max(2, bar.height * referenceScale)
        let width = size.width * CGFloat(Easing.clamp01(time / duration))
        guard width > 1 else { return }
        let rect = CGRect(
            x: 0,
            y: bar.top ? size.height - height : 0,
            width: width,
            height: height
        )
        context.setFillColor(bar.color.cgColor)
        context.fill(rect)
    }

    /// The whole-block entrance transform at `time` — shared by the drawing
    /// and the overlay-cache signature so they can never disagree.
    private static func cardAnimation(card: CaptionCard, style: CaptionStyle, layout: CardLayout, at time: TimeInterval) -> (alpha: Double, dx: CGFloat, dy: CGFloat, scale: CGFloat) {
        guard style.cardAnimation != .none else { return (1, 0, 0, 1) }
        let p = Easing.progress(time, from: card.start, duration: max(0.01, style.animationDuration) * 1.5)
        let eased = Easing.easeOutCubic(p)
        var alpha: Double = 1, scale: CGFloat = 1, dy: CGFloat = 0, dx: CGFloat = 0
        switch style.cardAnimation {
        case .none: break
        case .fadeIn: alpha = eased
        case .slideUp: alpha = eased; dy = -(1 - eased) * 0.6 * layout.lineAdvance
        case .slideDown: alpha = eased; dy = (1 - eased) * 0.6 * layout.lineAdvance
        case .popOn: alpha = min(1, p * 3); scale = CGFloat(max(0.02, Easing.easeOutBack(p)))
        case .stomp: alpha = min(1, p * 5); scale = 1 + 1.2 * (1 - eased)
        case .slideInLeft: alpha = min(1, p * 2.5); dx = -(1 - eased) * (layout.blockRect.maxX + layout.fontPixelSize)
        }
        return (alpha, dx, dy, scale)
    }

    private static func drawCard(_ card: CaptionCard, document: CaptionDocument, in context: CGContext, at time: TimeInterval) {
        let style = document.resolvedStyle(for: card)
        guard style.opacity > 0,
              let layout = CaptionLayout.layout(card: card, style: style, config: document.renderConfig) else { return }

        let active = card.activeWordIndex(at: time)
        let states = card.words.indices.map { index in
            wordState(
                index: index,
                card: card,
                style: style,
                document: document,
                layout: layout,
                time: time,
                active: active
            )
        }
        guard states.contains(where: \.visible) else { return }

        // Whole-block entrance, on top of any per-word animation. (Computed
        // before the shadow so the baked-shadow key can include it.)
        let anim = cardAnimation(card: card, style: style, layout: layout, at: time)
        // The speaker's name and a second-language line, drawn with the card.
        let extras = cardExtras(card: card, style: style, layout: layout, document: document)

        // A crawling circle warp spins with absolute time; every consumer of
        // the warped geometry below shares this one phase.
        let phase = warpPhase(style.textWarp, at: time)

        context.saveGState()
        // Identical rasterization in every consumer: no subpixel font
        // smoothing (it depends on the destination's opacity/backing).
        context.setShouldSmoothFonts(false)
        context.setAllowsFontSmoothing(false)
        context.setShouldAntialias(true)
        context.interpolationQuality = .high

        // Shadow + opacity apply to the composed card (pill and text cast one
        // clean shadow instead of stacking per-word shadows). The implicit CG
        // shadow re-blurs the whole composed layer on EVERY render — during a
        // karaoke hold that ran per frame even though the SILHOUETTE (glyph
        // shapes, boxes — not fill colors) never changed. Bake the shadow once
        // per silhouette state and composite the cached image instead; the
        // implicit path stays as the fallback.
        if style.knockoutPlate == nil, let shadow = style.shadow {
            if let baked = cardShadow(card: card, style: style, layout: layout,
                                      states: states, anim: anim, extras: extras, shadow: shadow, phase: phase, time: time) {
                // The implicit shadow's strength scales with the group alpha.
                context.saveGState()
                context.setAlpha(style.opacity * CGFloat(anim.alpha))
                context.draw(baked.image, in: baked.rect)
                context.restoreGState()
            } else {
                context.setShadow(
                    offset: CGSize(
                        width: shadow.offsetX * layout.referenceScale,
                        height: -shadow.offsetY * layout.referenceScale
                    ),
                    blur: shadow.radius * layout.referenceScale,
                    color: shadow.color.cgColor
                )
            }
        }
        // Whole-block rotation: the tilted-caption look. CG is y-up, so a
        // screen-clockwise rotation is a negative CG angle.
        let rotation = blockRotation(for: card, style: style)
        if rotation != 0 {
            let center = CGPoint(x: layout.blockRect.midX, y: layout.blockRect.midY)
            context.translateBy(x: center.x, y: center.y)
            context.rotate(by: -rotation)
            context.translateBy(x: -center.x, y: -center.y)
        }
        if anim.scale != 1 || anim.dy != 0 || anim.dx != 0 {
            let center = CGPoint(x: layout.blockRect.midX, y: layout.blockRect.midY)
            context.translateBy(x: center.x + anim.dx, y: center.y + anim.dy)
            context.scaleBy(x: anim.scale, y: anim.scale)
            context.translateBy(x: -center.x, y: -center.y)
        }

        context.setAlpha(style.opacity * CGFloat(anim.alpha))
        context.beginTransparencyLayer(auxiliaryInfo: nil)

        if let plate = style.knockoutPlate {
            // Knockout: a solid plate with the letterforms cut out — footage
            // shows only through the type. Replaces text + background.
            drawKnockoutPlate(
                plate, canvas: document.renderConfig.size,
                style: style, layout: layout, states: states, phase: phase, in: context
            )
        } else {
            drawBackground(card: card, style: style, layout: layout, states: states,
                           in: context, phase: phase, elapsed: time - card.start, extraRect: extras.backgroundRect)
            drawExtras(extras, in: context)

            for slot in layout.words {
                let state = states[slot.index]
                guard state.visible else { continue }
                drawWord(slot: slot, state: state, style: style, layout: layout,
                         in: context, phase: phase, time: time)
            }
        }

        context.endTransparencyLayer()
        context.restoreGState()
    }

    /// The knockout plate: one huge rect (padded far past the canvas so a
    /// block rotation can't reveal its edge) filled even-odd against every
    /// visible word's glyph path — the letters become holes. Each hole rides
    /// its word's entrance/exit/loop transform, so words pop in as windows.
    private static func drawKnockoutPlate(
        _ plate: StyleColor,
        canvas: CGSize,
        style: CaptionStyle,
        layout: CardLayout,
        states: [WordState],
        phase: CGFloat,
        in context: CGContext
    ) {
        let holes = CGMutablePath()
        for slot in layout.words {
            let state = states[slot.index]
            guard state.visible else { continue }

            // The word's glyph outline: warped when a warp is active, else
            // the straight glyphs at the baseline.
            let glyphs: CGPath
            if let warp = style.textWarp {
                glyphs = warpedPath(for: slot, layout: layout, warp: warp, phase: phase)
            } else {
                let path = CGMutablePath()
                for glyph in glyphOutlines(slot.fillLine) {
                    path.addPath(glyph.path, transform: CGAffineTransform(
                        translationX: slot.baselineOrigin.x + glyph.dx,
                        y: slot.baselineOrigin.y + glyph.dy
                    ))
                }
                glyphs = path
            }
            guard !glyphs.isEmpty else { continue }

            // The same animated transform drawWord applies (alpha/reveal
            // don't map to a binary hole and are ignored).
            let wordStyle = slot.word.style
            let staticRotation = wordStyle?.rotation ?? 0
            let staticDY = (wordStyle?.baselineOffset ?? 0) * layout.referenceScale
            let center = CGPoint(
                x: slot.frame.midX + CGFloat(state.xOffset),
                y: slot.frame.midY + CGFloat(state.yOffset) + staticDY
            )
            var transform = CGAffineTransform.identity
                .translatedBy(x: center.x, y: center.y)
                .rotated(by: CGFloat(state.rotation) + staticRotation)
                .scaledBy(x: CGFloat(state.scale), y: CGFloat(state.scale * state.scaleY))
                .translatedBy(x: -slot.frame.midX, y: -slot.frame.midY)
            if let transformed = glyphs.copy(using: &transform) {
                holes.addPath(transformed)
            }
        }

        let plateRect = CGRect(origin: .zero, size: canvas)
            .insetBy(dx: -canvas.width, dy: -canvas.height)
        context.saveGState()
        context.beginPath()
        context.addRect(plateRect)
        context.addPath(holes)
        context.setFillColor(plate.cgColor)
        context.fillPath(using: .evenOdd)
        context.restoreGState()
    }

    /// Renders the caption state at `time` as a transparent image at the
    /// render resolution — the preview surface displays this (scaled by the
    /// view system, never re-rendered) over the playing video.
    /// Renders the caption overlay to a transparent bitmap. `scale` (0…1)
    /// renders at a fraction of the canvas resolution — the live preview only
    /// needs display resolution, so rendering full 1080p+ every frame is wasted
    /// work. Export and any pixel-exact use pass `scale: 1`.
    public static func renderOverlay(document: CaptionDocument, at time: TimeInterval, scale: CGFloat = 1, cacheVersion: Int = 0) -> CGImage? {
        renderOverlay(document: document, at: time, scale: scale, cacheVersion: cacheVersion, layers: .all)
    }

    /// Renders one part of the overlay (see ``Layers``); only ``Layers/all``
    /// is ever cached.
    public static func renderOverlay(document: CaptionDocument, at time: TimeInterval, scale: CGFloat = 1,
                                     cacheVersion: Int = 0, layers: Layers) -> CGImage? {
        let config = document.renderConfig
        let s = max(0.05, min(1, scale))
        let width = max(1, Int((CGFloat(config.width) * s).rounded()))
        let height = max(1, Int((CGFloat(config.height) * s).rounded()))

        // Overlay cache (preview only — `cacheVersion != 0`): the caller passes
        // its document version, so an edit forces a miss. Within a version only
        // time-varying state changes, captured by the signature (nil = don't
        // cache — a progress bar / animated overlay sticker changes each frame).
        var signature: Int?
        if cacheVersion != 0, layers == .all {
            signature = overlayCacheSignature(document: document, at: time)
            if let sig = signature {
                overlayCacheLock.lock()
                let hit = overlayCache.first { $0.version == cacheVersion && $0.widthPx == width && $0.heightPx == height && $0.signature == sig }?.image
                overlayCacheLock.unlock()
                if let hit { return hit }
            }
        }

        guard let context = makeBitmapContext(width: width, height: height) else { return nil }
        context.scaleBy(x: CGFloat(width) / CGFloat(config.width), y: CGFloat(height) / CGFloat(config.height))
        draw(document: document, in: context, at: time, layers: layers)
        let image = context.makeImage()

        if let image, let sig = signature {
            overlayCacheLock.lock()
            overlayCache.removeAll { $0.version != cacheVersion }   // drop stale versions
            overlayCache.insert(OverlayCacheEntry(version: cacheVersion, widthPx: width, heightPx: height, signature: sig, image: image), at: 0)
            if overlayCache.count > overlayCacheLimit { overlayCache.removeLast(overlayCache.count - overlayCacheLimit) }
            overlayCacheLock.unlock()
        }
        return image
    }

    // MARK: - Overlay image cache

    private struct OverlayCacheEntry {
        let version: Int
        let widthPx: Int
        let heightPx: Int
        let signature: Int
        let image: CGImage
    }
    /// Flushes every render cache (layouts + composed overlays + gradients).
    /// Call after runtime font registration so nothing serves pre-registration
    /// glyphs.
    public static func flushRenderCaches() {
        CaptionLayout.flush()
        flushWordSprites()
        flushCardShadows()
        flushWarpPaths()
        overlayCacheLock.lock(); overlayCache.removeAll(); overlayCacheLock.unlock()
        gradientLock.lock(); gradientCache.removeAll(); gradientLock.unlock()
    }

    private static let overlayCacheLock = NSLock()
    nonisolated(unsafe) private static var overlayCache: [OverlayCacheEntry] = []
    private static let overlayCacheLimit = 6

    /// A hash of everything in the overlay that varies with TIME, or nil when
    /// the overlay isn't safe to cache across frames. Style/content is constant
    /// within a document version (the caller keys on version), so only the
    /// time-varying state is hashed — via the same `wordState`/`cardAnimation`/
    /// `stickerRenderEffects`/`titleRenderState` the drawing uses, so the two
    /// can't disagree. A static sticker hashes to the same value every frame
    /// (cache hits); an animating one changes per frame (correct misses).
    private static func overlayCacheSignature(document: CaptionDocument, at time: TimeInterval) -> Int? {
        // A progress bar advances every frame — every frame unique, don't cache.
        if document.progressBar != nil { return nil }
        // Stickers may animate; drawn fresh every frame.
        if document.placedStickers?.isEmpty == false { return nil }

        var hasher = Hasher()
        hasher.combine("overlay")
        let captionTime = time - document.captionTimingOffset
        if document.trackEnabled(.captions), let card = document.card(at: captionTime) {
            let style = document.resolvedStyle(for: card)
            if let layout = CaptionLayout.layout(card: card, style: style, config: document.renderConfig) {
                hasher.combine(card.id)
                let active = card.activeWordIndex(at: captionTime)
                let states = card.words.indices.map {
                    wordState(index: $0, card: card, style: style, document: document, layout: layout, time: captionTime, active: active)
                }
                hasher.combine(states)
                let anim = cardAnimation(card: card, style: style, layout: layout, at: captionTime)
                hasher.combine(anim.alpha); hasher.combine(anim.dx); hasher.combine(anim.dy); hasher.combine(anim.scale)
                // A crawling ring changes pixels with no word-state change.
                let phase = warpPhase(style.textWarp, at: captionTime)
                if phase != 0 { hasher.combine(Int((phase * 3600).rounded())) }
                // As do a mid-flight letter cascade and a background drawing on.
                if let clock = silhouetteClock(card: card, style: style, at: captionTime) {
                    hasher.combine(clock)
                }
            } else {
                hasher.combine(0)   // nothing lays out → empty caption layer
            }
        } else {
            hasher.combine(1)   // caption gap → empty overlay (letterbox/border static)
        }
        if document.trackEnabled(.titles), let hook = document.hook, HookCard.isVisible(hook, at: time) {
            let card = HookCard.card(for: hook)
            let hookDocument = HookCard.document(for: hook, config: document.renderConfig)
            if let layout = CaptionLayout.layout(card: card, style: hook.style, config: hookDocument.renderConfig) {
                hasher.combine(hook.id)
                let active = card.activeWordIndex(at: time)
                hasher.combine(card.words.indices.map {
                    wordState(index: $0, card: card, style: hook.style, document: hookDocument, layout: layout, time: time, active: active)
                })
                let anim = cardAnimation(card: card, style: hook.style, layout: layout, at: time)
                hasher.combine(anim.alpha); hasher.combine(anim.dx); hasher.combine(anim.dy); hasher.combine(anim.scale)
            }
        }
        return hasher.finalize()
    }



    /// A hook title's settled bounds — its text block plus any plate's
    /// padding and outline — normalized `0…1` with a **top-left** origin.
    /// What placement keeps clear of the face and the captions, and what
    /// `caption check` measures contrast and legibility inside. `nil` when
    /// the title lays out to nothing.
    public static func hookRect(_ hook: HookTitle, config: RenderConfig) -> CGRect? {
        let card = HookCard.card(for: hook)
        let hookDocument = HookCard.document(for: hook, config: config)
        guard let layout = CaptionLayout.layout(card: card, style: hook.style, config: hookDocument.renderConfig) else { return nil }
        let size = config.size
        var rect = displayBlockRect(layout, warp: hook.style.textWarp)
        let outline = max(0, hook.style.strokeWidth) * layout.referenceScale
        let padX = (hook.style.background?.paddingHorizontal ?? 0) * layout.referenceScale + outline
        let padY = (hook.style.background?.paddingVertical ?? 0) * layout.referenceScale + outline
        rect = rect.insetBy(dx: -padX, dy: -padY)
        return CGRect(
            x: rect.minX / size.width,
            y: 1 - rect.maxY / size.height,
            width: rect.width / size.width,
            height: rect.height / size.height
        )
    }

    /// The on-screen caption block's bounds at `time`, normalized `0…1` with
    /// a **top-left** origin — for editors drawing selection chrome around
    /// the caption. `nil` when no caption is visible.
    public static func captionBlockRect(document: CaptionDocument, at time: TimeInterval) -> CGRect? {
        guard document.trackEnabled(.captions) else { return nil }
        let time = time - document.captionTimingOffset
        guard let card = document.card(at: time) else { return nil }
        let style = document.resolvedStyle(for: card)
        guard let layout = CaptionLayout.layout(card: card, style: style, config: document.renderConfig) else { return nil }
        let size = document.renderConfig.size
        let rect = displayBlockRect(layout, warp: style.textWarp, phase: warpPhase(style.textWarp, at: time))
            .union(cardExtras(card: card, style: style, layout: layout, document: document).bounds)
        return CGRect(
            x: rect.minX / size.width,
            y: 1 - rect.maxY / size.height,
            width: rect.width / size.width,
            height: rect.height / size.height
        )
    }

    /// The visible caption's per-word rects at `time`, normalized `0…1`
    /// top-left — the hit targets for on-canvas inline word editing.
    public static func wordRects(
        document: CaptionDocument,
        at time: TimeInterval
    ) -> (cardID: UUID, rects: [(index: Int, rect: CGRect)])? {
        let time = time - document.captionTimingOffset
        guard let card = document.card(at: time) else { return nil }
        let style = document.resolvedStyle(for: card)
        guard let layout = CaptionLayout.layout(card: card, style: style, config: document.renderConfig) else { return nil }
        let size = document.renderConfig.size
        let warp = style.textWarp
        let phase = warpPhase(warp, at: time)
        let rects = layout.words.map { slot -> (Int, CGRect) in
            let frame = displayWordFrame(slot, layout: layout, warp: warp, phase: phase)
            return (slot.index, CGRect(
                x: frame.minX / size.width,
                y: 1 - frame.maxY / size.height,
                width: frame.width / size.width,
                height: frame.height / size.height
            ))
        }
        return (card.id, rects)
    }


    /// Creates a transparent sRGB bitmap context in CG coordinates.
    static func makeBitmapContext(width: Int, height: Int) -> CGContext? {
        CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }

    // MARK: - Word State

    /// Everything animated about one word at one instant, computed purely
    /// from timestamps.
    private struct WordState: Hashable {
        var visible = true
        var alpha: Double = 1
        var scale: Double = 1
        /// Extra vertical squash on top of `scale` (the flip-down entrance);
        /// total y scale is `scale * scaleY`.
        var scaleY: Double = 1
        var xOffset: Double = 0
        var yOffset: Double = 0
        /// Rotation around the word's center, in radians.
        var rotation: Double = 0
        /// Typewriter wipe: fraction of the word revealed (`1` = all of it).
        var reveal: Double = 1
        /// Focus-pull blur strength `0…1` (blur-in entrance/exit).
        var blur: Double = 0
        /// Motion-smear trail offset in pixels (smear-in entrance/exit).
        var smearDX: Double = 0
        /// Quantized weight-ramp step for the spoken word (`nil` = no ramp).
        var weightStep: Int?
        /// Quantized clock while any gradient in play hue-drifts
        /// (`nil` = static gradients — sprites cache normally).
        var driftClock: Int?
        /// The word's fill color right now.
        var color: StyleColor
        /// The word's resting fill color, before any temporal highlight recolor.
        /// A per-word gradient/image fill applies only while `color` still
        /// equals this — so a spoken-word highlight paints solid over it.
        var restingColor: StyleColor = .white
        /// Karaoke: fraction of the word filled with the highlight color
        /// (`nil` when not in a partial-fill state).
        var karaokeFraction: Double?
        var karaokeColor: StyleColor?
        /// A rounded box behind just this word (the active-box highlight).
        var boxColor: StyleColor?
        /// A gradient fill for the highlight box instead of a flat color.
        var boxGradient: GradientFill?
        /// An underline bar beneath this word.
        var underlineColor: StyleColor?
        /// Whether the style's glow applies to this word right now.
        var glows = false
    }

    private static func wordState(
        index: Int,
        card: CaptionCard,
        style: CaptionStyle,
        document: CaptionDocument,
        layout: CardLayout,
        time: TimeInterval,
        active: Int?
    ) -> WordState {
        let word = card.words[index]
        var state = WordState(color: style.textColor)
        let duration = max(0.01, style.animationDuration)

        // Any scale-up is capped so the word's growth stays within most of
        // one word gap — neighbors never collide, whatever the word width.
        // Slots are appended in index order (wordCursor), so direct indexing
        // replaces what was an O(n) scan per word per frame.
        let slotWidth = index < layout.words.count ? Double(layout.words[index].frame.width) : 0
        let maxUpscale = slotWidth > 0 ? 1 + 0.9 * Double(layout.spaceWidth) / slotWidth : 1

        // Entrance: per-word override wins over the global animation. Words
        // before their start moment are hidden (their layout slot is
        // reserved; lines never reflow as words appear).
        let entrance = word.style?.animation ?? style.wordAnimation
        var entranceSettled = true
        if entrance != .none {
            if time < word.start {
                state.visible = false
                return state
            }
            let p = Easing.progress(time, from: word.start, duration: duration)
            entranceSettled = p >= 1
            let effects = entranceEffects(entrance, progress: p, travel: Double(layout.lineAdvance), intensity: style.animationIntensity ?? 1)
            state.alpha *= effects.alpha
            state.scale *= effects.scale
            state.scaleY *= effects.scaleY
            state.xOffset += effects.dx
            state.yOffset += effects.dy
            state.rotation += effects.rotation
            state.reveal = effects.reveal
            state.blur = max(state.blur, effects.blur)
            state.smearDX += effects.smearDX
        }

        // Exit: the entrance curve run backwards over the card's final
        // moments — settled at q=1, gone at q=0. Rides on top of whatever
        // entrance already applied.
        if let exit = style.exitAnimation, exit != .none {
            let q = Easing.clamp01((card.end - time) / duration)
            if q < 1 {
                let out = entranceEffects(exit, progress: q, travel: Double(layout.lineAdvance), intensity: style.animationIntensity ?? 1)
                state.alpha *= out.alpha
                state.scale *= out.scale
                state.scaleY *= out.scaleY
                state.xOffset += out.dx
                state.yOffset += out.dy
                state.rotation += out.rotation
                state.reveal = min(state.reveal, out.reveal)
                state.blur = max(state.blur, out.blur)
                state.smearDX += out.smearDX
                entranceSettled = false // exit transients may pass neighbors
            }
        }

        // Multi-color words: rotate the palette across the card's words.
        // In Highlight Box mode the palette drives the BOX colors instead —
        // text stays flat (the colour-box look), never skittles.
        if let palette = style.wordColorPalette, !palette.isEmpty, style.highlightMode != .activeBox {
            state.color = palette[index % palette.count]
        }

        // Per-speaker colors (diarized interviews/podcasts): the document's,
        // else the style's own speaker palette.
        if let speakerColors = speakerPalette(document: document, style: style),
           let speaker = word.speaker, speaker >= 0 {
            state.color = speakerColors[speaker % speakerColors.count]
        }

        // Base color: a per-word override replaces the style's text color;
        // spoken-word highlights still apply on top (they're temporal).
        if let overrideColor = word.style?.color {
            state.color = overrideColor
        }

        // Ambient loop: phase-shifted per word so lines roll rather than
        // bounce in lockstep. Absolute-time driven — parity-safe.
        if let loop = style.wordLoop {
            let t = time * max(0.05, style.wordLoopSpeed ?? 1)   // speed scales the rate
            let phase = Double(index)                            // per-word roll offset
            let adv = Double(layout.lineAdvance)
            switch loop {
            case .wave:
                state.yOffset += sin(2 * .pi * t * 1.1 + phase * 0.9) * 0.06 * adv
            case .wiggle:
                state.rotation += sin(2 * .pi * t * 1.7 + phase * 1.3) * 0.045
            case .pulse:
                state.scale *= 1 + 0.04 * sin(2 * .pi * t * 1.4 + phase * 0.7)
            case .float:
                state.yOffset += sin(2 * .pi * t * 0.5 + phase * 0.5) * 0.05 * adv
            case .sway:
                state.xOffset += sin(2 * .pi * t * 0.6 + phase * 0.4) * 0.05 * adv
            case .bounce:
                state.yOffset += abs(sin(2 * .pi * t * 0.9 + phase * 0.6)) * 0.05 * adv
            case .breathe:
                state.scale *= 1 + 0.05 * sin(2 * .pi * t * 0.35 + phase * 0.3)
            case .shake:
                state.xOffset += sin(2 * .pi * t * 9 + phase) * 0.012 * adv
            case .jelly:
                // Squash-and-stretch in counter-phase, like set jelly.
                let s = sin(2 * .pi * t * 1.5 + phase * 0.8)
                state.scale *= 1 + 0.055 * s
                state.scaleY *= 1 - 0.10 * s
            }
        }

        // The resting color is now settled (palette / speaker / per-word
        // override applied). Temporal highlights below recolor `color` but not
        // this, so per-word gradient/image fills know when they still apply.
        state.restingColor = state.color

        // Spoken-word emphasis (computed once per card by the caller — it was
        // re-scanned per word).
        var highlightColor = style.activeWordColor ?? style.textColor
        // A colour-cycling highlight: each word the next colour, from a point
        // the card seeds so consecutive cards do not all open on the same one.
        if let palette = style.activeWordPalette, !palette.isEmpty {
            let offset = Int(SeededRandom.unit(Int((card.start * 1000).rounded()), 17) * Double(palette.count))
            highlightColor = palette[(index + offset) % palette.count]
        }
        // Key words, when the style highlights them: the card's emphasised
        // words wear the highlight for the whole card; with none, the voice leads.
        let lit: Bool
        if style.highlightKeyWords == true {
            let keyWords = card.words.indices.filter { card.words[$0].style?.color != nil }
            lit = keyWords.isEmpty ? index == active : keyWords.contains(index)
        } else {
            lit = index == active
        }
        switch style.highlightMode {
        case .none:
            break
        case .activeWord:
            if lit {
                state.color = highlightColor
            }
        case .karaoke:
            if word.end <= time {
                state.color = highlightColor
            } else if index == active, word.duration > 0 {
                let fraction = Easing.clamp01((time - word.start) / word.duration)
                state.karaokeFraction = fraction
                state.karaokeColor = highlightColor
            }
        case .activeBox:
            if lit {
                // The colour-box rotation: with a word palette set, the box
                // color cycles per word instead of staying fixed.
                if let palette = style.wordColorPalette, !palette.isEmpty {
                    state.boxColor = palette[index % palette.count]
                    state.color = style.textColor // text stays flat; the BOX carries the color
                } else {
                    state.boxColor = style.activeWordColor ?? .yellow
                }
                // A gradient box overrides the flat colour.
                state.boxGradient = style.activeBoxGradient
                // Optional inverse look: the word's text goes dark on a light pill.
                if let boxText = style.activeBoxTextColor {
                    state.color = boxText
                }
            }
        case .activeUnderline:
            if lit {
                state.underlineColor = style.activeWordColor ?? .yellow
            }
        case .spotlight:
            if index == active {
                state.color = highlightColor
            } else {
                state.alpha *= 0.35
            }
        }

        if let glow = style.glow {
            state.glows = glow.scope == .allWords || index == active
        }

        // Active-word pop: a brief pulse — up over one animation duration,
        // settling back over the next. The peak growth is clamped to most of
        // one word gap so a wide word never collides with its neighbors.
        if style.highlightMode != .none, style.activeWordScale != 1, index == active {
            let peak = min(Double(style.activeWordScale), maxUpscale) - 1
            if time < word.start + duration {
                state.scale *= 1 + peak * Easing.easeOutBack(Easing.progress(time, from: word.start, duration: duration))
            } else if time < word.start + 2 * duration {
                state.scale *= 1 + peak * (1 - Easing.easeOutCubic(Easing.progress(time, from: word.start + duration, duration: duration)))
            }
        }

        // Variable-font kinetics: the spoken word's weight ramps toward the
        // target across its duration (quantized so the ramped lines cache).
        // Karaoke is excluded — its fraction clip assumes fixed metrics.
        if style.activeWordWeightRamp != nil, style.highlightMode != .karaoke,
           index == active, word.duration > 0, style.mixedLetters == nil {
            let t = Easing.clamp01((time - word.start) / word.duration)
            state.weightStep = Int((t * 5).rounded())
        } else if style.weightRampHolds == true, style.activeWordWeightRamp != nil, style.highlightMode != .karaoke,
                  style.mixedLetters == nil, index != active,
                  word.end <= time || (active.map { index < $0 } ?? false) {
            // The weight sweep: a word already said stays at the target weight.
            state.weightStep = 5
        }

        // Hue-drifting gradients repaint on a quantized clock; static
        // gradients leave this nil so sprites cache normally.
        let driftRates: [CGFloat] = [
            style.textGradient?.drift ?? 0,
            word.style?.gradient?.drift ?? 0,
            style.activeBoxGradient?.drift ?? 0,
        ]
        if driftRates.contains(where: { $0 != 0 }) {
            state.driftClock = Int((time * 120).rounded())
        }

        // Keyword rules trump everything.
        if let rule = document.highlightRule(for: word) {
            state.color = rule.color
            state.karaokeFraction = nil
            state.karaokeColor = nil
            state.scale *= Double(rule.scale)
        }

        // The cap applies to the COMBINED scale — entrance overshoot, active
        // pulse, and keyword emphasis stack multiplicatively when they
        // coincide, and each being safe individually isn't enough. Entrance
        // transients are exempt: a stomp passing through its neighbors for a
        // fraction of a second is the aesthetic; sustained overlap is a bug.
        if entranceSettled {
            state.scale = min(state.scale, maxUpscale)
        }

        return state
    }

    // MARK: - Drawing

    private static func drawBackground(
        card: CaptionCard,
        style: CaptionStyle,
        layout: CardLayout,
        states: [WordState],
        in context: CGContext,
        phase: CGFloat = 0,
        elapsed: TimeInterval = .greatestFiniteMagnitude,
        extraRect: CGRect? = nil
    ) {
        guard let background = style.background else { return }
        let padH = background.paddingHorizontal * layout.referenceScale
        let padV = background.paddingVertical * layout.referenceScale
        let radius = background.cornerRadius * layout.referenceScale

        // Under a warp the straight block/line frames sit below the bent text;
        // fall back to the bounding box of the warped glyphs so the pill covers
        // (and, per-word, rides) the curve.
        let warp = style.textWarp

        // The optional pill outline (stroked-button look). Hairline default
        // when a color is set without a width.
        let strokeColor = background.strokeColor
        let strokePx = (background.strokeWidth ?? 3) * layout.referenceScale

        // Draw-on: the background sweeps in left→right over the card's
        // opening beats, like a highlighter being dragged.
        let reveal: CGFloat = background.drawOn == true
            ? CGFloat(Easing.clamp01(elapsed / 0.35))
            : 1

        func backgroundPath(_ rect: CGRect, radius: CGFloat) -> CGPath {
            if background.shape == .marker {
                return markerSwipePath(rect)
            }
            let clamped = min(radius, min(rect.width, rect.height) / 2)
            let path = CGMutablePath()
            path.addRoundedRect(in: rect, cornerWidth: clamped, cornerHeight: clamped)
            // Comic speech-bubble tail off the bottom edge.
            if background.tail == true, background.mode != .perWord {
                let h = rect.height
                let x = rect.minX + rect.width * 0.22
                path.move(to: CGPoint(x: x, y: rect.minY + 2))
                path.addLine(to: CGPoint(x: x + h * 0.42, y: rect.minY + 2))
                path.addLine(to: CGPoint(x: x - h * 0.12, y: rect.minY - h * 0.5))
                path.closeSubpath()
            }
            return path
        }

        func paintRoundedRect(_ rect: CGRect, radius: CGFloat) {
            context.saveGState()
            if reveal < 1 {
                context.clip(to: CGRect(
                    x: rect.minX - padH * 2,
                    y: rect.minY - rect.height * 2,
                    width: (rect.width + padH * 4) * reveal,
                    height: rect.height * 5
                ))
            }
            let path = backgroundPath(rect, radius: radius)
            context.setFillColor(background.color.cgColor)
            context.addPath(path)
            context.fillPath()
            if let strokeColor, strokePx > 0 {
                context.setStrokeColor(strokeColor.cgColor)
                context.setLineWidth(strokePx)
                context.setLineJoin(.round)
                context.addPath(path)
                context.strokePath()
            }
            context.restoreGState()
        }

        context.setFillColor(background.color.cgColor)
        switch background.mode {
        case .block where warp != nil, .perLine where warp != nil:
            // Under a warp, a straight pill can't hug the curve — trace each
            // line's centerline and stroke it thick with round caps, so the
            // background is a pill that bends with the text. (The pill
            // outline doesn't apply under a warp.)
            for line in layout.lines {
                guard line.wordIndexes.contains(where: { states[$0].visible }) else { continue }
                fillWarpRibbon(line: line, layout: layout, warp: warp!,
                               color: background.color, padV: padV, in: context)
            }
        case .block:
            // A name over the text (a lower third) sits inside the same band.
            let block = extraRect.map { layout.blockRect.union($0) } ?? layout.blockRect
            paintRoundedRect(block.insetBy(dx: -padH, dy: -padV), radius: radius)
        case .perLine:
            for line in layout.lines {
                // Skip pills for lines whose words haven't appeared yet.
                guard line.wordIndexes.contains(where: { states[$0].visible }) else { continue }
                paintRoundedRect(line.frame.insetBy(dx: -padH, dy: -padV), radius: radius)
            }
        case .perWord:
            // Every word its own chip, riding the word's entrance transform
            // (alpha only — chips at rest, glyphs animate on top).
            for slot in layout.words where states[slot.index].visible {
                let frame = warp != nil ? displayWordFrame(slot, layout: layout, warp: warp, phase: phase) : slot.frame
                context.saveGState()
                context.setAlpha(CGFloat(states[slot.index].alpha))
                paintRoundedRect(frame.insetBy(dx: -padH * 0.6, dy: -padV), radius: radius)
                context.restoreGState()
            }
        }
    }

    /// A rough highlighter-swipe silhouette: a skewed quad with seeded edge
    /// jitter (stable per geometry, so it never shimmers between frames).
    private static func markerSwipePath(_ rect: CGRect) -> CGPath {
        let sx = Int(rect.minX.rounded()), sy = Int(rect.minY.rounded()), sw = Int(rect.width.rounded())
        func jitter(_ salt: Int) -> CGFloat {
            CGFloat(SeededRandom.signedUnit(sx, sy, sw, salt))
        }
        let amp = rect.height * 0.09
        let skew = rect.height * 0.16
        let path = CGMutablePath()
        path.move(to: CGPoint(x: rect.minX + skew * 0.4 + amp * jitter(1), y: rect.maxY + amp * jitter(2)))
        path.addLine(to: CGPoint(x: rect.midX + skew * 0.2, y: rect.maxY + amp * jitter(3)))
        path.addLine(to: CGPoint(x: rect.maxX + skew + amp * jitter(4), y: rect.maxY + amp * jitter(5)))
        path.addLine(to: CGPoint(x: rect.maxX + amp * jitter(6), y: rect.minY + amp * jitter(7)))
        path.addLine(to: CGPoint(x: rect.midX - skew * 0.2, y: rect.minY + amp * jitter(8)))
        path.addLine(to: CGPoint(x: rect.minX - skew * 0.5 + amp * jitter(9), y: rect.minY + amp * jitter(10)))
        path.closeSubpath()
        return path
    }

    /// How the karaoke fill participates in an ink pass.
    private enum KaraokeInk {
        /// Direct drawing: the fill runs inline, clipped to `fraction`.
        case inline
        /// Baking the BASE sprite: skip the karaoke fill (composited later
        /// from the highlight sprite).
        case omit
        /// Baking the HIGHLIGHT sprite: only the karaoke-colored fill (plus
        /// scanlines, which draw over it) — composited clipped to the spoken
        /// fraction.
        case highlight
    }

    private static func drawWord(
        slot: CardLayout.WordSlot,
        state: WordState,
        style: CaptionStyle,
        layout: CardLayout,
        in context: CGContext,
        phase: CGFloat = 0,
        time: TimeInterval = .greatestFiniteMagnitude
    ) {
        context.saveGState()
        defer { context.restoreGState() }
        context.setAlpha(CGFloat(state.alpha))

        // Static per-word placement (author-set), composed with the animated
        // transform so a tilted word still pops/slides. Rotation is CG-
        // convention; baseline offset is reference points, positive = up.
        let wordStyle = slot.word.style
        let staticRotation = wordStyle?.rotation ?? 0
        let staticDY = (wordStyle?.baselineOffset ?? 0) * layout.referenceScale

        if state.scale != 1 || state.scaleY != 1 || state.xOffset != 0 || state.yOffset != 0
            || state.rotation != 0 || staticRotation != 0 || staticDY != 0 {
            let center = CGPoint(
                x: slot.frame.midX + CGFloat(state.xOffset),
                y: slot.frame.midY + CGFloat(state.yOffset) + staticDY
            )
            context.translateBy(x: center.x, y: center.y)
            context.rotate(by: CGFloat(state.rotation) + staticRotation)
            context.scaleBy(x: CGFloat(state.scale), y: CGFloat(state.scale * state.scaleY))
            context.translateBy(x: -slot.frame.midX, y: -slot.frame.midY)
        }

        // Typewriter wipe: everything (stroke included) clips to the
        // revealed fraction.
        if state.reveal < 1 {
            context.clip(to: CGRect(
                x: slot.frame.minX,
                y: slot.frame.minY - layout.lineAdvance,
                width: slot.frame.width * CGFloat(Easing.clamp01(state.reveal)),
                height: slot.frame.height + 2 * layout.lineAdvance
            ))
        }

        // Warped titles bend each glyph onto a curve, which the straight
        // CTLine sprite can't express — draw them directly through the glyph
        // path instead. (Only karaoke is skipped under a warp; glow, extrude,
        // strokes, drop and fills all follow the curve.)
        if let warp = style.textWarp {
            drawWarpedWord(slot: slot, state: state, style: style, layout: layout, warp: warp, phase: phase, in: context)
            return
        }

        // Per-letter cascade: while any glyph is mid-entrance, draw each
        // letter with its own staggered animation; afterwards the settled
        // word falls through to the normal sprite path seamlessly.
        if let stagger = style.letterStagger, stagger > 0,
           time != .greatestFiniteMagnitude, slot.charSlots == nil {
            let entrance = slot.word.style?.animation ?? style.wordAnimation
            if entrance != .none {
                let duration = max(0.01, style.animationDuration)
                let glyphs = glyphOutlines(slot.fillLine)
                if !glyphs.isEmpty,
                   time < slot.word.start + duration + stagger * Double(glyphs.count) {
                    drawLetterCascade(
                        slot: slot, state: state, style: style, layout: layout,
                        glyphs: glyphs, entrance: entrance, stagger: stagger,
                        time: time, in: context
                    )
                    return
                }
            }
        }

        // Variable-font weight ramp: the spoken word draws through freshly
        // resolved (cached) heavier lines instead of its sprite.
        if let step = state.weightStep,
           let ramped = weightRampedSlot(slot: slot, style: style, layout: layout, step: step) {
            drawWordInk(slot: ramped, state: state, style: style, layout: layout, in: context, karaoke: .inline)
            return
        }

        // Sprite path: the word's raster (box + glow + stroke + fill +
        // underline + scanlines + censor) is expensive — glow alone is 1-4
        // shadow-blurred CTLineDraw passes — and identical for every frame
        // with the same discrete state. Bake it once per (line, state) and
        // composite; karaoke animates by clipping a second cached sprite to
        // the spoken fraction, so the per-frame cost is two image draws.
        // Continuous motion (scale/offset/rotation/reveal/alpha) stays in the
        // CTM above, exactly like the direct path.
        let censored = ProfanityFilter.shouldCensor(slot.word, autoCensor: style.censorProfanity == true)
        if !Self.spritesDisabled,
           let base = wordSprite(slot: slot, state: state, style: style, layout: layout, karaoke: .omit) {
            compositeSprite(base, state: state, layout: layout, in: context)
            if let fraction = state.karaokeFraction, state.karaokeColor != nil,
               fraction > 0, !censored,
               let highlight = wordSprite(slot: slot, state: state, style: style, layout: layout, karaoke: .highlight) {
                context.saveGState()
                context.clip(to: CGRect(
                    x: slot.frame.minX,
                    y: slot.frame.minY - layout.lineAdvance, // cover descenders/overshoot
                    width: slot.frame.width * CGFloat(fraction),
                    height: slot.frame.height + 2 * layout.lineAdvance
                ))
                context.draw(highlight.image, in: highlight.rect)
                context.restoreGState()
            }
            return
        }

        // Fallback: draw directly (bitmap allocation failed).
        drawWordInk(slot: slot, state: state, style: style, layout: layout, in: context, karaoke: .inline)
    }

    /// Composites a baked word sprite, adding the motion-smear trail and
    /// focus-pull blur when the state carries them. The "blur" is a ring of
    /// low-alpha taps around the crisp sprite — cheap, cache-friendly, and
    /// deterministic, which a real gaussian per frame would not be.
    private static func compositeSprite(
        _ base: (image: CGImage, rect: CGRect),
        state: WordState,
        layout: CardLayout,
        in context: CGContext
    ) {
        if state.smearDX != 0 {
            for j in stride(from: 3, through: 1, by: -1) {
                context.saveGState()
                context.setAlpha(CGFloat(0.28 * (1 - Double(j) / 4)))
                context.draw(base.image, in: base.rect.offsetBy(dx: CGFloat(state.smearDX) * CGFloat(j) / 3, dy: 0))
                context.restoreGState()
            }
        }
        if state.blur > 0.02 {
            let radius = CGFloat(state.blur) * layout.fontPixelSize * 0.16
            context.saveGState()
            context.setAlpha(0.16)
            for tap in 0..<6 {
                let angle = Double(tap) / 6 * 2 * .pi
                context.draw(base.image, in: base.rect.offsetBy(
                    dx: radius * CGFloat(cos(angle)),
                    dy: radius * CGFloat(sin(angle))
                ))
            }
            context.restoreGState()
            context.saveGState()
            context.setAlpha(CGFloat(max(0.1, 1 - state.blur * 0.8)))
            context.draw(base.image, in: base.rect)
            context.restoreGState()
        } else {
            context.draw(base.image, in: base.rect)
        }
    }

    /// Draws a word as individually-animated letters: each glyph runs the
    /// entrance offset by `stagger` from the previous one. Fill and outline
    /// stack follow each glyph; the heavier decorations (glow, hard drop,
    /// extrude) join when the word settles into its sprite.
    private static func drawLetterCascade(
        slot: CardLayout.WordSlot,
        state: WordState,
        style: CaptionStyle,
        layout: CardLayout,
        glyphs: [(path: CGPath, dx: CGFloat, dy: CGFloat, size: CGFloat)],
        entrance: WordAnimation,
        stagger: TimeInterval,
        time: TimeInterval,
        in context: CGContext
    ) {
        let duration = max(0.01, style.animationDuration)
        let strokes = style.resolvedStrokes(for: slot.word.style)
        let wordStyle = slot.word.style
        let atRest = state.color == state.restingColor

        for (index, glyph) in glyphs.enumerated() {
            let p = Easing.progress(time, from: slot.word.start + stagger * Double(index), duration: duration)
            guard p > 0 else { continue }
            let effects = entranceEffects(entrance, progress: p, travel: Double(layout.lineAdvance), intensity: style.animationIntensity ?? 1)

            var restTransform = CGAffineTransform(
                translationX: slot.baselineOrigin.x + glyph.dx,
                y: slot.baselineOrigin.y + glyph.dy
            )
            guard let rest = glyph.path.copy(using: &restTransform), !rest.isEmpty else { continue }
            let box = rest.boundingBoxOfPath
            var animTransform = CGAffineTransform.identity
                .translatedBy(x: box.midX + CGFloat(effects.dx), y: box.midY + CGFloat(effects.dy))
                .rotated(by: CGFloat(effects.rotation))
                .scaledBy(x: CGFloat(max(0.02, effects.scale)), y: CGFloat(max(0.02, effects.scale * effects.scaleY)))
                .translatedBy(x: -box.midX, y: -box.midY)
            guard let animated = rest.copy(using: &animTransform) else { continue }

            context.saveGState()
            context.setAlpha(CGFloat(state.alpha * effects.alpha))
            if !strokes.isEmpty {
                context.setLineJoin(.round)
                context.setLineCap(.round)
                for layer in strokes {
                    context.addPath(animated)
                    context.setStrokeColor(layer.color.cgColor)
                    context.setLineWidth(layer.width * layout.referenceScale)
                    context.strokePath()
                }
            }
            context.addPath(animated)
            context.clip()
            let paintBox = animated.boundingBoxOfPath
            if let wordGradient = (atRest ? wordStyle?.gradient : nil), wordGradient.colors.count >= 2 {
                paintLinearGradient(wordGradient, in: paintBox, in: context,
                                    hueTurns: driftTurns(wordGradient, clock: state.driftClock))
            } else if let gradient = style.textGradient, gradient.colors.count >= 2, state.color == style.textColor {
                paintLinearGradient(gradient, in: layout.blockRect, in: context,
                                    hueTurns: driftTurns(gradient, clock: state.driftClock))
            } else {
                context.setFillColor(state.color.cgColor)
                context.fill(paintBox)
            }
            context.restoreGState()
        }
    }

    // MARK: - Weight-ramp line cache

    private struct WeightRampKey: Hashable {
        let line: ObjectIdentifier
        let step: Int
    }
    nonisolated(unsafe) private static var weightRampCache: [WeightRampKey: (fill: CTLine, strokes: [CTLine], width: CGFloat, source: CTLine)] = [:]

    /// A substitute slot whose lines are re-resolved at the ramped weight,
    /// centered inside the original word's space. Cached per (line, step).
    private static func weightRampedSlot(
        slot: CardLayout.WordSlot,
        style: CaptionStyle,
        layout: CardLayout,
        step: Int
    ) -> CardLayout.WordSlot? {
        guard let target = style.activeWordWeightRamp else { return nil }
        let key = WeightRampKey(line: ObjectIdentifier(slot.fillLine), step: step)

        warpPathLock.lock()
        let cached = weightRampCache[key]
        warpPathLock.unlock()

        let resolved: (fill: CTLine, strokes: [CTLine], width: CGFloat)
        if let cached {
            resolved = (cached.fill, cached.strokes, cached.width)
        } else {
            let overrides = slot.word.style
            let base = overrides?.fontWeight ?? style.fontWeight
            let t = CGFloat(step) / 5
            let trait = base.traitValue + (target.traitValue - base.traitValue) * t
            // The size the layout drew the word at (a stacked line scales it).
            let wordSize = fontSize(of: slot.fillLine)
                ?? layout.fontPixelSize * max(0.1, overrides?.sizeMultiplier ?? 1)
            let slant = min(max(overrides?.slant ?? style.slant ?? 0, -0.6), 0.6)
            let font = FontResolver.font(
                family: overrides?.fontFamily ?? style.fontFamily,
                weightTrait: trait, size: wordSize, slant: slant
            )
            let text = slot.text
            let kern = style.letterSpacing * layout.referenceScale
            let fill = CaptionLayout.makeLine(text, font: font, kern: kern, stroke: nil)
            let strokes = style.resolvedStrokes(for: overrides).map { layer in
                CaptionLayout.makeLine(text, font: font, kern: kern,
                                       stroke: (layer.color.cgColor, layer.width * layout.referenceScale / wordSize * 100))
            }
            resolved = (fill, strokes, CaptionLayout.lineWidth(fill))
            warpPathLock.lock()
            if weightRampCache.count >= 512 { weightRampCache.removeAll() }
            weightRampCache[key] = (fill, strokes, resolved.width, slot.fillLine)
            warpPathLock.unlock()
        }

        // Center the heavier line inside the reserved slot.
        let origin = CGPoint(
            x: slot.frame.minX + (slot.frame.width - resolved.width) / 2,
            y: slot.baselineOrigin.y
        )
        return CardLayout.WordSlot(
            index: slot.index,
            word: slot.word,
            lineIndex: slot.lineIndex,
            frame: slot.frame,
            baselineOrigin: origin,
            fillLine: resolved.fill,
            strokeLines: resolved.strokes,
            charSlots: nil,
            text: slot.text
        )
    }

    /// The point size of a laid-out line's first run, if it has one.
    private static func fontSize(of line: CTLine) -> CGFloat? {
        guard let runs = CTLineGetGlyphRuns(line) as? [CTRun], let run = runs.first else { return nil }
        let attributes = CTRunGetAttributes(run) as NSDictionary
        guard let value = attributes[kCTFontAttributeName], CFGetTypeID(value as CFTypeRef) == CTFontGetTypeID() else { return nil }
        return CTFontGetSize(value as! CTFont)
    }

    /// A quantized clock combined into silhouette-sensitive cache keys while
    /// a time-varying SHAPE effect is mid-flight — a letter cascade or a
    /// background drawing on. `nil` while the silhouette holds still, so
    /// caches hit normally.
    private static func silhouetteClock(card: CaptionCard, style: CaptionStyle, at time: TimeInterval) -> Int? {
        guard time != .greatestFiniteMagnitude else { return nil }
        var active = false
        if let stagger = style.letterStagger, stagger > 0, style.wordAnimation != .none {
            let duration = max(0.01, style.animationDuration)
            for word in card.words {
                let window = duration + stagger * Double(max(1, word.text.count))
                if time >= word.start, time < word.start + window { active = true; break }
            }
        }
        if style.background?.drawOn == true, time - card.start < 0.45 { active = true }
        guard active else { return nil }
        return Int((time * 240).rounded())
    }

    // MARK: - Card shadow cache

    private struct CardShadowKey: Hashable {
        let line: ObjectIdentifier            // layout identity (retained in the entry)
        let silhouette: Int                   // hash of everything that shapes the ink
    }

    private static let cardShadowLock = NSLock()
    nonisolated(unsafe) private static var cardShadowCache: [CardShadowKey: (image: CGImage, rect: CGRect, line: CTLine)] = [:]
    /// The last silhouette key seen per card — a bake only happens once the
    /// silhouette holds still for a frame. A continuously-animating style
    /// (word loops, pops mid-flight) would otherwise re-bake EVERY frame,
    /// which costs more than the implicit shadow it replaces.
    nonisolated(unsafe) private static var cardShadowStreak: [UUID: CardShadowKey] = [:]
    private static let cardShadowLimit = 256

    static func flushCardShadows() {
        cardShadowLock.lock(); cardShadowCache.removeAll(); cardShadowStreak.removeAll(); cardShadowLock.unlock()
    }

    /// The card's baked shadow: blur(silhouette of the composed card) in the
    /// shadow color, offset — cached by the silhouette state, which is stable
    /// through a karaoke hold (fill colors don't shape the ink).
    private static func cardShadow(
        card: CaptionCard,
        style: CaptionStyle,
        layout: CardLayout,
        states: [WordState],
        anim: (alpha: Double, dx: CGFloat, dy: CGFloat, scale: CGFloat),
        extras: CardExtras = CardExtras(),
        shadow: ShadowStyle,
        phase: CGFloat = 0,
        time: TimeInterval = .greatestFiniteMagnitude
    ) -> (image: CGImage, rect: CGRect)? {
        guard let firstLine = layout.words.first?.fillLine else { return nil }

        var hasher = Hasher()
        for state in states {
            hasher.combine(state.visible); hasher.combine(state.alpha)
            hasher.combine(state.scale); hasher.combine(state.scaleY)
            hasher.combine(state.xOffset)
            hasher.combine(state.yOffset); hasher.combine(state.rotation)
            hasher.combine(state.reveal)
            hasher.combine(state.blur); hasher.combine(state.smearDX)
            hasher.combine(state.weightStep)
            hasher.combine(state.boxColor != nil); hasher.combine(state.underlineColor != nil)
            // Hollow text (transparent fill): the karaoke fill ADDS silhouette
            // as it sweeps, so the fraction must key the shadow there. Opaque
            // fills recolor existing ink — fraction-independent.
            if state.karaokeFraction != nil,
               state.color.alpha < 0.99 || (state.karaokeColor?.alpha ?? 1) < 0.99 {
                hasher.combine(state.karaokeFraction)
            }
        }
        hasher.combine(anim.dx); hasher.combine(anim.dy); hasher.combine(anim.scale)
        // A crawling ring reshapes the silhouette every frame.
        if phase != 0 { hasher.combine(Int((phase * 3600).rounded())) }
        // So do a mid-flight letter cascade and a background drawing on.
        if let clock = silhouetteClock(card: card, style: style, at: time) {
            hasher.combine(clock)
        }
        let key = CardShadowKey(line: ObjectIdentifier(firstLine), silhouette: hasher.finalize())

        cardShadowLock.lock()
        if let hit = cardShadowCache[key] { cardShadowLock.unlock(); return (hit.image, hit.rect) }
        // Silhouette still moving (key differs from the previous frame's) →
        // implicit shadow this frame; bake only once it settles.
        let settled = cardShadowStreak[card.id] == key
        cardShadowStreak[card.id] = key
        if cardShadowStreak.count > 256 { cardShadowStreak.removeAll() }
        cardShadowLock.unlock()
        guard settled else { return nil }

        // Ink bounds: the block, padded for every per-word overhang, then run
        // through the same rotation + entrance transforms the content gets,
        // then grown by the blur + offset.
        let f = layout.fontPixelSize
        let glowPad = (style.glow != nil ? max(1, (style.glow?.radius ?? 0) * layout.referenceScale) * 2.5 : 0)
        let maxStrokePts = layout.words.map { style.resolvedStrokes(for: $0.word.style).map(\.width).max() ?? 0 }.max() ?? 0
        let maxHardPts = layout.words.map { slot -> CGFloat in
            guard let h = slot.word.style?.hardShadow ?? style.hardShadow else { return 0 }
            return max(abs(h.offsetX), abs(h.offsetY))
        }.max() ?? 0
        let maxExtrudePts = layout.words.map { slot -> CGFloat in
            (slot.word.style?.extrude ?? style.extrude)?.depth ?? 0
        }.max() ?? 0
        // A warp lifts glyphs off the baseline: arc/wave by |amount|·width,
        // a circle by its radius each way, scatter by its font-size throw.
        let warpPad: CGFloat
        switch style.textWarp?.shape {
        case nil:
            warpPad = 0
        case .arc, .wave:
            warpPad = abs(style.textWarp?.amount ?? 0) * layout.blockRect.width
        case .circle:
            let amount = abs(style.textWarp?.amount ?? 1)
            warpPad = layout.blockRect.width / .pi * max(0.1, amount == 0 ? 1 : amount) + f
        case .scatter:
            warpPad = abs(style.textWarp?.amount ?? 0) * f * 1.5 + f * 0.4
        case .snake:
            // The ribbon swings ±amplitude off the baseline.
            warpPad = abs(style.textWarp?.amount ?? 0) * layout.blockRect.width * 0.5 + f
        }
        let pad = f * 0.8 + glowPad + (maxStrokePts + maxHardPts + maxExtrudePts) * layout.referenceScale
            + (style.chromaticAberration ?? 0) * layout.referenceScale + warpPad + 8
        var box = layout.blockRect.union(extras.bounds).insetBy(dx: -pad, dy: -pad)
        var transform = CGAffineTransform.identity
        let center = CGPoint(x: layout.blockRect.midX, y: layout.blockRect.midY)
        let rotation = blockRotation(for: card, style: style)
        if rotation != 0 {
            transform = transform
                .translatedBy(x: center.x, y: center.y)
                .rotated(by: -rotation)
                .translatedBy(x: -center.x, y: -center.y)
        }
        if anim.scale != 1 || anim.dy != 0 || anim.dx != 0 {
            transform = transform
                .translatedBy(x: center.x + anim.dx, y: center.y + anim.dy)
                .scaledBy(x: anim.scale, y: anim.scale)
                .translatedBy(x: -center.x, y: -center.y)
        }
        box = box.applying(transform)
        let blurPx = max(0, shadow.radius * layout.referenceScale)
        let off = CGSize(width: shadow.offsetX * layout.referenceScale,
                         height: -shadow.offsetY * layout.referenceScale)
        let rect = box.insetBy(dx: -(blurPx * 3 + abs(off.width) + 8),
                               dy: -(blurPx * 3 + abs(off.height) + 8)).integral
        guard rect.width >= 1, rect.height >= 1, rect.width < 8192, rect.height < 8192 else { return nil }

        // Pass 1: the composed card ink (transformed), exactly as the
        // transparency layer would contain it.
        guard let inkCtx = makeBitmapContext(width: Int(rect.width), height: Int(rect.height)) else { return nil }
        inkCtx.translateBy(x: -rect.minX, y: -rect.minY)
        inkCtx.concatenate(transform)
        inkCtx.setShouldSmoothFonts(false)
        inkCtx.setAllowsFontSmoothing(false)
        inkCtx.setShouldAntialias(true)
        inkCtx.interpolationQuality = .high
        drawBackground(card: card, style: style, layout: layout, states: states,
                       in: inkCtx, phase: phase, elapsed: time - card.start, extraRect: extras.backgroundRect)
        drawExtras(extras, in: inkCtx)
        for slot in layout.words {
            let state = states[slot.index]
            guard state.visible else { continue }
            drawWord(slot: slot, state: state, style: style, layout: layout,
                     in: inkCtx, phase: phase, time: time)
        }
        guard let ink = inkCtx.makeImage() else { return nil }

        // Pass 2: shadow only — draw the ink far outside the bitmap with the
        // shadow offset bringing just the shadow back in.
        guard let shadowCtx = makeBitmapContext(width: Int(rect.width), height: Int(rect.height)) else { return nil }
        let big = rect.width + blurPx * 4 + abs(off.width) + 32
        shadowCtx.setShadow(offset: CGSize(width: off.width + big, height: off.height),
                            blur: blurPx, color: shadow.color.cgColor)
        shadowCtx.draw(ink, in: CGRect(x: -big, y: 0, width: rect.width, height: rect.height))
        guard let image = shadowCtx.makeImage() else { return nil }

        cardShadowLock.lock()
        if cardShadowCache.count >= cardShadowLimit { cardShadowCache.removeAll() }
        cardShadowCache[key] = (image, rect, firstLine)
        cardShadowLock.unlock()
        return (image, rect)
    }

    // MARK: - Word sprite cache

    private struct WordSpriteKey: Hashable {
        let line: ObjectIdentifier          // unique per (card, style, config) layout
        let color: StyleColor
        let glows: Bool
        let box: StyleColor?
        let boxGradient: GradientFill?
        let underline: StyleColor?
        let highlight: StyleColor?          // nil = base sprite, set = karaoke sprite
        let drift: Int?                     // hue-drift clock (nil = static gradients)
    }

    /// Diagnostic kill switch: set CAPTION_NO_SPRITES=1 to force direct drawing.
    private static let spritesDisabled = ProcessInfo.processInfo.environment["CAPTION_NO_SPRITES"] != nil

    private static let wordSpriteLock = NSLock()
    // Each entry RETAINS its CTLine: the key is the line's identity (address),
    // and without the retain an evicted layout's deallocated line could hand
    // its address to a new line — serving the WRONG cached sprite. Holding the
    // line makes address reuse impossible while the entry exists.
    nonisolated(unsafe) private static var wordSpriteCache: [WordSpriteKey: (image: CGImage, rect: CGRect, line: CTLine)] = [:]
    private static let wordSpriteLimit = 256

    /// The cached raster for one word in one discrete state, with the rect it
    /// composites into (absolute layout coordinates). The CTLine's identity is
    /// the layout identity: a new layout means new lines means new sprites.
    private static func wordSprite(
        slot: CardLayout.WordSlot,
        state: WordState,
        style: CaptionStyle,
        layout: CardLayout,
        karaoke: KaraokeInk
    ) -> (image: CGImage, rect: CGRect)? {
        let key = WordSpriteKey(
            line: ObjectIdentifier(slot.fillLine),
            color: state.color,
            glows: state.glows,
            box: state.boxColor,
            boxGradient: state.boxGradient,
            underline: state.underlineColor,
            highlight: karaoke == .highlight ? state.karaokeColor : nil,
            drift: state.driftClock
        )
        wordSpriteLock.lock()
        if let hit = wordSpriteCache[key] { wordSpriteLock.unlock(); return (hit.image, hit.rect) }
        wordSpriteLock.unlock()

        // Ink bounds: the glyph band plus every way ink can escape it.
        let f = layout.fontPixelSize
        let glowPad = (state.glows ? max(1, (style.glow?.radius ?? 0) * layout.referenceScale) * 2.5 : 0)
        let wordStrokePts = style.resolvedStrokes(for: slot.word.style).map(\.width).max() ?? 0
        let strokePad = wordStrokePts * layout.referenceScale + 2
        let caPad = (style.chromaticAberration ?? 0) * layout.referenceScale
        // The hard drop shifts the silhouette by its offset (and grows it by
        // the outline), so the sprite must extend that far on each axis.
        let hard = slot.word.style?.hardShadow ?? style.hardShadow
        let hardPadX = hard.map { abs($0.offsetX) * layout.referenceScale } ?? 0
        let hardPadY = hard.map { abs($0.offsetY) * layout.referenceScale } ?? 0
        // The extrusion reaches `depth` along its angle.
        let extrude = slot.word.style?.extrude ?? style.extrude
        let exPadX = extrude.map { abs(cos($0.angle * .pi / 180)) * $0.depth * layout.referenceScale } ?? 0
        let exPadY = extrude.map { abs(sin($0.angle * .pi / 180)) * $0.depth * layout.referenceScale } ?? 0
        // Mixed-letter chips + tilt swing past the glyph band on every side.
        let mixedLetterPad: CGFloat = slot.charSlots != nil ? f * 0.4 : 0
        let padX = max(f * (style.activeBoxPadH ?? 0.16), f * 0.10, strokePad, caPad) + glowPad + hardPadX + exPadX + mixedLetterPad + 4
        let padY = max(f * (style.activeBoxPadV ?? 0.10), f * 0.06, strokePad, caPad, f * 0.08 * 3) + glowPad + hardPadY + exPadY + mixedLetterPad + 4
        let rect = slot.frame.insetBy(dx: -padX, dy: -padY).integral
        guard rect.width >= 1, rect.height >= 1,
              rect.width < 8192, rect.height < 8192,
              let ctx = makeBitmapContext(width: Int(rect.width), height: Int(rect.height))
        else { return nil }

        // Bake in ABSOLUTE layout coordinates (translated to the sprite's
        // origin) so even the block-spanning textGradient lands exactly.
        ctx.translateBy(x: -rect.minX, y: -rect.minY)
        ctx.setShouldSmoothFonts(false)
        ctx.setAllowsFontSmoothing(false)
        ctx.setShouldAntialias(true)
        ctx.interpolationQuality = .high
        drawWordInk(slot: slot, state: state, style: style, layout: layout, in: ctx, karaoke: karaoke)
        guard let image = ctx.makeImage() else { return nil }

        wordSpriteLock.lock()
        if wordSpriteCache.count >= wordSpriteLimit { wordSpriteCache.removeAll() }
        wordSpriteCache[key] = (image, rect, slot.fillLine)
        wordSpriteLock.unlock()
        return (image, rect)
    }

    /// Empties the word-sprite cache (fonts changed, etc.).
    static func flushWordSprites() {
        wordSpriteLock.lock(); wordSpriteCache.removeAll(); wordSpriteLock.unlock()
    }

    /// The word's raster ink, in absolute layout coordinates — ONE source of
    /// truth shared by the direct path (.inline) and both sprite bakes
    /// (.omit / .highlight), so they cannot drift.
    private static func drawWordInk(
        slot: CardLayout.WordSlot,
        state: WordState,
        style: CaptionStyle,
        layout: CardLayout,
        in context: CGContext,
        karaoke karaokeMode: KaraokeInk
    ) {
        // The highlight sprite is ONLY the karaoke fill (+ scanlines over it,
        // + the censor bar which must cover everything).
        if karaokeMode != .highlight {

        // Active-word highlight box: a rounded rect hugging just this word,
        // drawn inside the word's transform so it pops along with it.
        // Padding is configurable (their "Horizontal / Vertical size"), and
        // the fill can be a gradient.
        if let boxColor = state.boxColor {
            let padH = layout.fontPixelSize * (style.activeBoxPadH ?? 0.16)
            let padV = layout.fontPixelSize * (style.activeBoxPadV ?? 0.10)
            let box = slot.frame.insetBy(dx: -padH, dy: -padV)
            let radius = min(layout.fontPixelSize * 0.18, box.height / 2)
            let path = style.activeBoxShape == .marker
                ? markerSwipePath(box)
                : CGPath(roundedRect: box, cornerWidth: radius, cornerHeight: radius, transform: nil)
            let boxFill = state.boxGradient.map {
                hueShifted($0, turns: driftTurns($0, clock: state.driftClock))
            }
            if let gradient = boxFill, gradient.colors.count >= 2,
               let cgGradient = cgGradient(for: gradient) {
                context.saveGState()
                context.addPath(path)
                context.clip()
                let radians = gradient.angle * .pi / 180
                let direction = CGVector(dx: cos(radians), dy: sin(radians))
                let half = abs(direction.dx) * box.width / 2 + abs(direction.dy) * box.height / 2
                let center = CGPoint(x: box.midX, y: box.midY)
                context.drawLinearGradient(
                    cgGradient,
                    start: CGPoint(x: center.x - direction.dx * half, y: center.y - direction.dy * half),
                    end: CGPoint(x: center.x + direction.dx * half, y: center.y + direction.dy * half),
                    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
                )
                context.restoreGState()
            } else {
                context.setFillColor(boxColor.cgColor)
                context.addPath(path)
                context.fillPath()
            }
        }

        // Mixed letters (the ransom-note preset) replace the whole
        // stroke/fill pipeline: every
        // character is its own baked cut-out (paper chip + tilted glyph).
        if let chars = slot.charSlots {
            drawMixedLetters(chars, slot: slot, layout: layout, in: context)
        } else {

        // Glow: zero-offset shadow passes stack into an even halo, drawn
        // beneath the crisp stroke+fill so the glyph itself stays sharp.
        // Hollow text (transparent fill) glows off its outline instead, so
        // the halo hugs the stroke rather than filling the letterforms.
        if state.glows, let glow = style.glow {
            let line = state.color.alpha < 0.05 ? (slot.strokeLines.first ?? slot.fillLine) : slot.fillLine
            context.saveGState()
            context.setLineJoin(.round)
            context.setLineCap(.round)
            context.setShadow(
                offset: .zero,
                blur: max(1, glow.radius * layout.referenceScale),
                color: glow.color.cgColor
            )
            context.setFillColor(glow.color.cgColor)
            let passes = 1 + Int((3 * Easing.clamp01(Double(glow.intensity))).rounded())
            for _ in 0..<passes {
                context.textPosition = slot.baselineOrigin
                CTLineDraw(line, context)
            }
            context.restoreGState()
        }

        // Chromatic aberration: two colored copies offset either side of
        // the text, under everything — the VHS/print-misregistration split.
        // Direction and colors are configurable; defaults are the classic
        // horizontal red/cyan.
        if let aberration = style.chromaticAberration, aberration > 0 {
            let shift = aberration * layout.referenceScale
            let angle = (style.fringeAngle ?? 0) * .pi / 180
            let direction = CGVector(dx: cos(angle), dy: sin(angle))
            let colors = style.fringeColors ?? []
            let first = colors.first?.cgColor ?? CGColor(srgbRed: 1, green: 0.1, blue: 0.25, alpha: 0.85)
            let second = (colors.count > 1 ? colors[1] : nil)?.cgColor ?? CGColor(srgbRed: 0, green: 0.9, blue: 1, alpha: 0.85)
            for (color, signedShift) in [(first, -shift), (second, shift)] {
                context.setFillColor(color)
                context.textPosition = CGPoint(
                    x: slot.baselineOrigin.x + direction.dx * signedShift,
                    y: slot.baselineOrigin.y + direction.dy * signedShift
                )
                CTLineDraw(slot.fillLine, context)
            }
        }

        // Hard offset drop: a crisp silhouette copy behind the outline+fill —
        // the solid "sticker depth". Expanded by the word's own outline width
        // (context fill+stroke, both in the drop color) so it matches the
        // stroked silhouette rather than peeking out thinner than the letters.
        if let hard = slot.word.style?.hardShadow ?? style.hardShadow {
            let dx = hard.offsetX * layout.referenceScale
            let dy = hard.offsetY * layout.referenceScale
            let outerStrokePx = (style.resolvedStrokes(for: slot.word.style).map(\.width).max() ?? 0) * layout.referenceScale
            context.saveGState()
            context.setFillColor(hard.color.cgColor)
            context.setStrokeColor(hard.color.cgColor)
            context.setLineWidth(outerStrokePx)
            context.setLineJoin(.round)
            context.setLineCap(.round)
            context.setTextDrawingMode(outerStrokePx > 0 ? .fillStroke : .fill)
            context.textPosition = CGPoint(x: slot.baselineOrigin.x + dx, y: slot.baselineOrigin.y - dy)
            CTLineDraw(slot.fillLine, context)
            context.restoreGState()
        }

        // 3D extrude: silhouette copies stepping back along the depth angle,
        // farthest drawn first so nearer walls paint over them into solid
        // depth. Expanded by the outline (fill+stroke) so the side walls match
        // the letters. Sits over the detached hard drop, under the face.
        if let ex = slot.word.style?.extrude ?? style.extrude, ex.depth > 0 {
            let depthPx = ex.depth * layout.referenceScale
            let radians = ex.angle * .pi / 180
            let dir = CGVector(dx: cos(radians), dy: sin(radians))
            let outerStrokePx = (style.resolvedStrokes(for: slot.word.style).map(\.width).max() ?? 0) * layout.referenceScale
            // One copy per pixel of depth keeps the wall solid, capped so a huge
            // depth can't explode the per-word bake.
            let steps = max(1, min(64, Int(depthPx.rounded())))
            context.saveGState()
            context.setLineWidth(outerStrokePx)
            context.setLineJoin(.round)
            context.setLineCap(.round)
            context.setTextDrawingMode(outerStrokePx > 0 ? .fillStroke : .fill)
            let fade = Easing.clamp01(Double(ex.fade ?? 0))
            for i in stride(from: steps, through: 1, by: -1) {
                let t = CGFloat(i) / CGFloat(steps)
                let k = CGFloat(fade) * t
                let color = CGColor(
                    srgbRed: CGFloat(ex.color.red) * (1 - k),
                    green: CGFloat(ex.color.green) * (1 - k),
                    blue: CGFloat(ex.color.blue) * (1 - k),
                    alpha: CGFloat(ex.color.alpha)
                )
                context.setFillColor(color)
                context.setStrokeColor(color)
                context.textPosition = CGPoint(
                    x: slot.baselineOrigin.x + dir.dx * depthPx * t,
                    y: slot.baselineOrigin.y + dir.dy * depthPx * t
                )
                CTLineDraw(slot.fillLine, context)
            }
            context.restoreGState()
        }

        // Outline passes first, fill on top — the classic caption look.
        // Stacked strokes draw widest-first so each narrower layer paints over
        // the one beneath (the "sticker" outline). Round joins: miter joins
        // spike wildly at sharp glyph apexes once strokes get caption-wide.
        if !slot.strokeLines.isEmpty {
            context.setLineJoin(.round)
            context.setLineCap(.round)
            for strokeLine in slot.strokeLines {
                context.textPosition = slot.baselineOrigin
                CTLineDraw(strokeLine, context)
            }
        }

        // Fill precedence, resting only (a temporal highlight recolors solid):
        //   per-word image → per-word gradient → global image (block) →
        //   global gradient (block) → solid. Per-word fills crop to the word's
        //   frame; global fills span the block so words share one continuous
        //   ramp / photo.
        let wordStyle = slot.word.style
        let atRest = state.color == state.restingColor
        let wordImage = (atRest ? wordStyle?.imageFill : nil).flatMap { ImageFillCache.image(for: $0.url) }
        let wordGradient: GradientFill? = atRest ? wordStyle?.gradient : nil
        let globalImage = (state.color == style.textColor ? style.imageFill : nil).flatMap { ImageFillCache.image(for: $0.url) }

        if let wordImage {
            clipToGlyphs(slot.fillLine, at: slot.baselineOrigin, in: context) {
                paintImage(wordImage, in: slot.frame, in: $0)
            }
        } else if let wordGradient, wordGradient.colors.count >= 2 {
            clipToGlyphs(slot.fillLine, at: slot.baselineOrigin, in: context) {
                paintLinearGradient(wordGradient, in: slot.frame, in: $0,
                                    hueTurns: driftTurns(wordGradient, clock: state.driftClock))
            }
        } else if let globalImage {
            clipToGlyphs(slot.fillLine, at: slot.baselineOrigin, in: context) {
                paintImage(globalImage, in: layout.blockRect, in: $0)
            }
        } else if let gradient = style.textGradient, gradient.colors.count >= 2,
                  state.color == style.textColor {
            clipToGlyphs(slot.fillLine, at: slot.baselineOrigin, in: context) {
                paintLinearGradient(gradient, in: layout.blockRect, in: $0,
                                    hueTurns: driftTurns(gradient, clock: state.driftClock))
            }
        } else {
            context.setFillColor(state.color.cgColor)
            context.textPosition = slot.baselineOrigin
            CTLineDraw(slot.fillLine, context)
        }

        } // end non-mixed-letter stroke/fill pipeline

        // Underlines: the persistent per-word bar (author-set, always on) and
        // the active-word bar (temporal highlight) share one shape; when both
        // land on a word the highlight color wins for that moment.
        if let underlineColor = state.underlineColor ?? slot.word.style?.underline {
            let thickness = layout.fontPixelSize * 0.08
            let bar = CGRect(
                x: slot.frame.minX,
                y: slot.frame.minY - thickness * 1.8,
                width: slot.frame.width,
                height: thickness
            )
            context.setFillColor(underlineColor.cgColor)
            let path = CGPath(roundedRect: bar, cornerWidth: thickness / 2, cornerHeight: thickness / 2, transform: nil)
            context.addPath(path)
            context.fillPath()
        }

        } // end !highlight

        // Karaoke fill. Inline (direct path): clipped to the spoken fraction
        // here. Highlight sprite: drawn FULL — the composite clips to the
        // fraction. Base sprite: omitted entirely.
        switch karaokeMode {
        case .inline:
            if let fraction = state.karaokeFraction, let color = state.karaokeColor, fraction > 0,
               slot.charSlots == nil {
                context.saveGState()
                let clip = CGRect(
                    x: slot.frame.minX,
                    y: slot.frame.minY - layout.lineAdvance, // cover descenders/overshoot
                    width: slot.frame.width * CGFloat(fraction),
                    height: slot.frame.height + 2 * layout.lineAdvance
                )
                context.clip(to: clip)
                context.setFillColor(color.cgColor)
                context.textPosition = slot.baselineOrigin
                CTLineDraw(slot.fillLine, context)
                context.restoreGState()
            }
        case .omit:
            break
        case .highlight:
            if let color = state.karaokeColor, slot.charSlots == nil {
                context.setFillColor(color.cgColor)
                context.textPosition = slot.baselineOrigin
                CTLineDraw(slot.fillLine, context)
            }
        }

        // Scanlines last, masked to the glyphs — dark stripes over whatever
        // ended up in the letterforms (solid, gradient, or karaoke fill).
        // (Skipped for mixed letters — the mask is the base font's glyphs,
        // not the seeded per-character cut-outs.)
        if let scan = style.scanlineIntensity, scan > 0, slot.charSlots == nil {
            context.saveGState()
            context.setTextDrawingMode(.clip)
            context.textPosition = slot.baselineOrigin
            CTLineDraw(slot.fillLine, context)
            context.setFillColor(CGColor(gray: 0, alpha: min(1, scan) * 0.5))
            let step = max(3, 5 * layout.referenceScale)
            var y = slot.frame.minY - layout.lineAdvance
            let top = slot.frame.maxY + layout.lineAdvance
            while y < top {
                context.fill(CGRect(x: slot.frame.minX - step, y: y, width: slot.frame.width + 2 * step, height: step * 0.4))
                y += step
            }
            context.restoreGState()
            context.setTextDrawingMode(.fill)
        }

        // Profanity censor bar: an opaque near-black block over the whole word,
        // drawn last so it covers every fill and highlight. Pairs with the
        // audio bleep applied at export. (Baked into BOTH sprites; the
        // highlight sprite is skipped entirely for censored words.)
        if ProfanityFilter.shouldCensor(slot.word, autoCensor: style.censorProfanity == true) {
            let padH = layout.fontPixelSize * 0.10
            let padV = layout.fontPixelSize * 0.06
            let bar = slot.frame.insetBy(dx: -padH, dy: -padV)
            context.setFillColor(CGColor(gray: 0.04, alpha: 1))
            fillRoundedRect(bar, radius: min(layout.fontPixelSize * 0.14, bar.height / 2), in: context)
        }
    }

    /// Draws a word's mixed letters: every character its own paper
    /// chip + tilted, baked-color glyph. Deterministic — the seeded picks
    /// were resolved at layout time, so this just places and draws.
    private static func drawMixedLetters(
        _ chars: [CardLayout.CharSlot],
        slot: CardLayout.WordSlot,
        layout: CardLayout,
        in context: CGContext
    ) {
        for char in chars {
            let originX = slot.baselineOrigin.x + char.x
            let baselineY = slot.baselineOrigin.y + char.dy
            let center = CGPoint(
                x: originX + char.width / 2,
                y: baselineY + (char.ascent - char.descent) / 2
            )
            context.saveGState()
            context.translateBy(x: center.x, y: center.y)
            context.rotate(by: char.tilt)
            context.translateBy(x: -center.x, y: -center.y)
            if let chip = char.chip {
                let padX = char.width * 0.16 + layout.fontPixelSize * 0.03
                let padY = layout.fontPixelSize * 0.05
                let rect = CGRect(
                    x: originX - padX,
                    y: baselineY - char.descent - padY,
                    width: char.width + 2 * padX,
                    height: char.ascent + char.descent + 2 * padY
                )
                // A slight drop under the chip so the cut-outs read as paper.
                context.setShadow(
                    offset: CGSize(width: 0, height: -2 * layout.referenceScale),
                    blur: 3 * layout.referenceScale,
                    color: CGColor(gray: 0, alpha: 0.35)
                )
                context.setFillColor(chip.cgColor)
                let radius = min(6 * layout.referenceScale, rect.height * 0.12)
                context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
                context.fillPath()
                context.setShadow(offset: .zero, blur: 0, color: nil)
            }
            context.textPosition = CGPoint(x: originX, y: baselineY)
            CTLineDraw(char.line, context)
            context.restoreGState()
        }
    }

    private static func fillRoundedRect(_ rect: CGRect, radius: CGFloat, in context: CGContext) {
        let clamped = min(radius, min(rect.width, rect.height) / 2)
        let path = CGPath(roundedRect: rect, cornerWidth: clamped, cornerHeight: clamped, transform: nil)
        context.addPath(path)
        context.fillPath()
    }

    /// Entrance math for hosts animating surfaces the renderer doesn't own
    /// (PiP preview layers) — the same curves as everything else, so a
    /// preview animation is the export animation.
    public static func overlayTransform(
        animation: WordAnimation,
        progress: Double,
        travel: Double
    ) -> (alpha: Double, scale: Double, dx: Double, dy: Double, rotation: Double) {
        let effects = entranceEffects(animation, progress: Easing.clamp01(progress), travel: travel)
        return (effects.alpha, max(0.02, effects.scale), effects.dx, effects.dy, effects.rotation)
    }

    // MARK: - Entrance Math (shared by words and stickers)

    /// The animated properties an entrance contributes at normalized
    /// progress `p`. `travel` sets slide/fly distances (a line height for
    /// words, the glyph size for stickers).
    private struct EntranceEffects {
        var alpha: Double = 1
        var scale: Double = 1
        /// Extra vertical squash multiplier on top of `scale` (flip-down).
        var scaleY: Double = 1
        var dx: Double = 0
        var dy: Double = 0
        var rotation: Double = 0
        var reveal: Double = 1
        /// Focus-pull blur strength `0…1` (blur-in).
        var blur: Double = 0
        /// Directional motion-smear trail offset in pixels (smear-in).
        var smearDX: Double = 0
    }

    /// A word entrance's curve at `progress`, for a sticker riding it
    /// (``StickerRenderer``): the same motion a word makes, applied to a picture.
    static func stickerEntrance(_ animation: WordAnimation, progress: Double, travel: Double)
        -> (alpha: Double, scale: Double, dx: Double, dy: Double, rotation: Double) {
        let effects = entranceEffects(animation, progress: progress, travel: travel)
        return (effects.alpha, effects.scale * effects.scaleY, effects.dx, effects.dy, effects.rotation)
    }

    private static func entranceEffects(_ animation: WordAnimation, progress p: Double, travel: Double, intensity: Double = 1) -> EntranceEffects {
        var effects = EntranceEffects()
        let eased = Easing.easeOutCubic(p)
        switch animation {
        case .none:
            break
        case .fadeIn:
            effects.alpha = eased
        case .popOn:
            effects.scale = max(0.02, Easing.easeOutBack(p))
            effects.alpha = min(1, p * 3)
        case .bounceIn:
            effects.scale = max(0.02, Easing.easeOutBounce(p))
            effects.alpha = min(1, p * 4)
        case .spring:
            effects.scale = max(0.02, Easing.spring(p))
            effects.alpha = min(1, p * 4)
        case .stomp:
            effects.scale = 1 + 1.6 * (1 - eased)
            effects.alpha = min(1, p * 5)
        case .slideUp:
            effects.alpha = eased
            effects.dy = -(1 - eased) * 0.35 * travel
        case .slideDown:
            effects.alpha = eased
            effects.dy = (1 - eased) * 0.35 * travel
        case .flyInLeft:
            effects.alpha = min(1, p * 2)
            effects.dx = -(1 - eased) * 2.2 * travel
        case .flyInRight:
            effects.alpha = min(1, p * 2)
            effects.dx = (1 - eased) * 2.2 * travel
        case .rotateIn:
            let back = Easing.easeOutBack(p)
            effects.rotation = (1 - back) * -0.25
            effects.scale = max(0.02, 0.7 + 0.3 * back)
            effects.alpha = min(1, p * 3)
        case .typewriter:
            effects.reveal = p
        case .shake:
            effects.alpha = min(1, p * 3)
            effects.dx = sin(p * .pi * 7) * (1 - p) * 0.12 * travel
        case .drop:
            effects.alpha = min(1, p * 4)
            effects.dy = (1 - Easing.easeOutBounce(p)) * 1.6 * travel
        case .twirlUp:
            effects.alpha = eased
            effects.dy = -(1 - eased) * 0.8 * travel
            effects.rotation = (1 - eased) * -.pi
        case .swing:
            effects.alpha = min(1, p * 3)
            effects.rotation = exp(-4 * p) * sin(p * .pi * 5) * 0.4
        case .skid:
            effects.alpha = min(1, p * 2.5)
            effects.dx = -(1 - Easing.easeOutBack(p)) * 2.0 * travel
        case .rollIn:
            // Comes from the right, rolling like a wheel: leftward travel
            // pairs with a clockwise spin, settling upright at p=1.
            effects.alpha = min(1, p * 2)
            effects.dx = (1 - eased) * 2.6 * travel
            effects.rotation = (1 - eased) * 2 * .pi
        case .rollInLeft:
            effects.alpha = min(1, p * 2)
            effects.dx = -(1 - eased) * 2.6 * travel
            effects.rotation = -(1 - eased) * 2 * .pi
        case .zoomIn:
            // Clean zoom from tiny — popOn without the overshoot.
            effects.scale = max(0.02, eased)
            effects.alpha = min(1, p * 2.5)
        case .spiralIn:
            // Shrinks from oversized while sweeping a quarter turn.
            effects.scale = 1 + 0.8 * (1 - eased)
            effects.rotation = (1 - eased) * .pi / 2
            effects.alpha = min(1, p * 2)
        case .flipDown:
            // A vertical squash recovering with overshoot — reads as the
            // word flipping down over its top edge.
            effects.scaleY = max(0.05, Easing.easeOutBack(p))
            effects.alpha = min(1, p * 3)
        case .whipIn:
            // Whips in from the left with a heavy tilt snapping upright.
            effects.dx = -(1 - Easing.easeOutBack(p)) * 2.0 * travel
            effects.rotation = (1 - eased) * 0.35
            effects.alpha = min(1, p * 2.5)
        case .blurIn:
            // Sharpens into focus from a soft blur.
            effects.alpha = min(1, p * 2)
            effects.blur = 1 - eased
        case .smearIn:
            // Whips in from the left with a decaying motion smear behind.
            effects.dx = -(1 - Easing.easeOutBack(p)) * 1.8 * travel
            effects.smearDX = -(1 - eased) * 0.9 * travel
            effects.alpha = min(1, p * 2.2)
        }
        // Intensity scales the transient magnitude — how far it travels and
        // how much it overshoots — without touching where it lands (p=1) or
        // the fade/reveal. `0` = appear in place, `1` = default, `2` = bigger.
        if intensity != 1 {
            effects.dx *= intensity
            effects.dy *= intensity
            effects.rotation *= intensity
            effects.scale = 1 + (effects.scale - 1) * intensity
            effects.scaleY = 1 + (effects.scaleY - 1) * intensity
            effects.blur = min(1, effects.blur * intensity)
            effects.smearDX *= intensity
        }
        return effects
    }

    // MARK: - Stickers


    /// Everything `drawTextSticker` derives from (sticker, time), computed once
    /// — ALSO consumed by the overlay-cache signature, so the cached pixels and
    /// the signature can never disagree.
    private struct TitleRenderState {
        var card: CaptionCard
        var shell: CaptionDocument
        var center: CGPoint
        var rotation: Double
        var scale: Double
        var scaleY: Double = 1
        var dx: Double
        var dy: Double
    }


    // MARK: - Gradient cache

    // CGGradient + the CGColor array were rebuilt per WORD per FRAME for
    // gradient box/text styles. GradientFill is Hashable — memoize.
    private static let gradientLock = NSLock()
    nonisolated(unsafe) private static var gradientCache: [GradientFill: CGGradient] = [:]

    // MARK: - Warped titles (text on a path)

    // The per-glyph warped path is pure in (fillLine, warp, phase) — the first
    // two fixed for a given layout, the phase quantized time for a crawling
    // circle (0 otherwise). It's built for the fill/stroke draw AND for the
    // frame/background geometry, so memoize it (retaining the CTLine, like the
    // sprite cache, so an evicted line's address can't be reused).
    private struct WarpPathKey: Hashable {
        let line: ObjectIdentifier
        let warp: TextWarp
        /// Quantized crawl phase (1/3600 rev steps); `0` for static warps.
        let phaseKey: Int
    }
    private static let warpPathLock = NSLock()
    nonisolated(unsafe) private static var warpPathCache: [WarpPathKey: (path: CGPath, line: CTLine)] = [:]
    private static let warpPathLimit = 256

    // A crawling ring rebuilds its path every frame, so decomposing the CTLine
    // into glyph outlines each time would dominate. Decompose once per line
    // (glyph outline + baseline position) and recompose with cheap transforms.
    nonisolated(unsafe) private static var glyphOutlineCache: [ObjectIdentifier: (glyphs: [(path: CGPath, dx: CGFloat, dy: CGFloat, size: CGFloat)], line: CTLine)] = [:]

    static func flushWarpPaths() {
        warpPathLock.lock()
        warpPathCache.removeAll()
        glyphOutlineCache.removeAll()
        warpPathLock.unlock()
    }

    /// The crawl phase (fraction of one path length) for a warp at `time` —
    /// deterministic in absolute time, so preview and export agree. Circles
    /// spin; snakes slither.
    static func warpPhase(_ warp: TextWarp?, at time: TimeInterval) -> CGFloat {
        guard let warp, warp.shape == .circle || warp.shape == .snake,
              let crawl = warp.crawl, crawl != 0 else { return 0 }
        let phase = (time * Double(crawl)).truncatingRemainder(dividingBy: 1)
        return CGFloat(phase < 0 ? phase + 1 : phase)
    }

    /// One line's serpentine geometry: the horizontal span whose sine arc
    /// length equals the line width (so the text exactly fills the ribbon)
    /// plus the cumulative arc-length table used to place glyphs.
    private struct SnakeTable {
        let span: CGFloat
        let amplitude: CGFloat
        let waves: CGFloat
        let cumulative: [CGFloat]
        let total: CGFloat

        /// Position + tangent angle at arc length `s` along the ribbon.
        func point(at s: CGFloat) -> (x: CGFloat, y: CGFloat, angle: CGFloat) {
            let target = min(max(0, s), total)
            // The table is monotonic; binary-search the segment.
            var lo = 0, hi = cumulative.count - 1
            while hi - lo > 1 {
                let mid = (lo + hi) / 2
                if cumulative[mid] < target { lo = mid } else { hi = mid }
            }
            let segment = cumulative[hi] - cumulative[lo]
            let fraction = segment > 0 ? (target - cumulative[lo]) / segment : 0
            let steps = CGFloat(cumulative.count - 1)
            let x = span * (CGFloat(lo) + fraction) / steps
            let omega = 2 * .pi * waves / span
            let y = amplitude * sin(omega * x)
            let slope = amplitude * omega * cos(omega * x)
            return (x, y, atan(slope))
        }
    }

    private static func makeSnakeTable(lineWidth: CGFloat, glyphSize: CGFloat, warp: TextWarp) -> SnakeTable {
        let waves = max(0.5, warp.waves ?? 1.5)
        // Amplitude scales with the GLYPH size, not the (potentially huge,
        // unshrunk) straight line width — `0.5` swings the ribbon about two
        // glyph-heights each way, whatever the text length.
        let amplitude = max(1, abs(warp.amount) * glyphSize * 4)
        let samples = 256

        func measure(_ span: CGFloat) -> ([CGFloat], CGFloat) {
            var cumulative: [CGFloat] = [0]
            cumulative.reserveCapacity(samples + 1)
            var total: CGFloat = 0
            var previousX: CGFloat = 0
            var previousY: CGFloat = 0
            let omega = 2 * .pi * waves / span
            for index in 1...samples {
                let x = span * CGFloat(index) / CGFloat(samples)
                let y = amplitude * sin(omega * x)
                total += hypot(x - previousX, y - previousY)
                cumulative.append(total)
                previousX = x
                previousY = y
            }
            return (cumulative, total)
        }

        // Bisect the span: a deeper sweep packs the same text length into a
        // narrower ribbon (arc length grows as the span shrinks the waves
        // steeper — length is monotonic in span here, so bisection holds).
        var lo = lineWidth * 0.12, hi = lineWidth
        for _ in 0..<24 {
            let mid = (lo + hi) / 2
            if measure(mid).1 > lineWidth { hi = mid } else { lo = mid }
        }
        let span = (lo + hi) / 2
        let (cumulative, total) = measure(span)
        return SnakeTable(span: span, amplitude: amplitude, waves: waves, cumulative: cumulative, total: total)
    }

    /// The cached warped glyph path for a word under the active warp.
    private static func warpedPath(for slot: CardLayout.WordSlot, layout: CardLayout, warp: TextWarp, phase: CGFloat = 0) -> CGPath {
        let phaseKey = Int((phase * 3600).rounded())
        let key = WarpPathKey(line: ObjectIdentifier(slot.fillLine), warp: warp, phaseKey: phaseKey)
        warpPathLock.lock()
        if let hit = warpPathCache[key] { warpPathLock.unlock(); return hit.path }
        warpPathLock.unlock()

        let lineFrame = slot.lineIndex < layout.lines.count ? layout.lines[slot.lineIndex].frame : layout.blockRect
        let path = warpedGlyphPath(
            slot.fillLine, baselineOrigin: slot.baselineOrigin,
            lineLeft: lineFrame.minX, lineWidth: max(1, lineFrame.width),
            warp: warp, phase: CGFloat(phaseKey) / 3600
        )
        warpPathLock.lock()
        if warpPathCache.count >= warpPathLimit { warpPathCache.removeAll() }
        warpPathCache[key] = (path, slot.fillLine)
        warpPathLock.unlock()
        return path
    }

    /// The line's glyph outlines with their baseline offsets — decomposed
    /// once per CTLine and cached (the crawl recomposes these every frame).
    private static func glyphOutlines(_ line: CTLine) -> [(path: CGPath, dx: CGFloat, dy: CGFloat, size: CGFloat)] {
        let key = ObjectIdentifier(line)
        warpPathLock.lock()
        if let hit = glyphOutlineCache[key] { warpPathLock.unlock(); return hit.glyphs }
        warpPathLock.unlock()

        var glyphsOut: [(path: CGPath, dx: CGFloat, dy: CGFloat, size: CGFloat)] = []
        let runs = CTLineGetGlyphRuns(line) as? [CTRun] ?? []
        for run in runs {
            let count = CTRunGetGlyphCount(run)
            guard count > 0 else { continue }
            let attrs = CTRunGetAttributes(run) as NSDictionary
            guard let fontValue = attrs[kCTFontAttributeName] else { continue }
            let font = fontValue as! CTFont
            let size = CTFontGetSize(font)
            var glyphs = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
            CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)
            for i in 0..<count {
                guard let glyph = CTFontCreatePathForGlyph(font, glyphs[i], nil) else { continue }
                glyphsOut.append((glyph, positions[i].x, positions[i].y, size))
            }
        }
        warpPathLock.lock()
        if glyphOutlineCache.count >= warpPathLimit { glyphOutlineCache.removeAll() }
        glyphOutlineCache[key] = (glyphsOut, line)
        warpPathLock.unlock()
        return glyphsOut
    }

    /// Draws one word bent onto ``TextWarp``'s curve: glow, the hard drop, a 3D
    /// extrude, the outline stack, and the fill all follow the warped glyph
    /// path. Reached only when a warp is set; it forgoes the sprite cache
    /// (titles are few and static, and the composed overlay is cached upstream),
    /// but the warped path itself is memoized. Karaoke is the one effect a warp
    /// can't express (its fraction-clip assumes a straight baseline).
    private static func drawWarpedWord(
        slot: CardLayout.WordSlot,
        state: WordState,
        style: CaptionStyle,
        layout: CardLayout,
        warp: TextWarp,
        phase: CGFloat = 0,
        in context: CGContext
    ) {
        let path = warpedPath(for: slot, layout: layout, warp: warp, phase: phase)
        guard !path.isEmpty else { return }
        let box = path.boundingBoxOfPath

        // Glow: stacked zero-offset blurred fills of the warped silhouette.
        if state.glows, let glow = style.glow {
            context.saveGState()
            context.setShadow(offset: .zero, blur: max(1, glow.radius * layout.referenceScale), color: glow.color.cgColor)
            context.setFillColor(glow.color.cgColor)
            let passes = 1 + Int((3 * Easing.clamp01(Double(glow.intensity))).rounded())
            for _ in 0..<passes {
                context.addPath(path)
                context.fillPath()
            }
            context.restoreGState()
        }

        // Hard drop: the whole warped silhouette, offset, in the drop color.
        if let hard = slot.word.style?.hardShadow ?? style.hardShadow {
            context.saveGState()
            context.translateBy(x: hard.offsetX * layout.referenceScale, y: -hard.offsetY * layout.referenceScale)
            context.addPath(path)
            context.setFillColor(hard.color.cgColor)
            context.fillPath()
            context.restoreGState()
        }

        // 3D extrude: the warped silhouette stepped back along the depth angle.
        if let extrude = slot.word.style?.extrude ?? style.extrude, extrude.depth > 0 {
            let depthPx = extrude.depth * layout.referenceScale
            let radians = extrude.angle * .pi / 180
            let dir = CGVector(dx: cos(radians), dy: sin(radians))
            let steps = max(1, min(64, Int(depthPx.rounded())))
            let fade = Easing.clamp01(Double(extrude.fade ?? 0))
            for i in stride(from: steps, through: 1, by: -1) {
                let t = CGFloat(i) / CGFloat(steps)
                let k = CGFloat(fade) * t
                let color = CGColor(
                    srgbRed: CGFloat(extrude.color.red) * (1 - k),
                    green: CGFloat(extrude.color.green) * (1 - k),
                    blue: CGFloat(extrude.color.blue) * (1 - k),
                    alpha: CGFloat(extrude.color.alpha)
                )
                context.saveGState()
                context.translateBy(x: dir.dx * depthPx * t, y: dir.dy * depthPx * t)
                context.addPath(path)
                context.setFillColor(color)
                context.fillPath()
                context.restoreGState()
            }
        }

        // Outline stack, widest-first, each stroking the warped path.
        let strokes = style.resolvedStrokes(for: slot.word.style)
        if !strokes.isEmpty {
            context.saveGState()
            context.setLineJoin(.round)
            context.setLineCap(.round)
            for layer in strokes {
                context.addPath(path)
                context.setStrokeColor(layer.color.cgColor)
                context.setLineWidth(layer.width * layout.referenceScale)
                context.strokePath()
            }
            context.restoreGState()
        }

        // Fill, resting-only precedence (matches the straight path): per-word
        // image → per-word gradient → global image → global gradient → solid.
        let wordStyle = slot.word.style
        let atRest = state.color == state.restingColor
        let wordImage = (atRest ? wordStyle?.imageFill : nil).flatMap { ImageFillCache.image(for: $0.url) }
        let wordGradient: GradientFill? = atRest ? wordStyle?.gradient : nil
        let globalImage = (state.color == style.textColor ? style.imageFill : nil).flatMap { ImageFillCache.image(for: $0.url) }

        context.saveGState()
        context.addPath(path)
        context.clip()
        if let wordImage {
            paintImage(wordImage, in: box, in: context)
        } else if let wordGradient, wordGradient.colors.count >= 2 {
            paintLinearGradient(wordGradient, in: box, in: context,
                                hueTurns: driftTurns(wordGradient, clock: state.driftClock))
        } else if let globalImage {
            paintImage(globalImage, in: layout.blockRect, in: context)
        } else if let gradient = style.textGradient, gradient.colors.count >= 2, state.color == style.textColor {
            paintLinearGradient(gradient, in: layout.blockRect, in: context,
                                hueTurns: driftTurns(gradient, clock: state.driftClock))
        } else {
            context.setFillColor(state.color.cgColor)
            context.fill(box)
        }
        context.restoreGState()
    }

    /// Builds the outline path of a line's glyphs placed and rotated onto the
    /// warp curve.
    ///
    /// Arc/wave: each glyph's baseline position maps to a normalized `u`
    /// across the line; the curve gives its vertical offset and tangent angle.
    /// Circle: `u` maps to an angle around a ring centered on the line
    /// (`phase` spins the ring — the crawl). Scatter: each glyph takes a
    /// seeded vertical throw and tilt.
    private static func warpedGlyphPath(
        _ line: CTLine,
        baselineOrigin: CGPoint,
        lineLeft: CGFloat,
        lineWidth: CGFloat,
        warp: TextWarp,
        phase: CGFloat = 0
    ) -> CGPath {
        let path = CGMutablePath()
        let outlines = glyphOutlines(line)
        // The serpentine table depends only on (lineWidth, glyph size, warp)
        // — build it once per line, not per glyph.
        let snake: SnakeTable? = warp.shape == .snake
            ? makeSnakeTable(lineWidth: lineWidth,
                             glyphSize: outlines.first?.size ?? max(24, lineWidth * 0.05),
                             warp: warp)
            : nil
        for glyph in outlines {
            let gx = baselineOrigin.x + glyph.dx
            let gy = baselineOrigin.y + glyph.dy
            let u = min(max((gx - lineLeft) / lineWidth, 0), 1)
            let transform: CGAffineTransform
            switch warp.shape {
            case .arc, .wave:
                let curve = warpOffset(u: u, lineWidth: lineWidth, warp: warp)
                transform = CGAffineTransform(translationX: gx, y: gy + curve.dy).rotated(by: curve.angle)
            case .snake:
                // Slide along the ribbon by arc length (phase = the slither),
                // wrapping at the ends so repeated text loops seamlessly.
                let table = snake!
                var s = (u + phase).truncatingRemainder(dividingBy: 1)
                if s < 0 { s += 1 }
                let point = table.point(at: s * table.total)
                let left = lineLeft + (lineWidth - table.span) / 2
                transform = CGAffineTransform(translationX: left + point.x, y: gy + point.y)
                    .rotated(by: point.angle)
            case .circle:
                // The ring: `amount` 1 = the text exactly closes the circle.
                // θ runs clockwise from the top; the glyph's up-vector points
                // outward, so text reads around the outside of the ring.
                let radius = max(4, lineWidth / (2 * .pi) * max(0.1, abs(warp.amount) == 0 ? 1 : abs(warp.amount)))
                let center = CGPoint(x: lineLeft + lineWidth / 2, y: gy)
                let theta = 2 * .pi * (u + phase)
                let position = CGPoint(x: center.x + radius * sin(theta), y: center.y + radius * cos(theta))
                transform = CGAffineTransform(translationX: position.x, y: position.y).rotated(by: -theta)
            case .scatter:
                // Seeded per-glyph jumble: vertical throw as a fraction of
                // the glyph's font size, plus a tilt. Deterministic in
                // (seed, glyph slot) — same jumble every frame, every run.
                let slot = Int((u * 977).rounded())
                let seed = warp.seed ?? 0
                let throwY = CGFloat(SeededRandom.signedUnit(seed, slot, 1)) * warp.amount * glyph.size
                let tilt = CGFloat(SeededRandom.signedUnit(seed, slot, 2)) * (warp.scatterRotation ?? 0.1)
                transform = CGAffineTransform(translationX: gx, y: gy + throwY).rotated(by: tilt)
            }
            path.addPath(glyph.path, transform: transform)
        }
        return path
    }

    /// A word's on-screen frame accounting for the active warp — the bounding
    /// box of its warped glyphs, so backgrounds, hit-targets, and the selection
    /// box follow the curve. Returns the straight slot frame when no warp.
    static func displayWordFrame(_ slot: CardLayout.WordSlot, layout: CardLayout, warp: TextWarp?, phase: CGFloat = 0) -> CGRect {
        guard let warp else { return slot.frame }
        let path = warpedPath(for: slot, layout: layout, warp: warp, phase: phase)
        guard !path.isEmpty else { return slot.frame }
        let box = path.boundingBoxOfPath
        return box.isNull ? slot.frame : box
    }

    /// The whole caption's on-screen block rect, following the warp when set.
    static func displayBlockRect(_ layout: CardLayout, warp: TextWarp?, phase: CGFloat = 0) -> CGRect {
        guard warp != nil, !layout.words.isEmpty else { return layout.blockRect }
        return layout.words
            .map { displayWordFrame($0, layout: layout, warp: warp, phase: phase) }
            .reduce(CGRect.null) { $0.union($1) }
    }

    /// Fills a rounded "pill" that follows a line's warp curve: the line's
    /// vertical-center baseline is traced across the curve and stroked thick
    /// with round caps, so the background bends with the text instead of sitting
    /// under it as a flat rectangle.
    private static func fillWarpRibbon(
        line: CardLayout.LineSlot,
        layout: CardLayout,
        warp: TextWarp,
        color: StyleColor,
        padV: CGFloat,
        in context: CGContext
    ) {
        let frame = line.frame
        guard frame.width > 1 else { return }
        let thickness = frame.height + 2 * padV
        let samples = max(8, Int(frame.width / 12))
        let ribbon = CGMutablePath()
        for i in 0...samples {
            let u = CGFloat(i) / CGFloat(samples)
            let point = CGPoint(
                x: frame.minX + u * frame.width,
                y: frame.midY + warpOffset(u: u, lineWidth: frame.width, warp: warp).dy
            )
            if i == 0 { ribbon.move(to: point) } else { ribbon.addLine(to: point) }
        }
        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(thickness)
        context.setLineJoin(.round)
        context.setLineCap(.round)
        context.addPath(ribbon)
        context.strokePath()
        context.restoreGState()
    }

    /// The curve's vertical offset and tangent angle at normalized position
    /// `u`. Circle and scatter place glyphs in 2D inside
    /// ``warpedGlyphPath`` instead, so they contribute no baseline offset
    /// here (the warp ribbon stays straight under them).
    private static func warpOffset(u: CGFloat, lineWidth: CGFloat, warp: TextWarp) -> (dy: CGFloat, angle: CGFloat) {
        let amplitude = warp.amount * lineWidth
        switch warp.shape {
        case .arc:
            let dy = amplitude * (1 - pow(2 * u - 1, 2))
            let slope = -4 * warp.amount * (2 * u - 1)
            return (dy, atan(slope))
        case .wave:
            let n = max(0.1, warp.waves ?? 1)
            let dy = amplitude * sin(2 * .pi * n * u)
            let slope = warp.amount * 2 * .pi * n * cos(2 * .pi * n * u)
            return (dy, atan(slope))
        case .circle, .scatter, .snake:
            return (0, 0)
        }
    }

    /// Clips the context to a line's glyph outlines and runs `paint` inside
    /// them, leaving the drawing mode back at `.fill`. The single glyph-mask
    /// primitive shared by every gradient and image fill.
    private static func clipToGlyphs(
        _ line: CTLine,
        at origin: CGPoint,
        in context: CGContext,
        _ paint: (CGContext) -> Void
    ) {
        context.saveGState()
        context.setTextDrawingMode(.clip)
        context.textPosition = origin
        CTLineDraw(line, context)
        paint(context)
        context.restoreGState()
        context.setTextDrawingMode(.fill)
    }

    /// The hue rotation (in turns) for a drifting gradient at the state's
    /// quantized clock — `0` for static gradients.
    private static func driftTurns(_ fill: GradientFill, clock: Int?) -> Double {
        guard let clock, let drift = fill.drift, drift != 0 else { return 0 }
        let turns = (Double(clock) / 120 * Double(drift)).truncatingRemainder(dividingBy: 1)
        return turns < 0 ? turns + 1 : turns
    }

    /// The gradient with every stop's hue rotated by `turns` — the drifting
    /// iridescent fill. Returns the fill untouched at `0`.
    private static func hueShifted(_ fill: GradientFill, turns: Double) -> GradientFill {
        guard turns != 0 else { return fill }
        var shifted = fill
        shifted.colors = fill.colors.map { $0.hueRotated(turns: turns) }
        return shifted
    }

    /// Paints a linear gradient across `rect` (already clipped by the caller).
    private static func paintLinearGradient(_ fill: GradientFill, in rect: CGRect, in context: CGContext, hueTurns: Double = 0) {
        let fill = hueShifted(fill, turns: hueTurns)
        guard fill.colors.count >= 2, let gradient = cgGradient(for: fill) else { return }
        let radians = fill.angle * .pi / 180
        let direction = CGVector(dx: cos(radians), dy: sin(radians))
        let half = abs(direction.dx) * rect.width / 2 + abs(direction.dy) * rect.height / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: center.x - direction.dx * half, y: center.y - direction.dy * half),
            end: CGPoint(x: center.x + direction.dx * half, y: center.y + direction.dy * half),
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
    }

    /// Aspect-fills an image to cover `rect` (already clipped by the caller),
    /// centered — so the glyph mask shows the busiest part of the photo.
    private static func paintImage(_ image: CGImage, in rect: CGRect, in context: CGContext) {
        let iw = CGFloat(image.width), ih = CGFloat(image.height)
        guard iw > 0, ih > 0, rect.width > 0, rect.height > 0 else { return }
        let scale = max(rect.width / iw, rect.height / ih)
        let w = iw * scale, h = ih * scale
        context.draw(image, in: CGRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h))
    }

    private static func cgGradient(for fill: GradientFill) -> CGGradient? {
        gradientLock.lock(); defer { gradientLock.unlock() }
        if let hit = gradientCache[fill] { return hit }
        guard let made = CGGradient(colorsSpace: nil, colors: fill.colors.map(\.cgColor) as CFArray, locations: nil) else { return nil }
        if gradientCache.count > 64 { gradientCache.removeAll() }
        gradientCache[fill] = made
        return made
    }






    // MARK: - Confetti burst


}

// MARK: - Hue rotation (gradient drift)

extension StyleColor {
    /// The color with its hue rotated by `turns` (fraction of the wheel),
    /// preserving saturation, brightness, and alpha — the drifting-gradient
    /// primitive.
    func hueRotated(turns: Double) -> StyleColor {
        guard turns != 0 else { return self }
        let maxC = max(red, green, blue), minC = min(red, green, blue)
        let delta = maxC - minC
        guard delta > 0.0001 else { return self }   // grays have no hue
        var hue: Double
        if maxC == red { hue = ((green - blue) / delta).truncatingRemainder(dividingBy: 6) }
        else if maxC == green { hue = (blue - red) / delta + 2 }
        else { hue = (red - green) / delta + 4 }
        hue /= 6
        if hue < 0 { hue += 1 }
        hue = (hue + turns).truncatingRemainder(dividingBy: 1)
        if hue < 0 { hue += 1 }

        let saturation = maxC == 0 ? 0 : delta / maxC
        let value = maxC
        let sector = hue * 6
        let i = floor(sector)
        let f = sector - i
        let p = value * (1 - saturation)
        let q = value * (1 - saturation * f)
        let t = value * (1 - saturation * (1 - f))
        let (r, g, b): (Double, Double, Double)
        switch Int(i) % 6 {
        case 0: (r, g, b) = (value, t, p)
        case 1: (r, g, b) = (q, value, p)
        case 2: (r, g, b) = (p, value, t)
        case 3: (r, g, b) = (p, q, value)
        case 4: (r, g, b) = (t, p, value)
        default: (r, g, b) = (value, p, q)
        }
        return StyleColor(red: r, green: g, blue: b, alpha: alpha)
    }
}



// MARK: - Image fill cache

/// Images used to fill glyphs, decoded once per URL.
///
/// Backs ``CaptionStyle/imageFill`` and ``WordStyle/imageFill`` — the texture
/// painted inside the letters. Thread-safe via `NSCache`, and the pixels are
/// deterministic for a given file, so a frame drawn twice is the same frame.
///
/// Only the first frame of a multi-frame file is read: a glyph fill cannot
/// animate, so decoding the rest would be work thrown away.
enum ImageFillCache {

    // NSCache is documented thread-safe; Swift 6 can't see that.
    nonisolated(unsafe) private static let cache = NSCache<NSURL, CGImage>()

    /// The image at `url`, decoded once and kept.
    static func image(for url: URL) -> CGImage? {
        if let cached = cache.object(forKey: url as NSURL) { return cached }

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetCount(source) > 0,
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }

        cache.setObject(image, forKey: url as NSURL)
        return image
    }
}
