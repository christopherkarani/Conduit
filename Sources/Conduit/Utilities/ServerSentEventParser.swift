// ServerSentEventParser.swift
// Conduit
//
// Minimal Server-Sent Events (SSE) parsing utilities. Designed to match the
// behavior expected by common EventSource implementations.

import Foundation

/// A parsed Server-Sent Event.
internal struct ServerSentEvent: Sendable, Equatable {
    /// The last event ID (may persist across events per SSE spec).
    var id: String?

    /// The event type. If absent, the default is `"message"`.
    var event: String

    /// The event data payload (may contain newlines if multiple `data:` lines were present).
    var data: String
}

/// Incremental parser for Server-Sent Events (SSE).
///
/// Feed the parser newline-delimited lines (without the trailing `\n`). A blank line
/// terminates the current event and causes it to be emitted.
internal struct ServerSentEventParser: Sendable {
    private var currentEventType: String?
    private var dataLines: [String] = []
    private var lastEventId: String?

    init() {}

    /// Ingests one SSE line (without its trailing newline) and returns any complete events.
    mutating func ingestLine(_ line: String) -> [ServerSentEvent] {
        let normalizedLine = normalizeLine(line)

        // Empty line dispatches the event.
        if normalizedLine.isEmpty {
            return dispatchIfNeeded()
        }

        // Comments begin with ":" and are ignored.
        if normalizedLine.hasPrefix(":") {
            return []
        }

        let (field, value) = parseFieldValue(normalizedLine)

        switch field {
        case "event":
            currentEventType = value.isEmpty ? nil : value
        case "data":
            dataLines.append(value)
        case "id":
            // The SSE spec ignores IDs containing null characters.
            if !value.contains("\u{0000}") {
                lastEventId = value
            }
        case "retry":
            // Ignored: reconnection timing is handled by the networking layer.
            break
        default:
            // Ignore unknown fields.
            break
        }

        return []
    }

    /// Call at end-of-stream to flush any pending event.
    mutating func finish() -> [ServerSentEvent] {
        dispatchIfNeeded()
    }

    // MARK: - Internals

    private func normalizeLine(_ line: String) -> String {
        // `URLSession.AsyncBytes.lines` can strip `\n` but may leave `\r` from CRLF.
        if line.hasSuffix("\r") {
            return String(line.dropLast())
        }
        return line
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
        defer {
            // Per spec, `event` and `data` buffers reset after dispatch.
            currentEventType = nil
            dataLines.removeAll(keepingCapacity: true)
        }

        guard !dataLines.isEmpty else { return [] }

        let data = dataLines.joined(separator: "\n")
        let event = currentEventType ?? "message"
        return [ServerSentEvent(id: lastEventId, event: event, data: data)]
    }
}

