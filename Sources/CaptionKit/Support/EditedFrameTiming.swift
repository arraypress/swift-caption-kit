//
//  EditedFrameTiming.swift
//  CaptionKit
//
//  Created by David Sherlock on 2026.
//
//  Where the frames of an unedited source land on a cut, sped-up timeline:
//  the timing a frame-timed video composition gives an edited
//  `AVMutableComposition`, worked out without reading one.
//
//  Why the exporter no longer reads the edited composition's video: on
//  macOS 27 an `AVAssetReader` on it can stop for good near an edit —
//  `copyNextSampleBuffer` never returns and every reader thread waits. On a
//  4 s static test clip with one cut and one speed ramp, about one read in
//  ten stalled, with or without the sound and with nothing else running; the
//  same source read unedited did not stall in 1,000 reads. Cancelling a
//  stalled reader to restart it crashed inside AVFoundation (2 of 8 tries),
//  so the edited read is avoided rather than restarted.
//

import CoreMedia

/// Places each frame of an unedited source on an edited timeline.
///
/// The rules, checked frame-for-frame against the edited composition's own
/// output — presentation time (value and timescale) and BGRA bytes:
///
/// - A frame shows in every kept piece its span overlaps.
/// - Inside a piece it lands at its source time mapped through the piece, or
///   at the piece's start when it began before the piece did.
/// - Where a piece carries straight on from the previous one in the source
///   (a speed change, no cut), the frame already showing is not shown again
///   at the join.
///
/// On 100 random cut layouts over three clips: 94 identical; 3 could not be
/// placed (pieces out of source order, from sped-up slivers a few ms long),
/// which the exporter still reads the old way; and 3 differ, each narrower
/// than a frame. Where a cut is shorter than the source frame it falls in,
/// the composition sometimes does not repeat that frame after the cut (7 of
/// 60 such cuts measured); here it always does — the same picture, with the
/// captions over it updated a frame sooner. And where a piece starts after
/// the picture ends (the sound runs a few milliseconds longer), the
/// composition added a black frame; here the last picture holds.
struct EditedFrameTiming {

    /// One kept piece: its source range and where it plays.
    struct Piece: Equatable {
        let source: CMTimeRange
        let target: CMTimeRange
        /// The previous piece ends exactly where this one starts in the source.
        let carriesOn: Bool
    }

    let pieces: [Piece]

    /// The first piece a later frame can still reach. Frames arrive in
    /// source order and the pieces run forward, so it only moves on.
    private var first = 0

    /// Pieces from `(source, target)` mappings in playback order. `nil`
    /// unless they run forward through the source without overlapping, each
    /// with a real length — anything else is left to the edited composition.
    init?(mappings: [(source: CMTimeRange, target: CMTimeRange)]) {
        var pieces: [Piece] = []
        for mapping in mappings {
            guard mapping.source.duration > .zero, mapping.target.duration > .zero else { return nil }
            var carriesOn = false
            if let previous = pieces.last {
                let order = CMTimeCompare(mapping.source.start, previous.source.end)
                guard order >= 0, CMTimeCompare(mapping.target.start, previous.target.start) > 0 else { return nil }
                carriesOn = order == 0
            }
            pieces.append(Piece(source: mapping.source, target: mapping.target, carriesOn: carriesOn))
        }
        guard !pieces.isEmpty else { return nil }
        self.pieces = pieces
    }

    /// The output times of the source frame shown over `[start, end)`, in
    /// order — none when every piece skips it, more than one when a cut
    /// shorter than the frame keeps it on both sides. Call in source order.
    mutating func outputTimes(start: CMTime, end: CMTime) -> [CMTime] {
        while first < pieces.count, CMTimeCompare(pieces[first].source.end, start) <= 0 {
            first += 1
        }
        var times: [CMTime] = []
        var index = first
        while index < pieces.count, CMTimeCompare(pieces[index].source.start, end) < 0 {
            let piece = pieces[index]
            index += 1
            let startsBefore = CMTimeCompare(start, piece.source.start) < 0
            if piece.carriesOn, startsBefore { continue }
            times.append(CMTimeCompare(start, piece.source.start) <= 0
                ? piece.target.start
                : CMTimeMapTimeFromRangeToRange(start, fromRange: piece.source, toRange: piece.target))
        }
        return times
    }
}
