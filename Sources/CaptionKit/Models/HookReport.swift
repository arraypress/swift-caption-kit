//
//  HookReport.swift
//  CaptionKit
//
//  Created by David Sherlock on 2026.
//

import CoreGraphics
import Foundation

/// What ``HookBuilder`` decided and measured.
public struct HookReport: Codable, Equatable, Sendable {
    public var text: String
    public var template: String
    /// Source seconds on screen.
    public var start: TimeInterval
    public var end: TimeInterval
    /// The rectangle it was kept inside, normalized top-left.
    public var safeRect: CGRect
    /// Where it landed, plate and outline included, normalized top-left.
    public var titleRect: CGRect
    /// Whether ``titleRect`` lies inside ``safeRect``.
    public var insideSafeZone: Bool
    /// Faces found across the sampled frames.
    public var faces: Int
    /// The share of the title's area over a (padded) face, `0…1`.
    public var faceOverlap: Double
    /// The share of the title's area over a (padded) caption, `0…1`.
    public var captionOverlap: Double
    /// The WCAG contrast ratio of the text against the worst-case footage
    /// (or plate) behind it.
    public var contrast: Double
    /// The plate's opacity when one was added for contrast, else `nil`.
    public var plateAlpha: Double?
    /// The type size as a fraction of the template's.
    public var scale: Double
    /// Whether a spot clear of every face and caption was found.
    public var placed: Bool
    /// How many frames were measured.
    public var framesSampled: Int
}
