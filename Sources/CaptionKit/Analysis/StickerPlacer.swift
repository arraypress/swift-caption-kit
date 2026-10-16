//
//  StickerPlacer.swift
//  CaptionKit
//
//  Created by David Sherlock on 2026.
//
//  Where stickers go, by rule and nothing else: inside the platform's safe
//  zone, clear of every face found in the frames a sticker covers, of the
//  caption block at every moment it shares the screen, of the hook title and
//  of any other sticker on screen with it. Spots are tried on a fixed grid in
//  a fixed order, so the same request on the same footage always lands in
//  the same place; a sticker that fits nowhere shrinks in steps and is then
//  refused with what blocked it — never dropped on top of something.
//

import CoreGraphics
import Foundation
import Legibility

public enum StickerPlacer {

    /// The sizes tried, as fractions of the requested width, largest first.
    public static let scales: [Double] = [1, 0.85, 0.7, 0.55]

    /// How far a face is kept from a sticker, normalized.
    static let facePadding: CGFloat = 0.03

    /// How far a caption block or the hook title is kept from a sticker, normalized.
    static let textPadding: CGFloat = 0.015

    /// The spacing of candidate centres, normalized.
    static let gridStep: CGFloat = 0.01

    /// How far from its anchor a sticker may land, normalized.
    public static let anchorReach: CGFloat = 0.25

    /// Where a sticker with no anchor would like to be, before the rules move
    /// it: centred, in the upper third.
    static let preferredCenter = CGPoint(x: 0.5, y: 0.3)

    /// How often the captions are sampled while a sticker is up, in seconds.
    static let captionSampling: TimeInterval = 0.1

    /// Places `requests` on `document`, in time order, each by the rules.
    ///
    /// - Parameters:
    ///   - requests: What to place.
    ///   - document: The built document: its words time the stickers; its
    ///     captions, hook, canvas, crop and video are what they keep clear of.
    ///   - platform: Whose interface to keep clear of; `nil` keeps clear of
    ///     every platform's on a 9:16 canvas, and only the canvas safe area
    ///     on any other shape (as ``HookBuilder``).
    ///   - rules: How many may share the screen, and the gap between them.
    /// - Returns: The placed stickers, in time order.
    /// - Throws: ``StickerError`` for the first sticker that cannot be placed.
    public static func place(_ requests: [StickerRequest], in document: CaptionDocument, platform: Platform? = nil,
                             rules: StickerRules = StickerRules()) async throws(StickerError) -> [PlacedSticker] {
        // Resolve every timing first, so spacing is judged in time order.
        var timed: [(index: Int, name: String, request: StickerRequest, start: TimeInterval, end: TimeInterval)] = []
        for (index, request) in requests.enumerated() {
            let name = request.name ?? "sticker \(index + 1)"
            guard (0.02...1).contains(request.size) else { throw .badSize(sticker: name, size: request.size) }
            let span = try timeSpan(of: request, name: name, words: document.allWords)
            timed.append((index, name, request, span.start, span.end))
        }
        timed.sort { $0.start != $1.start ? $0.start < $1.start : $0.index < $1.index }

        let config = document.renderConfig
        let safe = HookBuilder.safeRect(config: config, platform: platform)
        let hookRect = document.hook.flatMap { CaptionRenderer.hookRect($0, config: config) }
        var placed: [PlacedSticker] = []
        let masker = SubjectMasker()

        for item in timed {
            try checkSpacing(name: item.name, start: item.start, end: item.end, placed: placed, rules: rules)

            guard let media = await StickerMedia.prepare(item.request.source) else {
                throw .unreadable(sticker: item.name, path: item.request.source.label)
            }

            // What is on screen with it.
            var obstacles: [(rect: CGRect, what: String)] = []
            let samples = (0..<5).map { item.start + (item.end - item.start) * (Double($0) + 0.5) / 5 }
            let frames = await CanvasFrames.frames(for: document, at: samples)
            let images = frames.map(\.image)
            let person = PersonGrid(masks: await VisionQueue.run { images.compactMap { masker.mask(of: $0) } })
            for faces in await CanvasFrames.faces(in: images) {
                obstacles += faces.map { (HookPlacement.padded(head(of: $0), by: facePadding), "a face") }
            }
            var time = item.start
            while time < item.end {
                if let block = CaptionRenderer.captionBlockRect(document: document, at: time) {
                    obstacles.append((HookPlacement.padded(block, by: textPadding), "the captions"))
                }
                time += captionSampling
            }
            if let hook = document.hook, let hookRect, hook.start < item.end, hook.end > item.start {
                obstacles.append((HookPlacement.padded(hookRect, by: textPadding), "the hook title"))
            }
            for other in placed where other.start < item.end && other.end > item.start {
                obstacles.append((other.rect, "sticker \(other.name)"))
            }

            var spot: (rect: CGRect, size: Double)?
            for scale in scales {
                let width = item.request.size * scale
                let size = CGSize(width: width,
                                  height: width * media.aspect * Double(config.width) / Double(max(1, config.height)))
                if let rect = clearSpot(size: size, safe: safe, obstacles: obstacles.map(\.rect), anchor: item.request.anchor,
                                        person: person) {
                    spot = (rect, width)
                    break
                }
            }
            guard let spot else {
                let smallest = item.request.size * (scales.last ?? 1)
                let size = CGSize(width: smallest,
                                  height: smallest * media.aspect * Double(config.width) / Double(max(1, config.height)))
                throw .noRoom(sticker: item.name, blockedBy: blockers(size: size, safe: safe, obstacles: obstacles,
                                                                       anchor: item.request.anchor))
            }
            placed.append(PlacedSticker(name: item.name, source: item.request.source, start: item.start, end: item.end,
                                        rect: spot.rect, size: spot.size, entrance: item.request.entrance,
                                        loop: item.request.loop))
        }
        return placed
    }

    /// The head around a detected face: Vision's face box runs from the
    /// brows to the chin, so a sticker kept off only that box can land on the
    /// forehead or the hair. Grown up by 0.6 of its height and out by 0.15 of
    /// its width a side — on the generated portrait fixture that reaches the
    /// top of the hair.
    public static func head(of face: CGRect) -> CGRect {
        CGRect(x: face.minX - face.width * 0.15, y: face.minY - face.height * 0.6,
               width: face.width * 1.3, height: face.height * 1.6)
    }

    // MARK: - Timing

    /// When `request` is on screen, in source seconds.
    public static func timeSpan(of request: StickerRequest, name: String,
                                words: [Word]) throws(StickerError) -> (start: TimeInterval, end: TimeInterval) {
        switch request.timing {
        case .span(let start, let end):
            guard start >= 0, end > start else { throw .badSpan(sticker: name, start: start, end: end) }
            return (start, end)
        case .word(let text, let occurrence, let duration):
            let key = matchKey(text)
            let matches = words.filter { $0.matchKey == key }
            guard !matches.isEmpty else { throw .wordNotFound(sticker: name, word: text) }
            guard occurrence >= 1, occurrence <= matches.count else {
                throw .occurrenceMissing(sticker: name, word: text, occurrence: occurrence, found: matches.count)
            }
            let start = matches[occurrence - 1].start
            let hold = duration ?? StickerRules.defaultHold
            guard hold > 0 else { throw .badSpan(sticker: name, start: start, end: start + hold) }
            return (start, start + hold)
        }
    }

    /// A typed word as the transcript's words compare: lowercased, edge
    /// punctuation and symbols gone (``Word/matchKey``).
    static func matchKey(_ text: String) -> String {
        text.trimmingCharacters(in: .punctuationCharacters.union(.symbols).union(.whitespaces)).lowercased()
    }

    // MARK: - Spacing

    /// Refuses a sticker that breaks `rules` against those already placed.
    static func checkSpacing(name: String, start: TimeInterval, end: TimeInterval, placed: [PlacedSticker],
                             rules: StickerRules) throws(StickerError) {
        let sharing = placed.filter { $0.start < end && $0.end > start }
        if sharing.count >= max(1, rules.maxOnScreen) {
            let limit = max(1, rules.maxOnScreen)
            throw .spacing(sticker: name, other: sharing.map(\.name).joined(separator: ", "),
                           reason: "would make \(sharing.count + 1) stickers on screen at once; the limit is \(limit)")
        }
        // The gap applies to stickers that do not share the screen.
        for other in placed where !(other.start < end && other.end > start) {
            let gap = start >= other.end ? start - other.end : other.start - end
            if gap < rules.minimumGap - 1e-9 {
                throw .spacing(sticker: name, other: other.name,
                               reason: String(format: "starts %.2f s after the one before it; the gap is at least %.2f s",
                                              gap, rules.minimumGap))
            }
        }
    }

    // MARK: - Geometry

    /// The point a sticker would like, for `anchor` inside `safe`.
    static func anchorPoint(_ anchor: StickerAnchor?, size: CGSize, safe: CGRect) -> CGPoint {
        let left = safe.minX + size.width / 2, right = safe.maxX - size.width / 2
        let top = safe.minY + size.height / 2, bottom = safe.maxY - size.height / 2
        let midX = min(max(0.5, left), right), midY = (top + bottom) / 2
        switch anchor {
        case nil: return CGPoint(x: min(max(preferredCenter.x, left), right), y: min(max(preferredCenter.y, top), bottom))
        case .top: return CGPoint(x: midX, y: top)
        case .upperLeft: return CGPoint(x: left, y: top)
        case .upperRight: return CGPoint(x: right, y: top)
        case .left: return CGPoint(x: left, y: midY)
        case .right: return CGPoint(x: right, y: midY)
        case .center: return CGPoint(x: midX, y: midY)
        case .lowerLeft: return CGPoint(x: left, y: bottom)
        case .lowerRight: return CGPoint(x: right, y: bottom)
        case .bottom: return CGPoint(x: midX, y: bottom)
        }
    }

    /// The most of a sticker's box that may cover the person (the body —
    /// the head is an obstacle) for it to count as off them: spots off the
    /// person are tried first, nearest the anchor; the rest after.
    public static let personPreference = 0.15

    /// Candidate centres for a box of `size` inside `safe`, on the grid:
    /// spots that keep off the person (``personPreference``) before spots on
    /// them, and within each, nearest the anchor point first (top-to-bottom,
    /// left-to-right on a tie); within ``anchorReach`` of it when there is an
    /// anchor.
    static func candidates(size: CGSize, safe: CGRect, anchor: StickerAnchor?, person: PersonGrid? = nil) -> [CGPoint] {
        let left = safe.minX + size.width / 2, right = safe.maxX - size.width / 2
        let top = safe.minY + size.height / 2, bottom = safe.maxY - size.height / 2
        guard right >= left - 1e-9, bottom >= top - 1e-9 else { return [] }
        let target = anchorPoint(anchor, size: size, safe: safe)
        var points: [(point: CGPoint, onPerson: Bool, distance: CGFloat)] = []
        var y = top
        while y <= bottom + 1e-9 {
            var x = left
            while x <= right + 1e-9 {
                let distance = hypot(x - target.x, y - target.y)
                if anchor == nil || distance <= anchorReach {
                    let box = HookPlacement.rect(center: CGPoint(x: x, y: y), size: size)
                    let onPerson = (person?.coverage(of: box) ?? 0) > personPreference
                    points.append((CGPoint(x: x, y: y), onPerson, distance))
                }
                x += gridStep
            }
            y += gridStep
        }
        return points.sorted {
            if $0.onPerson != $1.onPerson { return !$0.onPerson }
            return abs($0.distance - $1.distance) > 1e-9 ? $0.distance < $1.distance
                : ($0.point.y != $1.point.y ? $0.point.y < $1.point.y : $0.point.x < $1.point.x)
        }.map(\.point)
    }

    /// The first clear box of `size`, or `nil`.
    static func clearSpot(size: CGSize, safe: CGRect, obstacles: [CGRect], anchor: StickerAnchor?,
                          person: PersonGrid? = nil) -> CGRect? {
        for center in candidates(size: size, safe: safe, anchor: anchor, person: person) {
            let box = HookPlacement.rect(center: center, size: size)
            if !obstacles.contains(where: { $0.intersects(box) }) { return box }
        }
        return nil
    }

    /// What stood in the way of every spot — the obstacles that overlap the
    /// candidates, or the safe zone itself when no candidate fits in it.
    static func blockers(size: CGSize, safe: CGRect, obstacles: [(rect: CGRect, what: String)],
                         anchor: StickerAnchor?) -> [String] {
        let spots = candidates(size: size, safe: safe, anchor: anchor)
        guard !spots.isEmpty else {
            return [anchor == nil ? "the safe zone (too small for it)" : "the safe zone near \(anchor!.rawValue)"]
        }
        var found: [String] = []
        for center in spots {
            let box = HookPlacement.rect(center: center, size: size)
            for obstacle in obstacles where obstacle.rect.intersects(box) && !found.contains(obstacle.what) {
                found.append(obstacle.what)
            }
        }
        return found.isEmpty ? ["the safe zone"] : found
    }
}

/// Where the person is, averaged over the frames a sticker covers, on a
/// coarse grid with a summed-area table — so the share of any box that
/// covers them is four lookups.
struct PersonGrid {

    static let columns = 72
    static let rows = 128

    /// Summed person value, `(rows + 1) × (columns + 1)`, row 0 the top.
    private var sums: [Double]

    /// `nil` when there are no masks.
    init?(masks: [CGImage]) {
        guard !masks.isEmpty else { return nil }
        let columns = Self.columns, rows = Self.rows
        var mean = [Double](repeating: 0, count: columns * rows)
        for mask in masks {
            var pixels = [UInt8](repeating: 0, count: columns * rows)
            let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
                guard let context = CGContext(data: buffer.baseAddress, width: columns, height: rows, bitsPerComponent: 8,
                                              bytesPerRow: columns, space: CGColorSpaceCreateDeviceGray(),
                                              bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
                context.interpolationQuality = .medium
                context.draw(mask, in: CGRect(x: 0, y: 0, width: columns, height: rows))
                return true
            }
            guard drawn else { continue }
            for index in mean.indices { mean[index] += Double(pixels[index]) / 255 / Double(masks.count) }
        }
        sums = [Double](repeating: 0, count: (rows + 1) * (columns + 1))
        for row in 0..<rows {
            for column in 0..<columns {
                sums[(row + 1) * (columns + 1) + column + 1] = mean[row * columns + column]
                    + sums[row * (columns + 1) + column + 1] + sums[(row + 1) * (columns + 1) + column]
                    - sums[row * (columns + 1) + column]
            }
        }
    }

    /// The mean person value (`0…1`) over `rect`, normalized top-left.
    func coverage(of rect: CGRect) -> Double {
        let columns = Self.columns, rows = Self.rows
        let x0 = max(0, min(columns, Int((rect.minX * CGFloat(columns)).rounded(.down))))
        let x1 = max(0, min(columns, Int((rect.maxX * CGFloat(columns)).rounded(.up))))
        let y0 = max(0, min(rows, Int((rect.minY * CGFloat(rows)).rounded(.down))))
        let y1 = max(0, min(rows, Int((rect.maxY * CGFloat(rows)).rounded(.up))))
        guard x1 > x0, y1 > y0 else { return 0 }
        let stride = columns + 1
        let total = sums[y1 * stride + x1] - sums[y0 * stride + x1] - sums[y1 * stride + x0] + sums[y0 * stride + x0]
        return total / Double((x1 - x0) * (y1 - y0))
    }
}
