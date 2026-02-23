# FoundationModelsProvider

Use Apple's system-integrated on-device models with zero setup on iOS 26+, macOS 26+, and visionOS 26+.

## Overview

`FoundationModelsProvider` is an actor that wraps Apple's Foundation Models framework. It provides on-device text generation managed entirely by the operating system — no model downloads, no API keys, and no data leaves the device.

**Requires:** iOS 26.0+, macOS 26.0+, or visionOS 26.0+ (`#if canImport(FoundationModels)`)

## Setup

No API keys or downloads required:

```swift
import Conduit

if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
    let provider = FoundationModelsProvider()
    let response = try await provider.generate(
        "What can you help me with?",
        model: .foundationModels,
        config: .default
    )
    print(response)
}
```

## Configuration

```swift
let config = FMConfiguration.default
    .instructions("You are a helpful assistant.")
    .prewarm(true)              // Pre-warm on initialization
    .maxResponseLength(1024)    // Max response tokens
    .temperature(0.7)

let provider = FoundationModelsProvider(configuration: config)
```

### Configuration Presets

| Preset | Description |
|--------|-------------|
| `.default` | Standard settings |
| `.minimal` | Minimal resource usage |
| `.conversational` | Optimized for chat |

## Streaming

```swift
if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
    let provider = FoundationModelsProvider()
    for try await text in provider.stream(
        "Tell me a fun fact",
        model: .foundationModels
    ) {
        print(text, terminator: "")
    }
}
```

## Model Identifier

Foundation Models uses a single model identifier:

```swift
.foundationModels  // The system-managed model
```

The actual model is selected and managed by the OS.

## Limitations

- **No tool calling** — Not supported by the Foundation Models framework
- **No vision** — Image input is not supported
- **No embeddings** — Use OpenAI or HuggingFace providers instead
- **Platform-restricted** — Only available on iOS 26+, macOS 26+, visionOS 26+
- **No model selection** — The OS controls which model is used

## Privacy

All inference runs on-device. No data is sent to external servers. This makes Foundation Models ideal for privacy-sensitive applications.
