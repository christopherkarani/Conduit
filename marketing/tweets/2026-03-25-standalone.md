# Standalone Tweets — 2026-03-25

## Tweet 1 — metric

Rewrote our AI layer for the third time this year.

OpenAI → Claude → Ollama. Each time = rewriting everything.

Conduit: one protocol, nine backends. Same code.

📎 Image: `../assets/code-images/provider-swap.png`

---

## Tweet 2 — hot-take

Stop writing custom tool-calling loops.

ToolExecutor handles retries, parallel execution, result parsing.

You write the tool. Conduit handles the boring parts.

---

## Tweet 3 — code

@Generable macro:

```swift
@Generable
struct WeatherResult {
    @Guide(description: "City name")
    var city: String
    var temperature: Double
}
```

One attribute. Synthesizes ~150 lines: init, schema, partial JSON.

📎 Image: `../assets/code-images/generable.png`

---

## Tweet 4 — insight

LLM streaming is messy because JSON arrives in chunks.

Model outputs `{"title": "A story of"` and stops.

Conduit closes unclosed braces automatically. Saved me weeks of debugging.

---

## Tweet 5 — question-hook

What if your iOS app could run GPT-4 class models locally?

MLX on Apple Silicon. KV quantization. Warmup for JIT.

No API keys. No latency. No privacy nightmares.

---

## Tweet 6 — metric

Provider switch time with traditional SDKs: 2-3 days.

With Conduit: 5 minutes.

The API is the same. The provider is an implementation detail.

---

## Tweet 7 — til

TIL @Observable classes can't be actors in Swift.

ChatSession uses NSLock instead. Lock never held across await points.

Workaround: elegant? No. Does it work? Yes.

---

## Tweet 8 — diagram

Conduit architecture:

```
Your Code
    ↓
TextGenerator Protocol
    ↓
OpenAI | Anthropic | MLX | HuggingFace | Llama | CoreML
```

One interface. Every backend.

📎 Image: `../assets/diagrams/architecture.svg`
