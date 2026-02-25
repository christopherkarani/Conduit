# MiniMaxProvider

Access MiniMax models through an OpenAI-compatible interface.

## Overview

`MiniMaxProvider` is an actor that wraps MiniMax's API. Like `KimiProvider`, it uses the OpenAI-compatible wrapper pattern, delegating to `OpenAIProvider` internally with MiniMax's base URL and model identifiers.

**Requires:** `MiniMax` + `OpenAI` traits (`#if CONDUIT_TRAIT_MINIMAX && CONDUIT_TRAIT_OPENAI`)

## Setup

```bash
export MINIMAX_API_KEY=...
```

```swift
import Conduit

let provider = MiniMaxProvider(apiKey: "...")

// Or auto-detect from environment
let config = MiniMaxConfiguration.standard(apiKey: nil)
let provider = MiniMaxProvider(configuration: config)
```

## Available Models

| Model | ID |
|-------|----|
| MiniMax Abacus | `.miniMaxAbacus` |

## Text Generation

```swift
let provider = MiniMaxProvider(apiKey: "...")

let response = try await provider.generate(
    "Explain machine learning",
    model: .miniMaxAbacus,
    config: .default
)
print(response)
```

## Streaming

```swift
for try await text in provider.stream(
    "Write a story about AI",
    model: .miniMaxAbacus,
    config: .default
) {
    print(text, terminator: "")
}
```

## Configuration

```swift
let config = MiniMaxConfiguration.standard(apiKey: "...")
    .timeout(120)
    .maxRetries(3)

let provider = MiniMaxProvider(configuration: config)
```

### Authentication

```swift
// Explicit API key
MiniMaxAuthentication.apiKey("...")

// Auto-detect from MINIMAX_API_KEY environment variable
MiniMaxAuthentication.auto
```

## Trait Requirements

MiniMaxProvider requires both the `MiniMax` and `OpenAI` traits:

```swift
.package(
    url: "https://github.com/christopherkarani/Conduit",
    from: "0.3.0",
    traits: ["MiniMax", "OpenAI"]
)
```
