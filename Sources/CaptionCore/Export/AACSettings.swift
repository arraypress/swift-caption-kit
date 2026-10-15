//
//  AACSettings.swift
//  CaptionCore
//
//  Created by David Sherlock on 2026.
//
//  The writer settings for re-encoding a clip's sound as AAC.
//
//  A fixed 128 kb/s is outside what the AAC encoder accepts for low sample
//  rates: 22.05 kHz mono tops out at 64 kb/s, 8 kHz mono at 24 kb/s
//  (measured from the system encoder's applicable-bitrate list). Asked for
//  more, the writer refused the first audio sample with -11861 "Cannot Encode
//  Media", which failed every export that re-encodes sound — any cut, speed
//  ramp, bleep or volume change — on such a clip. So the bitrate is the
//  closest one the encoder actually offers, and stays 128 kb/s wherever that
//  is allowed (44.1 and 48 kHz, mono or stereo), which keeps those exports
//  byte-for-byte what they were.
//

import AudioToolbox
import AVFoundation
import Foundation

/// AAC writer settings that the system encoder accepts for the source.
@_spi(CaptionEngine) public enum AACSettings {

    /// The bitrate asked for when the encoder allows it.
    @_spi(CaptionEngine) public static let preferredBitRate = 128_000

    /// The highest sample rate the AAC encoder takes.
    static let maximumSampleRate = 48_000.0

    /// `AVAssetWriterInput` output settings for AAC, shaped by the source.
    ///
    /// - Parameter hint: The source audio's format, when there is one. Its
    ///   sample rate (capped at 48 kHz) and channel count (one or two) carry
    ///   over; without it the output is 44.1 kHz stereo.
    /// - Returns: Settings with a bitrate the encoder supports.
    @_spi(CaptionEngine) public static func writerSettings(hint: CMFormatDescription?) -> [String: Any] {
        var sampleRate = 44_100.0
        var channels = 2
        if let hint, let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(hint)?.pointee {
            sampleRate = min(maximumSampleRate, asbd.mSampleRate)
            channels = max(1, min(2, Int(asbd.mChannelsPerFrame)))
        }
        let supported = supportedBitRates(sampleRate: sampleRate, channels: channels)
        return [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channels,
            AVEncoderBitRateKey: bitRate(preferred: preferredBitRate, supported: supported),
        ]
    }

    /// The bitrate to ask for, given what the encoder supports.
    ///
    /// - Parameters:
    ///   - preferred: The bitrate wanted.
    ///   - supported: The encoder's bitrates; empty when they are unknown.
    /// - Returns: The highest supported bitrate at or below `preferred`; the
    ///   lowest supported one when all are above it; `preferred` when the
    ///   list is empty, so the writer reports the problem itself.
    @_spi(CaptionEngine) public static func bitRate(preferred: Int, supported: [Int]) -> Int {
        let usable = supported.filter { $0 > 0 }
        if let below = usable.filter({ $0 <= preferred }).max() { return below }
        return usable.min() ?? preferred
    }

    /// The bitrates the system AAC encoder offers for a PCM source.
    ///
    /// - Parameters:
    ///   - sampleRate: The output sample rate.
    ///   - channels: The output channel count.
    /// - Returns: The applicable bitrates, or empty when the encoder cannot
    ///   be asked (an unsupported rate, for one).
    @_spi(CaptionEngine) public static func supportedBitRates(sampleRate: Double, channels: Int) -> [Int] {
        let count = UInt32(max(1, channels))
        var source = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 4 * count,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4 * count,
            mChannelsPerFrame: count,
            mBitsPerChannel: 32,
            mReserved: 0
        )
        var destination = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatMPEG4AAC,
            mFormatFlags: 0,
            mBytesPerPacket: 0,
            mFramesPerPacket: 1024,
            mBytesPerFrame: 0,
            mChannelsPerFrame: count,
            mBitsPerChannel: 0,
            mReserved: 0
        )
        var converter: AudioConverterRef?
        guard AudioConverterNew(&source, &destination, &converter) == noErr, let converter else { return [] }
        defer { AudioConverterDispose(converter) }

        var size: UInt32 = 0
        guard AudioConverterGetPropertyInfo(converter, kAudioConverterApplicableEncodeBitRates, &size, nil) == noErr,
              size > 0 else { return [] }
        var ranges = [AudioValueRange](
            repeating: AudioValueRange(),
            count: Int(size) / MemoryLayout<AudioValueRange>.stride
        )
        guard AudioConverterGetProperty(converter, kAudioConverterApplicableEncodeBitRates, &size, &ranges) == noErr else {
            return []
        }
        let filled = ranges.prefix(Int(size) / MemoryLayout<AudioValueRange>.stride)
        return filled.map { Int($0.mMaximum) }.filter { $0 > 0 }
    }
}
