# SwiftAI Framework API Specification

> **Version:** 1.0.0-draft  
> **Swift Version:** 6.2  
> **Platforms:** iOS 17+, macOS 14+, visionOS 1+  
> **Last Updated:** December 2025

---

## Table of Contents

1. [Overview](#overview)
2. [Package Structure](#package-structure)
3. [Core Protocols](#core-protocols)
4. [Model Identification](#model-identification)
5. [Message Types](#message-types)
6. [Generation Configuration](#generation-configuration)
7. [Streaming Infrastructure](#streaming-infrastructure)
8. [Text Generation API](#text-generation-api)
9. [Embeddings API](#embeddings-api)
10. [Transcription API](#transcription-api)
11. [Token Counting API](#token-counting-api)
12. [Model Management](#model-management)
13. [Error Handling](#error-handling)
14. [Provider Implementations](#provider-implementations)
15. [Result Builders](#result-builders)
16. [Macros](#macros)
17. [Convenience Extensions](#convenience-extensions)
18. [Usage Examples](#usage-examples)

---

## Overview

SwiftAI is a unified Swift SDK that provides a clean, idiomatic interface for LLM inference across three providers:

| Provider | Use Case | Connectivity |
|----------|----------|--------------|
| **MLX** | Local inference on Apple Silicon | Offline |
| **HuggingFace** | Cloud inference via HF Inference API | Online |
| **Apple Foundation Models** | System-integrated on-device AI (iOS 26+) | Offline |

### Design Principles

1. **Explicit Model Selection** â€” No "magic" auto-selection; developers choose their provider
2. **Swift 6.2 Concurrency** â€” Actors, Sendable types, AsyncSequence throughout
3. **Protocol-Oriented** â€” Provider abstraction via protocols with associated types
4. **Composable** â€” Designed to work with external orchestration layers (agents, RAG)

---

## Package Structure

```
SwiftAI/
â”œâ”€â”€ Package.swift
â”œâ”€â”€ Sources/
â”‚   â””â”€â”€ SwiftAI/
â”‚       â”œâ”€â”€ SwiftAI.swift                    # Re-exports & convenience
â”‚       â”‚
â”‚       â”œâ”€â”€ Core/
â”‚       â”‚   â”œâ”€â”€ Protocols/
â”‚       â”‚   â”‚   â”œâ”€â”€ AIProvider.swift         # Main provider protocol
â”‚       â”‚   â”‚   â”œâ”€â”€ TextGenerator.swift      # Text generation capability
â”‚       â”‚   â”‚   â”œâ”€â”€ EmbeddingGenerator.swift # Embedding capability
â”‚       â”‚   â”‚   â”œâ”€â”€ Transcriber.swift        # Transcription capability
â”‚       â”‚   â”‚   â”œâ”€â”€ TokenCounter.swift       # Token counting capability
â”‚       â”‚   â”‚   â””â”€â”€ ModelManaging.swift      # Model management capability
â”‚       â”‚   â”‚
â”‚       â”‚   â”œâ”€â”€ Types/
â”‚       â”‚   â”‚   â”œâ”€â”€ ModelIdentifier.swift    # Model identification
â”‚       â”‚   â”‚   â”œâ”€â”€ Message.swift            # Chat message types
â”‚       â”‚   â”‚   â”œâ”€â”€ GenerateConfig.swift     # Generation parameters
â”‚       â”‚   â”‚   â”œâ”€â”€ EmbeddingResult.swift    # Embedding output
â”‚       â”‚   â”‚   â”œâ”€â”€ TranscriptionResult.swift# Transcription output
â”‚       â”‚   â”‚   â””â”€â”€ TokenCount.swift         # Token count result
â”‚       â”‚   â”‚
â”‚       â”‚   â”œâ”€â”€ Streaming/
â”‚       â”‚   â”‚   â”œâ”€â”€ GenerationStream.swift   # Streaming response
â”‚       â”‚   â”‚   â”œâ”€â”€ StreamChunk.swift        # Individual chunks
â”‚       â”‚   â”‚   â””â”€â”€ StreamBuffer.swift       # Buffering utilities
â”‚       â”‚   â”‚
â”‚       â”‚   â””â”€â”€ Errors/
â”‚       â”‚       â”œâ”€â”€ AIError.swift            # Main error type
â”‚       â”‚       â””â”€â”€ ProviderError.swift      # Provider-specific errors
â”‚       â”‚
â”‚       â”œâ”€â”€ Providers/
â”‚       â”‚   â”œâ”€â”€ MLX/
â”‚       â”‚   â”‚   â”œâ”€â”€ MLXProvider.swift        # MLX implementation
â”‚       â”‚   â”‚   â”œâ”€â”€ MLXModelLoader.swift     # Model loading
â”‚       â”‚   â”‚   â””â”€â”€ MLXConfiguration.swift   # MLX-specific config
â”‚       â”‚   â”‚
â”‚       â”‚   â”œâ”€â”€ HuggingFace/
â”‚       â”‚   â”‚   â”œâ”€â”€ HuggingFaceProvider.swift
â”‚       â”‚   â”‚   â”œâ”€â”€ HFInferenceClient.swift
â”‚       â”‚   â”‚   â”œâ”€â”€ HFTokenProvider.swift
â”‚       â”‚   â”‚   â””â”€â”€ HFConfiguration.swift
â”‚       â”‚   â”‚
â”‚       â”‚   â””â”€â”€ FoundationModels/
â”‚       â”‚       â”œâ”€â”€ FoundationModelsProvider.swift
â”‚       â”‚       â”œâ”€â”€ FMSessionManager.swift
â”‚       â”‚       â””â”€â”€ FMConfiguration.swift
â”‚       â”‚
â”‚       â”œâ”€â”€ ModelManagement/
â”‚       â”‚   â”œâ”€â”€ ModelManager.swift           # Download, cache, delete
â”‚       â”‚   â”œâ”€â”€ ModelRegistry.swift          # Known model constants
â”‚       â”‚   â”œâ”€â”€ ModelCache.swift             # Cache management
â”‚       â”‚   â””â”€â”€ DownloadProgress.swift       # Progress tracking
â”‚       â”‚
â”‚       â”œâ”€â”€ Builders/
â”‚       â”‚   â”œâ”€â”€ PromptBuilder.swift          # Result builder for prompts
â”‚       â”‚   â””â”€â”€ MessageBuilder.swift         # Result builder for messages
â”‚       â”‚
â”‚       â””â”€â”€ Macros/
â”‚           â””â”€â”€ GenerableMacro.swift         # @Generable equivalent
â”‚
â””â”€â”€ Tests/
    â””â”€â”€ SwiftAITests/
```

---

## Core Protocols

### AIProvider

The foundational protocol that all inference providers must conform to.

```swift
/// A provider capable of performing AI inference operations.
///
/// Conforming types must be actors to ensure thread-safe access to
/// underlying model resources. The protocol uses primary associated
/// types for cleaner generic constraints.
///
/// - Note: Providers are responsible for managing their own lifecycle,
///   including model loading, memory management, and cleanup.
public protocol AIProvider<Response>: Actor, Sendable {
    
    /// The type returned from non-streaming generation.
    associatedtype Response: Sendable
    
    /// The type yielded during streaming generation.
    associatedtype StreamChunk: Sendable
    
    /// The model identifier type this provider accepts.
    associatedtype ModelID: ModelIdentifying
    
    // MARK: - Availability
    
    /// Whether this provider is currently available for inference.
    ///
    /// Availability may depend on:
    /// - Device capabilities (RAM, chip type)
    /// - OS version requirements
    /// - Model download status
    /// - Network connectivity (for cloud providers)
    var isAvailable: Bool { get async }
    
    /// Detailed availability status with reason if unavailable.
    var availabilityStatus: ProviderAvailability { get async }
    
    // MARK: - Text Generation
    
    /// Generates a complete response for the given messages.
    ///
    /// - Parameters:
    ///   - messages: The conversation history and current prompt.
    ///   - model: The model to use for generation.
    ///   - config: Generation parameters (temperature, max tokens, etc.).
    /// - Returns: The complete generated response.
    /// - Throws: `AIError` if generation fails.
    func generate(
        messages: [Message],
        model: ModelID,
        config: GenerateConfig
    ) async throws -> Response
    
    /// Streams tokens as they are generated.
    ///
    /// - Parameters:
    ///   - messages: The conversation history and current prompt.
    ///   - model: The model to use for generation.
    ///   - config: Generation parameters.
    /// - Returns: An async stream of generation chunks.
    func stream(
        messages: [Message],
        model: ModelID,
        config: GenerateConfig
    ) -> AsyncThrowingStream<StreamChunk, Error>
    
    // MARK: - Cancellation
    
    /// Cancels any in-flight generation request.
    ///
    /// This is a cooperative cancellationâ€”the provider will stop
    /// generation at the next safe point.
    func cancelGeneration() async
}
```

### TextGenerator

A focused protocol for text generation capabilities.

```swift
/// A type that can generate text responses.
public protocol TextGenerator: Sendable {
    associatedtype ModelID: ModelIdentifying
    
    /// Generates text from a simple string prompt.
    ///
    /// This is a convenience method that wraps the prompt in a user message.
    func generate(
        _ prompt: String,
        model: ModelID,
        config: GenerateConfig
    ) async throws -> String
    
    /// Generates text from a conversation.
    func generate(
        messages: [Message],
        model: ModelID,
        config: GenerateConfig
    ) async throws -> GenerationResult
    
    /// Streams text generation token by token.
    func stream(
        _ prompt: String,
        model: ModelID,
        config: GenerateConfig
    ) -> AsyncThrowingStream<String, Error>
    
    /// Streams text generation with full chunk metadata.
    func streamWithMetadata(
        messages: [Message],
        model: ModelID,
        config: GenerateConfig
    ) -> AsyncThrowingStream<GenerationChunk, Error>
}
```

### EmbeddingGenerator

Protocol for generating vector embeddings.

```swift
/// A type that can generate vector embeddings from text.
public protocol EmbeddingGenerator: Sendable {
    associatedtype ModelID: ModelIdentifying
    
    /// Generates an embedding vector for the given text.
    ///
    /// - Parameters:
    ///   - text: The text to embed.
    ///   - model: The embedding model to use.
    /// - Returns: The embedding result containing the vector.
    func embed(
        _ text: String,
        model: ModelID
    ) async throws -> EmbeddingResult
    
    /// Generates embeddings for multiple texts in a batch.
    ///
    /// Batch processing is more efficient than individual calls
    /// when embedding multiple texts.
    ///
    /// - Parameters:
    ///   - texts: The texts to embed.
    ///   - model: The embedding model to use.
    /// - Returns: Embedding results in the same order as input.
    func embedBatch(
        _ texts: [String],
        model: ModelID
    ) async throws -> [EmbeddingResult]
}
```

### Transcriber

Protocol for audio-to-text transcription.

```swift
/// A type that can transcribe audio to text.
public protocol Transcriber: Sendable {
    associatedtype ModelID: ModelIdentifying
    
    /// Transcribes audio from a file URL.
    ///
    /// - Parameters:
    ///   - url: The URL of the audio file to transcribe.
    ///   - model: The transcription model to use.
    ///   - config: Transcription options.
    /// - Returns: The transcription result.
    func transcribe(
        audioURL url: URL,
        model: ModelID,
        config: TranscriptionConfig
    ) async throws -> TranscriptionResult
    
    /// Transcribes audio from raw data.
    ///
    /// - Parameters:
    ///   - data: The audio data (WAV, MP3, M4A, FLAC supported).
    ///   - model: The transcription model to use.
    ///   - config: Transcription options.
    /// - Returns: The transcription result.
    func transcribe(
        audioData data: Data,
        model: ModelID,
        config: TranscriptionConfig
    ) async throws -> TranscriptionResult
    
    /// Streams transcription results as they become available.
    ///
    /// Useful for real-time transcription of live audio.
    func streamTranscription(
        audioURL url: URL,
        model: ModelID,
        config: TranscriptionConfig
    ) -> AsyncThrowingStream<TranscriptionSegment, Error>
}
```

### TokenCounter

Protocol for counting tokens in text.

```swift
/// A type that can count tokens in text.
///
/// Token counting is essential for:
/// - Context window management
/// - Cost estimation (for cloud providers)
/// - Prompt truncation strategies
public protocol TokenCounter: Sendable {
    associatedtype ModelID: ModelIdentifying
    
    /// Counts the number of tokens in the given text.
    ///
    /// - Parameters:
    ///   - text: The text to tokenize.
    ///   - model: The model whose tokenizer should be used.
    /// - Returns: Token count information.
    func countTokens(
        in text: String,
        for model: ModelID
    ) async throws -> TokenCount
    
    /// Counts tokens in a message array (including special tokens).
    ///
    /// This accounts for chat template overhead, special tokens,
    /// and message formatting specific to the model.
    func countTokens(
        in messages: [Message],
        for model: ModelID
    ) async throws -> TokenCount
    
    /// Encodes text to token IDs.
    ///
    /// - Parameters:
    ///   - text: The text to encode.
    ///   - model: The model whose tokenizer should be used.
    /// - Returns: Array of token IDs.
    func encode(
        _ text: String,
        for model: ModelID
    ) async throws -> [Int]
    
    /// Decodes token IDs back to text.
    ///
    /// - Parameters:
    ///   - tokens: The token IDs to decode.
    ///   - model: The model whose tokenizer should be used.
    ///   - skipSpecialTokens: Whether to skip special tokens in output.
    /// - Returns: The decoded text.
    func decode(
        _ tokens: [Int],
        for model: ModelID,
        skipSpecialTokens: Bool
    ) async throws -> String
}
```

### ModelManaging

Protocol for model lifecycle management.

```swift
/// A type that manages model downloads, caching, and deletion.
public protocol ModelManaging: Sendable {
    associatedtype ModelID: ModelIdentifying
    
    // MARK: - Discovery
    
    /// Lists all models available from this provider.
    func availableModels() async throws -> [ModelInfo]
    
    /// Lists models currently cached on device.
    func cachedModels() async -> [CachedModelInfo]
    
    /// Checks if a specific model is cached locally.
    func isCached(_ model: ModelID) async -> Bool
    
    // MARK: - Download
    
    /// Downloads a model to local storage.
    ///
    /// - Parameters:
    ///   - model: The model to download.
    ///   - progress: A closure called with download progress updates.
    /// - Returns: The local URL where the model was saved.
    func download(
        _ model: ModelID,
        progress: @escaping @Sendable (DownloadProgress) -> Void
    ) async throws -> URL
    
    /// Downloads a model with structured concurrency progress.
    func download(_ model: ModelID) -> DownloadTask
    
    // MARK: - Cache Management
    
    /// Deletes a cached model from local storage.
    func delete(_ model: ModelID) async throws
    
    /// Clears all cached models.
    func clearCache() async throws
    
    /// Returns the total size of cached models.
    func cacheSize() async -> ByteCount
}
```

---

## Model Identification

### ModelIdentifying Protocol

```swift
/// A type that uniquely identifies a model.
///
/// Model identifiers are used throughout SwiftAI to specify which
/// model should be used for inference. Each provider has its own
/// identifier type that conforms to this protocol.
public protocol ModelIdentifying: Hashable, Sendable, CustomStringConvertible {
    /// The raw string identifier (e.g., "mlx-community/Llama-3.2-1B-Instruct-4bit")
    var rawValue: String { get }
    
    /// Human-readable display name
    var displayName: String { get }
    
    /// The provider this model belongs to
    var provider: ProviderType { get }
}
```

### ModelIdentifier Enum

The primary model identifier type used throughout SwiftAI.

```swift
/// Identifies a model and its inference provider.
///
/// SwiftAI requires explicit model selectionâ€”there is no automatic
/// provider detection. This ensures developers understand exactly
/// where inference will occur.
///
/// ## Usage
/// ```swift
/// // Local MLX model
/// let localModel: ModelIdentifier = .mlx("mlx-community/Llama-3.2-1B-Instruct-4bit")
///
/// // Cloud HuggingFace model
/// let cloudModel: ModelIdentifier = .huggingFace("meta-llama/Llama-3.1-70B-Instruct")
///
/// // Apple Foundation Models
/// let appleModel: ModelIdentifier = .foundationModels
/// ```
public enum ModelIdentifier: ModelIdentifying, Codable {
    
    /// A model to be run locally via MLX on Apple Silicon.
    ///
    /// - Parameter id: The HuggingFace repository ID (e.g., "mlx-community/Llama-3.2-1B-Instruct-4bit")
    case mlx(String)
    
    /// A model to be run via HuggingFace Inference API.
    ///
    /// - Parameter id: The HuggingFace model ID (e.g., "meta-llama/Llama-3.1-70B-Instruct")
    case huggingFace(String)
    
    /// Apple's on-device Foundation Models (iOS 26+).
    ///
    /// This uses Apple's system language model. No model ID is needed
    /// as Apple manages the model automatically.
    case foundationModels
    
    // MARK: - ModelIdentifying
    
    public var rawValue: String {
        switch self {
        case .mlx(let id): return id
        case .huggingFace(let id): return id
        case .foundationModels: return "apple-foundation-models"
        }
    }
    
    public var displayName: String {
        switch self {
        case .mlx(let id):
            return id.components(separatedBy: "/").last ?? id
        case .huggingFace(let id):
            return id.components(separatedBy: "/").last ?? id
        case .foundationModels:
            return "Apple Intelligence"
        }
    }
    
    public var provider: ProviderType {
        switch self {
        case .mlx: return .mlx
        case .huggingFace: return .huggingFace
        case .foundationModels: return .foundationModels
        }
    }
    
    public var description: String {
        "[\(provider)] \(rawValue)"
    }
}
```

### Provider Type

```swift
/// The type of inference provider.
public enum ProviderType: String, Sendable, Codable, CaseIterable {
    /// MLX local inference on Apple Silicon
    case mlx
    
    /// HuggingFace Inference API (cloud)
    case huggingFace
    
    /// Apple Foundation Models (iOS 26+)
    case foundationModels
    
    /// Human-readable name
    public var displayName: String {
        switch self {
        case .mlx: return "MLX (Local)"
        case .huggingFace: return "HuggingFace (Cloud)"
        case .foundationModels: return "Apple Foundation Models"
        }
    }
    
    /// Whether this provider requires network connectivity
    public var requiresNetwork: Bool {
        switch self {
        case .mlx, .foundationModels: return false
        case .huggingFace: return true
        }
    }
}
```

### Model Registry

Pre-defined constants for commonly used models.

```swift
/// Registry of commonly used models with convenient static accessors.
///
/// Using registry constants ensures correct model IDs and makes
/// code more readable.
///
/// ## Usage
/// ```swift
/// let response = try await provider.generate(
///     "Hello!",
///     model: .llama3_2_1B,
///     config: .default
/// )
/// ```
public extension ModelIdentifier {
    
    // MARK: - MLX Local Models (Recommended)
    
    /// Llama 3.2 1B (4-bit quantized) - Fast, lightweight
    static let llama3_2_1B = ModelIdentifier.mlx("mlx-community/Llama-3.2-1B-Instruct-4bit")
    
    /// Llama 3.2 3B (4-bit quantized) - Balanced performance
    static let llama3_2_3B = ModelIdentifier.mlx("mlx-community/Llama-3.2-3B-Instruct-4bit")
    
    /// Phi-3 Mini (4-bit quantized) - Microsoft's efficient model
    static let phi3Mini = ModelIdentifier.mlx("mlx-community/Phi-3-mini-4k-instruct-4bit")
    
    /// Phi-4 (4-bit quantized) - Latest Phi model
    static let phi4 = ModelIdentifier.mlx("mlx-community/phi-4-4bit")
    
    /// Qwen 2.5 3B (4-bit quantized)
    static let qwen2_5_3B = ModelIdentifier.mlx("mlx-community/Qwen2.5-3B-Instruct-4bit")
    
    /// Mistral 7B (4-bit quantized)
    static let mistral7B = ModelIdentifier.mlx("mlx-community/Mistral-7B-Instruct-v0.3-4bit")
    
    /// Gemma 2 2B (4-bit quantized)
    static let gemma2_2B = ModelIdentifier.mlx("mlx-community/gemma-2-2b-it-4bit")
    
    // MARK: - MLX Embedding Models
    
    /// BGE Small - Fast embeddings
    static let bgeSmall = ModelIdentifier.mlx("mlx-community/bge-small-en-v1.5")
    
    /// BGE Large - Higher quality embeddings
    static let bgeLarge = ModelIdentifier.mlx("mlx-community/bge-large-en-v1.5")
    
    /// Nomic Embed - Good balance
    static let nomicEmbed = ModelIdentifier.mlx("mlx-community/nomic-embed-text-v1.5")
    
    // MARK: - HuggingFace Cloud Models
    
    /// Llama 3.1 70B - High capability, cloud only
    static let llama3_1_70B = ModelIdentifier.huggingFace("meta-llama/Llama-3.1-70B-Instruct")
    
    /// Llama 3.1 8B - Balanced cloud option
    static let llama3_1_8B = ModelIdentifier.huggingFace("meta-llama/Llama-3.1-8B-Instruct")
    
    /// Mixtral 8x7B - MoE architecture
    static let mixtral8x7B = ModelIdentifier.huggingFace("mistralai/Mixtral-8x7B-Instruct-v0.1")
    
    /// DeepSeek R1 - Reasoning focused
    static let deepseekR1 = ModelIdentifier.huggingFace("deepseek-ai/DeepSeek-R1")
    
    // MARK: - Apple Foundation Models
    
    /// Apple's on-device Foundation Model
    static let apple = ModelIdentifier.foundationModels
}
```

---

## Message Types

### Message

The core message type for conversations.

```swift
/// A message in a conversation.
///
/// Messages represent the conversation history passed to the model.
/// Each message has a role (system, user, assistant) and content.
///
/// ## Usage
/// ```swift
/// let messages: [Message] = [
///     .system("You are a helpful assistant."),
///     .user("What is Swift?"),
///     .assistant("Swift is a programming language..."),
///     .user("Tell me more about its concurrency features.")
/// ]
/// ```
public struct Message: Sendable, Hashable, Codable, Identifiable {
    
    /// Unique identifier for this message.
    public let id: UUID
    
    /// The role of the message sender.
    public let role: Role
    
    /// The content of the message.
    public let content: Content
    
    /// Timestamp when this message was created.
    public let timestamp: Date
    
    /// Optional metadata attached to this message.
    public let metadata: MessageMetadata?
    
    // MARK: - Initialization
    
    public init(
        id: UUID = UUID(),
        role: Role,
        content: Content,
        timestamp: Date = Date(),
        metadata: MessageMetadata? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.metadata = metadata
    }
    
    // MARK: - Convenience Initializers
    
    /// Creates a system message.
    public static func system(_ text: String) -> Message {
        Message(role: .system, content: .text(text))
    }
    
    /// Creates a user message.
    public static func user(_ text: String) -> Message {
        Message(role: .user, content: .text(text))
    }
    
    /// Creates an assistant message.
    public static func assistant(_ text: String) -> Message {
        Message(role: .assistant, content: .text(text))
    }
    
    /// Creates a user message with text content.
    public static func user(text: String) -> Message {
        Message(role: .user, content: .text(text))
    }
}
```

### Message.Role

```swift
extension Message {
    /// The role of the message sender.
    public enum Role: String, Sendable, Codable, CaseIterable {
        /// System instructions that guide the model's behavior.
        case system
        
        /// Input from the user.
        case user
        
        /// Output from the model.
        case assistant
        
        /// Tool/function call result (for future tool calling support).
        case tool
    }
}
```

### Message.Content

```swift
extension Message {
    /// The content of a message.
    ///
    /// Content can be simple text or a combination of text and other
    /// modalities (for future multimodal support).
    public enum Content: Sendable, Hashable, Codable {
        /// Plain text content.
        case text(String)
        
        /// Multiple content parts (for future multimodal support).
        case parts([ContentPart])
        
        /// Extracts text content, combining parts if necessary.
        public var textValue: String {
            switch self {
            case .text(let string):
                return string
            case .parts(let parts):
                return parts.compactMap { part in
                    if case .text(let text) = part { return text }
                    return nil
                }.joined(separator: "\n")
            }
        }
    }
    
    /// A single part of multimodal content.
    public enum ContentPart: Sendable, Hashable, Codable {
        /// Text content.
        case text(String)
        
        /// Image content (for future VLM support).
        case image(ImageContent)
    }
    
    /// Image content for vision models.
    public struct ImageContent: Sendable, Hashable, Codable {
        /// Base64-encoded image data.
        public let base64Data: String
        
        /// MIME type of the image.
        public let mimeType: String
        
        public init(base64Data: String, mimeType: String = "image/jpeg") {
            self.base64Data = base64Data
            self.mimeType = mimeType
        }
    }
}
```

### MessageMetadata

```swift
/// Optional metadata attached to a message.
public struct MessageMetadata: Sendable, Hashable, Codable {
    /// Token count for this message (if known).
    public var tokenCount: Int?
    
    /// Generation time in seconds (for assistant messages).
    public var generationTime: TimeInterval?
    
    /// Model used to generate this message.
    public var model: String?
    
    /// Tokens per second during generation.
    public var tokensPerSecond: Double?
    
    /// Custom key-value metadata.
    public var custom: [String: String]?
    
    public init(
        tokenCount: Int? = nil,
        generationTime: TimeInterval? = nil,
        model: String? = nil,
        tokensPerSecond: Double? = nil,
        custom: [String: String]? = nil
    ) {
        self.tokenCount = tokenCount
        self.generationTime = generationTime
        self.model = model
        self.tokensPerSecond = tokensPerSecond
        self.custom = custom
    }
}
```

---

## Generation Configuration

### GenerateConfig

```swift
/// Configuration options for text generation.
///
/// These parameters control the generation behavior including
/// randomness, length limits, and stopping conditions.
///
/// ## Usage
/// ```swift
/// // Use defaults
/// let config = GenerateConfig.default
///
/// // Customize
/// let config = GenerateConfig(
///     maxTokens: 500,
///     temperature: 0.8,
///     topP: 0.95
/// )
///
/// // Fluent API
/// let config = GenerateConfig.default
///     .temperature(0.9)
///     .maxTokens(1000)
/// ```
public struct GenerateConfig: Sendable, Hashable, Codable {
    
    // MARK: - Token Limits
    
    /// Maximum number of tokens to generate.
    ///
    /// Generation stops when this limit is reached. Set to `nil`
    /// for no limit (uses model's maximum context).
    public var maxTokens: Int?
    
    /// Minimum number of tokens to generate.
    ///
    /// The model will continue generating until at least this
    /// many tokens are produced (unless a stop condition is met).
    public var minTokens: Int?
    
    // MARK: - Sampling Parameters
    
    /// Controls randomness in generation.
    ///
    /// - `0.0`: Deterministic (always pick highest probability token)
    /// - `0.7`: Balanced creativity (default)
    /// - `1.0+`: More random/creative
    ///
    /// Range: 0.0 to 2.0
    public var temperature: Float
    
    /// Nucleus sampling threshold.
    ///
    /// Only consider tokens with cumulative probability up to this value.
    /// Lower values make output more focused; higher values more diverse.
    ///
    /// Range: 0.0 to 1.0 (default: 0.9)
    public var topP: Float
    
    /// Top-K sampling.
    ///
    /// Only consider the top K most likely tokens.
    /// Set to `nil` to disable top-K sampling.
    public var topK: Int?
    
    /// Repetition penalty.
    ///
    /// Penalizes tokens that have already appeared in the output.
    /// Values > 1.0 reduce repetition; 1.0 disables penalty.
    ///
    /// Range: 0.0 to 2.0 (default: 1.0)
    public var repetitionPenalty: Float
    
    /// Frequency penalty.
    ///
    /// Reduces likelihood of tokens based on how often they've appeared.
    ///
    /// Range: -2.0 to 2.0 (default: 0.0)
    public var frequencyPenalty: Float
    
    /// Presence penalty.
    ///
    /// Reduces likelihood of tokens that have appeared at all.
    ///
    /// Range: -2.0 to 2.0 (default: 0.0)
    public var presencePenalty: Float
    
    // MARK: - Stopping Conditions
    
    /// Sequences that stop generation when encountered.
    ///
    /// Generation stops immediately when any of these sequences
    /// appear in the output (the sequence is not included).
    public var stopSequences: [String]
    
    // MARK: - Advanced Options
    
    /// Random seed for reproducible generation.
    ///
    /// Set to a fixed value for deterministic output given
    /// the same input and parameters.
    public var seed: UInt64?
    
    /// Whether to return log probabilities.
    ///
    /// When enabled, the response includes probability information
    /// for each generated token.
    public var returnLogprobs: Bool
    
    /// Number of top log probabilities to return per token.
    public var topLogprobs: Int?
    
    // MARK: - Initialization
    
    public init(
        maxTokens: Int? = 1024,
        minTokens: Int? = nil,
        temperature: Float = 0.7,
        topP: Float = 0.9,
        topK: Int? = nil,
        repetitionPenalty: Float = 1.0,
        frequencyPenalty: Float = 0.0,
        presencePenalty: Float = 0.0,
        stopSequences: [String] = [],
        seed: UInt64? = nil,
        returnLogprobs: Bool = false,
        topLogprobs: Int? = nil
    ) {
        self.maxTokens = maxTokens
        self.minTokens = minTokens
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.repetitionPenalty = repetitionPenalty
        self.frequencyPenalty = frequencyPenalty
        self.presencePenalty = presencePenalty
        self.stopSequences = stopSequences
        self.seed = seed
        self.returnLogprobs = returnLogprobs
        self.topLogprobs = topLogprobs
    }
    
    // MARK: - Presets
    
    /// Default configuration suitable for most use cases.
    public static let `default` = GenerateConfig()
    
    /// Creative configuration for story writing, brainstorming.
    public static let creative = GenerateConfig(
        temperature: 0.9,
        topP: 0.95,
        frequencyPenalty: 0.5
    )
    
    /// Precise configuration for factual, deterministic output.
    public static let precise = GenerateConfig(
        temperature: 0.1,
        topP: 0.5,
        repetitionPenalty: 1.1
    )
    
    /// Code generation configuration.
    public static let code = GenerateConfig(
        temperature: 0.2,
        topP: 0.9,
        stopSequences: ["```", "\n\n\n"]
    )
}

// MARK: - Fluent API

extension GenerateConfig {
    /// Returns a copy with the specified max tokens.
    public func maxTokens(_ value: Int?) -> GenerateConfig {
        var copy = self
        copy.maxTokens = value
        return copy
    }
    
    /// Returns a copy with the specified temperature.
    public func temperature(_ value: Float) -> GenerateConfig {
        var copy = self
        copy.temperature = max(0, min(2, value))
        return copy
    }
    
    /// Returns a copy with the specified top-p value.
    public func topP(_ value: Float) -> GenerateConfig {
        var copy = self
        copy.topP = max(0, min(1, value))
        return copy
    }
    
    /// Returns a copy with the specified top-k value.
    public func topK(_ value: Int?) -> GenerateConfig {
        var copy = self
        copy.topK = value
        return copy
    }
    
    /// Returns a copy with the specified stop sequences.
    public func stopSequences(_ sequences: [String]) -> GenerateConfig {
        var copy = self
        copy.stopSequences = sequences
        return copy
    }
    
    /// Returns a copy with the specified seed.
    public func seed(_ value: UInt64?) -> GenerateConfig {
        var copy = self
        copy.seed = value
        return copy
    }
    
    /// Returns a copy with log probabilities enabled.
    public func withLogprobs(top: Int = 5) -> GenerateConfig {
        var copy = self
        copy.returnLogprobs = true
        copy.topLogprobs = top
        return copy
    }
}
```

---

## Streaming Infrastructure

### GenerationStream

```swift
/// A stream of generated content chunks.
///
/// `GenerationStream` wraps `AsyncThrowingStream` and provides
/// additional conveniences for working with streamed generation.
///
/// ## Usage
/// ```swift
/// let stream = provider.stream(messages: messages, model: .llama3_2_1B, config: .default)
///
/// // Simple text iteration
/// for try await text in stream.text {
///     print(text, terminator: "")
/// }
///
/// // Full chunk iteration with metadata
/// for try await chunk in stream {
///     print("Token: \(chunk.text), Tokens/sec: \(chunk.tokensPerSecond ?? 0)")
/// }
///
/// // Collect all text
/// let fullText = try await stream.collect()
/// ```
public struct GenerationStream: AsyncSequence, Sendable {
    public typealias Element = GenerationChunk
    
    private let stream: AsyncThrowingStream<GenerationChunk, Error>
    
    public init(_ stream: AsyncThrowingStream<GenerationChunk, Error>) {
        self.stream = stream
    }
    
    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(stream.makeAsyncIterator())
    }
    
    public struct AsyncIterator: AsyncIteratorProtocol {
        private var iterator: AsyncThrowingStream<GenerationChunk, Error>.AsyncIterator
        
        init(_ iterator: AsyncThrowingStream<GenerationChunk, Error>.AsyncIterator) {
            self.iterator = iterator
        }
        
        public mutating func next() async throws -> GenerationChunk? {
            try await iterator.next()
        }
    }
    
    // MARK: - Convenience Properties
    
    /// A stream that yields only the text content of each chunk.
    public var text: AsyncThrowingMapSequence<GenerationStream, String> {
        self.map { $0.text }
    }
    
    /// Collects all chunks and returns the complete text.
    public func collect() async throws -> String {
        var result = ""
        for try await chunk in self {
            result += chunk.text
        }
        return result
    }
    
    /// Collects all chunks and returns the final generation result.
    public func collectWithMetadata() async throws -> GenerationResult {
        var text = ""
        var totalTokens = 0
        var firstChunkTime: Date?
        var lastChunkTime: Date?
        
        for try await chunk in self {
            if firstChunkTime == nil {
                firstChunkTime = Date()
            }
            lastChunkTime = Date()
            text += chunk.text
            totalTokens += chunk.tokenCount
        }
        
        let duration = lastChunkTime?.timeIntervalSince(firstChunkTime ?? Date()) ?? 0
        
        return GenerationResult(
            text: text,
            tokenCount: totalTokens,
            generationTime: duration,
            tokensPerSecond: duration > 0 ? Double(totalTokens) / duration : 0,
            finishReason: .stop
        )
    }
}
```

### GenerationChunk

```swift
/// A single chunk of streamed generation output.
public struct GenerationChunk: Sendable, Hashable {
    /// The generated text in this chunk.
    public let text: String
    
    /// Number of tokens in this chunk (usually 1).
    public let tokenCount: Int
    
    /// Token ID if available.
    public let tokenId: Int?
    
    /// Log probability of this token.
    public let logprob: Float?
    
    /// Top alternative tokens with their probabilities.
    public let topLogprobs: [TokenLogprob]?
    
    /// Generation speed at this point (tokens per second).
    public let tokensPerSecond: Double?
    
    /// Whether this is the final chunk.
    public let isComplete: Bool
    
    /// Reason generation stopped (only set on final chunk).
    public let finishReason: FinishReason?
    
    public init(
        text: String,
        tokenCount: Int = 1,
        tokenId: Int? = nil,
        logprob: Float? = nil,
        topLogprobs: [TokenLogprob]? = nil,
        tokensPerSecond: Double? = nil,
        isComplete: Bool = false,
        finishReason: FinishReason? = nil
    ) {
        self.text = text
        self.tokenCount = tokenCount
        self.tokenId = tokenId
        self.logprob = logprob
        self.topLogprobs = topLogprobs
        self.tokensPerSecond = tokensPerSecond
        self.isComplete = isComplete
        self.finishReason = finishReason
    }
}

/// Log probability information for a token.
public struct TokenLogprob: Sendable, Hashable, Codable {
    /// The token text.
    public let token: String
    
    /// Log probability of this token.
    public let logprob: Float
    
    /// Token ID.
    public let tokenId: Int?
}
```

### GenerationResult

```swift
/// The result of a complete (non-streaming) generation.
public struct GenerationResult: Sendable, Hashable {
    /// The generated text.
    public let text: String
    
    /// Total number of tokens generated.
    public let tokenCount: Int
    
    /// Time taken to generate (seconds).
    public let generationTime: TimeInterval
    
    /// Average tokens per second.
    public let tokensPerSecond: Double
    
    /// Why generation stopped.
    public let finishReason: FinishReason
    
    /// Log probabilities (if requested).
    public let logprobs: [TokenLogprob]?
    
    /// Usage statistics.
    public let usage: UsageStats?
    
    public init(
        text: String,
        tokenCount: Int,
        generationTime: TimeInterval,
        tokensPerSecond: Double,
        finishReason: FinishReason,
        logprobs: [TokenLogprob]? = nil,
        usage: UsageStats? = nil
    ) {
        self.text = text
        self.tokenCount = tokenCount
        self.generationTime = generationTime
        self.tokensPerSecond = tokensPerSecond
        self.finishReason = finishReason
        self.logprobs = logprobs
        self.usage = usage
    }
}

/// Reason why generation stopped.
public enum FinishReason: String, Sendable, Codable {
    /// Natural end of generation (EOS token).
    case stop
    
    /// Reached maximum token limit.
    case maxTokens = "max_tokens"
    
    /// Hit a stop sequence.
    case stopSequence = "stop_sequence"
    
    /// User cancelled generation.
    case cancelled
    
    /// Content filtered by safety systems.
    case contentFilter = "content_filter"
    
    /// Tool call requested (for future use).
    case toolCall = "tool_call"
}

/// Token usage statistics.
public struct UsageStats: Sendable, Hashable, Codable {
    /// Tokens in the prompt/input.
    public let promptTokens: Int
    
    /// Tokens in the completion/output.
    public let completionTokens: Int
    
    /// Total tokens used.
    public var totalTokens: Int {
        promptTokens + completionTokens
    }
}
```

---

## Text Generation API

### Main Generation Methods

```swift
extension AIProvider where Self: TextGenerator {
    
    /// Generates a response from a simple string prompt.
    ///
    /// This is the simplest way to get a response from the model.
    ///
    /// ## Example
    /// ```swift
    /// let response = try await provider.generate(
    ///     "Explain quantum computing in simple terms",
    ///     model: .llama3_2_1B,
    ///     config: .default
    /// )
    /// print(response)
    /// ```
    public func generate(
        _ prompt: String,
        model: ModelID,
        config: GenerateConfig = .default
    ) async throws -> String {
        let messages = [Message.user(prompt)]
        let result = try await generate(messages: messages, model: model, config: config)
        return result.text
    }
    
    /// Generates a response with full result metadata.
    public func generateWithMetadata(
        _ prompt: String,
        model: ModelID,
        config: GenerateConfig = .default
    ) async throws -> GenerationResult {
        let messages = [Message.user(prompt)]
        return try await generate(messages: messages, model: model, config: config)
    }
}
```

### Chat Session

A stateful wrapper for multi-turn conversations.

```swift
/// A stateful chat session that maintains conversation history.
///
/// `ChatSession` simplifies multi-turn conversations by automatically
/// managing message history and providing a clean API for sending
/// messages and receiving responses.
///
/// ## Usage
/// ```swift
/// let session = ChatSession(provider: provider, model: .llama3_2_1B)
///
/// // Add system instructions
/// session.setSystemPrompt("You are a helpful cooking assistant.")
///
/// // Have a conversation
/// let response1 = try await session.send("How do I make pasta?")
/// let response2 = try await session.send("What sauce goes well with it?")
///
/// // Access conversation history
/// print(session.messages)
/// ```
@Observable
public final class ChatSession<Provider: AIProvider & TextGenerator>: @unchecked Sendable {
    
    // MARK: - Properties
    
    /// The provider used for generation.
    public let provider: Provider
    
    /// The model to use for generation.
    public let model: Provider.ModelID
    
    /// The conversation history.
    public private(set) var messages: [Message] = []
    
    /// Whether generation is currently in progress.
    public private(set) var isGenerating: Bool = false
    
    /// The current generation configuration.
    public var config: GenerateConfig
    
    /// Error from the last operation, if any.
    public private(set) var lastError: Error?
    
    // MARK: - Private
    
    private var generationTask: Task<Void, Never>?
    private let lock = NSLock()
    
    // MARK: - Initialization
    
    public init(
        provider: Provider,
        model: Provider.ModelID,
        config: GenerateConfig = .default
    ) {
        self.provider = provider
        self.model = model
        self.config = config
    }
    
    // MARK: - System Prompt
    
    /// Sets or updates the system prompt.
    ///
    /// If a system message already exists, it is replaced.
    /// The system message is always kept at the beginning.
    public func setSystemPrompt(_ prompt: String) {
        lock.lock()
        defer { lock.unlock() }
        
        if let index = messages.firstIndex(where: { $0.role == .system }) {
            messages[index] = .system(prompt)
        } else {
            messages.insert(.system(prompt), at: 0)
        }
    }
    
    // MARK: - Sending Messages
    
    /// Sends a message and returns the assistant's response.
    ///
    /// The user message and assistant response are automatically
    /// added to the conversation history.
    @discardableResult
    public func send(_ content: String) async throws -> String {
        let userMessage = Message.user(content)
        
        lock.lock()
        messages.append(userMessage)
        isGenerating = true
        lock.unlock()
        
        defer {
            lock.lock()
            isGenerating = false
            lock.unlock()
        }
        
        do {
            let result = try await provider.generate(
                messages: messages,
                model: model,
                config: config
            )
            
            let assistantMessage = Message(
                role: .assistant,
                content: .text(result.text),
                metadata: MessageMetadata(
                    tokenCount: result.tokenCount,
                    generationTime: result.generationTime,
                    tokensPerSecond: result.tokensPerSecond
                )
            )
            
            lock.lock()
            messages.append(assistantMessage)
            lastError = nil
            lock.unlock()
            
            return result.text
            
        } catch {
            lock.lock()
            lastError = error
            // Remove the user message on failure
            if messages.last?.role == .user {
                messages.removeLast()
            }
            lock.unlock()
            throw error
        }
    }
    
    /// Sends a message and streams the response.
    public func stream(_ content: String) -> AsyncThrowingStream<String, Error> {
        let userMessage = Message.user(content)
        
        lock.lock()
        messages.append(userMessage)
        isGenerating = true
        lock.unlock()
        
        return AsyncThrowingStream { continuation in
            let task = Task {
                var fullResponse = ""
                
                do {
                    let stream = provider.stream(
                        messages: messages,
                        model: model,
                        config: config
                    )
                    
                    for try await chunk in stream {
                        fullResponse += chunk.text
                        continuation.yield(chunk.text)
                    }
                    
                    let assistantMessage = Message.assistant(fullResponse)
                    
                    lock.lock()
                    messages.append(assistantMessage)
                    isGenerating = false
                    lastError = nil
                    lock.unlock()
                    
                    continuation.finish()
                    
                } catch {
                    lock.lock()
                    isGenerating = false
                    lastError = error
                    if messages.last?.role == .user {
                        messages.removeLast()
                    }
                    lock.unlock()
                    
                    continuation.finish(throwing: error)
                }
            }
            
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
    
    // MARK: - History Management
    
    /// Clears all messages except the system prompt.
    public func clearHistory() {
        lock.lock()
        defer { lock.unlock() }
        messages = messages.filter { $0.role == .system }
    }
    
    /// Removes the last exchange (user message + assistant response).
    public func undoLastExchange() {
        lock.lock()
        defer { lock.unlock() }
        
        // Remove assistant message
        if messages.last?.role == .assistant {
            messages.removeLast()
        }
        // Remove user message
        if messages.last?.role == .user {
            messages.removeLast()
        }
    }
    
    /// Injects previous conversation history.
    ///
    /// Useful for restoring a conversation from persistence.
    public func injectHistory(_ history: [Message]) {
        lock.lock()
        defer { lock.unlock() }
        
        // Preserve system prompt if exists
        let systemMessage = messages.first { $0.role == .system }
        messages = []
        if let system = systemMessage {
            messages.append(system)
        }
        messages.append(contentsOf: history.filter { $0.role != .system })
    }
    
    // MARK: - Cancellation
    
    /// Cancels the current generation.
    public func cancel() async {
        generationTask?.cancel()
        await provider.cancelGeneration()
    }
}
```

---

## Embeddings API

### EmbeddingResult

```swift
/// The result of an embedding operation.
public struct EmbeddingResult: Sendable {
    /// The embedding vector.
    ///
    /// The dimensionality depends on the model used.
    /// Common sizes: 384 (small), 768 (base), 1024 (large).
    public let vector: [Float]
    
    /// The original text that was embedded.
    public let text: String
    
    /// The model used to generate the embedding.
    public let model: String
    
    /// Dimensionality of the embedding.
    public var dimensions: Int {
        vector.count
    }
    
    /// Number of tokens in the input text.
    public let tokenCount: Int?
    
    // MARK: - Similarity Methods
    
    /// Computes cosine similarity with another embedding.
    ///
    /// - Returns: Similarity score between -1 and 1 (1 = identical).
    public func cosineSimilarity(with other: EmbeddingResult) -> Float {
        guard vector.count == other.vector.count else { return 0 }
        
        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0
        
        for i in vector.indices {
            dotProduct += vector[i] * other.vector[i]
            normA += vector[i] * vector[i]
            normB += other.vector[i] * other.vector[i]
        }
        
        let denominator = sqrt(normA) * sqrt(normB)
        return denominator > 0 ? dotProduct / denominator : 0
    }
    
    /// Computes Euclidean distance to another embedding.
    ///
    /// - Returns: Distance (0 = identical, larger = more different).
    public func euclideanDistance(to other: EmbeddingResult) -> Float {
        guard vector.count == other.vector.count else { return .infinity }
        
        var sum: Float = 0
        for i in vector.indices {
            let diff = vector[i] - other.vector[i]
            sum += diff * diff
        }
        return sqrt(sum)
    }
    
    /// Computes dot product with another embedding.
    public func dotProduct(with other: EmbeddingResult) -> Float {
        guard vector.count == other.vector.count else { return 0 }
        return zip(vector, other.vector).reduce(0) { $0 + $1.0 * $1.1 }
    }
}

// MARK: - Batch Embeddings

/// Result of a batch embedding operation.
public struct BatchEmbeddingResult: Sendable {
    /// Individual embedding results.
    public let embeddings: [EmbeddingResult]
    
    /// Total processing time.
    public let processingTime: TimeInterval
    
    /// Total tokens processed.
    public var totalTokens: Int {
        embeddings.compactMap(\.tokenCount).reduce(0, +)
    }
    
    /// Finds the most similar embedding to a query.
    public func mostSimilar(to query: EmbeddingResult) -> (result: EmbeddingResult, similarity: Float)? {
        embeddings
            .map { ($0, query.cosineSimilarity(with: $0)) }
            .max { $0.1 < $1.1 }
    }
    
    /// Ranks embeddings by similarity to a query.
    public func ranked(by query: EmbeddingResult) -> [(result: EmbeddingResult, similarity: Float)] {
        embeddings
            .map { ($0, query.cosineSimilarity(with: $0)) }
            .sorted { $0.1 > $1.1 }
    }
}
```

### Embedding Provider Extension

```swift
extension EmbeddingGenerator {
    
    /// Embeds a single text and returns just the vector.
    public func embedVector(_ text: String, model: ModelID) async throws -> [Float] {
        let result = try await embed(text, model: model)
        return result.vector
    }
    
    /// Computes similarity between two texts.
    public func similarity(
        between text1: String,
        and text2: String,
        model: ModelID
    ) async throws -> Float {
        let embedding1 = try await embed(text1, model: model)
        let embedding2 = try await embed(text2, model: model)
        return embedding1.cosineSimilarity(with: embedding2)
    }
    
    /// Finds the most similar text from candidates.
    public func findMostSimilar(
        to query: String,
        in candidates: [String],
        model: ModelID
    ) async throws -> (text: String, similarity: Float)? {
        let queryEmbedding = try await embed(query, model: model)
        let candidateEmbeddings = try await embedBatch(candidates, model: model)
        
        var best: (String, Float)?
        for (candidate, embedding) in zip(candidates, candidateEmbeddings) {
            let sim = queryEmbedding.cosineSimilarity(with: embedding)
            if best == nil || sim > best!.1 {
                best = (candidate, sim)
            }
        }
        return best
    }
}
```

---

## Transcription API

### TranscriptionConfig

```swift
/// Configuration for audio transcription.
public struct TranscriptionConfig: Sendable, Hashable {
    
    /// The language of the audio (ISO 639-1 code).
    ///
    /// If `nil`, the model will attempt auto-detection.
    public var language: String?
    
    /// Whether to include word-level timestamps.
    public var wordTimestamps: Bool
    
    /// Whether to translate to English (for non-English audio).
    public var translate: Bool
    
    /// Output format for the transcription.
    public var format: TranscriptionFormat
    
    /// Voice activity detection sensitivity.
    ///
    /// Higher values are more aggressive at filtering silence.
    /// Range: 0.0 to 1.0
    public var vadSensitivity: Float
    
    /// Initial prompt to condition the model.
    ///
    /// Can help with terminology, names, or formatting.
    public var initialPrompt: String?
    
    /// Temperature for sampling (0 = deterministic).
    public var temperature: Float
    
    // MARK: - Initialization
    
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
    
    /// Default configuration.
    public static let `default` = TranscriptionConfig()
    
    /// Configuration for detailed transcription with timestamps.
    public static let detailed = TranscriptionConfig(
        wordTimestamps: true,
        format: .detailed
    )
    
    /// Configuration for subtitle generation.
    public static let subtitles = TranscriptionConfig(
        wordTimestamps: true,
        format: .srt
    )
}

/// Output format for transcription.
public enum TranscriptionFormat: String, Sendable, Codable {
    /// Plain text output.
    case text
    
    /// Detailed JSON with timestamps and segments.
    case detailed
    
    /// SRT subtitle format.
    case srt
    
    /// WebVTT subtitle format.
    case vtt
}
```

### TranscriptionResult

```swift
/// The result of a transcription operation.
public struct TranscriptionResult: Sendable {
    
    /// The full transcribed text.
    public let text: String
    
    /// Individual segments with timing information.
    public let segments: [TranscriptionSegment]
    
    /// Detected language (ISO 639-1 code).
    public let language: String?
    
    /// Confidence in the detected language.
    public let languageConfidence: Float?
    
    /// Total duration of the audio in seconds.
    public let duration: TimeInterval
    
    /// Processing time in seconds.
    public let processingTime: TimeInterval
    
    /// Real-time factor (processing time / audio duration).
    public var realtimeFactor: Double {
        duration > 0 ? processingTime / duration : 0
    }
    
    // MARK: - Format Conversion
    
    /// Converts to SRT subtitle format.
    public func toSRT() -> String {
        segments.enumerated().map { index, segment in
            """
            \(index + 1)
            \(formatTimestamp(segment.startTime, srt: true)) --> \(formatTimestamp(segment.endTime, srt: true))
            \(segment.text.trimmingCharacters(in: .whitespaces))
            """
        }.joined(separator: "\n\n")
    }
    
    /// Converts to WebVTT subtitle format.
    public func toVTT() -> String {
        var vtt = "WEBVTT\n\n"
        vtt += segments.enumerated().map { index, segment in
            """
            \(index + 1)
            \(formatTimestamp(segment.startTime, srt: false)) --> \(formatTimestamp(segment.endTime, srt: false))
            \(segment.text.trimmingCharacters(in: .whitespaces))
            """
        }.joined(separator: "\n\n")
        return vtt
    }
    
    private func formatTimestamp(_ time: TimeInterval, srt: Bool) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        
        let separator = srt ? "," : "."
        return String(format: "%02d:%02d:%02d%@%03d", hours, minutes, seconds, separator, milliseconds)
    }
}

/// A segment of transcribed audio.
public struct TranscriptionSegment: Sendable, Hashable, Identifiable {
    public let id: Int
    
    /// Start time in seconds.
    public let startTime: TimeInterval
    
    /// End time in seconds.
    public let endTime: TimeInterval
    
    /// Transcribed text for this segment.
    public let text: String
    
    /// Word-level timing (if requested).
    public let words: [TranscriptionWord]?
    
    /// Average log probability (confidence).
    public let avgLogProb: Float?
    
    /// Compression ratio of the text.
    public let compressionRatio: Float?
    
    /// Probability of no speech in this segment.
    public let noSpeechProb: Float?
    
    /// Duration of the segment.
    public var duration: TimeInterval {
        endTime - startTime
    }
}

/// A single word with timing information.
public struct TranscriptionWord: Sendable, Hashable {
    /// The word text.
    public let word: String
    
    /// Start time in seconds.
    public let startTime: TimeInterval
    
    /// End time in seconds.
    public let endTime: TimeInterval
    
    /// Confidence score (0-1).
    public let confidence: Float?
}
```

---

## Token Counting API

### TokenCount

```swift
/// The result of a token counting operation.
public struct TokenCount: Sendable, Hashable {
    
    /// Number of tokens.
    public let count: Int
    
    /// The text that was counted.
    public let text: String
    
    /// The model/tokenizer used for counting.
    public let tokenizer: String
    
    /// Individual token IDs (if requested).
    public let tokenIds: [Int]?
    
    /// Individual token strings (if requested).
    public let tokens: [String]?
    
    // MARK: - Context Window Helpers
    
    /// Checks if this fits within a context window.
    public func fitsInContext(of size: Int) -> Bool {
        count <= size
    }
    
    /// Calculates remaining tokens in a context window.
    public func remainingIn(context size: Int) -> Int {
        max(0, size - count)
    }
    
    /// Percentage of context window used.
    public func percentageOf(context size: Int) -> Double {
        Double(count) / Double(size) * 100
    }
}

// MARK: - Common Context Window Sizes

extension Int {
    /// 4K context window (older models)
    public static let context4K = 4096
    
    /// 8K context window
    public static let context8K = 8192
    
    /// 16K context window
    public static let context16K = 16384
    
    /// 32K context window
    public static let context32K = 32768
    
    /// 128K context window (modern models)
    public static let context128K = 131072
}
```

### Token Counter Extensions

```swift
extension TokenCounter {
    
    /// Estimates whether messages fit within a context window.
    public func estimateFits(
        messages: [Message],
        model: ModelID,
        contextSize: Int,
        reserveForOutput: Int = 1024
    ) async throws -> (fits: Bool, tokens: Int, available: Int) {
        let count = try await countTokens(in: messages, for: model)
        let available = contextSize - reserveForOutput
        return (count.count <= available, count.count, available)
    }
    
    /// Truncates messages to fit within a context window.
    ///
    /// Preserves the system message and most recent messages.
    public func truncateToFit(
        messages: [Message],
        model: ModelID,
        contextSize: Int,
        reserveForOutput: Int = 1024
    ) async throws -> [Message] {
        var result = messages
        let available = contextSize - reserveForOutput
        
        while try await countTokens(in: result, for: model).count > available {
            // Find first non-system message to remove
            if let index = result.firstIndex(where: { $0.role != .system }) {
                result.remove(at: index)
            } else {
                break
            }
        }
        
        return result
    }
}
```

---

## Model Management

### ModelManager

```swift
/// Manages model downloads, caching, and lifecycle.
///
/// `ModelManager` provides a unified interface for managing models
/// across different providers. It handles downloading from HuggingFace,
/// caching, progress tracking, and cleanup.
public actor ModelManager {
    
    // MARK: - Singleton
    
    /// Shared model manager instance.
    public static let shared = ModelManager()
    
    // MARK: - Properties
    
    private let fileManager = FileManager.default
    private var activeDownloads: [String: DownloadTask] = [:]
    private let cache: ModelCache
    
    // MARK: - Initialization
    
    public init(cacheDirectory: URL? = nil) {
        let cacheDir = cacheDirectory ?? Self.defaultCacheDirectory
        self.cache = ModelCache(directory: cacheDir)
    }
    
    private static var defaultCacheDirectory: URL {
        FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SwiftAI/Models", isDirectory: true)
    }
    
    // MARK: - Discovery
    
    /// Lists all locally cached models.
    public func cachedModels() -> [CachedModelInfo] {
        cache.listModels()
    }
    
    /// Checks if a model is cached locally.
    public func isCached(_ model: ModelIdentifier) -> Bool {
        cache.exists(model)
    }
    
    /// Gets the local path for a cached model.
    public func localPath(for model: ModelIdentifier) -> URL? {
        cache.path(for: model)
    }
    
    // MARK: - Download
    
    /// Downloads a model from HuggingFace.
    ///
    /// - Parameters:
    ///   - model: The model to download.
    ///   - progress: Progress callback.
    /// - Returns: Local URL of the downloaded model.
    public func download(
        _ model: ModelIdentifier,
        progress: (@Sendable (DownloadProgress) -> Void)? = nil
    ) async throws -> URL {
        // Check if already cached
        if let path = cache.path(for: model) {
            return path
        }
        
        // Check if download in progress
        if let existing = activeDownloads[model.rawValue] {
            return try await existing.result()
        }
        
        // Start new download
        let task = DownloadTask(model: model, cache: cache)
        activeDownloads[model.rawValue] = task
        
        defer {
            activeDownloads[model.rawValue] = nil
        }
        
        if let progress {
            task.onProgress = progress
        }
        
        return try await task.start()
    }
    
    /// Creates a download task that can be observed.
    public func downloadTask(for model: ModelIdentifier) -> DownloadTask {
        if let existing = activeDownloads[model.rawValue] {
            return existing
        }
        
        let task = DownloadTask(model: model, cache: cache)
        activeDownloads[model.rawValue] = task
        return task
    }
    
    // MARK: - Cache Management
    
    /// Deletes a model from the cache.
    public func delete(_ model: ModelIdentifier) throws {
        try cache.delete(model)
    }
    
    /// Clears all cached models.
    public func clearCache() throws {
        try cache.clear()
    }
    
    /// Returns total size of cached models.
    public func cacheSize() -> ByteCount {
        cache.totalSize()
    }
    
    /// Evicts models to fit within a size limit.
    ///
    /// Removes least recently used models first.
    public func evictToFit(maxSize: ByteCount) throws {
        try cache.evictToFit(maxSize: maxSize)
    }
}
```

### DownloadTask

```swift
/// A task representing an in-progress model download.
@Observable
public final class DownloadTask: @unchecked Sendable {
    
    // MARK: - Properties
    
    /// The model being downloaded.
    public let model: ModelIdentifier
    
    /// Current download progress.
    public private(set) var progress: DownloadProgress = .init()
    
    /// Current state of the download.
    public private(set) var state: DownloadState = .pending
    
    /// Error if download failed.
    public private(set) var error: Error?
    
    // MARK: - Callbacks
    
    /// Called when progress updates.
    public var onProgress: (@Sendable (DownloadProgress) -> Void)?
    
    /// Called when download completes.
    public var onComplete: (@Sendable (Result<URL, Error>) -> Void)?
    
    // MARK: - Private
    
    private let cache: ModelCache
    private var continuation: CheckedContinuation<URL, Error>?
    private var urlTask: URLSessionDownloadTask?
    
    // MARK: - Initialization
    
    init(model: ModelIdentifier, cache: ModelCache) {
        self.model = model
        self.cache = cache
    }
    
    // MARK: - Control
    
    /// Starts the download.
    func start() async throws -> URL {
        state = .downloading
        
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            performDownload()
        }
    }
    
    /// Cancels the download.
    public func cancel() {
        urlTask?.cancel()
        state = .cancelled
        continuation?.resume(throwing: AIError.cancelled)
    }
    
    /// Pauses the download.
    public func pause() {
        urlTask?.suspend()
        state = .paused
    }
    
    /// Resumes a paused download.
    public func resume() {
        urlTask?.resume()
        state = .downloading
    }
    
    /// Awaits the download result.
    public func result() async throws -> URL {
        switch state {
        case .completed(let url):
            return url
        case .failed(let error):
            throw error
        case .cancelled:
            throw AIError.cancelled
        default:
            return try await withCheckedThrowingContinuation { cont in
                onComplete = { result in
                    switch result {
                    case .success(let url):
                        cont.resume(returning: url)
                    case .failure(let error):
                        cont.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    private func performDownload() {
        // Implementation details for HuggingFace download
        // Using URLSession with delegate for progress tracking
    }
}

/// Download progress information.
public struct DownloadProgress: Sendable {
    /// Bytes downloaded so far.
    public var bytesDownloaded: Int64 = 0
    
    /// Total bytes to download (if known).
    public var totalBytes: Int64?
    
    /// Current file being downloaded.
    public var currentFile: String?
    
    /// Files completed / total files.
    public var filesCompleted: Int = 0
    public var totalFiles: Int = 0
    
    /// Fraction completed (0.0 to 1.0).
    public var fractionCompleted: Double {
        guard let total = totalBytes, total > 0 else {
            return totalFiles > 0 ? Double(filesCompleted) / Double(totalFiles) : 0
        }
        return Double(bytesDownloaded) / Double(total)
    }
    
    /// Estimated time remaining in seconds.
    public var estimatedTimeRemaining: TimeInterval?
    
    /// Download speed in bytes per second.
    public var bytesPerSecond: Double?
}

/// State of a download task.
public enum DownloadState: Sendable {
    case pending
    case downloading
    case paused
    case completed(URL)
    case failed(Error)
    case cancelled
    
    public var isActive: Bool {
        switch self {
        case .downloading, .pending: return true
        default: return false
        }
    }
}
```

### CachedModelInfo

```swift
/// Information about a cached model.
public struct CachedModelInfo: Sendable, Identifiable {
    public var id: String { identifier.rawValue }
    
    /// The model identifier.
    public let identifier: ModelIdentifier
    
    /// Local path to the model.
    public let path: URL
    
    /// Size of the model on disk.
    public let size: ByteCount
    
    /// When the model was downloaded.
    public let downloadedAt: Date
    
    /// When the model was last accessed.
    public let lastAccessedAt: Date
    
    /// Model version/revision.
    public let revision: String?
}

/// Represents a byte count with formatting.
public struct ByteCount: Sendable, Hashable, Comparable {
    public let bytes: Int64
    
    public init(_ bytes: Int64) {
        self.bytes = bytes
    }
    
    public static func < (lhs: ByteCount, rhs: ByteCount) -> Bool {
        lhs.bytes < rhs.bytes
    }
    
    // MARK: - Formatting
    
    /// Formatted string (e.g., "4.2 GB").
    public var formatted: String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
    
    // MARK: - Convenience
    
    public static func megabytes(_ mb: Int) -> ByteCount {
        ByteCount(Int64(mb) * 1_000_000)
    }
    
    public static func gigabytes(_ gb: Int) -> ByteCount {
        ByteCount(Int64(gb) * 1_000_000_000)
    }
}
```

---

## Error Handling

### AIError

```swift
/// Errors that can occur during AI operations.
public enum AIError: Error, Sendable, LocalizedError {
    
    // MARK: - Provider Errors
    
    /// The requested provider is not available.
    case providerUnavailable(reason: UnavailabilityReason)
    
    /// The specified model was not found.
    case modelNotFound(ModelIdentifier)
    
    /// The model is not downloaded/cached.
    case modelNotCached(ModelIdentifier)
    
    /// Authentication failed.
    case authenticationFailed(String)
    
    // MARK: - Generation Errors
    
    /// Generation failed.
    case generationFailed(underlying: Error)
    
    /// Input exceeded token limit.
    case tokenLimitExceeded(count: Int, limit: Int)
    
    /// Content was filtered by safety systems.
    case contentFiltered(reason: String?)
    
    /// Generation was cancelled.
    case cancelled
    
    /// Generation timed out.
    case timeout(TimeInterval)
    
    // MARK: - Network Errors
    
    /// Network request failed.
    case networkError(URLError)
    
    /// Server returned an error.
    case serverError(statusCode: Int, message: String?)
    
    /// Rate limit exceeded.
    case rateLimited(retryAfter: TimeInterval?)
    
    // MARK: - Resource Errors
    
    /// Insufficient memory to load model.
    case insufficientMemory(required: ByteCount, available: ByteCount)
    
    /// Download failed.
    case downloadFailed(underlying: Error)
    
    /// File operation failed.
    case fileError(underlying: Error)
    
    // MARK: - Input Errors
    
    /// Invalid input provided.
    case invalidInput(String)
    
    /// Unsupported audio format.
    case unsupportedAudioFormat(String)
    
    /// Unsupported language.
    case unsupportedLanguage(String)
    
    // MARK: - LocalizedError
    
    public var errorDescription: String? {
        switch self {
        case .providerUnavailable(let reason):
            return "Provider unavailable: \(reason.description)"
        case .modelNotFound(let model):
            return "Model not found: \(model.rawValue)"
        case .modelNotCached(let model):
            return "Model not cached: \(model.rawValue). Download it first."
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
        case .generationFailed(let error):
            return "Generation failed: \(error.localizedDescription)"
        case .tokenLimitExceeded(let count, let limit):
            return "Input (\(count) tokens) exceeds limit (\(limit) tokens)"
        case .contentFiltered(let reason):
            return "Content filtered\(reason.map { ": \($0)" } ?? "")"
        case .cancelled:
            return "Operation cancelled"
        case .timeout(let duration):
            return "Operation timed out after \(Int(duration)) seconds"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let code, let message):
            return "Server error (\(code))\(message.map { ": \($0)" } ?? "")"
        case .rateLimited(let retry):
            return "Rate limited\(retry.map { ". Retry after \(Int($0)) seconds" } ?? "")"
        case .insufficientMemory(let required, let available):
            return "Insufficient memory: need \(required.formatted), have \(available.formatted)"
        case .downloadFailed(let error):
            return "Download failed: \(error.localizedDescription)"
        case .fileError(let error):
            return "File error: \(error.localizedDescription)"
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .unsupportedAudioFormat(let format):
            return "Unsupported audio format: \(format)"
        case .unsupportedLanguage(let language):
            return "Unsupported language: \(language)"
        }
    }
}

/// Reason why a provider is unavailable.
public enum UnavailabilityReason: Sendable, CustomStringConvertible {
    /// Device doesn't meet requirements.
    case deviceNotSupported
    
    /// Required OS version not met.
    case osVersionNotMet(required: String)
    
    /// Apple Intelligence not enabled.
    case appleIntelligenceDisabled
    
    /// Model still downloading.
    case modelNotReady
    
    /// No network connectivity.
    case noNetwork
    
    /// API key not configured.
    case apiKeyMissing
    
    /// Unknown reason.
    case unknown(String)
    
    public var description: String {
        switch self {
        case .deviceNotSupported:
            return "Device not supported"
        case .osVersionNotMet(let required):
            return "Requires \(required) or later"
        case .appleIntelligenceDisabled:
            return "Apple Intelligence is not enabled"
        case .modelNotReady:
            return "Model is still downloading"
        case .noNetwork:
            return "No network connectivity"
        case .apiKeyMissing:
            return "API key not configured"
        case .unknown(let reason):
            return reason
        }
    }
}
```

### Provider Availability

```swift
/// Detailed availability information for a provider.
public struct ProviderAvailability: Sendable {
    /// Whether the provider is available.
    public let isAvailable: Bool
    
    /// Reason if unavailable.
    public let unavailableReason: UnavailabilityReason?
    
    /// Device capabilities.
    public let capabilities: DeviceCapabilities?
    
    /// Recommended model size for this device.
    public let recommendedModelSize: ModelSize?
    
    public static let available = ProviderAvailability(
        isAvailable: true,
        unavailableReason: nil,
        capabilities: nil,
        recommendedModelSize: nil
    )
    
    public static func unavailable(_ reason: UnavailabilityReason) -> ProviderAvailability {
        ProviderAvailability(
            isAvailable: false,
            unavailableReason: reason,
            capabilities: nil,
            recommendedModelSize: nil
        )
    }
}

/// Device capabilities relevant to AI inference.
public struct DeviceCapabilities: Sendable {
    /// Total RAM in bytes.
    public let totalRAM: Int64
    
    /// Available RAM in bytes.
    public let availableRAM: Int64
    
    /// Chip type (e.g., "Apple M2").
    public let chipType: String?
    
    /// Neural Engine cores (if applicable).
    public let neuralEngineCores: Int?
    
    /// Whether device supports MLX.
    public let supportsMLX: Bool
    
    /// Whether device supports Foundation Models.
    public let supportsFoundationModels: Bool
}

/// Model size categories.
public enum ModelSize: String, Sendable, CaseIterable {
    case tiny = "tiny"      // < 500MB
    case small = "small"    // 500MB - 2GB
    case medium = "medium"  // 2GB - 8GB
    case large = "large"    // 8GB - 32GB
    case xlarge = "xlarge"  // > 32GB
    
    /// Approximate RAM required.
    public var approximateRAM: ByteCount {
        switch self {
        case .tiny: return .megabytes(512)
        case .small: return .gigabytes(2)
        case .medium: return .gigabytes(8)
        case .large: return .gigabytes(16)
        case .xlarge: return .gigabytes(32)
        }
    }
}
```

---

## Provider Implementations

### MLXProvider

```swift
/// MLX-based local inference provider.
///
/// Uses Apple's MLX framework for efficient on-device inference
/// on Apple Silicon. Supports text generation, embeddings, and
/// integrates with WhisperKit for transcription.
public actor MLXProvider: AIProvider, TextGenerator, EmbeddingGenerator, TokenCounter {
    
    public typealias Response = GenerationResult
    public typealias StreamChunk = GenerationChunk
    public typealias ModelID = ModelIdentifier
    
    // MARK: - Properties
    
    private let modelManager: ModelManager
    private var loadedModel: LoadedModel?
    private var loadedEmbedder: LoadedEmbedder?
    private let configuration: MLXConfiguration
    
    // MARK: - Initialization
    
    public init(
        configuration: MLXConfiguration = .default,
        modelManager: ModelManager = .shared
    ) {
        self.configuration = configuration
        self.modelManager = modelManager
    }
    
    // MARK: - Availability
    
    public var isAvailable: Bool {
        get async {
            await availabilityStatus.isAvailable
        }
    }
    
    public var availabilityStatus: ProviderAvailability {
        get async {
            #if !arch(arm64)
            return .unavailable(.deviceNotSupported)
            #endif
            
            let capabilities = await getDeviceCapabilities()
            
            guard capabilities.supportsMLX else {
                return .unavailable(.deviceNotSupported)
            }
            
            return ProviderAvailability(
                isAvailable: true,
                unavailableReason: nil,
                capabilities: capabilities,
                recommendedModelSize: recommendedSize(for: capabilities)
            )
        }
    }
    
    // MARK: - Text Generation
    
    public func generate(
        messages: [Message],
        model: ModelID,
        config: GenerateConfig
    ) async throws -> GenerationResult {
        let container = try await loadModelContainer(model)
        
        let prompt = try formatMessages(messages, for: container)
        let parameters = mapToGenerateParameters(config)
        
        let startTime = Date()
        var generatedText = ""
        var tokenCount = 0
        
        let result = try await container.perform { context in
            let input = try await context.processor.prepare(
                input: .init(prompt: prompt)
            )
            
            return try MLXLMCommon.generate(
                input: input,
                parameters: parameters,
                context: context
            ) { tokens in
                tokenCount = tokens.count
                if let maxTokens = config.maxTokens, tokens.count >= maxTokens {
                    return .stop
                }
                return .more
            }
        }
        
        generatedText = result.output
        let duration = Date().timeIntervalSince(startTime)
        
        return GenerationResult(
            text: generatedText,
            tokenCount: tokenCount,
            generationTime: duration,
            tokensPerSecond: duration > 0 ? Double(tokenCount) / duration : 0,
            finishReason: .stop
        )
    }
    
    public func stream(
        messages: [Message],
        model: ModelID,
        config: GenerateConfig
    ) -> AsyncThrowingStream<GenerationChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let container = try await loadModelContainer(model)
                    let prompt = try formatMessages(messages, for: container)
                    let parameters = mapToGenerateParameters(config)
                    
                    var tokenCount = 0
                    let startTime = Date()
                    
                    let detokenizer = NaiveStreamingDetokenizer(
                        tokenizer: await container.tokenizer
                    )
                    
                    _ = try await container.perform { context in
                        let input = try await context.processor.prepare(
                            input: .init(prompt: prompt)
                        )
                        
                        return try MLXLMCommon.generate(
                            input: input,
                            parameters: parameters,
                            context: context
                        ) { tokens in
                            tokenCount = tokens.count
                            
                            if let lastToken = tokens.last {
                                detokenizer.append(token: lastToken)
                                
                                if let text = detokenizer.next() {
                                    let elapsed = Date().timeIntervalSince(startTime)
                                    let chunk = GenerationChunk(
                                        text: text,
                                        tokenCount: 1,
                                        tokenId: lastToken,
                                        tokensPerSecond: elapsed > 0 ? Double(tokenCount) / elapsed : nil
                                    )
                                    continuation.yield(chunk)
                                }
                            }
                            
                            if let maxTokens = config.maxTokens, tokens.count >= maxTokens {
                                return .stop
                            }
                            return .more
                        }
                    }
                    
                    // Yield final chunk
                    let elapsed = Date().timeIntervalSince(startTime)
                    continuation.yield(GenerationChunk(
                        text: "",
                        tokenCount: 0,
                        isComplete: true,
                        finishReason: .stop
                    ))
                    
                    continuation.finish()
                    
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    public func cancelGeneration() async {
        // Cancel any in-flight generation
        loadedModel?.cancelGeneration()
    }
    
    // MARK: - Embeddings
    
    public func embed(_ text: String, model: ModelID) async throws -> EmbeddingResult {
        let embedder = try await loadEmbedder(model)
        let vector = try await embedder.embed(text)
        
        return EmbeddingResult(
            vector: vector,
            text: text,
            model: model.rawValue,
            tokenCount: nil
        )
    }
    
    public func embedBatch(_ texts: [String], model: ModelID) async throws -> [EmbeddingResult] {
        let embedder = try await loadEmbedder(model)
        
        return try await withThrowingTaskGroup(of: (Int, EmbeddingResult).self) { group in
            for (index, text) in texts.enumerated() {
                group.addTask {
                    let vector = try await embedder.embed(text)
                    return (index, EmbeddingResult(
                        vector: vector,
                        text: text,
                        model: model.rawValue,
                        tokenCount: nil
                    ))
                }
            }
            
            var results = Array(repeating: EmbeddingResult?.none, count: texts.count)
            for try await (index, result) in group {
                results[index] = result
            }
            return results.compactMap { $0 }
        }
    }
    
    // MARK: - Token Counting
    
    public func countTokens(in text: String, for model: ModelID) async throws -> TokenCount {
        let container = try await loadModelContainer(model)
        let tokenizer = await container.tokenizer
        let tokens = tokenizer.encode(text: text)
        
        return TokenCount(
            count: tokens.count,
            text: text,
            tokenizer: model.rawValue,
            tokenIds: tokens,
            tokens: tokens.map { tokenizer.decode(tokens: [$0]) }
        )
    }
    
    public func countTokens(in messages: [Message], for model: ModelID) async throws -> TokenCount {
        let container = try await loadModelContainer(model)
        let prompt = try formatMessages(messages, for: container)
        return try await countTokens(in: prompt, for: model)
    }
    
    public func encode(_ text: String, for model: ModelID) async throws -> [Int] {
        let container = try await loadModelContainer(model)
        return await container.tokenizer.encode(text: text)
    }
    
    public func decode(_ tokens: [Int], for model: ModelID, skipSpecialTokens: Bool) async throws -> String {
        let container = try await loadModelContainer(model)
        return await container.tokenizer.decode(tokens: tokens, skipSpecialTokens: skipSpecialTokens)
    }
    
    // MARK: - Private Helpers
    
    private func loadModelContainer(_ model: ModelID) async throws -> ModelContainer {
        // Check if already loaded
        if let loaded = loadedModel, loaded.modelId == model {
            return loaded.container
        }
        
        // Ensure model is downloaded
        guard let localPath = await modelManager.localPath(for: model) else {
            throw AIError.modelNotCached(model)
        }
        
        // Load the model
        let configuration = ModelConfiguration(id: model.rawValue)
        let container = try await LLMModelFactory.shared.loadContainer(
            configuration: configuration
        ) { progress in
            // Loading progress
        }
        
        loadedModel = LoadedModel(modelId: model, container: container)
        return container
    }
    
    private func loadEmbedder(_ model: ModelID) async throws -> EmbedderContainer {
        // Similar to loadModelContainer but for embedding models
        // ...
    }
    
    private func formatMessages(_ messages: [Message], for container: ModelContainer) throws -> String {
        // Use chat template if available
        // ...
    }
    
    private func mapToGenerateParameters(_ config: GenerateConfig) -> GenerateParameters {
        GenerateParameters(
            temperature: config.temperature,
            topP: config.topP,
            repetitionPenalty: config.repetitionPenalty
        )
    }
    
    private func getDeviceCapabilities() async -> DeviceCapabilities {
        // Query device info
        // ...
    }
    
    private func recommendedSize(for capabilities: DeviceCapabilities) -> ModelSize {
        let ram = capabilities.totalRAM
        switch ram {
        case ..<(4 * 1_000_000_000): return .tiny
        case ..<(8 * 1_000_000_000): return .small
        case ..<(16 * 1_000_000_000): return .medium
        case ..<(32 * 1_000_000_000): return .large
        default: return .xlarge
        }
    }
}

/// MLX-specific configuration.
public struct MLXConfiguration: Sendable {
    /// Memory limit for model loading.
    public var memoryLimit: ByteCount?
    
    /// Whether to use quantized models.
    public var preferQuantized: Bool
    
    /// Default configuration.
    public static let `default` = MLXConfiguration(
        memoryLimit: nil,
        preferQuantized: true
    )
}

private struct LoadedModel {
    let modelId: ModelIdentifier
    let container: ModelContainer
    
    func cancelGeneration() {
        // Implementation
    }
}
```

### HuggingFaceProvider

```swift
/// HuggingFace Inference API provider.
///
/// Uses HuggingFace's cloud infrastructure for inference.
/// Requires a HuggingFace API token for authentication.
public actor HuggingFaceProvider: AIProvider, TextGenerator, EmbeddingGenerator, Transcriber {
    
    public typealias Response = GenerationResult
    public typealias StreamChunk = GenerationChunk
    public typealias ModelID = ModelIdentifier
    
    // MARK: - Properties
    
    private let client: HFInferenceClient
    private let configuration: HFConfiguration
    
    // MARK: - Initialization
    
    public init(configuration: HFConfiguration = .default) throws {
        self.configuration = configuration
        self.client = try HFInferenceClient(configuration: configuration)
    }
    
    /// Creates a provider with an explicit API token.
    public init(token: String) {
        self.configuration = HFConfiguration(token: .static(token))
        self.client = HFInferenceClient(configuration: configuration)
    }
    
    // MARK: - Availability
    
    public var isAvailable: Bool {
        get async {
            await availabilityStatus.isAvailable
        }
    }
    
    public var availabilityStatus: ProviderAvailability {
        get async {
            // Check network connectivity
            guard await NetworkMonitor.shared.isConnected else {
                return .unavailable(.noNetwork)
            }
            
            // Check API key
            guard configuration.hasToken else {
                return .unavailable(.apiKeyMissing)
            }
            
            return .available
        }
    }
    
    // MARK: - Text Generation
    
    public func generate(
        messages: [Message],
        model: ModelID,
        config: GenerateConfig
    ) async throws -> GenerationResult {
        let request = HFChatCompletionRequest(
            model: model.rawValue,
            messages: messages.map { HFMessage(from: $0) },
            maxTokens: config.maxTokens,
            temperature: config.temperature,
            topP: config.topP,
            stop: config.stopSequences.isEmpty ? nil : config.stopSequences
        )
        
        let startTime = Date()
        let response = try await client.chatCompletion(request)
        let duration = Date().timeIntervalSince(startTime)
        
        let text = response.choices.first?.message.content ?? ""
        let tokenCount = response.usage?.completionTokens ?? 0
        
        return GenerationResult(
            text: text,
            tokenCount: tokenCount,
            generationTime: duration,
            tokensPerSecond: duration > 0 ? Double(tokenCount) / duration : 0,
            finishReason: mapFinishReason(response.choices.first?.finishReason),
            usage: UsageStats(
                promptTokens: response.usage?.promptTokens ?? 0,
                completionTokens: response.usage?.completionTokens ?? 0
            )
        )
    }
    
    public func stream(
        messages: [Message],
        model: ModelID,
        config: GenerateConfig
    ) -> AsyncThrowingStream<GenerationChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let request = HFChatCompletionRequest(
                        model: model.rawValue,
                        messages: messages.map { HFMessage(from: $0) },
                        maxTokens: config.maxTokens,
                        temperature: config.temperature,
                        topP: config.topP,
                        stop: config.stopSequences.isEmpty ? nil : config.stopSequences,
                        stream: true
                    )
                    
                    var tokenCount = 0
                    let startTime = Date()
                    
                    for try await event in client.streamChatCompletion(request) {
                        tokenCount += 1
                        let elapsed = Date().timeIntervalSince(startTime)
                        
                        let chunk = GenerationChunk(
                            text: event.choices.first?.delta?.content ?? "",
                            tokenCount: 1,
                            tokensPerSecond: elapsed > 0 ? Double(tokenCount) / elapsed : nil,
                            isComplete: event.choices.first?.finishReason != nil,
                            finishReason: mapFinishReason(event.choices.first?.finishReason)
                        )
                        
                        continuation.yield(chunk)
                    }
                    
                    continuation.finish()
                    
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    public func cancelGeneration() async {
        // Cancel via task cancellation
    }
    
    // MARK: - Embeddings
    
    public func embed(_ text: String, model: ModelID) async throws -> EmbeddingResult {
        let response = try await client.featureExtraction(
            model: model.rawValue,
            text: text
        )
        
        return EmbeddingResult(
            vector: response.embeddings,
            text: text,
            model: model.rawValue,
            tokenCount: nil
        )
    }
    
    public func embedBatch(_ texts: [String], model: ModelID) async throws -> [EmbeddingResult] {
        let response = try await client.featureExtraction(
            model: model.rawValue,
            texts: texts
        )
        
        return zip(texts, response.embeddings).map { text, vector in
            EmbeddingResult(
                vector: vector,
                text: text,
                model: model.rawValue,
                tokenCount: nil
            )
        }
    }
    
    // MARK: - Transcription
    
    public func transcribe(
        audioURL url: URL,
        model: ModelID,
        config: TranscriptionConfig
    ) async throws -> TranscriptionResult {
        let data = try Data(contentsOf: url)
        return try await transcribe(audioData: data, model: model, config: config)
    }
    
    public func transcribe(
        audioData data: Data,
        model: ModelID,
        config: TranscriptionConfig
    ) async throws -> TranscriptionResult {
        let startTime = Date()
        
        let response = try await client.automaticSpeechRecognition(
            model: model.rawValue,
            audio: data,
            language: config.language,
            returnTimestamps: config.wordTimestamps
        )
        
        let duration = Date().timeIntervalSince(startTime)
        
        return TranscriptionResult(
            text: response.text,
            segments: response.chunks?.map { chunk in
                TranscriptionSegment(
                    id: 0,
                    startTime: chunk.timestamp.0,
                    endTime: chunk.timestamp.1,
                    text: chunk.text,
                    words: nil,
                    avgLogProb: nil,
                    compressionRatio: nil,
                    noSpeechProb: nil
                )
            } ?? [],
            language: config.language,
            languageConfidence: nil,
            duration: 0, // Would need audio duration
            processingTime: duration
        )
    }
    
    public func streamTranscription(
        audioURL url: URL,
        model: ModelID,
        config: TranscriptionConfig
    ) -> AsyncThrowingStream<TranscriptionSegment, Error> {
        // HuggingFace API doesn't support streaming transcription
        // Fall back to full transcription
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let result = try await transcribe(audioURL: url, model: model, config: config)
                    for segment in result.segments {
                        continuation.yield(segment)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Private
    
    private func mapFinishReason(_ reason: String?) -> FinishReason {
        switch reason {
        case "stop": return .stop
        case "length": return .maxTokens
        case "content_filter": return .contentFilter
        default: return .stop
        }
    }
}

/// HuggingFace provider configuration.
public struct HFConfiguration: Sendable {
    /// Token provider for authentication.
    public var token: HFTokenProvider
    
    /// Base URL for API requests.
    public var baseURL: URL
    
    /// Request timeout.
    public var timeout: TimeInterval
    
    /// Whether a token is configured.
    var hasToken: Bool {
        token.token != nil
    }
    
    public init(
        token: HFTokenProvider = .auto,
        baseURL: URL = URL(string: "https://api-inference.huggingface.co")!,
        timeout: TimeInterval = 60
    ) {
        self.token = token
        self.baseURL = baseURL
        self.timeout = timeout
    }
    
    public static let `default` = HFConfiguration()
}

/// Provides authentication tokens for HuggingFace API.
public enum HFTokenProvider: Sendable {
    /// Auto-detect token from environment.
    case auto
    
    /// Static token value.
    case `static`(String)
    
    /// Load from Keychain.
    case keychain(service: String, account: String)
    
    /// Resolved token value.
    var token: String? {
        switch self {
        case .auto:
            return ProcessInfo.processInfo.environment["HF_TOKEN"]
                ?? ProcessInfo.processInfo.environment["HUGGING_FACE_HUB_TOKEN"]
        case .static(let value):
            return value
        case .keychain(let service, let account):
            return KeychainHelper.read(service: service, account: account)
        }
    }
}
```

### FoundationModelsProvider

```swift
/// Apple Foundation Models provider.
///
/// Uses Apple's on-device language model available on iOS 26+.
/// Provides structured output generation via @Generable types.
@available(iOS 26.0, macOS 26.0, *)
public actor FoundationModelsProvider: AIProvider, TextGenerator {
    
    public typealias Response = GenerationResult
    public typealias StreamChunk = GenerationChunk
    public typealias ModelID = ModelIdentifier
    
    // MARK: - Properties
    
    private var session: LanguageModelSession?
    private let configuration: FMConfiguration
    
    // MARK: - Initialization
    
    public init(configuration: FMConfiguration = .default) {
        self.configuration = configuration
    }
    
    // MARK: - Availability
    
    public var isAvailable: Bool {
        get async {
            await availabilityStatus.isAvailable
        }
    }
    
    public var availabilityStatus: ProviderAvailability {
        get async {
            let availability = SystemLanguageModel.default.availability
            
            switch availability {
            case .available:
                return .available
            case .unavailable(let reason):
                switch reason {
                case .appleIntelligenceNotEnabled:
                    return .unavailable(.appleIntelligenceDisabled)
                case .deviceNotEligible:
                    return .unavailable(.deviceNotSupported)
                case .modelNotReady:
                    return .unavailable(.modelNotReady)
                @unknown default:
                    return .unavailable(.unknown("Unknown availability reason"))
                }
            @unknown default:
                return .unavailable(.unknown("Unknown availability status"))
            }
        }
    }
    
    // MARK: - Text Generation
    
    public func generate(
        messages: [Message],
        model: ModelID,
        config: GenerateConfig
    ) async throws -> GenerationResult {
        let session = getOrCreateSession()
        
        let startTime = Date()
        
        // Build prompt from messages
        let prompt = buildPrompt(from: messages)
        
        let response = try await session.respond(to: prompt)
        
        let duration = Date().timeIntervalSince(startTime)
        
        return GenerationResult(
            text: response.content,
            tokenCount: 0, // FM doesn't expose token count
            generationTime: duration,
            tokensPerSecond: 0,
            finishReason: .stop
        )
    }
    
    public func stream(
        messages: [Message],
        model: ModelID,
        config: GenerateConfig
    ) -> AsyncThrowingStream<GenerationChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let session = getOrCreateSession()
                    let prompt = buildPrompt(from: messages)
                    
                    let startTime = Date()
                    var tokenCount = 0
                    
                    for try await partial in session.streamResponse(to: prompt) {
                        tokenCount += 1
                        let elapsed = Date().timeIntervalSince(startTime)
                        
                        let chunk = GenerationChunk(
                            text: partial,
                            tokenCount: 1,
                            tokensPerSecond: elapsed > 0 ? Double(tokenCount) / elapsed : nil
                        )
                        
                        continuation.yield(chunk)
                    }
                    
                    continuation.yield(GenerationChunk(
                        text: "",
                        isComplete: true,
                        finishReason: .stop
                    ))
                    
                    continuation.finish()
                    
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    public func cancelGeneration() async {
        // Foundation Models doesn't support explicit cancellation
        // Rely on task cancellation
    }
    
    // MARK: - Structured Generation
    
    /// Generates a structured output conforming to a Generable type.
    public func generate<T: Generable>(
        messages: [Message],
        generating type: T.Type,
        config: GenerateConfig
    ) async throws -> T {
        let session = getOrCreateSession()
        let prompt = buildPrompt(from: messages)
        
        let response = try await session.respond(to: prompt, generating: type)
        return response.content
    }
    
    /// Streams structured generation with partial updates.
    public func stream<T: Generable>(
        messages: [Message],
        generating type: T.Type,
        config: GenerateConfig
    ) -> AsyncThrowingStream<T.PartiallyGenerated, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let session = getOrCreateSession()
                    let prompt = buildPrompt(from: messages)
                    
                    for try await partial in session.streamResponse(to: prompt, generating: type) {
                        continuation.yield(partial)
                    }
                    
                    continuation.finish()
                    
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Session Management
    
    /// Sets system instructions for the session.
    public func setInstructions(_ instructions: String) {
        session = LanguageModelSession(instructions: Instructions(instructions))
    }
    
    /// Clears the current session and starts fresh.
    public func clearSession() {
        session = nil
    }
    
    /// Prewarms the model for faster first response.
    public func prewarm(promptPrefix: String? = nil) async {
        let session = getOrCreateSession()
        await session.prewarm(promptPrefix: promptPrefix)
    }
    
    // MARK: - Private
    
    private func getOrCreateSession() -> LanguageModelSession {
        if let existing = session {
            return existing
        }
        
        let newSession: LanguageModelSession
        if let instructions = configuration.instructions {
            newSession = LanguageModelSession(instructions: Instructions(instructions))
        } else {
            newSession = LanguageModelSession()
        }
        
        session = newSession
        return newSession
    }
    
    private func buildPrompt(from messages: [Message]) -> Prompt {
        // Extract system message for instructions
        // Build user/assistant conversation
        let conversationText = messages
            .filter { $0.role != .system }
            .map { message -> String in
                switch message.role {
                case .user: return "User: \(message.content.textValue)"
                case .assistant: return "Assistant: \(message.content.textValue)"
                default: return message.content.textValue
                }
            }
            .joined(separator: "\n\n")
        
        return Prompt(conversationText)
    }
}

/// Foundation Models configuration.
public struct FMConfiguration: Sendable {
    /// System instructions.
    public var instructions: String?
    
    /// Whether to prewarm on initialization.
    public var prewarmOnInit: Bool
    
    public init(
        instructions: String? = nil,
        prewarmOnInit: Bool = false
    ) {
        self.instructions = instructions
        self.prewarmOnInit = prewarmOnInit
    }
    
    public static let `default` = FMConfiguration()
}
```

---

## Result Builders

### MessageBuilder

```swift
/// Result builder for declaratively constructing message arrays.
///
/// ## Usage
/// ```swift
/// let messages = Messages {
///     Message.system("You are helpful.")
///     Message.user("Hello!")
///     
///     if includeContext {
///         Message.user(context)
///     }
/// }
/// ```
@resultBuilder
public struct MessageBuilder {
    
    public static func buildBlock(_ components: Message...) -> [Message] {
        components
    }
    
    public static func buildBlock(_ components: [Message]...) -> [Message] {
        components.flatMap { $0 }
    }
    
    public static func buildOptional(_ component: [Message]?) -> [Message] {
        component ?? []
    }
    
    public static func buildEither(first component: [Message]) -> [Message] {
        component
    }
    
    public static func buildEither(second component: [Message]) -> [Message] {
        component
    }
    
    public static func buildArray(_ components: [[Message]]) -> [Message] {
        components.flatMap { $0 }
    }
    
    public static func buildExpression(_ expression: Message) -> [Message] {
        [expression]
    }
    
    public static func buildExpression(_ expression: [Message]) -> [Message] {
        expression
    }
}

/// Creates a message array using the MessageBuilder.
public func Messages(@MessageBuilder _ builder: () -> [Message]) -> [Message] {
    builder()
}
```

### PromptBuilder

```swift
/// Result builder for constructing prompts from components.
///
/// ## Usage
/// ```swift
/// let prompt = Prompt {
///     SystemInstruction("You are a helpful assistant.")
///     
///     Context(documents)
///     
///     UserQuery(userInput)
///     
///     if useExamples {
///         Examples(fewShotExamples)
///     }
/// }
/// ```
@resultBuilder
public struct PromptBuilder {
    
    public static func buildBlock(_ components: PromptComponent...) -> PromptContent {
        PromptContent(components: components)
    }
    
    public static func buildOptional(_ component: PromptComponent?) -> PromptComponent {
        component ?? EmptyComponent()
    }
    
    public static func buildEither(first component: PromptComponent) -> PromptComponent {
        component
    }
    
    public static func buildEither(second component: PromptComponent) -> PromptComponent {
        component
    }
    
    public static func buildArray(_ components: [PromptComponent]) -> PromptComponent {
        CompositeComponent(components: components)
    }
}

/// A component that can be part of a prompt.
public protocol PromptComponent: Sendable {
    /// Renders this component to a string.
    func render() -> String
}

/// The final composed prompt content.
public struct PromptContent: PromptComponent, Sendable {
    let components: [PromptComponent]
    
    public func render() -> String {
        components.map { $0.render() }.joined(separator: "\n\n")
    }
    
    /// Converts to a Message array.
    public func toMessages() -> [Message] {
        // Parse components into appropriate messages
        // ...
    }
}

// MARK: - Built-in Components

/// System instruction component.
public struct SystemInstruction: PromptComponent {
    let text: String
    
    public init(_ text: String) {
        self.text = text
    }
    
    public func render() -> String {
        text
    }
}

/// User query component.
public struct UserQuery: PromptComponent {
    let text: String
    
    public init(_ text: String) {
        self.text = text
    }
    
    public func render() -> String {
        text
    }
}

/// Context/document injection component.
public struct Context: PromptComponent {
    let documents: [String]
    let header: String?
    
    public init(_ documents: [String], header: String? = "Context:") {
        self.documents = documents
        self.header = header
    }
    
    public func render() -> String {
        var result = header ?? ""
        if !result.isEmpty { result += "\n" }
        result += documents.enumerated()
            .map { "[\($0.offset + 1)] \($0.element)" }
            .joined(separator: "\n")
        return result
    }
}

/// Few-shot examples component.
public struct Examples: PromptComponent {
    let examples: [(input: String, output: String)]
    
    public init(_ examples: [(input: String, output: String)]) {
        self.examples = examples
    }
    
    public func render() -> String {
        examples.map { example in
            "Input: \(example.input)\nOutput: \(example.output)"
        }.joined(separator: "\n\n")
    }
}

struct EmptyComponent: PromptComponent {
    func render() -> String { "" }
}

struct CompositeComponent: PromptComponent {
    let components: [PromptComponent]
    
    func render() -> String {
        components.map { $0.render() }.joined(separator: "\n")
    }
}
```

---

## Macros

### @Generable Macro

SwiftAI provides a `@Generable` macro similar to Apple's Foundation Models framework, enabling type-safe structured output generation.

```swift
/// Marks a type as generable by language models.
///
/// The macro generates:
/// - A JSON schema representation
/// - A `PartiallyGenerated` companion type for streaming
/// - Decoding initializers for parsing model output
///
/// ## Usage
/// ```swift
/// @Generable
/// struct Recipe {
///     @Guide(description: "Name of the dish")
///     let name: String
///     
///     @Guide(description: "List of ingredients")
///     let ingredients: [String]
///     
///     @Guide(description: "Preparation steps")
///     let steps: [String]
///     
///     @Guide(.range(1...5))
///     let difficulty: Int
/// }
/// ```
@attached(member, names: named(PartiallyGenerated), named(schema), named(init(from:)))
@attached(extension, conformances: Generable)
public macro Generable() = #externalMacro(module: "SwiftAIMacros", type: "GenerableMacro")

/// Provides guidance to the model for generating a property.
@attached(peer)
public macro Guide(
    description: String? = nil,
    _ constraints: GuideConstraint...
) = #externalMacro(module: "SwiftAIMacros", type: "GuideMacro")

/// Constraints that can be applied via @Guide.
public enum GuideConstraint: Sendable {
    /// Value must be in range.
    case range(ClosedRange<Int>)
    
    /// Value must be one of the specified options.
    case anyOf([String])
    
    /// Array must have exactly this count.
    case count(Int)
    
    /// Array count must be in range.
    case countRange(ClosedRange<Int>)
    
    /// String must match pattern.
    case pattern(String)
    
    /// Custom constraint description.
    case custom(String)
}

/// Protocol that @Generable types conform to.
public protocol Generable: Sendable, Codable {
    /// The partially generated version of this type.
    associatedtype PartiallyGenerated: Sendable
    
    /// JSON schema for this type.
    static var schema: GenerableSchema { get }
}

/// Schema describing a Generable type.
public struct GenerableSchema: Sendable {
    public let typeName: String
    public let properties: [PropertySchema]
    
    public struct PropertySchema: Sendable {
        public let name: String
        public let type: String
        public let description: String?
        public let constraints: [GuideConstraint]
    }
    
    /// Converts to JSON Schema format.
    public func toJSONSchema() -> [String: Any] {
        // Generate JSON Schema representation
        // ...
    }
}
```

---

## Convenience Extensions

### String Extensions

```swift
extension String {
    /// Generates a response using the specified model.
    ///
    /// ## Usage
    /// ```swift
    /// let response = try await "Explain Swift concurrency"
    ///     .generate(with: provider, model: .llama3_2_1B)
    /// ```
    public func generate<P: AIProvider & TextGenerator>(
        with provider: P,
        model: P.ModelID,
        config: GenerateConfig = .default
    ) async throws -> String {
        try await provider.generate(self, model: model, config: config)
    }
    
    /// Streams a response using the specified model.
    public func stream<P: AIProvider & TextGenerator>(
        with provider: P,
        model: P.ModelID,
        config: GenerateConfig = .default
    ) -> AsyncThrowingStream<String, Error> {
        provider.stream(self, model: model, config: config)
    }
    
    /// Generates an embedding for this string.
    public func embed<P: EmbeddingGenerator>(
        with provider: P,
        model: P.ModelID
    ) async throws -> EmbeddingResult {
        try await provider.embed(self, model: model)
    }
    
    /// Counts tokens in this string.
    public func tokenCount<P: TokenCounter>(
        with provider: P,
        model: P.ModelID
    ) async throws -> Int {
        try await provider.countTokens(in: self, for: model).count
    }
}
```

### URL Extensions

```swift
extension URL {
    /// Transcribes audio at this URL.
    ///
    /// ## Usage
    /// ```swift
    /// let transcription = try await audioURL
    ///     .transcribe(with: provider, model: .whisperLarge)
    /// ```
    public func transcribe<P: Transcriber>(
        with provider: P,
        model: P.ModelID,
        config: TranscriptionConfig = .default
    ) async throws -> TranscriptionResult {
        try await provider.transcribe(audioURL: self, model: model, config: config)
    }
}
```

### Array Extensions

```swift
extension Array where Element == Message {
    /// Generates a response from this message array.
    public func generate<P: AIProvider & TextGenerator>(
        with provider: P,
        model: P.ModelID,
        config: GenerateConfig = .default
    ) async throws -> GenerationResult {
        try await provider.generate(messages: self, model: model, config: config)
    }
    
    /// Streams a response from this message array.
    public func stream<P: AIProvider & TextGenerator>(
        with provider: P,
        model: P.ModelID,
        config: GenerateConfig = .default
    ) -> AsyncThrowingStream<GenerationChunk, Error> {
        provider.stream(messages: self, model: model, config: config)
    }
    
    /// Counts total tokens in all messages.
    public func tokenCount<P: TokenCounter>(
        with provider: P,
        model: P.ModelID
    ) async throws -> Int {
        try await provider.countTokens(in: self, for: model).count
    }
}

extension Array where Element == String {
    /// Generates embeddings for all strings.
    public func embed<P: EmbeddingGenerator>(
        with provider: P,
        model: P.ModelID
    ) async throws -> [EmbeddingResult] {
        try await provider.embedBatch(self, model: model)
    }
}
```

---

## Usage Examples

### Basic Text Generation

```swift
import SwiftAI

// Initialize provider
let provider = MLXProvider()

// Check availability
guard await provider.isAvailable else {
    print("MLX not available on this device")
    return
}

// Simple generation
let response = try await provider.generate(
    "Explain quantum computing in simple terms",
    model: .llama3_2_1B,
    config: .default
)
print(response)

// Generation with custom config
let creativeResponse = try await provider.generate(
    "Write a haiku about Swift programming",
    model: .llama3_2_3B,
    config: .creative
)
```

### Streaming Generation

```swift
// Stream tokens as they generate
print("Assistant: ", terminator: "")
for try await chunk in provider.stream(
    "Write a short story about a robot",
    model: .llama3_2_1B,
    config: .default
) {
    print(chunk, terminator: "")
    fflush(stdout)
}
print()

// Stream with metadata
for try await chunk in provider.streamWithMetadata(
    messages: [.user("Hello!")],
    model: .llama3_2_1B,
    config: .default
) {
    print("\(chunk.text) [\(chunk.tokensPerSecond ?? 0) tok/s]")
}
```

### Chat Session

```swift
// Create a chat session
let session = ChatSession(provider: provider, model: .llama3_2_1B)

// Set system prompt
session.setSystemPrompt("You are a helpful cooking assistant.")

// Have a conversation
let response1 = try await session.send("How do I make pasta carbonara?")
print("Assistant:", response1)

let response2 = try await session.send("What wine pairs well with it?")
print("Assistant:", response2)

// Stream a response
print("Assistant: ", terminator: "")
for try await text in session.stream("Give me a vegetarian alternative") {
    print(text, terminator: "")
}
print()

// Access history
print("Conversation has \(session.messages.count) messages")
```

### Multiple Providers

```swift
// Local inference
let mlxProvider = MLXProvider()

// Cloud inference
let hfProvider = try HuggingFaceProvider(token: "hf_xxx")

// Apple Foundation Models (iOS 26+)
if #available(iOS 26.0, *) {
    let appleProvider = FoundationModelsProvider()
    
    let response = try await appleProvider.generate(
        messages: [.user("Hello!")],
        model: .foundationModels,
        config: .default
    )
}

// Use appropriate provider based on context
let provider: any TextGenerator = await mlxProvider.isAvailable 
    ? mlxProvider 
    : hfProvider

let response = try await provider.generate(
    "Hello!",
    model: .llama3_2_1B,
    config: .default
)
```

### Embeddings and Similarity

```swift
let provider = MLXProvider()

// Generate embeddings
let queryEmbedding = try await provider.embed(
    "How do I cook pasta?",
    model: .bgeSmall
)

// Embed documents
let documents = [
    "Pasta should be cooked in salted boiling water",
    "Swift is a programming language by Apple",
    "Italian cuisine features many pasta dishes"
]

let docEmbeddings = try await provider.embedBatch(documents, model: .bgeSmall)

// Find most similar
let ranked = docEmbeddings
    .map { ($0.text, queryEmbedding.cosineSimilarity(with: $0)) }
    .sorted { $0.1 > $1.1 }

for (doc, similarity) in ranked {
    print("[\(String(format: "%.2f", similarity))] \(doc)")
}
```

### Transcription

```swift
let provider = try HuggingFaceProvider(token: "hf_xxx")

// Transcribe audio file
let result = try await provider.transcribe(
    audioURL: audioFileURL,
    model: .huggingFace("openai/whisper-large-v3"),
    config: TranscriptionConfig(
        language: "en",
        wordTimestamps: true
    )
)

print("Transcription:", result.text)
print("Duration:", result.duration, "seconds")

// Generate subtitles
let srtContent = result.toSRT()
try srtContent.write(to: subtitlesURL, atomically: true, encoding: .utf8)
```

### Model Management

```swift
let manager = ModelManager.shared

// Check if model is cached
if await manager.isCached(.llama3_2_1B) {
    print("Model already downloaded")
} else {
    // Download with progress
    let url = try await manager.download(.llama3_2_1B) { progress in
        print("Downloading: \(Int(progress.fractionCompleted * 100))%")
    }
    print("Downloaded to:", url)
}

// List cached models
let cached = await manager.cachedModels()
for model in cached {
    print("\(model.identifier.displayName): \(model.size.formatted)")
}

// Check cache size
let totalSize = await manager.cacheSize()
print("Total cache size:", totalSize.formatted)

// Clean up
try await manager.delete(.llama3_2_1B)
```

### Token Counting for Context Management

```swift
let provider = MLXProvider()

// Count tokens in a message
let count = try await provider.countTokens(
    in: "Hello, how are you?",
    for: .llama3_2_1B
)
print("Token count:", count.count)

// Check if messages fit in context
let messages: [Message] = [
    .system("You are helpful."),
    .user(longDocument),
    .user("Summarize this.")
]

let (fits, tokens, available) = try await provider.estimateFits(
    messages: messages,
    model: .llama3_2_1B,
    contextSize: .context4K,
    reserveForOutput: 512
)

if !fits {
    print("Messages too long (\(tokens) tokens). Truncating...")
    let truncated = try await provider.truncateToFit(
        messages: messages,
        model: .llama3_2_1B,
        contextSize: .context4K
    )
    // Use truncated messages
}
```

### Using Result Builders

```swift
// Build messages declaratively
let messages = Messages {
    Message.system("You are a helpful assistant.")
    
    if let context = retrievedContext {
        Message.user("Context: \(context)")
    }
    
    Message.user(userQuestion)
}

// Build prompts with components
let prompt = Prompt {
    SystemInstruction("You are a helpful assistant.")
    
    Context(documents, header: "Reference Documents:")
    
    if useExamples {
        Examples([
            ("What is 2+2?", "4"),
            ("What is the capital of France?", "Paris")
        ])
    }
    
    UserQuery(userQuestion)
}
```

---

## Appendix: Type Summary

### Core Types

| Type | Kind | Description |
|------|------|-------------|
| `AIProvider` | Protocol | Main provider abstraction |
| `TextGenerator` | Protocol | Text generation capability |
| `EmbeddingGenerator` | Protocol | Embedding generation capability |
| `Transcriber` | Protocol | Audio transcription capability |
| `TokenCounter` | Protocol | Token counting capability |
| `ModelManaging` | Protocol | Model lifecycle management |
| `ModelIdentifier` | Enum | Identifies models across providers |
| `Message` | Struct | Chat message |
| `GenerateConfig` | Struct | Generation parameters |
| `GenerationResult` | Struct | Complete generation output |
| `GenerationChunk` | Struct | Streaming chunk |
| `EmbeddingResult` | Struct | Embedding output |
| `TranscriptionResult` | Struct | Transcription output |
| `TokenCount` | Struct | Token counting result |
| `AIError` | Enum | Error types |

### Provider Implementations

| Type | Provider | Capabilities |
|------|----------|--------------|
| `MLXProvider` | MLX | Text, Embeddings, Token Counting |
| `HuggingFaceProvider` | HuggingFace | Text, Embeddings, Transcription |
| `FoundationModelsProvider` | Apple | Text, Structured Output |

### Supporting Types

| Type | Description |
|------|-------------|
| `ChatSession` | Stateful conversation manager |
| `ModelManager` | Model download/cache manager |
| `DownloadTask` | Observable download task |
| `GenerationStream` | Async stream wrapper |
| `ProviderAvailability` | Availability status |
| `DeviceCapabilities` | Device info for inference |

---

*End of SwiftAI API Specification*
