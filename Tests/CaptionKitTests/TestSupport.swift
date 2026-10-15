//
//  TestSupport.swift
//  CaptionKitTests
//
//  Created by David Sherlock on 2026.
//
//  Helpers more than one suite needs.

import AVFoundation

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
