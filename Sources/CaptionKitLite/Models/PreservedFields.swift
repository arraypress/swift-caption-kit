//
//  PreservedFields.swift
//  CaptionKitLite
//
//  Created by David Sherlock on 2026.
//
//  The fields this engine does not model, carried through a load and save
//  unchanged.
//

import Foundation

/// A JSON value held as itself, so a field can survive a round-trip through
/// code that does not understand it.
///
/// ``CaptionDocument`` is a subset of the document the full engine writes: it
/// has no stickers, titles, B-roll, music or grade. Decoding one of those
/// projects and re-encoding it would ordinarily **drop every one of those
/// keys**, because `Codable` writes back only the properties the type
/// declares. A project styled in the editor and then batch-rendered here
/// would come back stripped of the work somebody did in the editor.
///
/// So the unmodelled keys are kept verbatim instead. This engine never reads
/// them and never renders them; it simply hands them back on the way out.
///
/// The same mechanism covers keys added by *future* versions, which is the
/// more valuable half: a document written by a newer build opens here, renders
/// its captions, and saves without losing whatever that build added.
public indirect enum PreservedValue: Codable, Equatable, Sendable {

    case string(String)
    case number(Double)
    case bool(Bool)
    case array([PreservedValue])
    case object([String: PreservedValue])
    case null

    // MARK: - Decoding

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([PreservedValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: PreservedValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Not a JSON value"
            )
        }
    }

    // MARK: - Encoding

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

// MARK: - Dynamic keys

/// A coding key built at runtime.
///
/// Needed because the unmodelled keys are, by definition, not in any
/// `CodingKeys` enum — they have to be read and written by name.
struct PreservedCodingKey: CodingKey {

    let stringValue: String
    let intValue: Int? = nil

    init(_ stringValue: String) {
        self.stringValue = stringValue
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        nil
    }
}

// MARK: - Capture and restore

extension PreservedValue {

    /// Every key in the document that `known` does not cover.
    ///
    /// - Parameters:
    ///   - decoder: The decoder mid-`init(from:)`.
    ///   - known: The keys this type models, which are decoded normally and
    ///     must not be duplicated here.
    static func unmodelledFields(
        from decoder: Decoder,
        known: Set<String>
    ) -> [String: PreservedValue] {
        guard let container = try? decoder.container(keyedBy: PreservedCodingKey.self) else {
            return [:]
        }

        var fields: [String: PreservedValue] = [:]
        for key in container.allKeys where !known.contains(key.stringValue) {
            // A value that will not decode is skipped rather than thrown on.
            // Losing one unreadable field is a smaller failure than refusing
            // to open the document at all.
            guard let value = try? container.decode(PreservedValue.self, forKey: key) else { continue }
            fields[key.stringValue] = value
        }
        return fields
    }

    /// Writes preserved fields back alongside the modelled ones.
    static func encode(
        _ fields: [String: PreservedValue],
        to encoder: Encoder
    ) throws {
        guard !fields.isEmpty else { return }

        var container = encoder.container(keyedBy: PreservedCodingKey.self)
        // Written in a fixed order so this step contributes nothing
        // non-deterministic. Whether the *document* serialises to stable bytes
        // is the encoder's business — see ``CaptionDocument/serialized()``,
        // which sets `.sortedKeys` for exactly that reason.
        for key in fields.keys.sorted() {
            try container.encode(fields[key], forKey: PreservedCodingKey(key))
        }
    }
}
