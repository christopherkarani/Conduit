import XCTest
@testable import Conduit

final class ServerSentEventParserParityTests: XCTestCase {

    func testByteStreamParsingCoversCommonEventSourceSemantics() {
        struct Case {
            var name: String
            var bytes: [UInt8]
            var expected: [ServerSentEvent]
        }

        let invalidUTF8: [UInt8] = [0xC3, 0x28] // Invalid 2-byte sequence.

        let cases: [Case] = [
            .init(
                name: "LF",
                bytes: Array("data: hello\n\n".utf8),
                expected: [ServerSentEvent(id: nil, event: nil, data: "hello", retry: nil)]
            ),
            .init(
                name: "CRLF",
                bytes: Array("data: hello\r\n\r\n".utf8),
                expected: [ServerSentEvent(id: nil, event: nil, data: "hello", retry: nil)]
            ),
            .init(
                name: "CR",
                bytes: Array("data: hello\r\r".utf8),
                expected: [ServerSentEvent(id: nil, event: nil, data: "hello", retry: nil)]
            ),
            .init(
                name: "Multi-line data",
                bytes: Array("data: hello\ndata: world\n\n".utf8),
                expected: [ServerSentEvent(id: nil, event: nil, data: "hello\nworld", retry: nil)]
            ),
            .init(
                name: "No space after colon",
                bytes: Array("data:hello\n\n".utf8),
                expected: [ServerSentEvent(id: nil, event: nil, data: "hello", retry: nil)]
            ),
            .init(
                name: "Event + data",
                bytes: Array("event: ping\ndata: {}\n\n".utf8),
                expected: [ServerSentEvent(id: nil, event: "ping", data: "{}", retry: nil)]
            ),
            .init(
                name: "Id + data",
                bytes: Array("id: 123\ndata: ok\n\n".utf8),
                expected: [ServerSentEvent(id: "123", event: nil, data: "ok", retry: nil)]
            ),
            .init(
                name: "Id does not persist",
                bytes: Array("id: 1\ndata: first\n\ndata: second\n\n".utf8),
                expected: [
                    ServerSentEvent(id: "1", event: nil, data: "first", retry: nil),
                    ServerSentEvent(id: nil, event: nil, data: "second", retry: nil),
                ]
            ),
            .init(
                name: "Ignore comment + unknown",
                bytes: Array(": comment\nfoo: bar\ndata: ok\n\n".utf8),
                expected: [ServerSentEvent(id: nil, event: nil, data: "ok", retry: nil)]
            ),
            .init(
                name: "Retry-only does not dispatch",
                bytes: Array("retry: 5000\n\n".utf8),
                expected: []
            ),
            .init(
                name: "Retry included when combined",
                bytes: Array("retry: 5000\ndata: ok\n\n".utf8),
                expected: [ServerSentEvent(id: nil, event: nil, data: "ok", retry: 5000)]
            ),
            .init(
                name: "Empty data dispatches",
                bytes: Array("data:\n\n".utf8),
                expected: [ServerSentEvent(id: nil, event: nil, data: "", retry: nil)]
            ),
            .init(
                name: "EOF flushes when needed",
                bytes: Array("data: hello".utf8),
                expected: [ServerSentEvent(id: nil, event: nil, data: "hello", retry: nil)]
            ),
            .init(
                name: "EOF does not flush empty data-only",
                bytes: Array("data:\n".utf8),
                expected: []
            ),
            .init(
                name: "BOM stripped",
                bytes: [0xEF, 0xBB, 0xBF] + Array("data: hello\n\n".utf8),
                expected: [ServerSentEvent(id: nil, event: nil, data: "hello", retry: nil)]
            ),
            .init(
                name: "Invalid UTF-8 replaced",
                bytes: Array("data: ".utf8) + invalidUTF8 + Array("\n\n".utf8),
                expected: [ServerSentEvent(id: nil, event: nil, data: "\u{FFFD}(", retry: nil)]
            ),
            .init(
                name: "Id containing null is ignored",
                bytes: Array("id: 1\u{0000}\ndata: ok\n\n".utf8),
                expected: [ServerSentEvent(id: nil, event: nil, data: "ok", retry: nil)]
            ),
        ]

        for testCase in cases {
            XCTAssertEqual(parseConduit(testCase.bytes), testCase.expected, "Mismatch for case '\(testCase.name)'")
        }
    }

    func testSingleDataEventDispatchesOnBlankLine() {
        var parser = ServerSentEventParser()

        XCTAssertEqual(parser.ingestLine("data: hello").count, 0)
        let events = parser.ingestLine("")

        XCTAssertEqual(events, [
            ServerSentEvent(id: nil, event: nil, data: "hello", retry: nil)
        ])
    }

    func testMultiLineDataIsJoinedWithNewlines() {
        var parser = ServerSentEventParser()

        _ = parser.ingestLine("data: hello")
        _ = parser.ingestLine("data: world")
        let events = parser.ingestLine("")

        XCTAssertEqual(events, [
            ServerSentEvent(id: nil, event: nil, data: "hello\nworld", retry: nil)
        ])
    }

    func testEventTypeAndIdAreParsed() {
        var parser = ServerSentEventParser()

        _ = parser.ingestLine("id: 123")
        _ = parser.ingestLine("event: ping")
        _ = parser.ingestLine("data: {}")
        let events = parser.ingestLine("")

        XCTAssertEqual(events, [
            ServerSentEvent(id: "123", event: "ping", data: "{}", retry: nil)
        ])
    }

    func testIdDoesNotPersistAcrossEvents() {
        var parser = ServerSentEventParser()

        _ = parser.ingestLine("id: 1")
        _ = parser.ingestLine("data: first")
        XCTAssertEqual(parser.ingestLine(""), [ServerSentEvent(id: "1", event: nil, data: "first", retry: nil)])

        _ = parser.ingestLine("data: second")
        XCTAssertEqual(parser.ingestLine(""), [ServerSentEvent(id: nil, event: nil, data: "second", retry: nil)])
    }

    func testNoSpaceAfterColonIsAccepted() {
        var parser = ServerSentEventParser()

        _ = parser.ingestLine("data:hello")
        XCTAssertEqual(parser.ingestLine(""), [ServerSentEvent(id: nil, event: nil, data: "hello", retry: nil)])
    }

    func testCRLFLeavesTrailingCarriageReturnWhichIsStripped() {
        var parser = ServerSentEventParser()

        _ = parser.ingestLine("data: hello\r")
        XCTAssertEqual(parser.ingestLine(""), [ServerSentEvent(id: nil, event: nil, data: "hello", retry: nil)])
    }

    func testCommentsAndUnknownFieldsAreIgnored() {
        var parser = ServerSentEventParser()

        _ = parser.ingestLine(": this is a comment")
        _ = parser.ingestLine("foo: bar")
        _ = parser.ingestLine("data: ok")
        XCTAssertEqual(parser.ingestLine(""), [ServerSentEvent(id: nil, event: nil, data: "ok", retry: nil)])
    }

    func testByteOrderMarkIsStrippedFromFirstLine() {
        var parser = ServerSentEventParser()

        _ = parser.ingestLine("\u{FEFF}data: hello")
        XCTAssertEqual(parser.ingestLine(""), [ServerSentEvent(id: nil, event: nil, data: "hello", retry: nil)])
    }

    func testNoDataDoesNotDispatch() {
        var parser = ServerSentEventParser()

        _ = parser.ingestLine("event: ping")
        XCTAssertEqual(parser.ingestLine(""), [
            ServerSentEvent(id: nil, event: "ping", data: "", retry: nil)
        ])
    }

    // MARK: - Helpers

    private func parseConduit(_ bytes: [UInt8]) -> [ServerSentEvent] {
        var parser = ServerSentEventParser()
        var events: [ServerSentEvent] = []

        var start = 0
        var index = 0

        while index < bytes.count {
            let byte = bytes[index]
            let isLF = byte == UInt8(ascii: "\n")
            let isCR = byte == UInt8(ascii: "\r")

            if isLF || isCR {
                let lineBytes = Array(bytes[start..<index])
                let line = String(decoding: lineBytes, as: UTF8.self)
                events.append(contentsOf: parser.ingestLine(line))

                index += 1
                if isCR, index < bytes.count, bytes[index] == UInt8(ascii: "\n") {
                    index += 1
                }
                start = index
                continue
            }

            index += 1
        }

        if start < bytes.count {
            let lineBytes = Array(bytes[start..<bytes.count])
            let line = String(decoding: lineBytes, as: UTF8.self)
            events.append(contentsOf: parser.ingestLine(line))
        }

        events.append(contentsOf: parser.finish())
        return events
    }
}
