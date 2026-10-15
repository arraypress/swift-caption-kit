//
//  FillerCutter.swift
//  CaptionCore
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Knobs for automatic filler removal.
public struct FillerCutRules: Codable, Equatable, Sendable {

    /// Words removed wherever they appear (matched case- and
    /// punctuation-insensitively against the transcript).
    ///
    /// The default list is conservative — "oh" and "ah" are real words as
    /// often as they are fillers, so they're not included; add them here if
    /// a given speaker abuses them.
    public var fillers: Set<String>

    /// Padding kept around a removed word so the cut doesn't clip the
    /// neighboring words' audio, in seconds.
    public var padding: TimeInterval

    /// If set, silences longer than this are also cut (keeping
    /// ``silenceKeep`` at each edge). This is what catches the "um"s Whisper
    /// itself swallows — they leave dead air between word timestamps.
    public var trimSilencesLongerThan: TimeInterval?

    /// How much of a trimmed silence to keep at each edge, in seconds.
    public var silenceKeep: TimeInterval

    /// When set, mid-video silences are SPEED-RAMPED at this rate instead
    /// of removed (Descript-style): the pause hurries by, the flow stays
    /// natural. Leading/trailing dead air is still removed outright.
    public var silenceSpeed: Double?

    public init(
        fillers: Set<String> = ["um", "umm", "uh", "uhh", "uhm", "erm", "er", "hmm", "hm", "mhm", "mm"],
        padding: TimeInterval = 0.05,
        trimSilencesLongerThan: TimeInterval? = nil,
        silenceKeep: TimeInterval = 0.25,
        silenceSpeed: Double? = nil
    ) {
        self.fillers = fillers
        self.padding = padding
        self.trimSilencesLongerThan = trimSilencesLongerThan
        self.silenceKeep = silenceKeep
        self.silenceSpeed = silenceSpeed
    }
}

/// Detects filler words and dead air in a word stream and proposes cuts.
///
/// Two detectors feed one cut list:
/// 1. **Transcribed fillers** — "um"/"uh"/… that Whisper did emit, matched by
///    text and removed from both the captions and the video.
/// 2. **Dead air** (opt-in) — Whisper suppresses many filler sounds entirely,
///    but they still leave a gap between word timestamps; long gaps are cut.
///
/// The result is a *proposal*: the app shows it on the timeline and the user
/// accepts/adjusts before it lands in the document's `cuts`.
///
/// ```swift
/// let result = FillerCutter.detect(in: words, rules: FillerCutRules(
///     trimSilencesLongerThan: 1.0
/// ))
/// let cards = CaptionGrouper.group(result.keptWords)
/// document.cuts = result.cuts
/// ```
public enum FillerCutter {

    /// The outcome of a detection pass.
    public struct Result: Equatable, Sendable {

        /// The word stream with filler words removed — group these.
        public let keptWords: [Word]

        /// The filler words that were removed, for review UI.
        public let removedWords: [Word]

        /// Proposed cuts on the source timeline (normalized).
        public let cuts: [Cut]
    }

    /// Scans a word stream for fillers (and, optionally, long silences).
    ///
    /// - Parameters:
    ///   - words: The transcript word stream.
    ///   - rules: Detection knobs.
    ///   - sourceDuration: The video's full duration. When provided together
    ///     with ``FillerCutRules/trimSilencesLongerThan``, silence *before
    ///     the first word* and *after the last word* is trimmed too — reels
    ///     should start the moment the speaker does.
    public static func detect(
        in words: [Word],
        rules: FillerCutRules = FillerCutRules(),
        sourceDuration: TimeInterval? = nil
    ) -> Result {
        var kept: [Word] = []
        var removed: [Word] = []
        var cuts: [Cut] = []

        let fillerKeys = Set(rules.fillers.map { $0.lowercased() })
        for word in words {
            if fillerKeys.contains(word.matchKey) {
                removed.append(word)
                cuts.append(Cut(start: word.start - rules.padding, end: word.end + rules.padding))
            } else {
                kept.append(word)
            }
        }

        if let threshold = rules.trimSilencesLongerThan {
            for (previous, next) in zip(kept, kept.dropFirst()) {
                let gap = next.start - previous.end
                if gap > threshold {
                    cuts.append(Cut(
                        start: previous.end + rules.silenceKeep,
                        end: next.start - rules.silenceKeep,
                        speed: rules.silenceSpeed
                    ))
                }
            }

            // Leading silence: don't make viewers wait for the first word.
            // A shorter fuse than mid-video pauses — half the threshold.
            if let first = kept.first, first.start > max(threshold / 2, rules.silenceKeep * 2) {
                cuts.append(Cut(start: 0, end: first.start - rules.silenceKeep))
            }

            // Trailing silence, when we know where the video ends.
            if let sourceDuration, let last = kept.last,
               sourceDuration - last.end > threshold {
                cuts.append(Cut(start: last.end + rules.silenceKeep, end: sourceDuration))
            }
        }

        // Never cut into a kept word: clamp each cut out of its neighbors.
        var clamped: [Cut] = []
        for cut in cuts {
            var adjusted = cut
            for word in kept {
                if word.end <= cut.start || word.start >= cut.end { continue }
                if word.start < cut.start {
                    adjusted.start = max(adjusted.start, word.end)
                }
                if word.end > cut.end {
                    adjusted.end = min(adjusted.end, word.start)
                }
            }
            if adjusted.duration > 0.01 {
                clamped.append(adjusted)
            }
        }

        return Result(
            keptWords: kept,
            removedWords: removed,
            cuts: TimeMap.normalize(clamped)
        )
    }
}
