// ServerSentEventParser.swift
// Conduit
//
// Minimal Server-Sent Events (SSE) parsing utilities. Designed to match the
// behavior expected by common EventSource implementations.

import Foundation

/// A parsed Server-Sent Event.
///
/// Mirrors the semantics of common `EventSource` implementations:
/// - `event == nil` implies the default type `"message"`
/// - `id` is only set when an `id:` field is present for that event
internal struct ServerSentEvent: Sendable, Equatable {
    /// The event ID (if provided by the server for this event).
    var id: String?

    /// The event type name (if provided via `event:`; `nil` implies `"message"`).
    var event: String?

    /// The event data payload (may contain newlines if multiple `data:` lines were present).
    var data: String

    /// Optional reconnection retry interval (ms) if provided by a `retry:` field.
    var retry: Int?
}

/// Incremental parser for Server-Sent Events (SSE).
///
/// Feed the parser newline-delimited lines (without the trailing `\n`). A blank line
/// terminates the current event and causes it to be emitted.
internal struct ServerSentEventParser: Sendable {
    // Current event state
    private var currentEventId: String?
    private var currentEventType: String?
    private var currentData: String = ""
    private var currentRetry: Int?

    // Persistent state (not currently surfaced, but maintained for parity)
    private var lastEventId: String = ""
    private var reconnectionTime: Int = 3000

    private var seenFields: Set<String> = []

    init() {}

    /// Ingests one SSE line (without its trailing newline) and returns any complete events.
    mutating func ingestLine(_ line: String) -> [ServerSentEvent] {
        let normalizedLine = normalizeLine(line)

        // Empty line dispatches the event.
        if normalizedLine.isEmpty {
            let events = dispatchIfNeeded()
            seenFields.removeAll(keepingCapacity: true)
            return events
        }

        // Comments begin with ":" and are ignored.
        if normalizedLine.hasPrefix(":") {
            return []
        }

        let (field, value) = parseFieldValue(normalizedLine)

        switch field {
        case "event":
            currentEventType = value
            seenFields.insert("event")
        case "data":
            if !currentData.isEmpty {
                currentData.append("\n")
            }
            currentData.append(value)
            seenFields.insert("data")
        case "id":
            if !value.contains("\u{0000}") {
                currentEventId = value
                lastEventId = value
            }
            seenFields.insert("id")
        case "retry":
            if let milliseconds = Int(value), milliseconds > 0 {
                reconnectionTime = milliseconds
                currentRetry = milliseconds
            }
            seenFields.insert("retry")
        default:
            // Ignore unknown fields.
            break
        }

        return []
    }

    /// Call at end-of-stream to flush any pending event.
    mutating func finish() -> [ServerSentEvent] {
        // Match upstream `EventSource.Parser.finish()` semantics: only dispatch if we have
        // non-empty `data`, or an explicit `id:` / `event:` for this event.
        let hasExplicitEmptyDataField = currentData.isEmpty && seenFields.contains("data")
        guard !currentData.isEmpty || hasExplicitEmptyDataField || currentEventId != nil || currentEventType != nil else {
            return []
        }

        let events = dispatchIfNeeded()
        seenFields.removeAll(keepingCapacity: true)
        return events
    }

    // MARK: - Internals

    private func normalizeLine(_ line: String) -> String {
        // `URLSession.AsyncBytes.lines` can strip `\n` but may leave `\r` from CRLF.
        var normalized = line
        if normalized.hasSuffix("\r") {
            normalized = String(normalized.dropLast())
        }
        // Some implementations allow an optional UTF-8 BOM at the start of a line.
        if normalized.hasPrefix("\u{FEFF}") {
            normalized = String(normalized.dropFirst())
        }
        return normalized
    }

    private func parseFieldValue(_ line: String) -> (field: String, value: String) {
        guard let colonIndex = line.firstIndex(of: ":") else {
            // No colon: whole line is the field name, value is empty.
            return (field: line, value: "")
        }

        let field = String(line[..<colonIndex])
        var valueStart = line.index(after: colonIndex)

        // If the value begins with a single leading space, discard it (SSE spec).
        if valueStart < line.endIndex, line[valueStart] == " " {
            valueStart = line.index(after: valueStart)
        }

        let value = String(line[valueStart...])
        return (field: field, value: value)
    }

    private mutating func dispatchIfNeeded() -> [ServerSentEvent] {
        let isDataField = currentData.isEmpty && seenFields.contains("data")
        let isRetryOnly =
            currentData.isEmpty && currentEventId == nil && currentEventType == nil
            && !isDataField

        defer {
            // Per spec, `event` and `data` buffers reset after dispatch.
            currentEventType = nil
            currentData = ""
            currentEventId = nil
            currentRetry = nil
        }

        guard !isRetryOnly else { return [] }

        let event = ServerSentEvent(
            id: currentEventId,
            event: currentEventType,
            data: currentData,
            retry: currentRetry
        )
        return [event]
    }
}
