# OpenAIProvider

Access OpenAI, OpenRouter, Ollama, Azure, and any OpenAI-compatible endpoint through a unified provider.

## Overview

`OpenAIProvider` is a multi-backend actor that speaks the OpenAI chat completions protocol. It supports five endpoints: OpenAI's official API, OpenRouter's model aggregator, local Ollama servers, Azure OpenAI, and any custom endpoint. It conforms to `TextGenerator`, `EmbeddingGenerator`, `TokenCounter`, and `ImageGenerator`.

**Requires:** `OpenAI` and/or `OpenRouter` trait (`#if CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER`)

## OpenAI (Official API)

```bash
export OPENAI_API_KEY=sk-...
```

```swift
import Conduit

let provider = OpenAIProvider(apiKey: "sk-...")
let response = try await provider.generate("Hello", model: .gpt4o)
```

### Available Models

| Model | ID | Best For |
|-------|----|----|
| GPT-4o | `.gpt4o` | Latest multimodal flagship |
| GPT-4o Mini | `.gpt4oMini` | Fast, cost-effective |
| GPT-4 Turbo | `.gpt4Turbo` | Vision + function calling |
| GPT-3.5 Turbo | `.gpt35Turbo` | Legacy, lowest cost |
| o1 | `.o1` | Complex reasoning |
| o1 Mini | `.o1Mini` | Fast reasoning |
| o3 Mini | `.o3Mini` | Latest mini reasoning |

### Streaming

```swift
for try await text in provider.stream("Tell me a story", model: .gpt4oMini) {
    print(text, terminator: "")
}
```

## OpenRouter

Access 200+ models from OpenAI, Anthropic, Google, Meta, and more through a single API.

```bash
export OPENROUTER_API_KEY=sk-or-...
```

```swift
let provider = OpenAIProvider(endpoint: .openRouter, apiKey: "sk-or-...")
let response = try await provider.generate(
    "Explain quantum computing",
    model: .openRouter("anthropic/claude-3-opus")
)
```

### Routing Configuration

```swift
let config = OpenAIConfiguration.openRouter(apiKey: "sk-or-...")
    .preferring(.anthropic, .openai)  // Provider preferences
    .routeByLatency()                 // Route to fastest

let provider = OpenAIProvider(configuration: config)
```

Full control with `OpenRouterRoutingConfig`:

```swift
let routing = OpenRouterRoutingConfig(
    providers: [.anthropic, .openai],
    fallbacks: true,
    routeByLatency: true,
    dataCollection: .deny
)
let config = OpenAIConfiguration.openRouter(apiKey: "sk-or-...")
    .routing(routing)
```

### Popular OpenRouter Models

```swift
.openRouter("anthropic/claude-3-opus")
.openRouter("google/gemini-pro-1.5")
.openRouter("meta-llama/llama-3.1-70b-instruct")
.openRouter("mistralai/mixtral-8x7b-instruct")

// Convenience aliases
.claudeOpus
.claudeSonnet
.geminiPro15
.llama31B70B
```

Get your API key at [openrouter.ai/keys](https://openrouter.ai/keys).

## Ollama (Local Inference)

Run LLMs locally with no API key required:

```bash
# Install Ollama
curl -fsSL https://ollama.com/install.sh | sh
ollama pull llama3.2
```

```swift
// Default localhost:11434
let provider = OpenAIProvider(endpoint: .ollama())
let response = try await provider.generate(
    "Hello from local inference!",
    model: .ollama("llama3.2")
)
```

### Ollama Configuration

```swift
let config = OpenAIConfiguration(
    endpoint: .ollama(),
    authentication: .none,
    ollamaConfig: OllamaConfiguration(
        keepAlive: "30m",
        pullOnMissing: true,
        numGPU: 35
    )
)
let provider = OpenAIProvider(configuration: config)
```

### Ollama Presets

| Preset | Description |
|--------|-------------|
| `.default` | Standard settings |
| `.lowMemory` | Constrained systems |
| `.interactive` | Longer keep-alive for chat |
| `.batch` | Unload immediately after use |
| `.alwaysOn` | Keep model loaded indefinitely |

### Popular Ollama Models

```swift
.ollamaLlama32       // Llama 3.2
.ollamaMistral       // Mistral 7B
.ollamaCodeLlama     // CodeLlama 7B
.ollamaPhi3          // Phi-3
.ollamaGemma2        // Gemma 2
.ollamaQwen25        // Qwen 2.5
.ollamaDeepseekCoder // DeepSeek Coder

// Any model by name
.ollama("llama3.2:3b")
```

Custom host and port:

```swift
let provider = OpenAIProvider(endpoint: .ollama(host: "192.168.1.100", port: 11434))
```

## Azure OpenAI

Enterprise-grade OpenAI via Microsoft Azure:

```swift
let provider = OpenAIProvider(
    endpoint: .azure(
        resource: "my-resource",
        deployment: "gpt-4",
        apiVersion: "2024-02-15-preview"
    ),
    apiKey: "azure-api-key"
)

let response = try await provider.generate(
    "Hello from Azure",
    model: .azure(deployment: "gpt-4")
)
```

## Custom Endpoints

Any OpenAI-compatible API:

```swift
let provider = OpenAIProvider(
    endpoint: .custom(URL(string: "https://my-proxy.com/v1")!),
    apiKey: "custom-key"
)
```

## Embeddings

```swift
let provider = OpenAIProvider(apiKey: "sk-...")

let embedding = try await provider.embed(
    "Conduit makes LLM inference easy",
    model: .textEmbedding3Small
)
print("Dimensions: \(embedding.dimensions)")
print("Vector: \(embedding.vector)")
```

### Embedding Models

| Model | ID | Dimensions |
|-------|-----|-----------|
| text-embedding-3-small | `.textEmbedding3Small` | 1536 |
| text-embedding-3-large | `.textEmbedding3Large` | 3072 |
| text-embedding-ada-002 | `.textEmbeddingAda002` | 1536 |

## Image Generation (DALL-E)

```swift
let provider = OpenAIProvider(apiKey: "sk-...")

let image = try await provider.textToImage(
    "A cat astronaut on the moon",
    model: .dallE3,
    config: .highQuality.size(.square1024)
)

// Use in SwiftUI
image.image

// Save to file
try image.save(to: URL.documentsDirectory.appending(path: "cat.png"))
```

## Token Counting

Estimated token counts for context window management:

```swift
let count = try await provider.countTokens(
    in: "Hello, how are you?",
    for: .gpt4o
)
print("Tokens: \(count)")
```

## Configuration

`OpenAIConfiguration` supports extensive customization:

```swift
let config = OpenAIConfiguration.openAI(apiKey: "sk-...")
    .timeout(60)
    .maxRetries(3)
    .apiVariant(.chatCompletions)
    .organization("org-...")

let provider = OpenAIProvider(configuration: config)
```

### API Variants

- `.chatCompletions` — Standard chat completions endpoint (default)
- `.responses` — OpenAI Responses API

### Authentication

```swift
.bearer("sk-...")              // Bearer token
.apiKey("key", headerName: "X-API-Key")  // Custom header
.environment("MY_API_KEY")     // From environment variable
.auto                          // Auto-detect from known env vars
.none                          // No auth (Ollama)
```
