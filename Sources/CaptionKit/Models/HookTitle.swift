//
//  HookTitle.swift
//  CaptionKit
//
//  Created by David Sherlock on 2026.
//

import CoreGraphics
import Foundation

/// An opening title over the first seconds of a video — the line that stops
/// the scroll. Drawn by the same renderer as the captions, on top of them.
///
/// Built by ``HookBuilder``, which places it by rule (inside the platform's
/// safe zone, clear of the face and of the captions) and measures its
/// contrast; or written by hand.
public struct HookTitle: Codable, Equatable, Sendable {

    /// A stable identity, so the layout cache recognises the title frame to frame.
    public var id: UUID

    /// The title text.
    public var text: String

    /// When the title appears, in seconds of source time.
    public var start: TimeInterval

    /// When it leaves, in seconds of source time.
    public var end: TimeInterval

    /// Its look. Highlighting is ignored: a title has no spoken word.
    public var style: CaptionStyle

    /// The rectangle the title is kept inside, normalized `0…1` with a
    /// top-left origin — the platform safe zone within the canvas safe area.
    public var safeRect: CGRect

    /// Word indexes beginning each line after the first.
    public var lineBreaks: [Int]

    public init(
        id: UUID = UUID(),
        text: String,
        start: TimeInterval = 0,
        end: TimeInterval = 2.5,
        style: CaptionStyle,
        safeRect: CGRect = CGRect(x: 0.05, y: 0.10, width: 0.90, height: 0.78),
        lineBreaks: [Int] = []
    ) {
        self.id = id
        self.text = text
        self.start = start
        self.end = end
        self.style = style
        self.safeRect = safeRect
        self.lineBreaks = lineBreaks
    }
}
