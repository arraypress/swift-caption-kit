//
//  FacePlacer.swift
//  CaptionKit
//
//  Created by David Sherlock on 2026.
//
//  Captions placed clear of the speaker's face and inside a safe area at
//  once. Placing below the chin and then clamping into a platform's safe
//  area is not enough: Instagram keeps the bottom 35% of a Reel clear, and
//  in a selfie the chin sits near 0.69 of the frame — the clamp pushed the
//  captions straight back onto the mouth. Here both are decided together,
//  on the captions as drawn: below the chin when the block fits there,
//  above the head when it fits there, and only when neither side has room
//  on the face, at whichever edge of the safe area covers less of it.
//

import CoreGraphics
import Foundation
import Legibility
@preconcurrency import AVFoundation
import Vision

public enum FacePlacer {

    /// The space kept between the captions' ink and the chin or the top of
    /// the head, as a share of the canvas height (38 px on 1920). A spacing
    /// choice, not a measurement: the ink is measured, so this is the whole
    /// of the gap the viewer sees.
    public static let gap: CGFloat = 0.02

    /// The speaker's head in `document`'s video as the canvas frames it,
    /// from `samples` frames spread across it; `nil` when a face is in fewer
    /// than a third of them (a face glimpsed once should not pin the layout).
    public static func head(in document: CaptionDocument, samples: Int = 12) async -> SpeakerHead? {
        guard let url = document.videoURL,
              let duration = try? await AVURLAsset(url: url).load(.duration).seconds, duration > 0 else { return nil }
        let step = duration / Double(samples + 1)
        let frames = await CanvasFrames.frames(for: document, at: (1...samples).map { Double($0) * step }, width: 360)
        let masker = SubjectMasker()
        var found: [(face: CGRect, chin: CGFloat, top: CGFloat)] = []
        for frame in frames {
            let image = frame.image
            if let head = await VisionQueue.run({ measure(image, masker: masker) }) { found.append(head) }
        }
        guard found.count >= max(2, samples / 3) else { return nil }
        let face = CGRect(x: median(found.map(\.face.minX)), y: median(found.map(\.face.minY)),
                          width: median(found.map(\.face.width)), height: median(found.map(\.face.height)))
        return SpeakerHead(top: median(found.map(\.top)), face: face, chin: median(found.map(\.chin)), frames: found.count)
    }

    /// Moves `document`'s captions clear of `head` inside `safe` (normalized,
    /// top-left) and reports where they went, measured after the move.
    ///
    /// The block is measured once at the centre — every card's ink, so the
    /// tallest card decides — and moved as a whole: below the chin, else
    /// above the head, else onto whichever edge of `safe` covers less face.
    @discardableResult
    public static func place(_ document: inout CaptionDocument, head: SpeakerHead, safe: CGRect) -> CaptionPlacement? {
        let probe: CGFloat = 0.5
        var trial = document
        trial.style.position.y = probe
        guard let span = inkSpan(of: trial) else { return nil }
        let above = span.top - probe, below = span.bottom - probe   // offsets of the ink from the anchor
        let tolerance: CGFloat = 0.002

        let side: CaptionPlacement.Side
        let y: CGFloat
        let underChin = head.chin + gap - above
        let overHead = head.top - gap - below
        if underChin + below <= safe.maxY + tolerance {
            (side, y) = (.below, underChin)
        } else if overHead + above >= safe.minY - tolerance {
            (side, y) = (.above, overHead)
        } else {
            // No room for the full gap either side: the edge of the safe area
            // that covers less face. Short of the gap but clear of the face
            // (into the hair, or past the beard) still counts as that side.
            let face = head.faceToChin
            let low = safe.maxY - below, high = safe.minY - above
            let covered = { (y: CGFloat) in max(0, min(y + below, face.maxY) - max(y + above, face.minY)) }
            let useHigh = covered(high) < covered(low)
            y = useHigh ? high : low
            side = covered(y) > 0 ? .over : (useHigh ? .above : .below)
        }

        document.style.position.y = y
        return CaptionPlacement(side: side, position: y, head: head, safe: safe,
                                faceOverlap: faceOverlap(of: document, face: head.faceToChin))
    }

    /// The largest share of `face` any card's ink covers, measured on the
    /// drawn pixels.
    public static func faceOverlap(of document: CaptionDocument, face: CGRect) -> Double {
        guard face.width > 0, face.height > 0 else { return 0 }
        let worst = document.cards.compactMap { InkFit.inkRect(of: $0, in: document) }
            .map { $0.intersection(face) }.filter { !$0.isNull }
            .map { $0.width * $0.height }.max() ?? 0
        return Double(worst / (face.width * face.height))
    }

    // MARK: - Helpers

    /// The face, chin and top of head in one canvas frame: the largest face
    /// Vision finds, its contour landmarks for the chin, and the person mask
    /// above it for the hair.
    static func measure(_ image: CGImage, masker: SubjectMasker) -> (face: CGRect, chin: CGFloat, top: CGFloat)? {
        let request = VNDetectFaceLandmarksRequest()
        try? VNImageRequestHandler(cgImage: image).perform([request])
        guard let found = request.results?.max(by: { area($0.boundingBox) < area($1.boundingBox) }) else { return nil }
        let box = found.boundingBox   // bottom-left origin
        let face = CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height)
        var chin = face.maxY
        if let contour = found.landmarks?.faceContour?.normalizedPoints,
           let lowest = contour.map({ 1 - (box.minY + CGFloat($0.y) * box.height) }).max() {
            chin = max(chin, lowest)
        }
        var top = face.minY
        if let mask = masker.mask(of: image),
           let hair = SubjectMasker.topEdge(in: mask, left: face.minX, right: face.maxX, limit: face.minY) {
            top = min(top, hair)
        }
        return (face, chin, top)
    }

    /// The top and bottom of all the cards' ink together.
    private static func inkSpan(of document: CaptionDocument) -> (top: CGFloat, bottom: CGFloat)? {
        let inks = document.cards.compactMap { InkFit.inkRect(of: $0, in: document) }
        guard let top = inks.map(\.minY).min(), let bottom = inks.map(\.maxY).max() else { return nil }
        return (top, bottom)
    }

    private static func area(_ rect: CGRect) -> CGFloat { rect.width * rect.height }

    private static func median(_ values: [CGFloat]) -> CGFloat {
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }
}
