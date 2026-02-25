# LlamaProvider

Run GGUF models locally via llama.cpp for cross-platform on-device inference.

## Overview

`LlamaProvider` is an actor for local inference using llama.cpp through the LlamaSwift binding. It runs GGUF-format models with configurable GPU offloading, sampling parameters, and memory management.

**Requires:** `Llama` trait (`#if Llama && canImport(LlamaSwift)`)

## Setup

Enable the Llama trait in your package:

```swift
.package(url: "https://github.com/christopherkarani/Conduit", from: "0.3.0", traits: ["Llama"])
```

```swift
import Conduit

let provider = LlamaProvider()
let response = try await provider.generate(
    "Hello from llama.cpp!",
    model: .llama("/path/to/model.gguf"),
    config: .default
)
print(response)
```

## Model Identifiers

Llama uses file paths to GGUF models:

```swift
.llama("/path/to/model.gguf")
```

Models must be in GGUF format. Many quantized GGUF models are available on HuggingFace.

## Configuration

```swift
let config = LlamaConfiguration(
    contextSize: 4096,       // Context window size
    batchSize: 512,          // Batch size for prompt processing
    threadCount: 8,          // CPU threads
    gpuLayers: 35,           // Layers to offload to GPU
    useMemoryMapping: true,  // Memory-map model file
    defaultMaxTokens: 512    // Default max generation tokens
)

let provider = LlamaProvider(configuration: config)
```

### Configuration Presets

| Preset | Description |
|--------|-------------|
| `.default` | Balanced settings, auto thread count |
| `.lowMemory` | Reduced context and batch sizes |
| `.cpuOnly` | No GPU offloading |

### GPU Layer Offloading

Move model layers to the GPU for faster inference:

```swift
let config = LlamaConfiguration(gpuLayers: 35)  // Offload 35 layers
```

Set to `0` for CPU-only inference, or a high number to offload as many layers as GPU memory allows.

### Mirostat Sampling

Enable Mirostat for more consistent output quality:

```swift
let config = LlamaConfiguration(
    mirostat: .v2(tau: 5.0, eta: 0.1)  // Mirostat v2
)
```

| Mode | Description |
|------|-------------|
| `.v1(tau:eta:)` | Mirostat v1 sampling |
| `.v2(tau:eta:)` | Mirostat v2 sampling (recommended) |

## Streaming

```swift
for try await text in provider.stream(
    "Explain GGUF format",
    model: .llama("/path/to/model.gguf")
) {
    print(text, terminator: "")
}
```

## Memory Management

```swift
let config = LlamaConfiguration(
    useMemoryMapping: true,   // Efficient file access
    lockMemory: false,        // Don't pin memory
    contextSize: 2048         // Smaller context for less memory
)
```
