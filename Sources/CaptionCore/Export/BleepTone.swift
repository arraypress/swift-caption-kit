//
//  BleepTone.swift
//  CaptionCore
//
//  Created by David Sherlock on 2026.
//

import AVFoundation

/// Generates the classic censor "bleep" — a 1 kHz sine tone — as a mono PCM
/// file the exporter splices in over censored words (with the voice ducked to
/// silence underneath). Kept dead simple and dependency-free: no sample assets
/// to ship, and the tone is synthesised on demand at the length needed.
@_spi(CaptionEngine) public enum BleepTone {

    /// Renders a sine tone of `duration` seconds to a temp CAF file and returns
    /// its URL, or `nil` on failure. Includes a 5 ms fade in/out so splicing it
    /// mid-timeline doesn't click.
    @_spi(CaptionEngine) public static func makeFile(duration: Double, frequency: Double = 1000, sampleRate: Double = 44_100) -> URL? {
        let frameCount = AVAudioFrameCount(max(1, (duration * sampleRate).rounded()))
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let samples = buffer.floatChannelData?[0]
        else { return nil }
        buffer.frameLength = frameCount

        let frames = Int(frameCount)
        let angularStep = 2.0 * Double.pi * frequency / sampleRate
        let fade = min(Int(0.005 * sampleRate), frames / 2)
        let peak = 0.6

        for i in 0..<frames {
            var amplitude = peak
            if i < fade {
                amplitude *= Double(i) / Double(fade)
            } else if i >= frames - fade {
                amplitude *= Double(frames - i) / Double(fade)
            }
            samples[i] = Float(sin(angularStep * Double(i)) * amplitude)
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("caption-censor-bleep-\(frames).caf")
        do {
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            try file.write(from: buffer)
            return url
        } catch {
            return nil
        }
    }
}
