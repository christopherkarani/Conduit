# HuggingFaceProvider

Access hundreds of models via HuggingFace Inference API for text generation, embeddings, transcription, and image generation.

## Overview

`HuggingFaceProvider` is an actor for cloud inference through the HuggingFace Inference API. It conforms to `TextGenerator`, `EmbeddingGenerator`, and `Transcriber`, giving you access to text generation, vector embeddings, and audio transcription across hundreds of models.

**No trait required** — HuggingFaceProvider is always available.

## Setup

```bash
export HF_TOKEN=hf_...
```

```swift
import Conduit

// Auto-detects HF_TOKEN from environment
let provider = HuggingFaceProvider()

// Or provide token explicitly
let provider = HuggingFaceProvider(token: "hf_...")

// Custom configuration
let config = HFConfiguration.default.timeout(120)
let provider = HuggingFaceProvider(configuration: config)
```

Get your token at [huggingface.co/settings/tokens](https://huggingface.co/settings/tokens).

## Text Generation

```swift
let provider = HuggingFaceProvider()

let response = try await provider.generate(
    "Explain transformers in simple terms",
    model: .huggingFace("meta-llama/Llama-3.1-70B-Instruct"),
    config: .default
)
print(response)
```

### Streaming

```swift
for try await text in provider.stream(
    "Write a poem about machine learning",
    model: .huggingFace("meta-llama/Llama-3.1-8B-Instruct")
) {
    print(text, terminator: "")
}
```

### Model Identifiers

Use any HuggingFace model by repository name:

```swift
.huggingFace("meta-llama/Llama-3.1-70B-Instruct")
.huggingFace("mistralai/Mixtral-8x22B-Instruct-v0.1")
.huggingFace("google/gemma-2-2b-it")
```

Pre-defined constants:

```swift
.llama3_1_70B    // meta-llama/Llama-3.1-70B-Instruct
.llama3_1_8B     // meta-llama/Llama-3.1-8B-Instruct
.mixtral8x22B    // mistralai/Mixtral-8x22B-Instruct
.mistral7B       // mistralai/Mistral-7B-Instruct
```

## Embeddings

Generate vector embeddings for semantic search and similarity:

```swift
let provider = HuggingFaceProvider()

let embedding = try await provider.embed(
    "Conduit makes LLM inference easy",
    model: .huggingFace("sentence-transformers/all-MiniLM-L6-v2")
)

print("Dimensions: \(embedding.dimensions)")
print("Vector: \(embedding.vector)")

// Batch embeddings
let embeddings = try await provider.embedBatch(
    ["First sentence", "Second sentence", "Third sentence"],
    model: .huggingFace("sentence-transformers/all-MiniLM-L6-v2")
)
```

### Similarity Comparison

```swift
let a = try await provider.embed("Swift programming", model: .huggingFace("sentence-transformers/all-MiniLM-L6-v2"))
let b = try await provider.embed("iOS development", model: .huggingFace("sentence-transformers/all-MiniLM-L6-v2"))
let similarity = a.cosineSimilarity(with: b)
print("Similarity: \(similarity)")  // 0.0...1.0
```

## Transcription

Transcribe audio using Whisper models:

```swift
let provider = HuggingFaceProvider()

let result = try await provider.transcribe(
    audioURL: audioFileURL,
    model: .huggingFace("openai/whisper-large-v3"),
    config: .detailed
)

print(result.text)
for segment in result.segments {
    print("\(segment.startTime)s: \(segment.text)")
}
```

## Image Generation

Generate images from text prompts:

```swift
let provider = HuggingFaceProvider()

let result = try await provider.textToImage(
    "A cat wearing a top hat, digital art",
    model: .huggingFace("stabilityai/stable-diffusion-3")
)

// Use in SwiftUI
result.image

// Save to file
try result.save(to: URL.documentsDirectory.appending(path: "cat.png"))
```

## Configuration

```swift
let config = HFConfiguration.default
    .token("hf_...")        // API token
    .timeout(120)           // Request timeout
    .maxRetries(3)          // Retry on transient failures
    .retryBaseDelay(1.0)    // Base delay between retries

let provider = HuggingFaceProvider(configuration: config)
```

### Token Resolution

The `HFTokenProvider` checks these sources in order:

1. Explicitly provided token
2. `HF_TOKEN` environment variable
3. `HUGGING_FACE_HUB_TOKEN` environment variable
