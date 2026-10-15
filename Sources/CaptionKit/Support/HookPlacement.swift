//
//  HookPlacement.swift
//  CaptionKit
//
//  Created by David Sherlock on 2026.
//
//  Where a hook title goes, by rule: inside the safe rectangle, touching no
//  obstacle (the speaker's face, the captions on screen with it), as near the
//  preferred height as that allows. Pure geometry in normalized top-left
//  coordinates, so every placement is reproducible and testable.
//

import CoreGraphics
import Foundation

public enum HookPlacement {

    /// Where a title sits when nothing is in the way: the upper third, where
    /// the eye lands first on a vertical video.
    public static let preferredCenterY: CGFloat = 0.25

    /// How finely candidate heights are tried.
    static let step: CGFloat = 0.005

    /// The centre for a block of `size` inside `safe` that overlaps none of
    /// `obstacles`, closest to `preferredY`; `nil` when no height works.
    /// Horizontally the block is centred on the frame when it fits there, and
    /// on the safe rectangle when it does not (a platform's action rail makes
    /// the safe rectangle lopsided).
    public static func center(
        size: CGSize,
        safe: CGRect,
        obstacles: [CGRect],
        preferredY: CGFloat = preferredCenterY
    ) -> CGPoint? {
        guard size.width <= safe.width + 1e-9, size.height <= safe.height + 1e-9 else { return nil }
        let x = centerX(width: size.width, safe: safe)
        for y in heights(size: size, safe: safe, preferredY: preferredY) {
            let block = rect(center: CGPoint(x: x, y: y), size: size)
            if !obstacles.contains(where: { $0.intersects(block) }) { return CGPoint(x: x, y: y) }
        }
        return nil
    }

    /// Candidate centre heights for a block of `size` in `safe`, nearest
    /// `preferredY` first: the preferred height (clamped inside), then a
    /// ``step`` above and below, and so on outward — upward first on a tie.
    static func heights(size: CGSize, safe: CGRect, preferredY: CGFloat) -> [CGFloat] {
        let lowest = safe.minY + size.height / 2
        let highest = safe.maxY - size.height / 2
        guard highest >= lowest - 1e-9 else { return [] }
        let start = min(max(preferredY, lowest), highest)
        var result = [start]
        var k: CGFloat = 1
        while true {
            let up = start - k * step, down = start + k * step
            let upOK = up >= lowest - 1e-9, downOK = down <= highest + 1e-9
            if !upOK, !downOK { break }
            if upOK { result.append(up) }
            if downOK { result.append(down) }
            k += 1
        }
        return result
    }

    /// The centre that overlaps `obstacles` least when nothing is clear —
    /// still inside `safe`, nearest `preferredY` on a tie.
    public static func leastOverlapping(
        size: CGSize,
        safe: CGRect,
        obstacles: [CGRect],
        preferredY: CGFloat = preferredCenterY
    ) -> CGPoint {
        let x = centerX(width: min(size.width, safe.width), safe: safe)
        let candidates = heights(size: size, safe: safe, preferredY: preferredY)
        guard !candidates.isEmpty else { return CGPoint(x: x, y: safe.midY) }
        var best = (y: candidates[0], overlap: CGFloat.infinity)
        // Nearest first, so a strictly smaller overlap is the only way to move.
        for y in candidates {
            let overlap = overlapFraction(of: rect(center: CGPoint(x: x, y: y), size: size), with: obstacles)
            if overlap < best.overlap - 1e-9 { best = (y, overlap) }
        }
        return CGPoint(x: x, y: best.y)
    }

    /// The share of `block`'s area that `obstacles` cover (`0…1`), counting
    /// overlapping obstacles once, on a 64×64 grid over the block.
    public static func overlapFraction(of block: CGRect, with obstacles: [CGRect]) -> CGFloat {
        guard block.width > 0, block.height > 0 else { return 0 }
        let hits = obstacles.filter { $0.intersects(block) }
        guard !hits.isEmpty else { return 0 }
        let grid = 64
        var covered = 0
        for row in 0..<grid {
            let y = block.minY + (CGFloat(row) + 0.5) * block.height / CGFloat(grid)
            for column in 0..<grid {
                let x = block.minX + (CGFloat(column) + 0.5) * block.width / CGFloat(grid)
                if hits.contains(where: { $0.contains(CGPoint(x: x, y: y)) }) { covered += 1 }
            }
        }
        return CGFloat(covered) / CGFloat(grid * grid)
    }

    /// The rectangle of `size` centred on `center`.
    public static func rect(center: CGPoint, size: CGSize) -> CGRect {
        CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
    }

    /// `rect` grown by `amount` on every side.
    public static func padded(_ rect: CGRect, by amount: CGFloat) -> CGRect {
        rect.insetBy(dx: -amount, dy: -amount)
    }

    private static func centerX(width: CGFloat, safe: CGRect) -> CGFloat {
        let half = width / 2
        if 0.5 - half >= safe.minX - 1e-9, 0.5 + half <= safe.maxX + 1e-9 { return 0.5 }
        return safe.midX
    }
}
