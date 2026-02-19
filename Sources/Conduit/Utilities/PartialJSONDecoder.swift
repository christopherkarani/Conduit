// PartialJSONDecoder.swift
// Conduit
//
// In-house implementation intended to match the behavior of mattt/PartialJSONDecoder
// for completing and decoding partial JSON during streaming.

import Foundation
import ConduitCore

// MARK: - Errors

/// Errors that can occur while decoding partial JSON.
public enum PartialJSONDecoderError: Error {
    case invalidUTF8Data
    case decodingFailed(any Error)
}

/// Errors that can occur while completing partial JSON.
public enum JSONCompletionError: Error, LocalizedError {
    case invalidValue(String)
    case depthLimitExceeded(String)

    public var errorDescription: String? {
        switch self {
        case .invalidValue(let message):
            return message
        case .depthLimitExceeded(let message):
            return message
        }
    }
}

// MARK: - JSONCompleter

/// Completes partial JSON by appending missing closing characters (quotes, brackets, braces, etc).
public final class JSONCompleter {
    public typealias NonConformingFloatDecodingStrategy = JSONDecoder.NonConformingFloatDecodingStrategy

    /// Strategy for handling non-conforming float tokens (e.g. `Infinity`, `NaN`).
    public var nonConformingFloatStrategy: NonConformingFloatDecodingStrategy = .throw

    /// Maximum nesting depth allowed when parsing objects/arrays.
    public var maximumDepth: Int = 64

    /// Completion info for a partial JSON value.
    /// - `string`: Characters to append to complete the value.
    /// - `endIndex`: The index in the original string where completion should be applied.
    public typealias Completion = (string: String, endIndex: String.Index)

    public init() {}

    /// Completes a JSON string if it is incomplete; otherwise returns it unchanged.
    public func complete(_ json: String) throws -> String {
        guard !json.isEmpty else { return "" }

        // Try C implementation first for performance
        // C outputs the FULL completed string (input truncated at completion point + suffix)
        let utf8 = Array(json.utf8)
        let capacity = utf8.count + 256
        var output = [CChar](repeating: 0, count: capacity)

        let result = utf8.withUnsafeBufferPointer { inputBuf in
            output.withUnsafeMutableBufferPointer { outputBuf in
                conduit_json_complete(
                    inputBuf.baseAddress.map { UnsafeRawPointer($0).assumingMemoryBound(to: CChar.self) },
                    inputBuf.count,
                    outputBuf.baseAddress,
                    outputBuf.count,
                    Int32(maximumDepth)
                )
            }
        }

        if result >= 0 {
            if result == 0 { return json } // Already complete
            return String(cString: output)
        }

        // Fallback to Swift implementation for edge cases
        if let completion = try completion(for: json, from: json.startIndex) {
            return String(json[..<completion.endIndex]) + completion.string
        }

        return json
    }

    /// Returns completion information for a JSON value starting at `startIndex`, or `nil` if complete.
    public func completion(for json: String, from startIndex: String.Index) throws -> Completion? {
        let start = skipWhitespace(in: json, from: startIndex)
        guard start < json.endIndex else { return nil }
        return try completeValue(in: json, from: start, depth: 0)
    }

    // MARK: - Value completion

    private func completeValue(in json: String, from startIndex: String.Index, depth: Int) throws -> Completion? {
        guard depth < maximumDepth else {
            throw JSONCompletionError.depthLimitExceeded("JSON nesting depth exceeds limit of \(maximumDepth)")
        }

        let start = skipWhitespace(in: json, from: startIndex)
        guard start < json.endIndex else { return nil }

        switch json[start] {
        case "{":
            return try completeObject(in: json, from: start, depth: depth + 1)
        case "[":
            return try completeArray(in: json, from: start, depth: depth + 1)
        case "\"":
            return completeString(in: json, from: start)
        case "-":
            // Special-case `-Infinity`
            if json.index(after: start) < json.endIndex,
               json[json.index(after: start)] == "I"
            {
                if case .throw = nonConformingFloatStrategy {
                    throw JSONCompletionError.invalidValue("Invalid numeric value: -Infinity")
                }
                return completeSpecialValue(in: json, from: start, value: "-Infinity")
            }
            return completeNumber(in: json, from: start)
        case "0"..."9":
            return completeNumber(in: json, from: start)
        case "t":
            return completeSpecialValue(in: json, from: start, value: "true")
        case "f":
            return completeSpecialValue(in: json, from: start, value: "false")
        case "n":
            return completeSpecialValue(in: json, from: start, value: "null")
        case "I":
            if case .throw = nonConformingFloatStrategy {
                throw JSONCompletionError.invalidValue("Invalid numeric value: Infinity")
            }
            return completeSpecialValue(in: json, from: start, value: "Infinity")
        case "N":
            if case .throw = nonConformingFloatStrategy {
                throw JSONCompletionError.invalidValue("Invalid numeric value: NaN")
            }
            return completeSpecialValue(in: json, from: start, value: "NaN")
        default:
            return nil
        }
    }

    // MARK: - Strings

    private func completeString(in json: String, from startIndex: String.Index) -> Completion? {
        guard startIndex < json.endIndex, json[startIndex] == "\"" else { return nil }

        var current = json.index(after: startIndex)
        var isEscaped = false

        while current < json.endIndex {
            let ch = json[current]
            if ch == "\\" {
                isEscaped.toggle()
            } else if ch == "\"" && !isEscaped {
                return nil
            } else {
                isEscaped = false
            }
            current = json.index(after: current)
        }

        return (string: "\"", endIndex: current)
    }

    // MARK: - Arrays

    private func completeArray(in json: String, from startIndex: String.Index, depth: Int) throws -> Completion? {
        guard startIndex < json.endIndex, json[startIndex] == "[" else { return nil }

        var current = json.index(after: startIndex)
        var requiresComma = false
        var lastValidIndex = current

        current = skipWhitespace(in: json, from: current)

        if current >= json.endIndex || json[current] == "]" {
            return (string: "]", endIndex: current)
        }

        while current < json.endIndex {
            if json[current] == "]" {
                return nil
            }

            if requiresComma {
                if json[current] == "," {
                    requiresComma = false
                    current = json.index(after: current)
                    current = skipWhitespace(in: json, from: current)
                    if current >= json.endIndex { break }
                    lastValidIndex = current
                } else {
                    return (string: "]", endIndex: lastValidIndex)
                }
            }

            if current >= json.endIndex { break }

            if json[current] == "]" {
                return nil
            }

            if let elementCompletion = try completeValue(in: json, from: current, depth: depth + 1) {
                return (string: elementCompletion.string + "]", endIndex: elementCompletion.endIndex)
            }

            let endOfValue = findEndOfCompleteValue(in: json, from: current)
            current = endOfValue
            lastValidIndex = current
            requiresComma = true
        }

        return (string: "]", endIndex: lastValidIndex)
    }

    // MARK: - Objects

    private func completeObject(in json: String, from startIndex: String.Index, depth: Int) throws -> Completion? {
        guard startIndex < json.endIndex, json[startIndex] == "{" else { return nil }

        var current = json.index(after: startIndex)
        var requiresComma = false
        var lastValidIndex = current

        current = skipWhitespace(in: json, from: current)

        if current >= json.endIndex || json[current] == "}" {
            return (string: "}", endIndex: current)
        }

        while current < json.endIndex {
            if json[current] == "}" {
                return nil
            }

            if requiresComma {
                if json[current] == "," {
                    requiresComma = false
                    current = json.index(after: current)
                    current = skipWhitespace(in: json, from: current)
                    if current >= json.endIndex { break }
                    lastValidIndex = current
                } else {
                    return (string: "}", endIndex: lastValidIndex)
                }
            }

            if current >= json.endIndex { break }

            if json[current] == "}" {
                return nil
            }

            // Key
            if let keyCompletion = completeString(in: json, from: current) {
                // Close key string, then fill in a null value, then close object.
                return (string: keyCompletion.string + ": null}", endIndex: keyCompletion.endIndex)
            }

            let keyEnd = findEndOfCompleteValue(in: json, from: current)
            if keyEnd <= current {
                return (string: "}", endIndex: lastValidIndex)
            }

            current = keyEnd
            lastValidIndex = current

            // Colon
            current = skipWhitespace(in: json, from: current)
            if current >= json.endIndex || json[current] != ":" {
                return (string: ": null}", endIndex: lastValidIndex)
            }

            current = json.index(after: current)
            lastValidIndex = current

            // Value
            current = skipWhitespace(in: json, from: current)
            if current >= json.endIndex {
                return (string: "null}", endIndex: lastValidIndex)
            }

            if let valueCompletion = try completeValue(in: json, from: current, depth: depth + 1) {
                return (string: valueCompletion.string + "}", endIndex: valueCompletion.endIndex)
            }

            let endOfValue = findEndOfCompleteValue(in: json, from: current)
            current = endOfValue
            lastValidIndex = current
            requiresComma = true
        }

        return (string: "}", endIndex: lastValidIndex)
    }

    // MARK: - Numbers

    private func completeNumber(in json: String, from startIndex: String.Index) -> Completion? {
        var current = startIndex
        var seenDecimal = false
        var seenExponent = false

        if current < json.endIndex, json[current] == "-" {
            current = json.index(after: current)
        }

        let afterSign = current

        // "-" at end
        if current >= json.endIndex {
            return (string: "0", endIndex: current)
        }

        // "-." prefix
        if json[current] == "." {
            return (string: "0.0", endIndex: current)
        }

        while current < json.endIndex, json[current].isNumber {
            current = json.index(after: current)
        }

        if current < json.endIndex, json[current] == "." {
            seenDecimal = true
            current = json.index(after: current)

            let fractionStart = current
            while current < json.endIndex, json[current].isNumber {
                current = json.index(after: current)
            }
            if current == fractionStart {
                return (string: "0", endIndex: current)
            }
        }

        if current < json.endIndex, (json[current] == "e" || json[current] == "E") {
            seenExponent = true
            current = json.index(after: current)

            if current < json.endIndex, (json[current] == "+" || json[current] == "-") {
                current = json.index(after: current)
            }

            if current >= json.endIndex || !json[current].isNumber {
                return (string: "0", endIndex: current)
            }

            while current < json.endIndex, json[current].isNumber {
                current = json.index(after: current)
            }
        }

        // If we saw no digits after the sign and no decimal/exponent was completed, this isn't a number.
        if current == afterSign, !(seenDecimal || seenExponent) {
            return nil
        }

        // "-." edge that didn't get caught above (kept for parity with upstream behavior)
        if current == json.index(after: afterSign), afterSign < json.endIndex, json[afterSign] == "." {
            return nil
        }

        return nil
    }

    // MARK: - Special literals (true/false/null/Infinity/NaN)

    private func completeSpecialValue(in json: String, from startIndex: String.Index, value: String) -> Completion? {
        var current = startIndex
        let chars = Array(value)
        var matched = 0

        while current < json.endIndex, matched < chars.count {
            if json[current] != chars[matched] {
                return nil
            }
            current = json.index(after: current)
            matched += 1
        }

        if matched == chars.count {
            return nil
        }

        let prefix = String(json[startIndex..<current])
        if value.hasPrefix(prefix) {
            return (string: String(chars[matched...]), endIndex: current)
        }

        return nil
    }

    // MARK: - Scanning helpers

    private func skipWhitespace(in json: String, from index: String.Index) -> String.Index {
        var current = index
        while current < json.endIndex, json[current].isWhitespace {
            current = json.index(after: current)
        }
        return current
    }

    private func findEndOfCompleteValue(in json: String, from startIndex: String.Index) -> String.Index {
        let start = skipWhitespace(in: json, from: startIndex)
        guard start < json.endIndex else { return start }

        // If the value is incomplete, return its endIndex so callers can stop.
        if let completion = try? completeValue(in: json, from: start, depth: 0) {
            return completion.endIndex
        }

        switch json[start] {
        case "\"":
            var current = json.index(after: start)
            var isEscaped = false
            while current < json.endIndex {
                let ch = json[current]
                if ch == "\\" {
                    isEscaped.toggle()
                } else if ch == "\"" && !isEscaped {
                    return json.index(after: current)
                } else {
                    isEscaped = false
                }
                current = json.index(after: current)
            }
            return current

        case "{":
            return findMatchingBrace(in: json, from: start, open: "{", close: "}")
        case "[":
            return findMatchingBrace(in: json, from: start, open: "[", close: "]")

        case "t":
            if json[start...].hasPrefix("true") { return json.index(start, offsetBy: 4) }
        case "f":
            if json[start...].hasPrefix("false") { return json.index(start, offsetBy: 5) }
        case "n":
            if json[start...].hasPrefix("null") { return json.index(start, offsetBy: 4) }

        case "-", "0"..."9":
            var current = start
            while current < json.endIndex, "1234567890.-+eE".contains(json[current]) {
                current = json.index(after: current)
            }
            return current

        case "I":
            if json[start...].hasPrefix("Infinity") { return json.index(start, offsetBy: 8) }
        case "N":
            if json[start...].hasPrefix("NaN") { return json.index(start, offsetBy: 3) }
        default:
            break
        }

        return start
    }

    private func findMatchingBrace(
        in json: String,
        from startIndex: String.Index,
        open: Character,
        close: Character
    ) -> String.Index {
        var level = 0
        var current = startIndex
        var inString = false
        var isEscaped = false

        while current < json.endIndex {
            let ch = json[current]

            if inString {
                if ch == "\\" {
                    isEscaped.toggle()
                } else if ch == "\"" && !isEscaped {
                    inString = false
                } else {
                    isEscaped = false
                }
            } else {
                if ch == "\"" {
                    inString = true
                    isEscaped = false
                } else if ch == open {
                    level += 1
                } else if ch == close {
                    level -= 1
                    if level == 0 {
                        return json.index(after: current)
                    }
                }
            }

            current = json.index(after: current)
        }

        return current
    }
}

// MARK: - PartialJSONDecoder

/// Decodes JSON that may be incomplete by attempting completion before decoding.
public final class PartialJSONDecoder {
    private let completer: JSONCompleter
    private let decoder: JSONDecoder

    public init(
        completer: JSONCompleter = JSONCompleter(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.completer = completer
        self.decoder = decoder
    }

    public func decode<T: Decodable>(
        _ type: T.Type,
        from data: Data
    ) throws -> (value: T, isComplete: Bool) {
        do {
            let value = try decoder.decode(type, from: data)
            return (value: value, isComplete: true)
        } catch {
            guard let jsonString = String(data: data, encoding: .utf8) else {
                throw PartialJSONDecoderError.invalidUTF8Data
            }

            let completed = try completer.complete(jsonString)
            guard let completedData = completed.data(using: .utf8) else {
                throw PartialJSONDecoderError.invalidUTF8Data
            }

            do {
                let value = try decoder.decode(type, from: completedData)
                return (value: value, isComplete: false)
            } catch {
                throw PartialJSONDecoderError.decodingFailed(error)
            }
        }
    }

    public func decode<T: Decodable>(
        _ type: T.Type,
        from string: String
    ) throws -> (value: T, isComplete: Bool) {
        guard let data = string.data(using: .utf8) else {
            throw PartialJSONDecoderError.invalidUTF8Data
        }
        return try decode(type, from: data)
    }
}

