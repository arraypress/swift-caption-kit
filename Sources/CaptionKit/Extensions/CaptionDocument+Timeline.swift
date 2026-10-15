//
//  CaptionDocument+Timeline.swift
//  CaptionKit
//
//  Created by David Sherlock on 2026.
//

import CaptionCore
import CoreGraphics
import Foundation

/// Lets the shared subtitle and overlay writers read this engine's document
/// and draw it with this engine's renderer.
extension CaptionDocument: CaptionTimeline {

    public func drawCaptions(in context: CGContext, at sourceTime: TimeInterval) {
        CaptionRenderer.draw(document: self, in: context, at: sourceTime)
    }
}
