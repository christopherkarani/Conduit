# Anthropic Provider

Cloud-based inference using Anthropic's Claude models. Features advanced reasoning, vision, and extended thinking.

## Table of Contents

- [Overview](#overview)
- [Setup](#setup)
- [Quick Start](#quick-start)
- [Available Models](#available-models)
- [Configuration](#configuration)
- [Vision Support](#vision-support)
- [Extended Thinking](#extended-thinking)
- [Streaming](#streaming)
- [Error Handling](#error-handling)
- [Rate Limiting](#rate-limiting)
- [Best Practices](#best-practices)

---

## Overview

The Anthropic provider connects to Anthropic's Claude API, offering:

- **Claude Models**: Access to the full Claude family
- **Vision**: Analyze images alongside text
- **Extended Thinking**: Deep reasoning for complex problems
- **Streaming**: Real-time token generation
- **Tool Calling**: Function invocation support

### Requirements

- Anthropic API key (get one at [console.anthropic.com](https://console.anthropic.com/))
- Network connectivity

---

## Setup

### Get an API Key

1. Sign up at [console.anthropic.com](https://console.anthropic.com/)
2. Navigate to API Keys
3. Create a new key

### Set API Key

**Option 1: Environment Variable (Recommended)**

```bash
export ANTHROPIC_API_KEY=sk-ant-api03-...
```

**Option 2: Direct in Code**

```swift
let provider = AnthropicProvider(apiKey: "sk-ant-api03-...")
```

> **Security**: Never commit API keys to source control. Use environment variables or a secrets manager.

---

## Quick Start

```swift
import Conduit

// Using environment variable
let provider = AnthropicProvider()

// Or with explicit key
let provider = AnthropicProvider(apiKey: "sk-ant-...")

// Simple generation
let response = try await provider.generate(
    "Explain the theory of relativity",
    model: .claudeSonnet45,
    config: .default
)
print(response)

// With messages
let messages = Messages {
    Message.system("You are a helpful physics tutor.")
    Message.user("Explain quantum entanglement")
}

let result = try await provider.generate(
    messages: messages,
    model: .claudeSonnet45,
    config: .default.maxTokens(1000)
)
print(result.text)
```

---

## Available Models

| Model | ID | Best For | Context |
|-------|-----|----------|---------|
| **Claude Opus 4.5** | `.claudeOpus45` | Most capable, complex reasoning | 200K |
| **Claude Sonnet 4.5** | `.claudeSonnet45` | Balanced performance and cost | 200K |
| **Claude 3.5 Sonnet** | `.claude35Sonnet` | Fast, high-quality responses | 200K |
| **Claude 3.5 Haiku** | `.claude35Haiku` | Fastest, most cost-effective | 200K |
| **Claude 3 Haiku** | `.claude3Haiku` | Budget-friendly, quick tasks | 200K |

### Model Selection Guide

```swift
// Complex reasoning, analysis
let response = try await provider.generate(prompt, model: .claudeOpus45)

// General use, balanced
let response = try await provider.generate(prompt, model: .claudeSonnet45)

// Fast responses, simple tasks
let response = try await provider.generate(prompt, model: .claude3Haiku)

// Best price/performance ratio
let response = try await provider.generate(prompt, model: .claude35Sonnet)
```

---

## Configuration

### Basic Configuration

```swift
let provider = AnthropicProvider(apiKey: "sk-ant-...")

// Generation config
let config = GenerateConfig.default
    .temperature(0.7)
    .maxTokens(1000)
    .topP(0.9)

let response = try await provider.generate(
    "Write a poem",
    model: .claudeSonnet45,
    config: config
)
```

### Advanced Configuration

```swift
var config = AnthropicConfiguration.standard(apiKey: "sk-ant-...")

// Timeout settings
config.timeout = 120  // seconds

// Retry behavior
config.maxRetries = 3

// Extended thinking
config.thinkingConfig = .standard

let provider = AnthropicProvider(configuration: config)
```

---

## Vision Support

Claude can analyze images alongside text:

### Single Image

```swift
// Load image as base64
let imageData = try Data(contentsOf: imageURL)
let base64 = imageData.base64EncodedString()

let messages = Messages {
    Message.user([
        .text("What's in this image?"),
        .image(base64Data: base64, mimeType: "image/jpeg")
    ])
}

let result = try await provider.generate(
    messages: messages,
    model: .claudeSonnet45,
    config: .default
)
print(result.text)
```

### Multiple Images

```swift
let messages = Messages {
    Message.user([
        .text("Compare these two images:"),
        .image(base64Data: image1Base64, mimeType: "image/jpeg"),
        .image(base64Data: image2Base64, mimeType: "image/png")
    ])
}

let result = try await provider.generate(
    messages: messages,
    model: .claudeSonnet45,
    config: .default
)
```

### Supported Formats

- JPEG (`image/jpeg`)
- PNG (`image/png`)
- GIF (`image/gif`)
- WebP (`image/webp`)

### Image Best Practices

- Maximum 5MB per image
- Resize large images before sending
- Use JPEG for photos, PNG for diagrams
- Consider image compression for faster requests

---

## Extended Thinking

Extended thinking enables Claude to reason deeply before responding:

### Enabling Extended Thinking

```swift
var config = AnthropicConfiguration.standard(apiKey: "sk-ant-...")
config.thinkingConfig = .standard  // 1024 token thinking budget

let provider = AnthropicProvider(configuration: config)

let response = try await provider.generate(
    "Solve this complex math problem: ...",
    model: .claudeOpus45,
    config: .default
)

// Access thinking process
if let reasoning = response.reasoningDetails.first {
    print("Thinking: \(reasoning.content)")
}
print("Answer: \(response.text)")
```

### Thinking Budget Options

```swift
// Standard thinking (1024 tokens)
config.thinkingConfig = .standard

// Extended thinking (4096 tokens)
config.thinkingConfig = .extended

// Custom budget
config.thinkingConfig = ThinkingConfig(maxTokens: 2048)
```

### When to Use Extended Thinking

- Complex mathematical problems
- Multi-step reasoning
- Code analysis and debugging
- Strategic planning
- Research synthesis

> **Note**: Extended thinking uses additional tokens and may increase latency.

---

## Streaming

Real-time token streaming:

```swift
let provider = AnthropicProvider(apiKey: "sk-ant-...")

// Basic streaming
for try await text in provider.stream(
    "Write a story about a robot",
    model: .claudeSonnet45,
    config: .default
) {
    print(text, terminator: "")
}

// With metadata
let stream = provider.streamWithMetadata(
    messages: messages,
    model: .claudeSonnet45,
    config: .default
)

for try await chunk in stream {
    print(chunk.text, terminator: "")

    if let tokensPerSecond = chunk.tokensPerSecond {
        // Track performance
    }

    if let reason = chunk.finishReason {
        print("\n[Done: \(reason)]")
    }
}
```

### Collect Streamed Response

```swift
let stream = provider.stream("Write a poem", model: .claudeSonnet45)

// Collect all text
let fullText = try await stream.collect()

// Collect with metrics
let result = try await stream.collectWithMetadata()
print("Tokens: \(result.tokenCount)")
print("Time: \(result.generationTime)s")
```

---

## Error Handling

### Common Errors

```swift
do {
    let response = try await provider.generate(prompt, model: model)
} catch AIError.authenticationFailed(let message) {
    // Invalid or missing API key
    print("Auth error: \(message)")

} catch AIError.rateLimited(let retryAfter) {
    // Rate limit exceeded
    if let seconds = retryAfter {
        print("Rate limited. Retry after \(seconds)s")
    }

} catch AIError.serverError(let statusCode, let message) {
    // Anthropic API error
    print("Server error \(statusCode): \(message)")

} catch AIError.networkError(let error) {
    // Network connectivity issue
    print("Network error: \(error)")

} catch AIError.tokenLimitExceeded(let count, let limit) {
    // Input too long
    print("Input has \(count) tokens, limit is \(limit)")
}
```

### Retry Strategy

The provider automatically retries on transient errors:

```swift
var config = AnthropicConfiguration.standard(apiKey: "sk-ant-...")
config.maxRetries = 3  // Default

let provider = AnthropicProvider(configuration: config)
```

---

## Rate Limiting

Anthropic enforces rate limits based on your plan:

### Handling Rate Limits

```swift
do {
    let response = try await provider.generate(prompt, model: model)
} catch AIError.rateLimited(let retryAfter) {
    if let seconds = retryAfter {
        try await Task.sleep(for: .seconds(seconds))
        // Retry request
    }
}
```

### Rate Limit Headers

```swift
let result = try await provider.generate(prompt, model: model, config: config)

if let rateInfo = result.rateLimitInfo {
    print("Requests remaining: \(rateInfo.requestsRemaining)")
    print("Tokens remaining: \(rateInfo.tokensRemaining)")
    print("Reset at: \(rateInfo.resetAt)")
}
```

### Tips to Avoid Rate Limits

1. **Batch requests** where possible
2. **Implement exponential backoff** for retries
3. **Cache responses** for repeated queries
4. **Use streaming** for long responses (reduces perceived latency)

---

## Best Practices

### System Prompts

```swift
let messages = Messages {
    // Clear, specific system prompt
    Message.system("""
        You are a helpful coding assistant.
        - Provide concise, accurate code examples
        - Use Swift 6.2 conventions
        - Include error handling
        """)

    Message.user("How do I make a network request?")
}
```

### Temperature Selection

| Use Case | Temperature |
|----------|-------------|
| Factual Q&A | 0.0 - 0.3 |
| General conversation | 0.5 - 0.7 |
| Creative writing | 0.8 - 1.0 |
| Brainstorming | 0.9 - 1.0 |

### Token Management

```swift
// Set reasonable limits
let config = GenerateConfig.default
    .maxTokens(1000)  // Prevents runaway responses

// Monitor usage
let result = try await provider.generate(...)
if let usage = result.usage {
    print("Input: \(usage.promptTokens)")
    print("Output: \(usage.completionTokens)")
    print("Total: \(usage.totalTokens)")
}
```

### Cost Optimization

1. **Use appropriate models**: Haiku for simple tasks, Opus for complex reasoning
2. **Set maxTokens**: Prevent unnecessarily long responses
3. **Cache responses**: Don't regenerate identical queries
4. **Use system prompts**: Guide responses to be concise

---

## Next Steps

- [Tool Calling](../ToolCalling.md) - Let Claude invoke your functions
- [Structured Output](../StructuredOutput.md) - Type-safe responses
- [Streaming](../Streaming.md) - Real-time patterns
- [ChatSession](../ChatSession.md) - Managed conversations
