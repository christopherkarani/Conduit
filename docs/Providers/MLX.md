# MLX Provider

Local LLM inference on Apple Silicon using the MLX framework. Zero network traffic, complete privacy.

## Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Model Selection](#model-selection)
- [Configuration](#configuration)
- [Warmup for Fast Responses](#warmup-for-fast-responses)
- [Cache Management](#cache-management)
- [Memory Optimization](#memory-optimization)
- [Token Counting](#token-counting)
- [Vision Models](#vision-models)
- [Platform Considerations](#platform-considerations)
- [Troubleshooting](#troubleshooting)

---

## Overview

The MLX provider runs LLMs directly on your Apple Silicon device using the [MLX framework](https://github.com/ml-explore/mlx-swift). Key benefits:

- **Complete Privacy**: Your data never leaves the device
- **Offline Capable**: No internet connection required
- **Consistent Latency**: No network variability
- **Cost Effective**: No per-token charges
- **GPU Accelerated**: Uses Metal for fast inference

### Requirements

- **Hardware**: Apple Silicon (M1/M2/M3/M4)
- **OS**: macOS 14+, iOS 17+, visionOS 1+
- **Storage**: 1-15GB per model (varies by model size)

---

## Installation

Enable the MLX trait in your `Package.swift`:

```swift
dependencies: [
    .package(
        url: "https://github.com/christopherkarani/Conduit",
        from: "2.0.0",
        traits: ["MLX"]
    )
]
```

> **Note**: Without the MLX trait, the MLXProvider is not available. This keeps the base package lightweight for cloud-only use cases.

---

## Quick Start

```swift
import Conduit

let provider = MLXProvider()

// Simple generation
let response = try await provider.generate(
    "Explain quantum computing in simple terms",
    model: .llama3_2_1B,
    config: .default
)
print(response)

// Streaming
for try await text in provider.stream("Tell me a story", model: .llama3_2_1B) {
    print(text, terminator: "")
}
```

---

## Model Selection

### Built-in Model Aliases

| Alias | Model | Size | Context | Best For |
|-------|-------|------|---------|----------|
| `.llama3_2_1B` | Llama 3.2 1B Instruct | ~1GB | 8K | Fast responses, simple tasks |
| `.llama3_2_3B` | Llama 3.2 3B Instruct | ~2GB | 8K | Balanced performance |
| `.phi4` | Microsoft Phi-4 | ~8GB | 16K | Reasoning, code |
| `.qwen2_5_3B` | Qwen 2.5 3B Instruct | ~2GB | 32K | Long context |
| `.mistral7B` | Mistral 7B Instruct | ~5GB | 8K | General purpose |

### Using Custom Models

Load any MLX-compatible model from Hugging Face:

```swift
// By HuggingFace path
let model = ModelIdentifier.mlx("mlx-community/Llama-3.2-1B-Instruct-4bit")

let response = try await provider.generate(
    "Hello",
    model: model,
    config: .default
)
```

### Model Discovery

```swift
// Check available models in MLX community
// Browse: https://huggingface.co/mlx-community
```

---

## Configuration

### Configuration Presets

| Preset | Memory | Use Case |
|--------|--------|----------|
| `.default` | Auto | Balanced performance |
| `.m1Optimized` | 6 GB | M1 MacBooks, base iPads |
| `.mProOptimized` | 12 GB | M1/M2/M3 Pro, Max chips |
| `.memoryEfficient` | 4 GB | Constrained devices |
| `.highPerformance` | 16+ GB | M2/M3/M4 Max, Ultra |
| `.lowMemory` | 4 GB | Very constrained devices |
| `.multiModel` | No limit | Multiple models cached |

### Using Presets

```swift
// Default configuration
let provider = MLXProvider()

// Optimized for M1
let provider = MLXProvider(configuration: .m1Optimized)

// High performance
let provider = MLXProvider(configuration: .highPerformance)
```

### Custom Configuration

```swift
let config = MLXConfiguration.default
    .memoryLimit(.gigabytes(8))
    .withQuantizedKVCache(bits: 4)
    .prefillStepSize(512)

let provider = MLXProvider(configuration: config)
```

### Configuration Options

| Option | Description | Default |
|--------|-------------|---------|
| `memoryLimit` | Max memory for models | Auto |
| `quantizedKVCache` | Reduce KV cache memory | Disabled |
| `prefillStepSize` | Tokens per prefill step | 512 |
| `memoryMapping` | Memory-map model files | Enabled |

---

## Warmup for Fast Responses

First generation can be slow (2-4 seconds) due to Metal shader compilation. Warm up models ahead of time:

```swift
let provider = MLXProvider()

// Warm up before user interaction
try await provider.warmUp(model: .llama3_2_1B, maxTokens: 5)

// Now first response is fast (100-300ms)
let response = try await provider.generate("Hello", model: .llama3_2_1B)
```

### Warmup Options

```swift
// Basic warmup
try await provider.warmUp(model: .llama3_2_1B)

// With prefill text (mimics real usage)
try await provider.warmUp(
    model: .llama3_2_1B,
    prefillText: "You are a helpful assistant.",
    maxTokens: 10
)
```

### When to Warm Up

- **App launch**: Background warmup during splash screen
- **Before conversation**: When user opens chat interface
- **Model switch**: After changing to a different model

---

## Cache Management

### Checking Cache Status

```swift
let manager = ModelManager.shared

// Check if model is cached
let isCached = await manager.isCached(.llama3_2_1B)

// List all cached models
let cached = await manager.cachedModels()
for model in cached {
    print("\(model.name): \(model.size.formatted())")
}

// Total cache size
let size = await manager.cacheSize()
print("Cache: \(size.formatted())")
```

### Downloading Models

```swift
// Download with progress
let url = try await manager.download(.llama3_2_1B) { progress in
    print("Progress: \(Int(progress.percentComplete))%")
    print("Speed: \(progress.bytesPerSecond.formatted())")
}
```

### Clearing Cache

```swift
// Remove specific model
try await manager.remove(.llama3_2_1B)

// Clear all cached models
try await manager.clearCache()

// Evict to fit size limit (keeps most recent)
try await manager.evictToFit(maxSize: .gigabytes(10))
```

### Storage Location

Models are stored at: `~/Library/Caches/Conduit/Models/`

---

## Memory Optimization

### Monitor Memory Usage

```swift
let stats = await provider.cacheStats()
print("Models loaded: \(stats.modelCount)")
print("Memory used: \(stats.totalMemory.formatted())")
```

### Evict Models

```swift
// Evict specific model from memory
await provider.evictModel(.llama3_2_1B)

// Clear all loaded models
await provider.clearCache()
```

### Memory Tips

1. **Use smaller models** for constrained devices (1B vs 7B)
2. **Enable quantized KV cache** to reduce memory 2-4x
3. **Evict unused models** when switching between models
4. **Monitor memory** on iOS to avoid termination

```swift
// Memory-efficient configuration
let config = MLXConfiguration.default
    .memoryLimit(.gigabytes(4))
    .withQuantizedKVCache(bits: 4)

let provider = MLXProvider(configuration: config)
```

---

## Token Counting

MLX provides accurate token counts using the model's tokenizer:

```swift
let provider = MLXProvider()

// Count tokens in text
let count = try await provider.countTokens(
    in: "Hello, how are you?",
    for: .llama3_2_1B
)
print("Tokens: \(count.count)")

// Count tokens in messages (includes chat template overhead)
let messages = Messages {
    Message.system("You are helpful.")
    Message.user("What is Swift?")
}

let messageCount = try await provider.countTokens(
    in: messages,
    for: .llama3_2_1B
)
print("Message tokens: \(messageCount.count)")

// Check if fits in context
if messageCount.fitsInContext(size: 4096) {
    // Safe to generate
}
```

### Encode/Decode

```swift
// Get raw token IDs
let tokens = try await provider.encode("Hello world", for: .llama3_2_1B)
// [1, 15043, 3186]

// Decode back to text
let text = try await provider.decode(tokens, for: .llama3_2_1B)
// "Hello world"
```

---

## Vision Models

Some MLX models support image input:

```swift
// Check model capabilities
let caps = try await provider.getModelCapabilities(.pixtral)
if caps.supportsVision {
    // Model supports images
}

// Use with image
let messages = Messages {
    Message.user([
        .text("What's in this image?"),
        .image(base64Data: imageData, mimeType: "image/jpeg")
    ])
}

let response = try await provider.generate(
    messages: messages,
    model: .pixtral,
    config: .default
)
```

### Supported Vision Models

- Pixtral
- LLaVA variants
- Other VLM models in mlx-community

---

## Platform Considerations

### macOS

Full support with maximum performance:

```swift
let provider = MLXProvider(configuration: .highPerformance)
```

### iOS

Works on iPhone/iPad with Apple Silicon:

```swift
// Use memory-efficient config on iOS
#if os(iOS)
let provider = MLXProvider(configuration: .m1Optimized)
#else
let provider = MLXProvider(configuration: .highPerformance)
#endif
```

### iOS Memory Considerations

- iOS may terminate apps using too much memory
- Use smaller models (1B-3B) on iPhone
- Monitor `os_proc_available_memory()` if needed
- Consider streaming to reduce peak memory

### visionOS

Supported for spatial computing apps:

```swift
let provider = MLXProvider()
// Same API as iOS/macOS
```

---

## Troubleshooting

### "Model not found" Error

The model needs to be downloaded first:

```swift
let manager = ModelManager.shared

if await !manager.isCached(.llama3_2_1B) {
    try await manager.download(.llama3_2_1B) { progress in
        print("Downloading: \(Int(progress.percentComplete))%")
    }
}
```

### Slow First Response

Warm up the model before first use:

```swift
try await provider.warmUp(model: .llama3_2_1B, maxTokens: 5)
```

### Out of Memory

- Use a smaller model
- Enable quantized KV cache
- Evict unused models
- Reduce `maxTokens` in config

```swift
let config = MLXConfiguration.lowMemory
    .withQuantizedKVCache(bits: 4)
let provider = MLXProvider(configuration: config)
```

### "Device not supported" Error

MLX requires Apple Silicon. Check before using:

```swift
#if arch(arm64)
let provider = MLXProvider()
#else
// Use cloud provider on Intel Macs
let provider = AnthropicProvider(apiKey: "...")
#endif
```

---

## Next Steps

- [Streaming](../Streaming.md) - Real-time token output
- [Structured Output](../StructuredOutput.md) - Type-safe responses
- [ChatSession](../ChatSession.md) - Managed conversations
- [Model Management](../ModelManagement.md) - Download and cache models
