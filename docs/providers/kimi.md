# KimiProvider

Access Moonshot's Kimi models with 256K context windows for long-document and coding tasks.

## Overview

`KimiProvider` is an actor that wraps Moonshot's Kimi API. It uses the OpenAI-compatible wrapper pattern, delegating to `OpenAIProvider` internally. All Kimi models support 256K token context windows, making them ideal for long document analysis, code review, and extended conversations.

**Requires:** `Kimi` + `OpenAI` traits (`#if CONDUIT_TRAIT_KIMI && CONDUIT_TRAIT_OPENAI`)

## Setup

```bash
export MOONSHOT_API_KEY=sk-moonshot-...
```

```swift
import Conduit

// Simple setup
let provider = KimiProvider(apiKey: "sk-moonshot-...")

// Or auto-detect from environment
let config = KimiConfiguration.standard(apiKey: nil)
let provider = KimiProvider(configuration: config)
```

Get your API key at [platform.moonshot.cn](https://platform.moonshot.cn/).

## Available Models

| Model | ID | Context | Best For |
|-------|----|---------|----------|
| Kimi K2.5 | `.kimiK2_5` | 256K | Complex reasoning, coding |
| Kimi K2 | `.kimiK2` | 256K | General purpose |

All models support the full 256K token context window.

## Text Generation

```swift
let provider = KimiProvider(apiKey: "sk-moonshot-...")

let response = try await provider.generate(
    "Explain async/await in Swift",
    model: .kimiK2_5,
    config: .default
)
print(response)
```

### Multi-turn Conversations

```swift
let messages = Messages {
    Message.system("You are a Swift programming expert.")
    Message.user("What are the benefits of actors?")
}

let result = try await provider.generate(
    messages: messages,
    model: .kimiK2_5,
    config: .default
)
```

## Streaming

```swift
for try await text in provider.stream(
    "Write a Swift function to parse JSON",
    model: .kimiK2_5,
    config: .default
) {
    print(text, terminator: "")
}
```

## Configuration

```swift
let config = KimiConfiguration.standard(apiKey: "sk-moonshot-...")
    .timeout(180)        // Longer timeout for large contexts
    .maxRetries(5)       // More retries for reliability

let provider = KimiProvider(configuration: config)
```

### Authentication

```swift
// Explicit API key
KimiAuthentication.apiKey("sk-moonshot-...")

// Auto-detect from MOONSHOT_API_KEY environment variable
KimiAuthentication.auto
```

## Trait Requirements

KimiProvider requires both the `Kimi` and `OpenAI` traits because it wraps `OpenAIProvider` internally:

```swift
.package(
    url: "https://github.com/christopherkarani/Conduit",
    from: "0.3.0",
    traits: ["Kimi", "OpenAI"]
)
```
