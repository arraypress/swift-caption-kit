//
//  CutStyle.swift
//  CaptionKit
//
//  Created by David Sherlock on 2026.
//
//  How a removed range looks at the seam.
//

import Foundation

/// The treatment applied where a ``Cut`` removed footage.
///
/// Filler removal and silence trimming leave seams, and an untreated seam
/// reads as a fault: the picture jumps, and a viewer assumes the file is
/// broken rather than that an editor made a choice. A brief dip or a small
/// punch-in is what turns the same cut into something deliberate — which is
/// why this is here rather than filed under styling.
///
/// Two kinds of treatment sit behind one enum. ``dipToBlack``, ``dipToWhite``
/// and ``punchIn`` are geometry and compositing the exporter computes itself.
/// ``whipPan``, ``zoomBlur`` and ``glitch`` run through Core Image — see
/// ``CutTransition`` — which is why ``CutTransition/needsCoreImage(_:)``
/// exists: most frames of most exports need neither, and building a filter
/// chain for them would be work thrown away.
public enum CutStyle: String, Codable, CaseIterable, Sendable {

    /// A plain jump cut, with no treatment at the seam.
    case none

    /// A quick dip through black across the cut.
    case dipToBlack

    /// A quick dip through white across the cut.
    case dipToWhite

    /// A subtle zoom punch-in that relaxes after the cut.
    case punchIn

    /// A horizontal motion-blur streak across the cut.
    case whipPan

    /// A radial zoom-blur burst across the cut.
    case zoomBlur

    /// An RGB channel-split glitch across the cut.
    case glitch
}
