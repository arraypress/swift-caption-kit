//
//  SplicerTests.swift
//  CaptionKitLite
//
//  Joining kept ranges. Every frame of the test video states its own number
//  in black and white blocks — colour levels did not survive the YUV round
//  trip, which made the first version of this check report frames 245 out
//  when the splice was perfect — so "the right picture after the cut" is
//  asserted, not eyeballed.
//

import AVFoundation
import XCTest
@testable import CaptionKitLite

final class SplicerTests: XCTestCase {

    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("splicer-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    // MARK: - Choosing the container

    func testVideoKeepsItsContainer() {
        XCTAssertEqual(Splicer.outputExtension(for: URL(fileURLWithPath: "a.MOV"), hasVideo: true), "mov")
        XCTAssertEqual(Splicer.outputExtension(for: URL(fileURLWithPath: "a.mp4"), hasVideo: true), "mp4")
        XCTAssertEqual(Splicer.outputExtension(for: URL(fileURLWithPath: "a.mkv"), hasVideo: true), "mp4")
    }

    func testSoundPassesThroughWhereItCanAndBecomesM4AWhereItCannot() {
        XCTAssertEqual(Splicer.outputExtension(for: URL(fileURLWithPath: "a.wav"), hasVideo: false), "wav")
        XCTAssertEqual(Splicer.outputExtension(for: URL(fileURLWithPath: "a.aif"), hasVideo: false), "aiff")
        XCTAssertEqual(Splicer.outputExtension(for: URL(fileURLWithPath: "a.mp3"), hasVideo: false), "m4a")
        XCTAssertEqual(Splicer.outputExtension(for: URL(fileURLWithPath: "a.m4a"), hasVideo: false), "m4a")
    }

    // MARK: - Sound

    func testAudioIsJoinedToTheKeptLength() async throws {
        for ext in ["wav", "m4a"] {
            let source = try tone(seconds: 10, ext: ext)
            let output = folder.appendingPathComponent("cut-\(ext).\(Splicer.outputExtension(for: source, hasVideo: false))")
            let result = try await Splicer.keep([Cut(start: 0, end: 2), Cut(start: 5, end: 7.5)], of: source, to: output)
            XCTAssertEqual(result.plannedDuration, 4.5, accuracy: 0.0001)
            XCTAssertLessThan(result.durationError, 0.03, "\(ext): \(result.outputDuration)")
            XCTAssertFalse(result.hasVideo)
            XCTAssertEqual(result.reencoded, ext == "m4a", "only m4a has to be re-encoded")
        }
    }

    func testCuttingEverythingIsRefused() async throws {
        let source = try tone(seconds: 2, ext: "wav")
        do {
            _ = try await Splicer.keep([], of: source, to: folder.appendingPathComponent("x.wav"))
            XCTFail("an empty keep list wrote a file")
        } catch let error as Splicer.SpliceError {
            XCTAssertEqual(error, .nothingKept)
        }
    }

    // MARK: - Pictures

    func testTheRightFrameShowsAfterEveryCut() async throws {
        let source = try await numberedVideo(frames: 300)   // 10 s at 30 fps, keyframe every 60
        let keep = [Cut(start: 0, end: 2.83), Cut(start: 4.85, end: 5.1), Cut(start: 5.7, end: 8.2)]
        let output = folder.appendingPathComponent("cut.mov")
        let result = try await Splicer.keep(keep, of: source, to: output)
        XCTAssertLessThan(result.durationError, 0.04)
        XCTAssertFalse(result.reencoded)

        let map = TimeMap(cuts: [Cut(start: 2.83, end: 4.85), Cut(start: 5.1, end: 5.7), Cut(start: 8.2, end: 10)])
        for t in stride(from: 0.1, to: result.outputDuration - 0.1, by: 0.31) {
            let shown = try await frameNumber(in: output, at: t)
            let wanted = Int(map.sourceTime(forOutput: t) * 30)
            XCTAssertLessThanOrEqual(abs(shown - wanted), 1, "at \(t)s: frame \(shown), wanted \(wanted)")
        }
    }

    // MARK: - Fixtures

    /// A sine tone, written as WAV or AAC.
    private func tone(seconds: Double, ext: String) throws -> URL {
        let url = folder.appendingPathComponent("tone.\(ext)")
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        let settings: [String: Any] = ext == "wav"
            ? format.settings
            : [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44_100, AVNumberOfChannelsKey: 1]
        let file = try AVAudioFile(forWriting: url, settings: settings)
        let frames = AVAudioFrameCount(seconds * 44_100)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        for index in 0..<Int(frames) {
            buffer.floatChannelData![0][index] = Float(sin(Double(index) * 2 * .pi * 440 / 44_100) * 0.3)
        }
        try file.write(from: buffer)
        return url
    }

    /// An H.264 video whose frame N shows N in ten black-or-white blocks.
    private func numberedVideo(frames: Int) async throws -> URL {
        let url = folder.appendingPathComponent("numbered.mov")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 320, AVVideoHeightKey: 240,
            AVVideoCompressionPropertiesKey: [AVVideoMaxKeyFrameIntervalKey: 60],
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: 320, kCVPixelBufferHeightKey as String: 240,
        ])
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        for frame in 0..<frames {
            while !input.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 1_000_000) }
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
            CVPixelBufferLockBaseAddress(buffer!, [])
            let base = CVPixelBufferGetBaseAddress(buffer!)!.assumingMemoryBound(to: UInt8.self)
            let stride = CVPixelBufferGetBytesPerRow(buffer!)
            for y in 0..<240 {
                for x in 0..<320 {
                    let value: UInt8 = y < 120 ? ((frame >> (x / 32)) & 1 == 1 ? 255 : 0) : 128
                    let pixel = base + y * stride + x * 4
                    pixel[0] = value; pixel[1] = value; pixel[2] = value; pixel[3] = 255
                }
            }
            CVPixelBufferUnlockBaseAddress(buffer!, [])
            adaptor.append(buffer!, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: 30))
        }
        input.markAsFinished()
        await writer.finishWriting()
        return url
    }

    /// The number a frame of ``numberedVideo(frames:)`` shows at a time.
    private func frameNumber(in url: URL, at seconds: Double) async throws -> Int {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let (image, _) = try await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600))
        let context = CGContext(data: nil, width: 320, height: 240, bitsPerComponent: 8, bytesPerRow: 320 * 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: 320, height: 240))
        let pixels = context.data!.assumingMemoryBound(to: UInt8.self)
        // Bitmap memory runs from the top row down; row 60 is inside the blocks.
        return (0..<10).reduce(0) { number, bit in
            number | ((pixels[(60 * 320 + bit * 32 + 16) * 4] > 128 ? 1 : 0) << bit)
        }
    }
}
