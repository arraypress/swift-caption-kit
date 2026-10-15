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
      "style": {"activeWordColor": "{accent}", "activeWordScale": 1.1, "background": {"color": "black@0.55", "cornerRadius": 18, "mode": "perLine", "paddingHorizontal": 26, "paddingVertical": 8}, "highlightMode": "karaoke", "textTransform": "uppercase"}
    },
    {
      "name": "boxed", "title": "Boxed", "featured": true,
      "slots": [{"name": "accent", "kind": "color", "default": "green"}],
      "style": {"activeWordColor": "{accent}", "activeWordScale": 1.06, "fontSize": 88, "highlightMode": "activeBox", "shadow": {"color": "black@0.6", "offsetX": 0, "offsetY": 5, "radius": 14}, "strokeColor": null, "strokeWidth": 0, "textTransform": "uppercase"}
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
      "style": {"fontSize": 90, "highlightMode": "none", "strokeWidth": 8, "textTransform": "uppercase", "wordAnimation": "bounceIn", "wordColorPalette": "{palette}"}
    },
    {
      "name": "wave", "title": "Wave",
      "slots": [{"name": "accent", "kind": "color", "default": "yellow"}],
      "style": {"activeWordColor": "{accent}", "fontSize": 88, "highlightMode": "karaoke", "strokeWidth": 8, "textTransform": "uppercase", "wordLoop": "wave"}
    },
    {
      "name": "underline", "title": "Underline",
      "slots": [{"name": "accent", "kind": "color", "default": "yellow"}],
      "style": {"activeWordColor": "{accent}", "activeWordScale": 1.04, "highlightMode": "activeUnderline", "shadow": {"color": "black@0.65", "offsetX": 0, "offsetY": 3, "radius": 12}, "strokeColor": null, "strokeWidth": 0, "wordAnimation": "fadeIn"}
    },
    {
      "name": "clean-pop", "title": "Clean Pop", "featured": true,
      "slots": [{"name": "accent", "kind": "color", "default": "yellow"}],
      "style": {"activeWordColor": "{accent}", "activeWordScale": 1.12, "fontSize": 92, "strokeWidth": 8, "textTransform": "uppercase", "wordAnimation": "popOn"}
    },
    {
      "name": "gradient", "title": "Gradient", "featured": true,
      "about": "Clean white caps with the spoken word in a gradient pill, purple to magenta.",
      "slots": [{"name": "from", "kind": "color", "default": "#7B2FF7"}, {"name": "to", "kind": "color", "default": "#E93FD8"}],
      "style": {"activeBoxGradient": {"angle": 0, "colors": ["{from}", "{to}"]}, "activeBoxPadH": 0.22, "activeBoxPadV": 0.16, "activeWordColor": "{from}", "activeWordScale": 1.04, "fontSize": 90, "fontWeight": "bold", "highlightMode": "activeBox", "shadow": {"color": "black@0.45", "offsetX": 0, "offsetY": 4, "radius": 9}, "strokeColor": null, "textTransform": "uppercase", "wordAnimation": "popOn"}
    },
    {
      "name": "inverse", "title": "Inverse",
      "about": "Inverse highlight: white caps with the spoken word in a WHITE pill and dark text (the fourth app-store tile).",
      "style": {"activeBoxPadH": 0.22, "activeBoxPadV": 0.16, "activeBoxTextColor": {"alpha": 1, "blue": 0.1, "green": 0.08, "red": 0.08}, "activeWordColor": "white", "activeWordScale": 1.04, "fontSize": 90, "fontWeight": "bold", "highlightMode": "activeBox", "shadow": {"color": "black@0.45", "offsetX": 0, "offsetY": 4, "radius": 9}, "strokeColor": null, "textTransform": "uppercase", "wordAnimation": "popOn"}
    },
    {
      "name": "sunset", "title": "Sunset",
      "about": "Clean white caps with the spoken word in a gradient pill, orange to pink.",
      "slots": [{"name": "from", "kind": "color", "default": "#FF7A00"}, {"name": "to", "kind": "color", "default": "#FF2D75"}],
      "style": {"activeBoxGradient": {"angle": 0, "colors": ["{from}", "{to}"]}, "activeBoxPadH": 0.22, "activeBoxPadV": 0.16, "activeWordColor": "{from}", "activeWordScale": 1.04, "fontSize": 90, "fontWeight": "bold", "highlightMode": "activeBox", "shadow": {"color": "black@0.45", "offsetX": 0, "offsetY": 4, "radius": 9}, "strokeColor": null, "textTransform": "uppercase", "wordAnimation": "popOn"}
    },
    {
      "name": "aqua", "title": "Aqua",
      "about": "Clean white caps with the spoken word in a gradient pill, cyan to blue.",
      "slots": [{"name": "from", "kind": "color", "default": "#00C6FB"}, {"name": "to", "kind": "color", "default": "#005BEA"}],
      "style": {"activeBoxGradient": {"angle": 0, "colors": ["{from}", "{to}"]}, "activeBoxPadH": 0.22, "activeBoxPadV": 0.16, "activeWordColor": "{from}", "activeWordScale": 1.04, "fontSize": 90, "fontWeight": "bold", "highlightMode": "activeBox", "shadow": {"color": "black@0.45", "offsetX": 0, "offsetY": 4, "radius": 9}, "strokeColor": null, "textTransform": "uppercase", "wordAnimation": "popOn"}
    },
    {
      "name": "mint", "title": "Mint",
      "about": "Clean white caps with the spoken word in a gradient pill, green to teal.",
      "slots": [{"name": "from", "kind": "color", "default": "#00F5A0"}, {"name": "to", "kind": "color", "default": "#00A3D9"}],
      "style": {"activeBoxGradient": {"angle": 0, "colors": ["{from}", "{to}"]}, "activeBoxPadH": 0.22, "activeBoxPadV": 0.16, "activeWordColor": "{from}", "activeWordScale": 1.04, "fontSize": 90, "fontWeight": "bold", "highlightMode": "activeBox", "shadow": {"color": "black@0.45", "offsetX": 0, "offsetY": 4, "radius": 9}, "strokeColor": null, "textTransform": "uppercase", "wordAnimation": "popOn"}
    },
    {
      "name": "ember", "title": "Ember",
      "about": "Clean white caps with the spoken word in a gradient pill, red to amber.",
      "slots": [{"name": "from", "kind": "color", "default": "#F83600"}, {"name": "to", "kind": "color", "default": "#FEB800"}],
      "style": {"activeBoxGradient": {"angle": 0, "colors": ["{from}", "{to}"]}, "activeBoxPadH": 0.22, "activeBoxPadV": 0.16, "activeWordColor": "{from}", "activeWordScale": 1.04, "fontSize": 90, "fontWeight": "bold", "highlightMode": "activeBox", "shadow": {"color": "black@0.45", "offsetX": 0, "offsetY": 4, "radius": 9}, "strokeColor": null, "textTransform": "uppercase", "wordAnimation": "popOn"}
    },
    {
      "name": "hype", "title": "Hype",
      "slots": [{"name": "accent", "kind": "color", "default": "yellow"}],
      "style": {"activeWordColor": "{accent}", "cardAnimation": "stomp", "fontSize": 96, "highlightMode": "karaoke", "strokeWidth": 9, "textTransform": "uppercase"}
    },
    {
      "name": "minimal", "title": "Minimal", "featured": true,
      "style": {"activeWordScale": 1, "background": {"color": "black@0.4", "cornerRadius": 12, "mode": "perLine", "paddingHorizontal": 20, "paddingVertical": 6}, "fontSize": 68, "fontWeight": "semibold", "highlightMode": "none", "strokeColor": null, "strokeWidth": 0, "wordAnimation": "fadeIn"}
    },
    {
      "name": "comic", "title": "Comic", "featured": true,
      "slots": [{"name": "accent", "kind": "color", "default": "orange"}],
      "style": {"activeWordColor": "{accent}", "fontFamily": "Marker Felt", "fontSize": 92, "strokeWidth": 8, "textTransform": "uppercase", "wordAnimation": "rotateIn", "wordLoop": "wiggle"}
    },
    {
      "name": "elegant", "title": "Elegant", "featured": true,
      "slots": [{"name": "accent", "kind": "color", "default": "#F5E6C8"}],
      "style": {"activeWordColor": "{accent}", "activeWordScale": 1, "fontFamily": "Georgia", "fontSize": 72, "fontWeight": "semibold", "highlightMode": "activeUnderline", "letterSpacing": 2, "shadow": {"color": "black@0.5", "offsetX": 0, "offsetY": 3, "radius": 16}, "strokeColor": null, "strokeWidth": 0, "wordAnimation": "fadeIn"}
    },
    {
      "name": "neon-glow", "title": "Neon Glow", "featured": true,
      "style": {"activeWordColor": "green", "fontSize": 88, "shadow": {"color": "green@0.9", "offsetX": 0, "offsetY": 0, "radius": 26}, "strokeColor": null, "strokeWidth": 0, "textTransform": "uppercase", "wordAnimation": "fadeIn"}
    },
    {
      "name": "lyric", "title": "Lyric",
      "about": "The music-lyric-video look: heavy italic yellow, every whole line on at once, and the spoken word blooming white.",
      "style": {"activeWordColor": "white", "activeWordScale": 1, "fontSize": 88, "fontWeight": "black", "glow": {"color": "white", "intensity": 0.7, "radius": 16, "scope": "activeWord"}, "shadow": null, "slant": 0.25, "strokeColor": null, "strokeWidth": 0, "textColor": "yellow", "textTransform": "uppercase"}
    },
    {
      "name": "hollow", "title": "Hollow", "featured": true,
      "about": "Outline-only italic caps with a soft halo; karaoke fills the hollow letters in as they're spoken.",
      "style": {"activeWordColor": "white", "activeWordScale": 1, "fontSize": 92, "fontWeight": "black", "glow": {"color": "white", "intensity": 0.4, "radius": 12, "scope": "allWords"}, "highlightMode": "karaoke", "shadow": null, "slant": 0.25, "strokeColor": "white", "strokeWidth": 4, "textColor": "white@0", "textTransform": "uppercase", "wordAnimation": "fadeIn"}
    },
    {
      "name": "poster-red", "title": "Poster Red", "featured": true,
      "about": "The statement-poster look: flat bold caps stacked one word per line, left-aligned in the frame's upper third — big, loud, editorial.",
      "slots": [{"name": "color", "kind": "color", "default": "#E02A2A"}],
      "grouping": {"maxCharactersPerLine": 14, "maxHoldAfterLastWord": 0.25, "maxLinesPerCard": 4, "maxWordsPerLine": 1, "minCardDuration": 1, "pauseThreshold": 0.7},
      "style": {"activeWordScale": 1, "alignment": "leading", "animationDuration": 0.22, "fontSize": 118, "fontWeight": "black", "highlightMode": "none", "lineSpacing": 0.92, "position": {"x": 0.42, "y": 0.3}, "shadow": {"color": "black@0.35", "offsetX": 0, "offsetY": 4, "radius": 6}, "strokeColor": null, "strokeWidth": 0, "textColor": "{color}", "textTransform": "uppercase", "wordAnimation": "slideUp"}
    },
    {
      "name": "poster-yellow", "title": "Poster Yellow",
      "slots": [{"name": "color", "kind": "color", "default": "#FFD60A"}],
      "grouping": {"maxCharactersPerLine": 14, "maxHoldAfterLastWord": 0.25, "maxLinesPerCard": 4, "maxWordsPerLine": 1, "minCardDuration": 1, "pauseThreshold": 0.7},
      "style": {"activeWordScale": 1, "alignment": "leading", "animationDuration": 0.22, "fontSize": 118, "fontWeight": "black", "highlightMode": "none", "lineSpacing": 0.92, "position": {"x": 0.42, "y": 0.3}, "shadow": {"color": "black@0.45", "offsetX": 0, "offsetY": 5, "radius": 8}, "strokeColor": null, "strokeWidth": 0, "textColor": "{color}", "textTransform": "uppercase", "wordAnimation": "slideUp"}
    },
    {
      "name": "statement", "title": "Statement", "featured": true,
      "about": "The \"THIS IS A MESSAGE\" look: heavy red caps, left-aligned, normal multi-word lines (no one-word grouping). Pairs with the Noir look.",
      "slots": [{"name": "color", "kind": "color", "default": "#E01E1E"}],
      "style": {"activeWordScale": 1, "alignment": "leading", "fontSize": 104, "fontWeight": "black", "highlightMode": "none", "lineSpacing": 0.98, "position": {"x": 0.4, "y": 0.5}, "shadow": {"color": "black@0.4", "offsetX": 0, "offsetY": 3, "radius": 5}, "strokeColor": null, "strokeWidth": 0, "textColor": "{color}", "textTransform": "uppercase"}
    },
    {
      "name": "hormozi", "title": "Hormozi", "featured": true,
      "about": "THE clip-caption look: a colored box hops onto each spoken word, cycling green/yellow/red/purple — box carries the color, text stays flat white.",
      "slots": [{"name": "accent", "kind": "colors", "default": "#2ECC40,#FFDC00,#FF4136,#B10DC9"}],
      "style": {"activeWordScale": 1.06, "fontSize": 88, "fontWeight": "black", "highlightMode": "activeBox", "shadow": null, "strokeWidth": 7, "textTransform": "uppercase", "wordAnimation": "popOn", "wordColorPalette": "{accent}"}
    },
    {
      "name": "beast", "title": "Beast", "featured": true,
      "about": "Chunky thumbnail energy: fat yellow caps in a thick black outline.",
      "slots": [{"name": "color", "kind": "color", "default": "#FFDC00"}, {"name": "accent", "kind": "color", "default": "#FF4136"}],
      "style": {"activeWordColor": "{accent}", "fontSize": 96, "fontWeight": "black", "shadow": {"color": "black@0.4", "offsetX": 4, "offsetY": 6, "radius": 0}, "strokeWidth": 11, "textColor": "{color}", "textTransform": "uppercase", "wordAnimation": "drop"}
    },
    {
      "name": "chips", "title": "Chips", "featured": true,
      "about": "Every word in its own white chip — clean product-video captions.",
      "style": {"activeWordScale": 1, "background": {"color": "white@0.94", "cornerRadius": 14, "mode": "perWord", "paddingHorizontal": 18, "paddingVertical": 8}, "fontSize": 66, "fontWeight": "semibold", "highlightMode": "none", "shadow": null, "strokeColor": null, "strokeWidth": 0, "textColor": "#141414", "wordAnimation": "fadeIn"}
    },
    {
      "name": "quiz-pop", "title": "Quiz Pop", "featured": true,
      "about": "The language-app quiz look: rounded white type on bright green word tiles, bouncing on per word.",
      "slots": [{"name": "tile", "kind": "color", "default": "#58CC02"}, {"name": "accent", "kind": "color", "default": "#FFF6C6"}],
      "style": {"activeWordColor": "{accent}", "activeWordScale": 1.06, "background": {"color": "{tile}", "cornerRadius": 16, "mode": "perWord", "paddingHorizontal": 20, "paddingVertical": 10}, "fontFamily": "Arial Rounded MT Bold", "fontSize": 62, "fontWeight": "bold", "shadow": {"color": "black@0.22", "offsetX": 0, "offsetY": 3, "radius": 5}, "strokeColor": null, "strokeWidth": 0, "wordAnimation": "bounceIn"}
    },
    {
      "name": "messages", "title": "Messages", "featured": true,
      "about": "iMessage-blue word bubbles.",
      "slots": [{"name": "bubble", "kind": "color", "default": "#0A84FF"}],
      "style": {"activeWordScale": 1, "background": {"color": "{bubble}", "cornerRadius": 20, "mode": "perWord", "paddingHorizontal": 20, "paddingVertical": 9}, "fontSize": 66, "fontWeight": "semibold", "highlightMode": "none", "shadow": null, "strokeColor": null, "strokeWidth": 0, "wordAnimation": "slideUp"}
    },
    {
      "name": "closed-cap", "title": "Closed Cap",
      "about": "Broadcast closed-caption: mono type on a hard black band, zero animation — the accessibility-forward look.",
      "style": {"activeWordScale": 1, "background": {"color": "black@0.85", "cornerRadius": 0, "mode": "perLine", "paddingHorizontal": 20, "paddingVertical": 8}, "fontFamily": "Courier New", "fontSize": 62, "fontWeight": "bold", "highlightMode": "none", "shadow": null, "strokeColor": null, "strokeWidth": 0}
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
      "style": {"activeWordScale": 1, "animationDuration": 0.3, "fontFamily": "Georgia", "fontSize": 66, "fontWeight": "semibold", "highlightMode": "none", "letterSpacing": 2, "shadow": {"color": "black@0.55", "offsetX": 0, "offsetY": 2, "radius": 14}, "strokeColor": null, "strokeWidth": 0, "wordAnimation": "fadeIn"}
    },
    {
      "name": "doodle", "title": "Doodle", "featured": true,
      "about": "Hand-drawn marker captions that wiggle like a sketchbook.",
      "slots": [{"name": "accent", "kind": "color", "default": "yellow"}],
      "style": {"activeWordColor": "{accent}", "fontFamily": "Bradley Hand", "fontSize": 82, "fontWeight": "bold", "shadow": {"color": "black@0.5", "offsetX": 0, "offsetY": 3, "radius": 8}, "strokeColor": null, "strokeWidth": 0, "wordAnimation": "popOn", "wordLoop": "wiggle"}
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
      "style": {"activeWordScale": 1, "fontSize": 86, "fontWeight": "black", "glow": {"color": "#9C7BFF", "intensity": 0.45, "radius": 14, "scope": "allWords"}, "highlightMode": "none", "shadow": null, "strokeColor": null, "strokeWidth": 0, "textGradient": {"angle": 45, "colors": ["{from}", "{to}"]}, "textTransform": "uppercase", "wordAnimation": "popOn"}
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
      "style": {"activeWordColor": "white", "fontSize": 90, "fontWeight": "black", "glow": {"color": "white", "intensity": 0.5, "radius": 12, "scope": "activeWord"}, "shadow": null, "slant": 0.25, "strokeColor": "white", "strokeWidth": 4, "textColor": "white@0", "textTransform": "uppercase"}
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
      "style": {"activeWordColor": "{accent}", "fontSize": 94, "highlightMode": "activeBox", "shadow": {"color": "black@0.6", "offsetX": 0, "offsetY": 4, "radius": 12}, "strokeColor": null, "strokeWidth": 0, "textTransform": "uppercase", "wordAnimation": "drop"}
    },
    {
      "name": "bubble", "title": "Bubble", "featured": true,
      "slots": [{"name": "accent", "kind": "color", "default": "pink"}],
      "style": {"activeWordColor": "{accent}", "background": {"color": "white@0.92", "cornerRadius": 26, "mode": "perLine", "paddingHorizontal": 30, "paddingVertical": 10}, "fontSize": 76, "strokeColor": null, "strokeWidth": 0, "textColor": "#1A1A2E", "wordAnimation": "popOn"}
    },
    {
      "name": "retro", "title": "Retro", "featured": true,
      "slots": [{"name": "accent", "kind": "color", "default": "orange"}],
      "style": {"activeWordColor": "{accent}", "fontFamily": "American Typewriter", "fontSize": 78, "fontWeight": "bold", "highlightMode": "activeUnderline", "strokeColor": "#3B2416", "strokeWidth": 5, "wordAnimation": "slideUp", "wordColorPalette": ["orange", "#F5E6C8", "pink", "yellow"], "wordLoop": "wave"}
    },
    {
      "name": "shadowline", "title": "Shadowline",
      "slots": [{"name": "color", "kind": "color", "default": "yellow"}],
      "style": {"activeWordColor": "white", "fontSize": 96, "shadow": {"color": "black", "offsetX": 6, "offsetY": 7, "radius": 0}, "strokeColor": null, "strokeWidth": 0, "textColor": "{color}", "textTransform": "uppercase", "wordAnimation": "slideUp"}
    },
    {
      "name": "whisper", "title": "Whisper",
      "style": {"activeWordScale": 1, "animationDuration": 0.35, "fontSize": 56, "fontWeight": "medium", "highlightMode": "none", "letterSpacing": 6, "shadow": {"color": "black@0.7", "offsetX": 0, "offsetY": 0, "radius": 18}, "strokeColor": null, "strokeWidth": 0, "textTransform": "lowercase", "wordAnimation": "fadeIn"}
    },
    {
      "name": "gamer", "title": "Gamer",
      "slots": [{"name": "accent", "kind": "color", "default": "#00C7BE"}],
      "style": {"activeWordColor": "{accent}", "background": {"color": "black@0.8", "cornerRadius": 8, "mode": "perLine", "paddingHorizontal": 26, "paddingVertical": 8}, "fontFamily": "Menlo", "fontSize": 72, "fontWeight": "bold", "highlightMode": "activeBox", "strokeColor": null, "strokeWidth": 0, "textTransform": "uppercase", "wordAnimation": "typewriter", "wordColorPalette": ["green", "#4FD8FF", "white"]}
    },
    {
      "name": "neon", "title": "Neon",
      "slots": [{"name": "accent", "kind": "color", "default": "green"}],
      "style": {"activeWordColor": "{accent}", "activeWordScale": 1.12, "fontSize": 92, "strokeWidth": 8, "textColor": "#EAFFEA", "textTransform": "uppercase", "wordAnimation": "spring"}
    },
    {
      "name": "ocean", "title": "Ocean",
      "slots": [{"name": "accent", "kind": "color", "default": "#4FD8FF"}],
      "style": {"activeWordColor": "{accent}", "activeWordScale": 1.1, "background": {"color": "#0A2540@0.6", "cornerRadius": 18, "mode": "perLine", "paddingHorizontal": 26, "paddingVertical": 8}, "highlightMode": "karaoke", "textTransform": "uppercase", "wordAnimation": "slideUp"}
    },
    {
      "name": "candy", "title": "Candy",
      "slots": [{"name": "accent", "kind": "color", "default": "pink"}],
      "style": {"activeWordColor": "{accent}", "activeWordScale": 1.12, "fontSize": 92, "strokeColor": "#5B1140", "strokeWidth": 8, "textTransform": "uppercase", "wordAnimation": "bounceIn"}
    },
    {
      "name": "inferno", "title": "Inferno",
      "slots": [{"name": "accent", "kind": "color", "default": "orange"}],
      "style": {"activeWordColor": "{accent}", "fontSize": 96, "highlightMode": "karaoke", "strokeWidth": 9, "textTransform": "uppercase", "wordAnimation": "stomp"}
    },
    {
      "name": "golden", "title": "Golden",
      "slots": [{"name": "color", "kind": "color", "default": "yellow"}],
      "style": {"activeWordColor": "white", "activeWordScale": 1.1, "background": {"color": "black@0.7", "cornerRadius": 18, "mode": "perLine", "paddingHorizontal": 26, "paddingVertical": 8}, "highlightMode": "karaoke", "textColor": "{color}", "textTransform": "uppercase"}
    },
    {
      "name": "typist", "title": "Typist",
      "slots": [{"name": "accent", "kind": "color", "default": "green"}],
      "style": {"activeWordColor": "{accent}", "background": {"color": "black@0.75", "cornerRadius": 6, "mode": "perLine", "paddingHorizontal": 26, "paddingVertical": 8}, "fontFamily": "Courier New", "fontSize": 72, "fontWeight": "bold", "strokeColor": null, "strokeWidth": 0, "textTransform": "lowercase", "wordAnimation": "typewriter"}
    }
    ]
    """#
}
