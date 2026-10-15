//
//  SubtitleFile.swift
//  CaptionCore
//
//  Created by David Sherlock on 2026.
//
//  Sidecar subtitle files from the caption cards — for YouTube uploads,
//  accessibility, and anywhere burned-in captions are not wanted.
//
//  The FORMAT rules live in swift-subtitle-kit, which is the one place in
//  this fleet that decides what a cue looks like on disk. This file keeps
//  the only part that is a caption document's business: turning cards into
//  cues, with their times mapped through the cut and speed map so they line
//  up with the EXPORTED video rather than the raw source.
//
//  The timestamps this now produces ROUND to the nearest millisecond where
//  the version here used to truncate. On round numbers nothing changes; a
//  card landing on 00:00:59.9996 now writes 00:01:00,000 rather than
//  00:00:59,999.
//

import Foundation
import SubtitleKit

/// Sidecar subtitle files (SRT/VTT) from the caption cards.
public enum SubtitleFile {

    /// The sidecar formats this writes.
    public enum Format: String, CaseIterable, Sendable {
        case srt
        case vtt

        /// The extension to give the file, without the dot.
        public var fileExtension: String { rawValue }

        /// The shared format this names.
        var shared: SubtitleFormat { self == .srt ? .srt : .vtt }
    }

    /// Renders the document's cards as subtitle text in `format`.
    ///
    /// - Parameters:
    ///   - document: The caption document.
    ///   - format: Which sidecar format to write.
    /// - Returns: The document's text.
    public static func render(document: some CaptionTimeline, format: Format) -> String {
        SubtitleWriter.render(cues(in: document), format: format.shared)
    }

    /// The document's cards as cues, on the exported timeline.
    ///
    /// - Parameter document: The caption document.
    /// - Returns: The cues, with cards swallowed by a removed cut left out.
    public static func cues(in document: some CaptionTimeline) -> [SubtitleCue] {
        let map = document.timeMap
        return document.cards.compactMap { card in
            let start = map.outputTime(forSource: card.start)
            let end = map.outputTime(forSource: card.end)
            let text = card.lines.map { line in
                line.map(\.text).joined(separator: " ")
            }.joined(separator: "\n")
            // A card swallowed whole by a removed cut collapses to nothing.
            // The threshold is this library's rule, not the format's, so it
            // stays here rather than moving to the shared writer.
            guard end - start > 0.05,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return SubtitleCue(start: start, end: end, text: text)
        }
    }
}
