# OpenAI Provider

Cloud-based inference supporting OpenAI, OpenRouter, Ollama, and Azure backends. Access GPT models, DALL-E, and embeddings.

## Table of Contents

- [Overview](#overview)
- [Setup](#setup)
- [Endpoints](#endpoints)
- [Available Models](#available-models)
- [Quick Start](#quick-start)
- [Image Generation](#image-generation)
- [Embeddings](#embeddings)
- [Using Ollama](#using-ollama)
- [Using OpenRouter](#using-openrouter)
- [Using Azure](#using-azure)
- [Configuration](#configuration)
- [Error Handling](#error-handling)

---

## Overview

The OpenAI provider offers a unified interface for multiple OpenAI-compatible backends:

- **OpenAI**: GPT-4o, GPT-4, DALL-E, embeddings
- **OpenRouter**: Access multiple providers through one API
- **Ollama**: Local inference via OpenAI-compatible API
- **Azure OpenAI**: Enterprise Azure deployments
- **Custom**: Any OpenAI-compatible endpoint

---

## Setup

### OpenAI API Key

1. Sign up at [platform.openai.com](https://platform.openai.com/)
2. Navigate to API Keys
3. Create a new key

**Environment Variable (Recommended)**

```bash
export OPENAI_API_KEY=sk-...
```

**Direct in Code**

```swift
let provider = OpenAIProvider(apiKey: "sk-...")
```

---

## Endpoints

### OpenAI (Default)

```swift
let provider = OpenAIProvider(apiKey: "sk-...")
// Uses https://api.openai.com/v1
```

### OpenRouter

```swift
let provider = OpenAIProvider(
    endpoint: .openRouter,
    apiKey: "sk-or-..."
)
```

### Ollama (Local)

```swift
let provider = OpenAIProvider(
    endpoint: .ollama(),  // http://localhost:11434/v1
    apiKey: nil
)

// Custom Ollama host
let provider = OpenAIProvider(
    endpoint: .ollama(host: "http://192.168.1.100:11434/v1"),
    apiKey: nil
)
```

### Azure OpenAI

```swift
let provider = OpenAIProvider(
    endpoint: .azure(
        resource: "your-resource",
        deployment: "your-deployment",
        apiVersion: "2024-02-01"
    ),
    apiKey: "your-azure-key"
)
```

### Custom Endpoint

```swift
let provider = OpenAIProvider(
    endpoint: .custom(URL(string: "https://your-api.com/v1")!),
    apiKey: "your-key"
)
```

---

## Available Models

### OpenAI Models

| Model | ID | Best For |
|-------|-----|----------|
| **GPT-4o** | `.gpt4o` | Multimodal flagship |
| **GPT-4o Mini** | `.gpt4oMini` | Fast, affordable |
| **GPT-4 Turbo** | `.gpt4Turbo` | Previous flagship |
| **o1** | `.o1` | Advanced reasoning |
| **o1-mini** | `.o1Mini` | Reasoning (smaller) |

### Embedding Models

| Model | Dimensions | Use Case |
|-------|------------|----------|
| `text-embedding-3-small` | 1536 | General purpose |
| `text-embedding-3-large` | 3072 | Higher quality |
| `text-embedding-ada-002` | 1536 | Legacy support |

### Image Models

| Model | Description |
|-------|-------------|
| `dall-e-3` | Highest quality |
| `dall-e-2` | Faster, lower cost |

### Ollama Models

```swift
.ollama("llama3.2")
.ollama("mistral")
.ollama("codellama")
.ollama("phi3")
```

### OpenRouter Models

```swift
.openRouter("anthropic/claude-3-opus")
.openRouter("google/gemini-pro")
.openRouter("meta-llama/llama-3.1-70b-instruct")
```

---

## Quick Start

```swift
import Conduit

let provider = OpenAIProvider(apiKey: "sk-...")

// Simple generation
let response = try await provider.generate(
    "Explain machine learning",
    model: .gpt4o,
    config: .default
)
print(response)

// Streaming
for try await text in provider.stream(
    "Write a poem about coding",
    model: .gpt4oMini,
    config: .creative
) {
    print(text, terminator: "")
}
```

---

## Image Generation

Generate images with DALL-E:

### Basic Generation

```swift
let provider = OpenAIProvider(apiKey: "sk-...")

let result = try await provider.generateImage(
    prompt: "A serene mountain landscape at sunset",
    config: .default
)

// Use in SwiftUI
result.image  // SwiftUI Image

// Save to file
try result.save(to: URL.documentsDirectory.appending(path: "image.png"))

// Access raw data
let data = result.data
```

### Configuration Options

```swift
let config = ImageGenerationConfig(
    size: .square1024,      // 1024x1024
    quality: .hd,           // Standard or HD
    style: .vivid           // Vivid or natural
)

let result = try await provider.generateImage(
    prompt: "A futuristic city",
    config: config
)
```

### Size Options

| Size | Dimensions |
|------|------------|
| `.square256` | 256x256 |
| `.square512` | 512x512 |
| `.square1024` | 1024x1024 |
| `.landscape1792x1024` | 1792x1024 |
| `.portrait1024x1792` | 1024x1792 |

---

## Embeddings

Generate vector embeddings for semantic search and RAG:

### Single Text

```swift
let provider = OpenAIProvider(apiKey: "sk-...")

let embedding = try await provider.embed(
    "Conduit makes LLM inference easy",
    model: .openAI("text-embedding-3-small")
)

print("Dimensions: \(embedding.dimensions)")  // 1536
print("Vector: \(embedding.vector.prefix(5))...")
```

### Batch Embeddings

```swift
let texts = [
    "Machine learning",
    "Artificial intelligence",
    "Neural networks"
]

let embeddings = try await provider.embedBatch(texts, model: embeddingModel)

for (text, embedding) in zip(texts, embeddings) {
    print("\(text): \(embedding.dimensions) dimensions")
}
```

### Similarity Search

```swift
let query = try await provider.embed("What is AI?", model: embeddingModel)
let doc = try await provider.embed("AI is artificial intelligence", model: embeddingModel)

let similarity = query.cosineSimilarity(with: doc)
print("Similarity: \(similarity)")  // 0.0 to 1.0
```

---

## Using Ollama

Run local inference with Ollama's OpenAI-compatible API:

### Setup Ollama

```bash
# Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Pull a model
ollama pull llama3.2
ollama pull codellama
```

### Use with Conduit

```swift
let provider = OpenAIProvider(
    endpoint: .ollama(),
    apiKey: nil
)

// Generate
let response = try await provider.generate(
    "Explain quantum computing",
    model: .ollama("llama3.2"),
    config: .default
)

// Stream
for try await text in provider.stream(
    "Write a function to sort an array",
    model: .ollama("codellama")
) {
    print(text, terminator: "")
}
```

### Remote Ollama Server

```swift
let provider = OpenAIProvider(
    endpoint: .ollama(host: "http://server.local:11434/v1"),
    apiKey: nil
)
```

---

## Using OpenRouter

Access multiple providers through OpenRouter:

### Setup

1. Get API key at [openrouter.ai](https://openrouter.ai/)
2. Set environment variable:

```bash
export OPENROUTER_API_KEY=sk-or-...
```

### Usage

```swift
let provider = OpenAIProvider(
    endpoint: .openRouter,
    apiKey: "sk-or-..."
)

// Use Claude via OpenRouter
let response = try await provider.generate(
    "Explain relativity",
    model: .openRouter("anthropic/claude-3-opus"),
    config: .default
)

// Use Gemini via OpenRouter
let response = try await provider.generate(
    "Write code",
    model: .openRouter("google/gemini-pro"),
    config: .code
)
```

### OpenRouter Configuration

```swift
let config = OpenRouterConfig(
    providers: ["anthropic", "google"],  // Preferred providers
    fallback: true  // Enable fallback on failure
)

// Apply to provider configuration
```

---

## Using Azure

For enterprise Azure OpenAI deployments:

### Setup

1. Create Azure OpenAI resource
2. Deploy a model
3. Get API key

### Usage

```swift
let provider = OpenAIProvider(
    endpoint: .azure(
        resource: "my-resource",      // Azure resource name
        deployment: "gpt-4o-deploy",  // Deployment name
        apiVersion: "2024-02-01"
    ),
    apiKey: "azure-api-key"
)

let response = try await provider.generate(
    "Enterprise question",
    model: .azure("gpt-4o-deploy"),
    config: .default
)
```

---

## Configuration

### Basic Configuration

```swift
let config = OpenAIConfiguration(
    endpoint: .openAI,
    timeout: 60,
    maxRetries: 3
)

let provider = OpenAIProvider(configuration: config, apiKey: "sk-...")
```

### Request Options

```swift
let config = GenerateConfig.default
    .temperature(0.7)
    .maxTokens(1000)
    .topP(0.9)
    .frequencyPenalty(0.5)
    .presencePenalty(0.5)
    .stopSequences(["END"])

let response = try await provider.generate(prompt, model: model, config: config)
```

---

## Error Handling

```swift
do {
    let response = try await provider.generate(prompt, model: model)
} catch AIError.authenticationFailed(let message) {
    // Invalid API key
    print("Auth error: \(message)")

} catch AIError.rateLimited(let retryAfter) {
    // Rate limit exceeded
    print("Rate limited, retry after: \(retryAfter ?? 0)s")

} catch AIError.serverError(let statusCode, let message) {
    // API error
    print("Error \(statusCode): \(message)")

} catch AIError.tokenLimitExceeded(let count, let limit) {
    // Input too long
    print("\(count) tokens exceeds \(limit) limit")
}
```

---

## Next Steps

- [Streaming](../Streaming.md) - Real-time token output
- [Structured Output](../StructuredOutput.md) - Type-safe responses
- [Tool Calling](../ToolCalling.md) - Function invocation
- [Embeddings](../Streaming.md) - Vector search patterns
