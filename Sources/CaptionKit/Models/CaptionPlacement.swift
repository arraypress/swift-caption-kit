//
//  CaptionPlacement.swift
//  CaptionKit
//
//  Created by David Sherlock on 2026.
//

import CoreGraphics
import Foundation

/// Where the speaker's head sits on the canvas: medians over sampled frames,
/// normalized `0…1` with a top-left origin.
public struct SpeakerHead: Codable, Equatable, Sendable {
    /// The top of the head — the hair, where the person mask reaches above
    /// the face box.
    public var top: CGFloat
    /// The face box: brow to chin, ear to ear.
    public var face: CGRect
    /// The chin: the lower of Vision's face box and its face-contour
    /// landmarks. The box alone stops short of the chin.
    public var chin: CGFloat
    /// How many sampled frames had a face.
    public var frames: Int

    public init(top: CGFloat, face: CGRect, chin: CGFloat, frames: Int) {
        self.top = top
        self.face = face
        self.chin = chin
        self.frames = frames
    }

    /// The face from brow to the chin landmarks — what a caption must not
    /// cover.
    public var faceToChin: CGRect {
        CGRect(x: face.minX, y: face.minY, width: face.width, height: max(face.height, chin - face.minY))
    }
}

/// Where the captions went relative to the speaker, and what was measured.
public struct CaptionPlacement: Codable, Equatable, Sendable {

    /// Which side of the face the captions sit on.
    public enum Side: String, Codable, Sendable {
        /// Below the chin.
        case below
        /// Above the head.
        case above
        /// Neither side had room inside the safe area: on the face, as little
        /// of it as the safe area allows.
        case over
    }

    public var side: Side
    /// The vertical position given to the captions (the block's centre).
    public var position: CGFloat
    /// The head the captions keep clear of.
    public var head: SpeakerHead
    /// The rectangle the captions had to stay inside.
    public var safe: CGRect
    /// The largest share (`0…1`) of the face any card's ink covers, measured
    /// on the drawn pixels after placing.
    public var faceOverlap: Double

    public init(side: Side, position: CGFloat, head: SpeakerHead, safe: CGRect, faceOverlap: Double) {
        self.side = side
        self.position = position
        self.head = head
        self.safe = safe
        self.faceOverlap = faceOverlap
    }
}
