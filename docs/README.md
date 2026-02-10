# Conduit Documentation

Welcome to the Conduit documentation! This guide will help you integrate LLM capabilities into your Swift applications.

## Quick Navigation

| Guide | Description |
|-------|-------------|
| [Getting Started](GettingStarted.md) | Installation, setup, and your first generation |
| [Providers](Providers/README.md) | Detailed guides for each provider |
| [Structured Output](StructuredOutput.md) | Type-safe responses with `@Generable` |
| [Tool Calling](ToolCalling.md) | Define and execute LLM-invokable tools |
| [Streaming](Streaming.md) | Real-time token streaming patterns |
| [ChatSession](ChatSession.md) | Stateful conversation management |
| [Model Management](ModelManagement.md) | Download, cache, and manage models |
| [Error Handling](ErrorHandling.md) | Handle errors gracefully |
| [Architecture](Architecture.md) | Design principles and internals |

---

## Getting Started

New to Conduit? Start here:

1. **[Installation](GettingStarted.md#installation)** - Add Conduit to your project
2. **[Quick Start](GettingStarted.md#your-first-generation)** - Generate your first response
3. **[Choose a Provider](Providers/README.md)** - Pick the right provider for your needs

---

## Providers at a Glance

| Provider | Type | Best For |
|----------|------|----------|
| [MLX](Providers/MLX.md) | Local | Privacy, offline, consistent latency |
| [Anthropic](Providers/Anthropic.md) | Cloud | Claude models, vision, extended thinking |
| [OpenAI](Providers/OpenAI.md) | Cloud | GPT models, DALL-E, embeddings |
| [HuggingFace](Providers/HuggingFace.md) | Cloud | Model variety, transcription, embeddings |
| [Foundation Models](Providers/FoundationModels.md) | System | iOS 26+, zero setup, OS-managed |

---

## Key Features

### Structured Output
Generate type-safe responses that parse directly into Swift types:

```swift
@Generable
struct Recipe {
    @Guide("Recipe name")
    let title: String

    @Guide("Time in minutes", .range(1...180))
    let cookingTime: Int
}

let recipe = try await provider.generate(
    "Create a pasta recipe",
    returning: Recipe.self,
    model: .claudeSonnet45
)
```

[Learn more about Structured Output →](StructuredOutput.md)

### Tool Calling
Let LLMs invoke your Swift functions:

```swift
struct WeatherTool: AITool {
    @Generable
    struct Arguments {
        @Guide("City name")
        let city: String
    }

    var description: String { "Get weather for a city" }

    func call(arguments: Arguments) async throws -> String {
        // Your implementation
    }
}
```

[Learn more about Tool Calling →](ToolCalling.md)

### Streaming
Real-time token streaming with metadata:

```swift
for try await chunk in provider.stream("Tell me a story", model: .llama3_2_1B) {
    print(chunk.text, terminator: "")

    if let speed = chunk.tokensPerSecond {
        // Track generation performance
    }
}
```

[Learn more about Streaming →](Streaming.md)

---

## Platform Support

| Platform | Status | Providers |
|----------|--------|-----------|
| macOS 14+ | Full | All providers |
| iOS 17+ | Full | All providers |
| visionOS 1+ | Full | All providers |
| Linux | Partial | Anthropic, OpenAI, HuggingFace |

---

## Requirements

- **Swift**: 6.2+
- **Xcode**: 16.0+
- **MLX Provider**: Apple Silicon (arm64)
- **Foundation Models**: iOS 26.0+ / macOS 26.0+

---

## Additional Resources

- [README](../README.md) - Project overview and quick start
- [CLAUDE.md](../CLAUDE.md) - Project conventions and architecture
- [GitHub Discussions](https://github.com/christopherkarani/Conduit/discussions) - Ask questions and share ideas
- [GitHub Issues](https://github.com/christopherkarani/Conduit/issues) - Report bugs and request features

---

## Contributing

We welcome contributions! See the main [README](../README.md#contributing) for guidelines.
