# CaptionKitLite

The caption engine: transcript in, styled animated captions burned into video
out. **Headless** — no UI frameworks, no network, no AI. The whole pipeline
runs in a unit test or a command-line tool.

```
word-level transcript → CaptionDocument → rendered frame(s) → export
```

One external dependency. Everything else is CoreGraphics, CoreImage, CoreText,
Vision and AVFoundation.

## The parity rule

**There is exactly one function that draws a caption** —
`CaptionRenderer.draw(document:in:at:)` — and every consumer calls it. It is a
pure function of `(document, time)`: no `CATextLayer`, no `CAAnimation`, no
`AVVideoCompositionCoreAnimationTool`. A preview and an export are identical by
construction. **Never add a second rendering path.**

## What's in the box

**Styling** — ~50 presets (`StylePresets.all`), heavy/hollow text, stroke
layers, drop and hard shadows, glow, gradient fills, image fills, synthetic
slant, scanlines, chromatic aberration, per-line / whole-block / per-word
background pills, and block rotation.

**Animation** — 25 word entrances (`bounceIn`, `popOn`, `stomp`, `typewriter`,
`whipIn`, `smearIn`, `spiralIn`…), 6 card entrances, and five spoken-word
highlight modes: `karaoke`, `activeWord`, `activeBox`, `activeUnderline`,
`none`. All pure functions of time.

**Custom styles** — `CaptionStyle` is `Codable`, so a style is a JSON file.
Nothing extra to learn, and no format to invent.

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
document.style = StylePresets.all.first { $0.name == "Karaoke" }!.style
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
- One dependency: [swift-depth-blur](https://github.com/arraypress/swift-depth-blur)

Transcription is deliberately out of scope: bring word-level timings from
whatever you like. `Word(text:start:end:)` is the entire contract.

## Licence

MIT. See [LICENSE](LICENSE).
