# Providers Overview

Conduit supports multiple LLM providers, each with unique strengths. This guide helps you choose the right one for your application.

## Table of Contents

- [Provider Comparison](#provider-comparison)
- [Choosing a Provider](#choosing-a-provider)
- [Provider Guides](#provider-guides)
- [Switching Providers](#switching-providers)

---

## Provider Comparison

### Capabilities Matrix

| Feature | [MLX](MLX.md) | [Anthropic](Anthropic.md) | [OpenAI](OpenAI.md) | [HuggingFace](HuggingFace.md) | [Foundation Models](FoundationModels.md) |
|---------|:---:|:---------:|:------:|:-----------:|:------------------:|
| Text Generation | ✓ | ✓ | ✓ | ✓ | ✓ |
| Streaming | ✓ | ✓ | ✓ | ✓ | ✓ |
| Structured Output | ✓ | ✓ | ✓ | ✓ | ✓ |
| Tool Calling | — | ✓ | ✓ | — | — |
| Vision | ✓* | ✓ | ✓ | — | — |
| Extended Thinking | — | ✓ | — | — | — |
| Embeddings | — | — | ✓ | ✓ | — |
| Transcription | — | — | ✓ | ✓ | — |
| Image Generation | ✓* | — | ✓ | ✓ | — |
| Token Counting | ✓ | — | ✓** | — | — |

*Limited model support
**Estimated counts

### Deployment Characteristics

| Characteristic | MLX | Anthropic | OpenAI | HuggingFace | Foundation Models |
|---------------|:---:|:---------:|:------:|:-----------:|:-----------------:|
| **Deployment** | Local | Cloud | Cloud | Cloud | System |
| **Privacy** | Complete | API-dependent | API-dependent | API-dependent | Complete |
| **Offline** | ✓ | — | — | — | ✓ |
| **Latency** | Consistent | Variable | Variable | Variable | Consistent |
| **Cost** | Free* | Per-token | Per-token | Per-token | Free |
| **Setup** | Download models | API key | API key | API key | None |

*Compute cost only (your hardware)

### Platform Support

| Platform | MLX | Anthropic | OpenAI | HuggingFace | Foundation Models |
|----------|:---:|:---------:|:------:|:-----------:|:-----------------:|
| macOS 14+ | ✓ | ✓ | ✓ | ✓ | ✓* |
| iOS 17+ | ✓ | ✓ | ✓ | ✓ | ✓* |
| visionOS 1+ | ✓ | ✓ | ✓ | ✓ | ✓* |
| Linux | — | ✓ | ✓ | ✓ | — |

*Requires iOS 26+/macOS 26+ for Foundation Models

---

## Choosing a Provider

### Decision Tree

```
Do you need complete privacy?
├── Yes → Do you have Apple Silicon?
│         ├── Yes → MLX (recommended)
│         └── No → Consider privacy-compliant cloud or on-prem solutions
│
└── No → What's your primary use case?
          ├── Advanced reasoning/vision → Anthropic (Claude)
          ├── GPT ecosystem/DALL-E → OpenAI
          ├── Model variety/budget → HuggingFace
          └── iOS 26+ system integration → Foundation Models
```

### Use Case Recommendations

| Use Case | Recommended Provider | Why |
|----------|---------------------|-----|
| **Privacy-sensitive apps** | MLX | Zero network traffic, complete data control |
| **Offline functionality** | MLX or Foundation Models | No internet required |
| **Production chatbots** | Anthropic | Claude excels at conversation |
| **Complex reasoning** | Anthropic | Extended thinking mode |
| **Image + text analysis** | Anthropic or OpenAI | Best vision support |
| **Image generation** | OpenAI (DALL-E) | High-quality images |
| **Embeddings/RAG** | OpenAI or HuggingFace | Dedicated embedding models |
| **Audio transcription** | HuggingFace | Whisper model access |
| **Budget-conscious** | HuggingFace | Competitive pricing |
| **iOS 26+ apps** | Foundation Models | Native integration, zero setup |
| **Consistent latency** | MLX | No network variability |

---

## Provider Guides

### [MLX Provider](MLX.md)

Local inference on Apple Silicon. Zero network traffic, complete privacy.

```swift
let provider = MLXProvider()
let response = try await provider.generate(
    "Hello",
    model: .llama3_2_1B,
    config: .default
)
```

**Best for**: Privacy apps, offline functionality, consistent latency

---

### [Anthropic Provider](Anthropic.md)

Claude models with vision and extended thinking.

```swift
let provider = AnthropicProvider(apiKey: "sk-ant-...")
let response = try await provider.generate(
    "Analyze this problem",
    model: .claudeSonnet45,
    config: .default
)
```

**Best for**: Advanced reasoning, vision tasks, production applications

---

### [OpenAI Provider](OpenAI.md)

GPT models, DALL-E, and embeddings. Supports OpenRouter, Ollama, and Azure.

```swift
let provider = OpenAIProvider(apiKey: "sk-...")
let response = try await provider.generate(
    "Write a poem",
    model: .gpt4o,
    config: .creative
)
```

**Best for**: GPT ecosystem, image generation, multiple backends

---

### [HuggingFace Provider](HuggingFace.md)

Cloud inference with thousands of models.

```swift
let provider = HuggingFaceProvider() // Uses HF_TOKEN env var
let response = try await provider.generate(
    "Explain quantum computing",
    model: .huggingFace("meta-llama/Llama-3.1-8B-Instruct"),
    config: .default
)
```

**Best for**: Model variety, embeddings, transcription, budget-conscious

---

### [Foundation Models Provider](FoundationModels.md)

System-integrated on-device AI for iOS 26+.

```swift
if #available(iOS 26.0, *) {
    let provider = FoundationModelsProvider()
    let response = try await provider.generate(
        "What can you help with?",
        model: .foundationModels,
        config: .default
    )
}
```

**Best for**: iOS 26+ apps, zero setup, OS-managed inference

---

## Switching Providers

All providers conform to the same protocols, making switching straightforward:

```swift
// Define a provider-agnostic function
func generateResponse<P: TextGenerator>(
    using provider: P,
    prompt: String,
    model: P.ModelID
) async throws -> String {
    try await provider.generate(prompt, model: model, config: .default)
}

// Use with any provider
let mlxProvider = MLXProvider()
let anthropicProvider = AnthropicProvider(apiKey: "...")

let response1 = try await generateResponse(
    using: mlxProvider,
    prompt: "Hello",
    model: .llama3_2_1B
)

let response2 = try await generateResponse(
    using: anthropicProvider,
    prompt: "Hello",
    model: .claudeSonnet45
)
```

### Provider Abstraction Pattern

For apps supporting multiple providers:

```swift
enum AppProvider {
    case local
    case cloud

    func createProvider() -> any TextGenerator {
        switch self {
        case .local:
            return MLXProvider()
        case .cloud:
            return AnthropicProvider(apiKey: Config.anthropicKey)
        }
    }
}
```

---

## Next Steps

- Choose a provider and read its detailed guide
- [Getting Started](../GettingStarted.md) - First generation walkthrough
- [Streaming](../Streaming.md) - Real-time responses
- [Structured Output](../StructuredOutput.md) - Type-safe responses
