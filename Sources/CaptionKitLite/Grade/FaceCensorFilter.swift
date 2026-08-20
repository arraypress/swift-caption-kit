//
//  FaceCensorFilter.swift
//  CaptionKitLite
//
//  Created by David Sherlock on 2026.
//

import CoreImage
import CoreText
import Foundation

/// Applies a tracked privacy cover (blur / pixelate / emoji) over the face.
///
/// Runs in SOURCE space — before the reframe transform — so the mask lines up
/// with the ``FaceCensor`` track (which is normalized to the source frame) and
/// then rides through reframe/crop with the footage. One builder, used by both
/// the exporter and the live preview handler.
public struct FaceCensorFilter: @unchecked Sendable {

    public let censor: FaceCensor
    private let emojiImage: CIImage?

    public init?(censor: FaceCensor) {
        guard !censor.keyframes.isEmpty else { return nil }
        self.censor = censor
        emojiImage = censor.mode == .emoji ? Self.renderEmoji(censor.emoji) : nil
    }

    /// `time` is source seconds; `sourceSize` the extent of `image`.
    public func apply(_ image: CIImage, at time: TimeInterval, sourceSize: CGSize) -> CIImage {
        guard let box = FaceCensorTrack.rect(at: time, keyframes: censor.keyframes) else { return image }
        let grow = 1 + max(0, censor.padding)
        let w = box.w * grow * sourceSize.width
        let h = box.h * grow * sourceSize.height
        // Normalized top-left center → CoreImage bottom-left pixel center.
        let cx = box.cx * sourceSize.width
        let cy = (1 - box.cy) * sourceSize.height
        let face = CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h)

        switch censor.mode {
        case .emoji:
            guard let emojiImage else { return image }
            let extent = emojiImage.extent
            guard extent.width > 0, extent.height > 0 else { return image }
            let scale = max(w / extent.width, h / extent.height) * 1.15
            let scaled = emojiImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            let placed = scaled.transformed(by: CGAffineTransform(
                translationX: face.midX - scaled.extent.midX,
                y: face.midY - scaled.extent.midY
            ))
            return placed.composited(over: image)

        case .blur:
            let radius = 6 + censor.intensity * 45
            let blurred = image
                .clampedToExtent()
                .applyingFilter("CIGaussianBlur", parameters: ["inputRadius": radius])
                .cropped(to: image.extent)
            return blurred.applyingFilter("CIBlendWithMask", parameters: [
                "inputBackgroundImage": image,
                "inputMaskImage": mask(over: face, in: image.extent),
            ]).cropped(to: image.extent)

        case .pixelate:
            let scale = max(6, 6 + censor.intensity * min(w, h) * 0.35)
            let pixelated = image
                .clampedToExtent()
                .applyingFilter("CIPixellate", parameters: [
                    "inputCenter": CIVector(x: face.midX, y: face.midY),
                    "inputScale": scale,
                ])
                .cropped(to: image.extent)
            return pixelated.applyingFilter("CIBlendWithMask", parameters: [
                "inputBackgroundImage": image,
                "inputMaskImage": mask(over: face, in: image.extent),
            ]).cropped(to: image.extent)
        }
    }

    /// A soft white oval over the face on black — feathered so the cover
    /// blends rather than showing a hard edge.
    private func mask(over face: CGRect, in extent: CGRect) -> CIImage {
        let radius = max(face.width, face.height) / 2
        let gradient = CIFilter(name: "CIRadialGradient")
        gradient?.setValue(CIVector(x: face.midX, y: face.midY), forKey: "inputCenter")
        gradient?.setValue(radius * 0.72, forKey: "inputRadius0")
        gradient?.setValue(radius * 1.05, forKey: "inputRadius1")
        gradient?.setValue(CIColor(red: 1, green: 1, blue: 1, alpha: 1), forKey: "inputColor0")
        gradient?.setValue(CIColor(red: 0, green: 0, blue: 0, alpha: 1), forKey: "inputColor1")
        return (gradient?.outputImage ?? CIImage(color: .black)).cropped(to: extent)
    }

    /// Rasterizes an emoji to a CIImage via CoreText (cross-platform — no
    /// AppKit/UIKit), transparent background.
    private static func renderEmoji(_ emoji: String) -> CIImage? {
        let side = 256
        let fontSize: CGFloat = 200
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }

        let font = CTFontCreateWithName("AppleColorEmoji" as CFString, fontSize, nil)
        let attributed = NSAttributedString(
            string: emoji.isEmpty ? "🙂" : emoji,
            attributes: [kCTFontAttributeName as NSAttributedString.Key: font]
        )
        let line = CTLineCreateWithAttributedString(attributed)
        let bounds = CTLineGetImageBounds(line, context)
        context.textPosition = CGPoint(
            x: (CGFloat(side) - bounds.width) / 2 - bounds.minX,
            y: (CGFloat(side) - bounds.height) / 2 - bounds.minY
        )
        CTLineDraw(line, context)
        guard let cgImage = context.makeImage() else { return nil }
        return CIImage(cgImage: cgImage)
    }
}
