# CaptionKit

The caption engine: transcript in, styled animated captions burned into video
out. **Headless** — no UI frameworks, no network, no generative AI. The whole
pipeline runs in a unit test or a command-line tool, and every automatic pass
is checked by a measurement rather than by somebody looking.

```
word-level transcript → CaptionDocument → rendered frame(s) → export
```

Three small arraypress packages (subtitle formats, depth blur, recipe rules);
everything else is CoreGraphics, CoreImage, CoreText, NaturalLanguage, Vision
and AVFoundation.

**One library, captions only.** This is the merge of the open
`swift-caption-kit-lite` and the private editor engine behind the Caption
Studio app (both retired, their history bundled; the old engine's repository
is `swift-caption-kit-archived`). What came across is what works with no one
watching — automatic emphasis and emoji, a hook title, captions behind the
speaker where they stay legible, translation re-timing, the platform safe
zones — and, since 0.8.0, stickers placed by rule rather than by hand. What
stayed behind needs an eye or is not a caption: hand-placed stickers and
motion paths, B-roll, music and sound effects, colour grading, face
retouching, the generative AI passes, the editor UI.

## Install

```swift
.package(url: "https://github.com/arraypress/swift-caption-kit.git", from: "0.8.0")
// .product(name: "CaptionKit", package: "swift-caption-kit")
```

## The parity rule

**There is exactly one function that draws a caption** —
`CaptionRenderer.draw(document:in:at:)` — and every consumer calls it. It is a
pure function of `(document, time)`: no `CATextLayer`, no `CAAnimation`, no
`AVVideoCompositionCoreAnimationTool`. A preview and an export are identical by
construction. **Never add a second rendering path.**

## What's in the box

**Styling** — 61 presets (`StylePresets`), heavy/hollow text, stroke
layers, drop and hard shadows, 3-D extrusion, glow, gradient fills, image
fills, synthetic slant, scanlines, chromatic aberration, per-line /
whole-block / per-word background pills, block rotation and a seeded
per-card tilt, stacked lines sized to one width, speaker colours, names and
dashes, and a second-language line.

**Animation** — 25 word entrances (`bounce-in`, `pop-on`, `stomp`,
`typewriter`, `whip-in`, `smear-in`, `spiral-in`…), 7 card entrances
(`slide-in-left` among them), a weight ramp that can hold, and six
spoken-word highlight modes: `karaoke`, `active-word`, `active-box`,
`active-underline`, `spotlight`, `none` — which can sit on the card's key
words instead of following the voice. All pure functions of time. Every
value is kebab-case, like the preset names.

**Custom styles** — `CaptionStyle` is `Codable`, so a style is a JSON file.
Nothing extra to learn, and no format to invent.

## The presets are data: `CaptionStyles`

The style model (`CaptionStyle`, `WordStyle`, `StyleColor`, `GroupingRules`)
and the 61 presets live in their own target, `CaptionStyles`, which
`CaptionKit` re-exports. It stays a separate target so the style data builds
without AVFoundation or Vision, but it is not a separate product any more: the
only other engine that imported it on its own is archived, and one product is
one less thing to keep in step.

The presets are a JSON catalogue compiled in as a Swift string — not a
resource bundle, which breaks beside a Homebrew binary reached through a
symlink. Each entry lists only what differs from `CaptionStyle()`, colours as
`yellow`, `#00E676` or `black@0.4`, with `{slot}` markers where a knob goes:

```json
{
  "name": "color-box", "title": "Color Box", "featured": true,
  "slots": [{"name": "accent", "kind": "colors", "default": "#2ECC40,#FFDC00,#FF4136,#B10DC9"}],
  "style": {"fontSize": 88, "fontWeight": "black", "highlightMode": "active-box", "wordColorPalette": "{accent}", …}
}
```

```swift
import CaptionStyles

let style = try StylePresets.style(named: "color-box", vars: ["accent": "#00E676"])
StylePresets.named("Clean Pop")?.name          // "clean-pop" — case and separators forgiven
StylePresets.catalog.first?.styleSlots         // RecipeKit `StyleSlot`s, for `--var`
try StyleJSON.style(from: ["fontSize": .number(90), "textColor": .string("pink")])  // a partial style, made whole
```

Names are kebab-case. Slots: `accent` (the spoken word, 28 presets), `color`
(the text, 9), `from`/`to` (gradient stops, 6), `palette` (3), and `tile`,
`bubble`, `band`, `speakers`, `depth`, `marker` (1 each); 13 presets have none. A test parses the catalogue with
RecipeKit's `StyleCatalogs` rules and requires no problems: kebab-case unique
names, every key a `CaptionStyle` field (`StyleSchema`, read off the types, so a
misspelt `"fontSzie"` is caught rather than ignored), every marker a slot and
every slot used, every default a colour that reads, every preset a style that
decodes.

**Measured:** all 50 presets, decoded from the JSON, encode byte-identical to
the Swift presets they replaced (every field, every Double), as do the
featured flags, grouping hints and word looks.

### The 2026-10 looks

Eleven presets came with the pieces they needed, each piece measured by a test
rather than looked at (`NewStyleTests`):

| Preset | What it adds |
|---|---|
| `weight-sweep` | `weightRampHolds`: a word already said keeps the ramp's target weight; spaces are reserved at the heavy width so nothing collides (ink of a said word ≥ 1.25× the released ramp) |
| `subtitle` | grouping `speakerBreak: line` (a new speaker takes a new line, two turns a card) and `speakerDash` (a dash opens each line only when two speakers share the card) |
| `lower-third` | `speakerLabel` mode `above` — the name in bold inside the band — and the `slide-in-left` card entrance |
| `two-speaker` | `speakerColors` on the style (a document's own `speakerColors` win) and a `speakerLabel` chip |
| `stacked` | `fitLinesToWidth`: each line scaled to the widest line, up to 2.4× (widths equal within 3 %) |
| `extruded`, `marker`, `glitch` | data only: `extrude`; Marker Felt with the typewriter draw-on; Menlo with RGB split, scanlines and a shiver |
| `bilingual` | `secondaryLine` over the document's `secondaryWords` — the words whose midpoint falls in a card's span, on one line above it |
| `soft-highlight` | `textTransform: sentence`, `activeBoxShape: marker` and `highlightKeyWords` (the emphasised words wear the highlight; with none, the voice leads) |
| `tilted-bounce` | `cardTilt` (a seeded per-card angle, within the bound, deterministic) and `activeWordPalette` (the spoken word cycles colours) |

Speaker looks degrade cleanly: words without a speaker draw as a plain
caption. `hormozi` and `beast` are now `color-box` and `thumbnail`. Every
existing preset draws byte-identical overlays to 0.7.0 across 2,400 renders
(50 presets × 12 times × 9:16 and 16:9 × plain and speaker-and-emphasis words).

## The engine underneath: `CaptionCore`

`Word`, `CaptionCard`, `Cut`, `RenderConfig`, `HighlightRule`, `FaceCensor`;
`CaptionGrouper`, `TimeMap`, `FillerCutter`, `ProfanityFilter`,
`SpeakerAssign`, `AutoPlacement`, `FaceTrack`; `CaptionLayout`, `Reframe`,
`AutoMotion`; the blur, face-cover and gradient filters; `ExportSettings`,
`SubtitleFile` and `OverlayExporter` live in the `CaptionCore` target, which
`CaptionKit` re-exports. The layout and timing helpers the renderer uses are
SPI (`@_spi(CaptionEngine) import CaptionCore`), not public API.

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

Exports that re-encode the sound (any cut, speed ramp, bleep or volume change)
ask the AAC encoder for 128 kb/s where it offers that — 44.1 and 48 kHz — and
otherwise for the highest bitrate it does offer: 64 kb/s for 22.05 kHz mono,
the format `say` writes. A fixed 128 kb/s was refused there ("Cannot Encode
Media"), so every cut export of such a clip failed.

## Usage

```swift
import CaptionKit

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

## The automatic passes — no eye needed

Each of these decides by rule, gives the same answer every run, and reports
what it decided as data a test or `caption check` can hold it to.

The fixture for the numbers below: two generated portraits (9:16, a dark
studio wall and a white overcast sky) with a slow zoom, under 12 seconds of a
`say` voice, transcribed by Apple's recogniser — 31 words, no punctuation.

### Emphasis — `EmphasisSuggester`

```swift
let (cards, count) = EmphasisSuggester.emphasize(cards: document.cards)
```

One word per card — the one that carries it — chosen by on-device
part-of-speech tagging (NaturalLanguage): a number scores 4, a noun 3, an
adjective 2.2 (the floor), a long word a little more, anything under three
letters nothing. It gets the next colour of a rotating palette as an ordinary
`WordStyle`. A word somebody already coloured (a recipe's `words.emphasis`) is
left alone. On the fixture: 5 cards, 5 words — "habits",
"business", "meeting", "travel", "win" — the same on every run.

### Emoji — `EmojiSuggester`, `EmojiCatalog`

```swift
let (cards, count) = EmojiSuggester.suggest(cards: document.cards)
```

A keyword gets its emoji inline, right after it in the caption line
(`WordStyle.emoji`), popping on with the word. The table is data — 65 emoji,
273 keywords, written for this library — compiled in as JSON
(`EmojiCatalogText`) and checked by a test: one emoji each, lowercase letters,
no word listed twice. Words that are mostly filler in speech ("right", "look",
"think", "time") are left out on purpose. At most one per card and four
seconds apart; never on a censored word. On the fixture: "business 💼" and
"money 💰" ("coffee" fell inside the four seconds).

### A hook title — `HookBuilder`, `HookTemplates`

```swift
let made = await HookBuilder.build(text: "Three things nobody tells you", document: document)
document.hook = made.hook          // drawn by the same renderer, above the captions
print(made.report)                 // where it went, and what was measured
```

An opening title over the first seconds, placed by rule and measured:

- **Where:** inside the platform safe zone within the canvas safe area
  (`PlatformZones`), clear of every face found in the frames it covers and of
  every caption on screen with it, as near the upper third as that allows. If it
  does not fit the type steps down (to 60%); if nothing clears, it takes the
  least-overlapping height and the report says `placed: false`.
- **Contrast:** the footage behind it is measured — WCAG relative luminance,
  the worst-case 90th percentile (10th for dark type) over five frames. Below
  WCAG's 3:1 for large text, a plate goes behind the type, just dark enough to
  reach 4.5:1 (at most 85%).
- **Read back:** `HookBuilder.readBack` draws the finished frame — footage,
  captions, title — and counts the title's words on-device text recognition
  reads.

Three looks as data (`bold`, `boxed`, `clean`), the same partial-style JSON the
presets use. `HookText.automatic` takes the opening sentence, or the first
card when the transcript carries no punctuation (Apple's recogniser often
gives none), cut to eight words.

Measured on the fixture: on the dark studio wall the title went above the
face at 60% size, contrast 8.2:1, no plate;
on the white sky `bold` and `clean` got an 85% black plate (5.3:1) and
`boxed` needed none (14.7:1). In every case 0% over the face, 0% over the
captions, inside the safe zone, and text recognition read back 100% of the
title — on the rendered frame and again on a frame decoded from the encoded
video.

### Captions behind the speaker — `SubjectCoverage`, `SubjectMasker`

```swift
let measured = await SubjectCoverage.measure(document)
document.behindSubject = BehindSubject(cards: SubjectCoverage.behindCards(measured))
```

The person is laid back over the caption from the clean frame (Vision person
segmentation, `SubjectMasker` — the same masks in the export, the preview and
the measurement), so the words sit in the scene. Only where they stay legible:
each card is sampled at three moments, each word's share under the person
taken, and a card goes behind only if its worst word is covered no more than
`SubjectCoverage.maximumCoverage` — **5%**, measured:

| Word covered by the person | Words | Read back behind |
|---|---|---|
| 0% | 7,800 | 99.6% |
| 0.1–2% | 528 | 96.4% |
| 2–5% | 401 | 98.0% |
| 5–8% | 315 | 83.5% |
| 8–10% | 178 | 80.3% |
| 10–12% | 153 | 63.4% |
| 15–20% | 385 | 32.7% |
| 25–30% | 447 | 8.3% |
| 50–100% | 13,663 | 0.1% |

Six presets (karaoke, color-box, boxed, clean-pop, thumbnail, minimal), twelve
sentences, twenty heights, over four generated portraits; only the 26,181
words text recognition read with the caption in front are counted, so a word
lost behind is the person's doing. The knee is at 5%: by style, words covered
up to 5% read back 96–99%, up to 10% 92–96%, up to 15% 88–93%.

End to end on the fixture (color-box, two words a card, high in the frame so the
speaker's head crosses the captions as the shot slowly zooms): 7 of 16 cards
went behind (worst word 2.4% covered) and 9 stayed in front (5.4–46%). Read
back off frames decoded from the rendered video, the behind cards gave 14 of
14 words; the composite really happened (1,043 pixels differ from a plain
render on the 2.4% card, 0 on a front card).

### Translation re-timing — `TranslationRetimer`

Translation changes the word count, so word timings cannot be copied across.
Each caption keeps its spoken span and the translated words share it in
proportion to their length (plus one, so a short word still gets a beat):

```swift
TranslationRetimer.expanded(words)                 // any entry holding a phrase becomes timed words
TranslationRetimer.retimed(card: card, translatedText: "Así que esto es gratis")
```

An entry of one word is returned exactly as it was, so a per-word transcript
passes through untouched; scripts written without spaces (Chinese, Japanese,
Thai, Lao, Khmer, Myanmar, Tibetan) go through on-device word segmentation.
The translating itself is the fleet's `translate` tool — see the `caption` CLI.
Measured through the real pipeline (`caption transcribe --lines`, `translate`
to Spanish, `caption render --words`): 31 English words in 5 captions became
33 Spanish words; all 5 captions kept their exact start and end, text and
order, and the words ran back to back.

### Platform safe zones — `Platform`, `PlatformZones`, `InkFit`

Which parts of the frame TikTok, Instagram Reels, YouTube Shorts and the
16:9 YouTube player cover with their own interface, and the rectangle left
clear (`PlatformZones.safeRect(for:)`; `safeRectForAll` for every 9:16
platform at once). Every number has a source, in `PlatformZones.swift`:
TikTok's official In-Feed safe-zone template (top 12.5%, bottom 34.4%, sides
11.1%, the rail 27.8% wide from y 43.75%), Meta's Reels guide (14% / 35% / 6%
and a 21% × 40% button notch), Google's Shorts safe zone (288 / 672 / 48 /
192 px of 1080×1920), and for 16:9 YouTube the player's controls (0.108 of a
720p player) with EBU R 95's 5% sides. All three vertical figures are the
platforms' guidance for ads — the only guidance they publish — so they are
the conservative bound for a post. (Until 0.8.0 these were unsourced numbers
carried over from the retired studio app, and let captions run down to 80–83%
of the height, where every official source stops at 65%.)

`PlatformZones.renderConfig(_:clearOf:)` widens a canvas's caption safe area
to a platform's. The layout keeps the text block inside it, but a pill's
padding or an outline reaches past; `InkFit` measures what each card actually
draws and pulls the margins in until the ink fits (on a 9:16 clip, 1 of 1,032
cards across all 61 styles and three platforms still reaches past: one
130-point word).

### Measured instead of looked at — `CaptionContrast`, `FootageStage`, `FootageCheck`, `SettledMoment`

- `CaptionContrast` — the WCAG ratio between a caption's letters and the
  pixels touching them (out to 3 reference points: an outline or a box counts,
  bare letters against bright footage do not), at each sampled card's settled
  moment; `scrim(for:)` picks the weakest black or white gradient (40–85%)
  that lifts the low quartile to 3:1, or none when none helps.
- `FootageStage` — one source frame with the document's footage effects in
  the exporter's stage order (face cover, the camera path and automatic zoom,
  mirror, background blur, scrim), for previews and measurements.
- `FootageCheck` — whether each footage effect did what it says: detail left
  outside and inside the person under a background blur, in the face under a
  face cover (and whether Vision still finds a face), a mirror against the
  flipped frame, a border's and a letterbox's solid share, when the first
  caption appears under a timing offset, how many words a zoom punch lands on.
- `SettledMoment` — the first moment a card has finished arriving (every
  entrance, letter cascade and draw-on done, before any exit): the frame a
  sample should show.
- `FillerHiding` — fillers out of the captions, left in the sound.
- `HookText.repeatsCaption` — an automatic hook that would only repeat the
  first caption is left out.
- `FaceTrack.track(videoURL:canvas:)` returns the crop offset that centres the
  face in a crop of that shape (`FaceTrack.pan`); it used to return the face's
  centre, which `Reframe` reads as a pan across the overflow — a speaker
  walking across a 16:9 frame sat 28% off-centre in a 9:16 crop; now 2.4%.
- `CaptionDocument.captionTimingOffset` now runs the way it is documented:
  negative shows captions early. It ran the other way until 0.8.0.

### Stickers, placed by rule — `StickerPlacer`, `StickerCheck`

An agent says what (`StickerSource`: an emoji, a picture with its
transparency, or a GIF / animated PNG / short video — alpha kept), when
(`StickerTiming`: the *n*th time a word is said, or a span of seconds), how it
moves (`StickerEntrance` — the word entrances' own curves — and `StickerLoop`)
and how big (a fraction of the frame's width). Never where. `StickerPlacer`
puts each one inside the platform safe zone, clear of every head in the frames
it covers (Vision's brow-to-chin face box grown to take in the forehead and
hair), of the caption block at every moment it shares the screen, of the hook
title and of other stickers; spots off the person's body are tried first. An
optional coarse anchor (`upper-right`, `bottom`, …) is a preference within a
quarter of the frame, still checked. When nothing fits it shrinks in steps
(100, 85, 70, 55 %) and then refuses, naming what blocked it. Restrained by
default (`StickerRules`): one on screen at a time, two seconds clear between
them. `StickerCheck` re-measures every placed sticker from the footage —
safe-zone containment, head / caption / hook overlap — and confirms it was
drawn: the share of its box's pixels that change with it, at three moments.

```swift
let placed = try await StickerPlacer.place(
    [StickerRequest(source: .emoji("☕️"), timing: .word("coffee"), loop: .float)],
    in: document, platform: .tiktok)
document.placedStickers = placed
let reports = await StickerCheck.measure(document, platform: .tiktok)  // ok, overlaps, drawn
```

## Measured on real speech: fillers, pauses and the splice

Two public-domain recordings: five minutes of a 1985 oral history (Hanford
Mills Museum, archive.org, Public Domain Mark) and four minutes of a NASA crew
interview (STS-133, archive.org, US government work). `FillerCutter` with
fillers on and pauses over 1 s, then `Splicer`, via `caption cut --verify`:

| Measure | oral history (5:00) | interview (4:00) |
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

This is the caption engine, not an editor. There are no hand-placed stickers,
picture-in-picture B-roll, appended clips, music beds, sound effects, colour
grading, face retouching or generative AI passes — those stayed with the
retired editor engine, because each one is judged by looking, or is not a
caption. (Music ducking and picture-in-picture belong to `vid`.)

Two consequences worth knowing:

**Projects from the retired editor engine survive a round-trip.** A document
carrying the editor's stickers (its `stickers` key — rule-placed ones are
`placedStickers`) or a grade decodes here, renders its captions, and saves with
those keys **intact** — see `PreservedValue`. This engine never reads them and
never drops them, which also means keys added by a future version survive.

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
