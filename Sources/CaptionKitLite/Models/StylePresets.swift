//
//  StylePresets.swift
//  CaptionKitLite
//
//  Created by David Sherlock on 2026.
//
//  The built-in caption style catalog and the one-tap per-word looks —
//  pure data over kit types, shared by every app shell (macOS, iOS) and
//  smoke-tested here so a preset can never silently stop rendering.
//

import CoreGraphics
import Foundation

/// One-click looks. Applying keeps the user's caption position.
public enum StylePresets {

    public static let all: [(name: String, style: CaptionStyle)] = [
        ("Karaoke", karaoke),
        ("Boxed", boxed),
        ("One Word", oneWord),
        ("Party", party),
        ("Wave", waveStyle),
        ("Underline", underline),
        ("Clean Pop", cleanPop),
        ("Gradient", gradientPop),
        ("Inverse", inverse),
        ("Sunset", gradientSunset),
        ("Aqua", gradientAqua),
        ("Mint", gradientMint),
        ("Ember", gradientEmber),
        ("Hype", hype),
        ("Minimal", minimal),
        ("Comic", comic),
        ("Elegant", elegant),
        ("Neon Glow", neonGlow),
        ("Lyric", lyric),
        ("Hollow", hollow),
        ("Poster Red", posterRed),
        ("Poster Yellow", posterYellow),
        ("Statement", statement),
        ("Hormozi", hormozi),
        ("Beast", beast),
        ("Chips", chips),
        ("Quiz Pop", quizPop),
        ("Messages", messages),
        ("Closed Cap", closedCap),
        ("Headline", headline),
        ("Magazine", magazine),
        ("Doodle", doodle),
        ("Techwave", techwave),
        ("Nova", nova),
        ("Focus", focus),
        ("Stamp", stamp),
        ("Outline Fill", outlineFill),
        ("Outline Red", outlineRed),
        ("Impact", impact),
        ("Bubble", bubble),
        ("Retro", retro),
        ("Shadowline", shadowline),
        ("Whisper", whisper),
        ("Gamer", gamer),
        ("Neon", neon),
        ("Ocean", ocean),
        ("Candy", candy),
        ("Inferno", inferno),
        ("Golden", golden),
        ("Typist", typist),
    ]

    /// The music-lyric-video look: heavy italic yellow, every whole line on
    /// at once, and the spoken word blooming white.
    public static var lyric: CaptionStyle {
        var style = CaptionStyle()
        style.textTransform = .uppercase
        style.fontWeight = .black
        style.fontSize = 88
        style.slant = 0.25
        style.textColor = .yellow
        style.strokeColor = nil
        style.strokeWidth = 0
        style.shadow = nil
        style.glow = GlowStyle(color: .white, radius: 16, intensity: 0.7, scope: .activeWord)
        style.wordAnimation = .none
        style.highlightMode = .activeWord
        style.activeWordColor = .white
        style.activeWordScale = 1
        style.background = nil
        return style
    }

    /// Outline-only italic caps with a soft halo; karaoke fills the hollow
    /// letters in as they're spoken.
    public static var hollow: CaptionStyle {
        var style = CaptionStyle()
        style.textTransform = .uppercase
        style.fontWeight = .black
        style.fontSize = 92
        style.slant = 0.25
        style.textColor = StyleColor.white.withAlpha(0)
        style.strokeColor = .white
        style.strokeWidth = 4
        style.shadow = nil
        style.glow = GlowStyle(color: .white, radius: 12, intensity: 0.4, scope: .allWords)
        style.wordAnimation = .fadeIn
        style.highlightMode = .karaoke
        style.activeWordColor = .white
        style.activeWordScale = 1
        style.background = nil
        return style
    }

    /// THE clip-caption look: a colored box hops onto each spoken word,
    /// cycling green/yellow/red/purple — box carries the color, text stays
    /// flat white.
    public static var hormozi: CaptionStyle {
        var style = CaptionStyle()
        style.textTransform = .uppercase
        style.fontWeight = .black
        style.fontSize = 88
        style.strokeColor = .black
        style.strokeWidth = 7
        style.shadow = nil
        style.wordAnimation = .popOn
        style.highlightMode = .activeBox
        style.wordColorPalette = [
            StyleColor(hex: "#2ECC40")!, StyleColor(hex: "#FFDC00")!,
            StyleColor(hex: "#FF4136")!, StyleColor(hex: "#B10DC9")!,
        ]
        style.activeWordScale = 1.06
        style.background = nil
        return style
    }

    /// Chunky thumbnail energy: fat yellow caps in a thick black outline.
    public static var beast: CaptionStyle {
        var style = CaptionStyle()
        style.textTransform = .uppercase
        style.fontWeight = .black
        style.fontSize = 96
        style.textColor = StyleColor(hex: "#FFDC00")!
        style.strokeColor = .black
        style.strokeWidth = 11
        style.shadow = ShadowStyle(color: StyleColor.black.withAlpha(0.4), radius: 0, offsetX: 4, offsetY: 6)
        style.wordAnimation = .drop
        style.highlightMode = .activeWord
        style.activeWordColor = StyleColor(hex: "#FF4136")!
        style.background = nil
        return style
    }

    /// Every word in its own white chip — clean product-video captions.
    public static var chips: CaptionStyle {
        var style = CaptionStyle()
        style.fontWeight = .semibold
        style.fontSize = 66
        style.textColor = StyleColor(hex: "#141414")!
        style.strokeColor = nil
        style.strokeWidth = 0
        style.shadow = nil
        style.wordAnimation = .fadeIn
        style.highlightMode = .none
        style.activeWordScale = 1
        style.background = BackgroundStyle(
            color: StyleColor.white.withAlpha(0.94),
            cornerRadius: 14,
            paddingHorizontal: 18,
            paddingVertical: 8,
            mode: .perWord
        )
        return style
    }

    /// The language-app quiz look: rounded white type on bright green word
    /// tiles, bouncing on per word.
    public static var quizPop: CaptionStyle {
        var style = CaptionStyle()
        style.fontFamily = "Arial Rounded MT Bold"
        style.fontWeight = .bold
        style.fontSize = 62
        style.textColor = .white
        style.strokeColor = nil
        style.strokeWidth = 0
        style.shadow = ShadowStyle(color: StyleColor.black.withAlpha(0.22), radius: 5, offsetY: 3)
        style.wordAnimation = .bounceIn
        style.highlightMode = .activeWord
        style.activeWordColor = StyleColor(hex: "#FFF6C6")!
        style.activeWordScale = 1.06
        style.background = BackgroundStyle(
            color: StyleColor(hex: "#58CC02")!,
            cornerRadius: 16,
            paddingHorizontal: 20,
            paddingVertical: 10,
            mode: .perWord
        )
        return style
    }

    /// iMessage-blue word bubbles.
    public static var messages: CaptionStyle {
        var style = chips
        style.textColor = .white
        style.background = BackgroundStyle(
            color: StyleColor(hex: "#0A84FF")!,
            cornerRadius: 20,
            paddingHorizontal: 20,
            paddingVertical: 9,
            mode: .perWord
        )
        style.wordAnimation = .slideUp
        return style
    }

    /// Broadcast closed-caption: mono type on a hard black band, zero
    /// animation — the accessibility-forward look.
    public static var closedCap: CaptionStyle {
        var style = CaptionStyle()
        style.fontFamily = "Courier New"
        style.fontWeight = .bold
        style.fontSize = 62
        style.strokeColor = nil
        style.strokeWidth = 0
        style.shadow = nil
        style.wordAnimation = .none
        style.highlightMode = .none
        style.activeWordScale = 1
        style.background = BackgroundStyle(
            color: StyleColor.black.withAlpha(0.85),
            cornerRadius: 0,
            paddingHorizontal: 20,
            paddingVertical: 8,
            mode: .perLine
        )
        return style
    }

    /// Tabloid banner: black caps on a white block, red spoken word.
    public static var headline: CaptionStyle {
        var style = CaptionStyle()
        style.textTransform = .uppercase
        style.fontWeight = .black
        style.fontSize = 74
        style.textColor = .black
        style.strokeColor = nil
        style.strokeWidth = 0
        style.shadow = nil
        style.wordAnimation = .none
        style.highlightMode = .activeWord
        style.activeWordColor = StyleColor(hex: "#D0021B")!
        style.activeWordScale = 1
        style.background = BackgroundStyle(
            color: .white,
            cornerRadius: 4,
            paddingHorizontal: 26,
            paddingVertical: 10,
            mode: .block
        )
        return style
    }

    /// Editorial serif — fashion-film elegance.
    public static var magazine: CaptionStyle {
        var style = CaptionStyle()
        style.fontFamily = "Georgia"
        style.fontWeight = .semibold
        style.fontSize = 66
        style.letterSpacing = 2
        style.strokeColor = nil
        style.strokeWidth = 0
        style.shadow = ShadowStyle(color: StyleColor.black.withAlpha(0.55), radius: 14, offsetY: 2)
        style.wordAnimation = .fadeIn
        style.animationDuration = 0.3
        style.highlightMode = .none
        style.activeWordScale = 1
        style.background = nil
        return style
    }

    /// Hand-drawn marker captions that wiggle like a sketchbook.
    public static var doodle: CaptionStyle {
        var style = CaptionStyle()
        style.fontFamily = "Bradley Hand"
        style.fontWeight = .bold
        style.fontSize = 82
        style.strokeColor = nil
        style.strokeWidth = 0
        style.shadow = ShadowStyle(color: StyleColor.black.withAlpha(0.5), radius: 8, offsetY: 3)
        style.wordAnimation = .popOn
        style.wordLoop = .wiggle
        style.highlightMode = .activeWord
        style.activeWordColor = .yellow
        style.background = nil
        return style
    }

    /// Cyber terminal: cyan mono-ish caps with scanlines and a color split.
    public static var techwave: CaptionStyle {
        var style = CaptionStyle()
        style.fontFamily = "Futura"
        style.fontWeight = .medium
        style.fontSize = 72
        style.textTransform = .uppercase
        style.letterSpacing = 4
        style.textColor = StyleColor(hex: "#00E5FF")!
        style.strokeColor = nil
        style.strokeWidth = 0
        style.shadow = nil
        style.scanlineIntensity = 0.5
        style.chromaticAberration = 2
        style.wordAnimation = .typewriter
        style.highlightMode = .activeWord
        style.activeWordColor = .white
        style.background = nil
        return style
    }

    /// Violet→cyan gradient with a soft halo — the dreamy title feed look.
    public static var nova: CaptionStyle {
        var style = CaptionStyle()
        style.textTransform = .uppercase
        style.fontWeight = .black
        style.fontSize = 86
        style.strokeColor = nil
        style.strokeWidth = 0
        style.shadow = nil
        style.textGradient = GradientFill(
            colors: [StyleColor(hex: "#8A2BE2")!, StyleColor(hex: "#00E5FF")!],
            angle: 45
        )
        style.glow = GlowStyle(color: StyleColor(hex: "#9C7BFF")!, radius: 14, intensity: 0.45, scope: .allWords)
        style.wordAnimation = .popOn
        style.highlightMode = .none
        style.activeWordScale = 1
        style.background = nil
        return style
    }

    /// Spotlight focus: the spoken word stays lit, the rest dims — calm
    /// authority for educational clips.
    public static var focus: CaptionStyle {
        var style = CaptionStyle()
        style.fontWeight = .heavy
        style.fontSize = 80
        style.strokeColor = nil
        style.strokeWidth = 0
        style.shadow = ShadowStyle(color: StyleColor.black.withAlpha(0.6), radius: 10, offsetY: 3)
        style.wordAnimation = .none
        style.highlightMode = .spotlight
        style.activeWordColor = .white
        style.activeWordScale = 1.05
        style.background = nil
        return style
    }

    /// Tilted red rubber-stamp slam.
    public static var stamp: CaptionStyle {
        var style = CaptionStyle()
        style.textTransform = .uppercase
        style.fontWeight = .black
        style.fontSize = 92
        style.textColor = StyleColor(hex: "#D62828")!
        style.strokeColor = nil
        style.strokeWidth = 0
        style.shadow = nil
        style.blockRotation = -0.06
        style.wordAnimation = .stomp
        style.highlightMode = .none
        style.activeWordScale = 1
        style.background = nil
        return style
    }

    /// The music-video reveal: every word a hollow outline, and ONLY the
    /// spoken word fills solid — lighting up word by word as she talks.
    public static var outlineFill: CaptionStyle {
        var style = CaptionStyle()
        style.textTransform = .uppercase
        style.fontWeight = .black
        style.fontSize = 90
        style.slant = 0.25
        style.textColor = StyleColor.white.withAlpha(0)
        style.strokeColor = .white
        style.strokeWidth = 4
        style.shadow = nil
        style.glow = GlowStyle(color: .white, radius: 12, intensity: 0.5, scope: .activeWord)
        style.wordAnimation = .none
        style.highlightMode = .activeWord
        style.activeWordColor = .white
        style.activeWordScale = 1.08
        style.background = nil
        return style
    }

    /// The rap-clip reveal: hollow white outlines, spoken word slams in
    /// SOLID RED — upright, no glow, pure attitude.
    public static var outlineRed: CaptionStyle {
        var style = outlineFill
        style.slant = nil
        style.strokeWidth = 5
        style.glow = nil
        style.activeWordColor = StyleColor(hex: "#E8352E")!
        style.activeWordScale = 1.05
        return style
    }

    /// The statement-poster look: flat bold caps stacked one word per
    /// line, left-aligned in the frame's upper third — big, loud, editorial.
    public static var posterRed: CaptionStyle {
        var style = CaptionStyle()
        style.textTransform = .uppercase
        style.fontWeight = .black
        style.fontSize = 118
        style.lineSpacing = 0.92
        style.textColor = StyleColor(hex: "#E02A2A")!
        style.strokeColor = nil
        style.strokeWidth = 0
        style.shadow = ShadowStyle(color: StyleColor.black.withAlpha(0.35), radius: 6, offsetY: 4)
        style.alignment = .leading
        style.position = NormalizedPoint(x: 0.42, y: 0.3)
        style.wordAnimation = .slideUp
        style.animationDuration = 0.22
        style.highlightMode = .none
        style.activeWordScale = 1
        style.background = nil
        return style
    }

    public static var posterYellow: CaptionStyle {
        var style = posterRed
        style.textColor = StyleColor(hex: "#FFD60A")!
        style.shadow = ShadowStyle(color: StyleColor.black.withAlpha(0.45), radius: 8, offsetY: 5)
        return style
    }

    /// The "THIS IS A MESSAGE" look: heavy red caps, left-aligned, normal
    /// multi-word lines (no one-word grouping). Pairs with the Noir look.
    public static var statement: CaptionStyle {
        var style = CaptionStyle()
        style.textTransform = .uppercase
        style.fontWeight = .black
        style.fontSize = 104
        style.lineSpacing = 0.98
        style.textColor = StyleColor(hex: "#E01E1E")!
        style.strokeColor = nil
        style.strokeWidth = 0
        style.shadow = ShadowStyle(color: StyleColor.black.withAlpha(0.4), radius: 5, offsetY: 3)
        style.alignment = .leading
        style.position = NormalizedPoint(x: 0.4, y: 0.5)
        style.wordAnimation = .none
        style.highlightMode = .none
        style.activeWordScale = 1
        style.background = nil
        return style
    }

    public static var impact: CaptionStyle {
        var style = CaptionStyle()
        style.textTransform = .uppercase
        style.fontSize = 94
        style.strokeColor = nil
        style.strokeWidth = 0
        style.shadow = ShadowStyle(radius: 12, offsetY: 4)
        style.wordAnimation = .drop
        style.highlightMode = .activeBox
        style.activeWordColor = .red
        style.background = nil
        return style
    }

    public static var bubble: CaptionStyle {
        var style = CaptionStyle()
        style.fontWeight = .heavy
        style.fontSize = 76
        style.textColor = StyleColor(hex: "#1A1A2E")!
        style.strokeColor = nil
        style.strokeWidth = 0
        style.wordAnimation = .popOn
        style.highlightMode = .activeWord
        style.activeWordColor = .pink
        style.background = BackgroundStyle(
            color: StyleColor.white.withAlpha(0.92),
            cornerRadius: 26,
            paddingHorizontal: 30,
            paddingVertical: 10
        )
        return style
    }

    public static var retro: CaptionStyle {
        var style = CaptionStyle()
        style.fontFamily = "American Typewriter"
        style.fontWeight = .bold
        style.fontSize = 78
        style.wordAnimation = .slideUp
        style.wordLoop = .wave
        style.highlightMode = .activeUnderline
        style.activeWordColor = .orange
        style.wordColorPalette = [.orange, StyleColor(hex: "#F5E6C8")!, .pink, .yellow]
        style.strokeColor = StyleColor(hex: "#3B2416")
        style.strokeWidth = 5
        style.background = nil
        return style
    }

    public static var shadowline: CaptionStyle {
        var style = CaptionStyle()
        style.textTransform = .uppercase
        style.fontSize = 96
        style.textColor = .yellow
        style.strokeColor = nil
        style.strokeWidth = 0
        // Hard offset shadow, zero blur — the sticker-text look.
        style.shadow = ShadowStyle(color: .black, radius: 0, offsetX: 6, offsetY: 7)
        style.wordAnimation = .slideUp
        style.highlightMode = .activeWord
        style.activeWordColor = .white
        style.background = nil
        return style
    }

    public static var whisper: CaptionStyle {
        var style = CaptionStyle()
        style.fontWeight = .medium
        style.fontSize = 56
        style.textTransform = .lowercase
        style.letterSpacing = 6
        style.strokeColor = nil
        style.strokeWidth = 0
        style.shadow = ShadowStyle(color: StyleColor.black.withAlpha(0.7), radius: 18, offsetY: 0)
        style.wordAnimation = .fadeIn
        style.highlightMode = .none
        style.activeWordScale = 1
        style.animationDuration = 0.35
        style.background = nil
        return style
    }

    public static var gamer: CaptionStyle {
        var style = CaptionStyle()
        style.fontFamily = "Menlo"
        style.fontWeight = .bold
        style.fontSize = 72
        style.textTransform = .uppercase
        style.wordAnimation = .typewriter
        style.highlightMode = .activeBox
        style.activeWordColor = StyleColor(hex: "#00C7BE")!
        style.wordColorPalette = [.green, StyleColor(hex: "#4FD8FF")!, .white]
        style.strokeColor = nil
        style.strokeWidth = 0
        style.background = BackgroundStyle(color: StyleColor.black.withAlpha(0.8), cornerRadius: 8)
        return style
    }

    public static var comic: CaptionStyle {
        var style = CaptionStyle()
        style.fontFamily = "Marker Felt"
        style.textTransform = .uppercase
        style.fontSize = 92
        style.strokeWidth = 8
        style.wordAnimation = .rotateIn
        style.wordLoop = .wiggle
        style.highlightMode = .activeWord
        style.activeWordColor = .orange
        style.background = nil
        return style
    }

    public static var elegant: CaptionStyle {
        var style = CaptionStyle()
        style.fontFamily = "Georgia"
        style.fontWeight = .semibold
        style.fontSize = 72
        style.letterSpacing = 2
        style.strokeColor = nil
        style.strokeWidth = 0
        style.shadow = ShadowStyle(color: StyleColor.black.withAlpha(0.5), radius: 16, offsetY: 3)
        style.wordAnimation = .fadeIn
        style.highlightMode = .activeUnderline
        style.activeWordColor = StyleColor(hex: "#F5E6C8") ?? .white
        style.activeWordScale = 1
        style.background = nil
        return style
    }

    public static var neonGlow: CaptionStyle {
        var style = CaptionStyle()
        style.textTransform = .uppercase
        style.fontSize = 88
        style.strokeColor = nil
        style.strokeWidth = 0
        // No stroke, no pill — the glow IS a zero-offset colored shadow.
        style.shadow = ShadowStyle(color: StyleColor.green.withAlpha(0.9), radius: 26, offsetX: 0, offsetY: 0)
        style.wordAnimation = .fadeIn
        style.highlightMode = .activeWord
        style.activeWordColor = .green
        style.background = nil
        return style
    }

    public static var neon: CaptionStyle {
        var style = cleanPop
        style.textColor = StyleColor(hex: "#EAFFEA") ?? .white
        style.activeWordColor = .green
        style.wordAnimation = .spring
        return style
    }

    public static var ocean: CaptionStyle {
        var style = karaoke
        style.activeWordColor = StyleColor(hex: "#4FD8FF") ?? .blue
        style.background = BackgroundStyle(color: StyleColor(hex: "#0A2540")?.withAlpha(0.6) ?? StyleColor.black.withAlpha(0.55))
        style.wordAnimation = .slideUp
        return style
    }

    public static var candy: CaptionStyle {
        var style = cleanPop
        style.textColor = .white
        style.activeWordColor = .pink
        style.wordAnimation = .bounceIn
        style.strokeColor = StyleColor(hex: "#5B1140")
        return style
    }

    public static var inferno: CaptionStyle {
        var style = hype
        style.textColor = .white
        style.activeWordColor = .orange
        style.wordAnimation = .stomp
        style.cardAnimation = .none
        return style
    }

    public static var golden: CaptionStyle {
        var style = karaoke
        style.textColor = .yellow
        style.activeWordColor = .white
        style.background = BackgroundStyle(color: StyleColor.black.withAlpha(0.7))
        return style
    }

    public static var typist: CaptionStyle {
        var style = CaptionStyle()
        style.fontFamily = "Courier New"
        style.fontWeight = .bold
        style.fontSize = 72
        style.textTransform = .lowercase
        style.wordAnimation = .typewriter
        style.highlightMode = .activeWord
        style.activeWordColor = .green
        style.strokeColor = nil
        style.strokeWidth = 0
        style.background = BackgroundStyle(color: StyleColor.black.withAlpha(0.75), cornerRadius: 6)
        return style
    }

    public static var karaoke: CaptionStyle {
        var style = CaptionStyle()
        style.textTransform = .uppercase
        style.highlightMode = .karaoke
        style.activeWordColor = .yellow
        style.activeWordScale = 1.1
        style.background = BackgroundStyle()
        return style
    }

    public static var boxed: CaptionStyle {
        var style = CaptionStyle()
        style.textTransform = .uppercase
        style.fontSize = 88
        style.strokeColor = nil
        style.strokeWidth = 0
        style.shadow = ShadowStyle(radius: 14, offsetY: 5)
        style.highlightMode = .activeBox
        style.activeWordColor = .green
        style.activeWordScale = 1.06
        style.background = nil
        return style
    }

    /// Presets that also change how words are grouped (applied via
    /// regroup when selected).
    /// Stacked one-word-per-line grouping — the poster/statement format.
    private static let stackedRules = GroupingRules(
        maxLinesPerCard: 4,
        maxWordsPerLine: 1,
        maxCharactersPerLine: 14,
        pauseThreshold: 0.7,
        minCardDuration: 1.0,
        maxHoldAfterLastWord: 0.25
    )

    /// The curated shelf the gallery shows by default — the strongest,
    /// most distinct looks. Everything else stays one "Show All" away;
    /// nothing is removed (presets are user-facing capability, not just
    /// browsing chrome).
    public static let featured: [String] = [
        "Karaoke", "Boxed", "One Word", "Clean Pop", "Hormozi", "Beast",
        "Chips", "Quiz Pop", "Messages", "Headline", "Magazine", "Doodle",
        "Techwave", "Nova", "Neon Glow", "Elegant", "Comic", "Poster Red",
        "Statement", "Hollow", "Bubble", "Retro", "Gradient", "Minimal",
    ]

    public static let groupingHints: [String: GroupingRules] = [
        "One Word": GroupingRules(
            maxLinesPerCard: 1,
            maxWordsPerLine: 1,
            maxCharactersPerLine: 24,
            pauseThreshold: 0.6,
            minCardDuration: 0.25,
            maxHoldAfterLastWord: 0.15
        ),
        "Poster Red": stackedRules,
        "Poster Yellow": stackedRules,
    ]

    public static var oneWord: CaptionStyle {
        var style = CaptionStyle()
        style.textTransform = .uppercase
        style.fontSize = 130
        style.strokeWidth = 9
        style.wordAnimation = .stomp
        style.highlightMode = .none
        style.wordColorPalette = [.white, .yellow, .white, StyleColor(hex: "#4FD8FF")!]
        style.position = NormalizedPoint(x: 0.5, y: 0.5)
        style.background = nil
        return style
    }

    public static var waveStyle: CaptionStyle {
        var style = CaptionStyle()
        style.textTransform = .uppercase
        style.fontSize = 88
        style.strokeWidth = 8
        style.wordLoop = .wave
        style.highlightMode = .karaoke
        style.activeWordColor = .yellow
        style.background = nil
        return style
    }

    public static var underline: CaptionStyle {
        // No pill — the pill and the underline fought each other. Clean
        // heavy white on a soft shadow, yellow bar riding the spoken word.
        var style = CaptionStyle()
        style.fontSize = 84
        style.fontWeight = .heavy
        style.strokeColor = nil
        style.strokeWidth = 0
        style.shadow = ShadowStyle(color: StyleColor.black.withAlpha(0.65), radius: 12, offsetY: 3)
        style.wordAnimation = .fadeIn
        style.highlightMode = .activeUnderline
        style.activeWordColor = .yellow
        style.activeWordScale = 1.04
        style.background = nil
        return style
    }

    public static var party: CaptionStyle {
        var style = CaptionStyle()
        style.textTransform = .uppercase
        style.fontSize = 90
        style.strokeWidth = 8
        style.wordAnimation = .bounceIn
        style.highlightMode = .none
        style.wordColorPalette = [.yellow, StyleColor(hex: "#4FD8FF")!, .green, .pink]
        style.background = nil
        return style
    }

    public static var cleanPop: CaptionStyle {
        var style = CaptionStyle()
        style.textTransform = .uppercase
        style.fontSize = 92
        style.strokeWidth = 8
        style.wordAnimation = .popOn
        style.highlightMode = .activeWord
        style.activeWordColor = .yellow
        style.activeWordScale = 1.12
        style.background = nil
        return style
    }

    /// Clean white caps with the spoken word in a gradient pill (the "video
    /// captions" app-store look). Each variant just swaps the two gradient
    /// stops.
    public static func gradientStyle(_ hexA: String, _ hexB: String) -> CaptionStyle {
        var style = CaptionStyle()
        style.textTransform = .uppercase
        style.fontWeight = .bold
        style.fontSize = 90
        style.strokeColor = nil
        style.shadow = ShadowStyle(color: StyleColor.black.withAlpha(0.45), radius: 9, offsetX: 0, offsetY: 4)
        style.wordAnimation = .popOn
        style.highlightMode = .activeBox
        style.activeWordColor = StyleColor(hex: hexA)
        style.activeBoxGradient = GradientFill(
            colors: [StyleColor(hex: hexA)!, StyleColor(hex: hexB)!],
            angle: 0
        )
        style.activeBoxPadH = 0.22
        style.activeBoxPadV = 0.16
        style.activeWordScale = 1.04
        style.background = nil
        return style
    }

    /// Inverse highlight: white caps with the spoken word in a WHITE pill and
    /// dark text (the fourth app-store tile).
    public static var inverse: CaptionStyle {
        var style = CaptionStyle()
        style.textTransform = .uppercase
        style.fontWeight = .bold
        style.fontSize = 90
        style.strokeColor = nil
        style.shadow = ShadowStyle(color: StyleColor.black.withAlpha(0.45), radius: 9, offsetX: 0, offsetY: 4)
        style.wordAnimation = .popOn
        style.highlightMode = .activeBox
        style.activeWordColor = .white
        style.activeBoxTextColor = StyleColor(red: 0.08, green: 0.08, blue: 0.1)
        style.activeBoxPadH = 0.22
        style.activeBoxPadV = 0.16
        style.activeWordScale = 1.04
        style.background = nil
        return style
    }

    public static var gradientPop: CaptionStyle { gradientStyle("#7B2FF7", "#E93FD8") } // purple → magenta
    public static var gradientSunset: CaptionStyle { gradientStyle("#FF7A00", "#FF2D75") } // orange → pink
    public static var gradientAqua: CaptionStyle { gradientStyle("#00C6FB", "#005BEA") } // cyan → blue
    public static var gradientMint: CaptionStyle { gradientStyle("#00F5A0", "#00A3D9") } // green → teal
    public static var gradientEmber: CaptionStyle { gradientStyle("#F83600", "#FEB800") } // red → amber

    public static var hype: CaptionStyle {
        var style = CaptionStyle()
        style.textTransform = .uppercase
        style.fontSize = 96
        style.strokeWidth = 9
        style.cardAnimation = .stomp
        style.highlightMode = .karaoke
        style.activeWordColor = .yellow
        style.background = nil
        return style
    }

    public static var minimal: CaptionStyle {
        var style = CaptionStyle()
        style.fontWeight = .semibold
        style.fontSize = 68
        style.strokeColor = nil
        style.strokeWidth = 0
        style.wordAnimation = .fadeIn
        style.highlightMode = .none
        style.activeWordScale = 1
        style.background = BackgroundStyle(
            color: StyleColor.black.withAlpha(0.4),
            cornerRadius: 12,
            paddingHorizontal: 20,
            paddingVertical: 6,
            mode: .perLine
        )
        return style
    }
}

/// One-click per-word style presets for the Word inspector's "Looks" row —
/// each sets the whole selected word's ``WordStyle`` at once; a `nil` style
/// clears it. `WordLook.genius` is also what Auto-Emphasize (Genius Look)
/// stamps onto every word the emphasis suggester picks.
public enum WordLook {
    public static let gold = StyleColor(red: 1, green: 0.82, blue: 0.12)
    public static let amber = StyleColor(red: 0.95, green: 0.45, blue: 0.05)
    public static let red = StyleColor(red: 0.92, green: 0.12, blue: 0.15)
    public static let darkGold = StyleColor(red: 0.45, green: 0.30, blue: 0.02)

    public static let genius = WordStyle(
        color: gold,
        strokeLayers: [StrokeLayer(color: red, width: 24), StrokeLayer(color: .black, width: 10)],
        hardShadow: HardShadowStyle(color: red, offsetX: 8, offsetY: 9),
        rotation: 0.12,
        slant: 0.18
    )
    public static let gold3D = WordStyle(
        gradient: GradientFill(colors: [.white, gold], angle: 90),
        extrude: ExtrudeStyle(color: darkGold, depth: 18, angle: -45, fade: 0.45)
    )
    public static let gradient = WordStyle(
        gradient: GradientFill(colors: [gold, amber], angle: 90)
    )
    public static let pop = WordStyle(
        color: .white,
        strokeLayers: [StrokeLayer(color: red, width: 18), StrokeLayer(color: .black, width: 8)],
        rotation: -0.10
    )

    /// (label, style) pairs for the preset buttons; a `nil` style clears.
    public static let all: [(name: String, style: WordStyle?)] = [
        ("Genius", genius),
        ("Gold 3D", gold3D),
        ("Gradient", gradient),
        ("Pop", pop),
        ("Clear", nil),
    ]
}
