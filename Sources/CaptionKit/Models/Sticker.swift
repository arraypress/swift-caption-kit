//
//  Sticker.swift
//  CaptionKit
//
//  Created by David Sherlock on 2026.
//
//  Stickers an agent asks for, and the ones the placer put down. A request
//  says what (an emoji, a picture, an animation), when (a spoken word or a
//  span of time), how it moves and how big it is — never where: placement is
//  by rule (``StickerPlacer``), so a sticker never lands on a face, a
//  caption, the hook title or a platform's buttons, and nobody has to look.
//

import CoreGraphics
import Foundation

/// What a sticker shows.
public enum StickerSource: Codable, Equatable, Hashable, Sendable {

    /// An emoji, drawn with the system colour-emoji font.
    case emoji(String)

    /// A still picture — PNG, JPEG, HEIC… Transparency is kept.
    case image(URL)

    /// A moving picture — GIF, animated PNG, or a short video (alpha kept
    /// where the file has it: HEVC with alpha, ProRes 4444). It loops.
    case animated(URL)

    /// Extensions read as video.
    public static let videoExtensions: Set<String> = ["mov", "mp4", "m4v"]

    /// A file as a source: a video or a GIF/APNG with more than one frame is
    /// ``animated(_:)``, anything else ``image(_:)``.
    public static func file(_ url: URL) -> StickerSource {
        StickerMedia.isAnimated(url) ? .animated(url) : .image(url)
    }

    /// `{"emoji": "🔥"}`, `{"image": "/path.png"}` or `{"animated": "/path.gif"}`.
    private enum CodingKeys: String, CodingKey, CaseIterable { case emoji, image, animated }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let emoji = try container.decodeIfPresent(String.self, forKey: .emoji) {
            self = .emoji(emoji)
        } else if let image = try container.decodeIfPresent(URL.self, forKey: .image) {
            self = .image(image)
        } else if let animated = try container.decodeIfPresent(URL.self, forKey: .animated) {
            self = .animated(animated)
        } else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "a sticker source is an emoji, image or animated file"))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .emoji(let emoji): try container.encode(emoji, forKey: .emoji)
        case .image(let url): try container.encode(url, forKey: .image)
        case .animated(let url): try container.encode(url, forKey: .animated)
        }
    }

    /// A short description for messages: the emoji, or the file name.
    public var label: String {
        switch self {
        case .emoji(let emoji): return emoji
        case .image(let url), .animated(let url): return url.lastPathComponent
        }
    }
}

/// When a sticker is on screen, in source seconds.
public enum StickerTiming: Codable, Equatable, Hashable, Sendable {

    /// From a spoken word's start — the `occurrence`th time it is said
    /// (1-based) — for `duration` seconds, or ``StickerRules/defaultHold``.
    case word(String, occurrence: Int = 1, duration: TimeInterval? = nil)

    /// A span of source time.
    case span(start: TimeInterval, end: TimeInterval)

    private enum CodingKeys: String, CodingKey, CaseIterable { case word, occurrence, duration, start, end }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let word = try container.decodeIfPresent(String.self, forKey: .word) {
            self = .word(word, occurrence: try container.decodeIfPresent(Int.self, forKey: .occurrence) ?? 1,
                         duration: try container.decodeIfPresent(TimeInterval.self, forKey: .duration))
        } else {
            self = .span(start: try container.decode(TimeInterval.self, forKey: .start),
                         end: try container.decode(TimeInterval.self, forKey: .end))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .word(let word, let occurrence, let duration):
            try container.encode(word, forKey: .word)
            try container.encode(occurrence, forKey: .occurrence)
            try container.encodeIfPresent(duration, forKey: .duration)
        case .span(let start, let end):
            try container.encode(start, forKey: .start)
            try container.encode(end, forKey: .end)
        }
    }
}

/// How a sticker arrives. Each borrows a word entrance's curve.
public enum StickerEntrance: String, Codable, CaseIterable, Sendable {
    case none
    case pop
    case bounce
    case fade
    case stomp
    case drop
    case slideUp = "slide-up"
    case spin

    /// The word entrance whose curve this one rides.
    var wordAnimation: WordAnimation {
        switch self {
        case .none: return .none
        case .pop: return .popOn
        case .bounce: return .bounceIn
        case .fade: return .fadeIn
        case .stomp: return .stomp
        case .drop: return .drop
        case .slideUp: return .slideUp
        case .spin: return .rotateIn
        }
    }
}

/// How a sticker moves while it is on screen.
public enum StickerLoop: String, Codable, CaseIterable, Sendable {
    case none
    case bounce
    case float
    case spin
    case shake
    case pulse
}

/// A coarse spot a sticker would like — still subject to every rule.
public enum StickerAnchor: String, Codable, CaseIterable, Sendable {
    case top
    case upperLeft = "upper-left"
    case upperRight = "upper-right"
    case left
    case right
    case center
    case lowerLeft = "lower-left"
    case lowerRight = "lower-right"
    case bottom
}

/// A sticker an agent asks for: what, when, how it moves, how big — and,
/// at most, a coarse anchor. Where it goes is decided by ``StickerPlacer``.
public struct StickerRequest: Codable, Equatable, Sendable {

    /// A name for messages and reports; `nil` reads as "sticker N".
    public var name: String?
    public var source: StickerSource
    public var timing: StickerTiming
    /// Width as a fraction of the frame's width.
    public var size: Double
    public var entrance: StickerEntrance
    public var loop: StickerLoop
    public var anchor: StickerAnchor?

    /// The default width: about a fifth of the frame.
    public static let defaultSize = 0.18

    public init(name: String? = nil, source: StickerSource, timing: StickerTiming, size: Double = defaultSize,
                entrance: StickerEntrance = .pop, loop: StickerLoop = .none, anchor: StickerAnchor? = nil) {
        self.name = name
        self.source = source
        self.timing = timing
        self.size = size
        self.entrance = entrance
        self.loop = loop
        self.anchor = anchor
    }
}

/// A sticker where the rules put it — what the document stores and the
/// renderer draws.
public struct PlacedSticker: Codable, Equatable, Sendable {

    public var id: UUID
    /// The request's name, or "sticker N".
    public var name: String
    public var source: StickerSource
    /// On screen from, in source seconds.
    public var start: TimeInterval
    /// Off screen at, in source seconds.
    public var end: TimeInterval
    /// The sticker's box at rest, normalized `0…1`, top-left origin.
    public var rect: CGRect
    /// The width it was placed at, as a fraction of the frame's width (the
    /// request's, or smaller when it had to shrink to fit).
    public var size: Double
    public var entrance: StickerEntrance
    public var loop: StickerLoop

    public init(id: UUID = UUID(), name: String, source: StickerSource, start: TimeInterval, end: TimeInterval,
                rect: CGRect, size: Double, entrance: StickerEntrance = .pop, loop: StickerLoop = .none) {
        self.id = id
        self.name = name
        self.source = source
        self.start = start
        self.end = end
        self.rect = rect
        self.size = size
        self.entrance = entrance
        self.loop = loop
    }

    /// Whether it is on screen at `time` (source seconds).
    public func isVisible(at time: TimeInterval) -> Bool {
        time >= start && time < end
    }
}

/// How restrained stickers are: how many may share the screen, and how long
/// the screen stays clear between them.
public struct StickerRules: Codable, Equatable, Sendable {

    /// At most this many on screen at once.
    public var maxOnScreen: Int
    /// Seconds from one sticker's end to the next one's start, for stickers
    /// that do not share the screen.
    public var minimumGap: TimeInterval

    /// How long a word's sticker stays when no duration is given.
    public static let defaultHold: TimeInterval = 1.2

    public init(maxOnScreen: Int = 1, minimumGap: TimeInterval = 2) {
        self.maxOnScreen = maxOnScreen
        self.minimumGap = minimumGap
    }
}
