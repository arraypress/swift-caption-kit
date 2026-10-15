//
//  FillerHiding.swift
//  CaptionKit
//
//  Created by David Sherlock on 2026.
//
//  Filler words kept out of the captions without cutting them out of the
//  video: the "um" is still heard, it is just not written. The same filler
//  list and matching as FillerCutter, so hiding and cutting agree on what a
//  filler is.
//

import Foundation

public enum FillerHiding {

    /// `words` without the fillers in `fillers` (matched like
    /// ``FillerCutter``: lowercased, punctuation stripped), and the ones
    /// taken out. Timing of every kept word is untouched.
    public static func hidden(_ words: [Word], fillers: Set<String> = FillerCutRules().fillers) -> (kept: [Word], hidden: [Word]) {
        let keys = Set(fillers.map { $0.lowercased() })
        var kept: [Word] = []
        var hidden: [Word] = []
        for word in words {
            if keys.contains(word.matchKey) { hidden.append(word) } else { kept.append(word) }
        }
        return (kept, hidden)
    }
}
