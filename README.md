# SwiftAI

**Unified Swift SDK for LLM inference across local and cloud providers**

[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-F05138.svg?style=flat&logo=swift)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2017+%20|%20macOS%2014+%20|%20visionOS%201+-007AFF.svg?style=flat&logo=apple)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg?style=flat)](LICENSE)
[![Version](https://img.shields.io/badge/Version-0.1.0-blue.svg?style=flat)](https://github.com/christopherkarani/SwiftAI/releases)

---

SwiftAI provides a clean, idiomatic Swift interface for LLM inference. Choose your provider explicitly—local inference with MLX on Apple Silicon, cloud inference via HuggingFace, or system-integrated AI with Apple Foundation Models on iOS 26+.

## Features

| Capability | MLX | HuggingFace | Foundation Models |
|:-----------|:---:|:-----------:|:-----------------:|
| Text Generation | ✓ | ✓ | ✓ |
| Streaming | ✓ | ✓ | ✓ |
| Embeddings | — | ✓ | — |
| Transcription | — | ✓ | — |
| Image Generation | — | ✓ | — |
| Token Counting | ✓ | — | — |
| Offline | ✓ | — | ✓ |
| Privacy | ✓ | — | ✓ |

## Installation

Add SwiftAI to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/christopherkarani/SwiftAI", from: "0.1.0")
]
```

Then add `"SwiftAI"` to your target's dependencies.

## Quick Start

### Local Generation (MLX)

```swift
import SwiftAI

let provider = MLXProvider()
let response = try await provider.generate(
    "Explain quantum computing in simple terms",
    model: .llama3_2_1B,
    config: .default
)
print(response)
```

### Cloud Generation (HuggingFace)

```swift
let provider = HuggingFaceProvider() // Uses HF_TOKEN environment variable
let response = try await provider.generate(
    "Write a haiku about Swift",
    model: .huggingFace("meta-llama/Llama-3.1-8B-Instruct"),
    config: .creative
)
print(response)
```

### Streaming

```swift
let provider = MLXProvider()
let stream = provider.stream(
    "Tell me a story about a robot",
    model: .llama3_2_3B,
    config: .default
)

for try await chunk in stream {
    print(chunk.text, terminator: "")
}
```

---

## Providers

### MLXProvider

Local inference on Apple Silicon. Zero network traffic, complete privacy.

**Best for:** Privacy-sensitive apps, offline functionality, consistent latency

```swift
// Default configuration
let provider = MLXProvider()

// Optimized for M1 devices
let provider = MLXProvider(configuration: .m1Optimized)

// Full control
let config = MLXConfiguration.default
    .memoryLimit(.gigabytes(8))
    .withQuantizedKVCache(bits: 4)
let provider = MLXProvider(configuration: config)
```

**Configuration Presets:**

| Preset | Memory | Use Case |
|--------|--------|----------|
| `.default` | Auto | Balanced performance |
| `.m1Optimized` | 6 GB | M1 MacBooks, base iPads |
| `.mProOptimized` | 12 GB | M1/M2 Pro, Max chips |
| `.memoryEfficient` | 4 GB | Constrained devices |
| `.highPerformance` | 16+ GB | M2/M3 Max, Ultra |

**Warmup for Fast First Response:**

```swift
let provider = MLXProvider()

// Warm up Metal shaders before first generation
try await provider.warmUp(model: .llama3_2_1B, maxTokens: 5)

// Now first response is fast
let response = try await provider.generate("Hello", model: .llama3_2_1B)
```

### HuggingFaceProvider

Cloud inference via HuggingFace Inference API. Access hundreds of models.

**Best for:** Large models, embeddings, transcription, image generation, model variety

**Setup:**
```bash
export HF_TOKEN=hf_your_token_here
```

```swift
// Auto-detects HF_TOKEN from environment
let provider = HuggingFaceProvider()

// Or provide token explicitly
let provider = HuggingFaceProvider(token: "hf_...")

// Custom configuration
let config = HFConfiguration.default.timeout(120)
let provider = HuggingFaceProvider(configuration: config)
```

**Embeddings:**

```swift
let provider = HuggingFaceProvider()

let embedding = try await provider.embed(
    "SwiftAI makes LLM inference easy",
    model: .huggingFace("sentence-transformers/all-MiniLM-L6-v2")
)

print("Dimensions: \(embedding.dimensions)")
print("Vector: \(embedding.vector)")

// Similarity comparison
let other = try await provider.embed("AI frameworks for Swift", model: /* ... */)
let similarity = embedding.cosineSimilarity(with: other)
```

**Transcription:**

```swift
let provider = HuggingFaceProvider()

let result = try await provider.transcribe(
    audioURL: audioFileURL,
    model: .huggingFace("openai/whisper-large-v3"),
    config: .detailed
)

print(result.text)
for segment in result.segments {
    print("\(segment.startTime)s: \(segment.text)")
}
```

**Image Generation:**

```swift
let provider = HuggingFaceProvider()

// Simple text-to-image with defaults
let result = try await provider.textToImage(
    "A cat wearing a top hat, digital art",
    model: .huggingFace("stabilityai/stable-diffusion-3")
)

// Use directly in SwiftUI
result.image  // SwiftUI Image (cross-platform)

// With configuration presets
let result = try await provider.textToImage(
    "Mountain landscape at sunset, photorealistic",
    model: .huggingFace("stabilityai/stable-diffusion-xl-base-1.0"),
    config: .highQuality.width(1024).height(768)
)

// Available presets: .default, .highQuality, .fast, .square512, .square1024, .landscape, .portrait

// Save to file
try result.save(to: URL.documentsDirectory.appending(path: "landscape.png"))

// Save to Photos library (iOS only, requires NSPhotoLibraryAddUsageDescription)
try await result.saveToPhotos()

// Access raw data if needed
let data = result.data
```

### Foundation Models (iOS 26+)

System-integrated on-device AI. Zero setup, managed by the OS.

**Best for:** iOS 26+ apps, system integration, no model downloads

```swift
if #available(iOS 26.0, *) {
    let provider = FoundationModelsProvider()
    let response = try await provider.generate(
        "What can you help me with?",
        model: .foundationModels,
        config: .default
    )
    print(response)
}
```

---

## Core Concepts

### Model Identifiers

SwiftAI requires explicit model selection—no magic auto-detection:

```swift
// MLX models (local)
.mlx("mlx-community/Llama-3.2-1B-Instruct-4bit")
.llama3_2_1B  // Convenience alias
.phi4
.qwen2_5_3B

// HuggingFace models (cloud)
.huggingFace("meta-llama/Llama-3.1-70B-Instruct")
.huggingFace("sentence-transformers/all-MiniLM-L6-v2")

// Foundation Models (iOS 26+)
.foundationModels
```

### Generation Config

Control generation behavior with presets or custom settings:

```swift
// Presets
.default      // temperature: 0.7, topP: 0.9
.creative     // temperature: 1.0, topP: 0.95
.precise      // temperature: 0.3, topP: 0.8
.code         // temperature: 0.2, topP: 0.9

// Custom
let config = GenerateConfig(
    temperature: 0.8,
    maxTokens: 500,
    topP: 0.9,
    stopSequences: ["END"]
)

// Fluent API
let config = GenerateConfig.default
    .temperature(0.8)
    .maxTokens(500)
```

### Messages

Build conversations with the `Messages` result builder:

```swift
let messages = Messages {
    Message.system("You are a Swift expert.")
    Message.user("What are actors?")
}

let result = try await provider.generate(
    messages: messages,
    model: .llama3_2_1B,
    config: .default
)

print(result.text)
print("Tokens: \(result.usage.totalTokens)")
```

---

## Streaming

Real-time token streaming with `AsyncSequence`:

```swift
// Simple text streaming
for try await text in provider.stream("Tell me a joke", model: .llama3_2_1B) {
    print(text, terminator: "")
}

// With metadata
let stream = provider.streamWithMetadata(
    messages: messages,
    model: .llama3_2_1B,
    config: .default
)

for try await chunk in stream {
    print(chunk.text, terminator: "")

    if let tokensPerSecond = chunk.tokensPerSecond {
        // Track performance
    }

    if let reason = chunk.finishReason {
        print("\nFinished: \(reason)")
    }
}

// Collect all chunks into final result
let result = try await stream.collectWithMetadata()
print("Total tokens: \(result.tokenCount)")
```

---

## ChatSession

Stateful conversation management with automatic history:

```swift
let session = try await ChatSession(
    provider: MLXProvider(),
    model: .llama3_2_1B,
    systemPrompt: "You are a helpful coding assistant.",
    warmup: .eager  // Fast first response
)

// Send messages—history is managed automatically
let response1 = try await session.send("What is a protocol in Swift?")
let response2 = try await session.send("Can you give me an example?")

// Stream responses
for try await text in session.streamResponse("Explain associated types") {
    print(text, terminator: "")
}

// Access conversation history
let history = await session.messages

// Clear and start fresh
await session.clearHistory()
```

**Warmup Options:**

| Option | First Message Latency | Use Case |
|--------|----------------------|----------|
| `nil` | 2-4 seconds | Infrequent use |
| `.default` | 1-2 seconds | Balanced |
| `.eager` | 100-300ms | Chat interfaces |

---

## Model Management

Download, cache, and manage models:

```swift
let manager = ModelManager.shared

// Check if model is cached
if await manager.isCached(.llama3_2_1B) {
    print("Model ready")
}

// Download with progress
let url = try await manager.download(.llama3_2_1B) { progress in
    print("Downloading: \(Int(progress.percentComplete))%")
}

// Cache management
let size = await manager.cacheSize()
print("Cache size: \(size.formatted())")

// Evict to fit storage limit
try await manager.evictToFit(maxSize: .gigabytes(30))

// Remove specific model
try await manager.remove(.llama3_2_1B)
```

**Storage Location:** `~/Library/Caches/SwiftAI/Models/`

---

## Token Counting

Manage context windows with precise token counts:

```swift
let provider = MLXProvider()

// Count tokens in text
let count = try await provider.countTokens(
    in: "Hello, world!",
    for: .llama3_2_1B
)
print("Tokens: \(count.count)")

// Count tokens in conversation (includes chat template overhead)
let messageCount = try await provider.countTokens(
    in: messages,
    for: .llama3_2_1B
)

// Check if content fits in context window
if messageCount.fitsInContext(size: 4096) {
    // Safe to generate
}

// Encode/decode
let tokens = try await provider.encode("Hello", for: .llama3_2_1B)
let decoded = try await provider.decode(tokens, for: .llama3_2_1B)
```

---

## Error Handling

SwiftAI provides detailed, actionable errors:

```swift
do {
    let response = try await provider.generate(prompt, model: model)
} catch AIError.modelNotCached(let model) {
    // Download the model first
    try await ModelManager.shared.download(model)
} catch AIError.providerUnavailable(let reason) {
    // Check availability requirements
    print("Provider unavailable: \(reason)")
} catch AIError.tokenLimitExceeded(let count, let limit) {
    // Truncate input
    print("Input has \(count) tokens, limit is \(limit)")
} catch AIError.networkError(let message) {
    // Handle connectivity issues
    print("Network error: \(message)")
}
```

---

## Requirements

| Platform | Minimum Version |
|----------|-----------------|
| iOS | 17.0 |
| macOS | 14.0 |
| visionOS | 1.0 |
| Swift | 6.2 |

**MLX Provider:** Requires Apple Silicon (arm64)

**Foundation Models:** Requires iOS 26.0+

---

## Design Principles

1. **Explicit Model Selection** — You choose your provider. No magic auto-detection.
2. **Swift 6.2 Concurrency** — Actors, Sendable types, and AsyncSequence throughout.
3. **Progressive Disclosure** — Simple one-liners for beginners, full control for experts.
4. **Protocol-Oriented** — Extensible via protocols with associated types.

---

## License

MIT License — see [LICENSE](LICENSE) for details.
