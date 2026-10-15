//
//  SeededRandom.swift
//  CaptionCore
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Deterministic pseudo-randomness for seeded looks (glyph scatter, mixed
/// letters). Swift's `Hasher` is process-seeded, so it can never back a look
/// that must survive an app relaunch — the same seed must produce the same
/// jumble in the preview, in the export, and when the project reopens.
public enum SeededRandom {

    /// A uniform value in `0..<1` from any mix of integer inputs (FNV-1a).
    public static func unit(_ values: Int...) -> Double {
        var hash: UInt64 = 0xcbf29ce484222325
        for value in values {
            var v = UInt64(bitPattern: Int64(value))
            for _ in 0..<8 {
                hash = (hash ^ (v & 0xFF)) &* 0x100000001b3
                v >>= 8
            }
        }
        // Take the top bits — the avalanche quality is better up there.
        return Double(hash >> 11) / Double(UInt64(1) << 53)
    }

    /// A uniform value in `-1...1`.
    public static func signedUnit(_ values: Int...) -> Double {
        var hash: UInt64 = 0xcbf29ce484222325
        for value in values {
            var v = UInt64(bitPattern: Int64(value))
            for _ in 0..<8 {
                hash = (hash ^ (v & 0xFF)) &* 0x100000001b3
                v >>= 8
            }
        }
        return Double(hash >> 11) / Double(UInt64(1) << 52) - 1
    }
}
