//
//  AudioReencodeTests.swift
//  CaptionKit
//
//  Exports that re-encode the sound. A clip with 22.05 kHz mono audio (what
//  `say` writes) failed every cut or speed-ramped export with "Cannot Encode
//  Media": the writer was asked for 128 kb/s AAC, and the encoder tops out
//  at 64 kb/s for that format.
//

@preconcurrency import AVFoundation
import Foundation
import Testing
@_spi(CaptionEngine) @testable import CaptionCore
@testable import CaptionKit

@Suite("Audio re-encode", .timeLimit(.minutes(3)))
struct AudioReencodeTests {

    // MARK: - Choosing the bitrate

    @Test("The preferred bitrate is kept where the encoder offers it")
    func keepsThePreferredBitRate() {
        #expect(AACSettings.bitRate(preferred: 128_000, supported: [64_000, 96_000, 128_000, 192_000]) == 128_000)
    }

    @Test("Above the encoder's range, the highest it offers is used")
    func capsAtTheEncodersMaximum() {
        #expect(AACSettings.bitRate(preferred: 128_000, supported: [16_000, 32_000, 64_000]) == 64_000)
    }

    @Test("Below the encoder's range, the lowest it offers is used")
    func risesToTheEncodersMinimum() {
        #expect(AACSettings.bitRate(preferred: 8_000, supported: [0, 16_000, 32_000]) == 16_000)
    }

    @Test("With nothing known, the preferred bitrate goes to the writer")
    func unknownRangeKeepsThePreference() {
        #expect(AACSettings.bitRate(preferred: 128_000, supported: []) == 128_000)
    }

    @Test("The system encoder's limits for low sample rates are what was measured")
    func measuredEncoderLimits() {
        #expect(AACSettings.supportedBitRates(sampleRate: 22_050, channels: 1).max() == 64_000)
        #expect(AACSettings.supportedBitRates(sampleRate: 44_100, channels: 2).contains(128_000))
        #expect(AACSettings.supportedBitRates(sampleRate: 48_000, channels: 1).contains(128_000))
    }

    @Test("44.1 kHz stereo still asks for 128 kb/s, so those exports are unchanged")
    func commonFormatsAreUnchanged() throws {
        let stereo = try format(sampleRate: 44_100, channels: 2)
        let settings = AACSettings.writerSettings(hint: stereo)
        #expect(settings[AVEncoderBitRateKey] as? Int == 128_000)
        #expect(AACSettings.writerSettings(hint: nil)[AVEncoderBitRateKey] as? Int == 128_000)
    }

    @Test("22.05 kHz mono asks for a bitrate the encoder accepts")
    func lowRateMonoIsClamped() throws {
        let mono = try format(sampleRate: 22_050, channels: 1)
        let settings = AACSettings.writerSettings(hint: mono)
        #expect(settings[AVEncoderBitRateKey] as? Int == 64_000)
        #expect(settings[AVSampleRateKey] as? Double == 22_050)
        #expect(settings[AVNumberOfChannelsKey] as? Int == 1)
    }

    // MARK: - The export itself

    @Test("A speed-ramped export of a 22.05 kHz mono clip writes video and sound")
    func speedRampOnLowRateAudioExports() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("reencode-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let clip = try await Fixture.clip(seconds: 4, sampleRate: 22_050, in: folder)
        let output = folder.appendingPathComponent("out.mp4")
        // One removed stretch and one sped-up pause: the two kinds of cut
        // `--trim-silence` and `--silence-speed` make.
        let document = CaptionDocument(
            videoURL: clip,
            cuts: [Cut(start: 1.0, end: 1.4), Cut(start: 2.0, end: 3.0, speed: 2)],
            renderConfig: RenderConfig(width: 180, height: 320)
        )
        try await CaptionExporter.export(document: document, to: output)

        let asset = AVURLAsset(url: output)
        let audio = try #require(try await asset.loadTracks(withMediaType: .audio).first)
        #expect(try await asset.loadTracks(withMediaType: .video).count == 1)
        let audioFormat = try #require(try await audio.load(.formatDescriptions).first)
        let rate = CMAudioFormatDescriptionGetStreamBasicDescription(audioFormat)?.pointee.mSampleRate
        #expect(rate == 22_050)
        // 4 s, less 0.4 s removed, less half of the 1 s ramp.
        let duration = try await asset.load(.duration).seconds
        #expect(abs(duration - 3.1) < 0.1, "duration \(duration)")
    }

    // MARK: - Fixtures

    private func format(sampleRate: Double, channels: UInt32) throws -> CMFormatDescription {
        var asbd = AudioStreamBasicDescription(
            mSampleRate: sampleRate, mFormatID: kAudioFormatMPEG4AAC, mFormatFlags: 0,
            mBytesPerPacket: 0, mFramesPerPacket: 1024, mBytesPerFrame: 0,
            mChannelsPerFrame: channels, mBitsPerChannel: 0, mReserved: 0
        )
        var description: CMFormatDescription?
        CMAudioFormatDescriptionCreate(
            allocator: nil, asbd: &asbd, layoutSize: 0, layout: nil,
            magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &description
        )
        return try #require(description)
    }
}

/// A synthetic clip: grey H.264 frames with an AAC tone, muxed into a .mov.
enum Fixture {

    static func clip(seconds: Double, sampleRate: Double, in folder: URL) async throws -> URL {
        let video = try await silentVideo(seconds: seconds, in: folder)
        let sound = try tone(seconds: seconds, sampleRate: sampleRate, in: folder)

        let composition = AVMutableComposition()
        let videoAsset = AVURLAsset(url: video)
        let soundAsset = AVURLAsset(url: sound)
        let range = CMTimeRange(start: .zero, duration: CMTime(seconds: seconds, preferredTimescale: 600))
        let videoTrack = try #require(composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid))
        try videoTrack.insertTimeRange(range, of: try #require(try await videoAsset.loadTracks(withMediaType: .video).first), at: .zero)
        let soundTrack = try #require(composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid))
        let soundDuration = try await soundAsset.load(.duration)
        try soundTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: min(range.duration, soundDuration)),
            of: try #require(try await soundAsset.loadTracks(withMediaType: .audio).first),
            at: .zero
        )

        let url = folder.appendingPathComponent("clip.mov")
        let session = try #require(AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough))
        try await session.export(to: url, as: .mov)
        return url
    }

    /// AAC at `sampleRate`, mono — the format `say` voices a clip in.
    private static func tone(seconds: Double, sampleRate: Double, in folder: URL) throws -> URL {
        let url = folder.appendingPathComponent("tone.m4a")
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1))
        let file = try AVAudioFile(forWriting: url, settings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: sampleRate, AVNumberOfChannelsKey: 1,
        ])
        let frames = AVAudioFrameCount(seconds * sampleRate)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
        buffer.frameLength = frames
        for index in 0..<Int(frames) {
            buffer.floatChannelData![0][index] = Float(sin(Double(index) * 2 * .pi * 440 / sampleRate) * 0.3)
        }
        try file.write(from: buffer)
        return url
    }

    /// Grey 160×284 H.264 frames at 30 fps.
    private static func silentVideo(seconds: Double, in folder: URL) async throws -> URL {
        let url = folder.appendingPathComponent("video.mov")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 160, AVVideoHeightKey: 284,
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: 160, kCVPixelBufferHeightKey as String: 284,
        ])
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        for frame in 0..<Int(seconds * 30) {
            try await waitUntilReady(input, of: writer)
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, try #require(adaptor.pixelBufferPool), &buffer)
            let pixels = try #require(buffer)
            CVPixelBufferLockBaseAddress(pixels, [])
            memset(CVPixelBufferGetBaseAddress(pixels), 128, CVPixelBufferGetDataSize(pixels))
            CVPixelBufferUnlockBaseAddress(pixels, [])
            adaptor.append(pixels, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: 30))
        }
        input.markAsFinished()
        await writer.finishWriting()
        return url
    }
}
