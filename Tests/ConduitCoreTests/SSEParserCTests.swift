// SSEParserCTests.swift
// ConduitCoreTests

import Foundation
import Testing
import ConduitCore

@Suite("SSE Parser C Tests")
struct SSEParserCTests {

    // Collected events from callbacks
    final class EventCollector: @unchecked Sendable {
        struct Event {
            let id: String?
            let event: String?
            let data: String
            let retry: Int
        }

        var events: [Event] = []

        static let callback: conduit_sse_callback_t = { eventPtr, contextPtr in
            guard let event = eventPtr, let ctx = contextPtr else { return }
            let collector = Unmanaged<EventCollector>.fromOpaque(ctx).takeUnretainedValue()

            let id = event.pointee.id.map { String(cString: $0) }
            let eventType = event.pointee.event.map { String(cString: $0) }
            let data = String(cString: event.pointee.data)
            let retry = Int(event.pointee.retry)

            collector.events.append(Event(id: id, event: eventType, data: data, retry: retry))
        }
    }

    func makeParser() -> OpaquePointer {
        conduit_sse_parser_create()!
    }

    func ingest(_ parser: OpaquePointer, line: String, collector: EventCollector) {
        let ctx = Unmanaged.passUnretained(collector).toOpaque()
        line.withCString { cstr in
            conduit_sse_ingest_line(parser, cstr, strlen(cstr), EventCollector.callback, ctx)
        }
    }

    func finish(_ parser: OpaquePointer, collector: EventCollector) {
        let ctx = Unmanaged.passUnretained(collector).toOpaque()
        conduit_sse_finish(parser, EventCollector.callback, ctx)
    }

    // MARK: - Basic Events

    @Test("Simple data event dispatched on empty line")
    func simpleDataEvent() {
        let parser = makeParser()
        defer { conduit_sse_parser_destroy(parser) }
        let collector = EventCollector()

        ingest(parser, line: "data: hello world", collector: collector)
        #expect(collector.events.isEmpty) // Not dispatched yet

        ingest(parser, line: "", collector: collector) // Empty line dispatches
        #expect(collector.events.count == 1)
        #expect(collector.events[0].data == "hello world")
        #expect(collector.events[0].event == nil)
        #expect(collector.events[0].id == nil)
    }

    @Test("Event with type")
    func eventWithType() {
        let parser = makeParser()
        defer { conduit_sse_parser_destroy(parser) }
        let collector = EventCollector()

        ingest(parser, line: "event: update", collector: collector)
        ingest(parser, line: "data: some data", collector: collector)
        ingest(parser, line: "", collector: collector)

        #expect(collector.events.count == 1)
        #expect(collector.events[0].event == "update")
        #expect(collector.events[0].data == "some data")
    }

    @Test("Event with id")
    func eventWithId() {
        let parser = makeParser()
        defer { conduit_sse_parser_destroy(parser) }
        let collector = EventCollector()

        ingest(parser, line: "id: 42", collector: collector)
        ingest(parser, line: "data: test", collector: collector)
        ingest(parser, line: "", collector: collector)

        #expect(collector.events.count == 1)
        #expect(collector.events[0].id == "42")
        #expect(collector.events[0].data == "test")
    }

    @Test("Multi-line data joined with newlines")
    func multiLineData() {
        let parser = makeParser()
        defer { conduit_sse_parser_destroy(parser) }
        let collector = EventCollector()

        ingest(parser, line: "data: line1", collector: collector)
        ingest(parser, line: "data: line2", collector: collector)
        ingest(parser, line: "data: line3", collector: collector)
        ingest(parser, line: "", collector: collector)

        #expect(collector.events.count == 1)
        #expect(collector.events[0].data == "line1\nline2\nline3")
    }

    // MARK: - Comments and Unknown Fields

    @Test("Comments are ignored")
    func commentsIgnored() {
        let parser = makeParser()
        defer { conduit_sse_parser_destroy(parser) }
        let collector = EventCollector()

        ingest(parser, line: ": this is a comment", collector: collector)
        ingest(parser, line: "data: actual data", collector: collector)
        ingest(parser, line: "", collector: collector)

        #expect(collector.events.count == 1)
        #expect(collector.events[0].data == "actual data")
    }

    @Test("Unknown fields are ignored")
    func unknownFieldsIgnored() {
        let parser = makeParser()
        defer { conduit_sse_parser_destroy(parser) }
        let collector = EventCollector()

        ingest(parser, line: "custom: field", collector: collector)
        ingest(parser, line: "data: test", collector: collector)
        ingest(parser, line: "", collector: collector)

        #expect(collector.events.count == 1)
        #expect(collector.events[0].data == "test")
    }

    // MARK: - Retry

    @Test("Retry field parsed correctly")
    func retryField() {
        let parser = makeParser()
        defer { conduit_sse_parser_destroy(parser) }
        let collector = EventCollector()

        ingest(parser, line: "retry: 5000", collector: collector)
        ingest(parser, line: "data: test", collector: collector)
        ingest(parser, line: "", collector: collector)

        #expect(collector.events.count == 1)
        #expect(collector.events[0].retry == 5000)
    }

    // MARK: - Finish

    @Test("Finish flushes pending event")
    func finishFlushes() {
        let parser = makeParser()
        defer { conduit_sse_parser_destroy(parser) }
        let collector = EventCollector()

        ingest(parser, line: "data: pending", collector: collector)
        #expect(collector.events.isEmpty)

        finish(parser, collector: collector)
        #expect(collector.events.count == 1)
        #expect(collector.events[0].data == "pending")
    }

    @Test("Finish with nothing pending produces no event")
    func finishNoPending() {
        let parser = makeParser()
        defer { conduit_sse_parser_destroy(parser) }
        let collector = EventCollector()

        finish(parser, collector: collector)
        #expect(collector.events.isEmpty)
    }

    // MARK: - Multiple Events

    @Test("Multiple events in sequence")
    func multipleEvents() {
        let parser = makeParser()
        defer { conduit_sse_parser_destroy(parser) }
        let collector = EventCollector()

        ingest(parser, line: "data: first", collector: collector)
        ingest(parser, line: "", collector: collector)
        ingest(parser, line: "data: second", collector: collector)
        ingest(parser, line: "", collector: collector)

        #expect(collector.events.count == 2)
        #expect(collector.events[0].data == "first")
        #expect(collector.events[1].data == "second")
    }

    // MARK: - Edge Cases

    @Test("Leading space in data value stripped per spec")
    func leadingSpaceStripped() {
        let parser = makeParser()
        defer { conduit_sse_parser_destroy(parser) }
        let collector = EventCollector()

        ingest(parser, line: "data:  two spaces", collector: collector)
        ingest(parser, line: "", collector: collector)

        // Only first space stripped, second kept
        #expect(collector.events[0].data == " two spaces")
    }

    @Test("Field with no colon uses whole line as field name")
    func noColonFieldName() {
        let parser = makeParser()
        defer { conduit_sse_parser_destroy(parser) }
        let collector = EventCollector()

        // "data" with no colon is treated as field "data" with empty value
        ingest(parser, line: "data", collector: collector)
        ingest(parser, line: "", collector: collector)

        #expect(collector.events.count == 1)
        #expect(collector.events[0].data == "")
    }
}
