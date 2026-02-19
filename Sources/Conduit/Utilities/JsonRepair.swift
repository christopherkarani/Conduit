// JsonRepair.swift
// Conduit
//
// Utility for repairing incomplete JSON from streaming responses.

import Foundation

// MARK: - JsonRepair

/// Utility for repairing incomplete or malformed JSON strings.
///
/// During streaming, language models may produce partial JSON that is not
/// yet valid. `JsonRepair` attempts to close open structures and fix common
/// issues to enable incremental parsing.
///
/// ## Usage
///
/// ```swift
/// let partial = #"{"name": "Alice", "age": 30, "city": "New Yor"#
/// let repaired = JsonRepair.repair(partial)
/// // repaired: {"name": "Alice", "age": 30, "city": "New Yor"}
///
/// let content = try JsonRepair.parse(partial)
/// // content: GeneratedContent with available fields
/// ```
///
/// ## Supported Repairs
///
/// - Unclosed strings (adds closing quote)
/// - Unclosed arrays and objects (adds closing brackets)
/// - Trailing commas before closing brackets
/// - Incomplete escape sequences
///
/// ## Limitations
///
/// - Cannot recover from fundamentally malformed JSON
/// - May produce semantically incorrect values for truncated content
/// - Works best with well-structured streaming output
public enum JsonRepair {

    // MARK: - Public API

    /// Creates GeneratedContent from a complete JSON string.
    ///
    /// - Parameter json: A complete JSON string
    /// - Returns: GeneratedContent with the parsed JSON structure
    public static func from(json: String) throws -> GeneratedContent {
        try parse(json)
    }

    /// Repairs incomplete JSON and parses it into `GeneratedContent`.
    ///
    /// - Parameter json: A potentially incomplete JSON string.
    /// - Returns: Parsed `GeneratedContent`.
    /// - Throws: If the repaired JSON is still not valid JSON.
    public static func parse(_ json: String) throws -> GeneratedContent {
        let repaired = repair(json)
        guard let data = repaired.data(using: .utf8) else {
            throw JsonRepairError.invalidJSON
        }

        do {
            let parsed = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            return try GeneratedContent.fromJSONValue(parsed)
        } catch {
            throw JsonRepairError.invalidJSON
        }
    }

    /// Attempts to repair and parse JSON, returning `nil` on failure.
    public static func tryParse(_ json: String) -> GeneratedContent? {
        try? parse(json)
    }

    /// Attempts to repair incomplete JSON to make it parseable.
    ///
    /// - Parameter json: The potentially incomplete JSON string
    /// - Returns: A repaired JSON string that should be valid JSON
    public static func repair(_ json: String, maximumDepth: Int = 64) -> String {
        let trimmed = json.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "{}" }

        // Pre-allocate result string with margin for closing brackets
        var resultBuilder = ""
        resultBuilder.reserveCapacity(json.count + 100)

        var state = ParserState(maximumDepth: maximumDepth)

        // Single pass: analyze AND build simultaneously
        for char in json {
            state.process(char)
            resultBuilder.append(char)
        }

        // If we're in a string, close it
        if state.inString {
            // Check for partial unicode escape sequence and remove it
            removePartialUnicodeEscape(&resultBuilder)
            // Also handle incomplete escape at the very end
            if state.escapeNext, let last = resultBuilder.last, last == "\\" {
                resultBuilder.removeLast()
            }
            resultBuilder.append("\"")
        }

        // Remove trailing whitespace and comma in-place
        while let last = resultBuilder.last, last.isWhitespace {
            resultBuilder.removeLast()
        }
        if resultBuilder.last == "," {
            resultBuilder.removeLast()
        }

        // Remove incomplete key-value pairs (key without value, key without colon)
        resultBuilder = removeIncompleteKeyValuePairs(resultBuilder)

        // Close any open brackets/braces
        for bracket in state.bracketStack.reversed() {
            // Before adding a closing bracket, remove any trailing comma
            while let last = resultBuilder.last, last.isWhitespace {
                resultBuilder.removeLast()
            }
            if resultBuilder.last == "," {
                resultBuilder.removeLast()
            }
            resultBuilder.append(bracket.closing)
        }

        // Final pass: remove trailing commas before existing closing brackets
        resultBuilder = removeTrailingCommasBeforeClosingBrackets(resultBuilder)

        return resultBuilder
    }

    // MARK: - Errors

    private enum JsonRepairError: Error {
        case invalidJSON
    }

    /// Checks if the string ends with a partial unicode escape sequence.
    ///
    /// Detects incomplete unicode escape patterns like `\u`, `\u1`, `\u12`, `\u123`
    /// which need to be removed before closing a string to avoid invalid JSON.
    ///
    /// - Parameter str: The string to check
    /// - Returns: `true` if the string ends with an incomplete `\uXXXX` escape sequence
    private static func isPartialUnicodeEscape(_ str: String) -> Bool {
        guard str.count >= 2 else { return false }
        let suffix = String(str.suffix(6))

        // Check for patterns like \u, \u1, \u12, \u123 (incomplete \uXXXX)
        if let backslashIndex = suffix.lastIndex(of: "\\") {
            let afterBackslash = suffix[suffix.index(after: backslashIndex)...]
            if afterBackslash.hasPrefix("u") {
                // Count hex digits after \u
                let hexPart = afterBackslash.dropFirst()
                let hexCount = hexPart.prefix(while: { $0.isHexDigit }).count
                // Incomplete if less than 4 hex digits
                return hexCount < 4
            }
        }
        return false
    }

    /// Removes a partial unicode escape sequence from the end of a string.
    ///
    /// This method modifies the string in-place to remove incomplete unicode escapes
    /// like `\u`, `\u1`, `\u12`, `\u123` which would make the JSON invalid.
    /// Complete unicode escapes (`\uXXXX` with 4 hex digits) are left intact.
    ///
    /// - Parameter str: The string to modify (modified in-place)
    private static func removePartialUnicodeEscape(_ str: inout String) {
        // Look for patterns like \u, \u1, \u12, \u123 at the end
        guard str.count >= 2 else { return }

        // Find the last backslash in the final 6 characters
        let searchRange = str.suffix(6)
        guard let backslashIdx = searchRange.lastIndex(of: "\\") else { return }

        let afterBackslash = str[str.index(after: backslashIdx)...]

        // Check if it's a unicode escape (\uXXXX)
        if afterBackslash.hasPrefix("u") {
            let hexPart = afterBackslash.dropFirst()
            let hexCount = hexPart.prefix(while: { $0.isHexDigit }).count

            // If incomplete (less than 4 hex digits), remove the whole escape
            if hexCount < 4 {
                str.removeSubrange(backslashIdx...)
            }
        }
    }

    /// Removes incomplete key-value pairs from the end of JSON (only in object context).
    ///
    /// This method handles several edge cases during streaming JSON parsing:
    /// - `{"key"` (no colon or value) → removes the incomplete key
    /// - `{"key":` (no value) → removes both the key and colon
    /// - `{"key": 30, "` (incomplete next key) → removes the incomplete key
    ///
    /// The method is context-aware and only removes incomplete keys in object contexts,
    /// not in arrays where strings are valid values.
    ///
    /// - Parameter json: The JSON string to process
    /// - Returns: JSON with incomplete key-value pairs removed
    private static func removeIncompleteKeyValuePairs(_ json: String) -> String {
        var result = json

        // Trim trailing whitespace
        while let last = result.last, last.isWhitespace {
            result.removeLast()
        }

        // Pattern: ends with comma followed by incomplete key or nothing
        // e.g., {"a": 1, " or {"a": 1, "b
        if result.hasSuffix(",") {
            result.removeLast()
            while let last = result.last, last.isWhitespace {
                result.removeLast()
            }
        }

        // Pattern: ends with colon (key without value) - need to remove the key too
        // e.g., {"name": "Alice", "age":
        if result.hasSuffix(":") {
            result.removeLast()
            while let last = result.last, last.isWhitespace {
                result.removeLast()
            }
            // Now we should have a quoted key - remove it
            if result.hasSuffix("\"") {
                result.removeLast()  // Remove closing quote
                // Find the opening quote of the key
                while let last = result.last {
                    if last == "\"" {
                        result.removeLast()
                        break
                    }
                    result.removeLast()
                }
                // Remove preceding comma and whitespace if any
                while let last = result.last, last.isWhitespace {
                    result.removeLast()
                }
                if result.last == "," {
                    result.removeLast()
                }
            }
        }

        // Pattern: ends with a quoted string that looks like an incomplete key (no colon after)
        // e.g., {"name": "Alice", "age" or {"name": "Alice", "
        // ONLY do this in object context, not array context
        if result.hasSuffix("\"") {
            let chars = Array(result)
            var idx = chars.count - 1

            // Find the start of this string
            idx -= 1  // Skip the closing quote
            while idx >= 0 {
                if chars[idx] == "\"" {
                    // Check if escaped
                    var backslashCount = 0
                    var checkIdx = idx - 1
                    while checkIdx >= 0 && chars[checkIdx] == "\\" {
                        backslashCount += 1
                        checkIdx -= 1
                    }
                    if backslashCount % 2 == 0 {
                        // Found unescaped opening quote
                        break
                    }
                }
                idx -= 1
            }

            if idx >= 0 {
                // Check what precedes this string (skip whitespace)
                var prevIdx = idx - 1
                while prevIdx >= 0 && chars[prevIdx].isWhitespace {
                    prevIdx -= 1
                }

                // Only remove if preceded by { (object start) - this is definitely an incomplete key
                // If preceded by comma, we need to check if we're in object or array context
                if prevIdx >= 0 && chars[prevIdx] == "{" {
                    // Remove this incomplete key (object context, key after open brace)
                    result = String(chars[..<idx])
                    while let last = result.last, last.isWhitespace {
                        result.removeLast()
                    }
                } else if prevIdx >= 0 && chars[prevIdx] == "," {
                    // Need to determine context - look for most recent unmatched [ or {
                    let context = findContext(chars, upTo: prevIdx)
                    if context == .object {
                        // Remove this incomplete key
                        result = String(chars[..<idx])
                        while let last = result.last, last.isWhitespace {
                            result.removeLast()
                        }
                        if result.last == "," {
                            result.removeLast()
                        }
                    }
                    // If array context, keep the string (it's a valid array element)
                }
            }
        }

        return result
    }

    /// Determines the JSON context (object or array) at a given position.
    ///
    /// This is used to decide whether a trailing string is an incomplete object key
    /// or a valid array element. The method scans backwards from the given index to
    /// find the most recent unmatched opening bracket (`{` or `[`).
    ///
    /// - Parameters:
    ///   - chars: The JSON characters as an array
    ///   - idx: The position to check context at
    /// - Returns: The JSON context (`.object`, `.array`, or `.unknown`)
    private enum JsonContext { case object, array, unknown }

    private static func findContext(_ chars: [Character], upTo idx: Int) -> JsonContext {
        guard !chars.isEmpty, idx >= 0 else { return .unknown }

        var bracketStack: [Character] = []
        var inString = false
        var escapeNext = false

        for i in 0...idx {
            let char = chars[i]

            if escapeNext {
                escapeNext = false
                continue
            }

            if inString {
                if char == "\\" {
                    escapeNext = true
                } else if char == "\"" {
                    inString = false
                }
                continue
            }

            switch char {
            case "\"":
                inString = true
            case "{":
                bracketStack.append("{")
            case "}":
                if bracketStack.last == "{" {
                    bracketStack.removeLast()
                }
            case "[":
                bracketStack.append("[")
            case "]":
                if bracketStack.last == "[" {
                    bracketStack.removeLast()
                }
            default:
                break
            }
        }

        switch bracketStack.last {
        case "{":
            return .object
        case "[":
            return .array
        default:
            return .unknown
        }
    }

    /// Removes trailing commas before closing brackets/braces in already-closed JSON.
    ///
    /// JSON does not allow trailing commas before closing brackets. This method
    /// performs a final cleanup pass to remove patterns like `[1, 2, 3,]` or
    /// `{"a": 1, "b": 2,}` which would be invalid JSON.
    ///
    /// The method is string-aware and only processes commas outside of quoted strings.
    ///
    /// - Parameter json: The JSON string to clean up
    /// - Returns: JSON with trailing commas removed
    private static func removeTrailingCommasBeforeClosingBrackets(_ json: String) -> String {
        var result = ""
        result.reserveCapacity(json.count)

        var inString = false
        var escapeNext = false
        let chars = Array(json)
        var i = 0

        while i < chars.count {
            let char = chars[i]

            if escapeNext {
                escapeNext = false
                result.append(char)
                i += 1
                continue
            }

            if inString {
                if char == "\\" {
                    escapeNext = true
                } else if char == "\"" {
                    inString = false
                }
                result.append(char)
                i += 1
                continue
            }

            if char == "\"" {
                inString = true
                result.append(char)
                i += 1
                continue
            }

            // Check for trailing comma followed by optional whitespace then closing bracket
            if char == "," {
                // Look ahead for whitespace + closing bracket
                var j = i + 1
                while j < chars.count && chars[j].isWhitespace {
                    j += 1
                }
                if j < chars.count && (chars[j] == "}" || chars[j] == "]") {
                    // Skip the comma - don't add it to result
                    i += 1
                    continue
                }
            }

            result.append(char)
            i += 1
        }

        return result
    }

}

// MARK: - Parser State

private extension JsonRepair {

    /// Tracks the state while scanning JSON for repair.
    struct ParserState {
        var inString = false
        var escapeNext = false
        var bracketStack: [Bracket] = []
        let maximumDepth: Int

        init(maximumDepth: Int) {
            self.maximumDepth = max(1, maximumDepth)
        }

        mutating func process(_ char: Character) {
            if escapeNext {
                escapeNext = false
                return
            }

            if inString {
                switch char {
                case "\\":
                    escapeNext = true
                case "\"":
                    inString = false
                default:
                    break
                }
            } else {
                switch char {
                case "\"":
                    inString = true
                case "{":
                    if bracketStack.count < maximumDepth {
                        bracketStack.append(.brace)
                    }
                case "}":
                    guard !bracketStack.isEmpty else { break }
                    if bracketStack.last == .brace {
                        bracketStack.removeLast()
                    } else if bracketStack.last == .bracket {
                        // Mismatch: expected ] but got }
                        // Only pop the mismatched bracket - repair() will add
                        // necessary closing brackets at the end
                        bracketStack.removeLast()
                    }
                case "[":
                    if bracketStack.count < maximumDepth {
                        bracketStack.append(.bracket)
                    }
                case "]":
                    guard !bracketStack.isEmpty else { break }
                    if bracketStack.last == .bracket {
                        bracketStack.removeLast()
                    } else if bracketStack.last == .brace {
                        // Mismatch: expected } but got ]
                        // Only pop the mismatched brace - repair() will add
                        // necessary closing brackets at the end
                        bracketStack.removeLast()
                    }
                default:
                    break
                }
            }
        }
    }

    /// Represents an open bracket type.
    enum Bracket {
        case brace    // {
        case bracket  // [

        var closing: Character {
            switch self {
            case .brace: return "}"
            case .bracket: return "]"
            }
        }
    }
}
