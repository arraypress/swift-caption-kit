//
//  StickerMedia.swift
//  CaptionKit
//
//  Created by David Sherlock on 2026.
//
//  A sticker's pictures, decoded once and kept: an emoji drawn to a bitmap,
//  a still, or every frame of a GIF, an animated PNG or a short video, with
//  each frame's time. The renderer only ever reads from here, so drawing a
//  sticker is a pure function of time — preview and export match.
//

@preconcurrency import AVFoundation
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import Synchronization

/// One sticker's decoded pictures.
public final class StickerFrames: @unchecked Sendable {

    /// The frames, in order; one for a still or an emoji.
    public let frames: [CGImage]

    /// How long each frame shows, in seconds.
    public let delays: [TimeInterval]

    init(frames: [CGImage], delays: [TimeInterval]) {
        self.frames = frames
        self.delays = delays.count == frames.count ? delays : Array(repeating: 0.1, count: frames.count)
    }

    /// One loop's length, in seconds.
    public var duration: TimeInterval { delays.reduce(0, +) }

    /// Height over width of the first frame (1 for an emoji).
    public var aspect: Double {
        guard let first = frames.first, first.width > 0 else { return 1 }
        return Double(first.height) / Double(first.width)
    }

    /// The frame showing `elapsed` seconds after the sticker appeared, the
    /// animation looping.
    public func frame(at elapsed: TimeInterval) -> CGImage? {
        guard frames.count > 1, duration > 0 else { return frames.first }
        var remaining = elapsed.truncatingRemainder(dividingBy: duration)
        if remaining < 0 { remaining += duration }
        for (index, delay) in delays.enumerated() {
            if remaining < delay { return frames[index] }
            remaining -= delay
        }
        return frames.last
    }
}

public enum StickerMedia {

    /// The longest side a decoded frame keeps, in pixels: a sticker is a
    /// fifth of the frame, so more is memory spent on nothing.
    public static let maximumSide = 512

    /// The most of a video sticker kept, in seconds — it loops.
    public static let maximumVideoSeconds: TimeInterval = 6

    /// The most video frames a second kept.
    public static let maximumVideoRate: Double = 15

    /// A frame shorter than this is read as a GIF that did not say (the
    /// convention browsers follow), and shown for ``fallbackDelay``.
    static let shortestDelay: TimeInterval = 0.02
    static let fallbackDelay: TimeInterval = 0.1

    private static let cache = Mutex<[StickerSource: StickerFrames]>([:])

    /// Whether `url` moves: a video, or a picture file with more than one frame.
    public static func isAnimated(_ url: URL) -> Bool {
        if StickerSource.videoExtensions.contains(url.pathExtension.lowercased()) { return true }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return false }
        return CGImageSourceGetCount(source) > 1
    }

    /// The decoded pictures for `source`, decoding them now if they are not
    /// cached. A video must be ``prepare(_:)``d first (its decode is async);
    /// everything else decodes here. `nil` when the file cannot be read.
    public static func frames(for source: StickerSource) -> StickerFrames? {
        if let hit = cache.withLock({ $0[source] }) { return hit }
        let decoded: StickerFrames?
        switch source {
        case .emoji(let emoji): decoded = emojiFrames(emoji)
        case .image(let url), .animated(let url):
            decoded = StickerSource.videoExtensions.contains(url.pathExtension.lowercased()) ? nil : imageFrames(url)
        }
        if let decoded { store(decoded, for: source) }
        return decoded
    }

    /// Decodes `source` (a video included) into the cache.
    ///
    /// - Returns: The pictures, or `nil` when the file cannot be read.
    @discardableResult
    public static func prepare(_ source: StickerSource) async -> StickerFrames? {
        if let ready = frames(for: source) { return ready }
        guard case .animated(let url) = source, StickerSource.videoExtensions.contains(url.pathExtension.lowercased()),
              let decoded = await videoFrames(url) else { return nil }
        store(decoded, for: source)
        return decoded
    }

    private static func store(_ frames: StickerFrames, for source: StickerSource) {
        cache.withLock { $0[source] = frames }
    }

    // MARK: - Decoding

    /// An emoji drawn with the colour-emoji font onto a transparent square.
    static func emojiFrames(_ emoji: String) -> StickerFrames? {
        let side = 320
        guard let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let font = CTFontCreateWithName("AppleColorEmoji" as CFString, 256, nil)
        let text = NSAttributedString(string: emoji.isEmpty ? "🙂" : emoji,
                                      attributes: [kCTFontAttributeName as NSAttributedString.Key: font])
        let line = CTLineCreateWithAttributedString(text)
        let bounds = CTLineGetImageBounds(line, context)
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        // Fit the glyph's inked bounds into the square, centred.
        let fit = min(CGFloat(side) * 0.94 / bounds.width, CGFloat(side) * 0.94 / bounds.height, 1)
        context.translateBy(x: CGFloat(side) / 2, y: CGFloat(side) / 2)
        context.scaleBy(x: fit, y: fit)
        context.textPosition = CGPoint(x: -bounds.midX, y: -bounds.midY)
        CTLineDraw(line, context)
        guard let image = context.makeImage() else { return nil }
        return StickerFrames(frames: [image], delays: [1])
    }

    /// Every frame of a still, GIF or animated PNG, with its delay.
    static func imageFrames(_ url: URL) -> StickerFrames? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 0 else { return nil }
        var frames: [CGImage] = []
        var delays: [TimeInterval] = []
        let thumbnail: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumSide,
        ]
        for index in 0..<count {
            guard let full = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            let image = max(full.width, full.height) > maximumSide
                ? CGImageSourceCreateThumbnailAtIndex(source, index, thumbnail as CFDictionary) ?? full
                : full
            frames.append(image)
            delays.append(delay(of: source, at: index))
        }
        guard !frames.isEmpty else { return nil }
        return StickerFrames(frames: frames, delays: frames.count == 1 ? [1] : delays)
    }

    /// A GIF or APNG frame's delay, the unclamped value where there is one.
    static func delay(of source: CGImageSource, at index: Int) -> TimeInterval {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any] ?? [:]
        var value: Double?
        if let gif = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any] {
            value = (gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double) ?? (gif[kCGImagePropertyGIFDelayTime] as? Double)
        } else if let png = properties[kCGImagePropertyPNGDictionary] as? [CFString: Any] {
            value = (png[kCGImagePropertyAPNGUnclampedDelayTime] as? Double) ?? (png[kCGImagePropertyAPNGDelayTime] as? Double)
        }
        guard let value, value >= shortestDelay else { return fallbackDelay }
        return value
    }

    /// Up to ``maximumVideoSeconds`` of a video at up to
    /// ``maximumVideoRate`` frames a second, alpha kept.
    static func videoFrames(_ url: URL) async -> StickerFrames? {
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let reader = try? AVAssetReader(asset: asset) else { return nil }
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ])
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { return nil }
        reader.add(output)
        guard reader.startReading() else { return nil }

        var frames: [CGImage] = []
        var times: [TimeInterval] = []
        let spacing = 1 / maximumVideoRate
        while let sample = output.copyNextSampleBuffer() {
            let time = CMSampleBufferGetPresentationTimeStamp(sample).seconds
            if time > maximumVideoSeconds { break }
            if let last = times.last, time - last < spacing - 1e-6 { continue }
            guard let buffer = CMSampleBufferGetImageBuffer(sample), let image = cgImage(from: buffer) else { continue }
            frames.append(image)
            times.append(time)
        }
        reader.cancelReading()
        guard !frames.isEmpty else { return nil }
        let end = (try? await asset.load(.duration).seconds).map { min($0, maximumVideoSeconds) } ?? (times.last ?? 0) + spacing
        var delays: [TimeInterval] = []
        for index in times.indices {
            let next = index + 1 < times.count ? times[index + 1] : max(end, times[index] + spacing)
            delays.append(max(shortestDelay, next - times[index]))
        }
        return StickerFrames(frames: frames, delays: delays)
    }

    /// A BGRA pixel buffer as a premultiplied sRGB image no larger than
    /// ``maximumSide`` on its longer side.
    private static func cgImage(from buffer: CVPixelBuffer) -> CGImage? {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        let width = CVPixelBufferGetWidth(buffer), height = CVPixelBufferGetHeight(buffer)
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let wrapped = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
              let full = wrapped.makeImage() else { return nil }
        let scale = min(1, Double(maximumSide) / Double(max(width, height)))
        let outWidth = max(1, Int((Double(width) * scale).rounded())), outHeight = max(1, Int((Double(height) * scale).rounded()))
        guard let context = CGContext(data: nil, width: outWidth, height: outHeight, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .high
        context.draw(full, in: CGRect(x: 0, y: 0, width: outWidth, height: outHeight))
        return context.makeImage()
    }
}
