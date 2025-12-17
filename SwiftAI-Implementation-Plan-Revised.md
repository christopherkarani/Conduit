# SwiftAI Framework Implementation Plan (Revised)

> **Version:** 1.1.0  
> **Created:** December 2025  
> **Estimated Duration:** 8-12 weeks  
> **Swift Version:** 6.2  
> **Platforms:** iOS 17+, macOS 14+, visionOS 1+  
> **Companion Document:** SwiftAI-API-Specification.md (source of truth for API signatures)

---

## How to Use This Document

1. **This plan** defines WHAT to build and in WHAT ORDER
2. **The API Specification** defines EXACT signatures and implementations
3. When implementing, reference both documents
4. Checkboxes track completion status

---

## Executive Summary

SwiftAI is a unified Swift SDK providing a clean, idiomatic interface for LLM inference across three providers:

| Provider | Use Case | Connectivity | Capabilities |
|----------|----------|--------------|--------------|
| **MLX** | Local inference on Apple Silicon | Offline | Text, Embeddings, Token Counting |
| **HuggingFace** | Cloud inference via HF Inference API | Online | Text, Embeddings, Transcription |
| **Apple Foundation Models** | System-integrated on-device AI (iOS 26+) | Offline | Text, Structured Output |

### Key Dependencies

```swift
// Package.swift dependencies
.package(url: "https://github.com/ml-explore/mlx-swift", from: "0.21.0"),
.package(url: "https://github.com/ml-explore/mlx-swift-examples", branch: "main"),
.package(url: "https://github.com/huggingface/swift-transformers", from: "0.1.0"),
.package(url: "https://github.com/huggingface/swift-huggingface-hub", from: "0.1.0"),
.package(url: "https://github.com/apple/swift-syntax", from: "509.0.0"), // For macros
```

### Design Principles

1. **Explicit Model Selection** — No "magic" auto-selection; developers choose their provider
2. **Swift 6.2 Concurrency** — Actors, Sendable types, AsyncSequence throughout
3. **Protocol-Oriented** — Provider abstraction via protocols with associated types
4. **Composable** — Designed to work with external orchestration layers (SwiftAgents)

---

## Implementation Phases Overview

| Phase | Description | Duration | Key Deliverables |
|-------|-------------|----------|------------------|
| 1 | Project Setup & Package Structure | Week 1 | Package.swift, directory structure |
| 2 | Core Protocols & Type System | Week 1-2 | 6 protocols |
| 3 | Model Identification System | Week 2 | ModelIdentifier, ProviderType, ModelInfo |
| 4 | Message Types & Content System | Week 2 | Message, MessageMetadata |
| 5 | Generation & Transcription Config | Week 2-3 | GenerateConfig, TranscriptionConfig, TranscriptionResult |
| 6 | Streaming & Result Types | Week 3 | Streams, Chunks, EmbeddingResult |
| 7 | Error Handling System | Week 3-4 | AIError, DeviceCapabilities |
| 8 | Token Counting API | Week 4 | TokenCount, context helpers |
| 9 | Model Management System | Week 4-5 | ModelManager, cache, downloads |
| 10 | MLX Provider Implementation | Week 5-7 | Full MLX provider |
| 11 | HuggingFace Provider Implementation | Week 7-8 | Full HF provider |
| 12 | Foundation Models Provider | Week 8-9 | Full FM provider with @Generable |
| 13 | Result Builders & Convenience APIs | Week 9-10 | Builders, ChatSession, extensions |
| 14 | Macros (@Generable) | Week 10-11 | Swift macros for structured output |
| 15 | Testing, Documentation & Polish | Week 11-12 | Tests, DocC, examples |

---

## Phase 1: Project Setup & Package Structure

### Objective
Establish the Swift package foundation with proper directory structure, dependencies, and build configuration.

### Deliverables

- [x] `Package.swift` with all dependencies (including swift-syntax for macros)
- [x] Complete directory structure matching API specification
- [x] `SwiftAI.swift` with comprehensive re-exports
- [x] `README.md` with project overview
- [x] `.gitignore` for Swift/Xcode projects

### Directory Structure (from API Spec)

```
SwiftAI/
├── Package.swift
├── Sources/
│   ├── SwiftAI/
│   │   ├── SwiftAI.swift                    # Re-exports & convenience
│   │   │
│   │   ├── Core/
│   │   │   ├── Protocols/
│   │   │   │   ├── AIProvider.swift
│   │   │   │   ├── TextGenerator.swift
│   │   │   │   ├── EmbeddingGenerator.swift
│   │   │   │   ├── Transcriber.swift
│   │   │   │   ├── TokenCounter.swift
│   │   │   │   └── ModelManaging.swift
│   │   │   │
│   │   │   ├── Types/
│   │   │   │   ├── ModelIdentifier.swift
│   │   │   │   ├── Message.swift
│   │   │   │   ├── GenerateConfig.swift
│   │   │   │   ├── EmbeddingResult.swift
│   │   │   │   ├── TranscriptionResult.swift
│   │   │   │   └── TokenCount.swift
│   │   │   │
│   │   │   ├── Streaming/
│   │   │   │   ├── GenerationStream.swift
│   │   │   │   ├── StreamChunk.swift
│   │   │   │   └── StreamBuffer.swift
│   │   │   │
│   │   │   └── Errors/
│   │   │       ├── AIError.swift
│   │   │       └── ProviderError.swift
│   │   │
│   │   ├── Providers/
│   │   │   ├── MLX/
│   │   │   │   ├── MLXProvider.swift
│   │   │   │   ├── MLXModelLoader.swift
│   │   │   │   └── MLXConfiguration.swift
│   │   │   │
│   │   │   ├── HuggingFace/
│   │   │   │   ├── HuggingFaceProvider.swift
│   │   │   │   ├── HFInferenceClient.swift
│   │   │   │   ├── HFTokenProvider.swift
│   │   │   │   └── HFConfiguration.swift
│   │   │   │
│   │   │   └── FoundationModels/
│   │   │       ├── FoundationModelsProvider.swift
│   │   │       ├── FMSessionManager.swift
│   │   │       └── FMConfiguration.swift
│   │   │
│   │   ├── ModelManagement/
│   │   │   ├── ModelManager.swift
│   │   │   ├── ModelRegistry.swift
│   │   │   ├── ModelCache.swift
│   │   │   └── DownloadProgress.swift
│   │   │
│   │   ├── Builders/
│   │   │   ├── PromptBuilder.swift
│   │   │   └── MessageBuilder.swift
│   │   │
│   │   └── Extensions/
│   │       ├── StringExtensions.swift
│   │       ├── ArrayExtensions.swift
│   │       └── URLExtensions.swift
│   │
│   └── SwiftAIMacros/
│       ├── GenerableMacro.swift
│       └── GuideMacro.swift
│
└── Tests/
    └── SwiftAITests/
```

### Package.swift Template

```swift
// swift-tools-version: 6.0
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "SwiftAI",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "SwiftAI", targets: ["SwiftAI"]),
    ],
    dependencies: [
        // MLX for local inference
        .package(url: "https://github.com/ml-explore/mlx-swift", from: "0.21.0"),
        .package(url: "https://github.com/ml-explore/mlx-swift-examples", branch: "main"),
        
        // HuggingFace ecosystem
        .package(url: "https://github.com/huggingface/swift-transformers", from: "0.1.0"),
        .package(url: "https://github.com/huggingface/swift-huggingface-hub", from: "0.1.0"),
        
        // Swift Syntax for macros
        .package(url: "https://github.com/apple/swift-syntax", from: "509.0.0"),
    ],
    targets: [
        .target(
            name: "SwiftAI",
            dependencies: [
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXLLM", package: "mlx-swift-examples"),
                .product(name: "MLXLMCommon", package: "mlx-swift-examples"),
                .product(name: "Transformers", package: "swift-transformers"),
                .product(name: "HuggingFaceHub", package: "swift-huggingface-hub"),
                "SwiftAIMacros",
            ],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .macro(
            name: "SwiftAIMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "SwiftAITests",
            dependencies: ["SwiftAI"]
        ),
    ]
)
```

### Acceptance Criteria

- [x] `swift build` succeeds without errors
- [x] All dependencies resolve correctly
- [x] Directory structure matches API specification exactly
- [x] Macro target compiles

### Phase 1 Status: **COMPLETE** :white_check_mark:

**Completed (December 16, 2025):**
- [x] Package.swift configured with dependencies + StrictConcurrency
- [x] 14 directories created matching API spec
- [x] 40 placeholder Swift files created
- [x] SwiftAIMacros target with @main entry point
- [x] SwiftAI.swift with module documentation
- [x] `swift build` passes
- [x] `swift test` passes (1 test)

**Dependencies Resolved:**
- MLX v0.29.1 (mlx-swift)
- Transformers v1.1.5 (swift-transformers)
- HuggingFace v0.5.0 (swift-huggingface)
- SwiftSyntax v509.1.1 (swift-syntax)

**Note:** Removed mlx-swift-examples dependency (only provides MLXMNIST and StableDiffusion example products, not needed for core framework). MLX provider will use mlx-swift directly.

---

## Phase 2: Core Protocols & Type System

### Objective
Define the foundational protocols that all providers must implement.

### Deliverables

- [x] `Sources/SwiftAI/Core/Protocols/AIProvider.swift`
- [x] `Sources/SwiftAI/Core/Protocols/TextGenerator.swift`
- [x] `Sources/SwiftAI/Core/Protocols/EmbeddingGenerator.swift`
- [x] `Sources/SwiftAI/Core/Protocols/Transcriber.swift`
- [x] `Sources/SwiftAI/Core/Protocols/TokenCounter.swift`
- [x] `Sources/SwiftAI/Core/Protocols/ModelManaging.swift`

### Protocol Summary (see API Spec for full signatures)

| Protocol | Key Methods |
|----------|-------------|
| `AIProvider` | `generate()`, `stream()`, `cancelGeneration()`, `isAvailable`, `availabilityStatus` |
| `TextGenerator` | `generate(_:)`, `generate(messages:)`, `stream(_:)`, `streamWithMetadata()` |
| `EmbeddingGenerator` | `embed(_:)`, `embedBatch(_:)` |
| `Transcriber` | `transcribe(audioURL:)`, `transcribe(audioData:)`, `streamTranscription()` |
| `TokenCounter` | `countTokens(in:)`, `countTokens(in messages:)`, `encode(_:)`, `decode(_:)` |
| `ModelManaging` | `availableModels()`, `cachedModels()`, `isCached()`, `download()`, `delete()` |

### Acceptance Criteria

- [x] All protocols compile without errors
- [x] Protocols use `Actor` and `Sendable` constraints correctly
- [x] Associated types use `ModelIdentifying` constraint
- [x] Documentation comments match API spec

### Phase 2 Status: **COMPLETE** :white_check_mark:

**Completed (December 16, 2025):**
- [x] ForwardDeclarations.swift with ModelIdentifying protocol, ProviderType enum, and stub types
- [x] AIProvider protocol with Actor constraint and primary associated types
- [x] TextGenerator protocol with 4 generation methods + default implementations
- [x] EmbeddingGenerator protocol with single and batch embedding
- [x] Transcriber protocol with URL, Data, and streaming transcription
- [x] TokenCounter protocol with text/message counting and encode/decode
- [x] ModelManaging protocol with discovery, download, and cache management
- [x] ProtocolCompilationTests.swift with 24 passing tests
- [x] `swift build` passes
- [x] `swift test` passes (24 tests)

---

## Phase 3: Model Identification System

### Objective
Create the model identification system that uniquely identifies models and their providers.

### Deliverables

- [ ] `Sources/SwiftAI/Core/Types/ModelIdentifier.swift`
  - [ ] `ModelIdentifying` protocol
  - [ ] `ModelIdentifier` enum (`.mlx()`, `.huggingFace()`, `.foundationModels`)
  - [ ] `ProviderType` enum
- [ ] `Sources/SwiftAI/ModelManagement/ModelRegistry.swift`
  - [ ] All static model constants from API spec
  - [ ] `ModelInfo` struct
  - [ ] `ModelCapability` enum

### Key Types

```swift
// ModelIdentifying protocol
public protocol ModelIdentifying: Hashable, Sendable, CustomStringConvertible {
    var rawValue: String { get }
    var displayName: String { get }
    var provider: ProviderType { get }
}

// ModelIdentifier enum
public enum ModelIdentifier: ModelIdentifying, Codable {
    case mlx(String)
    case huggingFace(String)
    case foundationModels
}

// ProviderType enum
public enum ProviderType: String, Sendable, Codable, CaseIterable {
    case mlx, huggingFace, foundationModels
    var displayName: String
    var requiresNetwork: Bool
}

// ModelInfo struct (for registry)
public struct ModelInfo: Sendable, Identifiable {
    public let identifier: ModelIdentifier
    public let name: String
    public let description: String
    public let size: ModelSize
    public let contextWindow: Int
    public let capabilities: Set<ModelCapability>
    public let isRecommended: Bool
}

// ModelCapability enum
public enum ModelCapability: String, Sendable, CaseIterable {
    case textGeneration, embeddings, transcription, codeGeneration, reasoning, multimodal
}
```

### Registry Models (from API Spec)

```swift
// MLX Local Models
static let llama3_2_1B, llama3_2_3B, phi3Mini, phi4, qwen2_5_3B, mistral7B, gemma2_2B

// MLX Embedding Models  
static let bgeSmall, bgeLarge, nomicEmbed

// HuggingFace Cloud Models
static let llama3_1_70B, llama3_1_8B, mixtral8x7B, deepseekR1, whisperLargeV3

// Apple Foundation Models
static let apple
```

### Acceptance Criteria

- [ ] `ModelIdentifier` is `Hashable`, `Sendable`, and `Codable`
- [ ] Round-trip JSON encoding/decoding works
- [ ] All registry models have correct identifiers
- [ ] `ModelInfo` contains all fields from spec

---

## Phase 4: Message Types & Content System

### Objective
Implement the message types used for conversations.

### Deliverables

- [x] `Sources/SwiftAI/Core/Types/Message.swift`
  - [x] `Message` struct
  - [x] `Message.Role` enum
  - [x] `Message.Content` enum
  - [x] `Message.ContentPart` enum
  - [x] `Message.ImageContent` struct
  - [x] `MessageMetadata` struct

### Key Types

```swift
public struct Message: Sendable, Hashable, Codable, Identifiable {
    public let id: UUID
    public let role: Role
    public let content: Content
    public let timestamp: Date
    public let metadata: MessageMetadata?
    
    // Convenience initializers
    public static func system(_ text: String) -> Message
    public static func user(_ text: String) -> Message
    public static func assistant(_ text: String) -> Message
}

public enum Role: String, Sendable, Codable, CaseIterable {
    case system, user, assistant, tool
}

public enum Content: Sendable, Hashable, Codable {
    case text(String)
    case parts([ContentPart])
    
    public var textValue: String
    public var isEmpty: Bool
}

public struct MessageMetadata: Sendable, Hashable, Codable {
    public var tokenCount: Int?
    public var generationTime: TimeInterval?
    public var model: String?
    public var tokensPerSecond: Double?
    public var finishReason: FinishReason?
    public var custom: [String: String]?
}
```

### Acceptance Criteria

- [x] Message types are fully `Sendable` and `Codable`
- [x] Convenience initializers create correct messages
- [x] `Content.textValue` extracts text from all variants
- [x] `ImageContent` supports base64 encoding

### Phase 4 Status: **COMPLETE** ✅

**Completed (December 16, 2025):**
- [x] Message struct with id, role, content, timestamp, metadata
- [x] Role enum with system, user, assistant, tool cases
- [x] Content enum with text and parts cases + custom Codable
- [x] ContentPart enum with text and image cases + custom Codable
- [x] ImageContent struct with base64Data and mimeType
- [x] MessageMetadata struct with all fields
- [x] Factory methods: .system(), .user(), .assistant()
- [x] 33 unit tests passing in MessageTests.swift
- [x] `swift build` passes
- [x] `swift test --filter MessageTests` passes (33 tests)

---

## Phase 5: Generation & Transcription Configuration

### Objective
Implement configuration types for generation and transcription.

### Deliverables

- [x] `Sources/SwiftAI/Core/Types/GenerateConfig.swift`
  - [x] `GenerateConfig` struct with all parameters
  - [x] Fluent API methods
  - [x] Presets (`.default`, `.creative`, `.precise`, `.code`)
- [x] `Sources/SwiftAI/Core/Types/TranscriptionResult.swift`
  - [x] `TranscriptionConfig` struct
  - [x] `TranscriptionFormat` enum
  - [x] `TranscriptionResult` struct
  - [x] `TranscriptionSegment` struct
  - [x] `TranscriptionWord` struct

### Phase 5 Status: **COMPLETE** ✅

**Completed (December 16, 2025):**
- [x] GenerateConfig with 12 parameters, 4 presets, 11 fluent API methods
- [x] Fluent API with value clamping (temperature 0-2, topP 0-1)
- [x] TranscriptionFormat enum with text, detailed, srt, vtt
- [x] TranscriptionConfig with 4 presets (.default, .detailed, .subtitles, .translateToEnglish)
- [x] TranscriptionWord with duration computed property
- [x] TranscriptionSegment with Identifiable conformance
- [x] TranscriptionResult with toSRT() and toVTT() methods
- [x] ForwardDeclarations.swift stubs removed
- [x] 52 GenerateConfig tests passing
- [x] 36 Transcription type tests passing
- [x] `swift build` passes
- [x] `swift test` passes (166 total tests)

### GenerateConfig Parameters (from API Spec)

```swift
public struct GenerateConfig: Sendable, Hashable, Codable {
    // Token Limits
    public var maxTokens: Int?
    public var minTokens: Int?
    
    // Sampling Parameters
    public var temperature: Float      // 0.0 to 2.0, default 0.7
    public var topP: Float             // 0.0 to 1.0, default 0.9
    public var topK: Int?
    public var repetitionPenalty: Float // default 1.0
    public var frequencyPenalty: Float  // -2.0 to 2.0, default 0.0
    public var presencePenalty: Float   // -2.0 to 2.0, default 0.0
    
    // Stopping Conditions
    public var stopSequences: [String]
    
    // Advanced
    public var seed: UInt64?
    public var returnLogprobs: Bool
    public var topLogprobs: Int?
    
    // Fluent API
    func temperature(_:) -> GenerateConfig
    func maxTokens(_:) -> GenerateConfig
    func topP(_:) -> GenerateConfig
    func topK(_:) -> GenerateConfig
    func stopSequences(_:) -> GenerateConfig
    func seed(_:) -> GenerateConfig
    func withLogprobs(top:) -> GenerateConfig
}
```

### Transcription Types

```swift
public struct TranscriptionConfig: Sendable, Hashable, Codable {
    public var language: String?
    public var wordTimestamps: Bool
    public var translate: Bool
    public var format: TranscriptionFormat
    public var vadSensitivity: Float
    public var initialPrompt: String?
    public var temperature: Float
    
    // Presets
    static let `default`, detailed, subtitles, translateToEnglish
}

public struct TranscriptionResult: Sendable {
    public let text: String
    public let segments: [TranscriptionSegment]
    public let language: String?
    public let languageConfidence: Float?
    public let duration: TimeInterval
    public let processingTime: TimeInterval
    
    public var realtimeFactor: Double
    public func toSRT() -> String
    public func toVTT() -> String
}

public struct TranscriptionSegment: Sendable, Hashable, Identifiable {
    public let id: Int
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    public let text: String
    public let words: [TranscriptionWord]?
    public let avgLogProb: Float?
    public let compressionRatio: Float?
    public let noSpeechProb: Float?
    public var duration: TimeInterval
}

public struct TranscriptionWord: Sendable, Hashable {
    public let word: String
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    public let confidence: Float?
}
```

### Acceptance Criteria

- [x] All config types are `Sendable` and `Codable`
- [x] Parameter clamping enforces valid ranges
- [x] Fluent API returns new instances (immutable)
- [x] Presets match API spec values
- [x] `toSRT()` and `toVTT()` produce valid subtitle formats

---

## Phase 6: Streaming & Result Types

### Objective
Build the streaming infrastructure and result types.

### Deliverables

- [ ] `Sources/SwiftAI/Core/Streaming/GenerationStream.swift`
  - [ ] `GenerationStream` struct (AsyncSequence)
  - [ ] `.text` computed property
  - [ ] `.collect()` method
  - [ ] `.collectWithMetadata()` method
  - [ ] `.timeToFirstToken()` method
  - [ ] `static func from(_:)` factory method
- [ ] `Sources/SwiftAI/Core/Streaming/StreamChunk.swift`
  - [ ] `GenerationChunk` struct
  - [ ] `TokenLogprob` struct
  - [ ] `FinishReason` enum
- [ ] `Sources/SwiftAI/Core/Streaming/StreamBuffer.swift`
  - [ ] Buffering utilities for streams
- [ ] `Sources/SwiftAI/Core/Types/GenerationResult.swift`
  - [ ] `GenerationResult` struct
  - [ ] `UsageStats` struct
- [ ] `Sources/SwiftAI/Core/Types/EmbeddingResult.swift`
  - [ ] `EmbeddingResult` struct with similarity methods
  - [ ] `BatchEmbeddingResult` struct

### Key Types

```swift
// GenerationStream
public struct GenerationStream: AsyncSequence, Sendable {
    public typealias Element = GenerationChunk
    
    public var text: AsyncThrowingMapSequence<GenerationStream, String>
    public func collect() async throws -> String
    public func collectWithMetadata() async throws -> GenerationResult
    public func timeToFirstToken() async throws -> (chunk: GenerationChunk, latency: TimeInterval)?
    public static func from(_ stringStream: AsyncThrowingStream<String, Error>) -> GenerationStream
}

// GenerationChunk
public struct GenerationChunk: Sendable, Hashable {
    public let text: String
    public let tokenCount: Int
    public let tokenId: Int?
    public let logprob: Float?
    public let topLogprobs: [TokenLogprob]?
    public let tokensPerSecond: Double?
    public let isComplete: Bool
    public let finishReason: FinishReason?
    public let timestamp: Date
    
    public static func completion(finishReason: FinishReason) -> GenerationChunk
}

// TokenLogprob
public struct TokenLogprob: Sendable, Hashable, Codable {
    public let token: String
    public let logprob: Float
    public let tokenId: Int?
    public var probability: Float { exp(logprob) }
}

// FinishReason
public enum FinishReason: String, Sendable, Codable {
    case stop, maxTokens, stopSequence, cancelled, contentFilter, toolCall
}

// GenerationResult
public struct GenerationResult: Sendable, Hashable {
    public let text: String
    public let tokenCount: Int
    public let generationTime: TimeInterval
    public let tokensPerSecond: Double
    public let finishReason: FinishReason
    public let logprobs: [TokenLogprob]?
    public let usage: UsageStats?
    
    public static func text(_ content: String) -> GenerationResult
}

// UsageStats
public struct UsageStats: Sendable, Hashable, Codable {
    public let promptTokens: Int
    public let completionTokens: Int
    public var totalTokens: Int { promptTokens + completionTokens }
}

// EmbeddingResult
public struct EmbeddingResult: Sendable {
    public let vector: [Float]
    public let text: String
    public let model: String
    public let tokenCount: Int?
    public var dimensions: Int { vector.count }
    
    public func cosineSimilarity(with other: EmbeddingResult) -> Float
    public func euclideanDistance(to other: EmbeddingResult) -> Float
    public func dotProduct(with other: EmbeddingResult) -> Float
}

// BatchEmbeddingResult
public struct BatchEmbeddingResult: Sendable {
    public let embeddings: [EmbeddingResult]
    public let processingTime: TimeInterval
    public var totalTokens: Int
    
    public func mostSimilar(to query: EmbeddingResult) -> (result: EmbeddingResult, similarity: Float)?
    public func ranked(by query: EmbeddingResult) -> [(result: EmbeddingResult, similarity: Float)]
}
```

### Acceptance Criteria

- [ ] `GenerationStream` conforms to `AsyncSequence`
- [ ] Stream collection methods work correctly
- [ ] `EmbeddingResult` similarity methods are mathematically correct
- [ ] `BatchEmbeddingResult.ranked()` returns descending similarity order

---

## Phase 7: Error Handling System

### Objective
Implement comprehensive error handling with localized descriptions.

### Deliverables

- [ ] `Sources/SwiftAI/Core/Errors/AIError.swift`
  - [ ] `AIError` enum with all cases from API spec
  - [ ] `errorDescription` implementation
  - [ ] `recoverySuggestion` implementation
  - [ ] `isRetryable` property
  - [ ] `UnavailabilityReason` enum
- [ ] `Sources/SwiftAI/Core/Errors/ProviderError.swift`
  - [ ] Provider-specific error types
- [ ] `Sources/SwiftAI/Core/Types/ProviderAvailability.swift`
  - [ ] `ProviderAvailability` struct
  - [ ] `DeviceCapabilities` struct with `current()` method
  - [ ] `ModelSize` enum
- [ ] `Sources/SwiftAI/Core/Types/ByteCount.swift`
  - [ ] `ByteCount` struct with formatting

### AIError Cases (from API Spec)

```swift
public enum AIError: Error, Sendable, LocalizedError {
    // Provider Errors
    case providerUnavailable(reason: UnavailabilityReason)
    case modelNotFound(ModelIdentifier)
    case modelNotCached(ModelIdentifier)
    case authenticationFailed(String)
    
    // Generation Errors
    case generationFailed(underlying: Error)
    case tokenLimitExceeded(count: Int, limit: Int)
    case contentFiltered(reason: String?)
    case cancelled
    case timeout(TimeInterval)
    
    // Network Errors
    case networkError(URLError)
    case serverError(statusCode: Int, message: String?)
    case rateLimited(retryAfter: TimeInterval?)
    
    // Resource Errors
    case insufficientMemory(required: ByteCount, available: ByteCount)
    case downloadFailed(underlying: Error)
    case fileError(underlying: Error)
    
    // Input Errors
    case invalidInput(String)
    case unsupportedAudioFormat(String)
    case unsupportedLanguage(String)
}
```

### DeviceCapabilities

```swift
public struct DeviceCapabilities: Sendable {
    public let totalRAM: Int64
    public let availableRAM: Int64
    public let chipType: String?
    public let neuralEngineCores: Int?
    public let supportsMLX: Bool
    public let supportsFoundationModels: Bool
    
    public static func current() -> DeviceCapabilities
}
```

### Acceptance Criteria

- [ ] All error cases have localized descriptions
- [ ] Recovery suggestions are helpful and actionable
- [ ] `isRetryable` correctly identifies network/rate limit errors
- [ ] `DeviceCapabilities.current()` detects hardware correctly
- [ ] `ByteCount` formatting produces human-readable strings

---

## Phase 8: Token Counting API

### Objective
Implement token counting capabilities with context window helpers.

### Deliverables

- [ ] `Sources/SwiftAI/Core/Types/TokenCount.swift`
  - [ ] `TokenCount` struct
  - [ ] Context window helper methods
  - [ ] `Int` extensions for context sizes

### TokenCounter Extensions (from API Spec)

```swift
extension TokenCounter {
    // Estimate if messages fit
    func estimateFits(
        messages: [Message],
        model: ModelID,
        contextSize: Int,
        reserveForOutput: Int
    ) async throws -> (fits: Bool, tokens: Int, available: Int)
    
    // Truncate to fit
    func truncateToFit(
        messages: [Message],
        model: ModelID,
        contextSize: Int,
        reserveForOutput: Int
    ) async throws -> [Message]
    
    // Chunk text (for RAG)
    func chunk(
        text: String,
        model: ModelID,
        maxTokensPerChunk: Int,
        overlap: Int
    ) async throws -> [String]
}
```

### Context Window Constants

```swift
extension Int {
    static let context4K = 4096
    static let context8K = 8192
    static let context16K = 16384
    static let context32K = 32768
    static let context64K = 65536
    static let context128K = 131072
}
```

### Acceptance Criteria

- [ ] `TokenCount` helpers calculate correctly
- [ ] `truncateToFit` preserves system messages
- [ ] `chunk` respects overlap parameter
- [ ] All context constants are defined

---

## Phase 9: Model Management System

### Objective
Build the model download, caching, and lifecycle management system.

### Deliverables

- [ ] `Sources/SwiftAI/ModelManagement/ModelManager.swift`
  - [ ] `ModelManager` actor (singleton)
  - [ ] Download with progress
  - [ ] Cache management
- [ ] `Sources/SwiftAI/ModelManagement/ModelCache.swift`
  - [ ] `ModelCache` actor
  - [ ] `CachedModelInfo` struct
  - [ ] LRU eviction
- [ ] `Sources/SwiftAI/ModelManagement/DownloadProgress.swift`
  - [ ] `DownloadProgress` struct
  - [ ] `DownloadState` enum
  - [ ] `DownloadTask` observable class

### Key Types

```swift
public actor ModelManager {
    public static let shared: ModelManager
    
    // Discovery
    func cachedModels() async -> [CachedModelInfo]
    func isCached(_ model: ModelIdentifier) async -> Bool
    func localPath(for model: ModelIdentifier) async -> URL?
    
    // Download
    func download(_ model: ModelIdentifier, progress: (@Sendable (DownloadProgress) -> Void)?) async throws -> URL
    func downloadTask(for model: ModelIdentifier) -> DownloadTask
    func cancelDownload(_ model: ModelIdentifier)
    
    // Cache Management
    func delete(_ model: ModelIdentifier) async throws
    func clearCache() async throws
    func cacheSize() async -> ByteCount
    func evictToFit(maxSize: ByteCount) async throws
}

public struct CachedModelInfo: Sendable, Identifiable {
    public let identifier: ModelIdentifier
    public let path: URL
    public let size: ByteCount
    public let downloadedAt: Date
    public let lastAccessedAt: Date
    public let revision: String?
}

@Observable
public final class DownloadTask: @unchecked Sendable {
    public let model: ModelIdentifier
    public private(set) var progress: DownloadProgress
    public private(set) var state: DownloadState
    
    public func cancel()
    public func pause()
    public func resume()
    public func result() async throws -> URL
}
```

### Acceptance Criteria

- [ ] Downloads from HuggingFace work correctly
- [ ] Progress tracking is accurate
- [ ] Cache correctly stores and retrieves models
- [ ] LRU eviction removes oldest models first
- [ ] Downloads can be cancelled and resumed

---

## Phase 10: MLX Provider Implementation

### Objective
Implement the MLX provider for local inference on Apple Silicon.

### Deliverables

- [ ] `Sources/SwiftAI/Providers/MLX/MLXProvider.swift`
  - [ ] Conforms to: `AIProvider`, `TextGenerator`, `EmbeddingGenerator`, `TokenCounter`
  - [ ] Non-streaming generation
  - [ ] Streaming generation with detokenization
  - [ ] Cancellation support
- [ ] `Sources/SwiftAI/Providers/MLX/MLXModelLoader.swift`
  - [ ] Model loading utilities
  - [ ] Chat template formatting
- [ ] `Sources/SwiftAI/Providers/MLX/MLXConfiguration.swift`
  - [ ] Configuration struct
  - [ ] Presets (`.default`, `.lowMemory`, `.performance`)

### MLXProvider Capabilities

| Capability | Status |
|------------|--------|
| Text Generation | Required |
| Streaming | Required |
| Embeddings | Required |
| Token Counting | Required |
| Transcription | Not supported (use WhisperKit separately) |

### Acceptance Criteria

- [ ] Provider compiles only on arm64 (Apple Silicon)
- [ ] `isAvailable` correctly detects device support
- [ ] Text generation returns correct results
- [ ] Streaming yields tokens incrementally
- [ ] Cancellation stops generation within reasonable time
- [ ] Token counting matches model's tokenizer

---

## Phase 11: HuggingFace Provider Implementation

### Objective
Implement the HuggingFace Inference API provider.

### Deliverables

- [ ] `Sources/SwiftAI/Providers/HuggingFace/HuggingFaceProvider.swift`
  - [ ] Conforms to: `AIProvider`, `TextGenerator`, `EmbeddingGenerator`, `Transcriber`
  - [ ] Chat completion API
  - [ ] Streaming with SSE parsing
- [ ] `Sources/SwiftAI/Providers/HuggingFace/HFInferenceClient.swift`
  - [ ] HTTP client for HF API
  - [ ] SSE stream parsing
- [ ] `Sources/SwiftAI/Providers/HuggingFace/HFTokenProvider.swift`
  - [ ] Token resolution (auto, static, keychain)
- [ ] `Sources/SwiftAI/Providers/HuggingFace/HFConfiguration.swift`
  - [ ] Configuration struct

### HuggingFaceProvider Capabilities

| Capability | Status |
|------------|--------|
| Text Generation | Required |
| Streaming | Required |
| Embeddings | Required |
| Transcription | Required (Whisper API) |

### Acceptance Criteria

- [ ] API authentication works with all token providers
- [ ] Chat completion returns correct responses
- [ ] Streaming correctly parses SSE events
- [ ] Embeddings return correct dimensions
- [ ] Transcription produces valid TranscriptionResult
- [ ] Rate limiting is handled gracefully

---

## Phase 12: Foundation Models Provider Implementation

### Objective
Implement the Apple Foundation Models provider for iOS 26+.

### Deliverables

- [ ] `Sources/SwiftAI/Providers/FoundationModels/FoundationModelsProvider.swift`
  - [ ] Conforms to: `AIProvider`, `TextGenerator`
  - [ ] Session management
  - [ ] Structured generation with `@Generable`
- [ ] `Sources/SwiftAI/Providers/FoundationModels/FMSessionManager.swift`
  - [ ] Session lifecycle
  - [ ] Prewarming
- [ ] `Sources/SwiftAI/Providers/FoundationModels/FMConfiguration.swift`
  - [ ] Configuration struct

### FoundationModelsProvider Capabilities

| Capability | Status |
|------------|--------|
| Text Generation | Required |
| Streaming | Required |
| Structured Output | Required (`generate<T: Generable>`) |
| Session Management | Required |

### Structured Generation Methods (from API Spec)

```swift
// Generate structured output
func generate<T: Generable>(
    messages: [Message],
    generating type: T.Type,
    config: GenerateConfig
) async throws -> T

// Stream structured generation
func stream<T: Generable>(
    messages: [Message],
    generating type: T.Type,
    config: GenerateConfig
) -> AsyncThrowingStream<T.PartiallyGenerated, Error>
```

### Acceptance Criteria

- [ ] `isAvailable` correctly checks Apple Intelligence status
- [ ] Text generation works with system language model
- [ ] Streaming provides incremental responses
- [ ] Session management (set instructions, clear, prewarm) works
- [ ] `@Generable` structured output generates correct types

---

## Phase 13: Result Builders & Convenience APIs

### Objective
Implement result builders and convenience extensions.

### Deliverables

- [ ] `Sources/SwiftAI/Builders/MessageBuilder.swift`
  - [ ] `@MessageBuilder` result builder
  - [ ] `Messages { }` function
- [ ] `Sources/SwiftAI/Builders/PromptBuilder.swift`
  - [ ] `@PromptBuilder` result builder
  - [ ] `Prompt { }` function
  - [ ] `PromptComponent` protocol
  - [ ] `SystemInstruction` struct
  - [ ] `UserQuery` struct
  - [ ] `Context` struct
  - [ ] `Examples` struct
- [ ] `Sources/SwiftAI/ChatSession.swift`
  - [ ] `ChatSession<Provider>` observable class
  - [ ] All methods from API spec
- [ ] `Sources/SwiftAI/Extensions/StringExtensions.swift`
  - [ ] `generate(with:model:config:)` method
  - [ ] `stream(with:model:config:)` method
  - [ ] `embed(with:model:)` method
  - [ ] `tokenCount(with:model:)` method
- [ ] `Sources/SwiftAI/Extensions/ArrayExtensions.swift`
  - [ ] Message array extensions
  - [ ] String array embed extension
- [ ] `Sources/SwiftAI/Extensions/URLExtensions.swift`
  - [ ] `transcribe(with:model:config:)` method

### ChatSession Methods (from API Spec)

```swift
@Observable
public final class ChatSession<Provider: AIProvider & TextGenerator>: @unchecked Sendable {
    public let provider: Provider
    public let model: ModelIdentifier
    public private(set) var messages: [Message]
    public private(set) var isGenerating: Bool
    public var config: GenerateConfig
    public private(set) var lastError: Error?
    
    // System Prompt
    func setSystemPrompt(_ prompt: String)
    
    // Sending
    @discardableResult func send(_ content: String) async throws -> String
    func stream(_ content: String) -> AsyncThrowingStream<String, Error>
    
    // History Management
    func clearHistory()
    func undoLastExchange()
    func injectHistory(_ history: [Message])
    
    // Cancellation
    func cancel() async
    
    // Computed
    var messageCount: Int
    var userMessageCount: Int
}
```

### Acceptance Criteria

- [ ] `Messages { }` supports conditionals and loops
- [ ] `Prompt { }` components render correctly
- [ ] `ChatSession` maintains conversation state correctly
- [ ] `undoLastExchange()` removes both user and assistant messages
- [ ] All convenience extensions work with all providers

---

## Phase 14: Macros (@Generable)

### Objective
Implement the `@Generable` macro for type-safe structured generation.

### Deliverables

- [ ] `Sources/SwiftAIMacros/GenerableMacro.swift`
  - [ ] `@Generable` attached macro
  - [ ] Schema generation
  - [ ] `PartiallyGenerated` type synthesis
- [ ] `Sources/SwiftAIMacros/GuideMacro.swift`
  - [ ] `@Guide` peer macro
  - [ ] Constraint validation
- [ ] `Sources/SwiftAI/StructuredOutput/Generable.swift`
  - [ ] `Generable` protocol
  - [ ] `GenerableSchema` struct
  - [ ] `GuideConstraint` enum

### Naming (Aligned with API Spec)

| Name | Purpose |
|------|---------|
| `@Generable` | Marks a type as generable |
| `@Guide` | Provides guidance for a property |
| `GuideConstraint` | Constraint types for validation |
| `GenerableSchema` | Schema representation |
| `Generable` | Protocol for generable types |

### Key Types

```swift
@attached(member, names: named(PartiallyGenerated), named(schema), named(init(from:)))
@attached(extension, conformances: Generable)
public macro Generable() = #externalMacro(module: "SwiftAIMacros", type: "GenerableMacro")

@attached(peer)
public macro Guide(
    description: String? = nil,
    _ constraints: GuideConstraint...
) = #externalMacro(module: "SwiftAIMacros", type: "GuideMacro")

public enum GuideConstraint: Sendable {
    case range(ClosedRange<Int>)
    case anyOf([String])
    case count(Int)
    case countRange(ClosedRange<Int>)
    case pattern(String)
    case custom(String)
}

public protocol Generable: Sendable, Codable {
    associatedtype PartiallyGenerated: Sendable
    static var schema: GenerableSchema { get }
}
```

### Acceptance Criteria

- [ ] `@Generable` generates `PartiallyGenerated` companion type
- [ ] `@Guide` constraints are included in schema
- [ ] `schema.toJSONSchema()` produces valid JSON Schema
- [ ] Macro compiles and works with Foundation Models provider

---

## Phase 15: Testing, Documentation & Polish

### Objective
Comprehensive testing, documentation, and final polish.

### Deliverables

- [ ] Unit tests for all core types
- [ ] Integration tests for each provider
- [ ] DocC documentation for all public APIs
- [ ] Example SwiftUI app
- [ ] Performance benchmarks

### Test Files

```
Tests/SwiftAITests/
├── Core/
│   ├── MessageTests.swift
│   ├── GenerateConfigTests.swift
│   ├── ModelIdentifierTests.swift
│   ├── TokenCountTests.swift
│   ├── ByteCountTests.swift
│   └── EmbeddingResultTests.swift
├── Streaming/
│   ├── GenerationStreamTests.swift
│   └── GenerationChunkTests.swift
├── Providers/
│   ├── MLXProviderTests.swift
│   ├── HuggingFaceProviderTests.swift
│   └── FoundationModelsProviderTests.swift
├── ModelManagement/
│   ├── ModelManagerTests.swift
│   └── ModelCacheTests.swift
└── Builders/
    ├── MessageBuilderTests.swift
    └── PromptBuilderTests.swift
```

### Acceptance Criteria

- [ ] >80% code coverage
- [ ] All unit tests pass
- [ ] Integration tests pass on supported devices
- [ ] DocC builds without warnings
- [ ] Example app demonstrates all major features
- [ ] MLX inference achieves 30+ tok/s on M1

---

## Complete Implementation Checklist

### Phase 1: Project Setup
- [ ] Package.swift with all dependencies including swift-syntax
- [ ] Complete directory structure
- [ ] SwiftAI.swift re-exports
- [ ] Macro target configured

### Phase 2: Core Protocols
- [ ] AIProvider protocol
- [ ] TextGenerator protocol (including `streamWithMetadata`)
- [ ] EmbeddingGenerator protocol
- [ ] Transcriber protocol
- [ ] TokenCounter protocol
- [ ] ModelManaging protocol

### Phase 3: Model Identification
- [ ] ModelIdentifying protocol
- [ ] ModelIdentifier enum
- [ ] ProviderType enum
- [ ] Model registry with all constants
- [ ] ModelInfo struct
- [ ] ModelCapability enum

### Phase 4: Message Types
- [ ] Message struct
- [ ] Message.Role enum
- [ ] Message.Content enum
- [ ] Message.ContentPart enum
- [ ] Message.ImageContent struct
- [ ] MessageMetadata struct

### Phase 5: Configuration Types
- [ ] GenerateConfig struct with fluent API
- [ ] Config presets
- [ ] TranscriptionConfig struct
- [ ] TranscriptionFormat enum
- [ ] TranscriptionResult struct
- [ ] TranscriptionSegment struct
- [ ] TranscriptionWord struct

### Phase 6: Streaming & Results
- [ ] GenerationStream (AsyncSequence)
- [ ] GenerationChunk struct
- [ ] TokenLogprob struct
- [ ] FinishReason enum
- [ ] GenerationResult struct
- [ ] UsageStats struct
- [ ] EmbeddingResult struct with similarity methods
- [ ] BatchEmbeddingResult struct
- [ ] StreamBuffer utilities

### Phase 7: Error Handling
- [ ] AIError enum (all cases)
- [ ] UnavailabilityReason enum
- [ ] ProviderAvailability struct
- [ ] DeviceCapabilities struct
- [ ] ModelSize enum
- [ ] ByteCount struct
- [ ] ProviderError types

### Phase 8: Token Counting
- [ ] TokenCount struct
- [ ] Context window helpers
- [ ] Int context size extensions
- [ ] TokenCounter.chunk() method

### Phase 9: Model Management
- [ ] ModelManager actor
- [ ] ModelCache actor
- [ ] CachedModelInfo struct
- [ ] DownloadTask class
- [ ] DownloadProgress struct
- [ ] DownloadState enum

### Phase 10: MLX Provider
- [ ] MLXProvider actor
- [ ] MLXConfiguration struct
- [ ] MLXModelLoader
- [ ] Text generation
- [ ] Streaming
- [ ] Embeddings
- [ ] Token counting

### Phase 11: HuggingFace Provider
- [ ] HuggingFaceProvider actor
- [ ] HFConfiguration struct
- [ ] HFInferenceClient
- [ ] HFTokenProvider
- [ ] Text generation
- [ ] Streaming (SSE)
- [ ] Embeddings
- [ ] Transcription

### Phase 12: Foundation Models Provider
- [ ] FoundationModelsProvider actor
- [ ] FMConfiguration struct
- [ ] FMSessionManager
- [ ] Text generation
- [ ] Streaming
- [ ] Structured generation (Generable)

### Phase 13: Convenience APIs
- [ ] MessageBuilder
- [ ] PromptBuilder
- [ ] PromptComponent types (SystemInstruction, UserQuery, Context, Examples)
- [ ] ChatSession class (all methods)
- [ ] String extensions
- [ ] Array extensions
- [ ] URL extensions

### Phase 14: Macros
- [ ] @Generable macro
- [ ] @Guide macro
- [ ] GuideConstraint enum
- [ ] GenerableSchema struct
- [ ] Generable protocol

### Phase 15: Testing & Documentation
- [ ] Unit tests (>80% coverage)
- [ ] Integration tests
- [ ] DocC documentation
- [ ] Example app
- [ ] Performance benchmarks

---

## Success Metrics

| Metric | Target |
|--------|--------|
| API Ergonomics | Simple use cases < 5 lines of code |
| MLX Performance | 30+ tokens/second on M1 |
| Reliability | 99%+ success rate for valid operations |
| Documentation | 100% public API coverage |
| Test Coverage | >80% code coverage |

---

*End of SwiftAI Implementation Plan (Revised)*

**Reference Document:** SwiftAI-API-Specification.md for exact API signatures
