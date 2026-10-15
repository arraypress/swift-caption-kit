//
//  PreservationTests.swift
//  CaptionKitTests
//
//  Created by David Sherlock on 2026.
//

import CoreImage
import Foundation
import Testing
@testable import CaptionKit

@Suite("Unmodelled fields")
struct PreservationTests {

    /// A project as the retired editor engine wrote it: modelled keys, plus the ones
    /// this engine has no types for.
    private var richDocument: Data {
        Data("""
        {
          "voiceVolume": 1,
          "cards": [],
          "stickers": [{"id":"A1","emoji":"🔥","start":1.0,"end":2.0}],
          "music": {"url":"file:///bed.m4a","volume":0.4,"duckUnderVoice":true},
          "grade": {"exposure":0.2,"contrast":1.1,"lut":"teal-orange.cube"},
          "soundEffects": [{"kind":"whoosh","time":0.5}],
          "appendedClips": [{"url":"file:///outro.mov","duration":3.0}],
          "faceBeauty": {"smoothing":0.3},
          "somethingFromAFutureBuild": {"nested":[1,2,3],"flag":true,"name":"x"}
        }
        """.utf8)
    }

    // MARK: Round-tripping

    @Test("A field this engine cannot model survives a load and save")
    func keepsUnmodelledFields() throws {
        // The failure this prevents: a project styled in the editor is batch
        // rendered here, and comes back stripped of the stickers, music and
        // grade somebody spent an afternoon on.
        let document = try JSONDecoder().decode(CaptionDocument.self, from: richDocument)
        let written = try JSONEncoder().encode(document)
        let json = try #require(
            try JSONSerialization.jsonObject(with: written) as? [String: Any]
        )

        for key in ["stickers", "music", "grade", "soundEffects", "appendedClips", "faceBeauty"] {
            #expect(json[key] != nil, "\(key) was dropped")
        }
    }

    @Test("Values inside a preserved field survive intact, not just the key")
    func keepsNestedValues() throws {
        let document = try JSONDecoder().decode(CaptionDocument.self, from: richDocument)
        let written = try JSONEncoder().encode(document)
        let json = try JSONSerialization.jsonObject(with: written) as? [String: Any]

        let grade = try #require(json?["grade"] as? [String: Any])
        #expect(grade["lut"] as? String == "teal-orange.cube")
        #expect(grade["contrast"] as? Double == 1.1)

        let future = try #require(json?["somethingFromAFutureBuild"] as? [String: Any])
        #expect(future["flag"] as? Bool == true)
        #expect(future["nested"] as? [Double] == [1, 2, 3])
    }

    @Test("A key added by a newer build survives too")
    func keepsFutureKeys() throws {
        // The more valuable half: this engine does not need to know what the
        // key means to hand it back.
        let document = try JSONDecoder().decode(CaptionDocument.self, from: richDocument)
        #expect(document.preserved["somethingFromAFutureBuild"] != nil)
    }

    // MARK: Boundaries

    @Test("Modelled keys are not also captured as preserved")
    func doesNotDuplicateModelledKeys() throws {
        let document = try JSONDecoder().decode(CaptionDocument.self, from: richDocument)
        // Duplicates would be written twice and could shadow the real value.
        for key in ["cards", "voiceVolume", "style", "cuts", "renderConfig"] {
            #expect(document.preserved[key] == nil, "\(key) is modelled and must not be preserved")
        }
    }

    @Test("A document with nothing unmodelled preserves nothing")
    func emptyWhenFullyModelled() throws {
        let document = CaptionDocument(cards: [])
        let written = try JSONEncoder().encode(document)
        let reread = try JSONDecoder().decode(CaptionDocument.self, from: written)
        #expect(reread.preserved.isEmpty)
    }

    @Test("Saving twice produces the same bytes")
    func encodingIsStable() throws {
        // Through the documented API, which sorts keys — a raw JSONEncoder
        // orders a keyed container however it likes, and that is its right.
        let document = try CaptionDocument.deserialize(from: richDocument)
        #expect(try document.serialized() == document.serialized())
    }

    @Test("A second round-trip changes nothing further")
    func roundTripIsIdempotent() throws {
        let once = try CaptionDocument.deserialize(from: richDocument)
        let written = try once.serialized()
        let twice = try CaptionDocument.deserialize(from: written)
        #expect(try twice.serialized() == written)
        #expect(twice.preserved == once.preserved)
    }

    @Test("Editing a caption leaves the unmodelled fields alone")
    func editingDoesNotDisturbThem() throws {
        var document = try JSONDecoder().decode(CaptionDocument.self, from: richDocument)
        let before = document.preserved

        document.style.highlightMode = .karaoke
        document.cards = CaptionGrouper.group(
            [Word(text: "hello", start: 0, end: 0.4)],
            rules: GroupingRules()
        )

        #expect(document.preserved == before)
    }

    // MARK: Tolerance

    @Test("An unmodelled key holding null is still carried")
    func keepsNull() throws {
        let data = Data(#"{"cards":[],"mystery":null}"#.utf8)
        let document = try JSONDecoder().decode(CaptionDocument.self, from: data)
        #expect(document.preserved["mystery"] == PreservedValue.null)
    }

    @Test("A malformed document still opens")
    func toleratesJunk() throws {
        // Refusing to open a project because one unreadable field exists is a
        // worse failure than losing that field.
        let data = Data(#"{"cards":[],"odd":[1,"two",{"three":3},null,true]}"#.utf8)
        let document = try JSONDecoder().decode(CaptionDocument.self, from: data)
        #expect(document.preserved["odd"] != nil)
    }
}

@Suite("Cut treatments")
struct CutStyleTests {

    @Test("Cut treatments round-trip", arguments: CutStyle.allCases)
    func roundTrips(_ style: CutStyle) throws {
        let data = try JSONEncoder().encode(style)
        #expect(try JSONDecoder().decode(CutStyle.self, from: data) == style)
    }

    @Test("A document keeps its cut treatment across a save")
    func survivesDocumentRoundTrip() throws {
        var document = CaptionDocument(cards: [])
        document.cutStyle = .punchIn
        let data = try JSONEncoder().encode(document)
        #expect(try JSONDecoder().decode(CaptionDocument.self, from: data).cutStyle == .punchIn)
    }
}

@Suite("Track switches")
struct TrackKindTests {

    @Test("A project that disables a layer this engine lacks still opens")
    func decodesForeignTracks() throws {
        // The reason TrackKind keeps cases for content this engine cannot
        // draw: disabledTracks decodes as a Set<TrackKind>, so a missing case
        // fails the whole document rather than one field.
        let data = Data(#"{"cards":[],"disabledTracks":["stickers","broll","soundEffects"]}"#.utf8)
        let document = try CaptionDocument.deserialize(from: data)

        #expect(document.disabledTracks?.contains(.stickers) == true)
        #expect(document.trackEnabled(.captions), "captions were never disabled")
    }

    @Test("Disabling captions is honoured")
    func honoursCaptionSwitch() throws {
        var document = CaptionDocument(cards: [])
        document.disabledTracks = [.captions]
        #expect(!document.trackEnabled(.captions))
    }
}

@Suite("Export bitrate")
struct ExportQualityTests {

    /// Vertical social canvases at the frame rate phones shoot.
    private static let canvases = [(720, 1280), (1080, 1920), (2160, 3840)]

    @Test("Bitrate scales with the picture, not a fixed guess")
    func scalesWithResolution() {
        // The bug this replaces: one fixed 12 Mbps produced a 21 MB file for
        // fifteen seconds of 720×1280.
        let settings = ExportSettings()
        let rates = Self.canvases.map {
            settings.resolvedBitRate(width: $0.0, height: $0.1, frameRate: 30)
        }
        #expect(rates == rates.sorted(), "a bigger canvas must not get less bitrate")
        #expect(rates[0] < rates[1], "720p must cost less than 1080p")
        #expect(rates[2] > rates[1] * 3, "4K is four times the pixels")
    }

    @Test("720×1280 lands in a sane range")
    func sensibleAt720() {
        let rate = ExportSettings().resolvedBitRate(width: 720, height: 1280, frameRate: 30)
        // Comfortably clean for a talking head, and a fraction of the old fixed
        // default — roughly 5 MB for fifteen seconds rather than 21.
        #expect(rate > 2_000_000)
        #expect(rate < 4_000_000)
    }

    @Test("Higher tiers spend more", arguments: [
        (ExportSettings.Quality.draft, ExportSettings.Quality.small),
        (.small, .balanced), (.balanced, .high), (.high, .maximum),
    ])
    func tiersAreOrdered(_ pair: (ExportSettings.Quality, ExportSettings.Quality)) {
        func rate(_ quality: ExportSettings.Quality) -> Int {
            ExportSettings(quality: quality).resolvedBitRate(width: 1080, height: 1920, frameRate: 30)
        }
        #expect(rate(pair.0) < rate(pair.1))
    }

    @Test("H.264 is given more bitrate than HEVC for the same picture")
    func codecAdjustment() {
        let hevc = ExportSettings(codec: .hevc).resolvedBitRate(width: 1080, height: 1920, frameRate: 30)
        let h264 = ExportSettings(codec: .h264).resolvedBitRate(width: 1080, height: 1920, frameRate: 30)
        #expect(h264 > hevc)
    }

    @Test("Frame rate counts too")
    func scalesWithFrameRate() {
        let settings = ExportSettings()
        let thirty = settings.resolvedBitRate(width: 1080, height: 1920, frameRate: 30)
        let sixty = settings.resolvedBitRate(width: 1080, height: 1920, frameRate: 60)
        #expect(sixty > thirty)
    }

    @Test("An explicit bitrate wins outright")
    func explicitOverrides() {
        let settings = ExportSettings(quality: .draft, averageBitRate: 9_000_000)
        #expect(settings.resolvedBitRate(width: 720, height: 1280, frameRate: 30) == 9_000_000)
    }

    @Test("A tiny canvas still gets enough bitrate to avoid blocking")
    func hasAFloor() {
        // Captions are hard edges over flat colour and show compression before
        // the footage does.
        let rate = ExportSettings(quality: .draft).resolvedBitRate(width: 64, height: 64, frameRate: 24)
        #expect(rate >= 600_000)
    }
}

@Suite("Cut transitions")
struct CutTransitionTests {

    private let image = CIImage(color: .gray).cropped(to: CGRect(x: 0, y: 0, width: 320, height: 568))

    @Test("All seven treatments are offered")
    func offersSeven() {
        #expect(CutStyle.allCases.count == 7)
        #expect(Set(CutStyle.allCases.map(\.rawValue)) == [
            "none", "dipToBlack", "dipToWhite", "punchIn", "whipPan", "zoomBlur", "glitch",
        ])
    }

    @Test("Only the pixel treatments ask for Core Image", arguments: CutStyle.allCases)
    func classifiesCorrectly(_ style: CutStyle) {
        // Dip and punch are geometry the exporter already computes; building a
        // filter chain for them would be work thrown away on every frame.
        let expected: Bool = switch style {
        case .whipPan, .zoomBlur, .glitch: true
        case .none, .dipToBlack, .dipToWhite, .punchIn: false
        }
        #expect(CutTransition.needsCoreImage(style) == expected)
    }

    @Test("The envelope peaks on the boundary and falls away")
    func envelopeShape() {
        let boundaries = [5.0]
        #expect(CutTransition.strength(at: 5.0, boundaries: boundaries) == 1)
        #expect(CutTransition.strength(at: 5.0, boundaries: boundaries) > CutTransition.strength(at: 5.08, boundaries: boundaries))
        #expect(CutTransition.strength(at: 9.0, boundaries: boundaries) == 0)
        #expect(CutTransition.strength(at: 0, boundaries: []) == 0)
    }

    @Test("The envelope never leaves 0…1")
    func envelopeIsClamped() {
        for time in stride(from: 0.0, through: 10.0, by: 0.25) {
            let value = CutTransition.strength(at: time, boundaries: [2, 5, 8])
            #expect(value >= 0 && value <= 1)
        }
    }

    @Test("A frame nowhere near a cut is returned untouched", arguments: CutStyle.allCases)
    func zeroStrengthIsIdentity(_ style: CutStyle) {
        // Most frames of any export are this case.
        #expect(CutTransition.apply(style: style, strength: 0, to: image) == image)
    }

    @Test("A geometry treatment is a no-op here", arguments: [
        CutStyle.none, .dipToBlack, .dipToWhite, .punchIn,
    ])
    func geometryStylesUnchanged(_ style: CutStyle) {
        #expect(CutTransition.apply(style: style, strength: 1, to: image) == image)
    }

    @Test("Each pixel treatment changes the frame", arguments: [
        CutStyle.whipPan, .zoomBlur, .glitch,
    ])
    func pixelStylesTransform(_ style: CutStyle) {
        #expect(CutTransition.apply(style: style, strength: 1, to: image) != image)
    }

    @Test("The frame keeps its size", arguments: [CutStyle.whipPan, .zoomBlur, .glitch])
    func extentSurvives(_ style: CutStyle) {
        // A blur samples past the edges, and an image that grew would shift
        // everything drawn after it.
        let result = CutTransition.apply(style: style, strength: 1, to: image)
        #expect(result.extent == image.extent)
    }

    @Test("The glitch keeps alpha intact")
    func glitchDoesNotWashOut() throws {
        // Additive compositing would sum three alphas to 3 and wash out every
        // stage drawn afterwards; a per-channel maximum recombines exactly.
        let opaque = CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1))
            .cropped(to: CGRect(x: 0, y: 0, width: 64, height: 64))
        let glitched = CutTransition.apply(style: .glitch, strength: 1, to: opaque)

        let context = CIContext()
        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(
            glitched,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 32, y: 32, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        #expect(pixel[3] == 255, "alpha must stay opaque")
    }
}
