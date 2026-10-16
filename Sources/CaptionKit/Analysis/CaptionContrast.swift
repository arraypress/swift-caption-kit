//
//  CaptionContrast.swift
//  CaptionKit
//
//  Created by David Sherlock on 2026.
//
//  How well the captions stand out from what is around them, measured on
//  the footage rather than judged: in sampled frames, the WCAG contrast
//  ratio between the caption's letters and a thin ring of pixels just
//  outside them (Legibility's `LetterRing`). A stroke, a box or a shadow is
//  in that ring and counts; so is bright footage pressing against thin white
//  letters. And when the
//  measured contrast is low, the scrim that lifts it — a soft gradient over
//  the footage behind the captions — chosen by measuring again.
//

@preconcurrency import AVFoundation
import CoreGraphics
import Foundation
import Legibility

public enum CaptionContrast {

    /// WCAG's minimum for large text, 3:1 — captions are large text.
    public static let minimum = Contrast.largeTextMinimum

    /// The scrim strengths tried, weakest first.
    public static let scrimOpacities: [Double] = [0.4, 0.55, 0.7, 0.85]

    /// One sampled card.
    public struct Card: Codable, Equatable, Sendable {
        /// Source time of the sample, in seconds.
        public var time: TimeInterval
        /// The card's text.
        public var text: String
        /// Text-to-surround contrast, `1…21`.
        public var ratio: Double
        /// Median relative luminance of the letters.
        public var textLuminance: Double
        /// Median relative luminance of the ring around them.
        public var surroundLuminance: Double
    }

    /// Every sampled card, and what they add up to.
    public struct Report: Codable, Equatable, Sendable {
        public var cards: [Card]

        /// The lowest ratio sampled.
        public var worst: Double? { cards.map(\.ratio).min() }
        /// The ratio a quarter of the cards fall below.
        public var lowQuartile: Double? { Contrast.percentile(cards.map(\.ratio), 0.25) }
        /// The median ratio.
        public var median: Double? { Contrast.percentile(cards.map(\.ratio), 0.5) }
        /// How many sampled cards are under ``CaptionContrast/minimum``.
        public var below: Int { cards.filter { $0.ratio < CaptionContrast.minimum }.count }

        /// Low when a quarter or more of the sampled cards are under 3:1.
        public var isLow: Bool { (lowQuartile ?? CaptionContrast.minimum) < CaptionContrast.minimum }

        public init(cards: [Card]) { self.cards = cards }
    }

    /// What the automatic scrim decided.
    public struct ScrimDecision: Sendable {
        /// The scrim to lay over the footage, or `nil` for none.
        public var overlay: GradientOverlay?
        /// Contrast without a scrim.
        public var before: Report
        /// Contrast with the chosen scrim, when there is one.
        public var after: Report?
    }

    // MARK: Measuring

    /// The contrast of `document`'s captions over its footage, at the settled
    /// moment of up to `maximumCards` cards spread through the video, measured
    /// on frames `width` pixels wide with the document's footage effects
    /// (scrim, blur, mirror) applied.
    public static func measure(_ document: CaptionDocument, maximumCards: Int = 12, width: Int = 1080) async -> Report {
        let samples = await prepare(document, maximumCards: maximumCards, width: width)
        return report(samples, document: document)
    }

    /// Decides the scrim: none when the captions already stand out
    /// (``Report/isLow`` is false) unless `force`. Otherwise every strength
    /// in ``scrimOpacities``, weakest first, in black and in white, until one
    /// lifts the low quartile to 3:1; when none does, the one that lifts it
    /// most — and no scrim at all when none lifts it (a caption whose own
    /// box is the problem, say). Dark at the bottom edge for captions in the
    /// lower half, at the top for captions in the upper half.
    public static func scrim(for document: CaptionDocument, force: Bool = false, maximumCards: Int = 12,
                             width: Int = 1080) async -> ScrimDecision {
        var plain = document
        plain.gradientOverlay = nil
        let samples = await prepare(plain, maximumCards: maximumCards, width: width)
        let before = report(samples, document: plain)
        guard force || before.isLow, !before.cards.isEmpty else { return ScrimDecision(overlay: nil, before: before) }

        let centres = samples.compactMap { $0.blockCentreY }
        let lower = (Contrast.percentile(centres, 0.5) ?? 0.75) >= 0.5
        let floor = before.lowQuartile ?? 0
        var best: (overlay: GradientOverlay, report: Report)?
        for opacity in scrimOpacities {
            for shade in [StyleColor.black, StyleColor.white] {
                let overlay = scrimOverlay(color: shade, opacity: opacity, lower: lower)
                var scrimmed = plain
                scrimmed.gradientOverlay = overlay
                let after = report(samples, document: scrimmed)
                if !after.isLow { return ScrimDecision(overlay: overlay, before: before, after: after) }
                if (after.lowQuartile ?? 0) > (best?.report.lowQuartile ?? floor) + 0.1 { best = (overlay, after) }
            }
        }
        if force, best == nil {
            let overlay = scrimOverlay(color: .black, opacity: scrimOpacities[0], lower: lower)
            var scrimmed = plain
            scrimmed.gradientOverlay = overlay
            return ScrimDecision(overlay: overlay, before: before, after: report(samples, document: scrimmed))
        }
        return ScrimDecision(overlay: best?.overlay, before: before, after: best?.report)
    }

    /// The scrim: `color` at `opacity` on the near edge, fading to clear
    /// across the frame (bottom up for captions in the lower half).
    public static func scrimOverlay(color: StyleColor, opacity: Double, lower: Bool) -> GradientOverlay {
        GradientOverlay(color: color, secondColor: nil, opacity: opacity, spread: 1, angleDegrees: lower ? 90 : 270)
    }

    // MARK: The pieces

    /// One sampled card, ready to measure under any footage effect.
    struct Sample {
        let time: TimeInterval
        let text: String
        /// The raw source frame.
        let footage: CGImage
        /// The real caption layer at the analysis size.
        let overlay: CGImage
        /// The letters' interior and the ring touching them, as pixel indexes.
        let interior: [Int]
        let ring: [Int]
        /// The caption block's vertical centre, normalized top-left.
        let blockCentreY: Double?
    }

    static func prepare(_ document: CaptionDocument, maximumCards: Int, width: Int) async -> [Sample] {
        guard let videoURL = document.videoURL, !document.cards.isEmpty else { return [] }
        let config = document.renderConfig
        let scale = CGFloat(width) / CGFloat(max(1, config.width))
        let cards = spread(document.cards, count: maximumCards)

        var captionsOnly = document
        captionsOnly.hook = nil
        captionsOnly.letterbox = nil
        captionsOnly.videoBorder = nil
        captionsOnly.progressBar = nil
        captionsOnly.behindSubject = nil
        let letterDocument = lettersOnly(captionsOnly)

        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: videoURL))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: width * 2, height: width * 2)
        let tolerance = CMTime(seconds: 0.02, preferredTimescale: 600)
        generator.requestedTimeToleranceBefore = tolerance
        generator.requestedTimeToleranceAfter = tolerance

        var samples: [Sample] = []
        for card in cards {
            let style = document.resolvedStyle(for: card)
            let captionTime = SettledMoment.settled(card, style: style) ?? (card.start + card.end) / 2
            let time = max(0, captionTime + document.captionTimingOffset)
            // The caption layer drawn twice, the second kept: a shadow is baked
            // from the second draw of a shape on, as in nearly every exported frame.
            _ = CaptionRenderer.renderOverlay(document: captionsOnly, at: time, scale: scale, layers: .captions)
            guard let footage = try? await generator.image(at: CMTime(seconds: time, preferredTimescale: 600)).image,
                  let overlay = CaptionRenderer.renderOverlay(document: captionsOnly, at: time, scale: scale, layers: .captions),
                  let letters = CaptionRenderer.renderOverlay(document: letterDocument, at: time, scale: scale, layers: .captions)
            else { continue }
            let block = CaptionRenderer.captionBlockRect(document: captionsOnly, at: time)
            // Hollow letters have no fill: their outline is the ink.
            var ink = Pixels.mask(of: letters)
            if !ink.contains(true) { ink = Pixels.mask(of: overlay) }
            guard let parts = LetterRing.regions(letters: ink, width: overlay.width, height: overlay.height,
                                                 referenceScale: Double(overlay.height) / 1920) else { continue }
            samples.append(Sample(time: time, text: card.text, footage: footage, overlay: overlay,
                                  interior: parts.interior, ring: parts.ring, blockCentreY: block.map { Double($0.midY) }))
        }
        return samples
    }

    /// Up to `count` cards spread evenly through `cards`.
    static func spread(_ cards: [CaptionCard], count: Int) -> [CaptionCard] {
        guard cards.count > count, count > 0 else { return cards }
        return (0..<count).map { cards[Int((Double($0) + 0.5) * Double(cards.count) / Double(count))] }
    }

    static func report(_ samples: [Sample], document: CaptionDocument) -> Report {
        Report(cards: samples.compactMap { sample in
            guard let composite = composite(sample, document: document),
                  let measured = LetterRing.measure(composite: composite, interior: sample.interior, ring: sample.ring)
            else { return nil }
            return Card(time: sample.time, text: sample.text, ratio: measured.ratio,
                        textLuminance: measured.text, surroundLuminance: measured.surround)
        })
    }

    /// The frame the viewer sees: footage with the document's footage
    /// effects, then the captions.
    static func composite(_ sample: Sample, document: CaptionDocument) -> CGImage? {
        let width = sample.overlay.width, height = sample.overlay.height
        guard let footage = FootageStage.compose(sample.footage, document: document, at: sample.time, width: width, height: height),
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        context.draw(footage, in: bounds)
        context.draw(sample.overlay, in: bounds)
        return context.makeImage()
    }

    // MARK: Bare letters

    /// `document` drawn as bare letters: no stroke, shadow, glow, box,
    /// highlight bar or 3-D depth, so the overlay's opaque pixels are the
    /// letters' fill alone.
    static func lettersOnly(_ document: CaptionDocument) -> CaptionDocument {
        var bare = document
        bare.style = bareLetters(document.style)
        bare.speakerColors = nil
        for index in bare.cards.indices {
            bare.cards[index].styleOverride = bare.cards[index].styleOverride.map(bareLetters)
            for word in bare.cards[index].words.indices {
                guard var style = bare.cards[index].words[word].style else { continue }
                style.strokeColor = style.strokeColor.map { _ in clear }
                style.strokeLayers = style.strokeLayers?.map { StrokeLayer(color: clear, width: $0.width) }
                style.hardShadow = nil
                style.extrude = nil
                bare.cards[index].words[word].style = style
            }
        }
        return bare
    }

    /// An invisible ink: outlines keep their width — the layout widens word
    /// gaps by it — but draw nothing.
    static let clear = StyleColor(red: 0, green: 0, blue: 0, alpha: 0)

    static func bareLetters(_ style: CaptionStyle) -> CaptionStyle {
        var bare = style
        bare.strokeColor = style.strokeColor.map { _ in clear }
        bare.strokeLayers = style.strokeLayers?.map { StrokeLayer(color: clear, width: $0.width) }
        bare.shadow = nil
        bare.hardShadow = nil
        bare.extrude = nil
        bare.glow = nil
        bare.background = nil
        bare.knockoutPlate = nil
        bare.chromaticAberration = nil
        // The spoken word keeps its pop (its scale) so the letters line up
        // with the real render; only the box, bar or dimming goes.
        bare.highlightMode = style.highlightMode == .none ? .none : .activeWord
        bare.opacity = 1
        return bare
    }
}
