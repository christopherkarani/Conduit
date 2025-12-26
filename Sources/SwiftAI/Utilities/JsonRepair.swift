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

        var result = json
        var state = ParserState()

        // Analyze the JSON structure
        for char in json {
            state.process(char)
        }

        // If we're in a string, close it
        if state.inString {
            // Check if we ended with an incomplete escape
            if state.escapeNext {
                result.removeLast() // Remove the backslash
            }
            result.append("\"")
        }

        // Remove trailing comma if present before closing
        result = result.trimmingTrailingComma()

        // Close any open brackets/braces
        for bracket in state.bracketStack.reversed() {
            result.append(bracket.closing)
        }

        return result
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
                    }
                case "[":
                    bracketStack.append(.bracket)
                case "]":
                    if bracketStack.last == .bracket {
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

// MARK: - String Extension

private extension String {

    /// Removes trailing comma and whitespace before a closing bracket.
    func trimmingTrailingComma() -> String {
        var result = self

        // Remove trailing whitespace
        while let last = result.last, last.isWhitespace {
            result.removeLast()
        }

        // Remove trailing comma
        if result.last == "," {
            result.removeLast()
        }

        return result
    }
}
