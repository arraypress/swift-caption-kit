//
//  EditedExportTests.swift
//  CaptionKitTests
//
//  Created by David Sherlock on 2026.
//
//  Cut and sped-up exports. The exporter used to read the picture through
//  an edited composition, and on macOS 27 that reader stalls for good near
//  a cut: about one export in ten of a static clip never finished. It now
//  reads the source as it is and places each frame on the edited timeline
//  (`EditedFrameTiming`); these check the placing rules and that the export
//  keeps finishing.
//

import AVFoundation
import Foundation
import Synchronization
import Testing
@testable import CaptionKit

/// Times on a 1/600 s clock, the composition's own.
private func t(_ value: Int64) -> CMTime { CMTime(value: value, timescale: 600) }
private func span(_ start: Int64, _ end: Int64) -> CMTimeRange { CMTimeRange(start: t(start), end: t(end)) }

/// The same instants to a microsecond: a mapped time comes back on a
/// nanosecond clock, rounded.
private func same(_ times: [CMTime], _ expected: [CMTime]) -> Bool {
    times.count == expected.count && zip(times, expected).allSatisfy { abs(($0 - $1).seconds) < 1e-6 }
}

@Suite("Edited frame timing")
struct EditedFrameTimingTests {

    @Test("A frame lands at its own time, or at a piece's start when it began in the cut")
    func framesLandThroughThePieces() throws {
        // Keep 0–1 s, cut 1–1.4 s, keep 1.4–2 s.
        var timing = try #require(EditedFrameTiming(mappings: [(span(0, 600), span(0, 600)), (span(840, 1200), span(600, 960))]))
        #expect(timing.outputTimes(start: t(580), end: t(600)) == [t(580)])
        #expect(timing.outputTimes(start: t(600), end: t(820)).isEmpty, "wholly cut")
        #expect(timing.outputTimes(start: t(820), end: t(860)) == [t(600)], "began in the cut")
        #expect(same(timing.outputTimes(start: t(860), end: t(880)), [t(620)]))
    }

    @Test("A sped-up piece brings its frames closer together")
    func speedCompressesTimes() throws {
        var timing = try #require(EditedFrameTiming(mappings: [(span(0, 600), span(0, 300))]))
        #expect(same(timing.outputTimes(start: t(100), end: t(120)), [t(50)]))
        #expect(same(timing.outputTimes(start: t(400), end: t(420)), [t(200)]))
    }

    @Test("Where the source carries on into a speed change, the frame showing is not shown again")
    func carriedOnFrameIsNotRepeated() throws {
        var timing = try #require(EditedFrameTiming(mappings: [(span(0, 600), span(0, 600)), (span(600, 1200), span(600, 900))]))
        #expect(timing.outputTimes(start: t(580), end: t(620)) == [t(580)])
        #expect(same(timing.outputTimes(start: t(620), end: t(640)), [t(610)]))
    }

    @Test("A cut narrower than a frame keeps that frame on both sides of it")
    func frameSpanningANarrowCutShowsTwice() throws {
        var timing = try #require(EditedFrameTiming(mappings: [(span(0, 600), span(0, 600)), (span(610, 1200), span(600, 1190))]))
        #expect(timing.outputTimes(start: t(590), end: t(620)) == [t(590), t(600)])
    }

    @Test("Pieces out of source order, or with no length, are left to the edited composition")
    func unplaceableEditsAreRefused() {
        #expect(EditedFrameTiming(mappings: [(span(600, 1200), span(0, 600)), (span(0, 600), span(600, 1200))]) == nil)
        #expect(EditedFrameTiming(mappings: [(span(0, 600), span(0, 0))]) == nil)
        #expect(EditedFrameTiming(mappings: []) == nil)
    }
}

@Suite("Edited export", .timeLimit(.minutes(5)))
struct EditedExportTests {

    /// The clip that stalled about one export in ten: a static picture, a
    /// removed stretch and a sped-up pause. The exporter's watchdog would
    /// quietly retry a stall, so the test counts stalls rather than timing
    /// runs — a time bound failed under heavy load, where one export took
    /// 80–90 s.
    @Test("A cut, sped-up export of a static clip finishes every time")
    func staticClipWithCutsKeepsFinishing() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("edited-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let clip = try await Fixture.clip(seconds: 4, sampleRate: 22_050, in: folder)
        let document = CaptionDocument(
            videoURL: clip,
            cuts: [Cut(start: 1.0, end: 1.4), Cut(start: 2.0, end: 3.0, speed: 2)],
            renderConfig: RenderConfig(width: 180, height: 320)
        )
        // The picture's length: the sound's varies by a few hundredths from
        // run to run (it did before this change too).
        var durations: Set<Double> = []
        let stallsBefore = CaptionExporter.stalls.load(ordering: .relaxed)
        for run in 0..<12 {
            let output = folder.appendingPathComponent("out-\(run).mp4")
            try await CaptionExporter.export(document: document, to: output)
            let video = try #require(try await AVURLAsset(url: output).loadTracks(withMediaType: .video).first)
            durations.insert(try await video.load(.timeRange).duration.seconds)
        }
        #expect(CaptionExporter.stalls.load(ordering: .relaxed) == stallsBefore, "a read stalled and was retried")
        #expect(durations.count == 1, "every run the same length: \(durations)")
        #expect(abs((durations.first ?? 0) - 3.1) < 0.1)
    }
}
