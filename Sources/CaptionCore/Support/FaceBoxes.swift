//
//  FaceBoxes.swift
//  CaptionCore
//
//  Created by David Sherlock on 2026.
//
//  Faces in a frame, the one way every caption feature finds them: Vision's
//  face rectangles, in the order Vision returns them. Placement, tracking,
//  the two-face split and the checks all read the same boxes.
//
//  Async callers find them on a dispatch queue (Legibility's
//  `VisionQueue`), never on a Swift concurrency thread: Vision blocks while
//  it works, and blocked threads in the cooperative pool starve every other
//  task in the process.
//

import CoreGraphics
import Foundation
import Legibility
import Vision

public enum FaceBoxes {

    /// Every face in `image`: Vision's boxes, normalized `0…1` with a
    /// bottom-left origin, found on the calling thread.
    public static func detect(in image: CGImage) -> [CGRect] {
        let request = VNDetectFaceRectanglesRequest()
        try? VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? []).map(\.boundingBox)
    }

    /// ``detect(in:)`` for each of `images`, off the cooperative pool.
    public static func find(in images: [CGImage]) async -> [[CGRect]] {
        await VisionQueue.run { images.map(detect(in:)) }
    }

    /// ``detect(in:)`` for one picture, off the cooperative pool.
    public static func find(in image: CGImage) async -> [CGRect] {
        await VisionQueue.run { detect(in: image) }
    }
}
