import XCTest
@testable import Conduit

final class ServerSentEventParserParityTests: XCTestCase {

    func testSingleDataEventDispatchesOnBlankLine() {
        var parser = ServerSentEventParser()

        XCTAssertEqual(parser.ingestLine("data: hello").count, 0)
        let events = parser.ingestLine("")

        XCTAssertEqual(events, [
            ServerSentEvent(id: nil, event: "message", data: "hello")
        ])
    }

    func testMultiLineDataIsJoinedWithNewlines() {
        var parser = ServerSentEventParser()

        _ = parser.ingestLine("data: hello")
        _ = parser.ingestLine("data: world")
        let events = parser.ingestLine("")

        XCTAssertEqual(events, [
            ServerSentEvent(id: nil, event: "message", data: "hello\nworld")
        ])
    }

    func testEventTypeAndIdAreParsed() {
        var parser = ServerSentEventParser()

        _ = parser.ingestLine("id: 123")
        _ = parser.ingestLine("event: ping")
        _ = parser.ingestLine("data: {}")
        let events = parser.ingestLine("")

        XCTAssertEqual(events, [
            ServerSentEvent(id: "123", event: "ping", data: "{}")
        ])
    }

    func testIdPersistsAcrossEventsPerSpec() {
        var parser = ServerSentEventParser()

        _ = parser.ingestLine("id: 1")
        _ = parser.ingestLine("data: first")
        XCTAssertEqual(parser.ingestLine(""), [ServerSentEvent(id: "1", event: "message", data: "first")])

        _ = parser.ingestLine("data: second")
        XCTAssertEqual(parser.ingestLine(""), [ServerSentEvent(id: "1", event: "message", data: "second")])
    }

    func testNoSpaceAfterColonIsAccepted() {
        var parser = ServerSentEventParser()

        _ = parser.ingestLine("data:hello")
        XCTAssertEqual(parser.ingestLine(""), [ServerSentEvent(id: nil, event: "message", data: "hello")])
    }

    func testCRLFLeavesTrailingCarriageReturnWhichIsStripped() {
        var parser = ServerSentEventParser()

        _ = parser.ingestLine("data: hello\r")
        XCTAssertEqual(parser.ingestLine(""), [ServerSentEvent(id: nil, event: "message", data: "hello")])
    }

    func testCommentsAndUnknownFieldsAreIgnored() {
        var parser = ServerSentEventParser()

        _ = parser.ingestLine(": this is a comment")
        _ = parser.ingestLine("foo: bar")
        _ = parser.ingestLine("data: ok")
        XCTAssertEqual(parser.ingestLine(""), [ServerSentEvent(id: nil, event: "message", data: "ok")])
    }

    func testNoDataDoesNotDispatch() {
        var parser = ServerSentEventParser()

        _ = parser.ingestLine("event: ping")
        XCTAssertTrue(parser.ingestLine("").isEmpty)
    }
}

