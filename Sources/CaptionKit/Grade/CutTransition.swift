//
//  CutTransition.swift
//  CaptionKit
//
//  Created by David Sherlock on 2026.
//
//  The Core Image half of the cut treatments.
//

import CoreImage
import Foundation

/// Core Image cut transitions — whip pan, zoom blur, and an RGB glitch.
///
/// A seam left by filler removal reads as a fault unless something marks it.
/// ``CutStyle/dipToBlack`` and ``CutStyle/punchIn`` mark it with geometry the
/// exporter already computes; these three need pixels resampled, so they live
/// here.
///
/// One `apply` shared by every consumer, and ``strength(at:boundaries:)`` is a
/// pure function of time — so a frame drawn twice at the same instant is the
/// same frame, and a preview matches its export.
public enum CutTransition {

    /// Whether a style needs the Core Image pipeline at all.
    ///
    /// Worth asking before building one: the dip and punch treatments are
    /// geometry, and the overwhelming majority of frames in any export sit
    /// nowhere near a cut. Setting up a filter chain for them would be work
    /// thrown away on every frame.
    public static func needsCoreImage(_ style: CutStyle) -> Bool {
        switch style {
        case .whipPan, .zoomBlur, .glitch: return true
        case .none, .dipToBlack, .dipToWhite, .punchIn: return false
        }
    }

    /// The boundary envelope: `1` on the boundary frame, fading to `0` over
    /// `window` seconds either side.
    ///
    /// Linear rather than eased on purpose. A cut effect is over in a sixth of
    /// a second, and at that length an easing curve is indistinguishable from
    /// a ramp — but a ramp is trivially predictable, which matters when the
    /// same number has to be computed identically in a preview and an export.
    public static func strength(
        at time: TimeInterval,
        boundaries: [Double],
        window: Double = 0.16
    ) -> Double {
        var strongest = 0.0
        for boundary in boundaries {
            strongest = max(strongest, 1 - abs(time - boundary) / window)
        }
        return max(0, min(1, strongest))
    }

    /// Applies a boundary effect at `strength`.
    ///
    /// - Parameters:
    ///   - strength: `0` leaves the image untouched, `1` is the boundary frame.
    ///   - image: The footage, already reframed onto the canvas.
    /// - Returns: The filtered image, cropped back to its original extent —
    ///   blurs sample beyond the frame, and an image that grew would shift
    ///   everything drawn after it.
    public static func apply(style: CutStyle, strength: Double, to image: CIImage) -> CIImage {
        guard strength > 0.01, needsCoreImage(style) else { return image }
        let extent = image.extent

        switch style {
        case .whipPan:
            // Clamped first, or the blur samples transparent black past the
            // edges and darkens them.
            return image
                .clampedToExtent()
                .applyingFilter("CIMotionBlur", parameters: [
                    "inputRadius": strength * 55,
                    "inputAngle": 0,
                ])
                .cropped(to: extent)

        case .zoomBlur:
            return image
                .clampedToExtent()
                .applyingFilter("CIZoomBlur", parameters: [
                    "inputCenter": CIVector(x: extent.midX, y: extent.midY),
                    "inputAmount": strength * 28,
                ])
                .cropped(to: extent)

        case .glitch:
            return channelSplit(image, strength: strength, extent: extent)

        case .none, .dipToBlack, .dipToWhite, .punchIn:
            return image
        }
    }

    // MARK: - Glitch

    /// Red pulled left, blue pulled right, green anchored.
    ///
    /// Recombined with a per-channel **maximum** rather than additive
    /// compositing. The three layers are disjoint — each holds one channel and
    /// zero in the others — so a maximum reassembles them exactly while
    /// leaving alpha at 1. Adding them instead sums three alphas to 3, which
    /// washes out every stage drawn afterwards.
    private static func channelSplit(_ image: CIImage, strength: Double, extent: CGRect) -> CIImage {
        let shift = CGFloat(strength) * extent.width * 0.02
        let zero = CIVector(x: 0, y: 0, z: 0, w: 0)

        let red = image
            .applyingFilter("CIColorMatrix", parameters: ["inputGVector": zero, "inputBVector": zero])
            .transformed(by: CGAffineTransform(translationX: -shift, y: 0))

        let green = image
            .applyingFilter("CIColorMatrix", parameters: ["inputRVector": zero, "inputBVector": zero])

        let blue = image
            .applyingFilter("CIColorMatrix", parameters: ["inputRVector": zero, "inputGVector": zero])
            .transformed(by: CGAffineTransform(translationX: shift, y: 0))

        return red
            .applyingFilter("CIMaximumCompositing", parameters: ["inputBackgroundImage": green])
            .applyingFilter("CIMaximumCompositing", parameters: ["inputBackgroundImage": blue])
            .cropped(to: extent)
    }
}
