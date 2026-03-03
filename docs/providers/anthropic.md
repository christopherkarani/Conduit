# AnthropicProvider

Access Anthropic's Claude models for advanced reasoning, vision, and extended thinking.

## Overview

`AnthropicProvider` is an actor that provides access to Anthropic's Claude model family. It supports text generation, streaming, vision (image+text), extended thinking for complex reasoning, and tool calling.

**Requires:** `Anthropic` trait (`#if CONDUIT_TRAIT_ANTHROPIC`)

## Setup

Set your API key as an environment variable or pass it directly:

```bash
export ANTHROPIC_API_KEY=sk-ant-api-03-...
```

```swift
import Conduit

// Auto-detect from environment
let provider = AnthropicProvider(configuration: .standard(apiKey: nil))

// Or provide explicitly
let provider = AnthropicProvider(apiKey: "sk-ant-...")
```

Get your API key at [console.anthropic.com](https://console.anthropic.com/).

## Available Models

| Model | ID | Best For |
|-------|----|----|
| Claude Opus 4.5 | `.claudeOpus45` | Most capable, complex reasoning |
| Claude Sonnet 4.5 | `.claudeSonnet45` | Balanced performance and speed |
| Claude Opus 4 | `.claudeOpus4` | Previous-gen flagship |
| Claude Sonnet 4 | `.claudeSonnet4` | Previous-gen balanced |
| Claude 3.5 Sonnet | `.claude35Sonnet` | Fast, high-quality responses |
| Claude 3.5 Haiku | `.claude35Haiku` | Speed-optimized |
| Claude 3 Opus | `.claude3Opus` | Claude 3 flagship |
| Claude 3 Haiku | `.claude3Haiku` | Fastest, most cost-effective |

## Text Generation

```swift
let provider = AnthropicProvider(apiKey: "sk-ant-...")

let response = try await provider.generate(
    "Explain quantum computing",
    model: .claudeSonnet45,
    config: .default.maxTokens(500)
)
print(response)
```

### Multi-turn Conversations

```swift
let messages = Messages {
    Message.system("You are a Swift expert.")
    Message.user("What are actors?")
}

let result = try await provider.generate(
    messages: messages,
    model: .claudeSonnet45,
    config: .default
)
print(result.text)
print("Tokens used: \(result.usage?.totalTokens ?? 0)")
```

## Streaming

```swift
for try await text in provider.stream(
    "Write a poem about Swift",
    model: .claude3Haiku,
    config: .default
) {
    print(text, terminator: "")
}
```

With metadata:

```swift
for try await chunk in provider.streamWithMetadata(
    messages: messages,
    model: .claudeSonnet45,
    config: .default
) {
    print(chunk.text, terminator: "")
    if let speed = chunk.tokensPerSecond {
        // Track generation speed
    }
}
```

## Vision

Send images alongside text using multimodal messages:

```swift
let messages = Messages {
    Message.user([
        .text("What's in this image?"),
        .image(base64Data: imageData, mimeType: "image/jpeg")
    ])
}

let result = try await provider.generate(
    messages: messages,
    model: .claudeSonnet45,
    config: .default
)
print(result.text)
```

Enable vision in the configuration:

```swift
let config = AnthropicConfiguration.standard(apiKey: "sk-ant-...")
    .vision(true)
let provider = AnthropicProvider(configuration: config)
```

## Extended Thinking

Enable extended thinking for complex reasoning tasks:

```swift
var config = AnthropicConfiguration.standard(apiKey: "sk-ant-...")
config.thinkingConfig = .standard  // enabled with 1024 budget tokens

let provider = AnthropicProvider(configuration: config)
let result = try await provider.generate(
    "Solve this complex problem step by step...",
    model: .claudeOpus45,
    config: .default
)

// Access reasoning details
for detail in result.reasoningDetails {
    print("Thinking: \(detail)")
}
print("Answer: \(result.text)")
```

Custom thinking budget:

```swift
config.thinkingConfig = ThinkingConfiguration(enabled: true, budgetTokens: 4096)
```

## Tool Calling

```swift
@Generable
struct SearchArgs {
    @Guide("Search query")
    let query: String
}

struct SearchTool: Tool {
    let name = "search"
    let description = "Search the web"
    func call(arguments: SearchArgs) async throws -> String {
        return "Results for: \(arguments.query)"
    }
}

let config = GenerateConfig.default
    .tools([SearchTool()])
    .toolChoice(.auto)

let result = try await provider.generate(
    messages: Messages { Message.user("Search for Swift concurrency") },
    model: .claudeSonnet45,
    config: config
)
```

## Configuration

`AnthropicConfiguration` uses a fluent API:

```swift
let config = AnthropicConfiguration.standard(apiKey: "sk-ant-...")
    .timeout(60)                    // Request timeout in seconds
    .maxRetries(3)                  // Retry on transient failures
    .streaming(true)                // Enable streaming (default)
    .vision(true)                   // Enable vision support
    .extendedThinking(.standard)    // Enable extended thinking

let provider = AnthropicProvider(configuration: config)
```

### Authentication

```swift
// Explicit API key
let auth = AnthropicAuthentication.apiKey("sk-ant-...")

// Auto-detect from ANTHROPIC_API_KEY environment variable
let auth = AnthropicAuthentication.auto
```

## Error Handling

```swift
do {
    let result = try await provider.generate("Hello", model: .claudeSonnet45)
} catch AIError.authenticationFailed(let message) {
    print("Check your API key: \(message)")
} catch AIError.rateLimited(let retryAfter) {
    if let delay = retryAfter {
        try await Task.sleep(for: .seconds(delay))
    }
} catch AIError.serverError(let code, let message) {
    print("Server error \(code): \(message ?? "")")
}
```
