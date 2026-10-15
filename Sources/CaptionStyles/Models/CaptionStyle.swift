//
//  CaptionStyle.swift
//  CaptionStyles
//
//  Created by David Sherlock on 2026.
//

import CoreGraphics
import Foundation

/// The complete visual treatment of a caption: font, colors, stroke, shadow,
/// background, position, animation, and highlight behavior.
///
/// A style is pure data — it serializes into the project document and drives
/// the renderer. It is never UI state. The document holds one global style;
/// individual cards may carry an override.
///
/// All point-based measurements (font size, stroke width, shadow radius,
/// paddings) are specified **at a 1920-pixel-tall reference frame** and scale
/// linearly with the actual render height, so the same style looks identical
/// at 1080×1920, 2160×3840, or a small preview.
public struct CaptionStyle: Codable, Equatable, Hashable, Sendable {

    // MARK: - Font

    /// The font family name (e.g. `"Avenir Next"`), or `nil` for the system font.
    public var fontFamily: String?

    /// The font weight.
    public var fontWeight: FontWeight

    /// The font size in points at the 1920-tall reference frame.
    public var fontSize: CGFloat

    /// Extra tracking between characters, in reference points.
    public var letterSpacing: CGFloat

    /// Multiplier on the natural width of the gap between words (`1` = the
    /// font's space width). The renderer additionally widens gaps by the
    /// stroke width, which otherwise eats them visually.
    public var wordSpacing: CGFloat

    /// Line-height multiplier (`1` = the font's natural line height).
    public var lineSpacing: CGFloat

    /// A case transform applied at layout time.
    public var textTransform: TextTransform

    /// Synthetic italic: a rightward shear applied to every glyph
    /// (`0.25` ≈ a classic oblique). Works with any font family — no italic
    /// face required. `nil`/`0` = upright.
    public var slant: CGFloat?

    // MARK: - Fill & Decoration

    /// The base text color.
    public var textColor: StyleColor

    /// Multi-color words: when set, each word takes the next color from
    /// this palette in rotation (the "every word a different accent" look).
    /// Spoken-word highlights and keyword rules still apply on top.
    /// `nil`/empty uses ``textColor`` for every word.
    public var wordColorPalette: [StyleColor]?

    /// A linear gradient replacing the flat text fill, or `nil` for solid
    /// ``textColor``. Highlight recolors (active word, karaoke, keywords,
    /// speakers) stay solid on top — the gradient is the resting look.
    public var textGradient: GradientFill?

    /// A photo/image clipped inside the glyphs, spanning the whole caption
    /// block — the "fill the letters with a photo" look. Takes precedence over
    /// ``textGradient``; highlight recolors still paint solid on top. Per-word
    /// ``WordStyle/imageFill`` overrides this for one word (cropped to that
    /// word). `nil` = no image fill.
    public var imageFill: ImageFill? = nil

    /// Retro CRT scanlines masked to the glyphs — dark-stripe strength
    /// `0…1`, or `nil` for none.
    public var scanlineIntensity: CGFloat?

    /// VHS-style chromatic aberration: two colored copies offset either
    /// side of the text by this many reference points — really a pair of
    /// hard drop shadows, which is exactly the retro print look. `nil` for
    /// none.
    public var chromaticAberration: CGFloat?

    /// Fringe direction in degrees (`0` = horizontal, `90` = vertical).
    /// `nil` = horizontal.
    public var fringeAngle: CGFloat?

    /// The two fringe colors (first sits at minus-offset, second at plus).
    /// `nil` = the classic red/cyan split.
    public var fringeColors: [StyleColor]?

    /// The outline color, or `nil` for no outline.
    public var strokeColor: StyleColor?

    /// The outline width in reference points.
    public var strokeWidth: CGFloat

    /// Stacked outlines, drawn widest-first beneath the fill — the "sticker"
    /// look (e.g. a black inline stroke wrapped in a thick colored one). When
    /// set and non-empty, this **replaces** the single ``strokeColor`` /
    /// ``strokeWidth`` stroke. `nil` = the single stroke. Per-word
    /// ``WordStyle/strokeLayers`` overrides this for one word.
    public var strokeLayers: [StrokeLayer]? = nil

    /// The drop shadow, or `nil` for none.
    public var shadow: ShadowStyle?

    /// A hard (un-blurred) offset copy of the text behind the fill — the solid
    /// colored drop that reads as "sticker depth" (e.g. the red offset behind a
    /// yellow word). Distinct from the blurred ``shadow``. Per-word
    /// ``WordStyle/hardShadow`` overrides this. `nil` = none.
    public var hardShadow: HardShadowStyle? = nil

    /// A solid 3D extrusion behind the text — stacked silhouette copies
    /// stepping back along an angle to build connected depth (the chunky
    /// metallic-title look). Per-word ``WordStyle/extrude`` overrides this.
    /// `nil` = flat.
    public var extrude: ExtrudeStyle? = nil

    /// A luminous bloom around the text, or `nil` for none — the lyric-video
    /// glow. Its scope glows either every word or just the spoken one.
    public var glow: GlowStyle?

    /// Mixed letters: every letter gets a seeded font, ink color, paper
    /// chip, and tilt (the cut-out-magazine "ransom note" look). When set it
    /// replaces the normal fill/stroke/gradient path for the letterforms;
    /// shadow, background, placement, and animations still apply. Intended
    /// for titles. `nil` = normal rendering.
    public var mixedLetters: MixedLetterStyle? = nil

    /// The background pill/box behind the text, or `nil` for none.
    public var background: BackgroundStyle?

    /// A knockout plate: a solid card covering the whole frame with the
    /// caption's letterforms cut out, so the footage shows only *through*
    /// the type — the mask-reveal intro. The plate and its holes ride the
    /// card's animations (a card exit slides the whole plate away; word
    /// entrances pop the holes in). Replaces the normal text/background
    /// drawing. `nil` = normal rendering.
    public var knockoutPlate: StyleColor? = nil

    /// Per-letter entrance cascade: each glyph runs ``wordAnimation``
    /// individually, offset by this many seconds from the previous letter
    /// (the character-by-character kinetic look). `nil`/`0` = the whole
    /// word animates as one.
    public var letterStagger: TimeInterval? = nil

    /// Overall caption opacity (`0…1`).
    public var opacity: CGFloat

    // MARK: - Placement

    /// The normalized center of the caption block: `x`,`y` in `0…1`,
    /// measured from the **top-left** of the frame. `(0.5, 0.75)` is the
    /// classic lower-third reel position.
    public var position: NormalizedPoint

    /// Horizontal alignment of lines within the caption block.
    public var alignment: CaptionAlignment

    /// The caption block is scaled down if a line would exceed this fraction
    /// of the frame width.
    public var maxWidthFraction: CGFloat

    /// Whole-block rotation in radians (positive = clockwise on screen) —
    /// the tilted-caption look. `nil`/`0` = level.
    public var blockRotation: CGFloat?

    /// Bends the caption's glyphs along a curve — arc or wave — the "text on a
    /// path" title look. Intended for **titles**: each glyph is placed and
    /// rotated onto the curve. Fill (solid/gradient/photo), outlines, the hard
    /// drop, the 3D extrude, and glow all follow the curve; only karaoke fills
    /// are unavailable under a warp (their fraction-clip assumes a straight
    /// baseline). `nil` = a straight baseline.
    public var textWarp: TextWarp? = nil

    // MARK: - Animation & Highlighting

    /// How words enter the screen.
    public var wordAnimation: WordAnimation

    /// How the caption leaves at its card's end: the entrance curves run
    /// in reverse (a pop-on pops off, a slide-up sinks away). `nil` = it
    /// just disappears — the classic hard swap.
    public var exitAnimation: WordAnimation?

    /// Ambient motion while words are on screen — captions that never sit
    /// still (wave, wiggle, pulse, float, sway…). `nil` = static.
    public var wordLoop: WordLoop?

    /// Loop rate multiplier for ``wordLoop`` — `2` is twice as fast, `0.5`
    /// half. `nil`/`1` = the default rate.
    public var wordLoopSpeed: Double?

    /// Scales how far word entrances/exits travel and overshoot — `0` =
    /// appear in place, `1` = default, `2` = double the throw. `nil`/`1` =
    /// default.
    public var animationIntensity: Double?

    /// How the whole caption block enters at each card's start.
    public var cardAnimation: CardAnimation

    /// How the currently-spoken word is emphasized.
    public var highlightMode: HighlightMode

    /// The color for the active word / karaoke fill. `nil` uses ``textColor``.
    public var activeWordColor: StyleColor?

    /// Variable-font kinetics: the spoken word's weight ramps from
    /// ``fontWeight`` to this target across the word's duration (thin
    /// swelling to black as it's said). Ignored under karaoke (its
    /// fraction-clip assumes fixed metrics). `nil` = constant weight.
    public var activeWordWeightRamp: FontWeight? = nil

    /// A gradient fill for the Highlight Box (``HighlightMode/activeBox``) —
    /// the block behind the spoken word becomes a gradient instead of the
    /// flat ``activeWordColor``. `nil` = solid.
    public var activeBoxGradient: GradientFill? = nil

    /// The Highlight Box's horizontal padding as a fraction of font size
    /// (`nil` = the default `0.16`) — their "Horizontal size".
    public var activeBoxPadH: CGFloat? = nil

    /// The Highlight Box's vertical padding as a fraction of font size
    /// (`nil` = the default `0.10`) — their "Vertical size".
    public var activeBoxPadV: CGFloat? = nil

    /// Text color for the spoken word when it sits in the Highlight Box — lets
    /// the word go dark on a light pill (the inverse-highlight look). `nil` =
    /// keeps the normal ``textColor``.
    public var activeBoxTextColor: StyleColor? = nil

    /// Auto-censor profanity: words matching ``ProfanityFilter`` get a black
    /// bar burned over them (and a bleep on export). Per-word
    /// ``WordStyle/censored`` overrides this either way. `nil`/`false` = off.
    public var censorProfanity: Bool? = nil

    /// The spoken-word highlight colour cycles through these instead of
    /// staying ``activeWordColor`` — each highlighted word takes the next,
    /// starting at a point seeded by the card (the colour-cycling key word).
    /// `nil`/empty = ``activeWordColor``.
    public var activeWordPalette: [StyleColor]? = nil

    /// The Highlight Box's silhouette: ``BackgroundStyle/Shape/marker`` makes
    /// it a rough highlighter swipe. `nil` = the rounded box.
    public var activeBoxShape: BackgroundStyle.Shape? = nil

    /// Highlight the card's KEY words instead of following the voice: when
    /// any word on the card carries a colour override (automatic emphasis,
    /// a recipe's per-word emphasis), those words wear the highlight for the
    /// whole card; a card with none falls back to the spoken word. Applies
    /// to ``HighlightMode/activeWord``, ``HighlightMode/activeBox`` and
    /// ``HighlightMode/activeUnderline``. `nil`/`false` = follow the voice.
    public var highlightKeyWords: Bool? = nil

    /// With ``activeWordWeightRamp``: a word already spoken keeps the target
    /// weight, so the line fills in bold as it is said (the weight sweep).
    /// Each word's space is reserved at the heavier weight so nothing
    /// collides. `nil`/`false` = the weight returns after the word.
    public var weightRampHolds: Bool? = nil

    /// Speaker colours carried by the style: a speaker's words take
    /// `speakerColors[speaker % count]`. A document's own
    /// `speakerColors` win; with neither, speakers look alike. `nil` = none.
    public var speakerColors: [StyleColor]? = nil

    /// The speaker's name shown with their caption — a bold line above the
    /// text or a chip — when the card's words carry a speaker. `nil` = none.
    public var speakerLabel: SpeakerLabelStyle? = nil

    /// A leading dash on each speaker's line when one card holds two
    /// speakers — the streaming-subtitle convention. Pair with grouping's
    /// `speakerBreak: line`. `nil`/`false` = no dashes.
    public var speakerDash: Bool? = nil

    /// Stacked type: every line is scaled so it spans the widest line's
    /// width (short words grow, at most ``maximumLineFitScale``×), building
    /// a solid block. `nil`/`false` = every line at the font size.
    public var fitLinesToWidth: Bool? = nil

    /// A seeded tilt per card, up to this many radians either way, on top of
    /// ``blockRotation`` — each caption lands at its own slight angle.
    /// Deterministic in the card's start time. `nil`/`0` = level.
    public var cardTilt: CGFloat? = nil

    /// A second line of text drawn small above the caption — the bilingual
    /// look. Its words come from the document's `secondaryWords` (those
    /// whose midpoint falls in the card's span). `nil` = none.
    public var secondaryLine: SecondaryLineStyle? = nil

    /// The largest a ``fitLinesToWidth`` line is scaled up.
    public static let maximumLineFitScale: CGFloat = 2.4

    /// Scale applied to the active word at the peak of its pop (`1` = none).
    public var activeWordScale: CGFloat

    /// Duration of entrance/pop animations, in seconds.
    public var animationDuration: TimeInterval

    // MARK: - Initialisation

    /// Creates a style. Every parameter has a sensible reel-caption default.
    public init(
        fontFamily: String? = nil,
        fontWeight: FontWeight = .heavy,
        fontSize: CGFloat = 84,
        letterSpacing: CGFloat = 0,
        wordSpacing: CGFloat = 1.15,
        lineSpacing: CGFloat = 1.08,
        textTransform: TextTransform = .none,
        slant: CGFloat? = nil,
        textColor: StyleColor = .white,
        strokeColor: StyleColor? = .black,
        strokeWidth: CGFloat = 6,
        shadow: ShadowStyle? = ShadowStyle(),
        glow: GlowStyle? = nil,
        background: BackgroundStyle? = nil,
        opacity: CGFloat = 1,
        position: NormalizedPoint = NormalizedPoint(x: 0.5, y: 0.75),
        alignment: CaptionAlignment = .center,
        maxWidthFraction: CGFloat = 0.9,
        wordAnimation: WordAnimation = .none,
        cardAnimation: CardAnimation = .none,
        highlightMode: HighlightMode = .activeWord,
        activeWordColor: StyleColor? = .yellow,
        activeWordScale: CGFloat = 1.08,
        animationDuration: TimeInterval = 0.14
    ) {
        self.fontFamily = fontFamily
        self.fontWeight = fontWeight
        self.fontSize = fontSize
        self.letterSpacing = letterSpacing
        self.wordSpacing = wordSpacing
        self.lineSpacing = lineSpacing
        self.textTransform = textTransform
        self.slant = slant
        self.textColor = textColor
        self.strokeColor = strokeColor
        self.strokeWidth = strokeWidth
        self.shadow = shadow
        self.glow = glow
        self.background = background
        self.opacity = opacity
        self.position = position
        self.alignment = alignment
        self.maxWidthFraction = maxWidthFraction
        self.wordAnimation = wordAnimation
        self.cardAnimation = cardAnimation
        self.highlightMode = highlightMode
        self.activeWordColor = activeWordColor
        self.activeWordScale = activeWordScale
        self.animationDuration = animationDuration
    }
}

// MARK: - Component Types

/// A normalized point: `x`,`y` in `0…1` from the top-left of the frame.
///
/// Positions are stored normalized so they map correctly between the preview
/// surface and the export resolution (the renderer resolves them to pixels).
public struct NormalizedPoint: Codable, Equatable, Hashable, Sendable {
    public var x: CGFloat
    public var y: CGFloat

    public init(x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
    }
}

/// Font weight, mapped to CoreText weight traits at draw time.
public enum FontWeight: String, Codable, CaseIterable, Sendable {
    case light, regular, medium, semibold, bold, heavy, black

    /// The CoreText weight trait value (`-1…1`).
    public var traitValue: CGFloat {
        switch self {
        case .light: return -0.4
        case .regular: return 0.0
        case .medium: return 0.23
        case .semibold: return 0.30
        case .bold: return 0.40
        case .heavy: return 0.56
        case .black: return 0.62
        }
    }
}

/// A case transform applied to caption text at layout time.
public enum TextTransform: String, Codable, CaseIterable, Sendable {
    case none
    case uppercase
    case lowercase

    /// As transcribed, with each card's first word — and any word after a
    /// sentence ends — starting with a capital.
    case sentence
}

/// Horizontal alignment of lines within the caption block.
public enum CaptionAlignment: String, Codable, CaseIterable, Sendable {
    case leading
    case center
    case trailing
}

/// How words enter the screen. Every animation begins at the word's spoken
/// start time and is a pure function of time — no CoreAnimation anywhere.
public enum WordAnimation: String, Codable, CaseIterable, Sendable {

    /// All of a card's words are visible for the card's whole duration.
    case none

    /// Fades in.
    case fadeIn = "fade-in"

    /// Pops on with a small scale overshoot.
    case popOn = "pop-on"

    /// Bounces to full size like a dropped ball settling.
    case bounceIn = "bounce-in"

    /// Springs on with a damped elastic wobble.
    case spring

    /// Slams down from oversized — the high-impact "stomp" look.
    case stomp

    /// Slides up into place.
    case slideUp = "slide-up"

    /// Drops down into place.
    case slideDown = "slide-down"

    /// Flies in from the left.
    case flyInLeft = "fly-in-left"

    /// Flies in from the right.
    case flyInRight = "fly-in-right"

    /// Spins in with a tilt and a pop.
    case rotateIn = "rotate-in"

    /// Reveals left-to-right like a fast typewriter wipe.
    case typewriter

    /// Rattles side to side as it lands.
    case shake

    /// Falls from above and bounces on landing.
    case drop

    /// Rises from below while spinning upright.
    case twirlUp = "twirl-up"

    /// Swings in like a pendulum settling.
    case swing

    /// Skids in from the left, overshoots, and slides back.
    case skid

    /// Rolls in from the right like a wheel — flies leftward into place
    /// while spinning one full turn, landing upright.
    case rollIn = "roll-in"

    /// Rolls in from the left, spinning the other way.
    case rollInLeft = "roll-in-left"

    /// Zooms in from tiny, clean and linear — no overshoot (the minimal
    /// title look; ``popOn`` with the bounce removed).
    case zoomIn = "zoom-in"

    /// Spirals in — shrinks from oversized while sweeping a quarter-turn
    /// arc into place.
    case spiralIn = "spiral-in"

    /// Flips down over the top edge like a page settling — a vertical
    /// squash-and-recover that reads as a 3D flip.
    case flipDown = "flip-down"

    /// Whips in from the left with a heavy tilt that snaps upright.
    case whipIn = "whip-in"

    /// Sharpens into focus from a soft blur — the focus-pull entrance.
    case blurIn = "blur-in"

    /// Whips in from the left trailing a directional motion smear.
    case smearIn = "smear-in"
}

/// How a whole caption block enters at its card's start time, on top of any
/// per-word animation.
public enum CardAnimation: String, Codable, CaseIterable, Sendable {

    /// The block just appears.
    case none

    /// The block fades in.
    case fadeIn = "fade-in"

    /// The block rises into place.
    case slideUp = "slide-up"

    /// The block drops into place.
    case slideDown = "slide-down"

    /// The block pops on with a scale overshoot.
    case popOn = "pop-on"

    /// The block slams down from oversized.
    case stomp

    /// The block slides in from the left edge of the frame (the broadcast
    /// lower third).
    case slideInLeft = "slide-in-left"
}

/// How the currently-spoken word is emphasized.
public enum HighlightMode: String, Codable, CaseIterable, Sendable {

    /// No spoken-word emphasis.
    case none

    /// The active word switches to ``CaptionStyle/activeWordColor`` while spoken.
    case activeWord = "active-word"

    /// Karaoke: words fill left-to-right with the active color as they are
    /// spoken, and stay filled afterwards.
    case karaoke

    /// A rounded box in ``CaptionStyle/activeWordColor`` hugs just the
    /// spoken word, hopping word to word; the text itself stays in
    /// ``CaptionStyle/textColor``.
    case activeBox = "active-box"

    /// An underline bar in ``CaptionStyle/activeWordColor`` slides under
    /// the spoken word.
    case activeUnderline = "active-underline"

    /// The spoken word stays at full strength while the rest of the
    /// caption dims — the "focus" look.
    case spotlight
}

/// Ambient word motion, looping while a caption is on screen. Deterministic
/// in time, so preview and export stay identical.
public enum WordLoop: String, Codable, CaseIterable, Sendable {

    /// Words bob up and down in a rolling wave.
    case wave

    /// Words rock with a tiny jitter.
    case wiggle

    /// Words breathe — a gentle scale pulse.
    case pulse

    /// Words drift up and down together, gently.
    case float

    /// Words sway left and right together.
    case sway

    /// Words hop on an invisible floor.
    case bounce

    /// Slow, soft breathing scale — calmer than ``pulse``.
    case breathe

    /// Fast, tiny horizontal shiver.
    case shake

    /// Organic squash-and-stretch — width and height oscillate in
    /// counter-phase, like set jelly.
    case jelly
}

/// A drop shadow behind the caption text.
public struct ShadowStyle: Codable, Equatable, Hashable, Sendable {

    /// The shadow color.
    public var color: StyleColor

    /// The blur radius in reference points.
    public var radius: CGFloat

    /// The shadow offset in reference points (`y` is down-positive).
    public var offsetX: CGFloat
    public var offsetY: CGFloat

    public init(
        color: StyleColor = StyleColor.black.withAlpha(0.6),
        radius: CGFloat = 10,
        offsetX: CGFloat = 0,
        offsetY: CGFloat = 4
    ) {
        self.color = color
        self.radius = radius
        self.offsetX = offsetX
        self.offsetY = offsetY
    }
}

/// Bends a caption's baseline into a curve, placing and rotating each glyph
/// onto it — text-on-a-path for titles.
public struct TextWarp: Codable, Equatable, Hashable, Sendable {

    /// The curve family.
    public enum Shape: String, Codable, CaseIterable, Sendable {
        /// A single arch — glyphs rise to a peak at the center and tilt to
        /// follow it. Positive ``amount`` arches up, negative sags down.
        case arc
        /// A sine wave along the line — glyphs ride the crests and troughs.
        case wave
        /// A full ring — the line's glyphs wrap a complete circle around the
        /// caption's center (the "text circling the head" look). The text
        /// exactly closes the ring at ``amount`` `1`; repeat the phrase with
        /// separators ("· need this · need this ·") to fill a bigger circle.
        /// Pairs with ``crawl`` for the marching rotation.
        case circle
        /// A per-letter jumble — every glyph takes a seeded vertical offset
        /// and tilt (the scattered chunky-title look). ``amount`` sets the
        /// throw, ``scatterRotation`` the tilt, ``seed`` reshuffles.
        case scatter

        /// A serpentine ribbon — the text flows along a deep S-curve at
        /// true arc length (glyphs never bunch on the bends), each rotated
        /// to the curve's tangent: the drawn-spline look that winds behind
        /// a subject. ``amount`` sets the sweep depth, ``waves`` the number
        /// of bends, and ``crawl`` slithers the text along the path.
        case snake
    }

    /// The curve family.
    public var shape: Shape

    /// Bend strength. Arc/wave: the peak rise/fall as a fraction of the line
    /// width (`0.15` is gentle; negatives invert). Circle: a multiplier on
    /// the closed-ring radius (`1` = the text exactly closes the circle).
    /// Scatter: the per-glyph vertical throw as a fraction of the font size.
    public var amount: CGFloat

    /// For ``Shape/wave``, how many full waves span the line. `nil` = one.
    public var waves: CGFloat?

    /// For ``Shape/circle`` and ``Shape/snake``: path-lengths per second
    /// the text crawls along the curve — the marching ring, the slithering
    /// snake. Deterministic in absolute time, so preview and export stay
    /// identical. `nil`/`0` = static.
    public var crawl: CGFloat?

    /// For ``Shape/scatter``: the maximum per-glyph tilt in radians
    /// (`0.12` ≈ a lively jumble). `nil` = a default modest tilt.
    public var scatterRotation: CGFloat?

    /// For ``Shape/scatter``: reshuffles the deterministic jumble — same
    /// seed, same scatter, forever (preview/export parity). `nil` = `0`.
    public var seed: Int?

    public init(shape: Shape = .arc, amount: CGFloat = 0.15, waves: CGFloat? = nil) {
        self.shape = shape
        self.amount = amount
        self.waves = waves
    }
}

/// Mixed letters: every letter cut from a different "magazine" —
/// a seeded font, ink color, and paper chip per character, with a small
/// seeded tilt. Deterministic for a given seed, so preview and export match
/// and a saved project always reopens with the same cut-outs.
public struct MixedLetterStyle: Codable, Equatable, Hashable, Sendable {

    /// Ink colors, picked per letter. Empty falls back to a classic set.
    public var colors: [StyleColor]

    /// Font families, picked per letter. Empty falls back to a built-in mix
    /// of print-ish faces.
    public var fontFamilies: [String]

    /// Paper-chip colors behind letters, picked per letter. An entry with
    /// `alpha == 0` means "no chip" for that draw — mixing bare and chipped
    /// letters. Empty falls back to a classic paper set.
    public var chipColors: [StyleColor]

    /// Maximum per-letter tilt in radians (`0.1` ≈ the classic cut-out mess).
    public var rotationMax: CGFloat

    /// Reshuffles which letter gets which font/color/chip.
    public var seed: Int

    public init(
        colors: [StyleColor] = [],
        fontFamilies: [String] = [],
        chipColors: [StyleColor] = [],
        rotationMax: CGFloat = 0.1,
        seed: Int = 0
    ) {
        self.colors = colors
        self.fontFamilies = fontFamilies
        self.chipColors = chipColors
        self.rotationMax = rotationMax
        self.seed = seed
    }

    /// The classic ink set (dark, red, cream, navy) used when ``colors`` is empty.
    public static let defaultColors: [StyleColor] = [
        StyleColor(red: 0.12, green: 0.12, blue: 0.13, alpha: 1),
        StyleColor(red: 0.78, green: 0.15, blue: 0.15, alpha: 1),
        StyleColor(red: 0.95, green: 0.92, blue: 0.82, alpha: 1),
        StyleColor(red: 0.15, green: 0.2, blue: 0.45, alpha: 1),
        StyleColor(red: 0.85, green: 0.45, blue: 0.6, alpha: 1),
    ]

    /// The print-ish face mix used when ``fontFamilies`` is empty.
    public static let defaultFontFamilies: [String] = [
        "Georgia", "American Typewriter", "Futura", "Marker Felt",
        "Baskerville", "Courier New", "Avenir Next Condensed",
    ]

    /// The paper-chip set used when ``chipColors`` is empty (includes a few
    /// clear entries so some letters sit bare).
    public static let defaultChipColors: [StyleColor] = [
        StyleColor(red: 0.97, green: 0.94, blue: 0.85, alpha: 1),
        StyleColor(red: 0.93, green: 0.78, blue: 0.83, alpha: 1),
        StyleColor(red: 0.75, green: 0.85, blue: 0.75, alpha: 1),
        StyleColor(red: 0.55, green: 0.6, blue: 0.65, alpha: 1),
        StyleColor(red: 0.9, green: 0.86, blue: 0.55, alpha: 1),
        StyleColor(red: 0.85, green: 0.35, blue: 0.3, alpha: 1),
    ]
}

/// A solid 3D extrusion: many silhouette copies stepping back along an angle,
/// filling the space into connected depth (the chunky metallic-title look).
/// Distinct from ``HardShadowStyle`` (one detached copy) — this one is solid
/// all the way back.
public struct ExtrudeStyle: Codable, Equatable, Hashable, Sendable {

    /// The side-wall color of the extrusion.
    public var color: StyleColor

    /// How far back the depth extends, in reference points.
    public var depth: CGFloat

    /// The depth direction in degrees (`0` = right, `90` = up; the default
    /// `-45` throws the depth down-and-right).
    public var angle: CGFloat

    /// Darkening toward the back, `0…1` — the far wall is `color` scaled by
    /// `1 - fade`. `nil`/`0` = flat color all the way back.
    public var fade: CGFloat?

    public init(
        color: StyleColor = StyleColor.black,
        depth: CGFloat = 16,
        angle: CGFloat = -45,
        fade: CGFloat? = 0.35
    ) {
        self.color = color
        self.depth = depth
        self.angle = angle
        self.fade = fade
    }
}

/// A hard (un-blurred) offset copy of the text, sitting behind the fill — the
/// solid colored drop of a sticker caption. Unlike ``ShadowStyle`` it has no
/// blur; it's a crisp silhouette offset by a fixed amount.
public struct HardShadowStyle: Codable, Equatable, Hashable, Sendable {

    /// The drop color.
    public var color: StyleColor

    /// The horizontal offset in reference points (positive = right).
    public var offsetX: CGFloat

    /// The vertical offset in reference points (positive = down).
    public var offsetY: CGFloat

    public init(
        color: StyleColor = StyleColor.black,
        offsetX: CGFloat = 7,
        offsetY: CGFloat = 7
    ) {
        self.color = color
        self.offsetX = offsetX
        self.offsetY = offsetY
    }
}

/// A photo/image clipped inside caption glyphs (see ``CaptionStyle/imageFill``
/// and ``WordStyle/imageFill``). The image is aspect-filled into the target
/// rect — the whole block for a global fill, or a single word's frame for a
/// per-word fill — then masked to the letterforms.
public struct ImageFill: Codable, Equatable, Hashable, Sendable {

    /// A file URL to the image (any format `ImageIO` reads; the first frame of
    /// an animation is used).
    public var url: URL

    public init(url: URL) {
        self.url = url
    }
}

/// One outline in a stack of stacked strokes (see
/// ``CaptionStyle/strokeLayers``). Layers are drawn widest-first, so a later
/// (narrower) layer paints over the wider ones beneath it.
public struct StrokeLayer: Codable, Equatable, Hashable, Sendable {

    /// The outline color.
    public var color: StyleColor

    /// The outline width in reference points (1920-tall frame).
    public var width: CGFloat

    public init(color: StyleColor = .black, width: CGFloat = 6) {
        self.color = color
        self.width = width
    }
}

/// A linear gradient across the whole caption block. Stops spread evenly
/// from start to end.
public struct GradientFill: Codable, Equatable, Hashable, Sendable {

    /// The gradient stops, in order. Two or more.
    public var colors: [StyleColor]

    /// Direction in degrees: `0` = left→right, `90` = bottom→top.
    public var angle: CGFloat

    /// Hue drift: every stop's hue rotates continuously at this many
    /// cycles per second (the slow iridescent shimmer). Deterministic in
    /// absolute time, so preview and export match. `nil`/`0` = static.
    public var drift: CGFloat?

    public init(colors: [StyleColor] = [.yellow, .pink], angle: CGFloat = 90, drift: CGFloat? = nil) {
        self.colors = colors
        self.angle = angle
        self.drift = drift
    }
}

/// A solid colored frame drawn around the whole video edge.
public struct BorderStyle: Codable, Equatable, Sendable {

    /// The border color.
    public var color: StyleColor

    /// Thickness in reference points (against the 1920-tall frame).
    public var width: CGFloat

    public init(color: StyleColor = .white, width: CGFloat = 24) {
        self.color = color
        self.width = width
    }
}

/// A luminous bloom around caption text — the lyric-video look. Rendered as
/// stacked zero-offset shadow passes, so it blooms evenly in every direction
/// (unlike ``ShadowStyle``, which drops behind the text).
public struct GlowStyle: Codable, Equatable, Hashable, Sendable {

    /// What glows.
    public enum Scope: String, Codable, CaseIterable, Sendable {

        /// Every visible word glows — the music-lyric title look.
        case allWords = "all-words"

        /// Only the currently-spoken word blooms, riding the highlight.
        case activeWord = "active-word"
    }

    /// The halo color (often white, whatever the text color).
    public var color: StyleColor

    /// The bloom radius in reference points.
    public var radius: CGFloat

    /// Halo density `0…1` — more intensity stacks more bloom passes.
    public var intensity: CGFloat

    public var scope: Scope

    public init(
        color: StyleColor = .white,
        radius: CGFloat = 18,
        intensity: CGFloat = 0.6,
        scope: Scope = .allWords
    ) {
        self.color = color
        self.radius = radius
        self.intensity = intensity
        self.scope = scope
    }
}

/// A rounded background behind caption text.
public struct BackgroundStyle: Codable, Equatable, Hashable, Sendable {

    /// Whether the background wraps each line, the whole block, or every
    /// word in its own chip (the message-bubble look).
    public enum Mode: String, Codable, CaseIterable, Sendable {
        case perLine = "per-line"
        case block
        case perWord = "per-word"
    }

    /// The background's silhouette.
    public enum Shape: String, Codable, CaseIterable, Sendable {
        /// The classic rounded pill/box.
        case rounded
        /// A rough, seeded highlighter swipe — jittered edges and a slight
        /// skew, like a marker dragged behind the words.
        case marker
    }

    public var color: StyleColor
    public var cornerRadius: CGFloat
    public var paddingHorizontal: CGFloat
    public var paddingVertical: CGFloat
    public var mode: Mode

    /// An outline around the pill/box, or `nil` for none. With a transparent
    /// ``color`` this gives the stroked-only button look ("SHOP NOW").
    public var strokeColor: StyleColor?

    /// The outline width in reference points. `nil` = a hairline default
    /// when ``strokeColor`` is set.
    public var strokeWidth: CGFloat?

    /// The background's silhouette. `nil` = ``Shape/rounded``.
    public var shape: Shape?

    /// Animated draw-on: the background sweeps in left→right over each
    /// card's first beats (the highlighter being dragged). `nil`/`false` =
    /// it's simply there.
    public var drawOn: Bool?

    /// A comic speech-bubble tail on the bottom edge (per-line and block
    /// modes). `nil`/`false` = none.
    public var tail: Bool?

    public init(
        color: StyleColor = StyleColor.black.withAlpha(0.55),
        cornerRadius: CGFloat = 18,
        paddingHorizontal: CGFloat = 26,
        paddingVertical: CGFloat = 8,
        mode: Mode = .perLine,
        strokeColor: StyleColor? = nil,
        strokeWidth: CGFloat? = nil,
        shape: Shape? = nil,
        drawOn: Bool? = nil,
        tail: Bool? = nil
    ) {
        self.color = color
        self.cornerRadius = cornerRadius
        self.paddingHorizontal = paddingHorizontal
        self.paddingVertical = paddingVertical
        self.mode = mode
        self.strokeColor = strokeColor
        self.strokeWidth = strokeWidth
        self.shape = shape
        self.drawOn = drawOn
        self.tail = tail
    }
}
