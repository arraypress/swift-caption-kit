//
//  PresetCatalogText.swift
//  CaptionStyles
//
//  Created by David Sherlock on 2026.
//
//  The built-in caption styles, as data. Compiled in as a string rather than
//  shipped as a resource: a resource bundle beside a Homebrew binary breaks
//  when the binary is reached through a symlink.
//
//  Each entry is a kebab-case name, a title for a picker, and a `style` that
//  lists only what differs from `CaptionStyle()` (a key set to null clears
//  an optional field). Colours are written `yellow`, `#FFDC00`, `black@0.4`
//  (alpha after the @) or as `{"red", "green", "blue", "alpha"}`. A `{slot}`
//  in a value is filled by `--var slot=value`: a `color` slot takes one
//  colour, a `colors` slot a comma list. `grouping` is how the style wants
//  words grouped into cards, when it differs from the defaults.
//
//  Checked by a test (`PresetCatalog.parsed.problems` must be empty): names
//  kebab-case and unique, every key a style field, every marker a slot and
//  every slot used, every default a colour that reads.
//

enum PresetCatalogText {

    /// Every group of presets, in gallery order.
    static let all = [presets]

    static let presets = #"""
    [
    {
      "name": "karaoke", "title": "Karaoke", "featured": true,
      "slots": [{"name": "accent", "kind": "color", "default": "yellow"}],
      "style": {"activeWordColor": "{accent}", "activeWordScale": 1.1, "background": {"color": "black@0.55", "cornerRadius": 18, "mode": "per-line", "paddingHorizontal": 26, "paddingVertical": 8}, "highlightMode": "karaoke", "textTransform": "uppercase"}
    },
    {
      "name": "boxed", "title": "Boxed", "featured": true,
      "slots": [{"name": "accent", "kind": "color", "default": "green"}],
      "style": {"activeWordColor": "{accent}", "activeWordScale": 1.06, "fontSize": 88, "highlightMode": "active-box", "shadow": {"color": "black@0.6", "offsetX": 0, "offsetY": 5, "radius": 14}, "strokeColor": null, "strokeWidth": 0, "textTransform": "uppercase"}
    },
    {
      "name": "one-word", "title": "One Word", "featured": true,
      "slots": [{"name": "palette", "kind": "colors", "default": "white,yellow,white,#4FD8FF"}],
      "grouping": {"maxCharactersPerLine": 24, "maxHoldAfterLastWord": 0.15, "maxLinesPerCard": 1, "maxWordsPerLine": 1, "minCardDuration": 0.25, "pauseThreshold": 0.6},
      "style": {"fontSize": 130, "highlightMode": "none", "position": {"x": 0.5, "y": 0.5}, "strokeWidth": 9, "textTransform": "uppercase", "wordAnimation": "stomp", "wordColorPalette": "{palette}"}
    },
    {
      "name": "party", "title": "Party",
      "slots": [{"name": "palette", "kind": "colors", "default": "yellow,#4FD8FF,green,pink"}],
      "style": {"fontSize": 90, "highlightMode": "none", "strokeWidth": 8, "textTransform": "uppercase", "wordAnimation": "bounce-in", "wordColorPalette": "{palette}"}
    },
    {
      "name": "wave", "title": "Wave",
      "slots": [{"name": "accent", "kind": "color", "default": "yellow"}],
      "style": {"activeWordColor": "{accent}", "fontSize": 88, "highlightMode": "karaoke", "strokeWidth": 8, "textTransform": "uppercase", "wordLoop": "wave"}
    },
    {
      "name": "underline", "title": "Underline",
      "slots": [{"name": "accent", "kind": "color", "default": "yellow"}],
      "style": {"activeWordColor": "{accent}", "activeWordScale": 1.04, "highlightMode": "active-underline", "shadow": {"color": "black@0.65", "offsetX": 0, "offsetY": 3, "radius": 12}, "strokeColor": null, "strokeWidth": 0, "wordAnimation": "fade-in"}
    },
    {
      "name": "clean-pop", "title": "Clean Pop", "featured": true,
      "slots": [{"name": "accent", "kind": "color", "default": "yellow"}],
      "style": {"activeWordColor": "{accent}", "activeWordScale": 1.12, "fontSize": 92, "strokeWidth": 8, "textTransform": "uppercase", "wordAnimation": "pop-on"}
    },
    {
      "name": "gradient", "title": "Gradient", "featured": true,
      "about": "Clean white caps with the spoken word in a gradient pill, purple to magenta.",
      "slots": [{"name": "from", "kind": "color", "default": "#7B2FF7"}, {"name": "to", "kind": "color", "default": "#E93FD8"}],
      "style": {"activeBoxGradient": {"angle": 0, "colors": ["{from}", "{to}"]}, "activeBoxPadH": 0.22, "activeBoxPadV": 0.16, "activeWordColor": "{from}", "activeWordScale": 1.04, "fontSize": 90, "fontWeight": "bold", "highlightMode": "active-box", "shadow": {"color": "black@0.45", "offsetX": 0, "offsetY": 4, "radius": 9}, "strokeColor": null, "textTransform": "uppercase", "wordAnimation": "pop-on"}
    },
    {
      "name": "inverse", "title": "Inverse",
      "about": "Inverse highlight: white caps with the spoken word in a WHITE pill and dark text (the fourth app-store tile).",
      "style": {"activeBoxPadH": 0.22, "activeBoxPadV": 0.16, "activeBoxTextColor": {"alpha": 1, "blue": 0.1, "green": 0.08, "red": 0.08}, "activeWordColor": "white", "activeWordScale": 1.04, "fontSize": 90, "fontWeight": "bold", "highlightMode": "active-box", "shadow": {"color": "black@0.45", "offsetX": 0, "offsetY": 4, "radius": 9}, "strokeColor": null, "textTransform": "uppercase", "wordAnimation": "pop-on"}
    },
    {
      "name": "sunset", "title": "Sunset",
      "about": "Clean white caps with the spoken word in a gradient pill, orange to pink.",
      "slots": [{"name": "from", "kind": "color", "default": "#FF7A00"}, {"name": "to", "kind": "color", "default": "#FF2D75"}],
      "style": {"activeBoxGradient": {"angle": 0, "colors": ["{from}", "{to}"]}, "activeBoxPadH": 0.22, "activeBoxPadV": 0.16, "activeWordColor": "{from}", "activeWordScale": 1.04, "fontSize": 90, "fontWeight": "bold", "highlightMode": "active-box", "shadow": {"color": "black@0.45", "offsetX": 0, "offsetY": 4, "radius": 9}, "strokeColor": null, "textTransform": "uppercase", "wordAnimation": "pop-on"}
    },
    {
      "name": "aqua", "title": "Aqua",
      "about": "Clean white caps with the spoken word in a gradient pill, cyan to blue.",
      "slots": [{"name": "from", "kind": "color", "default": "#00C6FB"}, {"name": "to", "kind": "color", "default": "#005BEA"}],
      "style": {"activeBoxGradient": {"angle": 0, "colors": ["{from}", "{to}"]}, "activeBoxPadH": 0.22, "activeBoxPadV": 0.16, "activeWordColor": "{from}", "activeWordScale": 1.04, "fontSize": 90, "fontWeight": "bold", "highlightMode": "active-box", "shadow": {"color": "black@0.45", "offsetX": 0, "offsetY": 4, "radius": 9}, "strokeColor": null, "textTransform": "uppercase", "wordAnimation": "pop-on"}
    },
    {
      "name": "mint", "title": "Mint",
      "about": "Clean white caps with the spoken word in a gradient pill, green to teal.",
      "slots": [{"name": "from", "kind": "color", "default": "#00F5A0"}, {"name": "to", "kind": "color", "default": "#00A3D9"}],
      "style": {"activeBoxGradient": {"angle": 0, "colors": ["{from}", "{to}"]}, "activeBoxPadH": 0.22, "activeBoxPadV": 0.16, "activeWordColor": "{from}", "activeWordScale": 1.04, "fontSize": 90, "fontWeight": "bold", "highlightMode": "active-box", "shadow": {"color": "black@0.45", "offsetX": 0, "offsetY": 4, "radius": 9}, "strokeColor": null, "textTransform": "uppercase", "wordAnimation": "pop-on"}
    },
    {
      "name": "ember", "title": "Ember",
      "about": "Clean white caps with the spoken word in a gradient pill, red to amber.",
      "slots": [{"name": "from", "kind": "color", "default": "#F83600"}, {"name": "to", "kind": "color", "default": "#FEB800"}],
      "style": {"activeBoxGradient": {"angle": 0, "colors": ["{from}", "{to}"]}, "activeBoxPadH": 0.22, "activeBoxPadV": 0.16, "activeWordColor": "{from}", "activeWordScale": 1.04, "fontSize": 90, "fontWeight": "bold", "highlightMode": "active-box", "shadow": {"color": "black@0.45", "offsetX": 0, "offsetY": 4, "radius": 9}, "strokeColor": null, "textTransform": "uppercase", "wordAnimation": "pop-on"}
    },
    {
      "name": "hype", "title": "Hype",
      "slots": [{"name": "accent", "kind": "color", "default": "yellow"}],
      "style": {"activeWordColor": "{accent}", "cardAnimation": "stomp", "fontSize": 96, "highlightMode": "karaoke", "strokeWidth": 9, "textTransform": "uppercase"}
    },
    {
      "name": "minimal", "title": "Minimal", "featured": true,
      "style": {"activeWordScale": 1, "background": {"color": "black@0.4", "cornerRadius": 12, "mode": "per-line", "paddingHorizontal": 20, "paddingVertical": 6}, "fontSize": 68, "fontWeight": "semibold", "highlightMode": "none", "strokeColor": null, "strokeWidth": 0, "wordAnimation": "fade-in"}
    },
    {
      "name": "comic", "title": "Comic", "featured": true,
      "slots": [{"name": "accent", "kind": "color", "default": "orange"}],
      "style": {"activeWordColor": "{accent}", "fontFamily": "Marker Felt", "fontSize": 92, "strokeWidth": 8, "textTransform": "uppercase", "wordAnimation": "rotate-in", "wordLoop": "wiggle"}
    },
    {
      "name": "elegant", "title": "Elegant", "featured": true,
      "slots": [{"name": "accent", "kind": "color", "default": "#F5E6C8"}],
      "style": {"activeWordColor": "{accent}", "activeWordScale": 1, "fontFamily": "Georgia", "fontSize": 72, "fontWeight": "semibold", "highlightMode": "active-underline", "letterSpacing": 2, "shadow": {"color": "black@0.5", "offsetX": 0, "offsetY": 3, "radius": 16}, "strokeColor": null, "strokeWidth": 0, "wordAnimation": "fade-in"}
    },
    {
      "name": "neon-glow", "title": "Neon Glow", "featured": true,
      "style": {"activeWordColor": "green", "fontSize": 88, "shadow": {"color": "green@0.9", "offsetX": 0, "offsetY": 0, "radius": 26}, "strokeColor": null, "strokeWidth": 0, "textTransform": "uppercase", "wordAnimation": "fade-in"}
    },
    {
      "name": "lyric", "title": "Lyric",
      "about": "The music-lyric-video look: heavy italic yellow, every whole line on at once, and the spoken word blooming white.",
      "style": {"activeWordColor": "white", "activeWordScale": 1, "fontSize": 88, "fontWeight": "black", "glow": {"color": "white", "intensity": 0.7, "radius": 16, "scope": "active-word"}, "shadow": null, "slant": 0.25, "strokeColor": null, "strokeWidth": 0, "textColor": "yellow", "textTransform": "uppercase"}
    },
    {
      "name": "hollow", "title": "Hollow", "featured": true,
      "about": "Outline-only italic caps with a soft halo; karaoke fills the hollow letters in as they're spoken.",
      "style": {"activeWordColor": "white", "activeWordScale": 1, "fontSize": 92, "fontWeight": "black", "glow": {"color": "white", "intensity": 0.4, "radius": 12, "scope": "all-words"}, "highlightMode": "karaoke", "shadow": null, "slant": 0.25, "strokeColor": "white", "strokeWidth": 4, "textColor": "white@0", "textTransform": "uppercase", "wordAnimation": "fade-in"}
    },
    {
      "name": "poster-red", "title": "Poster Red", "featured": true,
      "about": "The statement-poster look: flat bold caps stacked one word per line, left-aligned in the frame's upper third — big, loud, editorial.",
      "slots": [{"name": "color", "kind": "color", "default": "#E02A2A"}],
      "grouping": {"maxCharactersPerLine": 14, "maxHoldAfterLastWord": 0.25, "maxLinesPerCard": 4, "maxWordsPerLine": 1, "minCardDuration": 1, "pauseThreshold": 0.7},
      "style": {"activeWordScale": 1, "alignment": "leading", "animationDuration": 0.22, "fontSize": 118, "fontWeight": "black", "highlightMode": "none", "lineSpacing": 0.92, "position": {"x": 0.42, "y": 0.3}, "shadow": {"color": "black@0.35", "offsetX": 0, "offsetY": 4, "radius": 6}, "strokeColor": null, "strokeWidth": 0, "textColor": "{color}", "textTransform": "uppercase", "wordAnimation": "slide-up"}
    },
    {
      "name": "poster-yellow", "title": "Poster Yellow",
      "slots": [{"name": "color", "kind": "color", "default": "#FFD60A"}],
      "grouping": {"maxCharactersPerLine": 14, "maxHoldAfterLastWord": 0.25, "maxLinesPerCard": 4, "maxWordsPerLine": 1, "minCardDuration": 1, "pauseThreshold": 0.7},
      "style": {"activeWordScale": 1, "alignment": "leading", "animationDuration": 0.22, "fontSize": 118, "fontWeight": "black", "highlightMode": "none", "lineSpacing": 0.92, "position": {"x": 0.42, "y": 0.3}, "shadow": {"color": "black@0.45", "offsetX": 0, "offsetY": 5, "radius": 8}, "strokeColor": null, "strokeWidth": 0, "textColor": "{color}", "textTransform": "uppercase", "wordAnimation": "slide-up"}
    },
    {
      "name": "statement", "title": "Statement", "featured": true,
      "about": "The \"THIS IS A MESSAGE\" look: heavy red caps, left-aligned, normal multi-word lines (no one-word grouping). Pairs with the Noir look.",
      "slots": [{"name": "color", "kind": "color", "default": "#E01E1E"}],
      "style": {"activeWordScale": 1, "alignment": "leading", "fontSize": 104, "fontWeight": "black", "highlightMode": "none", "lineSpacing": 0.98, "position": {"x": 0.4, "y": 0.5}, "shadow": {"color": "black@0.4", "offsetX": 0, "offsetY": 3, "radius": 5}, "strokeColor": null, "strokeWidth": 0, "textColor": "{color}", "textTransform": "uppercase"}
    },
    {
      "name": "color-box", "title": "Color Box", "featured": true,
      "about": "The short-clip staple: a coloured box jumps onto each spoken word, cycling green, yellow, red and purple — the box carries the colour, the text stays flat white.",
      "slots": [{"name": "accent", "kind": "colors", "default": "#2ECC40,#FFDC00,#FF4136,#B10DC9"}],
      "style": {"activeWordScale": 1.06, "fontSize": 88, "fontWeight": "black", "highlightMode": "active-box", "shadow": null, "strokeWidth": 7, "textTransform": "uppercase", "wordAnimation": "pop-on", "wordColorPalette": "{accent}"}
    },
    {
      "name": "thumbnail", "title": "Thumbnail", "featured": true,
      "about": "Thumbnail energy: fat yellow caps in a thick black outline that drop into place.",
      "slots": [{"name": "color", "kind": "color", "default": "#FFDC00"}, {"name": "accent", "kind": "color", "default": "#FF4136"}],
      "style": {"activeWordColor": "{accent}", "fontSize": 96, "fontWeight": "black", "shadow": {"color": "black@0.4", "offsetX": 4, "offsetY": 6, "radius": 0}, "strokeWidth": 11, "textColor": "{color}", "textTransform": "uppercase", "wordAnimation": "drop"}
    },
    {
      "name": "chips", "title": "Chips", "featured": true,
      "about": "Every word in its own white chip — clean product-video captions.",
      "style": {"activeWordScale": 1, "background": {"color": "white@0.94", "cornerRadius": 14, "mode": "per-word", "paddingHorizontal": 18, "paddingVertical": 8}, "fontSize": 66, "fontWeight": "semibold", "highlightMode": "none", "shadow": null, "strokeColor": null, "strokeWidth": 0, "textColor": "#141414", "wordAnimation": "fade-in"}
    },
    {
      "name": "quiz-pop", "title": "Quiz Pop", "featured": true,
      "about": "The language-app quiz look: rounded white type on bright green word tiles, bouncing on per word.",
      "slots": [{"name": "tile", "kind": "color", "default": "#58CC02"}, {"name": "accent", "kind": "color", "default": "#FFF6C6"}],
      "style": {"activeWordColor": "{accent}", "activeWordScale": 1.06, "background": {"color": "{tile}", "cornerRadius": 16, "mode": "per-word", "paddingHorizontal": 20, "paddingVertical": 10}, "fontFamily": "Arial Rounded MT Bold", "fontSize": 62, "fontWeight": "bold", "shadow": {"color": "black@0.22", "offsetX": 0, "offsetY": 3, "radius": 5}, "strokeColor": null, "strokeWidth": 0, "wordAnimation": "bounce-in"}
    },
    {
      "name": "messages", "title": "Messages", "featured": true,
      "about": "iMessage-blue word bubbles.",
      "slots": [{"name": "bubble", "kind": "color", "default": "#0A84FF"}],
      "style": {"activeWordScale": 1, "background": {"color": "{bubble}", "cornerRadius": 20, "mode": "per-word", "paddingHorizontal": 20, "paddingVertical": 9}, "fontSize": 66, "fontWeight": "semibold", "highlightMode": "none", "shadow": null, "strokeColor": null, "strokeWidth": 0, "wordAnimation": "slide-up"}
    },
    {
      "name": "closed-cap", "title": "Closed Cap",
      "about": "Broadcast closed-caption: mono type on a hard black band, zero animation — the accessibility-forward look.",
      "style": {"activeWordScale": 1, "background": {"color": "black@0.85", "cornerRadius": 0, "mode": "per-line", "paddingHorizontal": 20, "paddingVertical": 8}, "fontFamily": "Courier New", "fontSize": 62, "fontWeight": "bold", "highlightMode": "none", "shadow": null, "strokeColor": null, "strokeWidth": 0}
    },
    {
      "name": "headline", "title": "Headline", "featured": true,
      "about": "Tabloid banner: black caps on a white block, red spoken word.",
      "slots": [{"name": "accent", "kind": "color", "default": "#D0021B"}],
      "style": {"activeWordColor": "{accent}", "activeWordScale": 1, "background": {"color": "white", "cornerRadius": 4, "mode": "block", "paddingHorizontal": 26, "paddingVertical": 10}, "fontSize": 74, "fontWeight": "black", "shadow": null, "strokeColor": null, "strokeWidth": 0, "textColor": "black", "textTransform": "uppercase"}
    },
    {
      "name": "magazine", "title": "Magazine", "featured": true,
      "about": "Editorial serif — fashion-film elegance.",
      "style": {"activeWordScale": 1, "animationDuration": 0.3, "fontFamily": "Georgia", "fontSize": 66, "fontWeight": "semibold", "highlightMode": "none", "letterSpacing": 2, "shadow": {"color": "black@0.55", "offsetX": 0, "offsetY": 2, "radius": 14}, "strokeColor": null, "strokeWidth": 0, "wordAnimation": "fade-in"}
    },
    {
      "name": "doodle", "title": "Doodle", "featured": true,
      "about": "Hand-drawn marker captions that wiggle like a sketchbook.",
      "slots": [{"name": "accent", "kind": "color", "default": "yellow"}],
      "style": {"activeWordColor": "{accent}", "fontFamily": "Bradley Hand", "fontSize": 82, "fontWeight": "bold", "shadow": {"color": "black@0.5", "offsetX": 0, "offsetY": 3, "radius": 8}, "strokeColor": null, "strokeWidth": 0, "wordAnimation": "pop-on", "wordLoop": "wiggle"}
    },
    {
      "name": "techwave", "title": "Techwave", "featured": true,
      "about": "Cyber terminal: cyan mono-ish caps with scanlines and a color split.",
      "slots": [{"name": "color", "kind": "color", "default": "#00E5FF"}],
      "style": {"activeWordColor": "white", "chromaticAberration": 2, "fontFamily": "Futura", "fontSize": 72, "fontWeight": "medium", "letterSpacing": 4, "scanlineIntensity": 0.5, "shadow": null, "strokeColor": null, "strokeWidth": 0, "textColor": "{color}", "textTransform": "uppercase", "wordAnimation": "typewriter"}
    },
    {
      "name": "nova", "title": "Nova", "featured": true,
      "about": "Violet→cyan gradient with a soft halo — the dreamy title feed look.",
      "slots": [{"name": "from", "kind": "color", "default": "#8A2BE2"}, {"name": "to", "kind": "color", "default": "#00E5FF"}],
      "style": {"activeWordScale": 1, "fontSize": 86, "fontWeight": "black", "glow": {"color": "#9C7BFF", "intensity": 0.45, "radius": 14, "scope": "all-words"}, "highlightMode": "none", "shadow": null, "strokeColor": null, "strokeWidth": 0, "textGradient": {"angle": 45, "colors": ["{from}", "{to}"]}, "textTransform": "uppercase", "wordAnimation": "pop-on"}
    },
    {
      "name": "focus", "title": "Focus",
      "about": "Spotlight focus: the spoken word stays lit, the rest dims — calm authority for educational clips.",
      "style": {"activeWordColor": "white", "activeWordScale": 1.05, "fontSize": 80, "highlightMode": "spotlight", "shadow": {"color": "black@0.6", "offsetX": 0, "offsetY": 3, "radius": 10}, "strokeColor": null, "strokeWidth": 0}
    },
    {
      "name": "stamp", "title": "Stamp",
      "about": "Tilted red rubber-stamp slam.",
      "slots": [{"name": "color", "kind": "color", "default": "#D62828"}],
      "style": {"activeWordScale": 1, "blockRotation": -0.06, "fontSize": 92, "fontWeight": "black", "highlightMode": "none", "shadow": null, "strokeColor": null, "strokeWidth": 0, "textColor": "{color}", "textTransform": "uppercase", "wordAnimation": "stomp"}
    },
    {
      "name": "outline-fill", "title": "Outline Fill",
      "about": "The music-video reveal: every word a hollow outline, and ONLY the spoken word fills solid — lighting up word by word as she talks.",
      "style": {"activeWordColor": "white", "fontSize": 90, "fontWeight": "black", "glow": {"color": "white", "intensity": 0.5, "radius": 12, "scope": "active-word"}, "shadow": null, "slant": 0.25, "strokeColor": "white", "strokeWidth": 4, "textColor": "white@0", "textTransform": "uppercase"}
    },
    {
      "name": "outline-red", "title": "Outline Red",
      "about": "The rap-clip reveal: hollow white outlines, spoken word slams in SOLID RED — upright, no glow, pure attitude.",
      "slots": [{"name": "accent", "kind": "color", "default": "#E8352E"}],
      "style": {"activeWordColor": "{accent}", "activeWordScale": 1.05, "fontSize": 90, "fontWeight": "black", "shadow": null, "strokeColor": "white", "strokeWidth": 5, "textColor": "white@0", "textTransform": "uppercase"}
    },
    {
      "name": "impact", "title": "Impact",
      "slots": [{"name": "accent", "kind": "color", "default": "red"}],
      "style": {"activeWordColor": "{accent}", "fontSize": 94, "highlightMode": "active-box", "shadow": {"color": "black@0.6", "offsetX": 0, "offsetY": 4, "radius": 12}, "strokeColor": null, "strokeWidth": 0, "textTransform": "uppercase", "wordAnimation": "drop"}
    },
    {
      "name": "bubble", "title": "Bubble", "featured": true,
      "slots": [{"name": "accent", "kind": "color", "default": "pink"}],
      "style": {"activeWordColor": "{accent}", "background": {"color": "white@0.92", "cornerRadius": 26, "mode": "per-line", "paddingHorizontal": 30, "paddingVertical": 10}, "fontSize": 76, "strokeColor": null, "strokeWidth": 0, "textColor": "#1A1A2E", "wordAnimation": "pop-on"}
    },
    {
      "name": "retro", "title": "Retro", "featured": true,
      "slots": [{"name": "accent", "kind": "color", "default": "orange"}],
      "style": {"activeWordColor": "{accent}", "fontFamily": "American Typewriter", "fontSize": 78, "fontWeight": "bold", "highlightMode": "active-underline", "strokeColor": "#3B2416", "strokeWidth": 5, "wordAnimation": "slide-up", "wordColorPalette": ["orange", "#F5E6C8", "pink", "yellow"], "wordLoop": "wave"}
    },
    {
      "name": "shadowline", "title": "Shadowline",
      "slots": [{"name": "color", "kind": "color", "default": "yellow"}],
      "style": {"activeWordColor": "white", "fontSize": 96, "shadow": {"color": "black", "offsetX": 6, "offsetY": 7, "radius": 0}, "strokeColor": null, "strokeWidth": 0, "textColor": "{color}", "textTransform": "uppercase", "wordAnimation": "slide-up"}
    },
    {
      "name": "whisper", "title": "Whisper",
      "style": {"activeWordScale": 1, "animationDuration": 0.35, "fontSize": 56, "fontWeight": "medium", "highlightMode": "none", "letterSpacing": 6, "shadow": {"color": "black@0.7", "offsetX": 0, "offsetY": 0, "radius": 18}, "strokeColor": null, "strokeWidth": 0, "textTransform": "lowercase", "wordAnimation": "fade-in"}
    },
    {
      "name": "gamer", "title": "Gamer",
      "slots": [{"name": "accent", "kind": "color", "default": "#00C7BE"}],
      "style": {"activeWordColor": "{accent}", "background": {"color": "black@0.8", "cornerRadius": 8, "mode": "per-line", "paddingHorizontal": 26, "paddingVertical": 8}, "fontFamily": "Menlo", "fontSize": 72, "fontWeight": "bold", "highlightMode": "active-box", "strokeColor": null, "strokeWidth": 0, "textTransform": "uppercase", "wordAnimation": "typewriter", "wordColorPalette": ["green", "#4FD8FF", "white"]}
    },
    {
      "name": "neon", "title": "Neon",
      "slots": [{"name": "accent", "kind": "color", "default": "green"}],
      "style": {"activeWordColor": "{accent}", "activeWordScale": 1.12, "fontSize": 92, "strokeWidth": 8, "textColor": "#EAFFEA", "textTransform": "uppercase", "wordAnimation": "spring"}
    },
    {
      "name": "ocean", "title": "Ocean",
      "slots": [{"name": "accent", "kind": "color", "default": "#4FD8FF"}],
      "style": {"activeWordColor": "{accent}", "activeWordScale": 1.1, "background": {"color": "#0A2540@0.6", "cornerRadius": 18, "mode": "per-line", "paddingHorizontal": 26, "paddingVertical": 8}, "highlightMode": "karaoke", "textTransform": "uppercase", "wordAnimation": "slide-up"}
    },
    {
      "name": "candy", "title": "Candy",
      "slots": [{"name": "accent", "kind": "color", "default": "pink"}],
      "style": {"activeWordColor": "{accent}", "activeWordScale": 1.12, "fontSize": 92, "strokeColor": "#5B1140", "strokeWidth": 8, "textTransform": "uppercase", "wordAnimation": "bounce-in"}
    },
    {
      "name": "inferno", "title": "Inferno",
      "slots": [{"name": "accent", "kind": "color", "default": "orange"}],
      "style": {"activeWordColor": "{accent}", "fontSize": 96, "highlightMode": "karaoke", "strokeWidth": 9, "textTransform": "uppercase", "wordAnimation": "stomp"}
    },
    {
      "name": "golden", "title": "Golden",
      "slots": [{"name": "color", "kind": "color", "default": "yellow"}],
      "style": {"activeWordColor": "white", "activeWordScale": 1.1, "background": {"color": "black@0.7", "cornerRadius": 18, "mode": "per-line", "paddingHorizontal": 26, "paddingVertical": 8}, "highlightMode": "karaoke", "textColor": "{color}", "textTransform": "uppercase"}
    },
    {
      "name": "typist", "title": "Typist",
      "slots": [{"name": "accent", "kind": "color", "default": "green"}],
      "style": {"activeWordColor": "{accent}", "background": {"color": "black@0.75", "cornerRadius": 6, "mode": "per-line", "paddingHorizontal": 26, "paddingVertical": 8}, "fontFamily": "Courier New", "fontSize": 72, "fontWeight": "bold", "strokeColor": null, "strokeWidth": 0, "textTransform": "lowercase", "wordAnimation": "typewriter"}
    },
    {
      "name": "weight-sweep", "title": "Weight Sweep",
      "about": "Quiet lowercase white type that thickens from light to bold as each word is said, so the line fills in heavy behind the voice. No colour at all.",
      "style": {"activeWordScale": 1, "activeWordWeightRamp": "black", "fontSize": 86, "fontWeight": "light", "highlightMode": "none", "shadow": {"color": "black@0.5", "offsetX": 0, "offsetY": 3, "radius": 12}, "strokeColor": null, "strokeWidth": 0, "textTransform": "lowercase", "weightRampHolds": true}
    },
    {
      "name": "subtitle", "title": "Subtitle",
      "about": "The streaming-service subtitle: plain white sans with a light shadow, bottom centre, at most two lines of 42 characters, and a dash on each line when two people share a subtitle.",
      "grouping": {"maxCharactersPerLine": 42, "maxHoldAfterLastWord": 0.6, "maxLinesPerCard": 2, "maxWordsPerLine": 12, "minCardDuration": 1.0, "pauseThreshold": 0.8, "speakerBreak": "line"},
      "style": {"activeWordScale": 1, "fontSize": 58, "fontWeight": "medium", "highlightMode": "none", "maxWidthFraction": 0.9, "position": {"x": 0.5, "y": 0.88}, "shadow": {"color": "black@0.85", "offsetX": 0, "offsetY": 2, "radius": 4}, "speakerDash": true, "strokeColor": null, "strokeWidth": 0}
    },
    {
      "name": "lower-third", "title": "Lower Third",
      "about": "A broadcast band at the bottom left that slides in from the edge; when the speaker is known their name sits in bold over the lighter words.",
      "slots": [{"name": "band", "kind": "color", "default": "#10233F@0.92"}, {"name": "accent", "kind": "color", "default": "#FFC845"}],
      "grouping": {"maxCharactersPerLine": 32, "maxHoldAfterLastWord": 0.6, "maxLinesPerCard": 2, "maxWordsPerLine": 7, "minCardDuration": 1.0, "pauseThreshold": 0.7, "speakerBreak": "card"},
      "style": {"activeWordScale": 1, "alignment": "leading", "animationDuration": 0.22, "background": {"color": "{band}", "cornerRadius": 4, "mode": "block", "paddingHorizontal": 30, "paddingVertical": 16}, "cardAnimation": "slide-in-left", "fontSize": 58, "fontWeight": "medium", "highlightMode": "none", "maxWidthFraction": 0.72, "position": {"x": 0, "y": 0.84}, "shadow": null, "speakerLabel": {"color": "{accent}", "fontWeight": "heavy", "mode": "above", "scale": 0.62, "uppercase": true}, "strokeColor": null, "strokeWidth": 0}
    },
    {
      "name": "two-speaker", "title": "Two Speaker",
      "about": "For interviews and podcasts: each speaker's words in their own colour, with their name on a chip above the caption.",
      "slots": [{"name": "speakers", "kind": "colors", "default": "#FFD84D,#5CE1FF"}],
      "grouping": {"maxCharactersPerLine": 20, "maxHoldAfterLastWord": 0.5, "maxLinesPerCard": 2, "maxWordsPerLine": 4, "minCardDuration": 0.9, "pauseThreshold": 0.6, "speakerBreak": "card"},
      "style": {"activeWordScale": 1, "fontSize": 84, "fontWeight": "heavy", "highlightMode": "none", "speakerColors": "{speakers}", "speakerLabel": {"fontWeight": "heavy", "mode": "chip", "scale": 0.4, "uppercase": true}, "strokeWidth": 6, "textTransform": "uppercase", "wordAnimation": "pop-on"}
    },
    {
      "name": "stacked", "title": "Stacked",
      "about": "One word to a line, each line sized to the same width, so the caption builds into a solid block of type.",
      "slots": [{"name": "accent", "kind": "color", "default": "yellow"}],
      "grouping": {"maxCharactersPerLine": 14, "maxHoldAfterLastWord": 0.4, "maxLinesPerCard": 3, "maxWordsPerLine": 1, "minCardDuration": 0.7, "pauseThreshold": 0.5},
      "style": {"activeWordColor": "{accent}", "activeWordScale": 1, "fitLinesToWidth": true, "fontSize": 92, "fontWeight": "black", "lineSpacing": 0.92, "maxWidthFraction": 0.78, "position": {"x": 0.5, "y": 0.72}, "strokeColor": null, "strokeWidth": 0, "textTransform": "uppercase", "wordAnimation": "pop-on"}
    },
    {
      "name": "extruded", "title": "Extruded",
      "about": "Chunky caps standing on a solid 3-D side wall that steps back down and to the right.",
      "slots": [{"name": "color", "kind": "color", "default": "#FFE14D"}, {"name": "depth", "kind": "color", "default": "#E4572E"}],
      "style": {"activeWordColor": "white", "activeWordScale": 1.06, "extrude": {"angle": -50, "color": "{depth}", "depth": 20, "fade": 0.4}, "fontSize": 98, "fontWeight": "black", "shadow": null, "strokeColor": "#1A1A1A", "strokeWidth": 5, "textColor": "{color}", "textTransform": "uppercase", "wordAnimation": "pop-on"}
    },
    {
      "name": "marker", "title": "Marker",
      "about": "Handwritten marker lettering that draws itself on, word by word, as it is said.",
      "slots": [{"name": "accent", "kind": "color", "default": "#FFE45C"}],
      "style": {"activeWordColor": "{accent}", "activeWordScale": 1, "animationDuration": 0.28, "fontFamily": "Marker Felt", "fontSize": 96, "fontWeight": "bold", "shadow": {"color": "black@0.55", "offsetX": 0, "offsetY": 3, "radius": 8}, "strokeColor": null, "strokeWidth": 0, "wordAnimation": "typewriter"}
    },
    {
      "name": "glitch", "title": "Glitch",
      "about": "Monospaced caps split into red and cyan, shivering on scanlines like a signal breaking up.",
      "slots": [{"name": "accent", "kind": "color", "default": "#00FFC6"}],
      "style": {"activeWordColor": "{accent}", "activeWordScale": 1, "chromaticAberration": 5, "fontFamily": "Menlo", "fontSize": 78, "fontWeight": "bold", "scanlineIntensity": 0.35, "shadow": {"color": "black@0.5", "offsetX": 0, "offsetY": 3, "radius": 8}, "strokeColor": null, "strokeWidth": 0, "textTransform": "uppercase", "wordAnimation": "shake", "wordLoop": "shake", "wordLoopSpeed": 1.3}
    },
    {
      "name": "bilingual", "title": "Bilingual",
      "about": "Two languages at once: the second words file runs small above the caption, the main words below at full size.",
      "slots": [{"name": "accent", "kind": "color", "default": "yellow"}],
      "grouping": {"maxCharactersPerLine": 30, "maxHoldAfterLastWord": 0.5, "maxLinesPerCard": 1, "maxWordsPerLine": 6, "minCardDuration": 0.9, "pauseThreshold": 0.6},
      "style": {"activeWordColor": "{accent}", "activeWordScale": 1.04, "fontSize": 78, "fontWeight": "heavy", "position": {"x": 0.5, "y": 0.78}, "secondaryLine": {"color": "white@0.85", "fontWeight": "medium", "gap": 14, "scale": 0.62}, "strokeWidth": 6}
    },
    {
      "name": "soft-highlight", "title": "Soft Highlight",
      "about": "Sentence case with a soft shadow and a pastel marker swiped behind the key word — the emphasised word when there is one, else the word being said.",
      "slots": [{"name": "marker", "kind": "color", "default": "#FFE98A"}],
      "style": {"activeBoxPadH": 0.14, "activeBoxPadV": 0.05, "activeBoxShape": "marker", "activeBoxTextColor": "#1F1F1F", "activeWordColor": "{marker}", "activeWordScale": 1, "fontSize": 76, "fontWeight": "semibold", "highlightKeyWords": true, "highlightMode": "active-box", "shadow": {"color": "black@0.45", "offsetX": 0, "offsetY": 3, "radius": 14}, "strokeColor": null, "strokeWidth": 0, "textTransform": "sentence", "wordAnimation": "fade-in"}
    },
    {
      "name": "tilted-bounce", "title": "Tilted Bounce",
      "about": "Big bouncing caps, each caption at its own slight angle on a thick 3-D drop, the spoken word cycling through bright colours.",
      "slots": [{"name": "palette", "kind": "colors", "default": "#FFD400,#3DF07B,#FF4FA3,#4FC3FF"}],
      "grouping": {"maxCharactersPerLine": 16, "maxHoldAfterLastWord": 0.4, "maxLinesPerCard": 2, "maxWordsPerLine": 3, "minCardDuration": 0.8, "pauseThreshold": 0.6},
      "style": {"activeWordPalette": "{palette}", "activeWordScale": 1.1, "cardTilt": 0.07, "fontSize": 100, "fontWeight": "black", "hardShadow": {"color": "black", "offsetX": 6, "offsetY": 10}, "highlightMode": "active-word", "shadow": null, "strokeWidth": 8, "textTransform": "uppercase", "wordAnimation": "bounce-in"}
    }
    ]
    """#
}
