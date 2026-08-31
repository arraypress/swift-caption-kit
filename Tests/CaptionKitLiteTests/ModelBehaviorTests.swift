//
//  ModelBehaviorTests.swift
//  CaptionKitLiteTests
//
//  Created by David Sherlock on 2026.
//
//  The hex rule that used to live inside StyleColor, pinned directly.
//

import Testing
@testable import CaptionKitLite

@Suite("Model behavior extracted")
struct ModelBehaviorTests {

    @Test("Hex parsing pins exact components")
    func hexParsing() {
        let gold = StyleColorHex.components("#FFD60A")
        #expect(gold != nil && abs(gold!.green - 0.84) < 0.01)
        let alpha = StyleColorHex.components("00000080")
        #expect(alpha != nil && abs(alpha!.alpha - 128.0 / 255.0) < 0.001)
        #expect(StyleColorHex.components("nope") == nil)
        #expect(StyleColor(hex: "#FF0000") == StyleColor(red: 1, green: 0, blue: 0))
    }
}
