//
//  ClipperTests.swift
//  CaptionKit
//
//  Where the cuts land. The export itself is AVFoundation's; the choice of
//  boundary is ours, and it is the part that ruins a clip when it is wrong.
//

import XCTest
@testable import CaptionKit

final class ClipperTests: XCTestCase {

    /// "one two three four five", a word per second with a 0.2 s gap.
    private let words: [Word] = (0..<5).map { index in
        Word(text: ["one", "two", "three", "four", "five"][index],
             start: Double(index) * 1.2,
             end: Double(index) * 1.2 + 1.0,
             confidence: 1)
    }

    // MARK: Snapping

    func testATimeInsideAWordMovesToTheNearestGap() {
        // 0.5 s is halfway through "one"; the gap after it runs 1.0–1.2.
        let snapped = Clipper.snap(0.5, to: words)
        XCTAssertEqual(snapped, 1.1, accuracy: 0.001)
    }

    func testATimeAlreadyInSilenceBarelyMoves() {
        XCTAssertEqual(Clipper.snap(1.1, to: words), 1.1, accuracy: 0.001)
    }

    func testNoWordsMeansNoMovement() {
        // An honest no-op beats inventing a boundary out of nothing.
        XCTAssertEqual(Clipper.snap(3.7, to: []), 3.7, accuracy: 0.001)
    }

    func testTheEdgesAreLeftAlone() {
        // Before the first word and after the last is already silence.
        XCTAssertEqual(Clipper.snap(0, to: words), 0, accuracy: 0.001)
        XCTAssertEqual(Clipper.snap(99, to: words), 99, accuracy: 0.001)
    }

    func testNoSnappedBoundaryFallsInsideAWord() {
        // The whole promise of the verb, asserted across the timeline.
        for step in stride(from: 0.0, through: 6.0, by: 0.05) {
            let snapped = Clipper.snap(step, to: words)
            for word in words where snapped > word.start && snapped < word.end {
                XCTFail(String(format: "%.2f snapped to %.2f, inside \"%@\"", step, snapped, word.text))
            }
        }
    }

    // MARK: Fixed intervals

    func testEveryCoversTheWholeTimelineWithoutGapsOrOverlaps() throws {
        let segments = Clipper.every(2, upTo: 6, words: words)
        XCTAssertFalse(segments.isEmpty)
        XCTAssertEqual(segments.first?.start, 0)
        XCTAssertEqual(try XCTUnwrap(segments.last).end, 6, accuracy: 0.001)
        for (a, b) in zip(segments, segments.dropFirst()) {
            XCTAssertEqual(a.end, b.start, accuracy: 0.001)
        }
    }

    func testTheFinalBoundaryIsTheEndOfTheFile() throws {
        // Snapping the last cut would drop the tail of the video.
        XCTAssertEqual(try XCTUnwrap(Clipper.every(2, upTo: 6, words: words).last).end, 6, accuracy: 0.001)
    }

    func testNonsenseIntervalsProduceNothing() {
        XCTAssertTrue(Clipper.every(0, upTo: 6, words: words).isEmpty)
        XCTAssertTrue(Clipper.every(2, upTo: 0, words: words).isEmpty)
    }

    // MARK: Phrases

    func testAPhraseIsFoundAcrossWordBoundaries() throws {
        let segment = try Clipper.around(phrase: "two three", length: 3, words: words, duration: 6)
        XCTAssertLessThanOrEqual(segment.start, 1.2)   // "two" starts here
        XCTAssertGreaterThanOrEqual(segment.end, 3.4)  // "three" ends here
    }

    func testMatchingIgnoresCaseAndPunctuation() throws {
        XCTAssertNoThrow(try Clipper.around(phrase: "Two, THREE!", length: 3, words: words, duration: 6))
    }

    func testTheHitAlwaysSurvivesTheSnapping() throws {
        // A clip of the wrong moment is the one failure this verb cannot have,
        // so snapping is never allowed to push a boundary past the match.
        let segment = try Clipper.around(phrase: "three", length: 0.5, words: words, duration: 6)
        XCTAssertLessThanOrEqual(segment.start, 2.4)
        XCTAssertGreaterThanOrEqual(segment.end, 3.4)
    }

    func testAMissingPhraseIsNamed() {
        XCTAssertThrowsError(try Clipper.around(phrase: "compressor", length: 3, words: words, duration: 6)) {
            guard case Clipper.ClipError.phraseNotFound = $0 else {
                return XCTFail("expected phraseNotFound, got \($0)")
            }
        }
    }

    func testAClipNearTheEndKeepsItsFullLength() throws {
        // Clamped at the tail, a naive centre-minus-half comes up short.
        let segment = try Clipper.around(phrase: "five", length: 3, words: words, duration: 6)
        XCTAssertEqual(segment.duration, 3, accuracy: 0.6)
        XCTAssertLessThanOrEqual(segment.end, 6.001)
    }
}
