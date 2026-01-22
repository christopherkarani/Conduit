# Conduit

**Unified Swift 6.2 SDK for local and cloud LLM inference**

[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-F05138.svg?style=flat&logo=swift)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2017+%20|%20macOS%2014+%20|%20visionOS%201+%20|%20Linux-007AFF.svg?style=flat)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg?style=flat)](LICENSE)
[![Version](https://img.shields.io/badge/Version-0.6.0-blue.svg?style=flat)](https://github.com/christopherkarani/Conduit/releases)

Conduit gives you a single Swift-native API that can target Anthropic, OpenRouter, Ollama, MLX, HuggingFace, and Apple’s Foundation Models without rewriting your prompt pipeline. Everything conforms to `TextGenerator`, so switching between highly capable Claude 4.5, GPT-5.2 on OpenRouter, Ollama-hosted Llama3, and local MLX is literally swapping one initializer.

## Provider highlights

| Provider | Why it matters |
| --- | --- |
| **Anthropic Claude 4.5 (Opus)** | Claude Opus 4.5 delivers extended thinking, vision + text inputs, and the most capable reasoning path; just pass `AnthropicModelID.claudeOpus45` to `AnthropicProvider`. |
| **OpenRouter GPT-5.2** | OpenRouter sits on top of 400+ models—route to OpenAI, Anthropic, Google, Mistral, etc. The Conduit helper `OpenAIProvider.forOpenRouter(apiKey:preferring:fallbacks:)` and `OpenAIModelID.openRouter("openai/gpt-5.2-opus")` let you target GPT-5.2 with routing, fallbacks, and latency-based preferences. |
| **Ollama local server** | Connect with `OpenAIProvider(endpoint: .ollama, apiKey: nil)` to talk to the Ollama daemon; models like `.ollamaLlama32` run on any platform without Apple Silicon. |
| **MLX Apple Silicon** | `MLXProvider` runs Llama 3.2 or Phi models entirely on-device, giving deterministic latency, private inference, and instant warm starts.
| **HuggingFace / Foundation Models** | The same interfaces support HuggingFace for embeddings, transcription, and images, and Apple Foundation Models for system-integrated intelligence on iOS 26+/macOS 26+.

## Multi-provider orchestration

Want to gather multiple perspectives with one prompt? This example shows how the same `run` helper works with Anthropic Opus 4.5, OpenRouter GPT-5.2, Ollama, and MLX.

```swift
import Conduit

enum ExampleError: Error {
    case missingAPIKey(String)
}

func requireAPIKey(_ name: String) throws -> String {
    guard let key = ProcessInfo.processInfo.environment[name], !key.isEmpty else {
        throw ExampleError.missingAPIKey(name)
    }
    return key
}

let prompt = "Plan a three-day SwiftUI sprint for a side project with daily goals."

func run<P: TextGenerator>(provider: P, model: P.ModelID) async throws -> String {
    try await provider.generate(prompt, model: model, config: .creative)
}

func gatherPlans() async throws {
    let anthropic = AnthropicProvider(apiKey: try requireAPIKey("ANTHROPIC_API_KEY"))
    let openRouter = OpenAIProvider.forOpenRouter(
        apiKey: try requireAPIKey("OPENROUTER_API_KEY"),
        preferring: [.anthropic, .openai]
    )
    let ollama = OpenAIProvider(endpoint: .ollama, apiKey: nil)
    let mlx = MLXProvider()

    let plans: [(label: String, job: () async throws -> String)] = [
        ("Claude Opus 4.5", { try await run(provider: anthropic, model: .claudeOpus45) }),
        ("OpenRouter GPT-5.2", { try await run(provider: openRouter, model: .openRouter("openai/gpt-5.2-opus")) }),
        ("Ollama Llama3.2", { try await run(provider: ollama, model: .ollamaLlama32) }),
        ("MLX Llama3.2 1B", { try await run(provider: mlx, model: .llama3_2_1b) })
    ]

    for plan in plans {
        let text = try await plan.job()
        print("\(plan.label): \(text)\n")
    }
}
```

Every provider call uses the same `run` helper, so you can part-hybrid your stack (a private MLX answer plus a Claude-derived reasoning path) without copying prompts.

## Ready in minutes

Want a single line of code that just works? Conduit keeps it simple:

```swift
import Conduit

let provider = MLXProvider()
let quickWins = try await provider.generate(
    "Explain how `async let` differs from `Task` in Swift.",
    model: .llama3_2_1b
)
print(quickWins)
```

Enable the `MLX` trait in `Package.swift` when targeting Apple Silicon, or switch to `AnthropicProvider`, `OpenAIProvider`, or `HuggingFaceProvider` for cloud-ready inference.

## Installation

Add Conduit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/christopherkarani/Conduit", from: "2.0.0")
]
```

For MLX-enabled builds on Apple Silicon, opt into the `MLX` trait:

```swift
dependencies: [
    .package(url: "https://github.com/christopherkarani/Conduit", from: "2.0.0", traits: ["MLX"])
]
```

Then add `"Conduit"` to your target dependencies.

## Testing

Documentation-driven examples are covered by `Tests/ConduitTests/DocumentationExamplesTests.swift`. Run
the tests that keep the README code working:

```bash
swift test --filter DocumentationExamplesTests
```

## Platform support

| Platform | Available Providers |
| --- | --- |
| macOS 14+ | MLX, Anthropic, OpenRouter/OpenAI, HuggingFace, Foundation Models |
| iOS 17+ / visionOS 1+ | MLX, Anthropic, OpenRouter/OpenAI, HuggingFace, Foundation Models |
| Linux | Anthropic, OpenRouter/OpenAI, HuggingFace, Ollama |

MLX runs on Apple Silicon only; Linux builds exclude MLX by default. Most cloud providers require network connectivity whereas MLX and Ollama (local server mode) work offline.

## Design notes

- **Protocol-first**: everything conforms to `TextGenerator`, `TranscriptionGenerator`, or `EmbeddingGenerator` so your app code stays provider-agnostic.
- **Explicit model selection**: choose `AnthropicModelID`, `OpenAIModelID`, or `ModelIdentifier` symbols so there is no guesswork about which model is in use.
- **Streaming + structured output**: shared helpers for chunk streaming, structured response macros (`@Generable`), and tool execution keep advanced scenarios consistent across providers.

## License

MIT License — see [LICENSE](LICENSE) for details.
