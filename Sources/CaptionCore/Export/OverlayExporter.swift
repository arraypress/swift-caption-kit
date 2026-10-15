//
//  OverlayExporter.swift
//  CaptionCore
//
//  Created by David Sherlock on 2026.
//

import AVFoundation
import CoreGraphics
import Foundation

/// Exports the caption layer ALONE as ProRes 4444 with alpha —
/// for editors who cut in Final Cut or Premiere but want this caption
/// engine. Same renderer, so the overlay matches the in-app preview
/// frame-for-frame.
public final class OverlayExporter: @unchecked Sendable {

    private let document: any CaptionTimeline
    private let outputURL: URL
    private var cancelled = false
    private let lock = NSLock()

    public init(document: some CaptionTimeline, outputURL: URL) {
        self.document = document
        self.outputURL = outputURL
    }

    public func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }

    private var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    /// Runs the export, calling `progress` with `0…1`.
    public func run(progress: @MainActor @Sendable (Double) -> Void = { _ in }) async throws {
        let config = document.renderConfig
        let fps = max(10, config.framesPerSecond)
        let map = document.timeMap
        let sourceDuration = document.videoDuration
            ?? document.cards.map(\.end).max()
            ?? 10
        let outputDuration = map.outputTime(forSource: sourceDuration)
        guard outputDuration > 0.1 else {
            throw ExportError.writerFailed("nothing to export — no captions or duration")
        }

        try? FileManager.default.removeItem(at: outputURL)
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.proRes4444,
            AVVideoWidthKey: config.width,
            AVVideoHeightKey: config.height,
        ])
        input.expectsMediaDataInRealTime = false
        writer.add(input)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: config.width,
                kCVPixelBufferHeightKey as String: config.height,
            ]
        )
        guard writer.startWriting() else {
            throw ExportError.writerFailed(writer.error?.localizedDescription ?? "could not start")
        }
        writer.startSession(atSourceTime: .zero)

        let frameCount = Int(outputDuration * Double(fps))
        for frame in 0..<frameCount {
            if isCancelled {
                writer.cancelWriting()
                throw CancellationError()
            }

            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(8))
            }
            let outputTime = Double(frame) / Double(fps)
            let sourceTime = map.sourceTime(forOutput: outputTime)

            guard let pool = adaptor.pixelBufferPool else {
                throw ExportError.cannotCreateBuffer
            }
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
            guard let buffer else { throw ExportError.cannotCreateBuffer }

            CVPixelBufferLockBaseAddress(buffer, [])
            if let context = CGContext(
                data: CVPixelBufferGetBaseAddress(buffer),
                width: config.width,
                height: config.height,
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
            ) {
                context.clear(CGRect(x: 0, y: 0, width: config.width, height: config.height))
                document.drawCaptions(in: context, at: sourceTime)
            }
            CVPixelBufferUnlockBaseAddress(buffer, [])

            if !adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: CMTimeScale(fps))) {
                throw ExportError.writerFailed(writer.error?.localizedDescription ?? "append failed")
            }
            if frame % 30 == 0 {
                await progress(Double(frame) / Double(max(1, frameCount)))
            }
        }
        input.markAsFinished()
        await writer.finishWriting()
        if writer.status != .completed {
            throw ExportError.writerFailed(writer.error?.localizedDescription ?? "finish failed")
        }
        await progress(1)
    }
}
