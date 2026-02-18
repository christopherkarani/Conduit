# Conduit Adds Kimi and MiniMax: Two New Cloud Providers with Massive Context Windows

We're excited to announce that Conduit now supports **Kimi** (Moonshot AI) and **MiniMax**—two powerful cloud AI providers that bring massive context windows and competitive pricing to your Swift applications.

## What is Conduit?

For those new to the project, Conduit is a unified Swift 6.2 SDK for AI inference. It provides a single, consistent API that works across:

- **Local inference**: MLX (Apple Silicon), Ollama, CoreML, llama.cpp
- **Cloud APIs**: Anthropic, OpenAI, HuggingFace, OpenRouter
- **System AI**: Apple Foundation Models (iOS 26+)

The key insight behind Conduit is that switching between providers shouldn't require rewriting your prompt pipeline. Everything conforms to the `TextGenerator` protocol, so your app code stays provider-agnostic.

## Meet the New Providers

### 🌙 Kimi by Moonshot AI

Kimi has been making waves in the AI community for its impressive **256K token context window**—available on all models. That's enough to process entire novels, large codebases, or hundreds of pages of documentation in a single request.

**Key Features:**
- **256K context window** (4x larger than GPT-4's 128K)
- Strong reasoning and coding capabilities
- OpenAI-compatible API
- Competitive pricing

**Available Models:**
- `kimi-k2-5` — Flagship model with advanced reasoning
- `kimi-k2` — General-purpose workhorse
- `kimi-k1-5` — Long context specialist

**Usage:**
```swift
import Conduit

let provider = KimiProvider(apiKey: "sk-moonshot-...")

// Process an entire codebase
let response = try await provider.generate(
    "Review this iOS project for memory leaks...",
    model: .kimiK2_5,
    config: .default.maxTokens(4000)
)

// Streaming for real-time responses
for try await chunk in provider.stream(
    "Explain this 200-page contract...",
    model: .kimiK2_5
) {
    print(chunk, terminator: "")
}
```

Authentication uses the `MOONSHOT_API_KEY` environment variable or explicit API key:

```bash
export MOONSHOT_API_KEY=sk-moonshot-...
```

### 🔷 MiniMax

MiniMax offers another compelling option with **128K+ context windows** and a focus on coding and agentic workflows. Their M2 model delivers strong performance at competitive price points.

**Key Features:**
- **128K+ context window**
- Optimized for coding tasks
- Good for agentic workflows
- Cost-effective inference

**Available Models:**
- `mini-max-m2` — Primary model for general tasks
- Additional variants for specialized use cases

**Usage:**
```swift
let provider = MiniMaxProvider(apiKey: "sk-minimax-...")

let result = try await provider.generate(
    "Build a SwiftUI todo app with Core Data",
    model: .miniMaxM2
)
```

## Design Philosophy: Clean APIs Through Internal Reuse

Both Kimi and MiniMax use OpenAI-compatible APIs internally. We could have exposed them through `OpenAIProvider` with custom endpoints, but that would lead to:

```swift
// ❌ What we avoided
let provider = OpenAIProvider(
    endpoint: .custom(URL(string: "https://api.moonshot.cn/v1")!),
    apiKey: "..."
)
let response = try await provider.generate(
    "Hello",
    model: .openRouter("kimi-k2-5")  // Confusing!
)
```

Instead, we built **dedicated providers** with clean naming:

```swift
// ✅ What we shipped
let provider = KimiProvider(apiKey: "...")
let response = try await provider.generate(
    "Hello",
    model: .kimiK2_5  // Clear and discoverable
)
```

### How We Did It

Under the hood, `KimiProvider` and `MiniMaxProvider` wrap `OpenAIProvider` for HTTP handling, SSE streaming, retries, and error mapping. This gives us:

1. **Code reuse** — ~2000 lines of HTTP infrastructure shared
2. **Clean APIs** — Provider-specific types and documentation
3. **Type safety** — `KimiModelID` can't be confused with `OpenAIModelID`
4. **Discoverability** — Xcode autocomplete shows `.kimiK2_5`, not generic strings

Here's the implementation pattern:

```swift
public actor KimiProvider: AIProvider, TextGenerator {
    public typealias ModelID = KimiModelID
    
    // Public API is pure Kimi
    public func generate(
        _ prompt: String,
        model: KimiModelID,  // Type-safe
        config: GenerateConfig
    ) async throws -> String {
        // Internal reuse of OpenAIProvider
        try await internalProvider.generate(
            prompt,
            model: OpenAIModelID(model.rawValue),  // Convert internally
            config: config
        )
    }
}
```

## Updated Feature Matrix

| Capability | MLX | HuggingFace | Anthropic | **Kimi** | **MiniMax** | OpenAI | Foundation |
|:-----------|:---:|:-----------:|:---------:|:--------:|:-----------:|:------:|:----------:|
| Text Generation | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Streaming | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Structured Output | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Tool Calling | — | — | ✓ | — | — | ✓ | — |
| Vision | — | — | ✓ | — | — | ✓ | — |
| Extended Thinking | — | — | ✓ | — | — | — | — |
| **Context Window** | 4K-128K | 4K-128K | 200K | **256K** | **128K+** | 128K | 4K |
| Offline | ✓ | — | — | — | — | — | ✓ |

## Model Registry Integration

Both providers are fully integrated with Conduit's `ModelRegistry` for model discovery:

```swift
// Find all Kimi models
let kimiModels = ModelRegistry.models(for: .kimi)

// Get info for a specific model
if let info = ModelRegistry.info(for: .kimiK2_5) {
    print("\(info.name): \(info.contextWindow) tokens")
    print("Capabilities: \(info.capabilities)")
}

// Find models by capability
let reasoningModels = ModelRegistry.models(with: .reasoning)
```

## Platform Support

Both providers work across all supported platforms:

| Platform | Status | Available Providers |
|:---------|:------:|:--------------------|
| macOS 14+ | **Full** | MLX, Anthropic, **Kimi**, **MiniMax**, OpenAI, HuggingFace, Foundation Models |
| iOS 17+ | **Full** | MLX, Anthropic, **Kimi**, **MiniMax**, OpenAI, HuggingFace, Foundation Models |
| visionOS 1+ | **Full** | MLX, Anthropic, **Kimi**, **MiniMax**, OpenAI, HuggingFace, Foundation Models |
| **Linux** | **Partial** | Anthropic, **Kimi**, **MiniMax**, OpenAI, HuggingFace |

## Getting Started

Add Conduit to your `Package.swift`:

```swift
dependencies: [
    .package(
        url: "https://github.com/christopherkarani/Conduit",
        from: "1.0.0",
        traits: ["Kimi", "MiniMax", "OpenAI"]
    )
]
```

**Note:** The `OpenAI` trait is required because both Kimi and MiniMax reuse OpenAI's HTTP infrastructure internally.

## Use Cases

### Document Analysis with Kimi

Kimi's 256K context window excels at processing large documents:

```swift
let provider = KimiProvider(apiKey: "...")

// Analyze a 500-page PDF in one request
let legalAnalysis = try await provider.generate(
    "Review this contract and identify all liability clauses...",
    model: .kimiK2_5,
    config: .default.maxTokens(8000)
)
```

### Code Generation with MiniMax

MiniMax works well for coding tasks and agentic workflows:

```swift
let provider = MiniMaxProvider(apiKey: "...")

// Build complex features
let code = try await provider.generate(
    """
    Create a Swift async network layer with:
    - Retry logic with exponential backoff
    - Request/response logging
    - Token refresh handling
    """,
    model: .miniMaxM2
)
```

### Multi-Provider Fallbacks

Use Swift's concurrency to query multiple providers simultaneously:

```swift
func gatherResponses(prompt: String) async throws -> [String] {
    let kimi = KimiProvider(apiKey: kimiKey)
    let minimax = MiniMaxProvider(apiKey: minimaxKey)
    let anthropic = AnthropicProvider(apiKey: anthropicKey)
    
    async let kimiTask = kimi.generate(prompt, model: .kimiK2_5)
    async let minimaxTask = minimax.generate(prompt, model: .miniMaxM2)
    async let claudeTask = anthropic.generate(prompt, model: .claudeSonnet45)
    
    return try await [kimiTask, minimaxTask, claudeTask]
}
```

## What's Next?

We're actively working on:

- **Embeddings support** for Kimi and MiniMax
- **Tool calling** if/when these providers support function calling
- **Vision support** for multimodal models
- **Additional providers**: Grok, Cohere, and more

## Try It Today

The Kimi and MiniMax providers are available now in the `0213` branch:

```bash
git clone https://github.com/christopherkarani/Conduit
cd Conduit
git checkout 0213
```

Or use Swift Package Manager with the branch:

```swift
.package(
    url: "https://github.com/christopherkarani/Conduit",
    branch: "0213",
    traits: ["Kimi", "MiniMax", "OpenAI"]
)
```

We'd love your feedback! Open an issue or join the discussion on GitHub.

---

**Links:**
- GitHub: https://github.com/christopherkarani/Conduit
- Kimi API Docs: https://platform.moonshot.cn/
- MiniMax API Docs: https://www.minimaxi.com/
