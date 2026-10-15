# CaptionKitLite

The caption engine: transcript in, styled animated captions burned into video
out. **Headless** — no UI frameworks, no network, no AI. The whole pipeline
runs in a unit test or a command-line tool.

```
word-level transcript → CaptionDocument → rendered frame(s) → export
```

Three small arraypress packages (subtitle formats, depth blur, recipe rules);
everything else is CoreGraphics, CoreImage, CoreText, Vision and AVFoundation.

## The parity rule

**There is exactly one function that draws a caption** —
`CaptionRenderer.draw(document:in:at:)` — and every consumer calls it. It is a
pure function of `(document, time)`: no `CATextLayer`, no `CAAnimation`, no
`AVVideoCompositionCoreAnimationTool`. A preview and an export are identical by
construction. **Never add a second rendering path.**

## What's in the box

**Styling** — 50 presets (`StylePresets`), heavy/hollow text, stroke
layers, drop and hard shadows, glow, gradient fills, image fills, synthetic
slant, scanlines, chromatic aberration, per-line / whole-block / per-word
background pills, and block rotation.

**Animation** — 25 word entrances (`bounceIn`, `popOn`, `stomp`, `typewriter`,
`whipIn`, `smearIn`, `spiralIn`…), 6 card entrances, and five spoken-word
highlight modes: `karaoke`, `activeWord`, `activeBox`, `activeUnderline`,
`none`. All pure functions of time.

**Custom styles** — `CaptionStyle` is `Codable`, so a style is a JSON file.
Nothing extra to learn, and no format to invent.

## The presets are data: `CaptionStyles`

The style model (`CaptionStyle`, `WordStyle`, `StyleColor`, `GroupingRules`)
and the 50 presets live in their own product, `CaptionStyles`, which
`CaptionKitLite` re-exports. It is the one copy: the fuller
`swift-caption-kit` depends on it rather than carrying its own (it used to
carry a byte-identical 904-line `StylePresets.swift` and the four model files).

The presets are a JSON catalogue compiled in as a Swift string — not a
resource bundle, which breaks beside a Homebrew binary reached through a
symlink. Each entry lists only what differs from `CaptionStyle()`, colours as
`yellow`, `#00E676` or `black@0.4`, with `{slot}` markers where a knob goes:

```json
{
  "name": "hormozi", "title": "Hormozi", "featured": true,
  "slots": [{"name": "accent", "kind": "colors", "default": "#2ECC40,#FFDC00,#FF4136,#B10DC9"}],
  "style": {"fontSize": 88, "fontWeight": "black", "highlightMode": "activeBox", "wordColorPalette": "{accent}", …}
}
```

```swift
import CaptionStyles

let style = try StylePresets.style(named: "hormozi", vars: ["accent": "#00E676"])
StylePresets.named("Clean Pop")?.name          // "clean-pop" — case and separators forgiven
StylePresets.catalog.first?.styleSlots         // RecipeKit `StyleSlot`s, for `--var`
try StyleJSON.style(from: ["fontSize": .number(90), "textColor": .string("pink")])  // a partial style, made whole
```

Names are kebab-case. Slots: `accent` (the spoken word, 23 presets), `color`
(the text, 8), `from`/`to` (gradient stops, 6), `palette` (2), `tile` and
`bubble` (1 each); 11 presets have none. A test parses the catalogue with
RecipeKit's `StyleCatalogs` rules and requires no problems: kebab-case unique
names, every key a `CaptionStyle` field (`StyleSchema`, read off the types, so a
misspelt `"fontSzie"` is caught rather than ignored), every marker a slot and
every slot used, every default a colour that reads, every preset a style that
decodes.

**Measured:** all 50 presets, decoded from the JSON, encode byte-identical to
the Swift presets they replaced (every field, every Double), as do the
featured flags, grouping hints and word looks; and `swift-caption-kit` renders
200/200 frames identical to this engine across the 50 presets × 4 moments.

**Grouping** — `CaptionGrouper` turns a word stream into readable cards by
pause, line and character rules; `reflowLines` re-lays a card without touching
timing.

**Cuts** — `FillerCutter` finds filler words and dead air and proposes
`Cut`s (remove outright, or speed-ramp the pause Descript-style);
`ProfanityFilter` is a deterministic word-list censor with a synthesised bleep;
`SpeakerAssign` maps diarization turns onto words for per-speaker colours.

**Face-aware** — `AutoPlacement` puts captions just below the speaker's face
and never over it; `FaceTrack` follows the largest face and emits smoothed crop
keyframes, so one wide source batch-exports to 9:16, 1:1 and 16:9 with the
speaker in frame; `FaceCensor` covers a face with blur, pixelation or an emoji.
All on-device Vision.

**Rendering & export** — `CaptionLayout` (CoreText measurement, per-word
fonts), `Reframe` (aspect-fill, crop offset, face-track keyframes),
`AutoMotion` (breathing zoom, punch-ins on emphasized words), burn-in export,
`OverlayExporter` (the caption layer alone as ProRes 4444 **with alpha**, for
cutting in Final Cut or Premiere), and SRT/VTT via `SubtitleFile`.

## Usage

```swift
import CaptionKitLite

let words = [Word(text: "hello", start: 0.0, end: 0.4)]   // from any transcriber
let cards = CaptionGrouper.group(words, rules: GroupingRules())

var document = CaptionDocument(cards: cards)
document.videoURL = videoURL          // required by the exporter
document.style = try StylePresets.style(named: "karaoke")
document.renderConfig = .reel

// A single frame — cheap, for previewing a style.
let frame = CaptionRenderer.renderOverlay(document: document, at: 1.2)

// Or the whole video.
try await CaptionExporter.export(document: document, to: outputURL)
```

Removing filler words and dead air:

```swift
let result = FillerCutter.detect(
    in: words,
    rules: FillerCutRules(
        fillers: ["um", "uh", "like"],
        trimSilencesLongerThan: 1.0,
        silenceSpeed: 1.8          // hurry the pause rather than cut it
    ),
    sourceDuration: duration
)
document.cuts = result.cuts
```

## Measured on real speech: fillers, pauses and the splice

Two public-domain recordings: five minutes of a 1985 oral history (Hanford
Mills Museum, archive.org, Public Domain Mark) and four minutes of a NASA crew
interview (STS-133, archive.org, US government work). `FillerCutter` with
fillers on and pauses over 1 s, then `Splicer`, via `caption cut --verify`:

| | oral history (5:00) | interview (4:00) |
|---|---|---|
| Cuts | 11 — 9 pauses, 2 "uh" | 5 — 3 pauses, "um", "uh uh" |
| Shorter by | 24.2 s | 6.2 s |
| Whole run, transcription included | 4.9 s | 5.3 s |
| Kept words heard again in order | 92.1% | 98.2% |
| Fillers heard again | 2 × "uh" | 1 × "um" |

- **Apple's recogniser wrote fillers as fillers.** "uh" stayed "uh" on real
  voices; the "Ah" seen in earlier probes came from a synthetic (`say`) voice.
  It wrote only 2–3 per ~900 words, which is low for unscripted speech —
  whether it drops others was not measured (nobody listened).
- **The second listen finds fillers the first missed.** Both "uh"s it heard in
  the cut oral history sit where the first transcript had no filler at all, so
  the cuts were right and the first pass simply did not write them. The "um" in
  the interview was heard ~0.4 s before the planned cut: Apple's word times come
  on a 0.06 s grid, and the start of that "um" probably survived. Evidence, from
  one case, for more padding before a filler than after it.
- **"Words heard again" is a weak signal on old recordings.** The recogniser
  agreed with itself 100% on the same file twice, and 100% after an uncut
  re-encode — but 92% after the cuts, with the differences spread through the
  whole five minutes ("sawmill" → "song you know" thirty seconds from any cut),
  not at the seams. Removing the pauses changes how it segments a noisy tape. On
  the clean studio interview the same score was 98%.

## What it is not

This is the caption engine, not an editor. There are no stickers, titles,
picture-in-picture B-roll, appended clips, music beds, sound effects, colour
grading, or AI passes — those belong to the application built on top.

Two consequences worth knowing:

**Projects from a fuller engine survive a round-trip.** A document carrying
stickers or a grade decodes here, renders its captions, and saves with those
keys **intact** — see `PreservedValue`. This engine never reads them and never
drops them, which also means keys added by a future version survive.

**Cut treatments are all here.** `none`, `dipToBlack`, `dipToWhite` and
`punchIn` are geometry the exporter computes; `whipPan`, `zoomBlur` and
`glitch` run through Core Image in `CutTransition`. No grading dependency —
they are implemented in this package.

## Requirements

- macOS 26+ / iOS 26+, Swift 6.2
- [swift-subtitle-kit](https://github.com/arraypress/swift-subtitle-kit),
  [swift-depth-blur](https://github.com/arraypress/swift-depth-blur) and
  [swift-recipe-kit](https://github.com/arraypress/swift-recipe-kit)

Transcription is deliberately out of scope: bring word-level timings from
whatever you like. `Word(text:start:end:)` is the entire contract.

## Licence

MIT. See [LICENSE](LICENSE).
