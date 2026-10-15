//
//  SpeakerAssign.swift
//  CaptionCore
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Maps diarization turns ("speaker 0 spoke 0.0–4.2s") onto words.
/// Dependency-free: pass any engine's turns as plain tuples.
public enum SpeakerAssign {

    public struct Turn: Equatable, Sendable {
        public let speaker: Int
        public let start: TimeInterval
        public let end: TimeInterval

        public init(speaker: Int, start: TimeInterval, end: TimeInterval) {
            self.speaker = speaker
            self.start = start
            self.end = end
        }
    }

    /// Assigns each word the speaker whose turn overlaps it most; words with
    /// no overlapping turn inherit the nearest neighbor's speaker.
    public static func assign(words: [Word], turns: [Turn]) -> [Word] {
        guard !turns.isEmpty else { return words }
        var result = words
        for index in result.indices {
            let word = result[index]
            var best: (speaker: Int, overlap: TimeInterval)?
            for turn in turns {
                let overlap = min(word.end, turn.end) - max(word.start, turn.start)
                if overlap > 0, overlap > (best?.overlap ?? 0) {
                    best = (turn.speaker, overlap)
                }
            }
            if let best {
                result[index].speaker = best.speaker
            } else if let nearest = turns.min(by: {
                distance(word: word, turn: $0) < distance(word: word, turn: $1)
            }) {
                result[index].speaker = nearest.speaker
            }
        }
        return result
    }

    /// How many distinct speakers the turns contain.
    public static func speakerCount(turns: [Turn]) -> Int {
        Set(turns.map(\.speaker)).count
    }

    private static func distance(word: Word, turn: Turn) -> TimeInterval {
        if word.end < turn.start { return turn.start - word.end }
        if word.start > turn.end { return word.start - turn.end }
        return 0
    }
}
