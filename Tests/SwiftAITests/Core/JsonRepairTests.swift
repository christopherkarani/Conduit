// JsonRepairTests.swift
// SwiftAITests
//
// Comprehensive tests for the JsonRepair utility that repairs incomplete JSON
// from streaming responses.

import Foundation
import Testing
@testable import SwiftAI

/// Tests for JsonRepair - Utility for repairing incomplete JSON strings
@Suite("JsonRepair")
struct JsonRepairTests {

    // MARK: - String Repairs

    @Suite("String Repairs")
    struct StringRepairTests {

        @Test("Unclosed string at end gets closing quote and brace")
        func unclosedStringAtEnd() {
            // Simulates streaming JSON that cuts off mid-string value
            let incomplete = #"{"name": "Alice"#
            let repaired = JsonRepair.repair(incomplete)

            // Should close the string and the object
            #expect(repaired == #"{"name": "Alice"}"#)
        }

        @Test("Incomplete escape sequence at end is handled gracefully")
        func incompleteEscapeSequence() {
            // String ends with backslash indicating incomplete escape
            let incomplete = #"{"text": "hello\"#
            let repaired = JsonRepair.repair(incomplete)

            // Should remove the incomplete escape and close properly
            #expect(repaired == #"{"text": "hello"}"#)
        }

        @Test("Partial unicode escape sequence is removed")
        func partialUnicodeEscape() {
            // Unicode escape \uXXXX is incomplete (only \u00)
            let incomplete = #"{"text": "\u00"#
            let repaired = JsonRepair.repair(incomplete)

            // Should remove the partial unicode escape and close properly
            #expect(repaired == #"{"text": ""}"#)
        }

        @Test("Normal strings pass through unchanged")
        func normalStringsUnchanged() {
            // Complete, valid JSON should not be modified
            let complete = #"{"name": "Alice", "age": 30}"#
            let repaired = JsonRepair.repair(complete)

            #expect(repaired == complete)
        }

        @Test("Empty string value is handled correctly")
        func emptyStringValue() {
            // JSON with empty string value
            let json = #"{"name": ""}"#
            let repaired = JsonRepair.repair(json)

            #expect(repaired == json)
        }

        @Test("String with escaped quotes is handled")
        func stringWithEscapedQuotes() {
            // String containing escaped quotes
            let json = #"{"message": "He said \"hello\""}"#
            let repaired = JsonRepair.repair(json)

            #expect(repaired == json)
        }

        @Test("Unclosed string with partial unicode at various lengths")
        func partialUnicodeVariousLengths() {
            // Test \u with no hex digits
            let partial1 = #"{"text": "\u"#
            #expect(JsonRepair.repair(partial1) == #"{"text": ""}"#)

            // Test \u with 1 hex digit
            let partial2 = #"{"text": "\u0"#
            #expect(JsonRepair.repair(partial2) == #"{"text": ""}"#)

            // Test \u with 2 hex digits
            let partial3 = #"{"text": "\u00"#
            #expect(JsonRepair.repair(partial3) == #"{"text": ""}"#)

            // Test \u with 3 hex digits
            let partial4 = #"{"text": "\u004"#
            #expect(JsonRepair.repair(partial4) == #"{"text": ""}"#)
        }
    }

    // MARK: - Object Repairs

    @Suite("Object Repairs")
    struct ObjectRepairTests {

        @Test("Unclosed single object gets closing brace")
        func unclosedSingleObject() {
            // Object without closing brace
            let incomplete = #"{"a": 1"#
            let repaired = JsonRepair.repair(incomplete)

            #expect(repaired == #"{"a": 1}"#)
        }

        @Test("Nested unclosed objects all get closed")
        func nestedUnclosedObjects() {
            // Multiple levels of unclosed objects
            let incomplete = #"{"user": {"name": "Bob""#
            let repaired = JsonRepair.repair(incomplete)

            #expect(repaired == #"{"user": {"name": "Bob"}}"#)
        }

        @Test("Trailing comma before close is removed")
        func trailingCommaRemoved() {
            // Object with trailing comma (invalid JSON)
            let invalidJson = #"{"a": 1,}"#
            let repaired = JsonRepair.repair(invalidJson)

            #expect(repaired == #"{"a": 1}"#)
        }

        @Test("Multiple trailing commas and whitespace are handled")
        func multipleTrailingCommasAndWhitespace() {
            // Object with comma and whitespace at end, but missing close
            let incomplete = #"{"a": 1,   "#
            let repaired = JsonRepair.repair(incomplete)

            // Should remove whitespace and comma, then close
            #expect(repaired == #"{"a": 1}"#)
        }

        @Test("Already valid object passes through unchanged")
        func validObjectUnchanged() {
            let validJson = #"{"name": "Alice", "age": 30, "active": true}"#
            let repaired = JsonRepair.repair(validJson)

            #expect(repaired == validJson)
        }

        @Test("Empty object is valid")
        func emptyObjectValid() {
            let emptyObject = "{}"
            let repaired = JsonRepair.repair(emptyObject)

            #expect(repaired == emptyObject)
        }

        @Test("Object with multiple properties and unclosed")
        func multiplePropertiesUnclosed() {
            let incomplete = #"{"name": "Alice", "age": 30, "city": "New York"#
            let repaired = JsonRepair.repair(incomplete)

            #expect(repaired == #"{"name": "Alice", "age": 30, "city": "New York"}"#)
        }
    }

    // MARK: - Array Repairs

    @Suite("Array Repairs")
    struct ArrayRepairTests {

        @Test("Unclosed array gets closing bracket")
        func unclosedArray() {
            let incomplete = "[1, 2, 3"
            let repaired = JsonRepair.repair(incomplete)

            #expect(repaired == "[1, 2, 3]")
        }

        @Test("Nested unclosed arrays all get closed")
        func nestedUnclosedArrays() {
            let incomplete = "[[1, 2, [3, 4"
            let repaired = JsonRepair.repair(incomplete)

            #expect(repaired == "[[1, 2, [3, 4]]]")
        }

        @Test("Mixed array and object closures")
        func mixedArrayObjectClosures() {
            // Object containing an unclosed array
            let incomplete = #"{"arr": [1, 2"#
            let repaired = JsonRepair.repair(incomplete)

            #expect(repaired == #"{"arr": [1, 2]}"#)
        }

        @Test("Array with trailing comma is fixed")
        func arrayTrailingComma() {
            let invalidJson = "[1, 2, 3,]"
            let repaired = JsonRepair.repair(invalidJson)

            #expect(repaired == "[1, 2, 3]")
        }

        @Test("Empty array is valid")
        func emptyArrayValid() {
            let emptyArray = "[]"
            let repaired = JsonRepair.repair(emptyArray)

            #expect(repaired == emptyArray)
        }

        @Test("Array of strings with one unclosed")
        func arrayOfStringsUnclosed() {
            let incomplete = #"["apple", "banana", "cherry"#
            let repaired = JsonRepair.repair(incomplete)

            #expect(repaired == #"["apple", "banana", "cherry"]"#)
        }

        @Test("Array of objects with one unclosed")
        func arrayOfObjectsUnclosed() {
            let incomplete = #"[{"name": "Alice"}, {"name": "Bob"#
            let repaired = JsonRepair.repair(incomplete)

            #expect(repaired == #"[{"name": "Alice"}, {"name": "Bob"}]"#)
        }
    }

    // MARK: - Edge Cases

    @Suite("Edge Cases")
    struct EdgeCaseTests {

        @Test("Empty input returns empty object")
        func emptyInputReturnsEmptyObject() {
            let repaired = JsonRepair.repair("")

            #expect(repaired == "{}")
        }

        @Test("Already valid JSON is unchanged")
        func alreadyValidJSONUnchanged() {
            let validJson = #"{"users": [{"name": "Alice", "age": 30}], "count": 1}"#
            let repaired = JsonRepair.repair(validJson)

            #expect(repaired == validJson)
        }

        @Test("Deeply nested structures (5+ levels)")
        func deeplyNestedStructures() {
            // 5 levels of nested objects, all unclosed
            let incomplete = #"{"a": {"b": {"c": {"d": {"e": "value""#
            let repaired = JsonRepair.repair(incomplete)

            #expect(repaired == #"{"a": {"b": {"c": {"d": {"e": "value"}}}}}"#)
        }

        @Test("Very long strings are handled")
        func veryLongStrings() {
            // Create a long string value
            let longValue = String(repeating: "x", count: 10000)
            let incomplete = #"{"data": ""# + longValue
            let repaired = JsonRepair.repair(incomplete)

            // Should close the string and object
            #expect(repaired.hasSuffix("\"}"))
            #expect(repaired.contains(longValue))
        }

        @Test("Multiple structural issues combined")
        func multipleStructuralIssues() {
            // Unclosed string, trailing comma, unclosed array, unclosed object
            let incomplete = #"{"items": [{"name": "test",  "#
            let repaired = JsonRepair.repair(incomplete)

            // Should fix all issues
            #expect(repaired == #"{"items": [{"name": "test"}]}"#)
        }

        @Test("Object with boolean values")
        func objectWithBooleanValues() {
            let incomplete = #"{"active": true, "verified": false"#
            let repaired = JsonRepair.repair(incomplete)

            #expect(repaired == #"{"active": true, "verified": false}"#)
        }

        @Test("Object with null values")
        func objectWithNullValues() {
            let incomplete = #"{"value": null, "other": 42"#
            let repaired = JsonRepair.repair(incomplete)

            #expect(repaired == #"{"value": null, "other": 42}"#)
        }

        @Test("Mixed nesting of arrays and objects")
        func mixedNestingDeep() {
            let incomplete = #"{"data": [{"items": [1, 2, {"nested": [3, 4"#
            let repaired = JsonRepair.repair(incomplete)

            #expect(repaired == #"{"data": [{"items": [1, 2, {"nested": [3, 4]}]}]}"#)
        }

        @Test("Whitespace only input returns empty object")
        func whitespaceOnlyInput() {
            // Only whitespace should be handled like empty
            let incomplete = "   "
            let repaired = JsonRepair.repair(incomplete)

            // After trimming whitespace, nothing remains so brackets added
            // Based on implementation, whitespace is removed then brackets closed
            #expect(repaired == "{}")
        }

        @Test("Single opening brace")
        func singleOpeningBrace() {
            let repaired = JsonRepair.repair("{")

            #expect(repaired == "{}")
        }

        @Test("Single opening bracket")
        func singleOpeningBracket() {
            let repaired = JsonRepair.repair("[")

            #expect(repaired == "[]")
        }
    }

    // MARK: - Integration with StructuredContent

    @Suite("StructuredContent Integration")
    struct StructuredContentIntegrationTests {

        @Test("parse() returns valid StructuredContent from incomplete JSON")
        func parseReturnsValidContent() throws {
            // Incomplete JSON that can be repaired
            let incomplete = #"{"name": "Alice", "age": 30"#

            let content = try JsonRepair.parse(incomplete)

            let obj = try content.object
            #expect(try obj["name"]?.string == "Alice")
            #expect(try obj["age"]?.int == 30)
        }

        @Test("tryParse() returns nil on fundamentally broken JSON")
        func tryParseReturnsNilOnBrokenJSON() {
            // JSON that cannot be meaningfully repaired
            // A colon without key-value structure
            let broken = #"{"name" :"#

            let content = JsonRepair.tryParse(broken)

            // The repair will try to close it, but the result may still be unparseable
            // Let's verify tryParse returns something (repair + parse might succeed)
            // Actually, this might succeed after repair, let's test a more broken case
            let veryBroken = #"{ : : : }"#
            let content2 = JsonRepair.tryParse(veryBroken)

            // This should fail to parse as the colon placement is invalid
            #expect(content2 == nil)
        }

        @Test("Round-trip: repair, parse, and access values")
        func roundTripRepairParseAccess() throws {
            // Simulate streaming JSON response cut off mid-way
            let streaming = #"{"users": [{"name": "Alice", "active": true}, {"name": "Bob""#

            // Repair the incomplete JSON
            let repaired = JsonRepair.repair(streaming)

            // Parse into StructuredContent
            let content = try StructuredContent(json: repaired)

            // Access the values
            let obj = try content.object
            let users = try obj["users"]?.array

            #expect(users?.count == 2)
            #expect(try users?[0].object["name"]?.string == "Alice")
            #expect(try users?[0].object["active"]?.bool == true)
            #expect(try users?[1].object["name"]?.string == "Bob")
        }

        @Test("tryParse returns content for simple incomplete JSON")
        func tryParseSucceedsForSimpleIncomplete() {
            let incomplete = #"{"message": "Hello, world"#

            let content = JsonRepair.tryParse(incomplete)

            #expect(content != nil)
            #expect((try? content?.object["message"]?.string) == "Hello, world")
        }

        @Test("parse throws on non-repairable JSON")
        func parseThrowsOnNonRepairable() {
            // Completely malformed JSON that repair cannot fix
            let malformed = "not json at all"

            // JsonRepair will try to close it but the result won't be valid JSON
            // However, "not json at all" becomes "not json at all" (no brackets to close)
            // This actually will fail to parse as StructuredContent
            #expect(throws: (any Error).self) {
                _ = try JsonRepair.parse(malformed)
            }
        }

        @Test("Empty input parses to empty object")
        func emptyInputParsesToEmptyObject() throws {
            let content = try JsonRepair.parse("")

            let obj = try content.object
            #expect(obj.isEmpty)
        }
    }

    // MARK: - Streaming Simulation Tests

    @Suite("Streaming Simulation")
    struct StreamingSimulationTests {

        @Test("Progressive streaming chunks all produce valid JSON")
        func progressiveStreamingChunks() throws {
            // Simulate receiving JSON progressively
            let fullJson = #"{"name": "Alice", "age": 30, "city": "NYC"}"#

            // Test various cut-off points
            let cutOffPoints = [5, 10, 15, 20, 25, 30, 35, 40]

            for cutOff in cutOffPoints where cutOff < fullJson.count {
                let partial = String(fullJson.prefix(cutOff))
                let repaired = JsonRepair.repair(partial)

                // Each repaired chunk should be parseable
                let content = JsonRepair.tryParse(partial)
                #expect(content != nil, "Failed to parse chunk at cutoff \(cutOff): \(partial)")
            }
        }

        @Test("Array streaming produces valid intermediate results")
        func arrayStreamingIntermediateResults() throws {
            // Simulate streaming an array of objects
            let partials = [
                "[",
                #"[{"id": 1"#,
                #"[{"id": 1}"#,
                #"[{"id": 1}, "#,
                #"[{"id": 1}, {"id": 2"#,
                #"[{"id": 1}, {"id": 2}]"#
            ]

            for partial in partials {
                let repaired = JsonRepair.repair(partial)
                let content = JsonRepair.tryParse(partial)
                #expect(content != nil, "Failed to parse: \(partial) -> \(repaired)")
            }
        }
    }

    // MARK: - Escape Sequence Tests

    @Suite("Escape Sequences")
    struct EscapeSequenceTests {

        @Test("Valid escape sequences pass through")
        func validEscapeSequences() {
            let json = #"{"text": "line1\nline2\ttab"}"#
            let repaired = JsonRepair.repair(json)

            #expect(repaired == json)
        }

        @Test("Escaped backslash is handled")
        func escapedBackslash() {
            let json = #"{"path": "C:\\Users\\Alice"}"#
            let repaired = JsonRepair.repair(json)

            #expect(repaired == json)
        }

        @Test("Complete unicode escape is preserved")
        func completeUnicodeEscape() {
            let json = #"{"symbol": "\u0041"}"#
            let repaired = JsonRepair.repair(json)

            #expect(repaired == json)
        }

        @Test("Multiple escape sequences in string")
        func multipleEscapeSequences() {
            let incomplete = #"{"text": "hello\nworld\t"#
            let repaired = JsonRepair.repair(incomplete)

            #expect(repaired == #"{"text": "hello\nworld\t"}"#)
        }
    }
}
