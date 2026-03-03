# CoreMLProvider

Run compiled Core ML models on-device with Neural Engine acceleration via swift-transformers.

## Overview

`CoreMLProvider` is an actor for on-device inference using compiled `.mlmodelc` Core ML models through the swift-transformers backend. It supports text generation with chat template handling and multiple compute unit configurations.

**Requires:** `CoreML` trait (`#if CONDUIT_TRAIT_COREML`) + `canImport(CoreML)`, `canImport(Tokenizers)`, `canImport(Generation)`, `canImport(Models)`

**Platforms:** macOS 15+, iOS 18+, tvOS 18+, watchOS 11+, visionOS 2+

## Setup

Enable the CoreML trait in your package:

```swift
.package(url: "https://github.com/christopherkarani/Conduit", from: "0.3.0", traits: ["CoreML"])
```

```swift
import Conduit

let provider = CoreMLProvider()
let response = try await provider.generate(
    "Hello",
    model: .coreml("/path/to/model.mlmodelc"),
    config: .default
)
```

## Model Identifiers

CoreML uses file paths as model identifiers:

```swift
.coreml("/path/to/compiled-model.mlmodelc")
```

Models must be compiled Core ML models in `.mlmodelc` format.

## Configuration

```swift
let config = CoreMLConfiguration(
    computeUnits: .cpuAndNeuralEngine,
    defaultMaxTokens: 512,
    promptFormatting: .tokenizerChatTemplate
)

let provider = CoreMLProvider(configuration: config)
```

### Compute Units

| Option | Description |
|--------|-------------|
| `.cpuOnly` | CPU only, most compatible |
| `.cpuAndGPU` | CPU + GPU |
| `.cpuAndNeuralEngine` | CPU + Neural Engine (fastest on supported hardware) |
| `.all` | Use all available compute units |

### Prompt Formatting

| Option | Description |
|--------|-------------|
| `.rolePrefixedText` | Simple role-prefixed format |
| `.tokenizerChatTemplate` | Use the tokenizer's built-in chat template |

### Chat Templates

Provide a custom chat template:

```swift
let config = CoreMLConfiguration(
    promptFormatting: .tokenizerChatTemplate,
    chatTemplate: "<|system|>\n{system}\n<|user|>\n{user}\n<|assistant|>\n"
)
```

### Tool Specification Strategy

For models that support function calling:

| Option | Description |
|--------|-------------|
| `.none` | No tool support |
| `.openAIFunction` | OpenAI function-calling format |

## Streaming

```swift
for try await text in provider.stream(
    "Tell me about Core ML",
    model: .coreml("/path/to/model.mlmodelc")
) {
    print(text, terminator: "")
}
```
