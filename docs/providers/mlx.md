# MLXProvider

Run models locally on Apple Silicon with zero network traffic and complete privacy.

## Overview

`MLXProvider` is an actor for on-device inference using Apple's MLX framework. It runs quantized models entirely on the Metal GPU, providing consistent latency with no API keys or network required. It conforms to `TextGenerator` and `TokenCounter`.

**Requires:** `MLX` trait (`#if CONDUIT_TRAIT_MLX`), Apple Silicon (M1 or later)

## Setup

No API keys needed. Enable the MLX trait in your package:

```swift
.package(url: "https://github.com/christopherkarani/Conduit", from: "0.3.0", traits: ["MLX"])
```

```swift
import Conduit

let provider = MLXProvider()
let response = try await provider.generate(
    "Explain quantum computing",
    model: .llama3_2_1b,
    config: .default
)
print(response)
```

## Available Models

| Model | ID | Parameters | Use Case |
|-------|----|-----------|----------|
| Llama 3.2 1B | `.llama3_2_1b` | 1B | Fast, lightweight |
| Llama 3.2 3B | `.llama3_2_3b` | 3B | Balanced |
| Phi-4 | `.phi4` | 14B | Reasoning |
| Qwen 2.5 3B | `.qwen2_5_3b` | 3B | Multilingual |
| Mistral 7B | `.mistral7B` | 7B | General purpose |
| Gemma 2 2B | `.gemma2_2b` | 2B | Compact |
| DeepSeek R1 | `.deepseekR1` | — | Code + reasoning |

Any MLX-compatible model from HuggingFace:

```swift
let model = ModelIdentifier.mlx("mlx-community/Mistral-7B-Instruct-v0.3-4bit")
```

Browse [mlx-community on HuggingFace](https://huggingface.co/mlx-community) for 4-bit quantized models.

## Configuration Presets

| Preset | Memory Limit | Use Case |
|--------|-------------|----------|
| `.default` | Auto | Balanced performance |
| `.m1Optimized` | 6 GB | M1 MacBooks, base iPads |
| `.mProOptimized` | 12 GB | M1/M2 Pro, Max chips |
| `.memoryEfficient` | 4 GB | Constrained devices |
| `.highPerformance` | 16+ GB | M2/M3 Max, Ultra |
| `.lowMemory` | — | Minimal footprint |
| `.multiModel` | — | Multiple models loaded |

```swift
// Use a preset
let provider = MLXProvider(configuration: .m1Optimized)

// Or customize
let config = MLXConfiguration.default
    .memoryLimit(.gigabytes(8))
    .withQuantizedKVCache(bits: 4)
    .maxCachedModels(2)

let provider = MLXProvider(configuration: config)
```

## Warmup

Pre-warm Metal shaders for fast first responses:

```swift
let provider = MLXProvider()

// Warm up before first generation
try await provider.warmUp(model: .llama3_2_1b, maxTokens: 5)

// Now first response is fast
let response = try await provider.generate("Hello", model: .llama3_2_1b)
```

## Streaming

```swift
for try await text in provider.stream("Write a haiku", model: .llama3_2_1b) {
    print(text, terminator: "")
}
```

With metadata:

```swift
for try await chunk in provider.streamWithMetadata(
    messages: Messages { Message.user("Tell me a joke") },
    model: .llama3_2_1b,
    config: .default
) {
    print(chunk.text, terminator: "")
    if let speed = chunk.tokensPerSecond {
        print(" [\(String(format: "%.1f", speed)) tok/s]")
    }
}
```

## Token Counting

MLXProvider provides exact token counts (not estimated):

```swift
let count = try await provider.countTokens(in: "Hello world", for: .llama3_2_1b)
print("Tokens: \(count)")

// Encode text to token IDs
let tokens = try await provider.encode("Hello world", for: .llama3_2_1b)
print("Token IDs: \(tokens)")

// Decode token IDs back to text
let text = try await provider.decode(tokens, for: .llama3_2_1b)
print("Decoded: \(text)")
```

## KV Cache Quantization

Reduce memory usage for longer contexts:

```swift
let config = MLXConfiguration.default
    .withQuantizedKVCache(bits: 4)  // 4-bit KV cache quantization

let provider = MLXProvider(configuration: config)
```

## Memory Management

Control memory usage for the model cache:

```swift
let config = MLXConfiguration.default
    .memoryLimit(.gigabytes(8))   // Max GPU memory
    .maxCachedModels(2)            // Keep 2 models in LRU cache
    .maxCacheSize(.gigabytes(12))  // Max total cache size

let provider = MLXProvider(configuration: config)
```

## Model Downloading

Models must be downloaded before first use. See [Model Management](/guide/model-management) for details:

```swift
let manager = ModelManager.shared
let url = try await manager.download(.llama3_2_1b) { progress in
    print("Progress: \(progress.percentComplete)%")
}
```

## Platform Requirements

MLX requires:
- Apple Silicon (M1 or later)
- macOS 14+ / iOS 17+ / visionOS 1+
- Metal GPU

The provider is guarded with `#if CONDUIT_TRAIT_MLX` and `#if arch(arm64)`.
