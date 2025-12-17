// TranscriptionResult.swift
// SwiftAI

import Foundation

// MARK: - TranscriptionFormat

/// Output format options for transcription results.
///
/// Transcription formats control how the output is structured and presented,
/// from simple plain text to detailed timestamped segments or subtitle formats.
///
/// ## Usage
/// ```swift
/// let config = TranscriptionConfig.default.format(.detailed)
/// let result = try await provider.transcribe(audioData, config: config)
/// ```
///
/// ## Formats
/// - `text`: Plain text without timing information
/// - `detailed`: JSON-compatible format with segments and word timestamps
/// - `srt`: SubRip subtitle format (.srt files)
/// - `vtt`: WebVTT subtitle format (.vtt files)
///
/// ## Protocol Conformances
/// - `Sendable`: Thread-safe across concurrency boundaries
/// - `Hashable`: Can be used in sets and as dictionary keys
/// - `Codable`: Full JSON encoding/decoding support
/// - `CaseIterable`: Can enumerate all format options
public enum TranscriptionFormat: String, Sendable, Hashable, Codable, CaseIterable {
    /// Plain text output without timing information.
    case text

    /// Detailed JSON format with timestamps and segments.
    case detailed

    /// SRT (SubRip) subtitle format with timestamps.
    case srt

    /// WebVTT subtitle format with timestamps.
    case vtt
}

// MARK: - TranscriptionConfig

/// Configuration options for audio transcription.
///
/// Controls language detection, timing precision, translation, and output format.
///
/// ## Usage
/// ```swift
/// // Use presets
/// let config = TranscriptionConfig.detailed
///
/// // Custom configuration
/// let config = TranscriptionConfig(
///     language: "en",
///     wordTimestamps: true,
///     translate: false,
///     format: .srt
/// )
/// ```
///
/// ## Presets
/// - `.default`: Standard transcription with auto language detection
/// - `.detailed`: Full word timestamps and detailed output
/// - `.subtitles`: SRT subtitle format with word timing
/// - `.translateToEnglish`: Translate any audio to English
///
/// ## Protocol Conformances
/// - `Sendable`: Thread-safe across concurrency boundaries
/// - `Hashable`: Can be used in sets and as dictionary keys
/// - `Codable`: Full JSON encoding/decoding support
public struct TranscriptionConfig: Sendable, Hashable, Codable {

    /// Language code (ISO 639-1). If nil, language is auto-detected.
    public var language: String?

    /// Whether to include word-level timestamps in the output.
    public var wordTimestamps: Bool

    /// Whether to translate the audio to English.
    public var translate: Bool

    /// Output format for the transcription result.
    public var format: TranscriptionFormat

    /// Voice Activity Detection (VAD) sensitivity (0.0 to 1.0).
    /// Higher values are more aggressive at detecting speech.
    public var vadSensitivity: Float

    /// Initial text prompt to guide the transcription style/context.
    public var initialPrompt: String?

    /// Temperature for sampling (0.0 = deterministic, 1.0 = creative).
    /// Lower temperatures produce more consistent results.
    public var temperature: Float

    /// Creates a transcription configuration.
    ///
    /// - Parameters:
    ///   - language: Language code (nil for auto-detection).
    ///   - wordTimestamps: Whether to include word-level timestamps.
    ///   - translate: Whether to translate to English.
    ///   - format: Output format.
    ///   - vadSensitivity: Voice activity detection sensitivity (0.0-1.0).
    ///   - initialPrompt: Optional text prompt for context.
    ///   - temperature: Sampling temperature (0.0-1.0).
    public init(
        language: String? = nil,
        wordTimestamps: Bool = false,
        translate: Bool = false,
        format: TranscriptionFormat = .text,
        vadSensitivity: Float = 0.5,
        initialPrompt: String? = nil,
        temperature: Float = 0.0
    ) {
        self.language = language
        self.wordTimestamps = wordTimestamps
        self.translate = translate
        self.format = format
        self.vadSensitivity = vadSensitivity
        self.initialPrompt = initialPrompt
        self.temperature = temperature
    }

    // MARK: - Presets

    /// Default configuration with auto language detection and text output.
    public static let `default` = TranscriptionConfig()

    /// Configuration for detailed output with word timestamps.
    ///
    /// ## Usage
    /// ```swift
    /// let config = TranscriptionConfig.detailed
    /// let result = try await provider.transcribe(audioData, config: config)
    /// print(result.segments.count) // Full segment breakdown
    /// ```
    public static let detailed = TranscriptionConfig(
        wordTimestamps: true,
        format: .detailed
    )

    /// Configuration optimized for subtitle generation.
    ///
    /// Produces SRT format with word-level timing information.
    ///
    /// ## Usage
    /// ```swift
    /// let config = TranscriptionConfig.subtitles
    /// let result = try await provider.transcribe(audioData, config: config)
    /// let srt = result.toSRT()
    /// try srt.write(to: url, atomically: true, encoding: .utf8)
    /// ```
    public static let subtitles = TranscriptionConfig(
        wordTimestamps: true,
        format: .srt
    )

    /// Configuration for translating audio to English.
    ///
    /// Automatically detects the source language and translates to English.
    ///
    /// ## Usage
    /// ```swift
    /// let config = TranscriptionConfig.translateToEnglish
    /// let result = try await provider.transcribe(frenchAudio, config: config)
    /// print(result.text) // English translation
    /// ```
    public static let translateToEnglish = TranscriptionConfig(
        translate: true
    )
}

// MARK: - TranscriptionWord

/// A single word in a transcription with timing information.
///
/// Represents word-level timing data when `wordTimestamps` is enabled.
///
/// ## Usage
/// ```swift
/// for segment in result.segments {
///     if let words = segment.words {
///         for word in words {
///             print("\(word.word) at \(word.startTime)s")
///         }
///     }
/// }
/// ```
///
/// ## Protocol Conformances
/// - `Sendable`: Thread-safe across concurrency boundaries
/// - `Hashable`: Can be used in sets and as dictionary keys
/// - `Codable`: Full JSON encoding/decoding support
public struct TranscriptionWord: Sendable, Hashable, Codable {

    /// The transcribed word text.
    public let word: String

    /// Start time in seconds from the beginning of the audio.
    public let startTime: TimeInterval

    /// End time in seconds from the beginning of the audio.
    public let endTime: TimeInterval

    /// Confidence score for this word (0.0 to 1.0), if available.
    public let confidence: Float?

    /// Duration of this word in seconds.
    ///
    /// Computed as `endTime - startTime`.
    ///
    /// ## Usage
    /// ```swift
    /// let word = TranscriptionWord(word: "hello", startTime: 1.0, endTime: 1.5)
    /// print(word.duration) // 0.5
    /// ```
    public var duration: TimeInterval {
        endTime - startTime
    }

    /// Creates a transcription word.
    ///
    /// - Parameters:
    ///   - word: The transcribed word text.
    ///   - startTime: Start time in seconds.
    ///   - endTime: End time in seconds.
    ///   - confidence: Optional confidence score (0.0-1.0).
    public init(
        word: String,
        startTime: TimeInterval,
        endTime: TimeInterval,
        confidence: Float? = nil
    ) {
        self.word = word
        self.startTime = startTime
        self.endTime = endTime
        self.confidence = confidence
    }
}

// MARK: - TranscriptionSegment

/// A segment of transcribed audio with timing and optional word-level detail.
///
/// Segments represent logical chunks of speech, typically sentences or phrases,
/// with timing information and quality metrics.
///
/// ## Usage
/// ```swift
/// for segment in result.segments {
///     print("[\(segment.startTime)s - \(segment.endTime)s]: \(segment.text)")
///
///     if let words = segment.words {
///         for word in words {
///             print("  - \(word.word) (\(word.duration)s)")
///         }
///     }
/// }
/// ```
///
/// ## Protocol Conformances
/// - `Identifiable`: Each segment has a unique integer ID
/// - `Sendable`: Thread-safe across concurrency boundaries
/// - `Hashable`: Can be used in sets and as dictionary keys
/// - `Codable`: Full JSON encoding/decoding support
public struct TranscriptionSegment: Sendable, Hashable, Codable, Identifiable {

    /// Unique identifier for this segment (sequential index).
    public let id: Int

    /// Start time in seconds from the beginning of the audio.
    public let startTime: TimeInterval

    /// End time in seconds from the beginning of the audio.
    public let endTime: TimeInterval

    /// The transcribed text for this segment.
    public let text: String

    /// Word-level breakdown with timestamps (if `wordTimestamps` was enabled).
    public let words: [TranscriptionWord]?

    /// Average log probability of tokens in this segment.
    /// Higher values indicate more confident predictions.
    public let avgLogProb: Float?

    /// Compression ratio of this segment.
    /// Values significantly above 1.0 may indicate repetition issues.
    public let compressionRatio: Float?

    /// Probability that this segment contains no speech (0.0 to 1.0).
    /// Higher values suggest the segment may be silence or noise.
    public let noSpeechProb: Float?

    /// Duration of this segment in seconds.
    ///
    /// Computed as `endTime - startTime`.
    ///
    /// ## Usage
    /// ```swift
    /// let segment = result.segments[0]
    /// print("Segment duration: \(segment.duration)s")
    /// ```
    public var duration: TimeInterval {
        endTime - startTime
    }

    /// Creates a transcription segment.
    ///
    /// - Parameters:
    ///   - id: Unique sequential identifier.
    ///   - startTime: Start time in seconds.
    ///   - endTime: End time in seconds.
    ///   - text: The transcribed text.
    ///   - words: Optional word-level breakdown.
    ///   - avgLogProb: Average log probability of tokens.
    ///   - compressionRatio: Compression ratio.
    ///   - noSpeechProb: Probability of no speech (0.0-1.0).
    public init(
        id: Int,
        startTime: TimeInterval,
        endTime: TimeInterval,
        text: String,
        words: [TranscriptionWord]? = nil,
        avgLogProb: Float? = nil,
        compressionRatio: Float? = nil,
        noSpeechProb: Float? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
        self.words = words
        self.avgLogProb = avgLogProb
        self.compressionRatio = compressionRatio
        self.noSpeechProb = noSpeechProb
    }
}

// MARK: - TranscriptionResult

/// The result of transcribing audio to text.
///
/// Contains the full transcribed text, timing information, segment breakdown,
/// and performance metrics. Can export to various subtitle formats.
///
/// ## Usage
/// ```swift
/// let result = try await provider.transcribe(audioData, config: .detailed)
///
/// // Access full text
/// print(result.text)
///
/// // Iterate segments
/// for segment in result.segments {
///     print("[\(segment.startTime)s]: \(segment.text)")
/// }
///
/// // Export as SRT
/// let srt = result.toSRT()
/// try srt.write(to: url, atomically: true, encoding: .utf8)
///
/// // Check performance
/// print("Realtime factor: \(result.realtimeFactor)x")
/// ```
///
/// ## Export Formats
/// - `toSRT()`: SubRip subtitle format
/// - `toVTT()`: WebVTT subtitle format
///
/// ## Protocol Conformances
/// - `Sendable`: Thread-safe across concurrency boundaries
/// - `Hashable`: Can be used in sets and as dictionary keys
/// - `Codable`: Full JSON encoding/decoding support
public struct TranscriptionResult: Sendable, Hashable, Codable {

    /// The complete transcribed text (all segments concatenated).
    public let text: String

    /// Breakdown of transcription into timed segments.
    public let segments: [TranscriptionSegment]

    /// Detected or specified language code (ISO 639-1).
    public let language: String?

    /// Confidence score for language detection (0.0 to 1.0).
    public let languageConfidence: Float?

    /// Total duration of the audio in seconds.
    public let duration: TimeInterval

    /// Time taken to process the audio in seconds.
    public let processingTime: TimeInterval

    /// Realtime factor: how fast the processing was compared to audio duration.
    ///
    /// Computed as `processingTime / duration`. Values less than 1.0 indicate
    /// faster-than-realtime processing.
    ///
    /// ## Usage
    /// ```swift
    /// let result = try await provider.transcribe(audioData)
    /// if result.realtimeFactor < 1.0 {
    ///     print("Faster than realtime: \(result.realtimeFactor)x")
    /// }
    /// ```
    ///
    /// - Returns: Processing speed ratio, or 0.0 if duration is zero.
    public var realtimeFactor: Double {
        guard duration > 0 else { return 0.0 }
        return processingTime / duration
    }

    /// Creates a transcription result.
    ///
    /// - Parameters:
    ///   - text: The complete transcribed text.
    ///   - segments: Timed segment breakdown.
    ///   - language: Detected or specified language code.
    ///   - languageConfidence: Confidence in language detection (0.0-1.0).
    ///   - duration: Total audio duration in seconds.
    ///   - processingTime: Time taken to transcribe in seconds.
    public init(
        text: String,
        segments: [TranscriptionSegment],
        language: String? = nil,
        languageConfidence: Float? = nil,
        duration: TimeInterval,
        processingTime: TimeInterval
    ) {
        self.text = text
        self.segments = segments
        self.language = language
        self.languageConfidence = languageConfidence
        self.duration = duration
        self.processingTime = processingTime
    }

    // MARK: - Export Methods

    /// Exports the transcription as SRT (SubRip) subtitle format.
    ///
    /// SRT format uses COMMA as millisecond separator: `HH:MM:SS,mmm`
    ///
    /// ## Usage
    /// ```swift
    /// let result = try await provider.transcribe(audioData, config: .subtitles)
    /// let srt = result.toSRT()
    /// try srt.write(to: fileURL, atomically: true, encoding: .utf8)
    /// ```
    ///
    /// ## Example Output
    /// ```
    /// 1
    /// 00:00:00,000 --> 00:00:05,500
    /// Hello world
    ///
    /// 2
    /// 00:00:05,500 --> 00:00:10,000
    /// Next segment
    /// ```
    ///
    /// - Returns: SRT-formatted subtitle string.
    public func toSRT() -> String {
        var output = ""

        for (index, segment) in segments.enumerated() {
            let segmentNumber = index + 1
            let startTimestamp = formatTimestamp(segment.startTime, srt: true)
            let endTimestamp = formatTimestamp(segment.endTime, srt: true)

            output += "\(segmentNumber)\n"
            output += "\(startTimestamp) --> \(endTimestamp)\n"
            output += "\(segment.text)\n\n"
        }

        return output
    }

    /// Exports the transcription as WebVTT subtitle format.
    ///
    /// VTT format starts with "WEBVTT" header and uses PERIOD as millisecond
    /// separator: `HH:MM:SS.mmm`
    ///
    /// ## Usage
    /// ```swift
    /// let result = try await provider.transcribe(audioData, config: .subtitles)
    /// let vtt = result.toVTT()
    /// try vtt.write(to: fileURL, atomically: true, encoding: .utf8)
    /// ```
    ///
    /// ## Example Output
    /// ```
    /// WEBVTT
    ///
    /// 1
    /// 00:00:00.000 --> 00:00:05.500
    /// Hello world
    ///
    /// 2
    /// 00:00:05.500 --> 00:00:10.000
    /// Next segment
    /// ```
    ///
    /// - Returns: WebVTT-formatted subtitle string.
    public func toVTT() -> String {
        var output = "WEBVTT\n\n"

        for (index, segment) in segments.enumerated() {
            let segmentNumber = index + 1
            let startTimestamp = formatTimestamp(segment.startTime, srt: false)
            let endTimestamp = formatTimestamp(segment.endTime, srt: false)

            output += "\(segmentNumber)\n"
            output += "\(startTimestamp) --> \(endTimestamp)\n"
            output += "\(segment.text)\n\n"
        }

        return output
    }

    // MARK: - Private Helpers

    /// Formats a time interval as a timestamp string.
    ///
    /// - Parameters:
    ///   - time: The time interval in seconds.
    ///   - srt: If true, uses comma separator (SRT). If false, uses period (VTT).
    ///
    /// - Returns: Formatted timestamp string (e.g., "00:01:23,456" or "00:01:23.456").
    private func formatTimestamp(_ time: TimeInterval, srt: Bool) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)

        let separator = srt ? "," : "."
        return String(format: "%02d:%02d:%02d%@%03d", hours, minutes, seconds, separator, milliseconds)
    }
}
