//
//  CaptionTimeline.swift
//  CaptionCore
//
//  Created by David Sherlock on 2026.
//

import CoreGraphics
import Foundation

/// What the shared writers need from a caption document: its cards, its
/// canvas, its edit map and a way to draw its captions.
///
/// CaptionKit's `CaptionDocument` conforms, drawing with its renderer, so
/// ``SubtitleFile`` and ``OverlayExporter`` stay free of the renderer and
/// testable with any timeline.
public protocol CaptionTimeline: Sendable {

    /// The caption cards, on the source timeline.
    var cards: [CaptionCard] { get }

    /// The output canvas: size, frame rate and safe area.
    var renderConfig: RenderConfig { get }

    /// The source → output time map built from the document's cuts.
    var timeMap: TimeMap { get }

    /// The source video's duration, when known.
    var videoDuration: TimeInterval? { get }

    /// Draws the captions alone at `sourceTime` into `context`.
    ///
    /// - Parameters:
    ///   - context: A canvas-sized context, already cleared.
    ///   - sourceTime: The moment on the source timeline.
    func drawCaptions(in context: CGContext, at sourceTime: TimeInterval)
}
