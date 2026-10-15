//
//  TextLegibility.swift
//  CaptionKit
//
//  Created by David Sherlock on 2026.
//

import CoreGraphics
import Foundation
import Vision

/// Whether text in a picture can be read, measured rather than judged: the
/// share of the expected words that on-device text recognition reads back.
///
/// A title that Vision cannot read on a frame is a title a viewer will
/// struggle with too; one it reads in full is at least not lost in the
/// footage. Used by `caption check` for hook titles, with no one looking.
public enum TextLegibility {

    /// The share (`0…1`) of `expected`'s words that text recognition finds in
    /// `image` inside `rect` (normalized, top-left; the whole image when
    /// `nil`). Words compare as letters and digits only, case ignored.
    public static func readFraction(of expected: String, in image: CGImage, rect: CGRect? = nil) -> Double {
        let wanted = words(in: expected)
        guard !wanted.isEmpty else { return 1 }
        let read = Set(recognisedWords(in: image, rect: rect))
        return Double(wanted.filter(read.contains).count) / Double(wanted.count)
    }

    /// The words text recognition reads in `image` inside `rect`, normalized.
    public static func recognisedWords(in image: CGImage, rect: CGRect? = nil) -> [String] {
        var target = image
        if let rect {
            let pixels = CanvasFrames.pixels(rect, in: image).integral
                .intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
            guard !pixels.isNull, pixels.width >= 4, pixels.height >= 4, let crop = image.cropping(to: pixels) else { return [] }
            target = crop
        }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        try? VNImageRequestHandler(cgImage: target).perform([request])
        let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        return lines.flatMap(words(in:))
    }

    /// `text` as comparable words: letters and digits only, lowercased.
    static func words(in text: String) -> [String] {
        text.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { !$0.isEmpty }
    }
}
