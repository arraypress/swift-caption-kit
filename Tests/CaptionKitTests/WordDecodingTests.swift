//
//  WordDecodingTests.swift
//  CaptionKitTests
//
//  Created by David Sherlock on 2026.
//
//  A word list written by hand has text and times and nothing else. It used
//  to fail to decode because `confidence` was required.
//

import Foundation
import Testing
@testable import CaptionCore
import CaptionStyles

@Suite("Word decoding")
struct WordDecodingTests {

    private func words(_ json: String) throws -> [Word] {
        try JSONDecoder().decode([Word].self, from: Data(json.utf8))
    }

    @Test("A hand-written word without confidence is fully confident")
    func confidenceIsOptional() throws {
        let decoded = try words(#"[{"text": "Hello", "start": 0.5, "end": 0.9}, {"text": "there.", "start": 1, "end": 1.4}]"#)
        #expect(decoded == [Word(text: "Hello", start: 0.5, end: 0.9), Word(text: "there.", start: 1, end: 1.4)])
        #expect(decoded.allSatisfy { $0.confidence == 1 })
    }

    @Test("A recognised word keeps its confidence, style and speaker")
    func everythingRoundTrips() throws {
        var style = WordStyle()
        style.sizeMultiplier = 1.5
        var word = Word(text: "Hello", start: 0.5, end: 0.9, confidence: 0.42, style: style)
        word.speaker = 2
        let encoded = try JSONEncoder().encode([word])
        #expect(try JSONDecoder().decode([Word].self, from: encoded) == [word])
        let decoded = try words(#"[{"text": "Hi", "start": 0, "end": 1, "confidence": 0.3, "speaker": 1}]"#)
        #expect(decoded.first?.confidence == 0.3)
        #expect(decoded.first?.speaker == 1)
    }

    @Test("Text, start and end are still required", arguments: [
        (#"[{"start": 0, "end": 1}]"#, "text"),
        (#"[{"text": "Hi", "end": 1}]"#, "start"),
        (#"[{"text": "Hi", "start": 0}]"#, "end"),
    ])
    func requiredFields(_ pair: (String, String)) {
        #expect {
            try words(pair.0)
        } throws: { error in
            guard case DecodingError.keyNotFound(let key, _) = error else { return false }
            return key.stringValue == pair.1
        }
    }

    @Test("A confidence of the wrong type is refused, not defaulted")
    func wrongTypeIsRefused() {
        #expect(throws: DecodingError.self) {
            try words(#"[{"text": "Hi", "start": 0, "end": 1, "confidence": "high"}]"#)
        }
    }
}
