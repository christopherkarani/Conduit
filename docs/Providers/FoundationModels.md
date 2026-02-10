# Foundation Models Provider

System-integrated on-device AI for iOS 26+ and macOS 26+. Zero setup, OS-managed inference.

## Table of Contents

- [Overview](#overview)
- [Requirements](#requirements)
- [Quick Start](#quick-start)
- [Availability Checking](#availability-checking)
- [Configuration](#configuration)
- [Streaming](#streaming)
- [Platform Considerations](#platform-considerations)
- [Limitations](#limitations)

---

## Overview

The Foundation Models provider uses Apple's built-in AI capabilities introduced in iOS 26 and macOS 26. Key benefits:

- **Zero Setup**: No API keys, no model downloads
- **System Managed**: Apple handles model updates and optimization
- **Privacy First**: All inference happens on-device
- **Deep Integration**: Designed for the Apple ecosystem

### How It Works

Foundation Models leverages the on-device AI models that Apple includes with iOS 26+ and macOS 26+. The system manages:

- Model loading and caching
- Memory allocation
- Background optimization
- Model updates via OS updates

---

## Requirements

- **iOS 26.0+** or **macOS 26.0+**
- Compatible Apple device with sufficient capabilities
- No API key or external dependencies

---

## Quick Start

```swift
import Conduit

if #available(iOS 26.0, macOS 26.0, *) {
    let provider = FoundationModelsProvider()

    let response = try await provider.generate(
        "What can you help me with?",
        model: .foundationModels,
        config: .default
    )
    print(response)
}
```

### With Availability Check

```swift
import Conduit

func generateWithFoundationModels(prompt: String) async throws -> String {
    if #available(iOS 26.0, macOS 26.0, *) {
        let provider = FoundationModelsProvider()
        return try await provider.generate(
            prompt,
            model: .foundationModels,
            config: .default
        )
    } else {
        // Fall back to another provider
        let provider = MLXProvider()
        return try await provider.generate(
            prompt,
            model: .llama3_2_1B,
            config: .default
        )
    }
}
```

---

## Availability Checking

### Runtime Check

```swift
if #available(iOS 26.0, macOS 26.0, *) {
    let provider = FoundationModelsProvider()

    if await provider.isAvailable {
        // Foundation Models is available
        let response = try await provider.generate(...)
    } else {
        // Not available on this device
    }
}
```

### Provider Availability Status

```swift
if #available(iOS 26.0, macOS 26.0, *) {
    let provider = FoundationModelsProvider()
    let status = await provider.availabilityStatus

    switch status {
    case .available:
        print("Ready to use")
    case .unavailable(let reason):
        print("Not available: \(reason)")
    case .degraded(let reason):
        print("Limited functionality: \(reason)")
    }
}
```

---

## Configuration

### Basic Configuration

```swift
if #available(iOS 26.0, macOS 26.0, *) {
    let config = FMConfiguration.default

    let provider = FoundationModelsProvider(configuration: config)
}
```

### Configuration Options

```swift
if #available(iOS 26.0, macOS 26.0, *) {
    var config = FMConfiguration.default

    // System prompt
    config.systemInstructions = "You are a helpful assistant."

    // Pre-warm model on init
    config.prewarm = true

    // Max response length
    config.maxResponseLength = 500

    // Temperature (0.0 - 1.0)
    config.defaultTemperature = 0.7

    let provider = FoundationModelsProvider(configuration: config)
}
```

### Configuration Presets

```swift
// Default settings, no prewarming
FMConfiguration.default

// Minimal resources, short responses
FMConfiguration.minimal  // maxLength: 200

// Conversational, prewarm enabled
FMConfiguration.conversational
```

---

## Streaming

Real-time token generation:

```swift
if #available(iOS 26.0, macOS 26.0, *) {
    let provider = FoundationModelsProvider()

    for try await text in provider.stream(
        "Tell me a story",
        model: .foundationModels,
        config: .default
    ) {
        print(text, terminator: "")
    }
}
```

### Streaming with Metadata

```swift
if #available(iOS 26.0, macOS 26.0, *) {
    let provider = FoundationModelsProvider()

    let stream = provider.streamWithMetadata(
        messages: [.user("Explain quantum physics")],
        model: .foundationModels,
        config: .default
    )

    for try await chunk in stream {
        print(chunk.text, terminator: "")

        if let reason = chunk.finishReason {
            print("\n[Finished: \(reason)]")
        }
    }
}
```

---

## Platform Considerations

### iOS

Works on iPhone and iPad with iOS 26+:

```swift
#if os(iOS)
if #available(iOS 26.0, *) {
    let provider = FoundationModelsProvider()
    // Use provider
}
#endif
```

### macOS

Works on Mac with macOS 26+:

```swift
#if os(macOS)
if #available(macOS 26.0, *) {
    let provider = FoundationModelsProvider()
    // Use provider
}
#endif
```

### visionOS

Check availability for visionOS:

```swift
#if os(visionOS)
// Foundation Models availability on visionOS TBD
#endif
```

### Cross-Platform Pattern

```swift
func createProvider() -> any TextGenerator {
    #if os(iOS)
    if #available(iOS 26.0, *) {
        return FoundationModelsProvider()
    }
    #elseif os(macOS)
    if #available(macOS 26.0, *) {
        return FoundationModelsProvider()
    }
    #endif

    // Fallback to MLX
    return MLXProvider()
}
```

---

## Limitations

### Compared to Other Providers

| Feature | Foundation Models | MLX | Cloud |
|---------|:-----------------:|:---:|:-----:|
| Vision | TBD | ✓* | ✓ |
| Tool Calling | TBD | — | ✓ |
| Extended Thinking | — | — | ✓ |
| Embeddings | — | — | ✓ |
| Custom Models | — | ✓ | ✓ |
| Offline | ✓ | ✓ | — |
| Privacy | ✓ | ✓ | — |

### Current Limitations

1. **Model Selection**: Uses Apple's built-in model only
2. **Capabilities**: Limited to text generation
3. **Availability**: Requires iOS 26+ / macOS 26+
4. **Device Support**: Not all devices may support Foundation Models

### When to Use Foundation Models

**Good for:**
- Simple text generation
- iOS 26+ apps needing quick AI integration
- Privacy-focused applications
- Apps where zero setup is important

**Consider alternatives for:**
- Complex reasoning tasks
- Vision/multimodal needs
- Custom model requirements
- Older OS support needed

---

## Error Handling

```swift
if #available(iOS 26.0, macOS 26.0, *) {
    let provider = FoundationModelsProvider()

    do {
        let response = try await provider.generate(
            prompt,
            model: .foundationModels,
            config: config
        )
    } catch AIError.providerUnavailable(let reason) {
        // Foundation Models not available
        print("Not available: \(reason)")

    } catch AIError.generationFailed(let error) {
        // Generation failed
        print("Generation error: \(error)")
    }
}
```

---

## Fallback Pattern

For apps supporting older iOS versions:

```swift
func generateResponse(prompt: String) async throws -> String {
    // Try Foundation Models first (iOS 26+)
    if #available(iOS 26.0, *) {
        let fmProvider = FoundationModelsProvider()
        if await fmProvider.isAvailable {
            return try await fmProvider.generate(
                prompt,
                model: .foundationModels,
                config: .default
            )
        }
    }

    // Fall back to MLX (requires Apple Silicon)
    #if arch(arm64)
    let mlxProvider = MLXProvider()
    return try await mlxProvider.generate(
        prompt,
        model: .llama3_2_1B,
        config: .default
    )
    #endif

    // Final fallback to cloud
    let cloudProvider = AnthropicProvider(apiKey: Config.apiKey)
    return try await cloudProvider.generate(
        prompt,
        model: .claudeHaiku,
        config: .default
    )
}
```

---

## Next Steps

- [Streaming](../Streaming.md) - Real-time responses
- [Structured Output](../StructuredOutput.md) - Type-safe outputs
- [ChatSession](../ChatSession.md) - Conversation management
- [Providers Overview](README.md) - Compare with other providers
