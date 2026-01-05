# Architecture

Understand Conduit's design principles, protocol hierarchy, and type system. Useful for contributors and advanced users.

## Table of Contents

- [Design Principles](#design-principles)
- [Protocol Hierarchy](#protocol-hierarchy)
- [Type System](#type-system)
- [Concurrency Model](#concurrency-model)
- [Provider Architecture](#provider-architecture)
- [Structured Output System](#structured-output-system)
- [Directory Structure](#directory-structure)

---

## Design Principles

### 1. Explicit Model Selection

Conduit requires you to explicitly choose your provider and model. No magic auto-detection:

```swift
// Explicit - you know exactly what you're using
let provider = AnthropicProvider(apiKey: "...")
let response = try await provider.generate(prompt, model: .claudeSonnet45)

// Not implicit/magic
// let response = try await AI.generate(prompt)  // Which model? Which provider?
```

**Why?** Different providers have different:
- Pricing
- Capabilities
- Privacy implications
- Latency characteristics

### 2. Actor-Based Concurrency

All providers are Swift actors, ensuring thread-safe access:

```swift
public actor AnthropicProvider: AIProvider, TextGenerator {
    // Internal state is isolated
    private var httpClient: HTTPClient

    // Methods are automatically serialized
    public func generate(...) async throws -> GenerationResult
}
```

**Why?** Providers maintain internal state (HTTP clients, caches, configurations) that must be protected from data races.

### 3. Protocol-Oriented Design

Functionality is defined through composable protocols:

```swift
// Core capability protocols
protocol TextGenerator { ... }
protocol EmbeddingGenerator { ... }
protocol ImageGenerator { ... }

// Providers adopt what they support
actor OpenAIProvider: AIProvider, TextGenerator, EmbeddingGenerator, ImageGenerator
actor MLXProvider: AIProvider, TextGenerator, TokenCounter
```

**Why?** Allows providers to declare exactly what they support, enables generic programming, and makes testing easier.

### 4. Progressive Disclosure

Simple tasks are simple. Complex tasks are possible:

```swift
// Level 1: One-liner
let response = try await provider.generate("Hello", model: .llama3_2_1B)

// Level 2: With configuration
let response = try await provider.generate(
    "Hello",
    model: .llama3_2_1B,
    config: .creative.maxTokens(500)
)

// Level 3: Full control
let config = GenerateConfig(
    temperature: 0.9,
    topP: 0.95,
    maxTokens: 500,
    stopSequences: ["END"],
    tools: [WeatherTool()],
    toolChoice: .auto
)
let response = try await provider.generate(
    messages: messages,
    model: .llama3_2_1B,
    config: config
)
```

### 5. Type-Safe Structured Output

The `@Generable` macro mirrors Apple's FoundationModels API:

```swift
@Generable
struct Recipe {
    @Guide("Recipe title")
    let title: String

    @Guide("Time in minutes", .range(1...180))
    let cookingTime: Int
}

// Type-safe generation
let recipe: Recipe = try await provider.generate(
    "Create a recipe",
    returning: Recipe.self,
    model: model
)
```

**Why?** Eliminates JSON parsing boilerplate, catches schema errors at compile time, and provides IDE autocomplete.

### 6. Sendable Throughout

All public types conform to `Sendable` for safe concurrent use:

```swift
// All core types are Sendable
public struct Message: Sendable, Codable { ... }
public struct GenerateConfig: Sendable, Codable { ... }
public struct GenerationResult: Sendable { ... }

// Errors are Sendable too
public enum AIError: Error, Sendable { ... }
```

---

## Protocol Hierarchy

```
                    ┌─────────────────┐
                    │   AIProvider    │
                    │ (Core protocol) │
                    └────────┬────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
         ▼                   ▼                   ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│  TextGenerator  │ │EmbeddingGenerator│ │ ImageGenerator  │
└─────────────────┘ └─────────────────┘ └─────────────────┘
         │                   │                   │
         │                   │                   │
         ▼                   ▼                   ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│  TokenCounter   │ │   Transcriber   │ │  ModelManaging  │
└─────────────────┘ └─────────────────┘ └─────────────────┘
```

### AIProvider

The core abstraction with associated types:

```swift
public protocol AIProvider<Response>: Actor, Sendable {
    associatedtype Response
    associatedtype StreamChunk
    associatedtype ModelID: ModelIdentifying

    func generate(messages: [Message], model: ModelID, config: GenerateConfig)
        async throws -> Response

    func stream(messages: [Message], model: ModelID, config: GenerateConfig)
        -> AsyncThrowingStream<StreamChunk, Error>

    func cancelGeneration() async
    var isAvailable: Bool { get async }
}
```

### Capability Protocols

```swift
// Text generation
protocol TextGenerator {
    func generate(_ prompt: String, ...) async throws -> String
    func generate(messages: [Message], ...) async throws -> GenerationResult
    func stream(_ prompt: String, ...) -> AsyncThrowingStream<String, Error>
}

// Vector embeddings
protocol EmbeddingGenerator {
    func embed(_ text: String, model: ModelID) async throws -> EmbeddingResult
    func embedBatch(_ texts: [String], model: ModelID) async throws -> [EmbeddingResult]
}

// Image generation
protocol ImageGenerator {
    func generateImage(prompt: String, config: ImageGenerationConfig)
        async throws -> GeneratedImage
}

// Token operations
protocol TokenCounter {
    func countTokens(in text: String, for model: ModelID) async throws -> TokenCount
    func encode(_ text: String, for model: ModelID) async throws -> [Int]
    func decode(_ tokens: [Int], for model: ModelID) async throws -> String
}
```

---

## Type System

### Core Types

```
┌─────────────────────────────────────────────────────────────┐
│                        Message                               │
│  ┌─────────┐  ┌─────────────────────────┐  ┌─────────────┐  │
│  │  Role   │  │       Content           │  │  Metadata   │  │
│  │ .system │  │ .text(String)           │  │ tokenCount  │  │
│  │ .user   │  │ .parts([ContentPart])   │  │ model       │  │
│  │.assistant│  │   ├─ .text             │  │ timestamp   │  │
│  │ .tool   │  │   ├─ .image             │  │             │  │
│  └─────────┘  │   └─ .audio             │  └─────────────┘  │
│               └─────────────────────────┘                    │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    GenerateConfig                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │   Sampling   │  │    Limits    │  │     Tools        │   │
│  │ temperature  │  │ maxTokens    │  │ tools            │   │
│  │ topP         │  │ minTokens    │  │ toolChoice       │   │
│  │ topK         │  │ stopSequences│  │ parallelToolCalls│   │
│  └──────────────┘  └──────────────┘  └──────────────────┘   │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                   GenerationResult                           │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────────────┐ │
│  │    Text     │  │   Metrics   │  │    Tool Calls        │ │
│  │ text        │  │ tokenCount  │  │ toolCalls            │ │
│  │ finishReason│  │ tokensPerSec│  │ reasoningDetails     │ │
│  │             │  │ usage       │  │                      │ │
│  └─────────────┘  └─────────────┘  └──────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Streaming Types

```
┌─────────────────────────────────────────────────────────────┐
│                   GenerationChunk                            │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────────────┐ │
│  │   Content   │  │   Status    │  │   Tool Updates       │ │
│  │ text        │  │ isComplete  │  │ partialToolCall      │ │
│  │ tokenCount  │  │ finishReason│  │ completedToolCalls   │ │
│  │ tokenId     │  │ timestamp   │  │                      │ │
│  └─────────────┘  └─────────────┘  └──────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Model Identifiers

```swift
// Type-safe model selection
public protocol ModelIdentifying: Hashable, Sendable {
    var modelId: String { get }
}

// Concrete implementation
public enum ModelIdentifier: ModelIdentifying {
    case mlx(String)
    case huggingFace(String)
    case foundationModels

    // Convenience aliases
    static let llama3_2_1B = mlx("mlx-community/Llama-3.2-1B-Instruct-4bit")
}

// Provider-specific models
public enum AnthropicModelID: ModelIdentifying {
    case claudeOpus45
    case claudeSonnet45
    case claude35Sonnet
    case claude3Haiku
}
```

---

## Concurrency Model

### Actor Isolation

```swift
// Provider is an actor - methods are serialized
public actor MLXProvider: AIProvider {
    private var modelCache: ModelCache
    private var currentModel: LoadedModel?

    // Called from any context, executes serially
    public func generate(...) async throws -> GenerationResult {
        // Safe access to mutable state
        if currentModel == nil {
            currentModel = try await loadModel()
        }
        return try await currentModel!.generate(...)
    }
}
```

### Sendable Types

```swift
// All public types are Sendable
public struct Message: Sendable { ... }
public struct GenerateConfig: Sendable { ... }

// Errors wrap non-Sendable with SendableError
public struct SendableError: Error, Sendable {
    let localizedDescription: String
    let debugDescription: String
}
```

### AsyncSequence for Streaming

```swift
// Streaming uses AsyncThrowingStream
public func stream(...) -> AsyncThrowingStream<GenerationChunk, Error> {
    AsyncThrowingStream { continuation in
        Task {
            do {
                for await token in internalStream {
                    continuation.yield(GenerationChunk(text: token))
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }
}
```

---

## Provider Architecture

### Provider Implementation Pattern

```swift
public actor AnthropicProvider: AIProvider, TextGenerator {
    // Type aliases define provider's types
    public typealias Response = GenerationResult
    public typealias StreamChunk = GenerationChunk
    public typealias ModelID = AnthropicModelID

    // Configuration
    private let configuration: AnthropicConfiguration
    private let httpClient: HTTPClient

    // Initialization
    public init(apiKey: String) {
        self.configuration = AnthropicConfiguration(apiKey: apiKey)
        self.httpClient = HTTPClient(...)
    }

    // Core protocol requirement
    public func generate(
        messages: [Message],
        model: AnthropicModelID,
        config: GenerateConfig
    ) async throws -> GenerationResult {
        let request = buildRequest(messages, model, config)
        let response = try await httpClient.send(request)
        return parseResponse(response)
    }
}
```

### Extension Pattern

Providers split functionality across extensions:

```
AnthropicProvider.swift           - Core actor, initialization
AnthropicProvider+Streaming.swift - Streaming implementation
AnthropicProvider+Helpers.swift   - Request/response building
AnthropicModelID.swift           - Model definitions
AnthropicConfiguration.swift     - Configuration types
```

---

## Structured Output System

### Generable Protocol

```swift
public protocol Generable: GenerableContentConvertible, Sendable {
    associatedtype Partial: GenerableContentConvertible, Sendable
    static var schema: Schema { get }
}

public protocol GenerableContentConvertible {
    var generableContent: StructuredContent { get }
    init(from structuredContent: StructuredContent) throws
}
```

### Macro Generation

The `@Generable` macro generates:

```swift
// Input
@Generable
struct Recipe {
    @Guide("Title")
    let title: String

    @Guide("Time", .range(1...180))
    let cookingTime: Int
}

// Generated
extension Recipe: Generable {
    static var schema: Schema {
        .object(
            name: "Recipe",
            properties: [
                "title": Property(schema: .string([]), description: "Title"),
                "cookingTime": Property(
                    schema: .integer([.range(1...180)]),
                    description: "Time"
                )
            ]
        )
    }

    struct Partial: GenerableContentConvertible {
        var title: String?
        var cookingTime: Int?
        // ... init, generableContent
    }

    init(from structuredContent: StructuredContent) throws {
        self.title = try structuredContent.requiredValue(forKey: "title").string
        self.cookingTime = try structuredContent.requiredValue(forKey: "cookingTime").int
    }

    var generableContent: StructuredContent {
        .object([
            "title": .string(title),
            "cookingTime": .number(Double(cookingTime))
        ])
    }
}
```

---

## Directory Structure

```
Sources/Conduit/
├── Core/
│   ├── Protocols/          # AIProvider, TextGenerator, etc.
│   │   ├── AIProvider.swift
│   │   ├── TextGenerator.swift
│   │   ├── EmbeddingGenerator.swift
│   │   ├── ImageGenerator.swift
│   │   ├── TokenCounter.swift
│   │   ├── Transcriber.swift
│   │   ├── AITool.swift
│   │   └── Generable.swift
│   ├── Types/              # Core data types
│   │   ├── Message.swift
│   │   ├── GenerateConfig.swift
│   │   ├── GenerationResult.swift
│   │   ├── Schema.swift
│   │   ├── StructuredContent.swift
│   │   └── ModelIdentifier.swift
│   ├── Streaming/          # Streaming infrastructure
│   │   ├── GenerationChunk.swift
│   │   └── GenerationStream.swift
│   ├── Errors/             # Error types
│   │   ├── AIError.swift
│   │   └── SendableError.swift
│   └── Tools/              # Tool execution
│       └── AIToolExecutor.swift
├── Providers/
│   ├── Anthropic/          # Claude provider
│   ├── OpenAI/             # OpenAI/Ollama/Azure
│   ├── MLX/                # Local inference
│   ├── HuggingFace/        # HF Inference API
│   └── FoundationModels/   # iOS 26+ system models
├── Builders/               # Result builders
│   ├── MessageBuilder.swift
│   └── PromptBuilder.swift
└── Macros/                 # @Generable, @Guide
    └── GenerableMacros.swift

Sources/ConduitMacros/      # Macro implementations
├── GenerableMacro.swift
└── GuideMacro.swift
```

---

## Next Steps

- [Getting Started](GettingStarted.md) - Start using Conduit
- [Providers](Providers/README.md) - Provider details
- [Structured Output](StructuredOutput.md) - @Generable deep dive
- [Error Handling](ErrorHandling.md) - Error patterns
