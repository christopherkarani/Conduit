// PartialJSONDecoder.swift
// Conduit
//
// Lightweight, in-house equivalent of mattt/PartialJSONDecoder.

import Foundation

/// The result of decoding partial JSON.
public struct PartialDecodingResult<Value: Sendable>: Sendable {
    public let value: Value
    public let isComplete: Bool
}

/// Completes partial JSON input by appending missing closing tokens.
///
/// This mirrors the behavior of `JSONCompleter` from `mattt/PartialJSONDecoder`, but
/// uses Conduit's `JsonRepair` implementation under the hood.
public struct JSONCompleter: Sendable {
    /// Maximum nesting depth to consider when completing JSON (default: 64).
    public var maximumDepth: Int = 64

    /// Strategy for handling non-conforming float values.
    ///
    /// If set to `.convertFromString`, the completer will wrap bare tokens matching
    /// the configured strings (e.g. `NaN`, `Infinity`) in quotes so `JSONDecoder` can
    /// decode them using its own `nonConformingFloatDecodingStrategy`.
    public var nonConformingFloatStrategy: JSONDecoder.NonConformingFloatDecodingStrategy? = nil

    public init() {}

    /// Returns the completion string and the index in the original JSON where completion should be applied.
    ///
    /// If the input is already valid JSON, returns `nil`.
    public func completion(
        for json: String,
        from startIndex: String.Index
    ) -> (completion: String, endIndex: String.Index)? {
        _ = startIndex // Currently unused; we always re-scan the full string for correctness.

        if isStrictlyValidJSON(json) {
            return nil
        }

        let repaired = applyNonConformingFloatQuotingIfNeeded(
            to: JsonRepair.repair(json, maximumDepth: maximumDepth)
        )

        let prefixEnd = longestCommonPrefixEndIndex(original: json, repaired: repaired)
        let completion = String(repaired[prefixEnd...])
        return (completion: completion, endIndex: prefixEnd)
    }

    /// Returns a completed JSON string and whether the original JSON was complete.
    public func complete(_ json: String) -> (json: String, isComplete: Bool) {
        let isComplete = isStrictlyValidJSON(json)
        let repaired = JsonRepair.repair(json, maximumDepth: maximumDepth)
        let completed = applyNonConformingFloatQuotingIfNeeded(to: repaired)
        return (json: completed, isComplete: isComplete)
    }

    private func longestCommonPrefixEndIndex(original: String, repaired: String) -> String.Index {
        var originalIndex = original.startIndex
        var repairedIndex = repaired.startIndex

        while originalIndex < original.endIndex, repairedIndex < repaired.endIndex {
            if original[originalIndex] != repaired[repairedIndex] {
                break
            }
            original.formIndex(after: &originalIndex)
            repaired.formIndex(after: &repairedIndex)
        }

        return originalIndex
    }

    private func isStrictlyValidJSON(_ json: String) -> Bool {
        guard let data = json.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) != nil
    }

    private func applyNonConformingFloatQuotingIfNeeded(to json: String) -> String {
        guard case let .convertFromString(posInf, negInf, nan)? = nonConformingFloatStrategy else {
            return json
        }

        // Replace bare tokens outside of strings: NaN / Infinity / -Infinity.
        let tokens: [(raw: String, replacement: String)] = [
            (raw: negInf, replacement: "\"\(negInf)\""),
            (raw: posInf, replacement: "\"\(posInf)\""),
            (raw: nan, replacement: "\"\(nan)\""),
        ]

        var result = ""
        result.reserveCapacity(json.count + 8)

        var inString = false
        var escapeNext = false
        var i = json.startIndex

        func isTokenBoundary(_ c: Character?) -> Bool {
            guard let c else { return true }
            return c.isWhitespace || [",", ":", "{", "}", "[", "]"].contains(c)
        }

        while i < json.endIndex {
            let ch = json[i]

            if escapeNext {
                escapeNext = false
                result.append(ch)
                json.formIndex(after: &i)
                continue
            }

            if inString {
                if ch == "\\" {
                    escapeNext = true
                } else if ch == "\"" {
                    inString = false
                }
                result.append(ch)
                json.formIndex(after: &i)
                continue
            }

            if ch == "\"" {
                inString = true
                result.append(ch)
                json.formIndex(after: &i)
                continue
            }

            // Outside strings: try to match any token at this index.
            var matched = false
            for token in tokens where !token.raw.isEmpty {
                guard json[i...].hasPrefix(token.raw) else { continue }

                let before = i > json.startIndex ? json[json.index(before: i)] : nil
                let afterIndex = json.index(i, offsetBy: token.raw.count, limitedBy: json.endIndex) ?? json.endIndex
                let after = afterIndex < json.endIndex ? json[afterIndex] : nil

                guard isTokenBoundary(before), isTokenBoundary(after) else { continue }

                result.append(contentsOf: token.replacement)
                i = afterIndex
                matched = true
                break
            }

            if !matched {
                result.append(ch)
                json.formIndex(after: &i)
            }
        }

        return result
    }
}

/// Decodes JSON that may be incomplete, returning the decoded value and whether the input was complete.
///
/// This mirrors the high-level behavior of `PartialJSONDecoder` from `mattt/PartialJSONDecoder`.
public struct PartialJSONDecoder: Sendable {
    public var decoder: JSONDecoder
    public var completer: JSONCompleter

    public init(
        decoder: JSONDecoder = JSONDecoder(),
        completer: JSONCompleter = JSONCompleter()
    ) {
        self.decoder = decoder
        self.completer = completer
    }

    public func decode<T: Decodable & Sendable>(
        _ type: T.Type,
        from data: Data
    ) throws -> PartialDecodingResult<T> {
        do {
            let value = try decoder.decode(type, from: data)
            return PartialDecodingResult(value: value, isComplete: true)
        } catch {
            guard let json = String(data: data, encoding: .utf8) else {
                throw error
            }
            let completed = completer.complete(json)
            guard let completedData = completed.json.data(using: .utf8) else {
                throw error
            }
            let value = try decoder.decode(type, from: completedData)
            return PartialDecodingResult(value: value, isComplete: completed.isComplete)
        }
    }

    public func decode<T: Decodable & Sendable>(
        _ type: T.Type,
        from json: String
    ) throws -> PartialDecodingResult<T> {
        try decode(type, from: Data(json.utf8))
    }
}
