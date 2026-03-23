# ``Conduit``

Unified Swift 6.2 SDK for local and cloud LLM inference.

## Overview

Conduit provides a single protocol-driven API that targets Anthropic, OpenAI, OpenRouter, Ollama, MLX, HuggingFace, Kimi, MiniMax, CoreML, llama.cpp, and Apple Foundation Models. Switching providers means swapping one initializer — prompt pipelines stay the same.

Every provider conforms to ``TextGenerator``, so your app code stays provider-agnostic. Additional protocols — ``EmbeddingGenerator``, ``Transcriber``, ``ImageGenerator``, and ``TokenCounter`` — expose capabilities where available.

All providers are actors with full Swift 6.2 concurrency safety. Types are `Sendable` throughout.

```swift
import Conduit

// Cloud inference
let anthropic = AnthropicProvider(apiKey: "sk-ant-...")
let response = try await anthropic.generate(
    "Explain quantum computing",
    model: .claudeSonnet45,
    config: .default.maxTokens(500)
)

// Local inference — same API shape
let mlx = MLXProvider()
let local = try await mlx.generate(
    "Explain quantum computing",
    model: .llama3_2_1b,
    config: .default.maxTokens(500)
)
```

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:Architecture>

### Generation

- <doc:Streaming>
- <doc:StructuredOutput>
- <doc:ToolCalling>

### Services

- <doc:ChatSession>

### Error Handling

- <doc:ErrorHandling>

### Platform & Integration

- <doc:PlatformSupport>
- <doc:SwiftAgentsIntegration>

### Providers

- <doc:ProvidersOverview>
- <doc:AnthropicProvider>
- <doc:OpenAIProvider>
- <doc:MLXProvider>
- <doc:HuggingFaceProvider>
- <doc:FoundationModelsProvider>
- <doc:KimiProvider>
- <doc:MiniMaxProvider>
- <doc:CoreMLProvider>
- <doc:LlamaProvider>

### Core Protocols

- ``TextGenerator``
- ``EmbeddingGenerator``
- ``Transcriber``
- ``ImageGenerator``
- ``TokenCounter``
- ``AIProvider``

### Core Types

- ``GenerateConfig``
- ``GenerationResult``
- ``GenerationChunk``
- ``Message``
- ``ModelIdentifier``
- ``UsageStats``
- ``FinishReason``

### Structured Output

- ``Generable``
- ``GeneratedContent``
- ``GenerationSchema``

### Tools

- ``Tool``
- ``ToolExecutor``

### Sessions

- ``ChatSession``

### Errors

- ``AIError``
