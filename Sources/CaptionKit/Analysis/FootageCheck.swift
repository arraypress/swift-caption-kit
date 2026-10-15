//
//  FootageCheck.swift
//  CaptionKit
//
//  Created by David Sherlock on 2026.
//
//  Whether each footage effect did what it says, measured on frames rather
//  than looked at: a background blur takes the fine detail out of the
//  background and leaves the person, a face cover takes it out of the face,
//  a mirror is the plain frame flipped, a border and a letterbox are solid
//  where they should be, and a caption offset moves when the first caption
//  appears.
//

@preconcurrency import AVFoundation
import CoreGraphics
import Foundation
import Vision

public enum FootageCheck {

    /// What was measured; a field is `nil` when its effect is off.
    public struct Report: Codable, Equatable, Sendable {
        /// Fine detail (mean absolute Laplacian) left outside the person, as
        /// a share of the unblurred frame's — under 1 when the blur took.
        public var backgroundDetail: Double?
        /// The same inside the person, which a background blur should keep (~1).
        public var subjectDetail: Double?
        /// Fine detail left inside the tracked face box, as a share of the
        /// uncovered face's.
        public var faceDetail: Double?
        /// Faces Vision still finds in the covered frames, of those it found uncovered.
        public var facesFound: [Int]?
        /// Mean absolute difference (0…1) between the output and the plain
        /// frame flipped left to right — near 0 for a mirror.
        public var mirrorError: Double?
        /// Share of the border band's pixels within 8 levels of its colour.
        public var borderSolid: Double?
        /// Share of the letterbox bars' pixels that are black.
        public var letterboxSolid: Double?
        /// Seconds between the first word's start and the first caption on
        /// screen (source time) — the offset, measured.
        public var captionLead: Double?
        /// Moments a zoom punch lands (emphasised words) and the measured
        /// change at the first of them against the plain frame (mean
        /// absolute difference, 0…1).
        public var punches: Int?
        public var punchChange: Double?

        public init() {}
    }

    /// Measures every footage effect `document` has, on up to `samples`
    /// frames, `width` pixels wide.
    public static func measure(_ document: CaptionDocument, samples: Int = 3, width: Int = 360) async -> Report {
        var report = Report()
        let config = document.renderConfig
        let height = max(16, Int((Double(width) * Double(config.height) / Double(max(1, config.width))).rounded()))
        var plain = document
        plain.backgroundBlur = nil
        plain.faceCensor = nil
        plain.mirrorHorizontal = false
        plain.gradientOverlay = nil
        plain.autoMotion = nil

        let times = sampleTimes(document, count: samples)
        let frames = await sourceFrames(document, at: times, width: width)

        if let blur = document.backgroundBlur, blur > 0.5 {
            var only = plain
            only.backgroundBlur = blur
            var outside: [Double] = [], inside: [Double] = []
            for (time, frame) in frames {
                guard let before = FootageStage.compose(frame, document: plain, at: time, width: width, height: height),
                      let after = FootageStage.compose(frame, document: only, at: time, width: width, height: height),
                      let mask = SubjectMasker().mask(of: before).flatMap({ personMask($0, width: width, height: height) })
                else { continue }
                let b = Detail.laplacian(of: before), a = Detail.laplacian(of: after)
                if let o = Detail.ratio(a, b, where: mask.map { !$0 }) { outside.append(o) }
                if let i = Detail.ratio(a, b, where: mask) { inside.append(i) }
            }
            report.backgroundDetail = Contrast.percentile(outside, 0.5)
            report.subjectDetail = Contrast.percentile(inside, 0.5)
        }

        if let censor = document.faceCensor, !censor.keyframes.isEmpty {
            var only = plain
            only.faceCensor = censor
            var ratios: [Double] = []
            var found: [Int] = []
            for (time, frame) in frames {
                guard let before = FootageStage.compose(frame, document: plain, at: time, width: width, height: height),
                      let after = FootageStage.compose(frame, document: only, at: time, width: width, height: height)
                else { continue }
                let faces = CanvasFrames.faces(in: before)
                found.append(CanvasFrames.faces(in: after).count)
                guard let face = faces.max(by: { $0.width < $1.width }) else { continue }
                let box = mask(of: CanvasFrames.pixels(face, in: before), width: width, height: height)
                if let r = Detail.ratio(Detail.laplacian(of: after), Detail.laplacian(of: before), where: box) { ratios.append(r) }
            }
            report.faceDetail = Contrast.percentile(ratios, 0.5)
            report.facesFound = found
        }

        if document.mirrorHorizontal, let (time, frame) = frames.first {
            var only = plain
            only.mirrorHorizontal = true
            if let before = FootageStage.compose(frame, document: plain, at: time, width: width, height: height),
               let after = FootageStage.compose(frame, document: only, at: time, width: width, height: height),
               let flipped = Detail.flipped(before) {
                report.mirrorError = Detail.meanDifference(after, flipped)
            }
        }

        if let border = document.videoBorder, border.width > 0, let (time, _) = frames.first,
           let overlay = CaptionRenderer.renderOverlay(document: document, at: time, layers: .titles),
           let pixels = CaptionContrast.rgba(of: overlay) {
            let band = max(1, Int((border.width * CGFloat(overlay.height) / 1920).rounded(.down)))
            let target = [border.color.red, border.color.green, border.color.blue].map { UInt8(max(0, min(255, ($0 * 255).rounded()))) }
            var solid = 0, total = 0
            for y in 0..<overlay.height {
                for x in 0..<overlay.width where x < band || y < band || x >= overlay.width - band || y >= overlay.height - band {
                    let offset = (y * overlay.width + x) * 4
                    total += 1
                    if (0..<3).allSatisfy({ abs(Int(pixels[offset + $0]) - Int(target[$0])) <= 8 }), pixels[offset + 3] > 247 { solid += 1 }
                }
            }
            report.borderSolid = total > 0 ? Double(solid) / Double(total) : nil
        }

        if let ratio = document.letterbox, ratio > 0,
           let overlay = CaptionRenderer.renderOverlay(document: plainCaptions(document), at: 0, layers: .captions),
           let pixels = CaptionContrast.rgba(of: overlay) {
            let size = CGSize(width: overlay.width, height: overlay.height)
            let canvasAspect = size.width / size.height
            var solid = 0, total = 0
            for y in 0..<overlay.height {
                for x in 0..<overlay.width {
                    let inBar: Bool
                    if CGFloat(ratio) > canvasAspect {
                        let bar = Int(((size.height - size.width / CGFloat(ratio)) / 2).rounded(.down)) - 1
                        inBar = y < bar || y >= overlay.height - bar
                    } else {
                        let bar = Int(((size.width - size.height * CGFloat(ratio)) / 2).rounded(.down)) - 1
                        inBar = x < bar || x >= overlay.width - bar
                    }
                    guard inBar else { continue }
                    let offset = (y * overlay.width + x) * 4
                    total += 1
                    if pixels[offset] == 0, pixels[offset + 1] == 0, pixels[offset + 2] == 0, pixels[offset + 3] == 255 { solid += 1 }
                }
            }
            report.letterboxSolid = total > 0 ? Double(solid) / Double(total) : nil
        }

        if document.captionTimingOffset != 0, let first = document.cards.first?.words.first {
            report.captionLead = firstCaption(document, near: first.start).map { $0 - first.start }
        }

        if let motion = document.autoMotion {
            let punches = motion.punchOnEmphasis ? AutoMotion.emphasisTimes(in: document.cards) : []
            report.punches = punches.count
            let moment = punches.first.map { $0 + 0.05 } ?? times.first
            if let moment, let frame = await sourceFrames(document, at: [moment], width: width).first?.1,
               let before = FootageStage.compose(frame, document: plain, at: moment, width: width, height: height),
               let after = FootageStage.compose(frame, document: { var d = plain; d.autoMotion = motion; return d }(),
                                                at: moment, width: width, height: height) {
                report.punchChange = Detail.meanDifference(before, after)
            }
        }
        return report
    }

    // MARK: Pieces

    /// Up to `count` source moments spread across the captioned span.
    static func sampleTimes(_ document: CaptionDocument, count: Int) -> [TimeInterval] {
        guard let start = document.cards.first?.start, let end = document.cards.last?.end, end > start else { return [0.5] }
        return (0..<max(1, count)).map { start + (end - start) * (Double($0) + 0.5) / Double(max(1, count)) }
    }

    /// Raw source frames at `times`.
    static func sourceFrames(_ document: CaptionDocument, at times: [TimeInterval], width: Int) async -> [(TimeInterval, CGImage)] {
        guard let url = document.videoURL else { return [] }
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: width * 3, height: width * 3)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        var frames: [(TimeInterval, CGImage)] = []
        for time in times {
            if let image = try? await generator.image(at: CMTime(seconds: time, preferredTimescale: 600)).image {
                frames.append((time, image))
            }
        }
        return frames
    }

    /// A person mask from Vision, resampled to `width`×`height` booleans.
    static func personMask(_ mask: CGImage, width: Int, height: Int) -> [Bool]? {
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue),
              let data = context.data else { return nil }
        context.draw(mask, in: CGRect(x: 0, y: 0, width: width, height: height))
        let bytes = data.bindMemory(to: UInt8.self, capacity: width * height)
        return (0..<(width * height)).map { bytes[$0] >= 128 }
    }

    /// `rect` (pixels, top-left) as a mask.
    static func mask(of rect: CGRect, width: Int, height: Int) -> [Bool] {
        let r = rect.integral
        return (0..<(width * height)).map { index in
            let x = index % width, y = index / width
            return CGFloat(x) >= r.minX && CGFloat(x) < r.maxX && CGFloat(y) >= r.minY && CGFloat(y) < r.maxY
        }
    }

    /// `document` reduced to what its caption layer draws without captions.
    static func plainCaptions(_ document: CaptionDocument) -> CaptionDocument {
        var bare = document
        bare.cards = []
        return bare
    }

    /// The first source time near `start` at which a caption is on screen,
    /// searched in 10 ms steps from a second before to a second after.
    static func firstCaption(_ document: CaptionDocument, near start: TimeInterval) -> TimeInterval? {
        stride(from: max(0, start - 1), through: start + 1, by: 0.01).first { time in
            CaptionRenderer.captionBlockRect(document: document, at: time) != nil
        }
    }

    // MARK: Detail

    /// Fine-detail measures on images.
    public enum Detail {

        /// The absolute 4-neighbour Laplacian of each pixel's luma (0…255
        /// scale; edge pixels 0) — high where the picture has fine detail.
        public static func laplacian(of image: CGImage) -> [Double] {
            guard let pixels = CaptionContrast.rgba(of: image) else { return [] }
            let width = image.width, height = image.height
            let luma = stride(from: 0, to: pixels.count, by: 4).map {
                0.299 * Double(pixels[$0]) + 0.587 * Double(pixels[$0 + 1]) + 0.114 * Double(pixels[$0 + 2])
            }
            var result = [Double](repeating: 0, count: width * height)
            guard width > 2, height > 2 else { return result }
            for y in 1..<(height - 1) {
                for x in 1..<(width - 1) {
                    let i = y * width + x
                    result[i] = abs(4 * luma[i] - luma[i - 1] - luma[i + 1] - luma[i - width] - luma[i + width])
                }
            }
            return result
        }

        /// Mean of `after` over mean of `before` where `mask` is set; `nil`
        /// when the mask is empty or `before` has no detail there.
        public static func ratio(_ after: [Double], _ before: [Double], where mask: [Bool]) -> Double? {
            guard after.count == before.count, mask.count == before.count else { return nil }
            var a = 0.0, b = 0.0, n = 0
            for i in mask.indices where mask[i] {
                a += after[i]
                b += before[i]
                n += 1
            }
            guard n > 0, b > 0 else { return nil }
            return a / b
        }

        /// Mean absolute RGB difference, 0…1.
        public static func meanDifference(_ a: CGImage, _ b: CGImage) -> Double? {
            guard a.width == b.width, a.height == b.height, let pa = CaptionContrast.rgba(of: a),
                  let pb = CaptionContrast.rgba(of: b) else { return nil }
            var total = 0.0, count = 0
            for i in stride(from: 0, to: pa.count, by: 4) {
                for c in 0..<3 { total += abs(Double(pa[i + c]) - Double(pb[i + c])) }
                count += 3
            }
            return count > 0 ? total / Double(count) / 255 : nil
        }

        /// `image` flipped left to right.
        public static func flipped(_ image: CGImage) -> CGImage? {
            guard let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                                          bytesPerRow: image.width * 4,
                                          space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            context.translateBy(x: CGFloat(image.width), y: 0)
            context.scaleBy(x: -1, y: 1)
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return context.makeImage()
        }
    }
}
