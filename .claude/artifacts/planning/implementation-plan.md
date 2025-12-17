# SwiftAI Implementation Plan

> **Version**: 1.0.0
> **Duration**: 8-12 weeks
> **Phases**: 15

---

## Overview

This document outlines the phased implementation approach for building SwiftAI, a unified Swift SDK for LLM inference across MLX, HuggingFace, and Apple Foundation Models.

### Design Principles

1. **Explicit Model Selection** — No auto-detection; developers choose their provider
2. **Swift 6.2 Concurrency** — Actors, Sendable types, AsyncSequence throughout
3. **Protocol-Oriented** — Provider abstraction via protocols with associated types
4. **Progressive Disclosure** — Simple API for beginners, full control for experts

### Phase Dependencies

```
Phase 1 (Setup) ─┬─► Phase 2 (Protocols) ─┬─► Phase 4 (Messages)
                 │                        │
                 │                        └─► Phase 5 (Config)
                 │
                 └─► Phase 3 (Models) ────────► Phase 6 (Streaming)
                                                     │
                                                     ▼
Phase 7 (Errors) ◄──────────────────────────────────┘
     │
     ▼
Phase 8 (Tokens) ──► Phase 9 (Model Mgmt)
     │
     ▼
Phase 10 (MLX) ──► Phase 11 (HF) ──► Phase 12 (FM)
                                          │
                                          ▼
                                   Phase 13 (Builders)
                                          │
                                          ▼
                                   Phase 14 (Macros)
                                          │
                                          ▼
                                   Phase 15 (Polish)
```

---

## Phase 1: Project Setup & Package.swift

**Duration**: 1-2 days
**Dependencies**: None

### Objective
Establish the Swift package structure, configure dependencies, and create the foundational directory layout.

### Deliverables
- `Package.swift` with all dependencies
- Directory structure matching specification
- `.gitignore` and `.swiftlint.yml`
- Basic README.md

### Implementation

```swift
// Package.swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwiftAI",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "SwiftAI", targets: ["SwiftAI"])
    ],
    dependencies: [
        // MLX
        .package(url: "https://github.com/ml-explore/mlx-swift", from: "0.21.0"),
        .package(url: "https://github.com/huggingface/swift-transformers", from: "0.1.0"),
        // Macros
        .package(url: "https://github.com/apple/swift-syntax", from: "600.0.0"),
    ],
    targets: [
        .target(
            name: "SwiftAI",
            dependencies: [
                .product(name: "MLX", package: "mlx-swift", condition: .when(platforms: [.macOS, .iOS])),
                .product(name: "MLXLLM", package: "mlx-swift", condition: .when(platforms: [.macOS, .iOS])),
                .product(name: "Transformers", package: "swift-transformers"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .macro(
            name: "SwiftAIMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
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
- [ ] `swift build` compiles without errors
- [ ] `swift package resolve` succeeds
- [ ] Directory structure matches specification
- [ ] README has basic project description

---

## Phase 2: Core Protocols

**Duration**: 2-3 days
**Dependencies**: Phase 1

### Objective
Define the foundational protocols that all providers and capabilities must conform to.

### Deliverables
- `Sources/SwiftAI/Core/Protocols/AIProvider.swift`
- `Sources/SwiftAI/Core/Protocols/TextGenerator.swift`
- `Sources/SwiftAI/Core/Protocols/EmbeddingGenerator.swift`
- `Sources/SwiftAI/Core/Protocols/Transcriber.swift`
- `Sources/SwiftAI/Core/Protocols/TokenCounter.swift`
- `Sources/SwiftAI/Core/Protocols/ModelManaging.swift`

### Key Protocols

```swift
public protocol AIProvider<Response>: Actor, Sendable {
    associatedtype Response: Sendable
    associatedtype StreamChunk: Sendable
    associatedtype ModelID: ModelIdentifying
    
    var isAvailable: Bool { get async }
    var availabilityStatus: ProviderAvailability { get async }
    
    func generate(messages: [Message], model: ModelID, config: GenerateConfig) async throws -> Response
    func stream(messages: [Message], model: ModelID, config: GenerateConfig) -> AsyncThrowingStream<StreamChunk, Error>
    func cancelGeneration() async
}
```

### Acceptance Criteria
- [ ] All protocols defined with full documentation
- [ ] Primary associated types used where beneficial
- [ ] All protocols require Sendable conformance
- [ ] Protocol extensions provide default implementations

---

## Phase 3: Model Identification

**Duration**: 1-2 days
**Dependencies**: Phase 1

### Objective
Create the type-safe model identification system and model registry.

### Deliverables
- `Sources/SwiftAI/Core/Types/ModelIdentifier.swift`
- `Sources/SwiftAI/ModelManagement/ModelRegistry.swift`

### Key Types

```swift
public protocol ModelIdentifying: Hashable, Sendable, CustomStringConvertible {
    var rawValue: String { get }
    var displayName: String { get }
    var provider: ProviderType { get }
}

public enum ModelIdentifier: ModelIdentifying, Codable {
    case mlx(String)
    case huggingFace(String)
    case foundationModels
}

// Registry with convenience constants
extension ModelIdentifier {
    static let llama3_2_1B = ModelIdentifier.mlx("mlx-community/Llama-3.2-1B-Instruct-4bit")
    static let llama3_2_3B = ModelIdentifier.mlx("mlx-community/Llama-3.2-3B-Instruct-4bit")
    // ... more models
}
```

### Acceptance Criteria
- [ ] ModelIdentifier enum with all three cases
- [ ] ModelIdentifying protocol defined
- [ ] ProviderType enum defined
- [ ] Model registry with common model constants

---

## Phase 4: Message Types

**Duration**: 2-3 days
**Dependencies**: Phase 2

### Objective
Implement the message types for representing conversations.

### Deliverables
- `Sources/SwiftAI/Core/Types/Message.swift`
- Unit tests for Message types

### Key Types

```swift
public struct Message: Sendable, Hashable, Codable, Identifiable {
    public let id: UUID
    public let role: Role
    public let content: Content
    public let timestamp: Date
    public let metadata: MessageMetadata?
    
    public enum Role: String, Sendable, Codable { case system, user, assistant, tool }
    public enum Content: Sendable, Hashable, Codable { case text(String), parts([ContentPart]) }
}
```

### Acceptance Criteria
- [ ] Message struct with all properties
- [ ] Convenience initializers (.system, .user, .assistant)
- [ ] Codable conformance working
- [ ] Unit tests passing

---

## Phase 5: Generation Configuration

**Duration**: 2-3 days
**Dependencies**: Phase 2

### Objective
Implement GenerateConfig with all sampling parameters and fluent API.

### Deliverables
- `Sources/SwiftAI/Core/Types/GenerateConfig.swift`
- Unit tests for config validation

### Key Features

```swift
public struct GenerateConfig: Sendable, Hashable, Codable {
    public var maxTokens: Int?
    public var temperature: Float
    public var topP: Float
    public var topK: Int?
    // ... more params
    
    // Presets
    public static let `default` = GenerateConfig()
    public static let creative = GenerateConfig(temperature: 0.9)
    public static let precise = GenerateConfig(temperature: 0.1)
    
    // Fluent API
    public func temperature(_ value: Float) -> GenerateConfig
    public func maxTokens(_ value: Int?) -> GenerateConfig
}
```

### Acceptance Criteria
- [ ] All sampling parameters defined
- [ ] Fluent API methods work correctly
- [ ] Value clamping for temperature/topP
- [ ] Presets defined

---

## Phase 6: Streaming Infrastructure

**Duration**: 3-4 days
**Dependencies**: Phase 2, 5

### Objective
Build the streaming infrastructure for token-by-token generation.

### Deliverables
- `Sources/SwiftAI/Core/Streaming/GenerationStream.swift`
- `Sources/SwiftAI/Core/Streaming/GenerationChunk.swift`
- `Sources/SwiftAI/Core/Types/GenerationResult.swift`

### Key Types

```swift
public struct GenerationStream: AsyncSequence, Sendable {
    public var text: AsyncThrowingMapSequence<GenerationStream, String>
    public func collect() async throws -> String
    public func collectWithMetadata() async throws -> GenerationResult
}

public struct GenerationChunk: Sendable, Hashable {
    public let text: String
    public let tokenCount: Int
    public let tokensPerSecond: Double?
    public let isComplete: Bool
    public let finishReason: FinishReason?
}
```

### Acceptance Criteria
- [ ] GenerationStream conforms to AsyncSequence
- [ ] Chunk collection works correctly
- [ ] Cancellation handling via onTermination
- [ ] Tests for streaming behavior

---

## Phase 7: Error Handling

**Duration**: 2-3 days
**Dependencies**: Phase 6

### Objective
Implement comprehensive error handling with AIError enum.

### Deliverables
- `Sources/SwiftAI/Core/Errors/AIError.swift`
- `Sources/SwiftAI/Core/Errors/ProviderError.swift`
- `Sources/SwiftAI/Core/Types/ProviderAvailability.swift`

### Key Types

```swift
public enum AIError: Error, Sendable, LocalizedError {
    case providerUnavailable(reason: UnavailabilityReason)
    case modelNotFound(ModelIdentifier)
    case generationFailed(underlying: Error)
    case tokenLimitExceeded(count: Int, limit: Int)
    case cancelled
    // ... more cases
    
    public var errorDescription: String? { /* localized descriptions */ }
}
```

### Acceptance Criteria
- [ ] All error cases defined
- [ ] LocalizedError conformance
- [ ] UnavailabilityReason enum complete
- [ ] ProviderAvailability struct defined

---

## Phase 8: Token Counting API

**Duration**: 2-3 days
**Dependencies**: Phase 7

### Objective
Implement token counting protocol and types.

### Deliverables
- `Sources/SwiftAI/Core/Types/TokenCount.swift`
- Token counting protocol extensions

### Key Features

```swift
public struct TokenCount: Sendable, Hashable {
    public let count: Int
    public let text: String
    public let tokenizer: String
    public let tokenIds: [Int]?
    
    public func fitsInContext(of size: Int) -> Bool
    public func remainingIn(context size: Int) -> Int
}

extension TokenCounter {
    public func truncateToFit(messages: [Message], model: ModelID, contextSize: Int) async throws -> [Message]
}
```

### Acceptance Criteria
- [ ] TokenCount struct complete
- [ ] Context window helpers work
- [ ] Truncation extension implemented
- [ ] Integration with SwiftAgents patterns

---

## Phase 9: Model Management

**Duration**: 3-4 days
**Dependencies**: Phase 8

### Objective
Implement the model download, cache, and lifecycle management system.

### Deliverables
- `Sources/SwiftAI/ModelManagement/ModelManager.swift`
- `Sources/SwiftAI/ModelManagement/ModelCache.swift`
- `Sources/SwiftAI/ModelManagement/DownloadProgress.swift`
- `Sources/SwiftAI/ModelManagement/DownloadTask.swift`

### Key Features

```swift
public actor ModelManager {
    public static let shared = ModelManager()
    
    public func cachedModels() -> [CachedModelInfo]
    public func isCached(_ model: ModelIdentifier) -> Bool
    public func download(_ model: ModelIdentifier, progress: @escaping (DownloadProgress) -> Void) async throws -> URL
    public func delete(_ model: ModelIdentifier) throws
    public func cacheSize() -> ByteCount
}
```

### Acceptance Criteria
- [ ] ModelManager actor complete
- [ ] Download with progress works
- [ ] Cache management functional
- [ ] Observable DownloadTask

---

## Phase 10: MLX Provider

**Duration**: 4-5 days
**Dependencies**: Phase 9

### Objective
Implement the MLX local inference provider.

### Deliverables
- `Sources/SwiftAI/Providers/MLX/MLXProvider.swift`
- `Sources/SwiftAI/Providers/MLX/MLXModelLoader.swift`
- `Sources/SwiftAI/Providers/MLX/MLXConfiguration.swift`

### Key Implementation

```swift
public actor MLXProvider: AIProvider, TextGenerator, EmbeddingGenerator, TokenCounter {
    // Full implementation with:
    // - Model loading
    // - Generation (sync and streaming)
    // - Embeddings
    // - Token counting
}
```

### Acceptance Criteria
- [ ] Availability check works on Apple Silicon
- [ ] Generation produces output
- [ ] Streaming works correctly
- [ ] Token counting accurate
- [ ] Memory management handled

---

## Phase 11: HuggingFace Provider

**Duration**: 3-4 days
**Dependencies**: Phase 10

### Objective
Implement the HuggingFace Inference API provider.

### Deliverables
- `Sources/SwiftAI/Providers/HuggingFace/HuggingFaceProvider.swift`
- `Sources/SwiftAI/Providers/HuggingFace/HFInferenceClient.swift`
- `Sources/SwiftAI/Providers/HuggingFace/HFTokenProvider.swift`
- `Sources/SwiftAI/Providers/HuggingFace/HFConfiguration.swift`

### Key Implementation

```swift
public actor HuggingFaceProvider: AIProvider, TextGenerator, EmbeddingGenerator, Transcriber {
    // HTTP client for HF Inference API
    // SSE streaming support
    // Token management
}
```

### Acceptance Criteria
- [ ] Authentication works
- [ ] Chat completions functional
- [ ] SSE streaming implemented
- [ ] Transcription works
- [ ] Rate limiting handled

---

## Phase 12: Foundation Models Provider

**Duration**: 3-4 days
**Dependencies**: Phase 11

### Objective
Implement the Apple Foundation Models wrapper (iOS 26+).

### Deliverables
- `Sources/SwiftAI/Providers/FoundationModels/FoundationModelsProvider.swift`
- `Sources/SwiftAI/Providers/FoundationModels/FMSessionManager.swift`
- `Sources/SwiftAI/Providers/FoundationModels/FMConfiguration.swift`

### Key Implementation

```swift
@available(iOS 26.0, macOS 26.0, *)
public actor FoundationModelsProvider: AIProvider, TextGenerator {
    // Session management
    // Structured output support
    // Availability checking
}
```

### Acceptance Criteria
- [ ] Availability check accurate
- [ ] Session management works
- [ ] Generation produces output
- [ ] Structured output with @Generable

---

## Phase 13: Result Builders

**Duration**: 2-3 days
**Dependencies**: Phase 12

### Objective
Implement result builders for declarative API construction.

### Deliverables
- `Sources/SwiftAI/Builders/MessageBuilder.swift`
- `Sources/SwiftAI/Builders/PromptBuilder.swift`
- Convenience extensions

### Key Implementation

```swift
@resultBuilder
public struct MessageBuilder {
    // Build expressions for Message
    // Support for optionals, arrays, conditionals
}

public func Messages(@MessageBuilder _ builder: () -> [Message]) -> [Message]
```

### Acceptance Criteria
- [ ] MessageBuilder works with conditionals
- [ ] PromptBuilder components functional
- [ ] For-in loop support
- [ ] Documentation complete

---

## Phase 14: Macros

**Duration**: 3-4 days
**Dependencies**: Phase 13

### Objective
Implement @StructuredOutput and @Field macros.

### Deliverables
- `Sources/SwiftAI/Macros/StructuredOutputMacro.swift`
- `Sources/SwiftAIMacros/` (macro implementation)

### Key Implementation

```swift
@attached(member, names: named(PartiallyGenerated), named(schema), named(init(from:)))
@attached(extension, conformances: StructuredOutputProtocol)
public macro StructuredOutput() = #externalMacro(...)

@attached(peer)
public macro Field(description: String?, _ constraints: FieldConstraint...) = #externalMacro(...)
```

### Acceptance Criteria
- [ ] @StructuredOutput generates schema
- [ ] @Field constraints work
- [ ] PartiallyGenerated type generated
- [ ] Macro tests passing

---

## Phase 15: Testing & Polish

**Duration**: 3-4 days
**Dependencies**: Phase 14

### Objective
Complete test coverage, documentation, and final polish.

### Deliverables
- Comprehensive test suite
- Full API documentation
- Example code
- Performance benchmarks

### Tasks
1. Achieve 80%+ test coverage
2. All public APIs documented
3. Example project in Examples/
4. Performance benchmarks for MLX
5. README with quick start guide

### Acceptance Criteria
- [ ] Test coverage >80%
- [ ] All public APIs documented
- [ ] Examples compile and run
- [ ] README complete
- [ ] SwiftLint clean

---

## Success Metrics

1. **API Ergonomics**: Simple use cases < 5 lines of code
2. **Performance**: MLX inference 30+ tokens/second on M1
3. **Reliability**: 99%+ success rate for valid operations
4. **Documentation**: 100% public API documentation coverage
5. **Test Coverage**: >80% code coverage

---

*End of SwiftAI Implementation Plan*
