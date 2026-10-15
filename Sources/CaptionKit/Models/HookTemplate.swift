//
//  HookTemplate.swift
//  CaptionKit
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A named look for a hook title: a partial ``CaptionStyle`` (only what
/// differs from the defaults), read from ``HookTemplateCatalogText``.
public struct HookTemplate: Codable, Equatable, Sendable {

    /// Kebab-case name: `bold`, `boxed`, `clean`.
    public var name: String

    /// One line on what it looks like.
    public var summary: String

    /// The style fields that differ from `CaptionStyle()`, as JSON.
    public var style: [String: JSONValue]

    public init(name: String, summary: String, style: [String: JSONValue]) {
        self.name = name
        self.summary = summary
        self.style = style
    }
}
