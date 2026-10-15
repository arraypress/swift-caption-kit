//
//  CaptionRenderer+Extras.swift
//  CaptionKit
//
//  Created by David Sherlock on 2026.
//
//  What a card draws besides its words: the speaker's name (a bold line
//  above the text, or a chip) and a second-language line. Both sit above
//  the caption block, ride the card's entrance and opacity, and are laid
//  out from the card alone — the same card always draws them the same way.
//

@_spi(CaptionEngine) import CaptionCore
import CoreGraphics
import CoreText
import Foundation

extension CaptionRenderer {

    /// The extras laid out for one card, in canvas pixels (CG, y-up).
    struct CardExtras {

        /// One line of text and where it goes.
        struct Text {
            let line: CTLine
            /// Outline passes, widest first, drawn under the fill.
            let strokes: [CTLine]
            let origin: CGPoint
            let rect: CGRect
            let color: StyleColor
        }

        /// The speaker's name.
        var label: Text?
        /// The chip behind the name, when it is one.
        var chip: (rect: CGRect, color: StyleColor)?
        /// The second-language line.
        var secondary: Text?
        /// What a block background should also cover: the name over the text.
        var backgroundRect: CGRect?

        /// Every extra's bounds together; `.null` when there are none.
        var bounds: CGRect {
            [label?.rect, chip?.rect, secondary?.rect].compactMap { $0 }.reduce(CGRect.null) { $0.union($1) }
        }
    }

    /// The speaker colours in force: the document's, else the style's.
    static func speakerPalette(document: CaptionDocument, style: CaptionStyle) -> [StyleColor]? {
        if let colors = document.speakerColors, !colors.isEmpty { return colors }
        if let colors = style.speakerColors, !colors.isEmpty { return colors }
        return nil
    }

    /// The block's rotation for `card`: the style's fixed tilt plus its seeded
    /// per-card tilt.
    static func blockRotation(for card: CaptionCard, style: CaptionStyle) -> CGFloat {
        var rotation = style.blockRotation ?? 0
        if let tilt = style.cardTilt, tilt != 0 {
            rotation += CGFloat(SeededRandom.signedUnit(Int((card.start * 1000).rounded()), 29)) * tilt
        }
        return rotation
    }

    /// The name a speaker is shown under.
    static func speakerName(_ speaker: Int, document: CaptionDocument) -> String {
        if let names = document.speakerNames, speaker < names.count {
            let name = names[speaker].trimmingCharacters(in: .whitespaces)
            if !name.isEmpty { return name }
        }
        return "Speaker \(speaker + 1)"
    }

    /// The secondary words that belong to `card`: those whose midpoint falls
    /// between its first word and its end.
    static func secondaryWords(for card: CaptionCard, in words: [Word]) -> [Word] {
        guard let first = card.words.first else { return [] }
        return words.filter {
            let middle = ($0.start + $0.end) / 2
            return middle >= first.start && middle < card.end
        }
    }

    /// Lays out `card`'s extras above its block.
    static func cardExtras(card: CaptionCard, style: CaptionStyle, layout: CardLayout,
                           document: CaptionDocument) -> CardExtras {
        var extras = CardExtras()
        guard style.speakerLabel != nil || style.secondaryLine != nil else { return extras }
        let block = layout.blockRect
        let canvas = document.renderConfig.size
        let kern = style.letterSpacing * layout.referenceScale
        var top = block.maxY

        func aligned(_ width: CGFloat) -> CGFloat {
            let x: CGFloat
            switch style.alignment {
            case .leading: x = block.minX
            case .center: x = block.midX - width / 2
            case .trailing: x = block.maxX - width
            }
            return min(max(0, x), max(0, canvas.width - width))
        }

        // The speaker's name, when the card's words carry one.
        if let label = style.speakerLabel, let speaker = card.words.compactMap(\.speaker).first, speaker >= 0 {
            var name = speakerName(speaker, document: document)
            if label.uppercase == true { name = name.uppercased() }
            let size = max(1, layout.fontPixelSize * max(0.1, label.scale))
            let font = FontResolver.font(family: style.fontFamily, weight: label.fontWeight, size: size)
            let line = CaptionLayout.makeLine(name, font: font, kern: kern, stroke: nil)
            let width = CaptionLayout.lineWidth(line)
            let ascent = CTFontGetAscent(font), descent = CTFontGetDescent(font)
            let speakerColor = speakerPalette(document: document, style: style).map { $0[speaker % $0.count] }
            switch label.mode {
            case .above:
                let baseline = top + size * 0.35 + descent
                let rect = CGRect(x: aligned(width), y: baseline - descent, width: width, height: ascent + descent)
                let color = label.color ?? speakerColor ?? style.activeWordColor ?? style.textColor
                extras.label = .init(line: line, strokes: [], origin: CGPoint(x: rect.minX, y: baseline), rect: rect, color: color)
                extras.backgroundRect = rect
                top = rect.maxY
            case .chip:
                let padH = size * 0.55, padV = size * 0.28
                let chipWidth = width + padH * 2
                let rect = CGRect(x: aligned(chipWidth), y: top + layout.fontPixelSize * 0.2,
                                  width: chipWidth, height: ascent + descent + padV * 2)
                let fill = speakerColor ?? style.activeWordColor ?? .yellow
                let ink = label.color ?? (Contrast.luminance(fill) > 0.4
                    ? StyleColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1) : .white)
                extras.chip = (rect, fill)
                extras.label = .init(line: line, strokes: [], origin: CGPoint(x: rect.minX + padH, y: rect.minY + padV + descent),
                                     rect: rect, color: ink)
                top = rect.maxY
            }
        }

        // The second-language line.
        if let secondary = style.secondaryLine, let all = document.secondaryWords, !all.isEmpty {
            let picked = secondaryWords(for: card, in: all)
            if !picked.isEmpty {
                var text = CaptionLayout.transformed(picked.map(\.text).joined(separator: " "), transform: style.textTransform)
                if style.textTransform == .sentence { text = CaptionLayout.capitalisedFirstLetter(text) }
                let weight = secondary.fontWeight ?? style.fontWeight
                var size = max(1, layout.fontPixelSize * max(0.1, secondary.scale))
                var font = FontResolver.font(family: style.fontFamily, weight: weight, size: size)
                var line = CaptionLayout.makeLine(text, font: font, kern: kern, stroke: nil)
                let room = canvas.width * min(1, max(0.1, style.maxWidthFraction))
                let measured = CaptionLayout.lineWidth(line)
                if measured > room {
                    size = max(1, size * room / measured)
                    font = FontResolver.font(family: style.fontFamily, weight: weight, size: size)
                    line = CaptionLayout.makeLine(text, font: font, kern: kern, stroke: nil)
                }
                let width = CaptionLayout.lineWidth(line)
                let ascent = CTFontGetAscent(font), descent = CTFontGetDescent(font)
                let baseline = top + secondary.gap * layout.referenceScale + descent
                let rect = CGRect(x: aligned(width), y: baseline - descent, width: width, height: ascent + descent)
                // The caption's outline, scaled with the text, keeps it legible.
                let strokes = style.resolvedStrokes(for: nil).map { layer in
                    CaptionLayout.makeLine(text, font: font, kern: kern,
                                           stroke: (layer.color.cgColor, layer.width * layout.referenceScale * secondary.scale / size * 100))
                }
                let color = secondary.color ?? style.textColor.withAlpha(style.textColor.alpha * 0.85)
                extras.secondary = .init(line: line, strokes: strokes, origin: CGPoint(x: rect.minX, y: baseline),
                                         rect: rect, color: color)
            }
        }
        return extras
    }

    /// Draws `extras` — chip, then name, then the second line.
    static func drawExtras(_ extras: CardExtras, in context: CGContext) {
        if let chip = extras.chip {
            context.setFillColor(chip.color.cgColor)
            let radius = chip.rect.height / 2
            context.addPath(CGPath(roundedRect: chip.rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
            context.fillPath()
        }
        for text in [extras.label, extras.secondary].compactMap({ $0 }) {
            if !text.strokes.isEmpty {
                context.setLineJoin(.round)
                context.setLineCap(.round)
                for stroke in text.strokes {
                    context.textPosition = text.origin
                    CTLineDraw(stroke, context)
                }
            }
            context.setFillColor(text.color.cgColor)
            context.textPosition = text.origin
            CTLineDraw(text.line, context)
        }
    }
}
