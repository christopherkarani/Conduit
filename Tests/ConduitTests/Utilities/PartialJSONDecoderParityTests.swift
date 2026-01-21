import XCTest
@testable import Conduit

final class PartialJSONDecoderParityTests: XCTestCase {

    private struct Message: Codable, Sendable, Equatable {
        var id: Int?
        var text: String?
        var tags: [String]?
    }

    func testDecodeCompleteJSONReportsComplete() throws {
        let decoder = PartialJSONDecoder()
        let json = #"{"id":42,"text":"hi","tags":["a","b"]}"#

        let (value, isComplete) = try decoder.decode(Message.self, from: json)
        XCTAssertEqual(value, Message(id: 42, text: "hi", tags: ["a", "b"]))
        XCTAssertTrue(isComplete)
    }

    func testDecodePartialJSONRepairsAndReportsIncomplete() throws {
        let decoder = PartialJSONDecoder()
        let json = #"{"id":42,"text":"hi","tags":["a","b""#

        let (value, isComplete) = try decoder.decode(Message.self, from: json)
        XCTAssertEqual(value.id, 42)
        XCTAssertEqual(value.text, "hi")
        XCTAssertEqual(value.tags, ["a", "b"])
        XCTAssertFalse(isComplete)
    }

    func testJSONCompleterReturnsCompletionAndTruncationIndex() throws {
        let completer = JSONCompleter()
        completer.maximumDepth = 64

        let json = #"{"id":42,"text":"hi","tags":["a","b""#
        let start = json.startIndex

        let completion = try XCTUnwrap(completer.completion(for: json, from: start))
        let completed = String(json[..<completion.endIndex]) + completion.string

        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: Data(completed.utf8)))
    }

    func testJSONCompleterCompletesCommonPartialsIntoValidJSONWhenPossible() throws {
        struct Case {
            var input: String
            var expectsValidJSON: Bool
        }

        let cases: [Case] = [
            .init(input: "", expectsValidJSON: false),
            .init(input: "   ", expectsValidJSON: false),
            .init(input: "42", expectsValidJSON: true),
            .init(input: "\"hello\"", expectsValidJSON: true),
            .init(input: "\"hello", expectsValidJSON: true),
            .init(input: "[1, 2, 3]", expectsValidJSON: true),
            .init(input: "[1, 2, 3", expectsValidJSON: true),
            .init(input: "[1, 2, 3,", expectsValidJSON: true),
            .init(input: "[1, 2,", expectsValidJSON: true),
            .init(input: "[[1, 2], [3,", expectsValidJSON: true),
            .init(input: #"{"a": 1}"#, expectsValidJSON: true),
            .init(input: #"{"a": 1"#, expectsValidJSON: true),
            .init(input: #"{"key":"#, expectsValidJSON: true),
            .init(input: #"{"key": 42,"#, expectsValidJSON: true),
            .init(input: #"{"key": "value"#, expectsValidJSON: true),
            .init(input: #"{"key1": true, "key2":"#, expectsValidJSON: true),
            .init(input: #"{"outer": {"inner": [1, 2, {"nested":"#, expectsValidJSON: true),
            .init(input: "123.", expectsValidJSON: true),
            .init(input: "-", expectsValidJSON: true),
            .init(input: "-.", expectsValidJSON: true),
            .init(input: "-123.", expectsValidJSON: true),
            .init(input: "1.23e", expectsValidJSON: true),
            .init(input: "1.23e+", expectsValidJSON: true),
            .init(input: "1.23e-", expectsValidJSON: true),
            // These remain invalid because they contain incomplete escape sequences.
            .init(input: "\"Partial escape: \\", expectsValidJSON: false),
            .init(input: "\"Unicode escape: \\u26", expectsValidJSON: false),
        ]

        let completer = JSONCompleter()
        completer.maximumDepth = 64

        for testCase in cases {
            let completed = try completer.complete(testCase.input)
            let isValid =
                (try? JSONSerialization.jsonObject(with: Data(completed.utf8), options: [.fragmentsAllowed])) != nil
            XCTAssertEqual(isValid, testCase.expectsValidJSON, "Unexpected validity for input: \(testCase.input)")
        }
    }
}
