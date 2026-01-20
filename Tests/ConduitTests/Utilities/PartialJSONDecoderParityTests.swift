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

        let result = try decoder.decode(Message.self, from: json)
        XCTAssertEqual(result.value, Message(id: 42, text: "hi", tags: ["a", "b"]))
        XCTAssertTrue(result.isComplete)
    }

    func testDecodePartialJSONRepairsAndReportsIncomplete() throws {
        let decoder = PartialJSONDecoder()
        let json = #"{"id":42,"text":"hi","tags":["a","b""#

        let result = try decoder.decode(Message.self, from: json)
        XCTAssertEqual(result.value.id, 42)
        XCTAssertEqual(result.value.text, "hi")
        XCTAssertEqual(result.value.tags, ["a", "b"])
        XCTAssertFalse(result.isComplete)
    }

    func testJSONCompleterReturnsCompletionAndTruncationIndex() throws {
        var completer = JSONCompleter()
        completer.maximumDepth = 64

        let json = #"{"id":42,"text":"hi","tags":["a","b""#
        let start = json.startIndex

        let completion = try XCTUnwrap(completer.completion(for: json, from: start))
        let completed = String(json[..<completion.endIndex]) + completion.completion

        XCTAssertNotNil(JsonRepair.tryParse(completed))
    }
}

