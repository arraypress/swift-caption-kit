//
//  Reframe.swift
//  CaptionCore
//
//  Created by David Sherlock on 2026.
//

import CoreGraphics
import Foundation

/// The aspect-fill reframe: where the source video lands on the canvas.
///
/// One function computes the placement for both the exporter and the
/// preview's video composition — the crop you scrub is the crop you ship.
public enum Reframe {

    /// The placement of the scaled source on the canvas.
    public struct Placement: Equatable, Sendable {
        /// Uniform scale applied to the source.
        public let scale: CGFloat
        /// Origin of the scaled source in canvas coordinates (CG, y-up).
        public let origin: CGPoint
        /// The scaled source size.
        public let size: CGSize
    }

    /// Computes the aspect-fill placement.
    ///
    /// - Parameters:
    ///   - source: The (oriented) source pixel size.
    ///   - canvas: The output canvas size.
    ///   - offset: Which part of the overflow to show, `0…1` per axis with
    ///     top-left semantics: `x` `0` = left edge, `1` = right edge;
    ///     `y` `0` = top, `1` = bottom. `(0.5, 0.5)` is centered.
    ///   - extraScale: Additional zoom (cut punch-ins), applied around the
    ///     canvas center.
    public static func placement(
        source: CGSize,
        canvas: CGSize,
        offset: NormalizedPoint = NormalizedPoint(x: 0.5, y: 0.5),
        extraScale: CGFloat = 1
    ) -> Placement {
        guard source.width > 0, source.height > 0 else {
            return Placement(scale: 1, origin: .zero, size: canvas)
        }
        let scale = max(canvas.width / source.width, canvas.height / source.height) * extraScale
        let size = CGSize(width: source.width * scale, height: source.height * scale)
        let overflowX = max(0, size.width - canvas.width)
        let overflowY = max(0, size.height - canvas.height)
        let x = -overflowX * min(1, max(0, offset.x))
        // Offset y uses top-left semantics; canvas coordinates are y-up.
        let y = -overflowY * (1 - min(1, max(0, offset.y)))
        return Placement(scale: scale, origin: CGPoint(x: x, y: y), size: size)
    }

    /// The placement as an affine transform (for CoreImage pipelines).
    public static func transform(
        source: CGSize,
        canvas: CGSize,
        offset: NormalizedPoint = NormalizedPoint(x: 0.5, y: 0.5),
        extraScale: CGFloat = 1
    ) -> CGAffineTransform {
        let placed = placement(source: source, canvas: canvas, offset: offset, extraScale: extraScale)
        return CGAffineTransform(a: placed.scale, b: 0, c: 0, d: placed.scale,
                                 tx: placed.origin.x, ty: placed.origin.y)
    }
}
