//
//  Contrast+StyleColor.swift
//  CaptionKit
//
//  Created by David Sherlock on 2026.
//
//  WCAG contrast (Legibility's) for the colours a caption style is written in.
//

import Foundation
import Legibility

extension Contrast {

    /// The relative luminance of a style colour (alpha ignored).
    public static func luminance(_ color: StyleColor) -> Double {
        luminance(red: color.red, green: color.green, blue: color.blue)
    }
}
