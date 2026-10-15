//
//  CaptionExporter.swift
//  CaptionKit
//
//  Created by David Sherlock on 2026.
//

@_spi(CaptionEngine) import CaptionCore
@preconcurrency import AVFoundation
import CoreGraphics
import CoreImage
import DepthBlur
import Foundation

/// Burns captions into a video with a streaming decode → composite → encode
/// pass.
///
/// Every output frame is produced by drawing the decoded source frame into
/// the output canvas (aspect-fill, so a 16:9 source reframes into a 9:16
/// reel) and then calling ``CaptionRenderer/draw(document:in:at:)`` — the
/// *same* function the preview uses, which is the preview/export parity
/// guarantee.
///
/// Only a few frames are ever in flight (`AVAssetReader` → pixel-buffer pool
/// → `AVAssetWriter`), so memory stays flat regardless of clip length —
/// correct on iOS from day one.
///
/// ```swift
/// try await CaptionExporter.export(document: document, to: outputURL) { fraction in
///     print("\(Int(fraction * 100))%")
/// }
/// ```
public enum CaptionExporter {

    /// Exports the document's video with captions burned in.
    ///
    /// - Parameters:
    ///   - document: The caption document; ``CaptionDocument/videoURL`` must
    ///     be set. Output geometry comes from its ``RenderConfig``.
    ///   - outputURL: Destination (overwritten if present).
    ///   - settings: Codec settings. Default HEVC 12 Mb/s MP4.
    ///   - progress: Optional callback with `0…1` progress.
    public static func export(
        document: CaptionDocument,
        to outputURL: URL,
        settings: ExportSettings = ExportSettings(),
        depthModelURL: URL? = nil,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws {
        guard let videoURL = document.videoURL else { throw ExportError.missingVideoURL }
        try? FileManager.default.removeItem(at: outputURL)

        // Scale the whole render config for higher-res (e.g. 4K) export —
        // the renderer, reframe, and canvas all read renderConfig, so
        // scaling it keeps captions/effects crisp and consistent.
        var document = document
        if settings.resolutionScale != 1 {
            let rc = document.renderConfig
            let scale = settings.resolutionScale
            document.renderConfig = RenderConfig(
                width: Int((CGFloat(rc.width) * scale / 2).rounded()) * 2,
                height: Int((CGFloat(rc.height) * scale / 2).rounded()) * 2,
                framesPerSecond: rc.framesPerSecond,
                safeAreaTop: rc.safeAreaTop,
                safeAreaBottom: rc.safeAreaBottom,
                safeAreaLeft: rc.safeAreaLeft,
                safeAreaRight: rc.safeAreaRight
            )
        }

        let session = try await CaptionExportSession(
            document: document,
            videoURL: videoURL,
            outputURL: outputURL,
            settings: settings,
            depthModelURL: depthModelURL,
            progress: progress
        )
        try await withTaskCancellationHandler {
            try await session.run()
        } onCancel: {
            session.cancel()
        }
    }
}

// MARK: - Session

/// One export run. Marked `@unchecked Sendable`: the AVFoundation objects are
/// only touched from the reader/writer callback queues and the mutable
/// completion state is lock-protected.
private final class CaptionExportSession: @unchecked Sendable {

    private let document: CaptionDocument
    private let settings: ExportSettings
    private let progress: (@Sendable (Double) -> Void)?

    private let reader: AVAssetReader
    /// The sound has a reader of its own. Sharing one reader couples the
    /// outputs: the video output stops delivering while the audio output's
    /// buffer is full, and the writer stops taking audio until more video
    /// arrives to interleave with it — a deadlock that left a render parked in
    /// `copyNextSampleBuffer` for good. Separate readers buffer independently.
    private let audioReader: AVAssetReader?
    private let writer: AVAssetWriter
    private let videoOutput: AVAssetReaderVideoCompositionOutput
    private let videoInput: AVAssetWriterInput
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor
    private let audioOutput: AVAssetReaderOutput?
    private let audioInput: AVAssetWriterInput?

    private let durationSeconds: Double
    private let sourceSize: CGSize
    private let canvasWidth: Int
    private let canvasHeight: Int
    /// Output→source time mapping when the document has cuts, else `nil`.
    private let timeMap: TimeMap?
    /// Person-segmentation background blur, `nil` when off.
    private let blurFilter: BackgroundBlurFilter?
    /// Tracked privacy face cover, `nil` when off.
    private let censorFilter: FaceCensorFilter?
    private var gradientFilter: GradientOverlayFilter?
    private let depthFilter: DepthBlurFilter?

    private let ciContext = CIContext()
    /// Person masks for captions drawn behind the speaker, `nil` when none are.
    private let subjectMasker: SubjectMasker?
    /// Output-timeline moments where a cut was removed — where cut-style
    /// smoothing (dip / punch-in) applies.
    private let cutBoundaries: [Double]
    /// Source-time moments auto-motion punches land on (emphasized words).
    private let emphasisTimes: [TimeInterval]

    private let videoQueue = DispatchQueue(label: "captionkit.export.video")
    private let audioQueue = DispatchQueue(label: "captionkit.export.audio")

    private let lock = NSLock()
    private var finishedInputs = 0
    private var totalInputs = 1
    private var terminalError: Error?
    private var cancelled = false
    private var finished: CheckedContinuation<Void, Error>?

    init(
        document: CaptionDocument,
        videoURL: URL,
        outputURL: URL,
        settings: ExportSettings,
        depthModelURL: URL? = nil,
        progress: (@Sendable (Double) -> Void)?
    ) async throws {
        self.document = document
        self.settings = settings
        self.progress = progress

        let sourceAsset = AVURLAsset(url: videoURL)
        guard let sourceVideoTrack = try await sourceAsset.loadTracks(withMediaType: .video).first else {
            throw ExportError.noVideoTrack
        }
        let mainDuration = try await sourceAsset.load(.duration).seconds
        let sourceDuration = mainDuration

        // Audio comes from the source video, or from a replacement file
        // (e.g. AudioCleaner output) on the same timeline.
        var audioAsset: AVAsset?
        if settings.includeAudio {
            audioAsset = settings.audioOverrideURL.map { AVURLAsset(url: $0) } ?? sourceAsset
        }
        let sourceAudioTrack = audioAsset != nil
            ? try await audioAsset!.loadTracks(withMediaType: .audio).first
            : nil
        let hasAudioOverride = settings.audioOverrideURL != nil && sourceAudioTrack != nil

        // Cuts: splice the kept ranges into a composition and read that —
        // AVFoundation keeps audio/video sample-accurately aligned across
        // the edit boundaries. Caption times map back through `timeMap`.
        // An audio override or sound effects also force the composition
        // path (multiple audio sources need mixing).
        let map = TimeMap(cuts: document.cuts)
        let hasCuts = !map.cuts.isEmpty
        timeMap = hasCuts ? map : nil
        gradientFilter = document.gradientOverlay.map(GradientOverlayFilter.init)
        if let blur = document.backgroundBlur, blur > 0.5 {
            // Radius is in 1920-reference points; scale to canvas pixels.
            blurFilter = BackgroundBlurFilter(radius: blur * Double(document.renderConfig.height) / 1920)
        } else {
            blurFilter = nil
        }
        censorFilter = document.faceCensor.flatMap(FaceCensorFilter.init(censor:))
        subjectMasker = document.behindSubject?.cards.isEmpty == false ? SubjectMasker() : nil
        // Depth blur needs the model the host resolves — off if it's absent.
        if let depthBlur = document.depthBlur, depthBlur.isActive, let depthModelURL,
           let estimator = try? DepthEstimator(modelURL: depthModelURL) {
            depthFilter = DepthBlurFilter(settings: depthBlur, estimator: estimator)
        } else {
            depthFilter = nil
        }
        // Punch times: emphasized words (when enabled) plus music beats.
        // Beats live on the music/output timeline; punches run in source
        // time, so map them across.
        var punchTimes = document.autoMotion?.punchOnEmphasis == true
            ? AutoMotion.emphasisTimes(in: document.cards)
            : []
        if document.autoMotion != nil, let beats = document.beatTimes {
            punchTimes += beats.map { map.sourceTime(forOutput: $0) }
        }
        emphasisTimes = punchTimes.sorted()
        if document.cutStyle != .none {
            // Only REMOVED cuts get boundary effects (dips, whips, punches)
            // — a speed ramp is already its own smooth transition. Appended
            // clip splices get the same treatment: the seam IS a cut.
            let boundaries = hasCuts
                ? map.cuts
                    .filter { $0.speed == nil }
                    .map { map.outputTime(forSource: $0.start) }
                    .filter { $0 > 0.05 }
                : []
            cutBoundaries = boundaries.sorted()
        } else {
            cutBoundaries = []
        }
        let voiceVolume = max(0, min(2, document.voiceVolume))
        // Words to bleep: the same censor decision the renderer's black bar
        // uses, so the audio and the video censor exactly the same words.
        let censorWords = settings.includeAudio
            ? document.allWords.filter {
                ProfanityFilter.shouldCensor($0, autoCensor: document.style.censorProfanity == true)
            }
            : []

        let readingAsset: AVAsset
        let readerVideoTrack: AVAssetTrack
        var readerAudioTrack: AVAssetTrack?
        var mixTracks: [AVAssetTrack] = []
        var mixParameters: [AVMutableAudioMixInputParameters] = []
        if hasCuts || hasAudioOverride || voiceVolume != 1 || !censorWords.isEmpty {
            let spliced = AVMutableComposition()
            guard let videoTrack = spliced.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                throw ExportError.noVideoTrack
            }
            videoTrack.preferredTransform = try await sourceVideoTrack.load(.preferredTransform)

            // ClipTracks keeps the asset alive: AVAssetTrack does NOT retain
            // its asset, and a dangling track fails insertTimeRange with
            // -11800/-12780.
            struct ClipTracks { let asset: AVAsset; let video: AVAssetTrack; let audio: AVAssetTrack? }
            let clipTracks: [ClipTracks] = [ClipTracks(asset: sourceAsset, video: sourceVideoTrack, audio: sourceAudioTrack)]

            var audioTrack: AVMutableCompositionTrack?
            if clipTracks.contains(where: { $0.audio != nil }) {
                audioTrack = spliced.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            }

            // A replacement audio file can be a hair shorter than the video
            // (encoder padding trimmed); clamp its inserts to what exists.
            var audioDuration = sourceDuration
            if hasAudioOverride, let audioAsset {
                audioDuration = try await audioAsset.load(.duration).seconds
            }

            var cursor = CMTime.zero
            for segment in map.playbackSegments(sourceDuration: sourceDuration) {
                let segmentStart = cursor
                // One source, so a kept span is always a single piece of it.
                for piece in [(clipIndex: 0, localStart: segment.start, localEnd: segment.end)] {
                    let tracks = clipTracks[piece.clipIndex]
                    let range = CMTimeRange(
                        start: CMTime(seconds: piece.localStart, preferredTimescale: 600),
                        end: CMTime(seconds: piece.localEnd, preferredTimescale: 600)
                    )
                    try videoTrack.insertTimeRange(range, of: tracks.video, at: cursor)
                    if let audioTrack, let clipAudio = tracks.audio {
                        // Only the main clip's audio can be the (possibly
                        // shorter) override file — clamp just there.
                        let limit = piece.clipIndex == 0 ? audioDuration : .greatestFiniteMagnitude
                        if piece.localStart < limit {
                            let audioRange = CMTimeRange(
                                start: range.start,
                                end: CMTime(seconds: min(piece.localEnd, limit), preferredTimescale: 600)
                            )
                            try audioTrack.insertTimeRange(audioRange, of: clipAudio, at: cursor)
                        }
                    }
                    cursor = cursor + range.duration
                }
                // Speed ramp: compress the whole just-inserted segment.
                if let speed = segment.speed {
                    let inserted = CMTimeRange(start: segmentStart, end: cursor)
                    let scaled = CMTime(seconds: inserted.duration.seconds / speed, preferredTimescale: 600)
                    videoTrack.scaleTimeRange(inserted, toDuration: scaled)
                    audioTrack?.scaleTimeRange(inserted, toDuration: scaled)
                    cursor = segmentStart + scaled
                }
            }

            // Censor ranges on the OUTPUT timeline — padded a touch, then
            // merged so the voice-duck envelope stays monotonic even when two
            // swear words sit back-to-back. Written out imperatively with
            // explicit types (chained map/filter/sort over labelled tuples
            // chokes the type-checker).
            let censorPad = 0.03
            var censorRaw: [(start: Double, end: Double)] = []
            for word in censorWords {
                let start = max(0, map.outputTime(forSource: word.start) - censorPad)
                let end = map.outputTime(forSource: word.end) + censorPad
                if end > start { censorRaw.append((start: start, end: end)) }
            }
            censorRaw.sort { $0.start < $1.start }
            var censorOutputRanges: [(start: Double, end: Double)] = []
            for range in censorRaw {
                if let last = censorOutputRanges.last, range.start <= last.end {
                    censorOutputRanges[censorOutputRanges.count - 1].end = max(last.end, range.end)
                } else {
                    censorOutputRanges.append(range)
                }
            }

            // Sound effects: one extra composition track per effect, placed
            // at its cut-adjusted output time, mixed via AVAudioMix volumes.
            if let audioTrack {
                mixTracks.append(audioTrack)
                let base = Float(voiceVolume)
                if voiceVolume != 1 || !censorOutputRanges.isEmpty {
                    let voice = AVMutableAudioMixInputParameters(track: audioTrack)
                    voice.setVolume(base, at: .zero)
                    // Silence the voice under each censored word; the bleep
                    // track fills the gap. Restored to `base` right after.
                    for range in censorOutputRanges {
                        voice.setVolume(0, at: CMTime(seconds: range.start, preferredTimescale: 600))
                        voice.setVolume(base, at: CMTime(seconds: range.end, preferredTimescale: 600))
                    }
                    mixParameters.append(voice)
                }
            }


            // Bleep bed: a synthesized 1 kHz tone spliced over each censored
            // range, replacing the voice we just ducked to silence.
            if !censorOutputRanges.isEmpty {
                let longest = censorOutputRanges.map { $0.end - $0.start }.max() ?? 0
                if longest > 0.01, let toneURL = BleepTone.makeFile(duration: longest + 0.1) {
                    let toneAsset = AVURLAsset(url: toneURL)
                    if let toneSource = try? await toneAsset.loadTracks(withMediaType: .audio).first,
                       let bleepTrack = spliced.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                        let toneDuration = (try? await toneAsset.load(.duration).seconds) ?? 0
                        for range in censorOutputRanges {
                            let length = min(range.end - range.start, toneDuration)
                            guard length > 0.01, range.start >= 0 else { continue }
                            try? bleepTrack.insertTimeRange(
                                CMTimeRange(start: .zero, duration: CMTime(seconds: length, preferredTimescale: 600)),
                                of: toneSource,
                                at: CMTime(seconds: range.start, preferredTimescale: 600)
                            )
                        }
                        let parameters = AVMutableAudioMixInputParameters(track: bleepTrack)
                        parameters.setVolume(0.5, at: .zero)
                        mixParameters.append(parameters)
                        mixTracks.append(bleepTrack)
                    }
                }
            }


            readingAsset = spliced
            readerVideoTrack = videoTrack
            readerAudioTrack = audioTrack
            durationSeconds = cursor.seconds
        } else {
            readingAsset = sourceAsset
            readerVideoTrack = sourceVideoTrack
            readerAudioTrack = sourceAudioTrack
            durationSeconds = sourceDuration
        }

        // A properties-based video composition bakes the track's preferred
        // transform, so rotated phone footage arrives upright.
        let composition = try await AVVideoComposition.videoComposition(withPropertiesOf: readingAsset)
        sourceSize = composition.renderSize

        reader = try AVAssetReader(asset: readingAsset)
        let output = AVAssetReaderVideoCompositionOutput(
            videoTracks: [readerVideoTrack],
            videoSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        )
        output.videoComposition = composition
        output.alwaysCopiesSampleData = false
        reader.add(output)
        videoOutput = output

        canvasWidth = document.renderConfig.width
        canvasHeight = document.renderConfig.height

        writer = try AVAssetWriter(outputURL: outputURL, fileType: settings.fileType)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: settings.codec.avCodec,
            AVVideoWidthKey: canvasWidth,
            AVVideoHeightKey: canvasHeight,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: settings.resolvedBitRate(
                    width: canvasWidth,
                    height: canvasHeight,
                    frameRate: document.renderConfig.framesPerSecond
                ),
            ],
        ])
        input.expectsMediaDataInRealTime = false
        writer.add(input)
        videoInput = input

        adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: canvasWidth,
                kCVPixelBufferHeightKey as String: canvasHeight,
            ]
        )

        // Audio: passthrough compressed when uncut and unmixed. With cuts
        // (compressed packets can't be spliced mid-stream), a PCM override
        // file, or sound effects (mixing), decode to PCM — through an
        // audio-mix output when there are multiple tracks — and let the
        // writer re-encode AAC.
        let hint = try await sourceAudioTrack?.load(.formatDescriptions).first
        if !mixTracks.isEmpty {
            let mixOutput = AVAssetReaderAudioMixOutput(audioTracks: mixTracks, audioSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
            ])
            // Time-domain stretching keeps sped-up speech at natural pitch
            // (no chipmunk on speed-ramped silences).
            mixOutput.audioTimePitchAlgorithm = .timeDomain
            if !mixParameters.isEmpty {
                let mix = AVMutableAudioMix()
                mix.inputParameters = mixParameters
                mixOutput.audioMix = mix
            }
            let audioReading = try AVAssetReader(asset: readingAsset)
            audioReading.add(mixOutput)
            audioReader = audioReading
            audioOutput = mixOutput
            let audioIn = AVAssetWriterInput(mediaType: .audio, outputSettings: AACSettings.writerSettings(hint: hint))
            audioIn.expectsMediaDataInRealTime = false
            writer.add(audioIn)
            audioInput = audioIn
            totalInputs = 2
        } else if let readerAudioTrack {
            let audioOut = AVAssetReaderTrackOutput(track: readerAudioTrack, outputSettings: nil)
            let audioReading = try AVAssetReader(asset: readingAsset)
            audioReading.add(audioOut)
            audioReader = audioReading
            audioOutput = audioOut
            let audioIn = AVAssetWriterInput(mediaType: .audio, outputSettings: nil, sourceFormatHint: hint)
            audioIn.expectsMediaDataInRealTime = false
            writer.add(audioIn)
            audioInput = audioIn
            totalInputs = 2
        } else {
            audioReader = nil
            audioOutput = nil
            audioInput = nil
        }
    }

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }

    func run() async throws {
        guard writer.startWriting() else {
            throw ExportError.writerFailed(writer.error?.localizedDescription ?? "could not start")
        }
        guard reader.startReading() else {
            writer.cancelWriting()
            throw ExportError.readerFailed(reader.error?.localizedDescription ?? "could not start")
        }
        if let audioReader, !audioReader.startReading() {
            reader.cancelReading()
            writer.cancelWriting()
            throw ExportError.readerFailed(audioReader.error?.localizedDescription ?? "could not start")
        }
        writer.startSession(atSourceTime: .zero)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            lock.lock()
            finished = continuation
            lock.unlock()

            videoInput.requestMediaDataWhenReady(on: videoQueue) { [weak self] in
                self?.pumpVideo()
            }
            if let audioInput, audioOutput != nil {
                audioInput.requestMediaDataWhenReady(on: audioQueue) { [weak self] in
                    self?.pumpAudio()
                }
            }
        }
    }

    // MARK: - Pumps

    private func pumpVideo() {
        while !hasFailed, videoInput.isReadyForMoreMediaData {
            if isCancelled { return abort(with: CancellationError()) }
            guard let sample = videoOutput.copyNextSampleBuffer() else {
                if reader.status == .failed {
                    return abort(with: ExportError.readerFailed(reader.error?.localizedDescription ?? "unknown"))
                }
                videoInput.markAsFinished()
                return inputFinished()
            }
            guard let source = CMSampleBufferGetImageBuffer(sample) else { continue }
            let pts = CMSampleBufferGetPresentationTimeStamp(sample)

            do {
                let composed = try compose(source: source, at: pts.seconds)
                if !adaptor.append(composed, withPresentationTime: pts) {
                    return abort(with: ExportError.writerFailed(writer.error?.localizedDescription ?? "video append failed"))
                }
            } catch {
                return abort(with: error)
            }

            if durationSeconds > 0 {
                progress?(min(1, pts.seconds / durationSeconds))
            }
        }
    }

    private func pumpAudio() {
        guard let audioOutput, let audioInput else { return }
        while !hasFailed, audioInput.isReadyForMoreMediaData {
            if isCancelled { return abort(with: CancellationError()) }
            guard let sample = audioOutput.copyNextSampleBuffer() else {
                if let audioReader, audioReader.status == .failed {
                    return abort(with: ExportError.readerFailed(audioReader.error?.localizedDescription ?? "unknown"))
                }
                audioInput.markAsFinished()
                return inputFinished()
            }
            if !audioInput.append(sample) {
                return abort(with: ExportError.writerFailed(writer.error?.localizedDescription ?? "audio append failed"))
            }
        }
    }

    // MARK: - Frame Composition

    /// Draws one source frame aspect-filled into a fresh canvas buffer, then
    /// captions on top via the single renderer.
    private func compose(source: CVPixelBuffer, at time: TimeInterval) throws -> CVPixelBuffer {
        guard let pool = adaptor.pixelBufferPool else { throw ExportError.cannotCreateBuffer }
        var destination: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &destination)
        guard let destination else { throw ExportError.cannotCreateBuffer }

        CVPixelBufferLockBaseAddress(source, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(source, .readOnly) }
        CVPixelBufferLockBaseAddress(destination, [])
        defer { CVPixelBufferUnlockBaseAddress(destination, []) }

        guard let sourceContext = Self.context(wrapping: source),
              let frame = sourceContext.makeImage(),
              let canvas = Self.context(wrapping: destination) else {
            throw ExportError.cannotCreateBuffer
        }

        let canvasSize = CGSize(width: canvasWidth, height: canvasHeight)
        canvas.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
        canvas.fill(CGRect(origin: .zero, size: canvasSize))

        // Aspect-fill reframe: cover the canvas, cropping the overflow,
        // panned by the document's crop offset — the 9:16 reframe of a
        // landscape source keeps the speaker in frame. Punch-in cut
        // smoothing adds a relaxing zoom right after each cut.
        // Cut punch, auto-motion drift, and emphasis punches all compose
        // into one extra scale. Motion runs on source time (it follows the
        // footage), cut punches on output time (they follow the edit).
        // Everything that follows the FOOTAGE runs in source time — with
        // cuts, the frame at output `time` shows source footage from later
        // in the original timeline.
        let drawTime = timeMap?.sourceTime(forOutput: time) ?? time

        var extraScale = punchScale(at: time)
        if let motion = document.autoMotion {
            extraScale *= AutoMotion.scale(at: drawTime, style: motion, emphasisTimes: emphasisTimes)
        }
        // Face-tracked / manual camera path wins over the static crop
        // offset, and can punch in (scale) as well as pan (offset).
        let cropOffset = document.cropKeyframes.flatMap { CropTrack.offset(at: drawTime, keyframes: $0) }
            ?? document.cropOffset
            ?? NormalizedPoint(x: 0.5, y: 0.5)
        if let keyframes = document.cropKeyframes {
            extraScale *= CropTrack.scale(at: drawTime, keyframes: keyframes)
        }
        // Mixed-orientation clips: reframe against THIS frame's dimensions
        // (appended clips can differ from the main video); identical to
        // sourceSize on single-clip projects.
        let placed = Reframe.placement(
            source: CGSize(width: frame.width, height: frame.height),
            canvas: canvasSize,
            offset: cropOffset,
            extraScale: extraScale
        )
        let drawRect = CGRect(origin: placed.origin, size: placed.size)

        let cutFXStrength = CutTransition.needsCoreImage(document.cutStyle)
            ? CutTransition.strength(at: time, boundaries: cutBoundaries)
            : 0

        if gradientFilter != nil || blurFilter != nil || cutFXStrength > 0.01 || censorFilter != nil || depthFilter != nil {
            // CoreImage route: reframe to canvas size first, then blur and
            // grade at canvas resolution — the identical stage order the
            // preview handler uses. Captions still draw over via CG.
            var image = CIImage(cvPixelBuffer: source)
            // Face cover runs in SOURCE space so its track lines up, then
            // rides through the reframe with the footage.
            if let depthFilter {
                image = depthFilter.apply(image)
            }
            if let censorFilter {
                image = censorFilter.apply(image, at: drawTime, sourceSize: image.extent.size)
            }
            image = image
                .transformed(by: CGAffineTransform(
                    a: placed.scale, b: 0, c: 0, d: placed.scale,
                    tx: placed.origin.x, ty: placed.origin.y
                ))
                .cropped(to: CGRect(origin: .zero, size: canvasSize))
            // Mirror the footage right after reframe — the SAME position the
            // preview handler uses. Doing it last (after grade + behind-title)
            // flipped directional effects like light leaks to the wrong side
            // and rendered behind-person titles backwards in the export.
            if document.mirrorHorizontal {
                image = image.transformed(by: CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: canvasSize.width, ty: 0))
            }
            if cutFXStrength > 0.01 {
                image = CutTransition.apply(style: document.cutStyle, strength: cutFXStrength, to: image)
            }
            if let blurFilter {
                image = blurFilter.apply(image)
            }
            if let gradientFilter {
                image = gradientFilter.apply(image)
            }
            if cutFXStrength > 0.01 {
            }
            ciContext.render(
                image,
                to: destination,
                bounds: CGRect(origin: .zero, size: canvasSize),
                colorSpace: CGColorSpace(name: CGColorSpace.sRGB)
            )
        } else {
            canvas.interpolationQuality = .high
            if document.mirrorHorizontal {
                canvas.saveGState()
                canvas.translateBy(x: canvasSize.width, y: 0)
                canvas.scaleBy(x: -1, y: 1)
                canvas.draw(frame, in: drawRect)
                canvas.restoreGState()
            } else {
                canvas.draw(frame, in: drawRect)
            }
        }

        // Dip cut-smoothing fades the FOOTAGE through black/white briefly.
        // Drawn before the PiP overlays AND the captions — in the preview the
        // dip lives in the video composition, under the separately-layered
        // live PiP players and the caption overlay, so neither is dimmed.
        // The exporter must match.
        if let dip = dipColor(at: time) {
            canvas.setFillColor(dip.color)
            canvas.setAlpha(dip.alpha)
            canvas.fill(CGRect(origin: .zero, size: canvasSize))
            canvas.setAlpha(1)
        }



        // THE renderer — the same call the preview makes. A caption behind
        // the speaker goes on first, then the person from the clean frame
        // over it, then everything that stays in front.
        if let subjectMasker, document.captionIsBehindSubject(at: drawTime),
           let clean = canvas.makeImage(), let mask = subjectMasker.mask(of: clean) {
            CaptionRenderer.draw(document: document, in: canvas, at: drawTime, layers: .captions)
            SubjectMasker.layPerson(from: clean, mask: mask, in: canvas, size: canvasSize)
            CaptionRenderer.draw(document: document, in: canvas, at: drawTime, layers: .titles)
        } else {
            CaptionRenderer.draw(document: document, in: canvas, at: drawTime)
        }

        return destination
    }

    // MARK: - Cut smoothing

    /// Extra zoom right after a cut boundary, easing back over 0.35s.
    private func punchScale(at time: TimeInterval) -> CGFloat {
        guard document.cutStyle == .punchIn else { return 1 }
        for boundary in cutBoundaries where time >= boundary && time < boundary + 0.35 {
            let progress = (time - boundary) / 0.35
            let eased = 1 - pow(1 - progress, 3)
            return 1 + 0.055 * (1 - eased)
        }
        return 1
    }

    /// Dip opacity around a cut boundary (±0.12s window).
    private func dipColor(at time: TimeInterval) -> (color: CGColor, alpha: CGFloat)? {
        let white: Bool
        switch document.cutStyle {
        case .dipToBlack: white = false
        case .dipToWhite: white = true
        case .none, .punchIn, .whipPan, .zoomBlur, .glitch: return nil
        }
        let window = 0.12
        var strongest: Double = 0
        for boundary in cutBoundaries {
            let strength = 1 - abs(time - boundary) / window
            strongest = max(strongest, strength)
        }
        guard strongest > 0 else { return nil }
        let component: CGFloat = white ? 1 : 0
        return (CGColor(srgbRed: component, green: component, blue: component, alpha: 1), CGFloat(min(1, strongest)))
    }

    /// Wraps a locked BGRA pixel buffer in a CGContext.
    private static func context(wrapping buffer: CVPixelBuffer) -> CGContext? {
        CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: CVPixelBufferGetWidth(buffer),
            height: CVPixelBufferGetHeight(buffer),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        )
    }

    // MARK: - Completion

    private var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    /// Set once ``abort(with:)`` has run: both pumps stop touching the
    /// reader and writer from then on.
    private var hasFailed: Bool {
        lock.lock()
        defer { lock.unlock() }
        return terminalError != nil
    }

    private func inputFinished() {
        lock.lock()
        finishedInputs += 1
        let done = finishedInputs == totalInputs && terminalError == nil
        lock.unlock()
        guard done else { return }

        writer.finishWriting { [self] in
            let continuation = takeContinuation()
            if writer.status == .completed {
                progress?(1)
                continuation?.resume()
            } else {
                continuation?.resume(throwing: ExportError.writerFailed(
                    writer.error?.localizedDescription ?? "finish failed"))
            }
        }
    }

    private func abort(with error: Error) {
        lock.lock()
        let alreadyFailed = terminalError != nil
        if !alreadyFailed { terminalError = error }
        lock.unlock()
        guard !alreadyFailed else { return }

        // The two pumps run on their own queues, and the one that did not
        // fail may be mid-copy or mid-append. Cancel the reader and writer
        // only after each queue has drained its current pass (both now stop
        // at `hasFailed`), so neither touches them while they tear down.
        videoQueue.async { [self] in
            audioQueue.async { [self] in
                reader.cancelReading()
                audioReader?.cancelReading()
                writer.cancelWriting()
                takeContinuation()?.resume(throwing: error)
            }
        }
    }

    private func takeContinuation() -> CheckedContinuation<Void, Error>? {
        lock.lock()
        defer { lock.unlock() }
        let continuation = finished
        finished = nil
        return continuation
    }
}
