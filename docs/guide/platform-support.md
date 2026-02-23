# Platform Support

Understand which providers are available on each platform and how to handle platform differences.

## Overview

Conduit supports macOS, iOS, visionOS, and Linux. Not all providers are available on every platform — local inference requires specific hardware, while cloud providers work everywhere with network access.

## Platform Matrix

| Platform | Status | Available Providers |
|:---------|:------:|:--------------------|
| macOS 14+ | Full | MLX, Anthropic, OpenAI, OpenRouter, Ollama, HuggingFace, Kimi, MiniMax, CoreML, Llama, Foundation Models* |
| iOS 17+ | Full | MLX, Anthropic, OpenAI, OpenRouter, HuggingFace, Kimi, MiniMax, CoreML, Foundation Models* |
| visionOS 1+ | Full | MLX, Anthropic, OpenAI, OpenRouter, HuggingFace, Kimi, MiniMax, CoreML, Foundation Models* |
| Linux | Cloud-only | Anthropic, OpenAI, OpenRouter, Ollama, HuggingFace, Kimi, MiniMax |

*Foundation Models requires iOS 26+, macOS 26+, or visionOS 26+.

## Provider Platform Requirements

### Local Providers

| Provider | Requirements |
|----------|-------------|
| MLXProvider | Apple Silicon (M1+), macOS 14+ / iOS 17+ / visionOS 1+ |
| FoundationModelsProvider | iOS 26+ / macOS 26+ / visionOS 26+ |
| CoreMLProvider | macOS 15+ / iOS 18+ / tvOS 18+ / watchOS 11+ / visionOS 2+ |
| LlamaProvider | Any platform with llama.swift support |
| Ollama (via OpenAIProvider) | Any platform running Ollama server |

### Cloud Providers

All cloud providers work on every platform with network access:

- AnthropicProvider
- OpenAIProvider (OpenAI, OpenRouter, Azure)
- HuggingFaceProvider
- KimiProvider
- MiniMaxProvider

## Linux

Conduit supports Linux for server-side Swift deployments. Build and test with Swift 6.2+:

```bash
swift build
swift test
```

No traits are enabled by default, so MLX and Foundation Models dependencies are excluded automatically.

### Linux Limitations

- **MLX Provider**: Requires Apple Silicon with Metal GPU (not available on Linux)
- **Foundation Models**: Requires Apple platforms (not available on Linux)
- **CoreML Provider**: Requires Apple frameworks (not available on Linux)
- **Image Generation**: `GeneratedImage.image` returns `nil` on Linux (use `data` or `save(to:)`)
- **Keychain**: Token storage falls back to environment variables

### Local Inference on Linux

Use Ollama via `OpenAIProvider` for local inference on Linux:

```bash
# Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Pull a model
ollama pull llama3.2
```

```swift
import Conduit

let provider = OpenAIProvider(endpoint: .ollama(), authentication: .none)
let response = try await provider.generate(
    "Hello from Linux!",
    model: .ollama("llama3.2"),
    config: .default
)
```

## Conditional Compilation

Use trait flags to guard platform-specific code:

```swift
#if CONDUIT_TRAIT_MLX
// MLX is available
let mlx = MLXProvider()
#endif

#if CONDUIT_TRAIT_ANTHROPIC
// Anthropic is available
let anthropic = AnthropicProvider(apiKey: "...")
#endif

#if canImport(FoundationModels)
// Foundation Models is available (iOS 26+, macOS 26+)
if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
    let fm = FoundationModelsProvider()
}
#endif
```

### Writing Cross-Platform Code

Use `TextGenerator` as a generic constraint for fully portable code:

```swift
func generate<P: TextGenerator>(
    with provider: P,
    model: P.ModelID,
    prompt: String
) async throws -> String {
    try await provider.generate(prompt, model: model, config: .default)
}
```

This function works with any provider on any platform.

## Minimum Deployment Targets

| Platform | Minimum Version |
|----------|----------------|
| iOS | 17.0 |
| macOS | 14.0 |
| visionOS | 1.0 |
| Linux | Swift 6.2+ |
