//
//  HookTemplates.swift
//  CaptionKit
//
//  Created by David Sherlock on 2026.
//
//  The built-in hook-title looks: read once from ``HookTemplateCatalogText``,
//  checked, and turned into styles.
//

import Foundation

public enum HookTemplates {

    /// What a parse found, and every problem in it.
    public struct Result: Sendable {
        public var templates: [HookTemplate] = []
        public var problems: [String] = []
    }

    /// The templates in `text`, with every problem found.
    public static func parse(_ text: String) -> Result {
        guard let templates = try? JSONDecoder().decode([HookTemplate].self, from: Data(text.utf8)) else {
            return Result(problems: ["the hook template catalogue is not a list of {name, summary, style}"])
        }
        var result = Result(templates: templates)
        var seen = Set<String>()
        for template in templates {
            let name = template.name
            if name.isEmpty || !name.allSatisfy({ ($0.isLetter && $0.isLowercase) || $0.isNumber || $0 == "-" }) {
                result.problems.append("\(name): not a kebab-case name")
            }
            if !seen.insert(name).inserted { result.problems.append("\(name): listed twice") }
            result.problems += StyleSchema.unknownKeys(in: template.style).map { "\(name): \($0) is not a style field" }
            do { _ = try StyleJSON.style(from: template.style, path: "hook.\(name)") } catch {
                result.problems.append("\(name): \(error.errorDescription ?? "does not decode")")
            }
        }
        return result
    }

    static let parsed = parse(HookTemplateCatalogText.templates)

    /// Every built-in template, in catalogue order.
    public static var all: [HookTemplate] { parsed.templates }

    /// The problems in the built-in catalogue — none, or a test fails.
    public static var problems: [String] { parsed.problems }

    /// The template's name used when none is asked for.
    public static let defaultName = "bold"

    /// The template called `name` (case-insensitive), or `nil`.
    public static func named(_ name: String) -> HookTemplate? {
        all.first { $0.name == name.lowercased() }
    }

    /// The style `template` describes.
    public static func style(of template: HookTemplate) -> CaptionStyle {
        (try? StyleJSON.style(from: template.style, path: "hook.\(template.name)")) ?? CaptionStyle()
    }
}
