# HuggingFace Provider

Cloud inference via the HuggingFace Inference API. Access thousands of models for text, embeddings, transcription, and images.

## Table of Contents

- [Overview](#overview)
- [Setup](#setup)
- [Quick Start](#quick-start)
- [Text Generation](#text-generation)
- [Embeddings](#embeddings)
- [Transcription](#transcription)
- [Image Generation](#image-generation)
- [Model Selection](#model-selection)
- [Configuration](#configuration)
- [Error Handling](#error-handling)

---

## Overview

The HuggingFace provider connects to the HuggingFace Inference API, offering:

- **Model Variety**: Thousands of open-source models
- **Text Generation**: Llama, Mistral, Qwen, and more
- **Embeddings**: Sentence transformers for semantic search
- **Transcription**: Whisper models for audio-to-text
- **Image Generation**: Stable Diffusion models
- **No Model Downloads**: Cloud-hosted inference

### Requirements

- HuggingFace account and API token
- Network connectivity

---

## Setup

### Get a Token

1. Sign up at [huggingface.co](https://huggingface.co/)
2. Go to Settings → Access Tokens
3. Create a new token with "Read" permission

### Set Token

**Environment Variable (Recommended)**

```bash
export HF_TOKEN=hf_...
```

**Direct in Code**

```swift
let provider = HuggingFaceProvider(token: "hf_...")
```

---

## Quick Start

```swift
import Conduit

// Auto-detects HF_TOKEN from environment
let provider = HuggingFaceProvider()

// Or with explicit token
let provider = HuggingFaceProvider(token: "hf_...")

// Simple generation
let response = try await provider.generate(
    "Explain machine learning",
    model: .huggingFace("meta-llama/Llama-3.1-8B-Instruct"),
    config: .default
)
print(response)
```

---

## Text Generation

### Basic Generation

```swift
let provider = HuggingFaceProvider()

let response = try await provider.generate(
    "What is Swift programming?",
    model: .huggingFace("meta-llama/Llama-3.1-8B-Instruct"),
    config: .default
)
print(response)
```

### With Messages

```swift
let messages = Messages {
    Message.system("You are a helpful coding assistant.")
    Message.user("Explain protocols in Swift")
}

let result = try await provider.generate(
    messages: messages,
    model: .huggingFace("meta-llama/Llama-3.1-8B-Instruct"),
    config: .default
)
print(result.text)
```

### Streaming

```swift
for try await text in provider.stream(
    "Write a short story",
    model: .huggingFace("meta-llama/Llama-3.1-8B-Instruct"),
    config: .creative
) {
    print(text, terminator: "")
}
```

### Popular Text Models

| Model | Use Case |
|-------|----------|
| `meta-llama/Llama-3.1-8B-Instruct` | General purpose |
| `meta-llama/Llama-3.1-70B-Instruct` | Complex reasoning |
| `mistralai/Mixtral-8x7B-Instruct-v0.1` | Code and reasoning |
| `Qwen/Qwen2.5-7B-Instruct` | Multilingual |
| `microsoft/phi-3-mini-4k-instruct` | Compact, efficient |

---

## Embeddings

Generate vector embeddings for semantic search:

### Single Text

```swift
let provider = HuggingFaceProvider()

let embedding = try await provider.embed(
    "Machine learning is fascinating",
    model: .huggingFace("sentence-transformers/all-MiniLM-L6-v2")
)

print("Dimensions: \(embedding.dimensions)")  // 384
print("Vector: \(embedding.vector.prefix(5))...")
```

### Batch Embeddings

```swift
let texts = [
    "What is machine learning?",
    "How does AI work?",
    "Neural network basics"
]

let embeddings = try await provider.embedBatch(
    texts,
    model: .huggingFace("sentence-transformers/all-MiniLM-L6-v2")
)
```

### Similarity Search

```swift
let query = try await provider.embed("What is AI?", model: embeddingModel)
let doc = try await provider.embed("Artificial intelligence is...", model: embeddingModel)

let similarity = query.cosineSimilarity(with: doc)
print("Similarity: \(similarity)")  // 0.0 to 1.0
```

### Popular Embedding Models

| Model | Dimensions | Use Case |
|-------|------------|----------|
| `sentence-transformers/all-MiniLM-L6-v2` | 384 | Fast, general |
| `sentence-transformers/all-mpnet-base-v2` | 768 | Higher quality |
| `BAAI/bge-small-en-v1.5` | 384 | State-of-the-art |
| `BAAI/bge-large-en-v1.5` | 1024 | Best quality |

---

## Transcription

Convert audio to text using Whisper models:

### Basic Transcription

```swift
let provider = HuggingFaceProvider()

let result = try await provider.transcribe(
    audioURL: audioFileURL,
    model: .huggingFace("openai/whisper-large-v3"),
    config: .default
)

print(result.text)
```

### From Data

```swift
let audioData = try Data(contentsOf: audioURL)

let result = try await provider.transcribe(
    audioData: audioData,
    model: .huggingFace("openai/whisper-large-v3"),
    config: .default
)
```

### With Timestamps

```swift
let result = try await provider.transcribe(
    audioURL: audioURL,
    model: .huggingFace("openai/whisper-large-v3"),
    config: .detailed
)

for segment in result.segments {
    print("\(segment.startTime)s - \(segment.endTime)s: \(segment.text)")
}
```

### Supported Audio Formats

- WAV
- MP3
- M4A
- FLAC
- OGG

### Transcription Models

| Model | Quality | Speed |
|-------|---------|-------|
| `openai/whisper-large-v3` | Best | Slow |
| `openai/whisper-medium` | Good | Medium |
| `openai/whisper-small` | Acceptable | Fast |
| `openai/whisper-tiny` | Basic | Fastest |

---

## Image Generation

Create images with Stable Diffusion:

### Basic Generation

```swift
let provider = HuggingFaceProvider()

let result = try await provider.textToImage(
    "A serene mountain landscape at sunset, digital art",
    model: .huggingFace("stabilityai/stable-diffusion-xl-base-1.0")
)

// SwiftUI Image
result.image

// Save to file
try result.save(to: URL.documentsDirectory.appending(path: "image.png"))
```

### With Configuration

```swift
let result = try await provider.textToImage(
    "A futuristic city with flying cars",
    model: .huggingFace("stabilityai/stable-diffusion-3-medium"),
    config: .highQuality.width(1024).height(768)
)
```

### Negative Prompts

```swift
let result = try await provider.textToImage(
    "A peaceful forest",
    negativePrompt: "people, buildings, cars",
    model: .huggingFace("stabilityai/stable-diffusion-xl-base-1.0"),
    config: .default
)
```

### Image Models

| Model | Quality | Speed |
|-------|---------|-------|
| `stabilityai/stable-diffusion-3-medium` | Best | Slow |
| `stabilityai/stable-diffusion-xl-base-1.0` | Great | Medium |
| `runwayml/stable-diffusion-v1-5` | Good | Fast |

### Configuration Presets

```swift
.default          // Balanced settings
.highQuality      // Maximum quality
.fast             // Speed optimized
.square512        // 512x512
.square1024       // 1024x1024
.landscape        // 1024x768
.portrait         // 768x1024
```

---

## Model Selection

### Model Naming

Models are specified by their HuggingFace path:

```swift
.huggingFace("organization/model-name")

// Examples
.huggingFace("meta-llama/Llama-3.1-8B-Instruct")
.huggingFace("sentence-transformers/all-MiniLM-L6-v2")
.huggingFace("openai/whisper-large-v3")
.huggingFace("stabilityai/stable-diffusion-xl-base-1.0")
```

### Finding Models

1. Browse [huggingface.co/models](https://huggingface.co/models)
2. Filter by task (Text Generation, Text-to-Image, etc.)
3. Sort by downloads or likes
4. Check the "Inference API" badge for compatibility

### Model Availability

Not all HuggingFace models support the Inference API. Look for:

- "Inference API" badge on model page
- "Hosted inference API" section

---

## Configuration

### Provider Configuration

```swift
let config = HFConfiguration.default
    .timeout(120)  // Longer timeout for large models

let provider = HuggingFaceProvider(configuration: config)
```

### Generation Configuration

```swift
let config = GenerateConfig.default
    .temperature(0.7)
    .maxTokens(500)
    .topP(0.9)

let response = try await provider.generate(
    prompt,
    model: model,
    config: config
)
```

### Presets

```swift
// Long-running requests
let config = HFConfiguration.longRunning  // 120s timeout

// Custom endpoint (private deployments)
let config = HFConfiguration.default
    .baseURL(URL(string: "https://your-endpoint.com")!)
```

---

## Error Handling

```swift
do {
    let response = try await provider.generate(prompt, model: model)
} catch AIError.authenticationFailed(let message) {
    // Invalid token
    print("Auth error: \(message)")

} catch AIError.modelNotFound(let model) {
    // Model not available for inference
    print("Model not found: \(model)")

} catch AIError.rateLimited(let retryAfter) {
    // Rate limit exceeded
    print("Rate limited, retry after: \(retryAfter ?? 0)s")

} catch AIError.serverError(let statusCode, let message) {
    // HuggingFace API error
    print("Error \(statusCode): \(message)")

} catch AIError.timeout(let duration) {
    // Request timed out (model loading?)
    print("Timeout after \(duration)s")
}
```

### Model Loading

Some models may need to "warm up" on first request:

```swift
// First request may take longer as model loads
do {
    let response = try await provider.generate(prompt, model: model)
} catch AIError.timeout {
    // Retry - model should be loaded now
    let response = try await provider.generate(prompt, model: model)
}
```

---

## Best Practices

### Model Selection

1. **Start small**: Test with smaller models first
2. **Check availability**: Not all models support inference
3. **Consider latency**: Larger models are slower
4. **Match task to model**: Use specialized models for specific tasks

### Cost Optimization

1. **Use smaller models** when quality is acceptable
2. **Set maxTokens** to limit output length
3. **Batch requests** where possible
4. **Cache embeddings** for repeated queries

### Error Resilience

```swift
// Retry with exponential backoff
var delay = 1.0
for attempt in 1...3 {
    do {
        return try await provider.generate(prompt, model: model)
    } catch AIError.rateLimited, AIError.timeout {
        try await Task.sleep(for: .seconds(delay))
        delay *= 2
    }
}
```

---

## Next Steps

- [Streaming](../Streaming.md) - Real-time responses
- [Structured Output](../StructuredOutput.md) - Type-safe outputs
- [Error Handling](../ErrorHandling.md) - Robust error handling
