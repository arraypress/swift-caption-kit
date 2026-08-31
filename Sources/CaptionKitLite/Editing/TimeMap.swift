//
//  TimeMap.swift
//  CaptionKitLite
//
//  Created by David Sherlock on 2026.
//
//  Timeline math, not a model: it lived beside Cut in Models/, but
//  nothing about it is data. Exporters and timeline UIs call it; a Cut
//  merely feeds it.
//

import Foundation

/// Pure math translating between the source timeline and the output timeline
/// once cuts are applied.
///
/// Used by the exporter (output frame time → source time, to draw the right
/// caption state on the right footage) and useful to apps for timeline UIs
/// and cut-skipping playback.
public struct TimeMap: Equatable, Sendable {

    /// Normalized cuts: sorted, merged, non-overlapping.
    public let cuts: [Cut]

    public init(cuts: [Cut]) {
        self.cuts = TimeMap.normalize(cuts)
    }

    /// Sorts, merges same-treatment overlaps, clamps mixed overlaps, and
    /// drops empty ranges.
    public static func normalize(_ cuts: [Cut]) -> [Cut] {
        let sorted = cuts.filter { $0.duration > 0 }.sorted { $0.start < $1.start }
        var merged: [Cut] = []
        for cut in sorted {
            var cut = cut
            if var last = merged.last {
                if cut.start <= last.end, cut.speed == last.speed {
                    last.end = max(last.end, cut.end)
                    merged[merged.count - 1] = last
                    continue
                }
                // Different treatments never overlap; the earlier one wins
                // the contested span.
                cut.start = max(cut.start, last.end)
                guard cut.duration > 0 else { continue }
            }
            merged.append(cut)
        }
        return merged
    }

    /// How much shorter the output is than the source, in seconds —
    /// removed ranges vanish entirely, sped ranges save the difference.
    public var removedDuration: TimeInterval {
        cuts.reduce(0) { $0 + $1.duration - $1.outputDuration }
    }

    /// Maps a time on the output (shortened) timeline to the source time
    /// whose frame is shown there.
    public func sourceTime(forOutput time: TimeInterval) -> TimeInterval {
        var output: TimeInterval = 0
        var source: TimeInterval = 0
        for cut in cuts {
            // Plain footage before this cut plays at rate 1.
            let plain = cut.start - source
            if time < output + plain {
                return source + (time - output)
            }
            output += plain
            source = cut.start
            if let speed = cut.speed {
                let scaled = cut.outputDuration
                if time < output + scaled {
                    return source + (time - output) * speed
                }
                output += scaled
            }
            source = cut.end
        }
        return source + (time - output)
    }

    /// Maps a source time to the output timeline. Times inside a removed
    /// cut collapse to the moment it vanishes; inside a sped cut they land
    /// proportionally within the hurried span.
    public func outputTime(forSource time: TimeInterval) -> TimeInterval {
        var output: TimeInterval = 0
        var source: TimeInterval = 0
        for cut in cuts {
            if time < cut.start {
                return output + (time - source)
            }
            output += cut.start - source
            if let speed = cut.speed {
                if time < cut.end {
                    return output + (time - cut.start) / speed
                }
                output += cut.outputDuration
            } else if time < cut.end {
                return output
            }
            source = cut.end
        }
        return output + (time - source)
    }

    /// Everything that PLAYS, in order: plain ranges at rate 1 (`speed`
    /// `nil`) and sped ranges at their rate. Removed ranges are absent.
    /// This is what the exporter splices (sped ranges get scaled).
    public func playbackSegments(
        sourceDuration: TimeInterval
    ) -> [(start: TimeInterval, end: TimeInterval, speed: Double?)] {
        var segments: [(start: TimeInterval, end: TimeInterval, speed: Double?)] = []
        var cursor: TimeInterval = 0
        for cut in cuts where cut.start < sourceDuration {
            if cut.start > cursor {
                segments.append((cursor, cut.start, nil))
            }
            let end = min(cut.end, sourceDuration)
            if let speed = cut.speed, end > cut.start {
                segments.append((max(cursor, cut.start), end, speed))
            }
            cursor = max(cursor, end)
        }
        if cursor < sourceDuration {
            segments.append((cursor, sourceDuration, nil))
        }
        return segments
    }

    /// The kept ranges of a source of the given duration, in order — what
    /// the exporter splices together.
    public func keptRanges(sourceDuration: TimeInterval) -> [Cut] {
        var keeps: [Cut] = []
        var cursor: TimeInterval = 0
        for cut in cuts where cut.start < sourceDuration {
            if cut.start > cursor {
                keeps.append(Cut(start: cursor, end: cut.start))
            }
            cursor = max(cursor, min(cut.end, sourceDuration))
        }
        if cursor < sourceDuration {
            keeps.append(Cut(start: cursor, end: sourceDuration))
        }
        return keeps
    }
}
