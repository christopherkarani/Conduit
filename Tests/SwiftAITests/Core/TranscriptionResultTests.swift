// TranscriptionResultTests.swift
// SwiftAI

import XCTest
@testable import SwiftAI

/// Comprehensive tests for transcription types and functionality.
///
/// Tests cover:
/// - TranscriptionFormat enum and its raw values
/// - TranscriptionConfig initialization and presets
/// - TranscriptionWord timing calculations
/// - TranscriptionSegment structure and identifiable conformance
/// - TranscriptionResult metrics and conversions
/// - SRT/VTT subtitle format generation and timestamp formatting
final class TranscriptionResultTests: XCTestCase {

    // MARK: - 1. TranscriptionFormat Tests

    func testFormatAllCases() {
        // Verify all 4 format cases exist
        let allCases = TranscriptionFormat.allCases
        XCTAssertEqual(allCases.count, 4)
        XCTAssertTrue(allCases.contains(.text))
        XCTAssertTrue(allCases.contains(.detailed))
        XCTAssertTrue(allCases.contains(.srt))
        XCTAssertTrue(allCases.contains(.vtt))
    }

    func testFormatRawValues() {
        // Verify raw string values are correct
        XCTAssertEqual(TranscriptionFormat.text.rawValue, "text")
        XCTAssertEqual(TranscriptionFormat.detailed.rawValue, "detailed")
        XCTAssertEqual(TranscriptionFormat.srt.rawValue, "srt")
        XCTAssertEqual(TranscriptionFormat.vtt.rawValue, "vtt")
    }

    func testFormatCodableRoundTrip() throws {
        // Test encode/decode preserves value
        let format = TranscriptionFormat.detailed
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let encoded = try encoder.encode(format)
        let decoded = try decoder.decode(TranscriptionFormat.self, from: encoded)

        XCTAssertEqual(format, decoded)
    }

    // MARK: - 2. TranscriptionConfig Tests

    func testConfigDefaultValues() {
        // Verify default initialization values
        let config = TranscriptionConfig()

        XCTAssertNil(config.language)
        XCTAssertFalse(config.wordTimestamps)
        XCTAssertFalse(config.translate)
        XCTAssertEqual(config.format, .text)
        XCTAssertEqual(config.vadSensitivity, 0.5)
        XCTAssertNil(config.initialPrompt)
        XCTAssertEqual(config.temperature, 0.0)
    }

    func testConfigDefaultPreset() {
        // Verify .default preset values
        let config = TranscriptionConfig.default

        XCTAssertNil(config.language)
        XCTAssertFalse(config.wordTimestamps)
        XCTAssertFalse(config.translate)
        XCTAssertEqual(config.format, .text)
        XCTAssertEqual(config.vadSensitivity, 0.5)
        XCTAssertEqual(config.temperature, 0.0)
    }

    func testConfigDetailedPreset() {
        // Verify .detailed preset has word timestamps and detailed format
        let config = TranscriptionConfig.detailed

        XCTAssertTrue(config.wordTimestamps)
        XCTAssertEqual(config.format, .detailed)
    }

    func testConfigSubtitlesPreset() {
        // Verify .subtitles preset has word timestamps and SRT format
        let config = TranscriptionConfig.subtitles

        XCTAssertTrue(config.wordTimestamps)
        XCTAssertEqual(config.format, .srt)
    }

    func testConfigTranslatePreset() {
        // Verify .translateToEnglish preset has translate enabled
        let config = TranscriptionConfig.translateToEnglish

        XCTAssertTrue(config.translate)
    }

    func testConfigCodableRoundTrip() throws {
        // Test encode/decode preserves all values
        let config = TranscriptionConfig(
            language: "en",
            wordTimestamps: true,
            translate: false,
            format: .srt,
            vadSensitivity: 0.7,
            initialPrompt: "Test prompt",
            temperature: 0.5
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let encoded = try encoder.encode(config)
        let decoded = try decoder.decode(TranscriptionConfig.self, from: encoded)

        XCTAssertEqual(config, decoded)
        XCTAssertEqual(decoded.language, "en")
        XCTAssertTrue(decoded.wordTimestamps)
        XCTAssertFalse(decoded.translate)
        XCTAssertEqual(decoded.format, .srt)
        XCTAssertEqual(decoded.vadSensitivity, 0.7)
        XCTAssertEqual(decoded.initialPrompt, "Test prompt")
        XCTAssertEqual(decoded.temperature, 0.5)
    }

    // MARK: - 3. TranscriptionWord Tests

    func testWordInitialization() {
        // Verify all fields are set correctly
        let word = TranscriptionWord(
            word: "hello",
            startTime: 1.0,
            endTime: 1.5,
            confidence: 0.95
        )

        XCTAssertEqual(word.word, "hello")
        XCTAssertEqual(word.startTime, 1.0)
        XCTAssertEqual(word.endTime, 1.5)
        XCTAssertEqual(word.confidence, 0.95)
    }

    func testWordDurationComputed() {
        // Verify duration = endTime - startTime
        let word = TranscriptionWord(
            word: "test",
            startTime: 2.5,
            endTime: 3.7
        )

        XCTAssertEqual(word.duration, 1.2, accuracy: 0.001)
    }

    func testWordCodableRoundTrip() throws {
        // Test encode/decode preserves values
        let word = TranscriptionWord(
            word: "world",
            startTime: 5.0,
            endTime: 5.8,
            confidence: 0.88
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let encoded = try encoder.encode(word)
        let decoded = try decoder.decode(TranscriptionWord.self, from: encoded)

        XCTAssertEqual(word, decoded)
        XCTAssertEqual(decoded.word, "world")
        XCTAssertEqual(decoded.startTime, 5.0)
        XCTAssertEqual(decoded.endTime, 5.8)
        XCTAssertEqual(decoded.confidence, 0.88)
    }

    func testWordHashable() {
        // Verify words can be used in Set
        let word1 = TranscriptionWord(word: "hello", startTime: 1.0, endTime: 1.5)
        let word2 = TranscriptionWord(word: "hello", startTime: 1.0, endTime: 1.5)
        let word3 = TranscriptionWord(word: "world", startTime: 2.0, endTime: 2.5)

        var wordSet: Set<TranscriptionWord> = []
        wordSet.insert(word1)
        wordSet.insert(word2)
        wordSet.insert(word3)

        XCTAssertEqual(wordSet.count, 2) // word1 and word2 are duplicates
    }

    // MARK: - 4. TranscriptionSegment Tests

    func testSegmentInitialization() {
        // Verify all fields are set correctly
        let words = [
            TranscriptionWord(word: "hello", startTime: 0.0, endTime: 0.5),
            TranscriptionWord(word: "world", startTime: 0.5, endTime: 1.0)
        ]

        let segment = TranscriptionSegment(
            id: 1,
            startTime: 0.0,
            endTime: 1.0,
            text: "hello world",
            words: words,
            avgLogProb: -0.5,
            compressionRatio: 1.2,
            noSpeechProb: 0.01
        )

        XCTAssertEqual(segment.id, 1)
        XCTAssertEqual(segment.startTime, 0.0)
        XCTAssertEqual(segment.endTime, 1.0)
        XCTAssertEqual(segment.text, "hello world")
        XCTAssertEqual(segment.words?.count, 2)
        XCTAssertEqual(segment.avgLogProb, -0.5)
        XCTAssertEqual(segment.compressionRatio, 1.2)
        XCTAssertEqual(segment.noSpeechProb, 0.01)
    }

    func testSegmentDurationComputed() {
        // Verify duration = endTime - startTime
        let segment = TranscriptionSegment(
            id: 1,
            startTime: 10.5,
            endTime: 15.3,
            text: "Test segment"
        )

        XCTAssertEqual(segment.duration, 4.8, accuracy: 0.001)
    }

    func testSegmentIdentifiable() {
        // Verify id property works as Identifiable
        let segment1 = TranscriptionSegment(id: 1, startTime: 0.0, endTime: 1.0, text: "First")
        let segment2 = TranscriptionSegment(id: 2, startTime: 1.0, endTime: 2.0, text: "Second")

        XCTAssertEqual(segment1.id, 1)
        XCTAssertEqual(segment2.id, 2)
        XCTAssertNotEqual(segment1.id, segment2.id)
    }

    func testSegmentWithWords() {
        // Verify words array is properly stored
        let words = [
            TranscriptionWord(word: "test", startTime: 0.0, endTime: 0.5),
            TranscriptionWord(word: "words", startTime: 0.5, endTime: 1.0)
        ]

        let segment = TranscriptionSegment(
            id: 1,
            startTime: 0.0,
            endTime: 1.0,
            text: "test words",
            words: words
        )

        XCTAssertNotNil(segment.words)
        XCTAssertEqual(segment.words?.count, 2)
        XCTAssertEqual(segment.words?[0].word, "test")
        XCTAssertEqual(segment.words?[1].word, "words")
    }

    func testSegmentCodableRoundTrip() throws {
        // Test encode/decode preserves values
        let words = [
            TranscriptionWord(word: "hello", startTime: 0.0, endTime: 0.5)
        ]

        let segment = TranscriptionSegment(
            id: 1,
            startTime: 0.0,
            endTime: 1.0,
            text: "hello",
            words: words,
            avgLogProb: -0.3,
            compressionRatio: 1.1,
            noSpeechProb: 0.02
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let encoded = try encoder.encode(segment)
        let decoded = try decoder.decode(TranscriptionSegment.self, from: encoded)

        XCTAssertEqual(segment, decoded)
        XCTAssertEqual(decoded.id, 1)
        XCTAssertEqual(decoded.text, "hello")
        XCTAssertEqual(decoded.words?.count, 1)
    }

    // MARK: - 5. TranscriptionResult Tests

    func testResultInitialization() {
        // Verify all fields are set correctly
        let segments = [
            TranscriptionSegment(id: 1, startTime: 0.0, endTime: 1.0, text: "Hello"),
            TranscriptionSegment(id: 2, startTime: 1.0, endTime: 2.0, text: "world")
        ]

        let result = TranscriptionResult(
            text: "Hello world",
            segments: segments,
            language: "en",
            languageConfidence: 0.95,
            duration: 2.0,
            processingTime: 0.5
        )

        XCTAssertEqual(result.text, "Hello world")
        XCTAssertEqual(result.segments.count, 2)
        XCTAssertEqual(result.language, "en")
        XCTAssertEqual(result.languageConfidence, 0.95)
        XCTAssertEqual(result.duration, 2.0)
        XCTAssertEqual(result.processingTime, 0.5)
    }

    func testResultRealtimeFactor() {
        // Verify realtimeFactor = processingTime / duration
        let result = TranscriptionResult(
            text: "Test",
            segments: [],
            duration: 10.0,
            processingTime: 2.0
        )

        XCTAssertEqual(result.realtimeFactor, 0.2, accuracy: 0.001)
    }

    func testResultRealtimeFactorZeroDuration() {
        // Verify returns 0 when duration is 0
        let result = TranscriptionResult(
            text: "Test",
            segments: [],
            duration: 0.0,
            processingTime: 1.0
        )

        XCTAssertEqual(result.realtimeFactor, 0.0)
    }

    func testResultCodableRoundTrip() throws {
        // Test encode/decode preserves values
        let segments = [
            TranscriptionSegment(id: 1, startTime: 0.0, endTime: 1.0, text: "Test")
        ]

        let result = TranscriptionResult(
            text: "Test",
            segments: segments,
            language: "en",
            languageConfidence: 0.92,
            duration: 5.0,
            processingTime: 1.0
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let encoded = try encoder.encode(result)
        let decoded = try decoder.decode(TranscriptionResult.self, from: encoded)

        XCTAssertEqual(result, decoded)
        XCTAssertEqual(decoded.text, "Test")
        XCTAssertEqual(decoded.segments.count, 1)
        XCTAssertEqual(decoded.language, "en")
    }

    // MARK: - 6. SRT Format Tests

    func testToSRTBasic() {
        // Verify produces valid SRT format
        let segments = [
            TranscriptionSegment(id: 1, startTime: 0.0, endTime: 5.0, text: "Hello world")
        ]

        let result = TranscriptionResult(
            text: "Hello world",
            segments: segments,
            duration: 5.0,
            processingTime: 1.0
        )

        let srt = result.toSRT()

        XCTAssertTrue(srt.contains("1\n"))
        XCTAssertTrue(srt.contains(" --> "))
        XCTAssertTrue(srt.contains("Hello world"))
    }

    func testToSRTTimestampFormat() {
        // Verify uses comma separator (HH:MM:SS,mmm)
        let segments = [
            TranscriptionSegment(id: 1, startTime: 0.0, endTime: 1.5, text: "Test")
        ]

        let result = TranscriptionResult(
            text: "Test",
            segments: segments,
            duration: 1.5,
            processingTime: 0.5
        )

        let srt = result.toSRT()

        XCTAssertTrue(srt.contains("00:00:00,000"))
        XCTAssertTrue(srt.contains("00:00:01,500"))
        XCTAssertTrue(srt.contains(",")) // Comma separator for SRT
    }

    func testToSRTMultipleSegments() {
        // Verify multiple segments are formatted correctly
        let segments = [
            TranscriptionSegment(id: 1, startTime: 0.0, endTime: 2.0, text: "First segment"),
            TranscriptionSegment(id: 2, startTime: 2.0, endTime: 4.0, text: "Second segment"),
            TranscriptionSegment(id: 3, startTime: 4.0, endTime: 6.0, text: "Third segment")
        ]

        let result = TranscriptionResult(
            text: "First segment Second segment Third segment",
            segments: segments,
            duration: 6.0,
            processingTime: 1.0
        )

        let srt = result.toSRT()

        XCTAssertTrue(srt.contains("1\n"))
        XCTAssertTrue(srt.contains("2\n"))
        XCTAssertTrue(srt.contains("3\n"))
        XCTAssertTrue(srt.contains("First segment"))
        XCTAssertTrue(srt.contains("Second segment"))
        XCTAssertTrue(srt.contains("Third segment"))
    }

    func testToSRTEmptySegments() {
        // Verify empty array produces empty string
        let result = TranscriptionResult(
            text: "",
            segments: [],
            duration: 0.0,
            processingTime: 0.0
        )

        let srt = result.toSRT()

        XCTAssertTrue(srt.isEmpty)
    }

    func testToSRTTextTrimmed() {
        // Verify text content is preserved (whitespace handling)
        let segments = [
            TranscriptionSegment(id: 1, startTime: 0.0, endTime: 1.0, text: "  Hello  ")
        ]

        let result = TranscriptionResult(
            text: "  Hello  ",
            segments: segments,
            duration: 1.0,
            processingTime: 0.5
        )

        let srt = result.toSRT()

        // SRT should preserve the text as-is (formatting responsibility is on caller)
        XCTAssertTrue(srt.contains("  Hello  "))
    }

    // MARK: - 7. VTT Format Tests

    func testToVTTHeader() {
        // Verify starts with "WEBVTT\n\n"
        let segments = [
            TranscriptionSegment(id: 1, startTime: 0.0, endTime: 1.0, text: "Test")
        ]

        let result = TranscriptionResult(
            text: "Test",
            segments: segments,
            duration: 1.0,
            processingTime: 0.5
        )

        let vtt = result.toVTT()

        XCTAssertTrue(vtt.hasPrefix("WEBVTT\n\n"))
    }

    func testToVTTTimestampFormat() {
        // Verify uses period separator (HH:MM:SS.mmm)
        let segments = [
            TranscriptionSegment(id: 1, startTime: 0.0, endTime: 1.5, text: "Test")
        ]

        let result = TranscriptionResult(
            text: "Test",
            segments: segments,
            duration: 1.5,
            processingTime: 0.5
        )

        let vtt = result.toVTT()

        XCTAssertTrue(vtt.contains("00:00:00.000"))
        XCTAssertTrue(vtt.contains("00:00:01.500"))
        XCTAssertTrue(vtt.contains(".")) // Period separator for VTT
    }

    func testToVTTMultipleSegments() {
        // Verify multiple segments are formatted correctly
        let segments = [
            TranscriptionSegment(id: 1, startTime: 0.0, endTime: 2.0, text: "First segment"),
            TranscriptionSegment(id: 2, startTime: 2.0, endTime: 4.0, text: "Second segment")
        ]

        let result = TranscriptionResult(
            text: "First segment Second segment",
            segments: segments,
            duration: 4.0,
            processingTime: 1.0
        )

        let vtt = result.toVTT()

        XCTAssertTrue(vtt.contains("WEBVTT"))
        XCTAssertTrue(vtt.contains("1\n"))
        XCTAssertTrue(vtt.contains("2\n"))
        XCTAssertTrue(vtt.contains("First segment"))
        XCTAssertTrue(vtt.contains("Second segment"))
    }

    func testToVTTEmptySegments() {
        // Verify empty produces just header
        let result = TranscriptionResult(
            text: "",
            segments: [],
            duration: 0.0,
            processingTime: 0.0
        )

        let vtt = result.toVTT()

        XCTAssertEqual(vtt, "WEBVTT\n\n")
    }

    // MARK: - 8. Timestamp Formatting Tests

    func testTimestampHours() {
        // Verify hours display correctly
        let segments = [
            TranscriptionSegment(id: 1, startTime: 3661.5, endTime: 3662.5, text: "Test") // 1:01:01.500
        ]

        let result = TranscriptionResult(
            text: "Test",
            segments: segments,
            duration: 3662.5,
            processingTime: 1.0
        )

        let srt = result.toSRT()

        XCTAssertTrue(srt.contains("01:01:01"))
    }

    func testTimestampMinutes() {
        // Verify minutes display correctly
        let segments = [
            TranscriptionSegment(id: 1, startTime: 125.0, endTime: 126.0, text: "Test") // 0:02:05.000
        ]

        let result = TranscriptionResult(
            text: "Test",
            segments: segments,
            duration: 126.0,
            processingTime: 1.0
        )

        let srt = result.toSRT()

        XCTAssertTrue(srt.contains("00:02:05"))
    }

    func testTimestampSeconds() {
        // Verify seconds display correctly
        let segments = [
            TranscriptionSegment(id: 1, startTime: 45.0, endTime: 46.0, text: "Test") // 0:00:45.000
        ]

        let result = TranscriptionResult(
            text: "Test",
            segments: segments,
            duration: 46.0,
            processingTime: 1.0
        )

        let srt = result.toSRT()

        XCTAssertTrue(srt.contains("00:00:45"))
    }

    func testTimestampMilliseconds() {
        // Verify milliseconds display correctly
        let segments = [
            TranscriptionSegment(id: 1, startTime: 1.234, endTime: 2.567, text: "Test")
        ]

        let result = TranscriptionResult(
            text: "Test",
            segments: segments,
            duration: 2.567,
            processingTime: 1.0
        )

        let srt = result.toSRT()

        XCTAssertTrue(srt.contains(",234"))
        XCTAssertTrue(srt.contains(",567"))
    }

    func testTimestampZeroPadding() {
        // Verify all components are zero-padded (hours, minutes, seconds, milliseconds)
        let segments = [
            TranscriptionSegment(id: 1, startTime: 3605.007, endTime: 7265.089, text: "Test")
        ]

        let result = TranscriptionResult(
            text: "Test",
            segments: segments,
            duration: 7265.089,
            processingTime: 1.0
        )

        let srt = result.toSRT()

        // Check zero-padding across all timestamp components:
        // 3605.007 seconds = 1 hour, 0 minutes, 5 seconds, 7 milliseconds = 01:00:05,007
        // 7265.089 seconds = 2 hours, 1 minute, 5 seconds, 89 milliseconds = 02:01:05,089
        XCTAssertTrue(srt.contains("01:00:05,00"))  // Hours and seconds padded
        XCTAssertTrue(srt.contains("02:01:05,08"))  // All components have leading zeros
    }
}
