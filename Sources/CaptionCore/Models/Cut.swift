//
//  Cut.swift
//  CaptionCore
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A range of the source video removed from the export — a filler word, a
/// mouth sound, dead air.
///
/// Cuts live on the **source** timeline. The document's words
/// keep their original source timestamps; ``TimeMap`` translates between the
/// source timeline and the shortened output timeline at render/export time.
public struct Cut: Codable, Equatable, Hashable, Sendable {

    /// Cut start on the source timeline, in seconds.
    public var start: TimeInterval

    /// Cut end on the source timeline, in seconds.
    public var end: TimeInterval

    /// `nil` removes the range entirely. A value (e.g. `1.8`) plays it at
    /// that rate instead — the speed-ramp treatment for silences and
    /// rambles: nothing is lost, the boring part just hurries by.
    public var speed: Double?

    public init(start: TimeInterval, end: TimeInterval, speed: Double? = nil) {
        self.start = start
        self.end = max(start, end)
        self.speed = speed.map { max(1.05, min(4, $0)) }
    }

    /// The range's source duration in seconds.
    public var duration: TimeInterval {
        max(0, end - start)
    }

    /// How long the range lasts on the output timeline (`0` when removed).
    public var outputDuration: TimeInterval {
        guard let speed, speed > 0 else { return 0 }
        return duration / speed
    }
}
