//
//  BackgroundBlurFilter.swift
//  CaptionKitLite
//
//  Created by David Sherlock on 2026.
//

import CoreImage
import Foundation
import Vision

/// Blurs the background behind the person — on-device Vision person
/// segmentation per frame, composited with CoreImage.
///
/// One instance per consumer (exporter, preview handler); calls are
/// internally serialized. The same filter runs in both, so parity holds.
public final class BackgroundBlurFilter: @unchecked Sendable {

    private let request: VNGeneratePersonSegmentationRequest
    private let lock = NSLock()

    /// Blur radius in pixels at render size.
    public var radius: Double

    public init(radius: Double) {
        self.radius = radius
        request = VNGeneratePersonSegmentationRequest()
        // .balanced everywhere: quality identical in preview and export.
        request.qualityLevel = .balanced
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
    }

    /// Person stays sharp; everything else blurs. Falls back to the
    /// untouched frame when no person is detected.
    public func apply(_ image: CIImage) -> CIImage {
        guard radius > 0.5 else { return image }

        lock.lock()
        defer { lock.unlock() }

        let handler = VNImageRequestHandler(ciImage: image)
        guard (try? handler.perform([request])) != nil,
              let maskBuffer = request.results?.first?.pixelBuffer else {
            return image
        }

        var mask = CIImage(cvPixelBuffer: maskBuffer)
        let scaleX = image.extent.width / mask.extent.width
        let scaleY = image.extent.height / mask.extent.height
        mask = mask.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        let blurred = image
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: ["inputRadius": radius])
            .cropped(to: image.extent)

        return image.applyingFilter("CIBlendWithMask", parameters: [
            "inputBackgroundImage": blurred,
            "inputMaskImage": mask,
        ]).cropped(to: image.extent)
    }
}
