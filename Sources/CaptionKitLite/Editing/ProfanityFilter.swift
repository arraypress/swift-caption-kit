//
//  ProfanityFilter.swift
//  CaptionKitLite
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Deterministic, fully-offline profanity detection.
///
/// Deliberately a plain word-list match rather than an on-device LLM: it's
/// instant, it's predictable, and it sidesteps the model guardrails that
/// refuse to even process profane text. Matching is whole-word only (against a
/// word's punctuation-stripped ``Word/matchKey``), never substring — so
/// "Scunthorpe", "classic", and "assess" are safe. Anything the list misses
/// can be force-censored per word via ``WordStyle/censored``.
public enum ProfanityFilter {

    /// The built-in English list. Whole words plus their common inflections,
    /// since matching is exact (no stemming). Conservative on purpose.
    public static let defaultList: Set<String> = [
        "fuck", "fucks", "fucked", "fucking", "fucker", "fuckers", "fuckin",
        "motherfucker", "motherfuckers", "motherfucking", "clusterfuck",
        "shit", "shits", "shitty", "shitting", "shithole", "shithead", "bullshit",
        "bitch", "bitches", "bitching", "bitchy",
        "asshole", "assholes", "dumbass", "jackass", "smartass",
        "bastard", "bastards",
        "dick", "dicks", "dickhead", "dickheads",
        "piss", "pissed", "pissing",
        "cock", "cocks",
        "cunt", "cunts",
        "whore", "whores", "slut", "sluts", "slutty",
        "goddamn", "goddamnit", "dammit", "damnit",
        "prick", "pricks", "twat", "wanker", "bollocks", "bugger",
        "douche", "douchebag",
        "nigger", "nigga", "niggers", "niggas",
        "faggot", "faggots", "fag", "fags", "retard", "retarded",
    ]

    /// Whether this word is on the profanity list.
    public static func isProfane(_ word: Word, list: Set<String> = defaultList) -> Bool {
        let key = word.matchKey
        return !key.isEmpty && list.contains(key)
    }

    /// The effective censor decision for a word, folding the per-word tri-state
    /// override over the document-wide auto-censor toggle:
    /// - ``WordStyle/censored`` `== true`  → always censor,
    /// - ``WordStyle/censored`` `== false` → never censor (protects false hits),
    /// - `nil` → censor only when `autoCensor` is on and the word is profane.
    public static func shouldCensor(
        _ word: Word,
        autoCensor: Bool,
        list: Set<String> = defaultList
    ) -> Bool {
        if let forced = word.style?.censored { return forced }
        return autoCensor && isProfane(word, list: list)
    }
}
