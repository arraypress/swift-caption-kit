//
//  SubtitleFile.swift
//  CaptionKitLite
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Sidecar subtitle files (SRT/VTT) from the caption cards — for YouTube
/// uploads, accessibility, and anywhere burned-in captions aren't wanted.
/// Times are mapped through the cut/speed TimeMap so they match the
/// exported video, not the raw source.
public enum SubtitleFile {

    public enum Format: String, CaseIterable, Sendable {
        case srt
        case vtt

        public var fileExtension: String { rawValue }
    }

    /// Renders the document's cards as subtitle text in `format`.
    public static func render(document: CaptionDocument, format: Format) -> String {
        let map = document.timeMap
        var cues: [(start: TimeInterval, end: TimeInterval, text: String)] = []
        for card in document.cards {
            let start = map.outputTime(forSource: card.start)
            let end = map.outputTime(forSource: card.end)
            let text = card.lines.map { line in
                line.map(\.text).joined(separator: " ")
            }.joined(separator: "\n")
            // Cards swallowed whole by a removed cut collapse to nothing.
            guard end - start > 0.05, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            cues.append((start, end, text))
        }

        switch format {
        case .srt:
            return cues.enumerated().map { index, cue in
                "\(index + 1)\n\(timestamp(cue.start, comma: true)) --> \(timestamp(cue.end, comma: true))\n\(cue.text)"
            }.joined(separator: "\n\n") + "\n"
        case .vtt:
            let body = cues.map { cue in
                "\(timestamp(cue.start, comma: false)) --> \(timestamp(cue.end, comma: false))\n\(cue.text)"
            }.joined(separator: "\n\n")
            return "WEBVTT\n\n" + body + "\n"
        }
    }

    private static func timestamp(_ time: TimeInterval, comma: Bool) -> String {
        let clamped = max(0, time)
        let hours = Int(clamped) / 3600
        let minutes = (Int(clamped) % 3600) / 60
        let seconds = Int(clamped) % 60
        let milliseconds = Int((clamped - clamped.rounded(.down)) * 1000)
        let separator = comma ? "," : "."
        return String(format: "%02d:%02d:%02d%@%03d", hours, minutes, seconds, separator, milliseconds)
    }
}
