![unnamed-14](https://github.com/user-attachments/assets/30ca8b25-ac66-48d9-b462-afd135050304)

**Switch between Claude, GPT-4o, local Llama on Apple Silicon, and Apple's Foundation Models — by changing one line of code.**

[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-F05138.svg?style=flat&logo=swift)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2017+%20|%20macOS%2014+%20|%20visionOS%201+%20|%20Linux-007AFF.svg?style=flat)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg?style=flat)](LICENSE)
[![Version](https://img.shields.io/badge/Version-1.0.0-blue.svg?style=flat)](https://github.com/christopherkarani/Conduit/releases)

Conduit is a unified Swift 6.2 SDK for LLM inference across local and cloud providers. Every provider conforms to `TextGenerator`, giving you a single API surface whether you're running Claude in the cloud, GPT-4o via OpenRouter, Llama on your device with MLX, or Apple's built-in Foundation Models. Actors and `Sendable` types give you compile-time race-condition safety with zero extra work.

## Table of Contents

- [Quick Demo](#quick-demo)
- [Feature Matrix](#feature-matrix)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Providers](#providers)
- [Streaming](#streaming)
- [Structured Output with @Generable](#structured-output-with-generable)
- [Tool Calling](#tool-calling)
- [ChatSession](#chatsession)
- [Provider Swap in One Line](#provider-swap-in-one-line)
- [On-Device & Privacy](#on-device--privacy)
- [Model Management](#model-management)
- [Generation Config](#generation-config)
- [Design Philosophy](#design-philosophy)
- [Documentation](#documentation)
- [Contributing](#contributing)
- [License](#license)

---

## Quick Demo

```swift
import Conduit

// Cloud — Anthropic
let provider = AnthropicProvider(apiKey: "sk-ant-...")
let response = try await provider.generate(
    "Explain async/await in Swift",
    model: .claudeSonnet45,
    config: .default
)

// Swap to local MLX — same call, zero rewrite
// let provider = MLXProvider()
// let response = try await provider.generate("Explain async/await in Swift", model: .llama3_2_1B, config: .default)
```

---

## Feature Matrix

| Capability | MLX | HuggingFace | Anthropic | Kimi | MiniMax | OpenAI | Foundation Models |
|:-----------|:---:|:-----------:|:---------:|:----:|:-------:|:------:|:-----------------:|
| Text Generation | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Streaming | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Structured Output | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Tool Calling | — | — | ✓ | — | — | ✓ | — |
| Vision | — | — | ✓ | — | — | ✓ | — |
| Extended Thinking | — | — | ✓ | — | — | — | — |
| Embeddings | — | ✓ | — | — | — | ✓ | — |
| Transcription | — | ✓ | — | — | — | ✓ | — |
| Image Generation | — | ✓ | — | — | — | ✓ | — |
| Token Counting | ✓ | — | — | — | — | ✓* | — |
| Offline | ✓ | — | — | — | — | —** | ✓ |
| Privacy | ✓ | — | — | — | — | —** | ✓ |

*Estimated token counting
**Offline/privacy available when using Ollama local endpoint

---

## Installation

Add Conduit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/christopherkarani/Conduit", from: "1.0.0")
]
```

Then add `"Conduit"` to your target's dependencies.

### Enabling Optional Providers

Conduit uses Swift package traits for optional heavyweight dependencies. Enable only what you need:

```swift
// On-device MLX inference (Apple Silicon only)
.package(url: "https://github.com/christopherkarani/Conduit", from: "1.0.0", traits: ["MLX"])
```

> **Note:** Without any traits, all cloud providers (Anthropic, OpenAI, HuggingFace, Kimi, MiniMax) are available. MLX requires the trait because it links against Apple Silicon Metal libraries.

### Platform Support

| Platform | Status | Available Providers |
|:---------|:------:|:--------------------|
| macOS 14+ | **Full** | All providers |
| iOS 17+ | **Full** | All providers |
| visionOS 1+ | **Full** | All providers |
| Linux | **Partial** | Anthropic, Kimi, MiniMax, OpenAI, HuggingFace |

MLX runs on Apple Silicon only. Foundation Models requires iOS 26+ / macOS 26+. Linux builds exclude both by default.

---

## Quick Start

### Cloud (Anthropic Claude)

```swift
import Conduit

let provider = AnthropicProvider(apiKey: "sk-ant-...")
let response = try await provider.generate(
    "What are actors in Swift?",
    model: .claudeSonnet45,
    config: .default
)
print(response)
```

### Local (MLX on Apple Silicon)

```swift
import Conduit

let provider = MLXProvider()
let response = try await provider.generate(
    "What are actors in Swift?",
    model: .llama3_2_1B,
    config: .default
)
print(response)
```

### Streaming

```swift
import Conduit

let provider = AnthropicProvider(apiKey: "sk-ant-...")
for try await chunk in provider.stream(
    "Write a haiku about Swift concurrency",
    model: .claudeSonnet45,
    config: .default
) {
    print(chunk, terminator: "")
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

// Optimized presets
let provider = MLXProvider(configuration: .m1Optimized)
let provider = MLXProvider(configuration: .highPerformance)

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

**Warmup for fast first response:**

```swift
let provider = MLXProvider()
try await provider.warmUp(model: .llama3_2_1B, maxTokens: 5)
// First response is now fast (~100-300ms instead of ~2-4s)
let response = try await provider.generate("Hello", model: .llama3_2_1B)
```

### HuggingFaceProvider

Cloud inference via HuggingFace Inference API. Access hundreds of models.

**Best for:** Large models, embeddings, transcription, image generation, model variety

```swift
// Auto-detects HF_TOKEN from environment
let provider = HuggingFaceProvider()

// Explicit token
let provider = HuggingFaceProvider(token: "hf_...")
```

**Embeddings:**

```swift
let embedding = try await provider.embed(
    "Conduit makes LLM inference easy",
    model: .huggingFace("sentence-transformers/all-MiniLM-L6-v2")
)
let similarity = embedding.cosineSimilarity(with: otherEmbedding)
```

**Image Generation:**

```swift
let result = try await provider.textToImage(
    "A cat wearing a top hat, digital art",
    model: .huggingFace("stabilityai/stable-diffusion-3"),
    config: .highQuality.width(1024).height(768)
)
result.image  // SwiftUI Image, ready to display
try result.save(to: URL.documentsDirectory.appending(path: "image.png"))
```

### Foundation Models (iOS 26+)

System-integrated on-device AI. Zero setup, managed by the OS.

```swift
if #available(iOS 26.0, *) {
    let provider = FoundationModelsProvider()
    let response = try await provider.generate(
        "What can you help me with?",
        model: .foundationModels,
        config: .default
    )
}
```

### Anthropic Claude

First-class support for Anthropic's Claude models.

**Best for:** Advanced reasoning, vision, extended thinking, production applications

```swift
let provider = AnthropicProvider(apiKey: "sk-ant-...")

// Text generation
let response = try await provider.generate(
    "Explain quantum computing",
    model: .claudeSonnet45,
    config: .default.maxTokens(500)
)

// Streaming
for try await chunk in provider.stream("Write a poem about Swift", model: .claude3Haiku, config: .default) {
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

**Vision:**

```swift
let messages = Messages {
    Message.user([
        .text("What's in this image?"),
        .image(base64Data: imageData, mimeType: "image/jpeg")
    ])
}
let result = try await provider.generate(messages: messages, model: .claudeSonnet45, config: .default)
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

### Kimi Provider

Dedicated support for Moonshot's Kimi models with 256K context windows.

**Best for:** Long context tasks, coding, reasoning, document analysis

```swift
let provider = KimiProvider(apiKey: "sk-moonshot-...")
let response = try await provider.generate(
    "Summarize this 100-page document...",
    model: .kimiK2_5,
    config: .default
)
```

**Available Models:**

| Model | ID | Context |
|-------|----|---------|
| Kimi K2.5 | `.kimiK2_5` | 256K |
| Kimi K2 | `.kimiK2` | 256K |
| Kimi K1.5 | `.kimiK1_5` | 256K |

Get your API key at: https://platform.moonshot.cn/

### MiniMax Provider

Support for MiniMax models, compatible with both OpenAI and Anthropic wire formats.

```swift
let provider = MiniMaxProvider(apiKey: "your-minimax-key")
let response = try await provider.generate(
    "Hello",
    model: .abab65Chat,
    config: .default
)
```

### OpenAI Provider

Works with OpenAI, OpenRouter, Ollama, Azure, and any OpenAI-compatible endpoint.

**Supported backends:**
- **OpenAI** — Official GPT-4, DALL-E, Whisper APIs
- **OpenRouter** — 200+ models from OpenAI, Anthropic, Google, Meta, and more
- **Ollama** — Local inference server (offline / privacy)
- **Azure OpenAI** — Microsoft's enterprise OpenAI service
- **Custom** — Any OpenAI-compatible endpoint

**OpenAI (official):**

```swift
let provider = OpenAIProvider(apiKey: "sk-...")
let response = try await provider.generate("Hello", model: .gpt4o, config: .default)
```

**OpenRouter:**

```swift
// Simple
let provider = OpenAIProvider(openRouterKey: "sk-or-...")
let response = try await provider.generate(
    "Hello",
    model: .openRouter("anthropic/claude-3-opus"),
    config: .default
)

// Static factory methods
let provider = OpenAIProvider.forClaude(apiKey: "sk-or-...")  // Optimized for Claude
let provider = OpenAIProvider.fastest(apiKey: "sk-or-...")    // Latency-optimized routing
```

**Ollama (local):**

```swift
// Install: curl -fsSL https://ollama.com/install.sh | sh && ollama pull llama3.2
let provider = OpenAIProvider(endpoint: .ollama())
let response = try await provider.generate(
    "Hello from local inference!",
    model: .ollama("llama3.2"),
    config: .default
)
```

**Azure:**

```swift
let provider = OpenAIProvider(
    endpoint: .azure(resource: "my-resource", deployment: "gpt-4", apiVersion: "2024-02-15-preview"),
    apiKey: "azure-key"
)
```

**Available OpenAI Models:**

| Model | ID | Best For |
|-------|----|----|
| GPT-4o | `.gpt4o` | Latest multimodal flagship |
| GPT-4o Mini | `.gpt4oMini` | Fast, cost-effective |
| o1 | `.o1` | Complex reasoning |
| o3 Mini | `.o3Mini` | Fast reasoning |

---

## Streaming

Real-time token streaming with `AsyncSequence`:

```swift
// Simple text streaming
for try await text in provider.stream("Tell me a joke", model: .llama3_2_1B, config: .default) {
    print(text, terminator: "")
}

// With metadata (tokens per second, finish reason)
let stream = provider.streamWithMetadata(
    messages: messages,
    model: .llama3_2_1B,
    config: .default
)

for try await chunk in stream {
    print(chunk.text, terminator: "")

    if let tokensPerSecond = chunk.tokensPerSecond {
        print("Speed: \(tokensPerSecond) tok/s")
    }

    if let reason = chunk.finishReason {
        print("\nFinished: \(reason)")
    }
}
```

---

## Structured Output with @Generable

This is Conduit's most differentiated feature. The `@Generable` macro synthesizes a complete type-safe structured output pipeline at compile time — no runtime JSON parsing, no manual schema writing.

**Define your type:**

```swift
import Conduit

@Generable
struct MovieReview {
    @Guide(description: "Film title")
    let title: String

    @Guide(description: "Rating from 1 to 10", .range(1...10))
    let rating: Int

    @Guide(description: "Brief summary of the film", .maxLength(200))
    let summary: String

    @Guide(description: "Would you recommend this film?")
    let recommended: Bool
}
```

The macro synthesizes:
- `MovieReview.generationSchema` — the JSON schema to send to the provider
- `MovieReview.PartiallyGenerated` — a mirror type with all-optional fields for streaming
- `init(_ generatedContent: GeneratedContent)` — decoding from the model's response

**Generate with schema enforcement:**

```swift
let provider = AnthropicProvider(apiKey: "sk-ant-...")

let config = GenerateConfig.default
    .responseFormat(.jsonSchema(name: "MovieReview", schema: MovieReview.generationSchema))

let result = try await provider.generate(
    messages: [.user("Review the film Inception")],
    model: .claudeSonnet45,
    config: config
)

// result.text is JSON validated against the schema
// {"title": "Inception", "rating": 9, "summary": "A mind-bending thriller..."}
let review = try MovieReview(GeneratedContent(jsonString: result.text))
print(review.title)   // "Inception"
print(review.rating)  // 9
```

**Nested types and enums:**

```swift
@Generable
enum Sentiment {
    case positive
    case neutral
    case negative
}

@Generable
struct ProductAnalysis {
    @Guide(description: "Product name")
    let name: String

    @Guide(description: "Sentiment of the review")
    let sentiment: Sentiment

    @Guide(description: "Key strengths", .count(3))
    let strengths: [String]
}
```

---

## Tool Calling

Define type-safe tools using `@Generable` arguments:

```swift
struct WeatherTool: AITool {
    @Generable
    struct Arguments {
        @Guide(description: "The city to get weather for")
        let location: String

        @Guide(description: "Unit: celsius or fahrenheit")
        let unit: String
    }

    var name: String { "get_weather" }
    var description: String { "Get current weather for a location" }

    func call(arguments: Arguments) async throws -> String {
        // Call your weather API
        return "72°F, sunny in \(arguments.location)"
    }
}

// Use with a provider
let tool = WeatherTool()
let result = try await provider.generate(
    messages: [.user("What's the weather in San Francisco?")],
    model: .claudeSonnet45,
    config: .default.tools([tool])
)
```

---

## ChatSession

Stateful conversation management with automatic history tracking, tool execution, and SwiftUI integration.

```swift
let provider = AnthropicProvider(apiKey: "sk-ant-...")
let session = ChatSession(
    provider: provider,
    model: .claudeSonnet45,
    config: .default
)

// Set system prompt
session.setSystemPrompt("You are a helpful Swift coding assistant.")

// Send messages — history is managed automatically
let response = try await session.send("What are actors in Swift?")
let followUp = try await session.send("Show me a real example.")
```

**Streaming in a session:**

```swift
let stream = session.stream("Write a sorting algorithm in Swift")
for try await token in stream {
    print(token, terminator: "")
}
```

**Eager warmup for fast first-message latency:**

```swift
// Pays 1-2s warmup cost at init → first message is ~100-300ms instead of ~2-4s
let session = try await ChatSession(
    provider: MLXProvider(),
    model: .llama3_2_1B,
    warmup: .eager
)
```

**Tool execution loop:**

```swift
let executor = ToolExecutor(tools: [WeatherTool(), CalendarTool()])
session.toolExecutor = executor
session.maxToolCallRounds = 8

// ChatSession automatically runs the tool loop until the model stops calling tools
let response = try await session.send("What's the weather and my schedule today?")
```

**SwiftUI integration — ChatSession is `@Observable`:**

```swift
struct ChatView: View {
    @State var session: ChatSession<AnthropicProvider>

    var body: some View {
        VStack {
            ForEach(session.messages) { message in
                MessageBubble(message: message)
            }
            if session.isGenerating {
                ProgressView("Generating...")
            }
        }
    }
}
```

**History management:**

```swift
session.clearHistory()           // Clear all messages (keeps system prompt)
session.undoLastExchange()       // Remove last user+assistant pair
session.injectHistory(messages)  // Restore a saved conversation
await session.cancel()           // Cancel in-progress generation
```

---

## Provider Swap in One Line

Every provider conforms to `TextGenerator`, so your prompt logic is completely provider-agnostic:

```swift
func run<P: TextGenerator>(provider: P, model: P.ModelID) async throws -> String {
    try await provider.generate(
        "Plan a three-day SwiftUI sprint with daily goals.",
        model: model,
        config: .creative
    )
}

// Run the same prompt across all your providers
let anthropic = AnthropicProvider(apiKey: "sk-ant-...")
let openRouter = OpenAIProvider.forOpenRouter(apiKey: "sk-or-...", preferring: [.anthropic, .openai])
let ollama = OpenAIProvider(endpoint: .ollama(), apiKey: nil)
let mlx = MLXProvider()

let claudePlan   = try await run(provider: anthropic,  model: .claudeOpus45)
let gptPlan      = try await run(provider: openRouter, model: .openRouter("openai/gpt-4-turbo"))
let ollamaPlan   = try await run(provider: ollama,     model: .ollamaLlama32)
let localPlan    = try await run(provider: mlx,        model: .llama3_2_1B)
```

---

## On-Device & Privacy

### MLX (Apple Silicon)

Run open-weight models entirely on-device. No network traffic, no data leaves the device.

```swift
// Enable MLX trait in Package.swift, then:
let provider = MLXProvider(configuration: .m1Optimized)
let response = try await provider.generate(
    "Summarize my private notes...",
    model: .llama3_2_1B,
    config: .default
)
```

### Apple Foundation Models (iOS 26+)

Use the OS-managed on-device model. No API key, no model download.

```swift
if #available(iOS 26.0, *) {
    let provider = FoundationModelsProvider()
    let response = try await provider.generate(
        "Summarize this text",
        model: .foundationModels,
        config: .default
    )
}
```

### Ollama (Local Server — Linux compatible)

Run any open-weight model on localhost with Ollama.

```bash
curl -fsSL https://ollama.com/install.sh | sh
ollama pull llama3.2
```

```swift
let provider = OpenAIProvider(endpoint: .ollama())
let response = try await provider.generate(
    "Hello from local inference!",
    model: .ollama("llama3.2"),
    config: .default
)
```

---

## Model Management

Download models from HuggingFace Hub for MLX inference with progress tracking.

### Downloading

```swift
let manager = ModelManager.shared

// Download with progress
let url = try await manager.download(.llama3_2_1B) { progress in
    print("Downloading: \(progress.percentComplete)%")
    if let speed = progress.formattedSpeed { print("Speed: \(speed)") }
    if let eta = progress.formattedETA { print("ETA: \(eta)") }
}

// Validate before downloading (checks MLX compatibility, estimates size)
let url = try await manager.downloadValidated(.llama3_2_1B) { progress in
    print("Progress: \(progress.percentComplete)%")
}
```

### SwiftUI Integration

`DownloadTask` is `@Observable` — bind it directly to a `ProgressView`:

```swift
struct ModelDownloadView: View {
    @State private var downloadTask: DownloadTask?

    var body: some View {
        if let task = downloadTask {
            VStack {
                ProgressView(value: task.progress.fractionCompleted)
                Text("\(task.progress.percentComplete)%")
                if let speed = task.progress.formattedSpeed { Text(speed) }
                Button("Cancel") { task.cancel() }
            }
        } else {
            Button("Download Llama 3.2") {
                Task {
                    downloadTask = await ModelManager.shared.downloadTask(for: .llama3_2_1B)
                }
            }
        }
    }
}
```

### Cache Management

```swift
let manager = ModelManager.shared

if await manager.isCached(.llama3_2_1B) { print("Model ready") }

let cached = try await manager.cachedModels()
for model in cached {
    print("\(model.identifier.displayName): \(model.size.formatted)")
}

// Evict least-recently-used models to fit storage limit
try await manager.evictToFit(maxSize: .gigabytes(30))

// Remove specific model or clear everything
try await manager.delete(.llama3_2_1B)
try await manager.clearCache()
```

### Size Estimation

```swift
if let size = await manager.estimateDownloadSize(.llama3_2_1B) {
    print("Download size: \(size.formatted)")  // e.g., "2.1 GB"
}
```

Browse the [mlx-community on HuggingFace](https://huggingface.co/mlx-community) for 4-bit quantized models optimized for Apple Silicon.

**Storage locations:**
- MLX models: `~/Library/Caches/Conduit/Models/mlx/`
- HuggingFace models: `~/Library/Caches/Conduit/Models/huggingface/`

---

## Generation Config

Control generation with presets or a fluent API:

```swift
// Presets
.default      // temperature: 0.7, topP: 0.9, maxTokens: 1024
.creative     // temperature: 0.9, topP: 0.95, frequencyPenalty: 0.5
.precise      // temperature: 0.1, topP: 0.5, repetitionPenalty: 1.1
.code         // temperature: 0.2, topP: 0.9, stopSequences: ["```", "\n\n\n"]

// Fluent API
let config = GenerateConfig.default
    .temperature(0.8)
    .maxTokens(500)

// Full constructor
let config = GenerateConfig(
    temperature: 0.8,
    maxTokens: 500,
    topP: 0.9,
    stopSequences: ["END"]
)
```

---

## Design Philosophy

- **Actors everywhere** — All providers are actors, giving compile-time data-race safety via Swift 6.2 strict concurrency
- **Explicit model selection** — No magic auto-detection; you always know exactly which model is running
- **Protocol-first** — Everything conforms to `TextGenerator`, `EmbeddingGenerator`, or `ImageGenerator`, so your code stays provider-agnostic
- **Sendable by default** — All public types conform to `Sendable`, safe to pass across actor boundaries

---

## Documentation

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

1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b feature/amazing-feature`
3. **Commit** your changes with a descriptive message
4. **Push** and **open a Pull Request**

Please ensure your code follows existing conventions, includes tests (Swift Testing framework), and maintains backward compatibility.

---

## Community

- **[GitHub Discussions](https://github.com/christopherkarani/Conduit/discussions)** — Ask questions, share ideas
- **[GitHub Issues](https://github.com/christopherkarani/Conduit/issues)** — Report bugs, request features

---

## License

MIT License — see [LICENSE](LICENSE) for details.
