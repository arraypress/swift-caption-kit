//
//  CaptionStyle+Strokes.swift
//  CaptionStyles
//
//  Created by David Sherlock on 2026.
//
//  Which outlines a word gets: its own, or the style's. Shared by both
//  caption engines' layout and renderer, so it is public here rather than
//  copied into each.
//

import CoreGraphics
import Foundation

/// A resolved stroke — a `StrokeLayer` after the per-word/global precedence has
/// been applied. Produced by ``CaptionStyle/resolvedStrokes(for:)``
/// and consumed by layout + the renderer, ordered widest-first.
public struct ResolvedStroke: Equatable, Sendable {
    public var color: StyleColor
    public var width: CGFloat

    public init(color: StyleColor, width: CGFloat) {
        self.color = color
        self.width = width
    }
}

public extension CaptionStyle {

    /// The outline stack for a word, applying precedence: a word's own layers
    /// or single stroke win entirely; otherwise the global layers or single
    /// stroke. Ordered widest-first, with non-positive widths dropped.
    func resolvedStrokes(for word: WordStyle?) -> [ResolvedStroke] {
        if let layers = word?.strokeLayers, !layers.isEmpty {
            return Self.ordered(layers)
        }
        if let color = word?.strokeColor {
            let width = max(0, word?.strokeWidth ?? strokeWidth)
            return width > 0 ? [ResolvedStroke(color: color, width: width)] : []
        }
        if let layers = strokeLayers, !layers.isEmpty {
            return Self.ordered(layers)
        }
        if let color = strokeColor, strokeWidth > 0 {
            return [ResolvedStroke(color: color, width: strokeWidth)]
        }
        return []
    }

    private static func ordered(_ layers: [StrokeLayer]) -> [ResolvedStroke] {
        layers
            .filter { $0.width > 0 }
            .map { ResolvedStroke(color: $0.color, width: $0.width) }
            .sorted { $0.width > $1.width }
    }
}
