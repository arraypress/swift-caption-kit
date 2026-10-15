//
//  StylePreset+Style.swift
//  CaptionStyles
//
//  Created by David Sherlock on 2026.
//

import Foundation
import RecipeKit

public extension StylePreset {

    /// Its slots as RecipeKit's, for `--var` and listings.
    var styleSlots: [StyleSlot] { PresetCatalog.slots(of: self) }

    /// On the curated shelf.
    var isFeatured: Bool { featured == true }

    /// The style it makes with these `--var` values; slots not given take their defaults.
    func style(vars: [String: String] = [:]) throws(StyleError) -> CaptionStyle {
        try PresetCatalog.style(of: self, values: vars)
    }
}
