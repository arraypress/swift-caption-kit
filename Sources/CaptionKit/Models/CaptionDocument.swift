//
//  CaptionDocument.swift
//  CaptionKit
//
//  Created by David Sherlock on 2026.
//

import DepthBlur
import Foundation

/// The editable project: one video, one caption track, one global style.
///
/// This is what the user edits, what serializes to disk as the project file,
/// and what the renderer consumes (together with a time) to produce a frame.
///
/// ```swift
/// var document = CaptionDocument(videoURL: url, cards: cards)
/// document.style.highlightMode = .karaoke
/// let data = try document.serialized()
/// ```
public struct CaptionDocument: Codable, Equatable, Sendable {

    /// Keys from the retired editor engine's document that this one does not
    /// model — stickers, B-roll, music, the grade — carried through a load
    /// and save untouched.
    ///
    /// Never read and never rendered here. It exists so that a project styled
    /// in the editor survives a batch render: without it, re-encoding would
    /// write back only the properties this type declares and quietly strip
    /// everything else. See ``PreservedValue``.
    public var preserved: [String: PreservedValue] = [:]

    /// The source video. Optional so documents can be built and tested
    /// headless, without any media on disk.
    public var videoURL: URL?

    /// The caption cards in chronological order.
    public var cards: [CaptionCard]

    /// The global style; cards may override it individually.
    public var style: CaptionStyle

    /// Keyword highlight rules, applied on top of the style.
    public var highlightRules: [HighlightRule]

    /// Gain applied to the video's own voice/audio track on export
    /// (`0…2`, `1` = untouched).
    public var voiceVolume: Double

    /// How cut boundaries look on export (dip, punch-in…).
    public var cutStyle: CutStyle

    /// The source video's duration, set at import — used by overlays that
    /// need it (the progress bar).
    public var videoDuration: TimeInterval?

    /// A color-wash gradient over the footage (under captions). `nil` = off.
    public var gradientOverlay: GradientOverlay?

    /// An animated progress bar overlay, or `nil` for none.
    public var progressBar: ProgressBarStyle?

    /// Which part of the source shows when it's cropped into the canvas
    /// (aspect-fill reframe): `0…1` per axis, top-left semantics, `nil` =
    /// centered. Only matters when the source overflows the canvas — e.g. a
    /// landscape source in a 9:16 reel.
    public var cropOffset: NormalizedPoint?

    /// Automatic camera motion (breathing zoom + emphasis punch-ins), or
    /// `nil` for a static frame.
    public var autoMotion: AutoMotionStyle?

    /// Per-speaker caption colors (index = speaker id from diarization), or
    /// `nil` to color all speakers alike.
    public var speakerColors: [StyleColor]?

    /// Speakers' names for styles that show them (index = speaker id from
    /// diarization), or `nil` for "Speaker 1", "Speaker 2", ….
    public var speakerNames: [String]?

    /// A second transcript drawn small above each caption by styles with a
    /// ``CaptionStyle/secondaryLine`` (the bilingual look): a card shows the
    /// words whose midpoint falls in its span. `nil` = none.
    public var secondaryWords: [Word]?

    /// Gaussian-blur the background behind the person (reference points at
    /// a 1920-tall frame), or `nil` for none. On-device person segmentation.
    public var backgroundBlur: Double?

    /// Shifts caption timing relative to the audio, in seconds. Negative
    /// shows captions slightly EARLY (~-0.1s) — the editor trick that makes
    /// them feel snappier. Applies only to captions; the audio and the
    /// cuts are untouched.
    public var captionTimingOffset: TimeInterval = 0

    /// Detected beats, in seconds on the output timeline —
    /// Auto Motion punch-ins land on these when set. `nil` = no beat sync.
    public var beatTimes: [TimeInterval]?

    /// Face-tracked crop path (source time): when set, the aspect-fill
    /// reframe follows these instead of the static ``cropOffset`` — the
    /// speaker stays in frame at every export aspect.
    public var cropKeyframes: [CropKeyframe]?

    /// Privacy cover over the face (blur / pixelate / emoji), tracked. `nil`
    /// = off.
    public var faceCensor: FaceCensor?

    /// Depth-based cinematic background blur. `nil` = off. The model isn't in
    /// the document — the host supplies the ``DepthBlur`` estimator.
    public var depthBlur: DepthBlur?

    /// Mirror the footage horizontally (the video only — captions are left
    /// alone, so text stays readable). `false` = untouched.
    public var mirrorHorizontal: Bool = false

    /// Cinematic letterbox: the target aspect ratio (width/height, e.g. `2.39`)
    /// the visible area is masked to with black bars. `nil` = no bars.
    public var letterbox: Double?

    /// A solid colored frame around the whole video edge (`nil` = none).
    public var videoBorder: BorderStyle?

    /// Source ranges removed on export (filler words, dead air). Words keep
    /// their source timestamps; ``timeMap`` translates.
    public var cuts: [Cut]

    /// The grouping knobs used to build (and re-flow) ``cards``.
    public var groupingRules: GroupingRules

    /// Tracks the editor has switched OFF — content on a disabled track
    /// neither renders nor sounds, in preview AND export (the pro-NLE
    /// behavior: what you see is what you ship). `nil`/empty = all on.
    public var disabledTracks: Set<TrackKind>?

    /// The output canvas.
    public var renderConfig: RenderConfig

    /// An opening title over the first seconds, drawn above the captions, or
    /// `nil` for none. See ``HookBuilder``.
    public var hook: HookTitle?

    /// The cards drawn behind the speaker, or `nil` for none. See
    /// ``SubjectCoverage``, which decides which cards may go.
    public var behindSubject: BehindSubject?

    /// Stickers where ``StickerPlacer`` put them, drawn above the captions,
    /// or `nil` for none. Its own key, `placedStickers`: the retired editor's
    /// `stickers` key is a different shape and rides through ``preserved``.
    public var placedStickers: [PlacedSticker]?

    /// Creates a document.
    public init(
        videoURL: URL? = nil,
        cards: [CaptionCard] = [],
        style: CaptionStyle = CaptionStyle(),
        highlightRules: [HighlightRule] = [],
        voiceVolume: Double = 1,
        cutStyle: CutStyle = .none,
        cuts: [Cut] = [],
        groupingRules: GroupingRules = GroupingRules(),
        renderConfig: RenderConfig = .reel
    ) {
        self.videoURL = videoURL
        self.cards = cards
        self.style = style
        self.highlightRules = highlightRules
        self.voiceVolume = voiceVolume
        self.cutStyle = cutStyle
        self.cuts = cuts
        self.groupingRules = groupingRules
        self.renderConfig = renderConfig
    }

    /// Written out rather than synthesised: with both ``init(from:)`` and
    /// ``encode(to:)`` hand-written, Swift generates no `CodingKeys` at all.
    /// Declaring it also means ``preserved`` cannot accidentally become a key
    /// in the document — it is a carrier for other people's fields, not one
    /// of ours.
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case videoURL
        case cards
        case style
        case highlightRules
        case voiceVolume
        case cutStyle
        case videoDuration
        case gradientOverlay
        case progressBar
        case cropOffset
        case autoMotion
        case speakerColors
        case backgroundBlur
        case captionTimingOffset
        case beatTimes
        case cropKeyframes
        case faceCensor
        case depthBlur
        case mirrorHorizontal
        case letterbox
        case videoBorder
        case cuts
        case groupingRules
        case disabledTracks
        case renderConfig
        case hook
        case behindSubject
        case speakerNames
        case secondaryWords
        case placedStickers
    }

    /// The keys this type models, so ``PreservedValue/unmodelledFields(from:known:)``
    /// knows what to leave alone. `preserved` itself is listed because it is a
    /// carrier, not a field of the document.
    private static let modelledKeys: Set<String> = {
        var keys = Set(CodingKeys.allCases.map(\.rawValue))
        // Not a field of the document — the carrier for everybody else's.
        keys.insert("preserved")
        return keys
    }()

    /// Tolerant decoding: fields added in newer versions fall back to their
    /// defaults, so old project files keep opening.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        videoURL = try container.decodeIfPresent(URL.self, forKey: .videoURL)
        cards = try container.decodeIfPresent([CaptionCard].self, forKey: .cards) ?? []
        style = try container.decodeIfPresent(CaptionStyle.self, forKey: .style) ?? CaptionStyle()
        highlightRules = try container.decodeIfPresent([HighlightRule].self, forKey: .highlightRules) ?? []
        voiceVolume = try container.decodeIfPresent(Double.self, forKey: .voiceVolume) ?? 1
        cutStyle = try container.decodeIfPresent(CutStyle.self, forKey: .cutStyle) ?? .none
        videoDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .videoDuration)
        gradientOverlay = try container.decodeIfPresent(GradientOverlay.self, forKey: .gradientOverlay)
        progressBar = try container.decodeIfPresent(ProgressBarStyle.self, forKey: .progressBar)
        cropOffset = try container.decodeIfPresent(NormalizedPoint.self, forKey: .cropOffset)
        autoMotion = try container.decodeIfPresent(AutoMotionStyle.self, forKey: .autoMotion)
        speakerColors = try container.decodeIfPresent([StyleColor].self, forKey: .speakerColors)
        backgroundBlur = try container.decodeIfPresent(Double.self, forKey: .backgroundBlur)
        captionTimingOffset = try container.decodeIfPresent(TimeInterval.self, forKey: .captionTimingOffset) ?? 0
        beatTimes = try container.decodeIfPresent([TimeInterval].self, forKey: .beatTimes)
        cropKeyframes = try container.decodeIfPresent([CropKeyframe].self, forKey: .cropKeyframes)
        faceCensor = try container.decodeIfPresent(FaceCensor.self, forKey: .faceCensor)
        depthBlur = try container.decodeIfPresent(DepthBlur.self, forKey: .depthBlur)
        mirrorHorizontal = try container.decodeIfPresent(Bool.self, forKey: .mirrorHorizontal) ?? false
        letterbox = try container.decodeIfPresent(Double.self, forKey: .letterbox)
        videoBorder = try container.decodeIfPresent(BorderStyle.self, forKey: .videoBorder)
        cuts = try container.decodeIfPresent([Cut].self, forKey: .cuts) ?? []
        groupingRules = try container.decodeIfPresent(GroupingRules.self, forKey: .groupingRules) ?? GroupingRules()
        renderConfig = try container.decodeIfPresent(RenderConfig.self, forKey: .renderConfig) ?? .reel
        disabledTracks = try container.decodeIfPresent(Set<TrackKind>.self, forKey: .disabledTracks)
        hook = try container.decodeIfPresent(HookTitle.self, forKey: .hook)
        behindSubject = try container.decodeIfPresent(BehindSubject.self, forKey: .behindSubject)
        speakerNames = try container.decodeIfPresent([String].self, forKey: .speakerNames)
        secondaryWords = try container.decodeIfPresent([Word].self, forKey: .secondaryWords)
        placedStickers = try container.decodeIfPresent([PlacedSticker].self, forKey: .placedStickers)

        // Everything another writer put there that this one does not model.
        preserved = PreservedValue.unmodelledFields(from: decoder, known: Self.modelledKeys)
    }

    /// Writes the modelled fields, then everything this engine does not model.
    ///
    /// Hand-written rather than synthesised for one reason: the synthesised
    /// encoder writes back only the declared properties, which would drop
    /// every key in ``preserved`` on the first save.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(videoURL, forKey: .videoURL)
        try container.encode(cards, forKey: .cards)
        try container.encode(style, forKey: .style)
        try container.encode(highlightRules, forKey: .highlightRules)
        try container.encode(voiceVolume, forKey: .voiceVolume)
        try container.encode(cutStyle, forKey: .cutStyle)
        try container.encodeIfPresent(videoDuration, forKey: .videoDuration)
        try container.encodeIfPresent(gradientOverlay, forKey: .gradientOverlay)
        try container.encodeIfPresent(progressBar, forKey: .progressBar)
        try container.encodeIfPresent(cropOffset, forKey: .cropOffset)
        try container.encodeIfPresent(autoMotion, forKey: .autoMotion)
        try container.encodeIfPresent(speakerColors, forKey: .speakerColors)
        try container.encodeIfPresent(backgroundBlur, forKey: .backgroundBlur)
        try container.encode(captionTimingOffset, forKey: .captionTimingOffset)
        try container.encodeIfPresent(beatTimes, forKey: .beatTimes)
        try container.encodeIfPresent(cropKeyframes, forKey: .cropKeyframes)
        try container.encodeIfPresent(faceCensor, forKey: .faceCensor)
        try container.encodeIfPresent(depthBlur, forKey: .depthBlur)
        try container.encode(mirrorHorizontal, forKey: .mirrorHorizontal)
        try container.encodeIfPresent(letterbox, forKey: .letterbox)
        try container.encodeIfPresent(videoBorder, forKey: .videoBorder)
        try container.encode(cuts, forKey: .cuts)
        try container.encode(groupingRules, forKey: .groupingRules)
        try container.encodeIfPresent(disabledTracks, forKey: .disabledTracks)
        try container.encode(renderConfig, forKey: .renderConfig)
        try container.encodeIfPresent(hook, forKey: .hook)
        try container.encodeIfPresent(behindSubject, forKey: .behindSubject)
        try container.encodeIfPresent(speakerNames, forKey: .speakerNames)
        try container.encodeIfPresent(secondaryWords, forKey: .secondaryWords)
        try container.encodeIfPresent(placedStickers, forKey: .placedStickers)

        // Last, so a modelled key always wins over a stale preserved copy of
        // the same name.
        try PreservedValue.encode(preserved, to: encoder)
    }

    /// Whether a track's content should render/sound right now.
    public func trackEnabled(_ kind: TrackKind) -> Bool {
        !(disabledTracks?.contains(kind) ?? false)
    }

    /// The source↔output time mapping induced by ``cuts``.
    public var timeMap: TimeMap {
        TimeMap(cuts: cuts)
    }
}

/// A switchable timeline track — the unit of "turn this whole layer off".
///
/// ``captions`` and ``titles`` (the hook title) carry content here. The rest
/// are kept deliberately: a project from the retired editor engine can
/// disable a sticker or B-roll track, and
/// ``CaptionDocument/disabledTracks`` decodes as a `Set<TrackKind>`. Drop the
/// cases and that decode throws — so a project would fail to open outright
/// over a layer this engine does not even draw.
public enum TrackKind: String, Codable, Equatable, Hashable, Sendable, CaseIterable {

    /// The caption layer.
    case captions

    /// Emoji and image stickers. Present so such a document still opens.
    case stickers

    /// Titles: the hook title here (text stickers in the retired editor).
    case titles

    /// Picture-in-picture video overlays. Present so such a document still opens.
    case broll

    /// Sound effects. Present so such a document still opens.
    case soundEffects = "sound-effects"
}

/// A thin animated progress bar across the frame — the "keep watching" bar.
public struct ProgressBarStyle: Codable, Equatable, Sendable {

    /// Bar color.
    public var color: StyleColor

    /// Bar thickness in reference points (at a 1920-tall frame).
    public var height: CGFloat

    /// Whether the bar sits at the top edge (else the bottom).
    public var top: Bool

    public init(color: StyleColor = .yellow, height: CGFloat = 10, top: Bool = true) {
        self.color = color
        self.height = height
        self.top = top
    }
}

extension CaptionDocument {

    /// The card on screen at `time`, preferring the latest-starting card when
    /// user edits create overlaps.
    public func card(at time: TimeInterval) -> CaptionCard? {
        cards.last { $0.contains(time: time) }
    }

    /// The effective style for a card: its style override (or the global
    /// style), with the card's position override applied on top.
    public func resolvedStyle(for card: CaptionCard) -> CaptionStyle {
        var resolved = card.styleOverride ?? style
        if let position = card.positionOverride {
            resolved.position = position
        }
        return resolved
    }

    /// Whether the caption on screen at `time` (source time) goes behind
    /// the speaker.
    public func captionIsBehindSubject(at time: TimeInterval) -> Bool {
        guard let behind = behindSubject, !behind.cards.isEmpty, trackEnabled(.captions),
              let card = card(at: time - captionTimingOffset) else { return false }
        return behind.cards.contains(card.id)
    }

    /// The first keyword rule matching a word, if any.
    public func highlightRule(for word: Word) -> HighlightRule? {
        highlightRules.first { $0.matches(word) }
    }

    /// Resizes one caption card's time window, clamped so cards never
    /// overlap. Captions are exclusive in time — the renderer shows one card
    /// at a time, so an overlap doesn't layer, it makes a neighbor flicker
    /// out. The start edge stops at the previous card's end, the end edge at
    /// the next card's start (neighbors are found by time, not array order),
    /// and the card always keeps `minimumDuration`.
    public mutating func resizeCard(
        id: UUID,
        newStart: TimeInterval? = nil,
        newEnd: TimeInterval? = nil,
        minimumDuration: TimeInterval = 0.2
    ) {
        guard let index = cards.firstIndex(where: { $0.id == id }) else { return }
        let card = cards[index]

        // Nearest neighbors by time (edits can leave the array unsorted).
        let previousEnd = cards
            .filter { $0.id != id && $0.start < card.start }
            .map(\.end)
            .max()
        let nextStart = cards
            .filter { $0.id != id && $0.start > card.start }
            .map(\.start)
            .min()

        if let newStart {
            let floor = previousEnd ?? 0
            cards[index].start = min(max(newStart, floor), cards[index].end - minimumDuration)
        }
        if let newEnd {
            let ceiling = nextStart ?? .greatestFiniteMagnitude
            cards[index].end = max(min(newEnd, ceiling), cards[index].start + minimumDuration)
        }
    }

    /// All words across all cards, in order.
    public var allWords: [Word] {
        cards.flatMap(\.words)
    }

    // MARK: - Serialization

    /// Encodes the document as pretty-printed JSON.
    public func serialized() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// Decodes a document previously produced by ``serialized()``.
    public static func deserialize(from data: Data) throws -> CaptionDocument {
        try JSONDecoder().decode(CaptionDocument.self, from: data)
    }
}
