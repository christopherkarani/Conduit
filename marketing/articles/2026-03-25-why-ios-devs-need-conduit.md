# Why iOS Developers Need Conduit: A Unified SDK for Every LLM

If you've shipped AI features in an iOS app recently, you know the drill. OpenAI SDK here. Anthropic SDK there. Maybe you tried Ollama for local inference. Each one has its own API, its own message format, its own streaming implementation. Switching from GPT-4 to Claude felt like rewriting the networking layer.

I got tired of this. So I built Conduit.

## The core idea

One protocol, nine backends. When you build on `TextGenerator`, swapping providers means changing one initializer:

```swift
// OpenAI
let provider = OpenAIProvider.openAIKey(apiKey: "sk-...")

// Anthropic — just change the initializer
let provider = AnthropicProvider.anthropicKey(apiKey: "sk-ant-...")

// Local MLX (Apple Silicon)
let provider = try await MLXProvider.configuration(.stable)

// Same API everywhere
let result = try await provider.generate(prompt: "Hello", model: .gpt4o, config: .default)
```

Your prompt pipelines, message handling, streaming logic — all of it stays the same. The provider is an implementation detail.

## Tool calling that doesn't make you want to quit

Tool calling is where things get ugly. OpenAI uses function calling. Anthropic uses tool_use. Each has different JSON formats, different error handling. You end up writing adapters just to get a weather lookup working.

Conduit's `ToolExecutor` handles the entire loop:

```swift
let session = ChatSession(provider: provider, model: .gpt4o, config: .default)
session.toolExecutor = ToolExecutor(tools: [WeatherTool(), SearchTool()])
session.toolCallRetryPolicy = .retryableAIErrors(maxAttempts: 3)

// Just send. Tools execute automatically.
let response = try await session.send("What's the weather in Tokyo?")
```

No manual result parsing. No format conversion. Just async/await.

## Structured output without the Codable headache

JSON schema validation with LLMs usually means lots of manual `Codable`. Custom decoding logic. Error handling everywhere. Conduit's `@Generable` macro handles the boilerplate:

```swift
@Generable
struct WeatherResult {
    @Guide(description: "City name")
    var city: String

    @Guide(description: "Temperature in Celsius")
    var temperature: Double

    @Guide(description: "Weather condition")
    var condition: String
}

// Auto-synthesized: init, schema, partial JSON handling
let result = try await provider.generate(
    prompt: "Return weather for Tokyo as JSON",
    config: .default.responseFormat(.jsonObject)
)
let weather = try WeatherResult(result.generatedContent)
```

One attribute, ~150 lines of boilerplate synthesized. Initializers, schema generation, partial JSON handling for streaming.

## Streaming JSON that doesn't break

LLM streaming is messy. Tokens arrive out of order. JSON objects get split across chunks. You spend more time debugging partial JSON than building features.

Conduit's `GeneratedContent` handles incomplete JSON gracefully:

```swift
// If model outputs {"title": "A story of" (truncated)
// Conduit tries closing with }, then "", falls back to string
let content = try GeneratedContent(json: partialJson)
```

Combined with `StreamingResult<T>`, you get typed snapshots as data arrives:

```swift
for try await snapshot in stream {
    // snapshot.content is WeatherResult.PartiallyGenerated
    // All fields Optional — nil until field arrives
    print(snapshot.content.city)
}
```

## Local inference on iOS

MLX on Apple Silicon makes this practical now. Conduit makes it first-class:

```swift
// Let the model tell you what it supports
let capabilities = try await provider.getModelCapabilities()

// KV quantization, attention sinks, speculative scheduling
config.runtimeFeatures.kvQuantization.enabled = true

// Warmup for JIT compilation
try await provider.warmUp(model: .llama3_2_1b, prefillText: "Hi", maxTokens: 5)
```

No API keys for simple tasks. No latency on basic prompts. No sending user data anywhere.

## SwiftUI integration that actually works

`ChatSession` is `@Observable`. Direct SwiftUI binding without wrappers:

```swift
@Observable
class MyViewModel {
    var session: ChatSession<OpenAIProvider>
}

struct ChatView: View {
    @State var viewModel = MyViewModel()

    var body: some View {
        VStack {
            ForEach(viewModel.session.messages) { message in
                MessageRow(message)
            }

            if viewModel.session.isGenerating {
                ProgressView()
            }
        }
    }
}
```

Thread safety via NSLock — the lock is never held across await points.

## Some numbers

| Task | Without Conduit | With Conduit |
|------|-----------------|--------------|
| Switch providers | 2-3 days | 5 minutes |
| Tool calling code | 500+ lines | 50 lines |
| Structured output | Custom Codable | @Generable |
| Streaming JSON | Roll your own | Built-in |
| Local inference | Proprietary | First-class |

## What makes this different

Most "unified" SDKs are thin wrappers. Conduit goes deeper:

- Partial JSON recovery isn't a feature, it's a design decision
- Runtime feature gating in MLXProvider lets each model expose its capabilities
- Layered VLM detection cascades through metadata, config, and name heuristics
- Actors everywhere — providers, tool executor, model registry

## The point

You're not locked into one provider. You won't have to rewrite when Claude 4 drops. You don't need separate code paths for local vs cloud.

Treat AI as infrastructure. Conduit handles the plumbing.

Swift 6.2. iOS 17+. Apple Silicon optimized. Open source.

---

Get started:

```bash
# Cloud-only
swift build

# With OpenAI + Anthropic
swift build --traits OpenAI,Anthropic

# MLX for Apple Silicon
swift build --traits MLX
```

Repo: github.com/AIStack/Conduit
