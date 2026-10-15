//
//  EmojiCatalog.swift
//  CaptionKit
//
//  Created by David Sherlock on 2026.
//
//  The keyword → emoji table, read once from ``EmojiCatalogText`` and checked.
//

import Foundation

public enum EmojiCatalog {

    /// One emoji and the words that call for it.
    public struct Entry: Codable, Equatable, Sendable {
        public var emoji: String
        public var words: [String]

        public init(emoji: String, words: [String]) {
            self.emoji = emoji
            self.words = words
        }
    }

    /// What a parse found, and every problem in it.
    public struct Result: Sendable {
        public var entries: [Entry] = []
        public var problems: [String] = []
    }

    /// The entries in `text`, with every problem found: an emoji that is not
    /// one character, a word that is not lowercase letters, a word listed twice.
    public static func parse(_ text: String) -> Result {
        guard let entries = try? JSONDecoder().decode([Entry].self, from: Data(text.utf8)) else {
            return Result(problems: ["the emoji catalogue is not a list of {emoji, words}"])
        }
        var result = Result(entries: entries)
        var seen: [String: String] = [:]
        for entry in entries {
            if entry.emoji.count != 1 || !entry.emoji.unicodeScalars.contains(where: \.properties.isEmoji) {
                result.problems.append("\(entry.emoji): not one emoji")
            }
            for word in entry.words {
                if word.isEmpty || !word.allSatisfy({ $0.isLetter && $0.isLowercase }) {
                    result.problems.append("\(entry.emoji): \"\(word)\" is not lowercase letters")
                }
                if let earlier = seen[word] {
                    result.problems.append("\"\(word)\" is listed for both \(earlier) and \(entry.emoji)")
                }
                seen[word] = entry.emoji
            }
        }
        return result
    }

    static let parsed = parse(EmojiCatalogText.entries)

    /// The built-in keyword → emoji map.
    public static let map: [String: String] = parsed.entries.reduce(into: [:]) { map, entry in
        for word in entry.words where map[word] == nil { map[word] = entry.emoji }
    }

    /// The problems in the built-in catalogue — none, or a test fails.
    public static var problems: [String] { parsed.problems }

    /// The emoji `key` (a ``Word/matchKey``) calls for in `map`, forgiving a
    /// plural `s` on a word of four letters or more.
    public static func emoji(for key: String, in map: [String: String] = map) -> String? {
        if let emoji = map[key] { return emoji }
        if key.count >= 4, key.hasSuffix("s") { return map[String(key.dropLast())] }
        return nil
    }
}
