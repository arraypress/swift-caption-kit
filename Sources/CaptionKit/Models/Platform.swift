//
//  Platform.swift
//  CaptionKit
//
//  Created by David Sherlock on 2026.
//

import CoreGraphics
import Foundation

/// A short-video platform whose own interface covers part of a 9:16 frame —
/// the progress bar, the like/comment rail, the caption and sound line, the
/// tab bar. Text placed under one of those is hidden, or fights a button,
/// once the video is posted.
///
/// The covered regions are ``PlatformZones/zones(for:)``; the rectangle left
/// clear is ``PlatformZones/safeRect(for:)``.
public enum Platform: String, Codable, CaseIterable, Sendable {

    /// An Instagram story.
    case story

    /// An Instagram reel.
    case reel

    /// A TikTok post.
    case tiktok

    /// A YouTube short.
    case shorts
}

/// One region of the frame a platform's interface occupies, normalized `0…1`
/// on a 9:16 canvas with a **top-left** origin.
public struct ScreenZone: Codable, Equatable, Sendable {

    /// The covered rectangle.
    public var rect: CGRect

    /// What covers it, e.g. "Actions" or "Tab bar".
    public var label: String

    public init(rect: CGRect, label: String) {
        self.rect = rect
        self.label = label
    }
}
