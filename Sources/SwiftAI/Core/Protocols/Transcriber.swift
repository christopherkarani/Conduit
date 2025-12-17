// Transcriber.swift
// SwiftAI

import Foundation

// MARK: - Transcriber Protocol

/// A type that can transcribe audio to text.
///
/// The `Transcriber` protocol defines a unified interface for audio transcription
/// across different providers. Conforming types can process audio files or raw
/// audio data and convert them to text, with optional real-time streaming support.
///
/// ## Supported Audio Formats
///
/// Implementations should support common audio formats including:
/// - WAV (Waveform Audio File Format)
/// - MP3 (MPEG Audio Layer 3)
/// - M4A (MPEG-4 Audio)
/// - FLAC (Free Lossless Audio Codec)
///
/// The exact supported formats may vary by provider. Consult provider-specific
/// documentation for details.
///
/// ## Usage
///
/// ### Basic Transcription
/// ```swift
/// let provider = MLXProvider()
/// let result = try await provider.transcribe(
///     audioURL: fileURL,
///     model: .whisper,
///     config: .default
/// )
/// print(result.text)
/// ```
///
/// ### Streaming Transcription
/// ```swift
/// let stream = provider.streamTranscription(
///     audioURL: liveAudioURL,
///     model: .whisper,
///     config: .default
/// )
///
/// for try await segment in stream {
///     print("[\(segment.startTime)s]: \(segment.text)")
/// }
/// ```
///
/// ## Streaming Use Cases
///
/// Streaming transcription is particularly useful for:
/// - **Live Audio**: Real-time transcription of ongoing audio streams
/// - **Long Recordings**: Processing long audio files with incremental results
/// - **Interactive UI**: Displaying transcription progress as it becomes available
/// - **Early Feedback**: Starting to process results before full transcription completes
///
/// - Note: All methods are `async` and may be long-running operations.
///   Consider using `Task` for cancellation support in UI contexts.
///
/// - SeeAlso: `TranscriptionConfig` for configuration options
/// - SeeAlso: `TranscriptionResult` for output format
/// - SeeAlso: `TranscriptionSegment` for streaming output format
public protocol Transcriber: Sendable {

    // MARK: - Associated Types

    /// The model identifier type this transcriber accepts.
    ///
    /// Different providers use different model identification schemes.
    /// For example, MLX might use local model paths while HuggingFace
    /// uses repository identifiers.
    associatedtype ModelID: ModelIdentifying

    // MARK: - File-Based Transcription

    /// Transcribes audio from a file URL.
    ///
    /// Reads audio data from the specified file and transcribes it to text.
    /// The file must be in a supported audio format (WAV, MP3, M4A, FLAC).
    ///
    /// - Parameters:
    ///   - url: The URL of the audio file to transcribe. Must be a valid
    ///          file URL pointing to a readable audio file.
    ///   - model: The transcription model to use. Different models may
    ///            support different languages and have varying accuracy levels.
    ///   - config: Transcription options including language hints, timestamp
    ///             preferences, and output formatting.
    /// - Returns: The transcription result containing the full text and
    ///            optional segment-level timing information.
    /// - Throws: `AIError` if transcription fails due to invalid file format,
    ///           model loading errors, or processing failures.
    func transcribe(
        audioURL url: URL,
        model: ModelID,
        config: TranscriptionConfig
    ) async throws -> TranscriptionResult

    // MARK: - Data-Based Transcription

    /// Transcribes audio from raw data.
    ///
    /// Processes audio data directly without requiring file system access.
    /// Useful for transcribing audio from network streams, in-memory
    /// recordings, or embedded resources.
    ///
    /// - Parameters:
    ///   - data: The audio data in a supported format (WAV, MP3, M4A, FLAC).
    ///   - model: The transcription model to use.
    ///   - config: Transcription options.
    /// - Returns: The transcription result.
    /// - Throws: `AIError` if transcription fails.
    func transcribe(
        audioData data: Data,
        model: ModelID,
        config: TranscriptionConfig
    ) async throws -> TranscriptionResult

    // MARK: - Streaming Transcription

    /// Streams transcription results as they become available.
    ///
    /// Provides incremental transcription results as segments of the audio
    /// are processed. This is particularly useful for:
    /// - Live audio transcription where results are needed in real-time
    /// - Long audio files where early results improve user experience
    /// - Interactive applications requiring progressive feedback
    ///
    /// Each segment includes timing information (start/end times) along with
    /// the transcribed text for that portion of audio.
    ///
    /// ## Example
    /// ```swift
    /// let stream = provider.streamTranscription(
    ///     audioURL: audioURL,
    ///     model: .whisper,
    ///     config: .default
    /// )
    ///
    /// for try await segment in stream {
    ///     print("[\(segment.startTime)s - \(segment.endTime)s]: \(segment.text)")
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - url: The URL of the audio file to transcribe.
    ///   - model: The transcription model to use.
    ///   - config: Transcription options.
    /// - Returns: An async stream that yields `TranscriptionSegment` instances
    ///            as they become available. The stream completes when the entire
    ///            audio file has been processed.
    /// - Note: The stream will throw errors if transcription fails at any point.
    ///         Consumers should handle errors appropriately using `try await`.
    func streamTranscription(
        audioURL url: URL,
        model: ModelID,
        config: TranscriptionConfig
    ) -> AsyncThrowingStream<TranscriptionSegment, Error>
}
