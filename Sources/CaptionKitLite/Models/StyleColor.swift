//
//  StyleColor.swift
//  CaptionKitLite
//
//  Created by David Sherlock on 2026.
//

import CoreGraphics
import Foundation

/// A platform-neutral, serializable sRGB color.
///
/// `CaptionKit` cannot use `NSColor`/`UIColor` (the library is headless and
/// cross-platform) and `CGColor` is not `Codable`, so styles store colors as
/// plain sRGB components and resolve to `CGColor` at draw time.
///
/// ```swift
/// let yellow = StyleColor(hex: "#FFD60A")
/// style.textColor = .white
/// ```
public struct StyleColor: Codable, Equatable, Hashable, Sendable {

    /// Red component (`0…1`, sRGB).
    public var red: Double

    /// Green component (`0…1`, sRGB).
    public var green: Double

    /// Blue component (`0…1`, sRGB).
    public var blue: Double

    /// Alpha component (`0…1`).
    public var alpha: Double

    /// Creates a color from sRGB components (`0…1`).
    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// Creates a color from a hex string like `"#FFD60A"`, `"FFD60A"`, or
    /// `"#FFD60AFF"` (with alpha). Returns `nil` for malformed input.
    public init?(hex: String) {
        guard let c = StyleColorHex.components(hex) else { return nil }
        self.init(red: c.red, green: c.green, blue: c.blue, alpha: c.alpha)
    }

    /// The same color with a different alpha.
    public func withAlpha(_ alpha: Double) -> StyleColor {
        StyleColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    /// Resolves to a `CGColor` in the sRGB color space.
    public var cgColor: CGColor {
        CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }

    // MARK: - Presets

    public static let white = StyleColor(red: 1, green: 1, blue: 1)
    public static let black = StyleColor(red: 0, green: 0, blue: 0)
    public static let clear = StyleColor(red: 0, green: 0, blue: 0, alpha: 0)

    /// The classic caption-highlight yellow.
    public static let yellow = StyleColor(red: 1, green: 0.84, blue: 0.04)

    public static let green = StyleColor(red: 0.20, green: 0.84, blue: 0.29)
    public static let red = StyleColor(red: 1, green: 0.23, blue: 0.19)
    public static let blue = StyleColor(red: 0.04, green: 0.52, blue: 1)
    public static let purple = StyleColor(red: 0.75, green: 0.35, blue: 0.95)
    public static let orange = StyleColor(red: 1, green: 0.58, blue: 0)
    public static let pink = StyleColor(red: 1, green: 0.18, blue: 0.57)
}
