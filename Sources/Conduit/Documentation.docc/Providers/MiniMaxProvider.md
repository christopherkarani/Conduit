# MiniMaxProvider

Access MiniMax models through an OpenAI-compatible interface.

## Overview

``MiniMaxProvider`` is an actor that wraps MiniMax's API. Like ``KimiProvider``, it uses the OpenAI-compatible wrapper pattern, delegating to ``OpenAIProvider`` internally with MiniMax's base URL and model identifiers.

**Requires:** `MiniMax` + `OpenAI` traits (`#if CONDUIT_TRAIT_MINIMAX && CONDUIT_TRAIT_OPENAI`)

## Setup

```bash
export MINIMAX_API_KEY=...
```

```swift
import ConduitAdvanced

// Uses MINIMAX_API_KEY from the environment
let provider = MiniMaxProvider()

// Or pass an explicit API key
let explicitProvider = MiniMaxProvider(apiKey: "...")
```

## Available Models

| Model | ID |
|-------|----|
| MiniMax M2.7 | `.minimaxM2_7` |
| MiniMax M2.7 Highspeed | `.minimaxM2_7Highspeed` |
| MiniMax M2.5 | `.minimaxM2_5` |
| MiniMax M2.5 Highspeed | `.minimaxM2_5Highspeed` |
| MiniMax M2.1 | `.minimaxM2_1` |
| MiniMax M2.1 Lightning | `.minimaxM2_1Lightning` |
| MiniMax M2 | `.minimaxM2` |

## Text Generation

```swift
import ConduitAdvanced

let provider = MiniMaxProvider()

let response = try await provider.generate(
    "Explain machine learning",
    model: .minimaxM2_7,
    config: .default
)
print(response)
```

## Streaming

```swift
import ConduitAdvanced

let provider = MiniMaxProvider()

for try await text in provider.stream(
    "Write a story about AI",
    model: .minimaxM2_7,
    config: .default
) {
    print(text, terminator: "")
}
```

## Configuration

```swift
import ConduitAdvanced

let provider = MiniMaxProvider(
    apiKey: "...",
    baseURL: URL(string: "https://api.minimax.io/v1")!,
    timeout: 120,
    maxRetries: 3
)
```

`MiniMaxProvider()` defaults to the official global MiniMax OpenAI-compatible endpoint:

```swift
URL(string: "https://api.minimax.io/v1")!
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

## Topics

### Essentials

- ``MiniMaxProvider``
- ``MiniMaxModelID``
