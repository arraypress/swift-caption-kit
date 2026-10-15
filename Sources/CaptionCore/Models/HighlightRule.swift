//
//  HighlightRule.swift
//  CaptionCore
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A keyword-based highlight: listed words are always drawn in ``color``,
/// regardless of whether they are currently being spoken.
///
/// Matching is case-insensitive and ignores attached punctuation, so a rule
/// for `"money"` matches the spoken word `"Money,"`.
///
/// ```swift
/// document.highlightRules = [
///     HighlightRule(keywords: ["free", "secret", "money"], color: .green)
/// ]
/// ```
public struct HighlightRule: Codable, Equatable, Identifiable, Sendable {

    /// A stable identity for editing.
    public var id: UUID

    /// The words this rule matches (case- and punctuation-insensitive).
    public var keywords: [String]

    /// The color applied to matching words.
    public var color: StyleColor

    /// Extra scale applied to matching words (`1` = none).
    public var scale: CGFloat

    /// Creates a keyword highlight rule.
    public init(id: UUID = UUID(), keywords: [String], color: StyleColor, scale: CGFloat = 1) {
        self.id = id
        self.keywords = keywords
        self.color = color
        self.scale = scale
    }

    /// Whether this rule matches the given word.
    public func matches(_ word: Word) -> Bool {
        let key = word.matchKey
        return keywords.contains { $0.lowercased() == key }
    }
}
