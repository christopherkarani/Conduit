# Conduit

**Unified Swift SDK for LLM inference across local and cloud providers**

[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-F05138.svg?style=flat&logo=swift)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2017+%20|%20macOS%2014+%20|%20visionOS%201+%20|%20Linux-007AFF.svg?style=flat)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg?style=flat)](LICENSE)
[![Version](https://img.shields.io/badge/Version-0.6.0-blue.svg?style=flat)](https://github.com/christopherkarani/Conduit/releases)

---

Conduit provides a clean, idiomatic Swift interface for LLM inference. Choose your provider explicitly—local inference with MLX on Apple Silicon, cloud inference via HuggingFace, or system-integrated AI with Apple Foundation Models on iOS 26+.

## Why Conduit?

- **One API, Many Providers** — Switch between local (MLX), cloud (Anthropic, OpenAI, HuggingFace), and system (Foundation Models) with minimal code changes
- **Type-Safe Structured Output** — Generate Swift types directly from LLM responses with the `@Generable` macro
- **Privacy-First Options** — Run models entirely on-device with MLX or Foundation Models
- **Swift 6.2 Concurrency** — Built from the ground up with actors, Sendable types, and AsyncSequence

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Providers](#providers)
- [Streaming](#streaming)
- [Structured Output](#structured-output)
- [Tool Calling](#tool-calling)
- [ChatSession](#chatsession)
- [Documentation](#documentation)
- [Contributing](#contributing)
- [Community](#community)
- [License](#license)

## Features

| Capability | MLX | HuggingFace | Anthropic | Foundation Models |
|:-----------|:---:|:-----------:|:---------:|:-----------------:|
| Text Generation | ✓ | ✓ | ✓ | ✓ |
| Streaming | ✓ | ✓ | ✓ | ✓ |
| Structured Output | ✓ | ✓ | ✓ | ✓ |
| Tool Calling | — | — | ✓ | — |
| Vision | — | — | ✓ | — |
| Extended Thinking | — | — | ✓ | — |
| Embeddings | — | ✓ | — | — |
| Transcription | — | ✓ | — | — |
| Image Generation | — | ✓ | — | — |
| Token Counting | ✓ | — | — | — |
| Offline | ✓ | — | — | ✓ |
| Privacy | ✓ | — | — | ✓ |

## Installation

Add Conduit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/christopherkarani/Conduit", from: "2.0.0")
]
```

Then add `"Conduit"` to your target's dependencies.

### Enabling MLX (Apple Silicon Only)

To use on-device MLX inference, enable the `MLX` trait:

```swift
dependencies: [
    .package(url: "https://github.com/christopherkarani/Conduit", from: "2.0.0", traits: ["MLX"])
]
```

> **Note**: MLX requires Apple Silicon with Metal GPU. Without the trait, only cloud providers are available.

## Platform Support

| Platform | Status | Available Providers |
|:---------|:------:|:--------------------|
| macOS 14+ | **Full** | MLX, Anthropic, OpenAI, HuggingFace, Foundation Models |
| iOS 17+ | **Full** | MLX, Anthropic, OpenAI, HuggingFace, Foundation Models |
| visionOS 1+ | **Full** | MLX, Anthropic, OpenAI, HuggingFace, Foundation Models |
| **Linux** | **Partial** | Anthropic, OpenAI, HuggingFace |

### Building on Linux

Conduit supports Linux for server-side Swift deployments. Build normally with Swift 6.2+:

```bash
swift build
swift test
```

By default, MLX dependencies are excluded (no trait enabled). This makes Conduit Linux-compatible out of the box.

### Linux Limitations

- **MLX Provider**: Requires Apple Silicon with Metal GPU (not available on Linux)
- **Foundation Models**: Requires iOS 26+/macOS 26+ (not available on Linux)
- **Image Generation**: `GeneratedImage.image` returns `nil` (use `data` or `save(to:)`)
- **Keychain**: Token storage falls back to environment variables

### Local Inference on Linux

For local LLM inference on Linux, use **Ollama** via the OpenAI provider:

```bash
# Install Ollama on Linux
curl -fsSL https://ollama.com/install.sh | sh

# Pull a model
ollama pull llama3.2
```

```swift
import Conduit

// Use Ollama for local inference on Linux
let provider = OpenAIProvider(endpoint: .ollama, apiKey: nil)
let response = try await provider.generate(
    "Hello from Linux!",
    model: .ollama("llama3.2"),
    config: .default
)
```

## Quick Start

### Local Generation (MLX)

```swift
import Conduit

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
    "Conduit makes LLM inference easy",
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

### Anthropic Claude

Conduit includes first-class support for Anthropic's Claude models via the Anthropic API.

**Best for:** Advanced reasoning, vision tasks, extended thinking, production applications

**Setup:**
```bash
export ANTHROPIC_API_KEY=sk-ant-api-03-...
```

```swift
import Conduit

// Simple generation
let provider = AnthropicProvider(apiKey: "sk-ant-...")
let response = try await provider.generate(
    "Explain quantum computing",
    model: .claudeSonnet45,
    config: .default.maxTokens(500)
)

// Streaming
for try await chunk in provider.stream(
    "Write a poem about Swift",
    model: .claude3Haiku,
    config: .default
) {
    print(chunk, terminator: "")
}
```

**Available Models:**

| Model | ID | Best For |
|-------|----|----|
| Claude Opus 4.5 | `.claudeOpus45` | Most capable, complex reasoning |
| Claude Sonnet 4.5 | `.claudeSonnet45` | Balanced performance and speed |
| Claude 3.5 Sonnet | `.claude35Sonnet` | Fast, high-quality responses |
| Claude 3 Haiku | `.claude3Haiku` | Fastest, most cost-effective |

**Features:**

- Text generation (streaming and non-streaming)
- Multi-turn conversations with context
- Vision support (multimodal image+text)
- Extended thinking mode for complex reasoning
- Comprehensive error handling
- Environment variable support (ANTHROPIC_API_KEY)

**Vision Example:**

```swift
let messages = Messages {
    Message.user([
        .text("What's in this image?"),
        .image(base64Data: imageData, mimeType: "image/jpeg")
    ])
}

let result = try await provider.generate(
    messages: messages,
    model: .claudeSonnet45,
    config: .default
)
```

**Extended Thinking:**

```swift
var config = AnthropicConfiguration.standard(apiKey: "sk-ant-...")
config.thinkingConfig = .standard

let provider = AnthropicProvider(configuration: config)
let result = try await provider.generate(
    "Solve this complex problem...",
    model: .claudeOpus45,
    config: .default
)
```

Get your API key at: https://console.anthropic.com/

---

## Core Concepts

### Model Identifiers

Conduit requires explicit model selection—no magic auto-detection:

```swift
// MLX models (local)
.mlx("mlx-community/Llama-3.2-1B-Instruct-4bit")
.llama3_2_1B  // Convenience alias
.phi4
.qwen2_5_3B

// HuggingFace models (cloud)
.huggingFace("meta-llama/Llama-3.1-70B-Instruct")
.huggingFace("sentence-transformers/all-MiniLM-L6-v2")

// Anthropic models (cloud)
.claudeOpus45
.claudeSonnet45
.claude35Sonnet
.claude3Haiku

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

## Structured Output

Generate type-safe structured responses using the `@Generable` macro, mirroring Apple's FoundationModels API from iOS 26.

### Defining Generable Types

```swift
import Conduit

@Generable
struct Recipe {
    @Guide("The recipe title")
    let title: String

    @Guide("Cooking time in minutes", .range(1...180))
    let cookingTime: Int

    @Guide("Difficulty level", .anyOf(["easy", "medium", "hard"]))
    let difficulty: String

    @Guide("List of ingredients")
    let ingredients: [String]
}
```

### Generating Structured Responses

```swift
let provider = AnthropicProvider(apiKey: "sk-ant-...")

// Generate typed response
let recipe = try await provider.generate(
    "Create a recipe for chocolate chip cookies",
    returning: Recipe.self,
    model: .claudeSonnet45
)

print(recipe.title)           // "Classic Chocolate Chip Cookies"
print(recipe.cookingTime)     // 25
print(recipe.difficulty)      // "easy"
print(recipe.ingredients)     // ["flour", "butter", "chocolate chips", ...]
```

### Streaming Structured Output

Get progressive updates as the response is generated:

```swift
let stream = provider.stream(
    "Generate a detailed recipe",
    returning: Recipe.self,
    model: .claudeSonnet45
)

for try await partial in stream {
    // Update UI progressively
    if let title = partial.title {
        titleLabel.text = title
    }
    if let ingredients = partial.ingredients {
        updateIngredientsList(ingredients)
    }
}

// Get final complete result
let recipe = try await stream.collect()
```

### Available Constraints

| Type | Constraints |
|------|-------------|
| String | `.pattern(_:)`, `.anyOf(_:)`, `.minLength(_:)`, `.maxLength(_:)` |
| Int/Double | `.range(_:)`, `.minimum(_:)`, `.maximum(_:)` |
| Array | `.count(_:)`, `.minimumCount(_:)`, `.maximumCount(_:)` |

---

## Tool Calling

Define and execute tools that LLMs can invoke during generation.

### Defining Tools

```swift
struct WeatherTool: AITool {
    @Generable
    struct Arguments {
        @Guide("City name to get weather for")
        let city: String

        @Guide("Temperature unit", .anyOf(["celsius", "fahrenheit"]))
        let unit: String?
    }

    var description: String { "Get current weather for a city" }

    func call(arguments: Arguments) async throws -> String {
        // Implement weather lookup
        return "Weather in \(arguments.city): 22C, Sunny"
    }
}
```

### Executing Tools

```swift
// Create executor and register tools
let executor = AIToolExecutor()
await executor.register(WeatherTool())
await executor.register(SearchTool())

// Configure provider with tools
let config = GenerateConfig.default
    .tools([WeatherTool(), SearchTool()])
    .toolChoice(.auto)

// Generate with tool access
let response = try await provider.generate(
    messages: messages,
    model: .claudeSonnet45,
    config: config
)

// Handle tool calls if present
if let toolCalls = response.toolCalls {
    let results = try await executor.execute(toolCalls: toolCalls)
    // Continue conversation with results...
}
```

### Tool Choice Options

```swift
.toolChoice(.auto)              // Model decides whether to use tools
.toolChoice(.required)          // Model must use a tool
.toolChoice(.none)              // Model cannot use tools
.toolChoice(.tool(name: "weather"))  // Model must use specific tool
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

**Storage Location:** `~/Library/Caches/Conduit/Models/`

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

Conduit provides detailed, actionable errors:

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
5. **Type-Safe Structured Output** — @Generable macro mirrors Apple's FoundationModels API.
6. **Tool Integration** — First-class support for LLM tool/function calling.

---

## Documentation

Comprehensive guides are available in the [docs](docs/) folder:

| Guide | Description |
|-------|-------------|
| [Getting Started](docs/GettingStarted.md) | Installation, setup, and first generation |
| [Providers](docs/Providers/README.md) | Detailed guides for each provider |
| [Structured Output](docs/StructuredOutput.md) | Type-safe responses with `@Generable` |
| [Tool Calling](docs/ToolCalling.md) | Define and execute LLM-invokable tools |
| [Streaming](docs/Streaming.md) | Real-time token streaming patterns |
| [ChatSession](docs/ChatSession.md) | Stateful conversation management |
| [Model Management](docs/ModelManagement.md) | Download, cache, and manage models |
| [Error Handling](docs/ErrorHandling.md) | Handle errors gracefully |
| [Architecture](docs/Architecture.md) | Design principles and internals |

---

## Contributing

We welcome contributions! Here's how to get started:

1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b feature/amazing-feature`
3. **Commit** your changes: `git commit -m 'Add amazing feature'`
4. **Push** to the branch: `git push origin feature/amazing-feature`
5. **Open** a Pull Request

Please ensure your code:
- Follows existing code style and conventions
- Includes tests for new functionality
- Updates documentation as needed
- Maintains backward compatibility

---

## Community

- **[GitHub Discussions](https://github.com/christopherkarani/Conduit/discussions)** — Ask questions, share ideas
- **[GitHub Issues](https://github.com/christopherkarani/Conduit/issues)** — Report bugs, request features

---

## License

MIT License — see [LICENSE](LICENSE) for details.
