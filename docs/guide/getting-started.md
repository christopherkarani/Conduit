# Getting Started

Install Conduit, enable provider traits, and run your first generation.

## Overview

Conduit uses Swift package traits to control which providers are compiled. No traits are enabled by default, keeping the package lightweight and Linux-compatible.

## Installation

Add Conduit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/christopherkarani/Conduit", from: "0.3.0")
]
```

Then add `"Conduit"` to your target's dependencies:

```swift
.target(
    name: "MyApp",
    dependencies: ["Conduit"]
)
```

### Enabling Provider Traits

Enable specific providers with traits:

```swift
// MLX for on-device inference (Apple Silicon only)
.package(url: "https://github.com/christopherkarani/Conduit", from: "0.3.0", traits: ["MLX"])

// Cloud providers
.package(
    url: "https://github.com/christopherkarani/Conduit",
    from: "0.3.0",
    traits: ["Anthropic", "OpenAI", "OpenRouter"]
)

// Multiple providers
.package(
    url: "https://github.com/christopherkarani/Conduit",
    from: "0.3.0",
    traits: ["MLX", "Anthropic", "OpenAI", "HuggingFaceHub"]
)
```

### Trait Reference

| Trait | Compile Flag | Providers Enabled |
|-------|-------------|-------------------|
| `OpenAI` | `CONDUIT_TRAIT_OPENAI` | OpenAIProvider (OpenAI, Ollama, Azure, custom) |
| `OpenRouter` | `CONDUIT_TRAIT_OPENROUTER` | OpenAIProvider (OpenRouter mode) |
| `Anthropic` | `CONDUIT_TRAIT_ANTHROPIC` | AnthropicProvider |
| `Kimi` | `CONDUIT_TRAIT_KIMI` | KimiProvider (requires OpenAI trait too) |
| `MiniMax` | `CONDUIT_TRAIT_MINIMAX` | MiniMaxProvider (requires OpenAI trait too) |
| `MLX` | `CONDUIT_TRAIT_MLX` | MLXProvider (Apple Silicon only) |
| `CoreML` | `CONDUIT_TRAIT_COREML` | CoreMLProvider |
| `HuggingFaceHub` | — | HuggingFace Hub downloads |
| `Llama` | `Llama` | LlamaProvider (llama.cpp via llama.swift) |

## API Keys

Cloud providers need API keys. Set them as environment variables:

```bash
export ANTHROPIC_API_KEY=sk-ant-api-03-...
export OPENAI_API_KEY=sk-...
export OPENROUTER_API_KEY=sk-or-...
export MOONSHOT_API_KEY=sk-moonshot-...
export MINIMAX_API_KEY=...
export HF_TOKEN=hf_...
```

Most providers support `.auto` authentication that resolves keys from the environment automatically.

## Quick Start — Cloud (Anthropic)

```swift
import Conduit

let provider = AnthropicProvider(apiKey: "sk-ant-...")
let response = try await provider.generate(
    "Explain quantum computing in one paragraph",
    model: .claudeSonnet45,
    config: .default.maxTokens(300)
)
print(response)
```

## Quick Start — Local (MLX)

```swift
import Conduit

let provider = MLXProvider()
let response = try await provider.generate(
    "Explain quantum computing in one paragraph",
    model: .llama3_2_1b,
    config: .default.maxTokens(300)
)
print(response)
```

## Quick Start — Streaming

```swift
import Conduit

let provider = AnthropicProvider(apiKey: "sk-ant-...")
for try await text in provider.stream("Tell me a joke", model: .claude35Sonnet) {
    print(text, terminator: "")
}
```

## Building on Linux

Conduit supports Linux for server-side Swift. Build normally with Swift 6.2+:

```bash
swift build
swift test
```

No traits are enabled by default, so MLX and Foundation Models dependencies are excluded. Cloud providers (Anthropic, OpenAI, HuggingFace) work out of the box. For local inference on Linux, use Ollama via `OpenAIProvider`.

## Next Steps

- [Architecture](/guide/architecture) — Understand the protocol hierarchy and design patterns
- [Streaming](/guide/streaming) — Real-time token streaming
- [Structured Output](/guide/structured-output) — Type-safe LLM responses with `@Generable`
- [Providers Overview](/providers/) — Choose the right provider for your use case
