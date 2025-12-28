// JsonRepair.swift
// SwiftAI
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
/// // content: StructuredContent with available fields
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

    /// Attempts to repair incomplete JSON to make it parseable.
    ///
    /// - Parameter json: The potentially incomplete JSON string
    /// - Returns: A repaired JSON string that should be valid JSON
    public static func repair(_ json: String) -> String {
        guard !json.isEmpty else { return "{}" }

        // Pre-allocate result string with margin for closing brackets
        var resultBuilder = ""
        resultBuilder.reserveCapacity(json.count + 100)

        var state = ParserState()

        // Single pass: analyze AND build simultaneously
        for char in json {
            state.process(char)
            resultBuilder.append(char)
        }

        // If we're in a string, close it
        if state.inString {
            if state.escapeNext {
                // Check if we're in the middle of a unicode escape (\uXXXX)
                // Remove the incomplete escape gracefully
                while let last = resultBuilder.last,
                      last == "\\" || isPartialUnicodeEscape(resultBuilder) {
                    resultBuilder.removeLast()
                    if last == "\\" { break }
                }
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

        // Close any open brackets/braces
        for bracket in state.bracketStack.reversed() {
            resultBuilder.append(bracket.closing)
        }

        return resultBuilder
    }

    /// Checks if the string ends with a partial unicode escape sequence.
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

    /// Attempts to repair and parse incomplete JSON into StructuredContent.
    ///
    /// - Parameter json: The potentially incomplete JSON string
    /// - Returns: Parsed StructuredContent
    /// - Throws: If the repaired JSON still cannot be parsed
    public static func parse(_ json: String) throws -> StructuredContent {
        let repaired = repair(json)
        return try StructuredContent(json: repaired)
    }

    /// Attempts to repair and parse JSON, returning nil on failure.
    ///
    /// - Parameter json: The potentially incomplete JSON string
    /// - Returns: Parsed StructuredContent, or nil if repair failed
    public static func tryParse(_ json: String) -> StructuredContent? {
        try? parse(json)
    }
}

// MARK: - Parser State

private extension JsonRepair {

    /// Tracks the state while scanning JSON for repair.
    struct ParserState {
        var inString = false
        var escapeNext = false
        var bracketStack: [Bracket] = []

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
                    bracketStack.append(.brace)
                case "}":
                    if bracketStack.last == .brace {
                        bracketStack.removeLast()
                    } else if bracketStack.last == .bracket {
                        // Mismatch: expected ] but got }
                        // Pop the bracket - the } will close the outer brace
                        bracketStack.removeLast()
                        if bracketStack.last == .brace {
                            bracketStack.removeLast()
                        }
                    }
                case "[":
                    bracketStack.append(.bracket)
                case "]":
                    if bracketStack.last == .bracket {
                        bracketStack.removeLast()
                    } else if bracketStack.last == .brace {
                        // Mismatch: expected } but got ]
                        // Pop the brace - the ] will close the outer bracket
                        bracketStack.removeLast()
                        if bracketStack.last == .bracket {
                            bracketStack.removeLast()
                        }
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

