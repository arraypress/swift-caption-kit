//
//  CaptionLayout.swift
//  CaptionKitLite
//
//  Created by David Sherlock on 2026.
//

import CoreGraphics
import CoreText
import Foundation

/// The pixel-space layout of one caption card: per-word frames, baselines,
/// and prebuilt CoreText lines.
///
/// Layout is computed word-by-word (each word is its own `CTLine`) so the
/// renderer knows every word's exact frame — required for karaoke fills,
/// per-word pops, and per-word colors. Word positions are fixed for the
/// card's whole duration; entrance animations reveal words into their
/// reserved slots rather than reflowing the line.
///
/// All rects are in **CoreGraphics coordinates** (origin bottom-left, y up)
/// at the full render resolution.
struct CardLayout {

    struct WordSlot {
        /// Index into `card.words`.
        let index: Int
        let word: Word
        let lineIndex: Int
        /// The glyph band: baseline − descent … baseline + ascent.
        let frame: CGRect
        /// Where `CTLineDraw` should start drawing (the baseline origin).
        let baselineOrigin: CGPoint
        /// The word drawn with fill-from-context (color set at draw time).
        let fillLine: CTLine
        /// Stroke-only outline lines, ordered **widest-first** (each carries
        /// its own baked stroke color). Empty when the word has no outline.
        let strokeLines: [CTLine]
        /// Mixed letters: one seeded cut-out per character (font, ink,
        /// chip, tilt all baked). `nil` for normal words — the renderer takes
        /// the per-character path only when this is present.
        let charSlots: [CharSlot]?
    }

    /// One mixed letter: its own line (font + ink color baked), placed
    /// relative to the word's baseline origin, with a seeded tilt and paper
    /// chip behind it.
    struct CharSlot {
        /// The single-character line, ink color baked in.
        let line: CTLine
        /// Baseline x offset from the word's baseline origin.
        let x: CGFloat
        /// Baseline y offset (seeded jitter) from the word's baseline.
        let dy: CGFloat
        let width: CGFloat
        let ascent: CGFloat
        let descent: CGFloat
        /// Seeded tilt in radians, applied about the letter's center.
        let tilt: CGFloat
        /// The paper chip behind the letter; `nil` = a bare letter.
        let chip: StyleColor?
    }

    struct LineSlot {
        let index: Int
        /// The glyph band around all of the line's words.
        let frame: CGRect
        /// Indexes (into `words`) of the words on this line.
        let wordIndexes: [Int]
    }

    let words: [WordSlot]
    let lines: [LineSlot]
    /// The tight rect around all lines.
    let blockRect: CGRect
    /// The resolved font pixel size after reference scaling and width fitting.
    let fontPixelSize: CGFloat
    /// Pixels per reference point (`renderHeight / 1920`).
    let referenceScale: CGFloat
    /// The vertical distance between line baselines.
    let lineAdvance: CGFloat
    /// The effective gap between adjacent words, in pixels.
    let spaceWidth: CGFloat
}

enum CaptionLayout {

    /// The reference frame height that style point values are specified at.
    static let referenceHeight: CGFloat = 1920

    // MARK: - Layout cache

    // `layout` is a pure function of (card, style, config) — no time. During
    // playback the document doesn't change, so every frame of a card would
    // otherwise re-run the same CoreText typesetting (the dominant preview
    // cost). Cache by exact-equal inputs: an edit makes the key non-equal, so
    // there's no staleness — the recompute happens automatically.
    private struct LayoutCacheEntry {
        let card: CaptionCard
        let style: CaptionStyle
        let config: RenderConfig
        let layout: CardLayout
    }
    private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var cache: [LayoutCacheEntry] = []
    private static let cacheLimit = 8

    /// Empties the cache. Call after runtime font registration — a layout
    /// cached against the pre-registration fallback font would otherwise serve
    /// stale glyph metrics until the card or style is edited.
    static func flush() {
        cacheLock.lock(); cache.removeAll(); cacheLock.unlock()
    }

    private static func cachedLayout(card: CaptionCard, style: CaptionStyle, config: RenderConfig) -> CardLayout? {
        cacheLock.lock(); defer { cacheLock.unlock() }
        guard let idx = cache.firstIndex(where: { $0.config == config && $0.card == card && $0.style == style }) else { return nil }
        let entry = cache.remove(at: idx)
        cache.insert(entry, at: 0)   // move-to-front LRU
        return entry.layout
    }

    private static func storeLayout(_ layout: CardLayout?, card: CaptionCard, style: CaptionStyle, config: RenderConfig) {
        guard let layout else { return }
        cacheLock.lock(); defer { cacheLock.unlock() }
        cache.insert(LayoutCacheEntry(card: card, style: style, config: config, layout: layout), at: 0)
        if cache.count > cacheLimit { cache.removeLast(cache.count - cacheLimit) }
    }

    /// Lays out a card at the render resolution (cached by its exact inputs).
    static func layout(
        card: CaptionCard,
        style: CaptionStyle,
        config: RenderConfig
    ) -> CardLayout? {
        if let hit = cachedLayout(card: card, style: style, config: config) { return hit }
        let result = computeLayout(card: card, style: style, config: config)
        storeLayout(result, card: card, style: style, config: config)
        return result
    }

    private static func computeLayout(
        card: CaptionCard,
        style: CaptionStyle,
        config: RenderConfig
    ) -> CardLayout? {
        let canvas = config.size
        guard !card.words.isEmpty, canvas.width > 0, canvas.height > 0 else { return nil }

        let referenceScale = canvas.height / referenceHeight
        var fontSize = max(1, style.fontSize * referenceScale)

        // Folded warps (ring, serpentine) wrap the line around the anchor —
        // the STRAIGHT width is meaningless for them, so fitting the font to
        // the frame width would just shrink the glyphs (a long repeated
        // phrase is exactly how those looks get their path length), and the
        // safe-area clamp would drag the fold's center away from the anchor.
        let folded = style.textWarp.map { $0.shape == .circle || $0.shape == .snake } ?? false

        // First pass at the requested size; if the widest line overflows
        // `maxWidthFraction`, scale the font down once and re-measure
        // (measurement is linear in font size, so one pass converges).
        let maxBlockWidth = canvas.width * min(1, max(0.1, style.maxWidthFraction))
        var metrics = measure(card: card, style: style, fontSize: fontSize, referenceScale: referenceScale)
        if !folded, metrics.blockWidth > maxBlockWidth {
            fontSize = max(1, fontSize * maxBlockWidth / metrics.blockWidth)
            metrics = measure(card: card, style: style, fontSize: fontSize, referenceScale: referenceScale)
        }

        // Anchor the block at the style's normalized position (top-left
        // origin), clamped into the safe area, then convert to CG (y-up).
        let safe = config.safeAreaRect
        let blockWidth = metrics.blockWidth
        let blockHeight = metrics.blockHeight

        var blockLeft = style.position.x * canvas.width - blockWidth / 2
        var blockTop = style.position.y * canvas.height - blockHeight / 2
        if !folded {
            blockLeft = clamp(blockLeft, min(safe.minX, safe.maxX - blockWidth), max(safe.minX, safe.maxX - blockWidth))
            blockTop = clamp(blockTop, min(safe.minY, safe.maxY - blockHeight), max(safe.minY, safe.maxY - blockHeight))
        }

        let blockBottomCG = canvas.height - blockTop - blockHeight

        var wordSlots: [CardLayout.WordSlot] = []
        wordSlots.reserveCapacity(card.words.count)
        var lineSlots: [CardLayout.LineSlot] = []

        var wordCursor = 0
        var consumedTop: CGFloat = 0
        for (lineIndex, line) in metrics.lines.enumerated() {
            let lineWidth = line.totalWidth
            let lineX: CGFloat
            switch style.alignment {
            case .leading: lineX = blockLeft
            case .center: lineX = blockLeft + (blockWidth - lineWidth) / 2
            case .trailing: lineX = blockLeft + blockWidth - lineWidth
            }

            // Line boxes stack top-down (heights vary with per-word size
            // overrides); convert each to a CG-space band. Words on a line
            // share one baseline; each word's frame is its own glyph band.
            let boxBottom = blockBottomCG + blockHeight - consumedTop - line.advance
            let bandInset = (line.advance - (line.ascent + line.descent)) / 2
            let baselineY = boxBottom + bandInset + line.descent
            consumedTop += line.advance

            var x = lineX
            var indexes: [Int] = []
            for measured in line.words {
                let frame = CGRect(
                    x: x,
                    y: baselineY - measured.descent,
                    width: measured.width,
                    height: measured.ascent + measured.descent
                )
                wordSlots.append(CardLayout.WordSlot(
                    index: wordCursor,
                    word: measured.word,
                    lineIndex: lineIndex,
                    frame: frame,
                    baselineOrigin: CGPoint(x: x, y: baselineY),
                    fillLine: measured.fillLine,
                    strokeLines: measured.strokeLines,
                    charSlots: measured.charSlots
                ))
                indexes.append(wordCursor)
                wordCursor += 1
                x += measured.width + metrics.spaceWidth
            }

            lineSlots.append(CardLayout.LineSlot(
                index: lineIndex,
                frame: CGRect(
                    x: lineX,
                    y: baselineY - line.descent,
                    width: lineWidth,
                    height: line.ascent + line.descent
                ),
                wordIndexes: indexes
            ))
        }

        return CardLayout(
            words: wordSlots,
            lines: lineSlots,
            blockRect: CGRect(x: blockLeft, y: blockBottomCG, width: blockWidth, height: blockHeight),
            fontPixelSize: fontSize,
            referenceScale: referenceScale,
            lineAdvance: metrics.baseAdvance,
            spaceWidth: metrics.spaceWidth
        )
    }

    // MARK: - Measurement

    private struct MeasuredWord {
        let word: Word
        let width: CGFloat
        let ascent: CGFloat
        let descent: CGFloat
        let fillLine: CTLine
        let strokeLines: [CTLine]
        let charSlots: [CardLayout.CharSlot]?
    }

    private struct MeasuredLine {
        let words: [MeasuredWord]
        let totalWidth: CGFloat
        /// Tallest metrics on the line — per-word size overrides can make one
        /// word taller than its neighbors.
        let ascent: CGFloat
        let descent: CGFloat
        let advance: CGFloat
    }

    private struct Metrics {
        let lines: [MeasuredLine]
        let blockWidth: CGFloat
        let blockHeight: CGFloat
        /// The advance of a line of un-overridden words (used for animation
        /// magnitudes).
        let baseAdvance: CGFloat
        let spaceWidth: CGFloat
    }

    private static func measure(
        card: CaptionCard,
        style: CaptionStyle,
        fontSize: CGFloat,
        referenceScale: CGFloat
    ) -> Metrics {
        let slant = min(max(style.slant ?? 0, -0.6), 0.6)
        let baseFont = FontResolver.font(family: style.fontFamily, weight: style.fontWeight, size: fontSize, slant: slant)
        let kern = style.letterSpacing * referenceScale
        let lineSpacing = max(0.5, style.lineSpacing)
        let baseAdvance = (CTFontGetAscent(baseFont) + CTFontGetDescent(baseFont) + CTFontGetLeading(baseFont)) * lineSpacing

        // Word gap: the font's space, scaled by the style, widened by the
        // widest global outline (outlines grow every glyph outward by half the
        // stroke on each side, which otherwise swallows the visual gap).
        let globalStrokePts = style.resolvedStrokes(for: nil).map(\.width).max() ?? 0
        let strokePixels = globalStrokePts * referenceScale
        let spaceWidth = lineWidth(makeLine(" ", font: baseFont, kern: 0, stroke: nil))
            * max(0.2, style.wordSpacing) + strokePixels

        var measuredLines: [MeasuredLine] = []
        var blockWidth: CGFloat = 0
        var blockHeight: CGFloat = 0
        var wordCounter = 0   // flat word index — seeds the ransom letters
        for lineWords in card.lines {
            var measured: [MeasuredWord] = []
            var total: CGFloat = 0
            var maxAscent: CGFloat = 0
            var maxDescent: CGFloat = 0
            var maxLeading: CGFloat = 0
            for word in lineWords {
                // Per-word overrides resolve to a per-word font; stroke width
                // stays constant in pixels (the CoreText attribute is a
                // percentage of font size, so it's recomputed per word).
                let overrides = word.style
                let wordSize = fontSize * max(0.1, overrides?.sizeMultiplier ?? 1)
                // Per-word slant overrides the global shear; clamp to the same
                // sane range so an extreme value can't lay the glyphs flat.
                let wordSlant = min(max(overrides?.slant ?? slant, -0.6), 0.6)
                let font: CTFont
                if overrides?.fontFamily == nil, overrides?.fontWeight == nil, wordSize == fontSize, wordSlant == slant {
                    font = baseFont
                } else {
                    font = FontResolver.font(
                        family: overrides?.fontFamily ?? style.fontFamily,
                        weight: overrides?.fontWeight ?? style.fontWeight,
                        size: wordSize,
                        slant: wordSlant
                    )
                }
                // Inline emoji rides the word's own line — it pops, scales,
                // and karaoke-clips together with its word.
                var text = transformed(word.text, transform: style.textTransform)
                if let emoji = overrides?.emoji, !emoji.isEmpty {
                    text += " " + emoji
                }
                let fillLine = makeLine(text, font: font, kern: kern, stroke: nil)
                // One stroke-only line per resolved layer, widest-first. The
                // CoreText stroke-width attribute is a percent of the font size,
                // so it's recomputed against this word's own size.
                let strokeLines = style.resolvedStrokes(for: overrides).map { layer in
                    makeLine(text, font: font, kern: kern,
                             stroke: (layer.color.cgColor, layer.width * referenceScale / wordSize * 100))
                }
                // Mixed letters: each character measured as its own seeded
                // cut-out; the word's width/height come from the letters.
                let charSlots = style.mixedLetters.map {
                    mixedLetterChars(text, mixedLetters: $0, wordIndex: wordCounter,
                                wordSize: wordSize, weight: overrides?.fontWeight ?? style.fontWeight)
                }
                let measuredWidth: CGFloat
                let measuredAscent: CGFloat
                let measuredDescent: CGFloat
                if let charSlots, let last = charSlots.last {
                    measuredWidth = last.x + last.width
                    measuredAscent = charSlots.map(\.ascent).max() ?? CTFontGetAscent(font)
                    measuredDescent = charSlots.map(\.descent).max() ?? CTFontGetDescent(font)
                } else {
                    measuredWidth = lineWidth(fillLine)
                    measuredAscent = CTFontGetAscent(font)
                    measuredDescent = CTFontGetDescent(font)
                }
                measured.append(MeasuredWord(
                    word: word,
                    width: measuredWidth,
                    ascent: measuredAscent,
                    descent: measuredDescent,
                    fillLine: fillLine,
                    strokeLines: strokeLines,
                    charSlots: charSlots
                ))
                total += measured.last!.width
                maxAscent = max(maxAscent, measuredAscent)
                maxDescent = max(maxDescent, measuredDescent)
                maxLeading = max(maxLeading, CTFontGetLeading(font))
                wordCounter += 1
            }
            total += spaceWidth * CGFloat(max(0, measured.count - 1))
            let advance = (maxAscent + maxDescent + maxLeading) * lineSpacing
            measuredLines.append(MeasuredLine(
                words: measured,
                totalWidth: total,
                ascent: maxAscent,
                descent: maxDescent,
                advance: advance
            ))
            blockWidth = max(blockWidth, total)
            blockHeight += advance
        }

        return Metrics(
            lines: measuredLines,
            blockWidth: blockWidth,
            blockHeight: blockHeight,
            baseAdvance: baseAdvance,
            spaceWidth: spaceWidth
        )
    }

    /// Measures one word as mixed letters (the ransom-note preset look): every character gets a
    /// seeded font, size jitter, ink color, paper chip, tilt, and baseline
    /// bounce — all deterministic in (seed, word, character), so the same
    /// project always shows the same cut-outs.
    private static func mixedLetterChars(
        _ text: String,
        mixedLetters: MixedLetterStyle,
        wordIndex: Int,
        wordSize: CGFloat,
        weight: FontWeight
    ) -> [CardLayout.CharSlot] {
        let families = mixedLetters.fontFamilies.isEmpty ? MixedLetterStyle.defaultFontFamilies : mixedLetters.fontFamilies
        let inks = mixedLetters.colors.isEmpty ? MixedLetterStyle.defaultColors : mixedLetters.colors
        // The default chip set mixes in bare letters (clear entries).
        let chips = mixedLetters.chipColors.isEmpty
            ? MixedLetterStyle.defaultChipColors + [.clear, .clear]
            : mixedLetters.chipColors

        func luminance(_ color: StyleColor) -> Double {
            0.299 * color.red + 0.587 * color.green + 0.114 * color.blue
        }

        var slots: [CardLayout.CharSlot] = []
        var x: CGFloat = 0
        for (charIndex, character) in text.enumerated() {
            let seed = mixedLetters.seed
            let sizeJitter = 0.88 + 0.28 * SeededRandom.unit(seed, wordIndex, charIndex, 1)
            let charSize = wordSize * sizeJitter
            let family = families[Int(SeededRandom.unit(seed, wordIndex, charIndex, 2) * Double(families.count)) % families.count]
            let font = FontResolver.font(family: family, weight: weight, size: charSize)
            let chipPick = chips[Int(SeededRandom.unit(seed, wordIndex, charIndex, 3) * Double(chips.count)) % chips.count]
            let chip: StyleColor? = chipPick.alpha > 0.01 ? chipPick : nil
            var ink = inks[Int(SeededRandom.unit(seed, wordIndex, charIndex, 4) * Double(inks.count)) % inks.count]
            // A cream letter on a cream chip vanishes — nudge the ink to the
            // next color when the pair is too close in luminance.
            if let chip, abs(luminance(ink) - luminance(chip)) < 0.25,
               let index = inks.firstIndex(of: ink) {
                ink = inks[(index + 1) % inks.count]
            }
            let tilt = CGFloat(SeededRandom.signedUnit(seed, wordIndex, charIndex, 5)) * mixedLetters.rotationMax
            let dy = CGFloat(SeededRandom.signedUnit(seed, wordIndex, charIndex, 6)) * charSize * 0.06

            let attributes: [CFString: Any] = [
                kCTFontAttributeName: font,
                kCTForegroundColorAttributeName: ink.cgColor,   // baked — not context-fed
            ]
            guard let attributed = CFAttributedStringCreate(nil, String(character) as CFString, attributes as CFDictionary) else { continue }
            let line = CTLineCreateWithAttributedString(attributed)
            let width = lineWidth(line)
            slots.append(CardLayout.CharSlot(
                line: line,
                x: x,
                dy: dy,
                width: width,
                ascent: CTFontGetAscent(font),
                descent: CTFontGetDescent(font),
                tilt: tilt,
                chip: chip
            ))
            // Slight tracking so tilted chips don't fuse into one strip.
            x += width + charSize * 0.08
        }
        return slots
    }

    /// The exact string a word lays out as (case transform + inline emoji)
    /// — shared with the renderer so re-resolved lines (weight ramps) can
    /// never drift from the layout's text.
    static func lineText(for word: Word, style: CaptionStyle) -> String {
        var text = transformed(word.text, transform: style.textTransform)
        if let emoji = word.style?.emoji, !emoji.isEmpty {
            text += " " + emoji
        }
        return text
    }

    static func makeLine(
        _ text: String,
        font: CTFont,
        kern: CGFloat,
        stroke: (color: CGColor, percent: CGFloat)?
    ) -> CTLine {
        var attributes: [CFString: Any] = [
            kCTFontAttributeName: font,
            // Fill color comes from the graphics context at draw time, so one
            // CTLine serves every color state (base, highlight, karaoke).
            kCTForegroundColorFromContextAttributeName: true,
        ]
        if kern != 0 {
            attributes[kCTKernAttributeName] = kern
        }
        if let stroke {
            attributes[kCTStrokeWidthAttributeName] = stroke.percent
            attributes[kCTStrokeColorAttributeName] = stroke.color
        }
        let attributed = CFAttributedStringCreate(nil, text as CFString, attributes as CFDictionary)!
        return CTLineCreateWithAttributedString(attributed)
    }

    static func lineWidth(_ line: CTLine) -> CGFloat {
        CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    }

    static func transformed(_ text: String, transform: TextTransform) -> String {
        switch transform {
        case .none: return text
        case .uppercase: return text.uppercased()
        case .lowercase: return text.lowercased()
        }
    }

    private static func clamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }
}

// MARK: - Font Resolution

enum FontResolver {

    /// Resolves a `CTFont` for a family + weight, falling back to the system
    /// UI font family when no family is named.
    ///
    /// Resolution goes through a font *descriptor* so the weight trait
    /// participates in matching — asking for "Avenir Next" + heavy finds
    /// "AvenirNext-Heavy". CoreText's cascade handles emoji and non-Latin
    /// fallback automatically.
    static func font(family: String?, weight: FontWeight, size: CGFloat, slant: CGFloat = 0) -> CTFont {
        font(family: family, weightTrait: weight.traitValue, size: size, slant: slant)
    }

    /// Resolves a font at a RAW weight-trait value (`-1…1`) — the continuous
    /// axis the weight-ramp animation interpolates along. Variable fonts
    /// (San Francisco included) resolve smoothly; static families snap to
    /// the nearest face.
    static func font(family: String?, weightTrait: CGFloat, size: CGFloat, slant: CGFloat = 0) -> CTFont {
        // The system font's hidden family name doesn't weight-match through
        // descriptor MATCHING — apply the trait to the font itself instead
        // (the documented route to weighted San Francisco, and the one that
        // resolves the variable weight axis continuously).
        if family == nil, let systemFont = CTFontCreateUIFontForLanguage(.system, size, nil) {
            let traits: [CFString: Any] = [kCTFontWeightTrait: weightTrait]
            let attributes: [CFString: Any] = [kCTFontTraitsAttribute: traits]
            let descriptor = CTFontDescriptorCreateWithAttributes(attributes as CFDictionary)
            if slant != 0 {
                var matrix = CGAffineTransform(a: 1, b: 0, c: slant, d: 1, tx: 0, ty: 0)
                return CTFontCreateCopyWithAttributes(systemFont, size, &matrix, descriptor)
            }
            return CTFontCreateCopyWithAttributes(systemFont, size, nil, descriptor)
        }
        let familyName: String
        if let family {
            familyName = family
        } else if let systemFont = CTFontCreateUIFontForLanguage(.system, size, nil) {
            familyName = CTFontCopyFamilyName(systemFont) as String
        } else {
            familyName = "Helvetica Neue"
        }

        let traits: [CFString: Any] = [kCTFontWeightTrait: weightTrait]
        let attributes: [CFString: Any] = [
            kCTFontFamilyNameAttribute: familyName,
            kCTFontTraitsAttribute: traits,
        ]
        let descriptor = CTFontDescriptorCreateWithAttributes(attributes as CFDictionary)
        // Synthetic italic: a shear in the font matrix leans the glyphs
        // without touching their advances, so layout stays stable.
        if slant != 0 {
            var matrix = CGAffineTransform(a: 1, b: 0, c: slant, d: 1, tx: 0, ty: 0)
            return CTFontCreateWithFontDescriptor(descriptor, size, &matrix)
        }
        return CTFontCreateWithFontDescriptor(descriptor, size, nil)
    }
}
