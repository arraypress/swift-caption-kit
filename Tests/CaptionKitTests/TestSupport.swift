//
//  TestSupport.swift
//  CaptionKitTests
//
//  Created by David Sherlock on 2026.
//
//  Helpers more than one suite needs.

@preconcurrency import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import Testing

/// Runs a pixel comparison up to `attempts` times and reports whether any
/// attempt agreed.
///
/// Two draws of the same thing can differ for a reason that is not the code
/// under test: a card's first render takes its shadow by a different route
/// than later ones, and the renderer's caches are process-wide while other
/// suites render in parallel, so one can evict a card's shadow between two
/// draws. Each attempt warms the caches itself; a real difference disagrees
/// on every attempt.
func agreesOnSomeAttempt(_ attempts: Int = 3, _ compare: () throws -> Bool) rethrows -> Bool {
    for _ in 0..<attempts {
        if try compare() { return true }
    }
    return false
}

/// Waits until a writer input takes more data. Throws instead of waiting for
/// ever when the writer has failed — its input is never ready again.
func waitUntilReady(_ input: AVAssetWriterInput, of writer: AVAssetWriter) async throws {
    while !input.isReadyForMoreMediaData {
        if writer.status == .failed || writer.status == .cancelled {
            throw writer.error ?? CocoaError(.fileWriteUnknown)
        }
        try await Task.sleep(nanoseconds: 1_000_000)
    }
}

/// 1.5 s of the generated portrait (no real person) filling a 360×640 frame.
func portraitVideo() async throws -> URL {
    let resource = try #require(Bundle.module.url(forResource: "portrait", withExtension: "jpg", subdirectory: "Resources"))
    let source = try #require(CGImageSourceCreateWithURL(resource as CFURL, nil))
    let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    return try await writeVideo(width: 360, height: 640, frames: 45, alpha: false) { context, _ in
        context.draw(image, in: CGRect(x: 0, y: 0, width: 360, height: 640))
    }
}

/// A `width`×`height` clip of `frames` frames at 30 fps, each drawn by `paint`
/// (ProRes 4444 with alpha, or H.264), in a fresh temporary folder.
func writeVideo(width: Int, height: Int, frames: Int, alpha: Bool,
                paint: (CGContext, Int) -> Void) async throws -> URL {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("captionkit-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let url = folder.appendingPathComponent(alpha ? "alpha.mov" : "clip.mov")
    let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: alpha ? AVVideoCodecType.proRes4444 : AVVideoCodecType.h264,
        AVVideoWidthKey: width, AVVideoHeightKey: height,
    ])
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height,
    ])
    writer.add(input)
    #expect(writer.startWriting())
    writer.startSession(atSourceTime: .zero)
    for index in 0..<frames {
        try await waitUntilReady(input, of: writer)
        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, try #require(adaptor.pixelBufferPool), &buffer)
        let pixels = try #require(buffer)
        CVPixelBufferLockBaseAddress(pixels, [])
        let context = try #require(CGContext(
            data: CVPixelBufferGetBaseAddress(pixels), width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixels), space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue))
        paint(context, index)
        CVPixelBufferUnlockBaseAddress(pixels, [])
        #expect(adaptor.append(pixels, withPresentationTime: CMTime(value: CMTimeValue(index), timescale: 30)))
    }
    input.markAsFinished()
    await writer.finishWriting()
    #expect(writer.status == .completed)
    return url
}
