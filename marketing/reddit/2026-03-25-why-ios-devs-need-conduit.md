# Reddit Post — Why iOS Developers Need Conduit — 2026-03-25

**Subreddit:** r/iOSProgramming / r/swift

---

**Title:** Built a unified Swift SDK that works with OpenAI, Anthropic, MLX, and llama.cpp — switching providers is one line of code

---

Every few weeks a new LLM provider drops. GPT-4o, Claude 3.5, Gemini 1.5, Llama 3.2.

Each time, teams scramble to integrate. Different APIs. Different message formats. Different streaming implementations.

I got tired of this. Built Conduit.

**One protocol, nine backends.**

```swift
// OpenAI
let provider = OpenAIProvider.openAIKey(apiKey: "sk-...")

// Anthropic — change the initializer
let provider = AnthropicProvider.anthropicKey(apiKey: "sk-ant-...")

// MLX on Apple Silicon — local inference
let provider = try await MLXProvider.configuration(.stable)

// Same API everywhere
let result = try await provider.generate(prompt: "Hello", model: .gpt4o, config: .default)
```

**What makes it different:**

1. **@Generable macro** — one attribute instead of manual Codable:
```swift
@Generable
struct WeatherResult {
    @Guide(description: "City name")
    var city: String
    var temperature: Double
}
```

2. **Streaming JSON recovery** — when a model outputs `{"title": "A story of"}` (truncated), Conduit tries closing braces. This sounds minor until you've spent days debugging partial JSON in production.

3. **ToolExecutor** — the whole tool-calling loop (execute, retry, parse results) runs transparently. Set it and forget it.

4. **Local inference first-class** — MLX with KV quantization, attention sinks, warmup for JIT compilation.

**Honest limitations:**
- Swift 6.2 only (uses primary associated types heavily)
- iOS 17+ / macOS 14+
- MLX trait requires Apple Silicon
- FoundationModels on iOS 26+ (still beta territory)

Repo: github.com/AIStack/Conduit

Been using this in prod for a few months. The provider-switching story is as smooth as I hoped. Happy to answer questions.
