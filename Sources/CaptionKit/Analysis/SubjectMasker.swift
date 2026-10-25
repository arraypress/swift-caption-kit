//
//  SubjectMasker.swift
//  CaptionKit
//
//  Created by David Sherlock on 2026.
//

import CoreGraphics
import CoreVideo
import Foundation
import Vision

/// The person in a frame, as a mask: on-device Vision person segmentation,
/// the same request at the same size wherever it runs — the export, the
/// preview and the coverage measurement — so what was measured is what is
/// drawn.
///
/// One instance per consumer; calls are serialized.
public final class SubjectMasker: @unchecked Sendable {

    /// The longest side a frame is segmented at. The mask is soft and coarse;
    /// segmenting a 4K frame only costs time.
    public static let segmentationSize: CGFloat = 720

    private let request: VNGeneratePersonSegmentationRequest
    private let lock = NSLock()

    public init() {
        request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .balanced
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
    }

    /// The person mask of `image` — grayscale, white where the person is, at
    /// the segmentation's own resolution (draw it scaled) — or `nil` when
    /// segmentation fails.
    public func mask(of image: CGImage) -> CGImage? {
        guard let input = Self.downscaled(image, to: Self.segmentationSize) else { return nil }
        lock.lock()
        defer { lock.unlock() }
        guard (try? VNImageRequestHandler(cgImage: input).perform([request])) != nil,
              let buffer = request.results?.first?.pixelBuffer else { return nil }
        return Self.image(of: buffer)
    }

    /// The share (`0…1`) of `rect` (normalized, top-left) that `mask` marks
    /// as person: the mean mask value over the rect.
    public static func coverage(of rect: CGRect, in mask: CGImage) -> Double {
        let width = mask.width, height = mask.height
        var pixels = [UInt8](repeating: 0, count: width * height)
        guard let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
        else { return 0 }
        context.draw(mask, in: CGRect(x: 0, y: 0, width: width, height: height))
        let x0 = max(0, Int((rect.minX * CGFloat(width)).rounded(.down)))
        let x1 = min(width, Int((rect.maxX * CGFloat(width)).rounded(.up)))
        let y0 = max(0, Int((rect.minY * CGFloat(height)).rounded(.down)))
        let y1 = min(height, Int((rect.maxY * CGFloat(height)).rounded(.up)))
        guard x1 > x0, y1 > y0 else { return 0 }
        var total = 0
        for y in y0..<y1 {   // row 0 of the bitmap is the top of the image
            for x in x0..<x1 { total += Int(pixels[y * width + x]) }
        }
        return Double(total) / Double((x1 - x0) * (y1 - y0) * 255)
    }

    /// The highest row (normalized, top-left) where `mask` marks at least
    /// half of the columns between `left` and `right` as person, searching
    /// down from the top to `limit` — the top of a head above its face box.
    /// `nil` when no row above `limit` is.
    public static func topEdge(in mask: CGImage, left: CGFloat, right: CGFloat, limit: CGFloat) -> CGFloat? {
        let width = mask.width, height = mask.height
        var pixels = [UInt8](repeating: 0, count: width * height)
        guard let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
        else { return nil }
        context.draw(mask, in: CGRect(x: 0, y: 0, width: width, height: height))
        let x0 = max(0, Int((left * CGFloat(width)).rounded(.down)))
        let x1 = min(width, Int((right * CGFloat(width)).rounded(.up)))
        let last = min(height, Int((limit * CGFloat(height)).rounded(.up)))
        guard x1 > x0, last > 0 else { return nil }
        for y in 0..<last {   // row 0 of the bitmap is the top of the image
            var total = 0
            for x in x0..<x1 { total += Int(pixels[y * width + x]) }
            if total * 2 >= (x1 - x0) * 255 { return CGFloat(y) / CGFloat(height) }
        }
        return nil
    }

    /// `clean` drawn over `context` through `mask` — the person laid back
    /// over whatever was drawn since `clean` was taken.
    public static func layPerson(from clean: CGImage, mask: CGImage, in context: CGContext, size: CGSize) {
        let bounds = CGRect(origin: .zero, size: size)
        context.saveGState()
        context.interpolationQuality = .high
        context.clip(to: bounds, mask: mask)
        context.draw(clean, in: bounds)
        context.restoreGState()
    }

    // MARK: - Helpers

    private static func downscaled(_ image: CGImage, to longest: CGFloat) -> CGImage? {
        let scale = min(1, longest / CGFloat(max(image.width, image.height)))
        guard scale < 1 else { return image }
        let width = max(1, Int((CGFloat(image.width) * scale).rounded()))
        let height = max(1, Int((CGFloat(image.height) * scale).rounded()))
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    private static func image(of buffer: CVPixelBuffer) -> CGImage? {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer),
              let context = CGContext(data: base, width: CVPixelBufferGetWidth(buffer), height: CVPixelBufferGetHeight(buffer),
                                      bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
        else { return nil }
        return context.makeImage()
    }
}
