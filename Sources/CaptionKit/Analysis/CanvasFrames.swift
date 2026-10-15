//
//  CanvasFrames.swift
//  CaptionKit
//
//  Created by David Sherlock on 2026.
//

@preconcurrency import AVFoundation
import CoreGraphics
import Foundation
import Vision

/// Footage frames as the export frames them — aspect-filled onto the canvas
/// with the document's crop — at a reduced size, for measuring what is
/// behind a title or a caption: faces, people, brightness.
public enum CanvasFrames {

    /// One sampled frame.
    public struct Frame: @unchecked Sendable {
        /// Source time, in seconds.
        public let time: TimeInterval
        /// The canvas-shaped frame.
        public let image: CGImage
    }

    /// `document`'s video at `times` (source seconds), framed onto its canvas
    /// at `width` pixels wide. A time that cannot be decoded is skipped.
    public static func frames(for document: CaptionDocument, at times: [TimeInterval], width: Int = 540) async -> [Frame] {
        guard let videoURL = document.videoURL, !times.isEmpty else { return [] }
        let config = document.renderConfig
        let canvasWidth = max(16, width)
        let canvasHeight = max(16, Int((Double(canvasWidth) * Double(config.height) / Double(max(1, config.width))).rounded()))

        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: videoURL))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: canvasWidth * 2, height: canvasWidth * 2)
        let tolerance = CMTime(seconds: 0.02, preferredTimescale: 600)
        generator.requestedTimeToleranceBefore = tolerance
        generator.requestedTimeToleranceAfter = tolerance

        var frames: [Frame] = []
        for time in times {
            guard let footage = try? await generator.image(at: CMTime(seconds: max(0, time), preferredTimescale: 600)).image,
                  let framed = frame(footage, document: document, time: time, width: canvasWidth, height: canvasHeight) else { continue }
            frames.append(Frame(time: time, image: framed))
        }
        return frames
    }

    /// `footage` drawn onto a `width`×`height` canvas the way the exporter
    /// draws it: aspect-fill, the crop offset (or the camera path at `time`),
    /// mirrored when the document mirrors.
    static func frame(_ footage: CGImage, document: CaptionDocument, time: TimeInterval, width: Int, height: Int) -> CGImage? {
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let canvas = CGSize(width: width, height: height)
        context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(origin: .zero, size: canvas))
        let offset = document.cropKeyframes.flatMap { CropTrack.offset(at: time, keyframes: $0) }
            ?? document.cropOffset ?? NormalizedPoint(x: 0.5, y: 0.5)
        let scale = document.cropKeyframes.map { CropTrack.scale(at: time, keyframes: $0) } ?? 1
        let placed = Reframe.placement(source: CGSize(width: footage.width, height: footage.height),
                                       canvas: canvas, offset: offset, extraScale: scale)
        context.interpolationQuality = .high
        if document.mirrorHorizontal {
            context.translateBy(x: canvas.width, y: 0)
            context.scaleBy(x: -1, y: 1)
        }
        context.draw(footage, in: CGRect(origin: placed.origin, size: placed.size))
        return context.makeImage()
    }

    /// Every face Vision finds in `image`, normalized `0…1` with a
    /// **top-left** origin.
    public static func faces(in image: CGImage) -> [CGRect] {
        let request = VNDetectFaceRectanglesRequest()
        try? VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? []).map { face in
            let box = face.boundingBox
            return CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height)
        }
    }

    /// `rect` (normalized, top-left) in `image`'s pixels, top-left origin.
    public static func pixels(_ rect: CGRect, in image: CGImage) -> CGRect {
        CGRect(x: rect.minX * CGFloat(image.width), y: rect.minY * CGFloat(image.height),
               width: rect.width * CGFloat(image.width), height: rect.height * CGFloat(image.height))
    }
}
