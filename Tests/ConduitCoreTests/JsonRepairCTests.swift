// JsonRepairCTests.swift
// ConduitCoreTests

import Foundation
import Testing
import ConduitCore

@Suite("JSON Repair C Tests")
struct JsonRepairCTests {

    // Helper to call the C repair function
    func repair(_ json: String, maxDepth: Int = 64) -> String {
        let input = Array(json.utf8)
        let capacity = input.count + 256
        var output = [CChar](repeating: 0, count: capacity)

        let result = input.withUnsafeBufferPointer { inputBuf in
            output.withUnsafeMutableBufferPointer { outputBuf in
                conduit_json_repair(
                    inputBuf.baseAddress,
                    inputBuf.count,
                    outputBuf.baseAddress,
                    outputBuf.count,
                    Int32(maxDepth)
                )
            }
        }

        guard result >= 0 else { return "" }
        return String(cString: output)
    }

    // MARK: - String Repairs

    @Test("Unclosed string at end gets closing quote and brace")
    func unclosedStringAtEnd() {
        let repaired = repair(#"{"name": "Alice"#)
        #expect(repaired == #"{"name": "Alice"}"#)
    }

    @Test("Incomplete escape sequence at end is handled")
    func incompleteEscapeSequence() {
        let repaired = repair(#"{"text": "hello\"#)
        #expect(repaired == #"{"text": "hello"}"#)
    }

    @Test("Partial unicode escape is removed")
    func partialUnicodeEscape() {
        let repaired = repair(#"{"text": "\u00"#)
        #expect(repaired == #"{"text": ""}"#)
    }

    @Test("Normal strings pass through unchanged")
    func normalStringsUnchanged() {
        let complete = #"{"name": "Alice", "age": 30}"#
        #expect(repair(complete) == complete)
    }

    // MARK: - Object Repairs

    @Test("Unclosed single object")
    func unclosedSingleObject() {
        #expect(repair(#"{"a": 1"#) == #"{"a": 1}"#)
    }

    @Test("Nested unclosed objects")
    func nestedUnclosedObjects() {
        #expect(repair(#"{"user": {"name": "Bob""#) == #"{"user": {"name": "Bob"}}"#)
    }

    @Test("Trailing comma before close removed")
    func trailingCommaRemoved() {
        #expect(repair(#"{"a": 1,}"#) == #"{"a": 1}"#)
    }

    @Test("Multiple trailing commas and whitespace")
    func multipleTrailingCommasAndWhitespace() {
        #expect(repair(#"{"a": 1,   "#) == #"{"a": 1}"#)
    }

    @Test("Valid object passes through unchanged")
    func validObjectUnchanged() {
        let json = #"{"name": "Alice", "age": 30, "active": true}"#
        #expect(repair(json) == json)
    }

    @Test("Empty object is valid")
    func emptyObjectValid() {
        #expect(repair("{}") == "{}")
    }

    // MARK: - Array Repairs

    @Test("Unclosed array")
    func unclosedArray() {
        #expect(repair("[1, 2, 3") == "[1, 2, 3]")
    }

    @Test("Nested unclosed arrays")
    func nestedUnclosedArrays() {
        #expect(repair("[[1, 2, [3, 4") == "[[1, 2, [3, 4]]]")
    }

    @Test("Mixed array and object closures")
    func mixedArrayObjectClosures() {
        #expect(repair(#"{"arr": [1, 2"#) == #"{"arr": [1, 2]}"#)
    }

    @Test("Array trailing comma fixed")
    func arrayTrailingComma() {
        #expect(repair("[1, 2, 3,]") == "[1, 2, 3]")
    }

    @Test("Empty array is valid")
    func emptyArrayValid() {
        #expect(repair("[]") == "[]")
    }

    // MARK: - Edge Cases

    @Test("Empty input returns empty object")
    func emptyInput() {
        #expect(repair("") == "{}")
    }

    @Test("Deeply nested structures (5+ levels)")
    func deeplyNested() {
        let repaired = repair(#"{"a": {"b": {"c": {"d": {"e": "value""#)
        #expect(repaired == #"{"a": {"b": {"c": {"d": {"e": "value"}}}}}"#)
    }

    @Test("Mixed nesting deep")
    func mixedNestingDeep() {
        let repaired = repair(#"{"data": [{"items": [1, 2, {"nested": [3, 4"#)
        #expect(repaired == #"{"data": [{"items": [1, 2, {"nested": [3, 4]}]}]}"#)
    }

    @Test("Single opening brace")
    func singleBrace() {
        #expect(repair("{") == "{}")
    }

    @Test("Single opening bracket")
    func singleBracket() {
        #expect(repair("[") == "[]")
    }

    @Test("Whitespace only input")
    func whitespaceOnly() {
        #expect(repair("   ") == "{}")
    }

    @Test("Boolean values")
    func booleanValues() {
        #expect(repair(#"{"active": true, "verified": false"#) ==
                #"{"active": true, "verified": false}"#)
    }

    @Test("Null values")
    func nullValues() {
        #expect(repair(#"{"value": null, "other": 42"#) ==
                #"{"value": null, "other": 42}"#)
    }
}
