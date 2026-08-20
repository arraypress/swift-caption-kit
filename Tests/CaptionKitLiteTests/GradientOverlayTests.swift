//
//  GradientOverlayTests.swift
//  CaptionKitLiteTests
//
//  Created by David Sherlock on 2026.
//
//  The footage color-wash: it must actually tint, respect opacity zero,
//  follow its angle, and round-trip through the document.
//

import CoreImage
import Foundation
import Testing
@testable import CaptionKitLite

@Suite("Gradient overlay")
struct GradientOverlayTests {

    private let context = CIContext(options: [.workingColorSpace: NSNull()])

    /// Mean RGB of a rendered region.
    private func meanColor(_ image: CIImage, rect: CGRect) -> (r: Double, g: Double, b: Double) {
        let averaged = image.applyingFilter("CIAreaAverage", parameters: ["inputExtent": CIVector(cgRect: rect)])
        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(averaged, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        return (Double(pixel[0]) / 255, Double(pixel[1]) / 255, Double(pixel[2]) / 255)
    }

    private var gray: CIImage {
        CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5)).cropped(to: CGRect(x: 0, y: 0, width: 200, height: 400))
    }

    @Test("A red wash at 90° tints the top more than the bottom")
    func verticalWash() {
        let overlay = GradientOverlay(color: StyleColor(red: 1, green: 0, blue: 0), opacity: 0.8, spread: 1, angleDegrees: 90)
        let out = GradientOverlayFilter(overlay).apply(gray)
        // The wash color anchors at the gradient's ORIGIN edge — bottom at
        // 90° — and fades to clear toward the top.
        let top = meanColor(out, rect: CGRect(x: 0, y: 300, width: 200, height: 100))
        let bottom = meanColor(out, rect: CGRect(x: 0, y: 0, width: 200, height: 100))
        #expect(bottom.r > top.r + 0.1, "Red anchors at the origin edge and fades out")
        #expect(bottom.r > bottom.g + 0.2, "The origin edge is unmistakably red")
    }

    @Test("Zero opacity is a no-op; two-color fills both ends")
    func opacityAndTwoColor() {
        let off = GradientOverlay(opacity: 0)
        let outOff = GradientOverlayFilter(off).apply(gray)
        let mid = meanColor(outOff, rect: CGRect(x: 0, y: 0, width: 200, height: 400))
        #expect(abs(mid.r - 0.5) < 0.02 && abs(mid.b - 0.5) < 0.02)

        let duo = GradientOverlay(
            color: StyleColor(red: 1, green: 0, blue: 0),
            secondColor: StyleColor(red: 0, green: 0, blue: 1),
            opacity: 0.9, spread: 1, angleDegrees: 90
        )
        let outDuo = GradientOverlayFilter(duo).apply(gray)
        let bottom = meanColor(outDuo, rect: CGRect(x: 0, y: 0, width: 200, height: 80))
        let top = meanColor(outDuo, rect: CGRect(x: 0, y: 320, width: 200, height: 80))
        #expect(bottom.r > bottom.b, "Near edge leans on the first color")
        #expect(top.b > top.r, "Far edge leans on the second color")
    }

    @Test("Round-trips through the document")
    func codable() throws {
        var doc = CaptionDocument(videoURL: URL(fileURLWithPath: "/v.mov"), cards: [])
        doc.gradientOverlay = GradientOverlay(opacity: 0.33, spread: 0.5, angleDegrees: 45)
        let decoded = try CaptionDocument.deserialize(from: doc.serialized())
        #expect(decoded.gradientOverlay?.opacity == 0.33)
        #expect(decoded.gradientOverlay?.angleDegrees == 45)
    }
}
