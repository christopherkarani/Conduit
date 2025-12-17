# Phase 10: MLX Provider Implementation Plan

## Status: APPROVED - Ready for Implementation

## Date: December 17, 2025

---

## Summary

Implement MLXProvider for local LLM inference on Apple Silicon using mlx-swift-lm. This is the first concrete provider implementation in SwiftAI.

**Estimated LOC**: ~800-1000 lines across 3 files

---

## CRITICAL: Prerequisites FIRST

### Add mlx-swift-lm Dependency to Package.swift

```swift
// Add to dependencies array (after mlx-swift):
.package(url: "https://github.com/ml-explore/mlx-swift-lm.git", from: "0.5.0"),

// Add to SwiftAI target dependencies:
.product(name: "MLXLMCommon", package: "mlx-swift-lm"),
.product(name: "MLXLLM", package: "mlx-swift-lm"),
```

Current Package.swift location: `/Users/chriskarani/CodingProjects/SwiftAI/Package.swift`

---

## Implementation Order (MUST FOLLOW THIS ORDER)

### Step 1: MLXConfiguration.swift (~150 lines)

**Path**: `Sources/SwiftAI/Providers/MLX/MLXConfiguration.swift`

**Current State**: Placeholder with empty `_MLXConfigurationPlaceholder` enum

**Implementation**:
```swift
import Foundation

/// Configuration options for MLXProvider.
public struct MLXConfiguration: Sendable, Hashable {

    // MARK: - Memory Management
    public var memoryLimit: ByteCount?
    public var useMemoryMapping: Bool
    public var kvCacheLimit: Int?

    // MARK: - Compute Preferences
    public var prefillStepSize: Int        // Default: 512
    public var useQuantizedKVCache: Bool   // Default: false
    public var kvQuantizationBits: Int     // 4 or 8

    // MARK: - Initialization
    public init(
        memoryLimit: ByteCount? = nil,
        useMemoryMapping: Bool = true,
        kvCacheLimit: Int? = nil,
        prefillStepSize: Int = 512,
        useQuantizedKVCache: Bool = false,
        kvQuantizationBits: Int = 4
    )

    // MARK: - Presets
    public static let `default`: MLXConfiguration
    public static let memoryEfficient: MLXConfiguration  // Quantized KV cache
    public static let highPerformance: MLXConfiguration  // Large prefill steps
    public static let m1Optimized: MLXConfiguration      // ~8GB RAM
    public static let mProOptimized: MLXConfiguration    // ~16-32GB RAM

    // MARK: - Fluent API
    public func memoryLimit(_ limit: ByteCount?) -> MLXConfiguration
    public func prefillStepSize(_ size: Int) -> MLXConfiguration
    public func kvCacheLimit(_ limit: Int?) -> MLXConfiguration
    public func withQuantizedKVCache(bits: Int) -> MLXConfiguration
}
```

---

### Step 2: MLXModelLoader.swift (~250 lines)

**Path**: `Sources/SwiftAI/Providers/MLX/MLXModelLoader.swift`

**Current State**: Placeholder with empty `_MLXModelLoaderPlaceholder` enum

**Implementation**:
```swift
import Foundation
#if arch(arm64)
import MLX
import MLXLMCommon
import MLXLLM
import Transformers
#endif

/// Internal actor for loading and managing MLX model instances.
internal actor MLXModelLoader {

    // MARK: - Types
    struct LoadedModel: Sendable {
        let container: ModelContainer
        let modelId: String
        let loadedAt: Date
        var lastAccessedAt: Date
    }

    // MARK: - Properties
    private var loadedModels: [String: LoadedModel] = [:]
    private let configuration: MLXConfiguration
    private let maxLoadedModels: Int = 1  // LRU eviction

    // MARK: - Initialization
    init(configuration: MLXConfiguration = .default, maxLoadedModels: Int = 1)

    // MARK: - Model Loading
    func loadModel(identifier: ModelIdentifier) async throws -> ModelContainer
    func unloadModel(identifier: ModelIdentifier) async
    func unloadAllModels() async
    func isLoaded(_ identifier: ModelIdentifier) async -> Bool

    // MARK: - Tokenizer Access
    func tokenizer(for identifier: ModelIdentifier) async throws -> any Tokenizer

    // MARK: - Private Helpers
    private func evictIfNeeded() async
    private func resolveModelPath(for identifier: ModelIdentifier) async throws -> URL
}
```

**Key Integration**: Uses `ModelManager.shared.localPath(for:)` to resolve cached model paths

---

### Step 3: MLXProvider.swift (~500 lines)

**Path**: `Sources/SwiftAI/Providers/MLX/MLXProvider.swift`

**Current State**: Placeholder with empty `_MLXProviderPlaceholder` enum

**Protocol Conformances**: AIProvider, TextGenerator, EmbeddingGenerator, TokenCounter

**Implementation**:
```swift
import Foundation
#if arch(arm64)
import MLX
import MLXLMCommon
import MLXLLM
import Transformers
#endif

/// Local inference provider using MLX on Apple Silicon.
public actor MLXProvider: AIProvider, TextGenerator, EmbeddingGenerator, TokenCounter {

    // MARK: - Associated Types
    public typealias Response = GenerationResult
    public typealias StreamChunk = GenerationChunk
    public typealias ModelID = ModelIdentifier

    // MARK: - Properties
    public let configuration: MLXConfiguration
    private let modelLoader: MLXModelLoader
    private var isCancelled: Bool = false

    // MARK: - Initialization
    public init(configuration: MLXConfiguration = .default)

    // MARK: - AIProvider: Availability
    public var isAvailable: Bool { get async }  // #if arch(arm64) return true #else return false
    public var availabilityStatus: ProviderAvailability { get async }

    // MARK: - AIProvider: Generation
    public func generate(messages: [Message], model: ModelID, config: GenerateConfig) async throws -> GenerationResult
    public nonisolated func stream(messages: [Message], model: ModelID, config: GenerateConfig) -> AsyncThrowingStream<GenerationChunk, Error>
    public func cancelGeneration() async

    // MARK: - TextGenerator
    public func generate(_ prompt: String, model: ModelID, config: GenerateConfig) async throws -> String
    public nonisolated func stream(_ prompt: String, model: ModelID, config: GenerateConfig) -> AsyncThrowingStream<String, Error>
    public nonisolated func streamWithMetadata(messages: [Message], model: ModelID, config: GenerateConfig) -> AsyncThrowingStream<GenerationChunk, Error>

    // MARK: - EmbeddingGenerator
    public func embed(_ text: String, model: ModelID) async throws -> EmbeddingResult
    public func embedBatch(_ texts: [String], model: ModelID) async throws -> [EmbeddingResult]

    // MARK: - TokenCounter
    public func countTokens(in text: String, for model: ModelID) async throws -> TokenCount
    public func countTokens(in messages: [Message], for model: ModelID) async throws -> TokenCount
    public func encode(_ text: String, for model: ModelID) async throws -> [Int]
    public func decode(_ tokens: [Int], for model: ModelID, skipSpecialTokens: Bool) async throws -> String
}

// MARK: - Private Implementation (inside #if arch(arm64))
extension MLXProvider {
    private func performGeneration(messages:model:config:) async throws -> GenerationResult
    private func performStreamingGeneration(messages:model:config:continuation:) async
    private func performEmbedding(text:model:) async throws -> EmbeddingResult
    private func createUserInput(from messages: [Message]) -> UserInput
    private func createGenerateParameters(from config: GenerateConfig) -> GenerateParameters
}
```

---

## Type Mapping Reference

### SwiftAI → MLX Type Mappings

| SwiftAI | MLX | Notes |
|---------|-----|-------|
| `GenerateConfig.temperature` | `GenerateParameters.temperature` | Direct |
| `GenerateConfig.topP` | `GenerateParameters.topP` | Direct |
| `GenerateConfig.maxTokens` | `GenerateParameters.maxTokens` | Optional → required (default 1024) |
| `GenerateConfig.repetitionPenalty` | `GenerateParameters.repetitionPenalty` | Direct |
| `[Message]` | `UserInput(prompt: .messages([...]))` | Convert roles |
| `Message.Role.system` | `.system(text)` | |
| `Message.Role.user` | `.user(text)` | |
| `Message.Role.assistant` | `.assistant(text)` | |
| `Message.Role.tool` | `.user(text)` | Map to user |

### Finish Reason Mapping

| SwiftAI FinishReason | MLX Condition |
|---------------------|---------------|
| `.stop` | Natural EOS or callback returns `.stop` |
| `.maxTokens` | `tokens.count >= maxTokens` |
| `.stopSequence` | Text contains stop sequence |
| `.cancelled` | `Task.isCancelled` or `isCancelled` flag |

---

## Streaming Implementation

Use `NaiveStreamingDetokenizer` for incremental token-to-text:

```swift
var detokenizer = NaiveStreamingDetokenizer(tokenizer: context.tokenizer)

// In generation callback:
if let lastToken = tokens.last {
    detokenizer.append(token: lastToken)
}

if let newText = detokenizer.next() {
    continuation.yield(GenerationChunk(text: newText, tokenCount: 1, ...))
}
```

---

## Cancellation Mechanism

Dual-path cancellation:
1. Check `Task.isCancelled` in generation callback
2. Check `isCancelled` actor property (set by `cancelGeneration()`)

```swift
// In generation callback:
if Task.isCancelled || self.isCancelled {
    return .stop
}

// Public cancellation method:
public func cancelGeneration() async {
    isCancelled = true
}
```

---

## Error Handling

Wrap all MLX errors in `AIError`:

| Scenario | AIError Case |
|----------|--------------|
| Non-Apple Silicon | `.providerUnavailable(reason: .deviceNotSupported)` |
| Model not downloaded | `.modelNotCached(identifier)` |
| Invalid model type | `.invalidInput("MLXProvider only supports .mlx() models")` |
| Generation failure | `.generationFailed(underlying: SendableError(error))` |
| User cancellation | `.cancelled` |

---

## arm64 Conditional Compilation Pattern

```swift
#if arch(arm64)
import MLXLMCommon
import MLXLLM
// Full implementation
#else
// Throw AIError.providerUnavailable(reason: .deviceNotSupported)
#endif
```

---

## Critical Files to Modify/Create

| File | Action | Purpose |
|------|--------|---------|
| `/Users/chriskarani/CodingProjects/SwiftAI/Package.swift` | MODIFY | Add mlx-swift-lm dependency |
| `/Users/chriskarani/CodingProjects/SwiftAI/Sources/SwiftAI/Providers/MLX/MLXConfiguration.swift` | REPLACE | Configuration struct |
| `/Users/chriskarani/CodingProjects/SwiftAI/Sources/SwiftAI/Providers/MLX/MLXModelLoader.swift` | REPLACE | Model loading actor |
| `/Users/chriskarani/CodingProjects/SwiftAI/Sources/SwiftAI/Providers/MLX/MLXProvider.swift` | REPLACE | Main provider actor |

---

## Dependencies Graph

```
MLXConfiguration (no deps)
       ↓
MLXModelLoader (needs MLXConfiguration, ModelManager.shared)
       ↓
MLXProvider (needs both, implements 4 protocols)
```

---

## Acceptance Criteria

- [ ] `Package.swift` updated with mlx-swift-lm
- [ ] `swift build` passes on arm64 and non-arm64
- [ ] `isAvailable` returns true on Apple Silicon only
- [ ] `generate()` produces valid GenerationResult
- [ ] `stream()` yields incremental GenerationChunk objects
- [ ] Cancellation works within ~100ms
- [ ] All errors wrapped in AIError
- [ ] Token counting matches model tokenizer
- [ ] Performance: 30+ tok/s on M1 (1B model)
- [ ] All public APIs documented

---

## mlx-swift-lm Key APIs (from Context7 research)

### Model Loading
```swift
let model = try await loadModel(id: "mlx-community/Llama-3.2-3B-Instruct-4bit")
let container = try await LLMModelFactory.shared.loadContainer(configuration: config, progressHandler: { ... })
```

### ChatSession (High-level)
```swift
let session = ChatSession(model)
let answer = try await session.respond(to: prompt)
for try await chunk in session.streamResponse(to: prompt) { ... }
```

### Generate API (Low-level)
```swift
try await model.perform { context in
    let userInput = UserInput(prompt: "...")
    let lmInput = try await context.processor.prepare(input: userInput)
    let parameters = GenerateParameters(maxTokens: 100, temperature: 0.8, topP: 0.95)

    let stream = try generate(input: lmInput, parameters: parameters, context: context)
    for await generation in stream {
        switch generation {
        case .chunk(let text): // Handle chunk
        case .info(let info): // Generation stats
        case .toolCall(let tc): // Tool calls
        }
    }
}
```

### TokenIterator (Manual)
```swift
var iterator = try TokenIterator(input: lmInput, model: context.model, parameters: parameters)
while let token = iterator.next() {
    let text = context.tokenizer.decode(tokens: [token])
}
```

---

## swift-transformers Key APIs

### AutoTokenizer
```swift
let tokenizer = try await AutoTokenizer.from(pretrained: "model-id")
let encoded = try tokenizer.encode(text: "...")
let decoded = tokenizer.decode(tokens: encoded)
let chatTokens = try tokenizer.applyChatTemplate(messages: messages)
```

---

## Testing Strategy

### Unit Tests
- MLXConfigurationTests: Presets, fluent API, Sendable conformance
- MLXProviderTests: Availability check, error handling

### Integration Tests (Require Apple Silicon + Downloaded Model)
- Generation end-to-end
- Streaming with cancellation
- Token counting accuracy

### Performance Tests
- Target: 30+ tok/s on M1 with 1B model

---

*Plan created: December 17, 2025*
*Status: APPROVED - Ready for Implementation*
