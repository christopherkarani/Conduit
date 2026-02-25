// JsonCompleterCTests.swift
// ConduitCoreTests

import Foundation
import Testing
import ConduitCore

@Suite("JSON Completer C Tests")
struct JsonCompleterCTests {

    // Helper: calls conduit_json_complete which now returns the FULL completed string
    // Returns empty string if JSON is already complete, or the full completed string otherwise
    func completeRaw(_ json: String, maxDepth: Int = 64) -> (output: String, resultCode: Int64) {
        let input = Array(json.utf8)
        let capacity = input.count + 256
        var output = [CChar](repeating: 0, count: capacity)

        let result = input.withUnsafeBufferPointer { inputBuf in
            output.withUnsafeMutableBufferPointer { outputBuf in
                conduit_json_complete(
                    inputBuf.baseAddress,
                    inputBuf.count,
                    outputBuf.baseAddress,
                    outputBuf.count,
                    Int32(maxDepth)
                )
            }
        }

        return (String(cString: output), result)
    }

    // Helper: returns full completed JSON (the original if already complete)
    func fullComplete(_ json: String) -> String {
        let (output, code) = completeRaw(json)
        if code == 0 { return json } // Already complete
        if code < 0 { return json }  // Error fallback
        return output
    }

    // MARK: - Complete JSON returns code 0 (already complete)

    @Test("Complete object needs no completion")
    func completeObjectNoSuffix() {
        let (_, code) = completeRaw(#"{"a": 1}"#)
        #expect(code == 0)
    }

    @Test("Complete array needs no completion")
    func completeArrayNoSuffix() {
        let (_, code) = completeRaw("[1, 2, 3]")
        #expect(code == 0)
    }

    @Test("Complete string needs no completion")
    func completeStringNoSuffix() {
        let (_, code) = completeRaw(#""hello""#)
        #expect(code == 0)
    }

    @Test("Empty input returns code 0")
    func emptyInput() {
        let (_, code) = completeRaw("")
        #expect(code == 0)
    }

    // MARK: - String Completion

    @Test("Unclosed string gets closing quote")
    func unclosedString() {
        #expect(fullComplete(#""hello"#) == #""hello""#)
    }

    // MARK: - Object Completion

    @Test("Unclosed object with value")
    func unclosedObjectWithValue() {
        let result = fullComplete(#"{"a": 1"#)
        #expect(result == #"{"a": 1}"#)
    }

    @Test("Object with incomplete key gets null value")
    func objectIncompleteKey() {
        let result = fullComplete(#"{"name"#)
        // Should complete the string and add : null}
        #expect(result == #"{"name": null}"#)
    }

    @Test("Object with key and colon but no value")
    func objectKeyColonNoValue() {
        let result = fullComplete(#"{"name": "#)
        // Trailing space after colon is before the completion point,
        // so the output truncates at the colon position: {"name":null}
        #expect(result == #"{"name":null}"#)
    }

    @Test("Object with incomplete string value")
    func objectIncompleteStringValue() {
        let result = fullComplete(#"{"name": "Alice"#)
        #expect(result == #"{"name": "Alice"}"#)
    }

    @Test("Nested objects get closed")
    func nestedObjectsClosed() {
        let result = fullComplete(#"{"a": {"b": 1"#)
        #expect(result == #"{"a": {"b": 1}}"#)
    }

    // MARK: - Array Completion

    @Test("Unclosed array")
    func unclosedArray() {
        let result = fullComplete("[1, 2")
        #expect(result == "[1, 2]")
    }

    @Test("Array with incomplete element")
    func arrayIncompleteElement() {
        let result = fullComplete(#"[1, "hello"#)
        #expect(result == #"[1, "hello"]"#)
    }

    // MARK: - Special Values

    @Test("Partial true gets completed")
    func partialTrue() {
        #expect(fullComplete("tr") == "true")
    }

    @Test("Partial false gets completed")
    func partialFalse() {
        #expect(fullComplete("fal") == "false")
    }

    @Test("Partial null gets completed")
    func partialNull() {
        #expect(fullComplete("nu") == "null")
    }

    // MARK: - Number Completion

    @Test("Complete number needs no completion")
    func completeNumber() {
        let (_, code) = completeRaw("42")
        #expect(code == 0)
    }

    @Test("Bare minus gets -0")
    func bareMinus() {
        #expect(fullComplete("-") == "-0")
    }

    @Test("Decimal point without fraction")
    func decimalNoFraction() {
        #expect(fullComplete("3.") == "3.0")
    }

    @Test("Minus-dot gets -0.0")
    func minusDot() {
        #expect(fullComplete("-.") == "-0.0")
    }
}
