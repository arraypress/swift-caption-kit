//
//  GradientOverlayFilter.swift
//  CaptionCore
//
//  Created by David Sherlock on 2026.
//

import CoreImage
import Foundation

/// A color-wash gradient over the footage — the "Gradient" look mobile
/// caption apps ship: one color fading across the frame at an angle,
/// under the captions. `nil` second color fades to clear.
public struct GradientOverlay: Codable, Equatable, Sendable {
    /// The wash color at the gradient's origin edge.
    public var color: StyleColor
    /// The far edge's color; `nil` fades to transparent.
    public var secondColor: StyleColor?
    /// Overall strength `0…1` (multiplies both colors' alpha).
    public var opacity: Double
    /// How much of the frame the fade spans, `0.1…1` (small = a tight edge
    /// band, 1 = across the whole frame).
    public var spread: Double
    /// Direction in degrees: 0 = left→right, 90 = bottom→top.
    public var angleDegrees: Double

    public init(
        color: StyleColor = StyleColor(red: 0.98, green: 0.75, blue: 0.30),
        secondColor: StyleColor? = nil,
        opacity: Double = 0.45,
        spread: Double = 0.8,
        angleDegrees: Double = 90
    ) {
        self.color = color
        self.secondColor = secondColor
        self.opacity = opacity
        self.spread = spread
        self.angleDegrees = angleDegrees
    }
}

/// Renders a ``GradientOverlay`` onto frames. Pure CoreImage, no state —
/// the same call runs in the preview pipeline and the exporter.
public struct GradientOverlayFilter: Sendable {

    public let overlay: GradientOverlay

    public init(_ overlay: GradientOverlay) {
        self.overlay = overlay
    }

    public func apply(_ image: CIImage) -> CIImage {
        let extent = image.extent
        guard overlay.opacity > 0.005, extent.width > 1 else { return image }
        let angle = overlay.angleDegrees * .pi / 180
        let direction = CGVector(dx: cos(angle), dy: sin(angle))
        let reach = (abs(direction.dx) * extent.width + abs(direction.dy) * extent.height)
            * min(1, max(0.1, overlay.spread))
        let center = CGPoint(x: extent.midX, y: extent.midY)
        let from = CGPoint(x: center.x - direction.dx * reach / 2, y: center.y - direction.dy * reach / 2)
        let to = CGPoint(x: center.x + direction.dx * reach / 2, y: center.y + direction.dy * reach / 2)

        func ciColor(_ color: StyleColor, fallbackAlpha: Double) -> CIColor {
            CIColor(
                red: color.red, green: color.green, blue: color.blue,
                alpha: color.alpha * overlay.opacity * fallbackAlpha
            )
        }
        let near = ciColor(overlay.color, fallbackAlpha: 1)
        let far = overlay.secondColor.map { ciColor($0, fallbackAlpha: 1) }
            ?? CIColor(red: overlay.color.red, green: overlay.color.green, blue: overlay.color.blue, alpha: 0)

        let gradient = CIFilter(name: "CILinearGradient", parameters: [
            "inputPoint0": CIVector(x: from.x, y: from.y),
            "inputPoint1": CIVector(x: to.x, y: to.y),
            "inputColor0": near,
            "inputColor1": far,
        ])?.outputImage?.cropped(to: extent)
        guard let gradient else { return image }
        return gradient.composited(over: image).cropped(to: extent)
    }
}
