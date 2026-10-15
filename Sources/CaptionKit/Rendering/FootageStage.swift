//
//  FootageStage.swift
//  CaptionKit
//
//  Created by David Sherlock on 2026.
//
//  One footage frame drawn the way the export draws it before the captions
//  go on: the face cover in source space, the reframe (the camera path and
//  automatic zoom included), the mirror, the background blur and the scrim —
//  in the exporter's own stage order. For a preview that shows what the
//  render will, and for measurements taken on what the viewer will see.
//

import CoreGraphics
import CoreImage
import Foundation

public enum FootageStage {

    /// Whether `document` changes the footage itself — anything beyond the
    /// plain aspect-fill reframe at a fixed crop.
    public static func changesFootage(_ document: CaptionDocument) -> Bool {
        document.gradientOverlay != nil || (document.backgroundBlur ?? 0) > 0.5 || document.faceCensor != nil
            || document.mirrorHorizontal || document.autoMotion != nil || document.cropKeyframes?.isEmpty == false
    }

    /// `footage` (a source frame at source time `time`) on a `width`×`height`
    /// canvas with `document`'s footage effects, ready for the captions.
    /// Cut transitions and dips are left out: they belong to the edit, not to
    /// a moment of source footage.
    public static func compose(_ footage: CGImage, document: CaptionDocument, at time: TimeInterval,
                               width: Int, height: Int) -> CGImage? {
        guard width > 0, height > 0 else { return nil }
        let canvas = CGSize(width: width, height: height)
        let bounds = CGRect(origin: .zero, size: canvas)
        var image = CIImage(cgImage: footage)

        if let censor = document.faceCensor.flatMap(FaceCensorFilter.init(censor:)) {
            image = censor.apply(image, at: time, sourceSize: image.extent.size)
        }

        var extraScale: CGFloat = 1
        if let motion = document.autoMotion {
            extraScale *= AutoMotion.scale(at: time, style: motion, emphasisTimes: AutoMotion.emphasisTimes(in: document.cards))
        }
        let offset = document.cropKeyframes.flatMap { CropTrack.offset(at: time, keyframes: $0) }
            ?? document.cropOffset ?? NormalizedPoint(x: 0.5, y: 0.5)
        if let keyframes = document.cropKeyframes { extraScale *= CropTrack.scale(at: time, keyframes: keyframes) }
        let placed = Reframe.placement(source: CGSize(width: footage.width, height: footage.height), canvas: canvas,
                                       offset: offset, extraScale: extraScale)
        image = image
            .transformed(by: CGAffineTransform(a: placed.scale, b: 0, c: 0, d: placed.scale,
                                               tx: placed.origin.x, ty: placed.origin.y))
            .cropped(to: bounds)
        // Black where the footage does not reach, as the exporter's cleared canvas.
        image = image.composited(over: CIImage(color: CIColor(red: 0, green: 0, blue: 0)).cropped(to: bounds))
        if document.mirrorHorizontal {
            image = image.transformed(by: CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: canvas.width, ty: 0))
        }
        if let blur = document.backgroundBlur, blur > 0.5 {
            // Radius in 1920-reference points, scaled to this canvas.
            image = BackgroundBlurFilter(radius: blur * Double(height) / 1920).apply(image)
        }
        if let overlay = document.gradientOverlay {
            image = GradientOverlayFilter(overlay).apply(image)
        }
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        return CIContext().createCGImage(image, from: bounds, format: .RGBA8, colorSpace: space)
    }
}
