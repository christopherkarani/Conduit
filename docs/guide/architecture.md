# Architecture

Understand Conduit's protocol hierarchy, type system, and design patterns.

## Overview

Conduit is built around a set of protocols that define provider capabilities. Every provider is an actor for thread-safe concurrent use, and all public types are `Sendable`. This architecture lets you write provider-agnostic app code and swap providers by changing a single initializer.

## Protocol Hierarchy

All providers conform to one or more of these protocols:

- **`TextGenerator`** — Text generation with streaming and non-streaming methods. Every provider implements this.
- **`EmbeddingGenerator`** — Vector embeddings for semantic search and similarity.
- **`Transcriber`** — Audio-to-text transcription.
- **`ImageGenerator`** — Text-to-image generation.
- **`TokenCounter`** — Token counting, encoding, and decoding.
- **`AIProvider`** — Actor-based umbrella protocol with availability checks and cancellation.

### TextGenerator

The core protocol. All providers implement it.

```swift
public protocol TextGenerator: Sendable {
    associatedtype ModelID: ModelIdentifying

    func generate(_ prompt: String, model: ModelID, config: GenerateConfig) async throws -> String
    func generate(messages: [Message], model: ModelID, config: GenerateConfig) async throws -> GenerationResult
    func stream(_ prompt: String, model: ModelID, config: GenerateConfig) -> AsyncThrowingStream<String, Error>
    func streamWithMetadata(messages: [Message], model: ModelID, config: GenerateConfig) -> AsyncThrowingStream<GenerationChunk, Error>
}
```

Write generic functions against `TextGenerator` to support any provider:

```swift
func summarize<P: TextGenerator>(with provider: P, model: P.ModelID, text: String) async throws -> String {
    try await provider.generate("Summarize: \(text)", model: model, config: .default.maxTokens(200))
}
```

## Actor-Based Providers

Every provider is an actor, ensuring thread-safe concurrent use:

```swift
public actor AnthropicProvider: AIProvider, TextGenerator { ... }
public actor OpenAIProvider: AIProvider, TextGenerator, EmbeddingGenerator, TokenCounter, ImageGenerator { ... }
public actor MLXProvider: AIProvider, TextGenerator, TokenCounter { ... }
```

You can call providers from any task or actor without data races.

## Model Identifiers

Conduit uses type-safe model identifiers. Each provider defines its own `ModelID` type:

- `AnthropicModelID` — `.claudeOpus45`, `.claudeSonnet45`, `.claude35Sonnet`, `.claude3Haiku`
- `OpenAIModelID` — `.gpt4o`, `.gpt4oMini`, `.o1`, `.textEmbedding3Small`, `.dallE3`
- `ModelIdentifier` — `.mlx("repo/model")`, `.huggingFace("repo/model")`, `.foundationModels`

Provider-specific model IDs have static constants for common models:

```swift
// Anthropic
let response = try await anthropic.generate("Hello", model: .claudeSonnet45)

// OpenAI
let response = try await openai.generate("Hello", model: .gpt4o)

// MLX
let response = try await mlx.generate("Hello", model: .llama3_2_1b)

// HuggingFace — any model by repository name
let response = try await hf.generate("Hello", model: .huggingFace("meta-llama/Llama-3.1-70B-Instruct"))
```

## GenerateConfig

`GenerateConfig` controls generation behavior with a fluent API:

```swift
// Presets
let config = GenerateConfig.default      // temperature: 0.7, topP: 0.9
let config = GenerateConfig.creative     // temperature: 1.0, topP: 0.95
let config = GenerateConfig.precise      // temperature: 0.3, topP: 0.8
let config = GenerateConfig.code         // temperature: 0.2, topP: 0.9

// Fluent chaining
let config = GenerateConfig.default
    .temperature(0.8)
    .maxTokens(500)
    .topP(0.9)
    .stopSequences(["END"])
```

## Messages and MessageBuilder

The `Message` type represents conversation turns. Use the `Messages` result builder for ergonomic construction:

```swift
let messages = Messages {
    Message.system("You are a Swift expert.")
    Message.user("What are actors?")
}

let result = try await provider.generate(
    messages: messages,
    model: .claudeSonnet45,
    config: .default
)
```

The builder supports conditionals and loops:

```swift
let messages = Messages {
    Message.system("You are a helpful assistant.")

    if includeContext {
        Message.user("Context: \(context)")
    }

    for question in questions {
        Message.user(question)
    }
}
```

Multimodal content uses `ContentPart`:

```swift
let messages = Messages {
    Message.user([
        .text("What's in this image?"),
        .image(base64Data: imageData, mimeType: "image/jpeg")
    ])
}
```

## Conditional Compilation Traits

Providers are gated behind Swift package traits. Guard new provider code with the appropriate flag:

```swift
#if CONDUIT_TRAIT_ANTHROPIC
let provider = AnthropicProvider(apiKey: "...")
#endif

#if CONDUIT_TRAIT_MLX
let provider = MLXProvider()
#endif
```

Some providers also use `#if canImport(...)` for platform detection:

```swift
#if canImport(FoundationModels)
let provider = FoundationModelsProvider()
#endif
```
