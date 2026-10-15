//
//  StickerError.swift
//  CaptionKit
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Why a sticker was refused. Each names the sticker, so an agent placing a
/// dozen knows which one to change.
public enum StickerError: Error, LocalizedError, Equatable, Sendable {

    /// The word is never said.
    case wordNotFound(sticker: String, word: String)

    /// The word is said, but not that many times.
    case occurrenceMissing(sticker: String, word: String, occurrence: Int, found: Int)

    /// A span that ends before it starts, or starts before zero.
    case badSpan(sticker: String, start: TimeInterval, end: TimeInterval)

    /// A width outside `0.02…1` of the frame.
    case badSize(sticker: String, size: Double)

    /// The file cannot be read as a picture or a video.
    case unreadable(sticker: String, path: String)

    /// It would break the restraint rules: too many on screen, or too soon
    /// after the one before.
    case spacing(sticker: String, other: String, reason: String)

    /// No spot inside the safe zone is clear of what is listed, even at the
    /// smallest size tried.
    case noRoom(sticker: String, blockedBy: [String])

    public var errorDescription: String? {
        switch self {
        case .wordNotFound(let sticker, let word):
            return "\(sticker): \"\(word)\" is never said in the transcript"
        case .occurrenceMissing(let sticker, let word, let occurrence, let found):
            return "\(sticker): \"\(word)\" is said \(found) time\(found == 1 ? "" : "s"), so there is no occurrence \(occurrence)"
        case .badSpan(let sticker, let start, let end):
            return String(format: "%@: a span runs forward from 0 or later; not %.2f–%.2f s", sticker, start, end)
        case .badSize(let sticker, let size):
            return "\(sticker): size is a fraction of the frame's width, 0.02–1; not \(size)"
        case .unreadable(let sticker, let path):
            return "\(sticker): cannot read \(path) as a picture, a GIF/APNG or a video"
        case .spacing(let sticker, let other, let reason):
            return "\(sticker): \(reason) (\(other))"
        case .noRoom(let sticker, let blockedBy):
            return "\(sticker): no clear spot inside the safe zone, even at the smallest size — blocked by \(blockedBy.joined(separator: ", "))"
        }
    }
}
