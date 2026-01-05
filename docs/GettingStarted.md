# Getting Started with Conduit

This guide will help you install Conduit and generate your first LLM response in minutes.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Your First Generation](#your-first-generation)
- [Streaming Responses](#streaming-responses)
- [Multi-turn Conversations](#multi-turn-conversations)
- [Next Steps](#next-steps)

---

## Prerequisites

Before you begin, ensure you have:

- **Swift 6.2+** (comes with Xcode 16.0+)
- **macOS 14+**, **iOS 17+**, or **visionOS 1+**
- For local inference: **Apple Silicon** (M1/M2/M3/M4)
- For cloud providers: API keys (see individual provider guides)

---

## Installation

### Swift Package Manager

Add Conduit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/christopherkarani/Conduit", from: "2.0.0")
]
```

Then add `"Conduit"` to your target's dependencies:

```swift
.target(
    name: "MyApp",
    dependencies: ["Conduit"]
)
```

### Enabling MLX (Local Inference)

To use on-device inference with MLX, enable the trait:

```swift
dependencies: [
    .package(
        url: "https://github.com/christopherkarani/Conduit",
        from: "2.0.0",
        traits: ["MLX"]
    )
]
```

> **Note**: MLX requires Apple Silicon with Metal GPU. Without the trait, only cloud providers are available.

### Xcode Project

1. Open your project in Xcode
2. Go to **File → Add Package Dependencies**
3. Enter the repository URL: `https://github.com/christopherkarani/Conduit`
4. Select version `2.0.0` or later
5. Click **Add Package**

---

## Your First Generation

### Option 1: Local Inference (MLX)

Zero network traffic, complete privacy:

```swift
import Conduit

// Create provider
let provider = MLXProvider()

// Generate response
let response = try await provider.generate(
    "Explain quantum computing in simple terms",
    model: .llama3_2_1B,
    config: .default
)

print(response)
```

> **First run**: The model will be downloaded (~1-2GB). Subsequent runs use the cached model.

### Option 2: Cloud Inference (Anthropic Claude)

```swift
import Conduit

// Set your API key (or use ANTHROPIC_API_KEY environment variable)
let provider = AnthropicProvider(apiKey: "sk-ant-...")

let response = try await provider.generate(
    "Explain quantum computing in simple terms",
    model: .claudeSonnet45,
    config: .default
)

print(response)
```

Get your API key at: https://console.anthropic.com/

### Option 3: Cloud Inference (HuggingFace)

```bash
# Set your HuggingFace token
export HF_TOKEN=hf_your_token_here
```

```swift
import Conduit

// Auto-detects HF_TOKEN from environment
let provider = HuggingFaceProvider()

let response = try await provider.generate(
    "Explain quantum computing in simple terms",
    model: .huggingFace("meta-llama/Llama-3.1-8B-Instruct"),
    config: .default
)

print(response)
```

Get your token at: https://huggingface.co/settings/tokens

---

## Streaming Responses

Real-time token streaming provides better UX for long responses:

```swift
let provider = MLXProvider()

print("Response: ", terminator: "")

for try await text in provider.stream(
    "Write a short poem about Swift programming",
    model: .llama3_2_1B,
    config: .default
) {
    print(text, terminator: "")
}

print() // New line at end
```

### Streaming with Metadata

Track generation performance:

```swift
let stream = provider.streamWithMetadata(
    messages: [.user("Tell me a joke")],
    model: .llama3_2_1B,
    config: .default
)

for try await chunk in stream {
    print(chunk.text, terminator: "")

    // Performance metrics
    if let tokensPerSecond = chunk.tokensPerSecond {
        // Typical: 30-100 tok/s on Apple Silicon
    }

    // Check for completion
    if let reason = chunk.finishReason {
        print("\n[Finished: \(reason)]")
    }
}
```

---

## Multi-turn Conversations

Build conversations with the `Messages` result builder:

```swift
let provider = AnthropicProvider(apiKey: "sk-ant-...")

let messages = Messages {
    Message.system("You are a helpful Swift programming tutor.")
    Message.user("What is a protocol in Swift?")
}

let result = try await provider.generate(
    messages: messages,
    model: .claudeSonnet45,
    config: .default
)

print(result.text)
print("Tokens used: \(result.usage?.totalTokens ?? 0)")
```

### Continuing the Conversation

```swift
var conversation = Messages {
    Message.system("You are a helpful Swift tutor.")
    Message.user("What is a protocol?")
}

// First response
let response1 = try await provider.generate(
    messages: conversation,
    model: .claudeSonnet45,
    config: .default
)

// Add assistant response and follow-up
conversation.append(Message.assistant(response1.text))
conversation.append(Message.user("Can you give me an example?"))

// Continue conversation
let response2 = try await provider.generate(
    messages: conversation,
    model: .claudeSonnet45,
    config: .default
)
```

### Using ChatSession (Recommended)

For managed conversations, use `ChatSession`:

```swift
let session = try await ChatSession(
    provider: MLXProvider(),
    model: .llama3_2_1B,
    systemPrompt: "You are a helpful coding assistant.",
    warmup: .eager  // Fast first response
)

// History is managed automatically
let response1 = try await session.send("What is a protocol?")
let response2 = try await session.send("Can you give me an example?")

// Access full history
let history = await session.messages
```

[Learn more about ChatSession →](ChatSession.md)

---

## Generation Configuration

Control response behavior with presets or custom settings:

### Using Presets

```swift
// Balanced (default)
.default      // temperature: 0.7, topP: 0.9

// Creative writing
.creative     // temperature: 1.0, topP: 0.95

// Factual/deterministic
.precise      // temperature: 0.3, topP: 0.8

// Code generation
.code         // temperature: 0.2, topP: 0.9
```

### Custom Configuration

```swift
let config = GenerateConfig.default
    .temperature(0.8)
    .maxTokens(500)
    .stopSequences(["END", "---"])

let response = try await provider.generate(
    "Write a story",
    model: .llama3_2_1B,
    config: config
)
```

---

## Next Steps

Now that you've generated your first response, explore these topics:

| Topic | Description |
|-------|-------------|
| [Providers](Providers/README.md) | Choose the right provider for your needs |
| [Structured Output](StructuredOutput.md) | Generate type-safe responses |
| [Tool Calling](ToolCalling.md) | Let LLMs invoke your functions |
| [Streaming](Streaming.md) | Advanced streaming patterns |
| [Error Handling](ErrorHandling.md) | Handle errors gracefully |

---

## Common Issues

### "Model not found" Error

For MLX, ensure the model is downloaded:

```swift
let manager = ModelManager.shared

if await !manager.isCached(.llama3_2_1B) {
    try await manager.download(.llama3_2_1B) { progress in
        print("Downloading: \(Int(progress.percentComplete))%")
    }
}
```

### Slow First Response (MLX)

Warm up the model before first generation:

```swift
let provider = MLXProvider()
try await provider.warmUp(model: .llama3_2_1B, maxTokens: 5)
// Now first response is fast
```

### API Key Not Found

For cloud providers, ensure your API key is set:

```bash
# Anthropic
export ANTHROPIC_API_KEY=sk-ant-...

# HuggingFace
export HF_TOKEN=hf_...

# OpenAI
export OPENAI_API_KEY=sk-...
```

---

## Getting Help

- [GitHub Discussions](https://github.com/christopherkarani/Conduit/discussions) - Ask questions
- [GitHub Issues](https://github.com/christopherkarani/Conduit/issues) - Report bugs
- [API Reference](../README.md) - Inline documentation in source files
