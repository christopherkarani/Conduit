// LineBufferCTests.swift
// ConduitCoreTests

import Foundation
import Testing
import ConduitCore

@Suite("Line Buffer C Tests")
struct LineBufferCTests {

    // MARK: - Basic Line Extraction

    @Test("Extract single line ending with LF")
    func singleLineLF() {
        let buf = conduit_line_buffer_create(256)!
        defer { conduit_line_buffer_destroy(buf) }

        let data: [UInt8] = Array("hello\n".utf8)
        conduit_line_buffer_append(buf, data, data.count)

        var line = [CChar](repeating: 0, count: 256)
        var lineLen: Int = 0
        let result = conduit_line_buffer_next_line(buf, &line, 256, &lineLen)

        #expect(result == 1)
        #expect(lineLen == 5)
        #expect(String(cString: line) == "hello")
    }

    @Test("Extract single line ending with CR")
    func singleLineCR() {
        let buf = conduit_line_buffer_create(256)!
        defer { conduit_line_buffer_destroy(buf) }

        let data: [UInt8] = Array("hello\r".utf8)
        conduit_line_buffer_append(buf, data, data.count)

        var line = [CChar](repeating: 0, count: 256)
        var lineLen: Int = 0
        let result = conduit_line_buffer_next_line(buf, &line, 256, &lineLen)

        #expect(result == 1)
        #expect(String(cString: line) == "hello")
    }

    @Test("Extract single line ending with CRLF")
    func singleLineCRLF() {
        let buf = conduit_line_buffer_create(256)!
        defer { conduit_line_buffer_destroy(buf) }

        let data: [UInt8] = Array("hello\r\n".utf8)
        conduit_line_buffer_append(buf, data, data.count)

        var line = [CChar](repeating: 0, count: 256)
        var lineLen: Int = 0
        let result = conduit_line_buffer_next_line(buf, &line, 256, &lineLen)

        #expect(result == 1)
        #expect(String(cString: line) == "hello")
    }

    // MARK: - Multiple Lines

    @Test("Extract multiple lines")
    func multipleLines() {
        let buf = conduit_line_buffer_create(256)!
        defer { conduit_line_buffer_destroy(buf) }

        let data: [UInt8] = Array("line1\nline2\nline3\n".utf8)
        conduit_line_buffer_append(buf, data, data.count)

        var line = [CChar](repeating: 0, count: 256)
        var lineLen: Int = 0

        #expect(conduit_line_buffer_next_line(buf, &line, 256, &lineLen) == 1)
        #expect(String(cString: line) == "line1")

        #expect(conduit_line_buffer_next_line(buf, &line, 256, &lineLen) == 1)
        #expect(String(cString: line) == "line2")

        #expect(conduit_line_buffer_next_line(buf, &line, 256, &lineLen) == 1)
        #expect(String(cString: line) == "line3")

        // No more lines
        #expect(conduit_line_buffer_next_line(buf, &line, 256, &lineLen) == 0)
    }

    // MARK: - Partial Data

    @Test("No line returned for incomplete data")
    func incompleteData() {
        let buf = conduit_line_buffer_create(256)!
        defer { conduit_line_buffer_destroy(buf) }

        let data: [UInt8] = Array("partial".utf8)
        conduit_line_buffer_append(buf, data, data.count)

        var line = [CChar](repeating: 0, count: 256)
        var lineLen: Int = 0

        #expect(conduit_line_buffer_next_line(buf, &line, 256, &lineLen) == 0)
    }

    @Test("Incremental append completes a line")
    func incrementalAppend() {
        let buf = conduit_line_buffer_create(256)!
        defer { conduit_line_buffer_destroy(buf) }

        var line = [CChar](repeating: 0, count: 256)
        var lineLen: Int = 0

        let part1: [UInt8] = Array("hel".utf8)
        conduit_line_buffer_append(buf, part1, part1.count)
        #expect(conduit_line_buffer_next_line(buf, &line, 256, &lineLen) == 0)

        let part2: [UInt8] = Array("lo\n".utf8)
        conduit_line_buffer_append(buf, part2, part2.count)
        #expect(conduit_line_buffer_next_line(buf, &line, 256, &lineLen) == 1)
        #expect(String(cString: line) == "hello")
    }

    // MARK: - Empty Lines

    @Test("Empty line between two lines")
    func emptyLineBetween() {
        let buf = conduit_line_buffer_create(256)!
        defer { conduit_line_buffer_destroy(buf) }

        let data: [UInt8] = Array("a\n\nb\n".utf8)
        conduit_line_buffer_append(buf, data, data.count)

        var line = [CChar](repeating: 0, count: 256)
        var lineLen: Int = 0

        #expect(conduit_line_buffer_next_line(buf, &line, 256, &lineLen) == 1)
        #expect(String(cString: line) == "a")

        #expect(conduit_line_buffer_next_line(buf, &line, 256, &lineLen) == 1)
        #expect(lineLen == 0) // Empty line
        #expect(String(cString: line) == "")

        #expect(conduit_line_buffer_next_line(buf, &line, 256, &lineLen) == 1)
        #expect(String(cString: line) == "b")
    }

    // MARK: - Drain

    @Test("Drain returns remaining bytes")
    func drainRemainder() {
        let buf = conduit_line_buffer_create(256)!
        defer { conduit_line_buffer_destroy(buf) }

        let data: [UInt8] = Array("line1\nremainder".utf8)
        conduit_line_buffer_append(buf, data, data.count)

        var line = [CChar](repeating: 0, count: 256)
        var lineLen: Int = 0

        #expect(conduit_line_buffer_next_line(buf, &line, 256, &lineLen) == 1)
        #expect(String(cString: line) == "line1")

        // Drain the remainder
        var remainder = [CChar](repeating: 0, count: 256)
        let drainLen = conduit_line_buffer_drain(buf, &remainder, 256)
        #expect(drainLen == 9) // "remainder" = 9 bytes
    }

    // MARK: - Pending Count

    @Test("Pending count tracks buffered bytes")
    func pendingCount() {
        let buf = conduit_line_buffer_create(256)!
        defer { conduit_line_buffer_destroy(buf) }

        #expect(conduit_line_buffer_pending(buf) == 0)

        let data: [UInt8] = Array("hello\n".utf8)
        conduit_line_buffer_append(buf, data, data.count)
        #expect(conduit_line_buffer_pending(buf) == 6)

        var line = [CChar](repeating: 0, count: 256)
        var lineLen: Int = 0
        conduit_line_buffer_next_line(buf, &line, 256, &lineLen)
        #expect(conduit_line_buffer_pending(buf) == 0)
    }

    @Test("next_line returns -1 (not 0) when line exceeds output buffer capacity")
    func nextLineOversizedLine() {
        let buf = conduit_line_buffer_create(1024)!
        defer { conduit_line_buffer_destroy(buf) }

        // Append a line that is longer than the output buffer we'll provide
        let longLine: [UInt8] = Array("ABCDEFGHIJ\n".utf8) // 10 chars + newline
        conduit_line_buffer_append(buf, longLine, longLine.count)

        // Provide a 4-byte output buffer — too small for the 10-char line
        var line = [CChar](repeating: 0, count: 4)
        var lineLen: Int = 0
        let result = conduit_line_buffer_next_line(buf, &line, 4, &lineLen)

        // Must return -1 (not 0) so callers can distinguish "no line" from "line too large"
        #expect(result == -1)
        // The oversized line must remain unconsumed so callers can retry with a larger buffer
        #expect(conduit_line_buffer_pending(buf) == longLine.count)
    }

    // MARK: - SSE Simulation

    @Test("Simulated SSE stream with mixed delimiters")
    func sseSimulation() {
        let buf = conduit_line_buffer_create(1024)!
        defer { conduit_line_buffer_destroy(buf) }

        // Simulate an SSE stream chunk
        let chunk: [UInt8] = Array("data: hello\r\n\r\ndata: world\r\n\r\n".utf8)
        conduit_line_buffer_append(buf, chunk, chunk.count)

        var line = [CChar](repeating: 0, count: 256)
        var lineLen: Int = 0
        var lines: [String] = []

        while conduit_line_buffer_next_line(buf, &line, 256, &lineLen) == 1 {
            lines.append(String(cString: line))
        }

        #expect(lines == ["data: hello", "", "data: world", ""])
    }
}
