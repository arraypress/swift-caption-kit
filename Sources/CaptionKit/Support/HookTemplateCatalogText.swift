//
//  HookTemplateCatalogText.swift
//  CaptionKit
//
//  Created by David Sherlock on 2026.
//
//  The hook-title looks, as data — the same partial-style JSON the caption
//  presets use (only what differs from `CaptionStyle()`; colours `white`,
//  `#FFD400`, `black@0.6`). Compiled in rather than shipped as a resource, for
//  the same Homebrew-symlink reason as the presets.
//
//  Every template turns highlighting off (a title has no spoken word) and
//  enters all at once. Checked by a test: every name kebab-case and unique,
//  every key a style field, every style decodes.
//

enum HookTemplateCatalogText {

    static let templates = #"""
    [
      {"name": "bold", "summary": "Heavy white capitals, thick black outline, stomped on",
       "style": {"fontSize": 112, "fontWeight": "black", "textTransform": "uppercase", "strokeWidth": 10,
                 "highlightMode": "none", "activeWordColor": null, "activeWordScale": 1,
                 "cardAnimation": "stomp", "animationDuration": 0.2}},
      {"name": "boxed", "summary": "Black type on a yellow block, popped on",
       "style": {"fontSize": 96, "fontWeight": "heavy", "textColor": "black", "strokeColor": null, "strokeWidth": 0,
                 "shadow": null,
                 "background": {"color": "#FFD400", "cornerRadius": 18, "mode": "block", "paddingHorizontal": 36, "paddingVertical": 18},
                 "highlightMode": "none", "activeWordColor": null, "activeWordScale": 1,
                 "cardAnimation": "popOn", "animationDuration": 0.2}},
      {"name": "clean", "summary": "Bold white sans with a soft shadow, faded in",
       "style": {"fontFamily": "Avenir Next", "fontSize": 92, "fontWeight": "bold", "strokeColor": null, "strokeWidth": 0,
                 "shadow": {"color": "black@0.55", "radius": 14, "offsetX": 0, "offsetY": 4},
                 "highlightMode": "none", "activeWordColor": null, "activeWordScale": 1,
                 "cardAnimation": "fadeIn", "animationDuration": 0.25}}
    ]
    """#
}
