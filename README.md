<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/assets/banner-dark.svg">
    <img src="docs/assets/banner-light.svg" alt="Conduit Banner" width="100%">
  </picture>
</p>

<p align="center">
  <a href="https://swift.org">
    <img src="https://img.shields.io/badge/Swift-6.2-F05138.svg?style=flat&logo=swift" alt="Swift 6.2">
  </a>
  <a href="https://developer.apple.com">
    <img src="https://img.shields.io/badge/Platforms-iOS%2017+%20|%20macOS%2014+%20|%20visionOS%201+%20|%20Linux-007AFF.svg?style=flat" alt="Platforms">
  </a>
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/License-MIT-green.svg?style=flat" alt="License">
  </a>
  <a href="https://github.com/christopherkarani/Conduit/stargazers">
    <img src="https://img.shields.io/github/stars/christopherkarani/Conduit?style=flat" alt="Stars">
  </a>
</p>

<p align="center">
  <b>Conduit</b> is a type-safe Swift framework for working with cloud and on-device language models through one API.
</p>

<p align="center">
  <a href="README.md">English</a> |
  <a href="locales/README.es.md">Español</a> |
  <a href="locales/README.ja.md">日本語</a> |
  <a href="locales/README.zh-CN.md">中文</a>
</p>

---

## What it gives you

- **Fast local inference:** tuned for Apple Silicon with first-class **MLX** support.
- **Type-safe structured output:** **Swift 6 macros** validate your generated shapes at compile time.
- **One surface for multiple providers:** switching between Claude, GPT-4o, and local models is a small config change.
- **Actor-based providers:** the concurrency model stays explicit and thread-safe.

---

## Performance

Conduit is tuned for Apple Silicon and local model throughput. The chart below shows the kind of token rates you can expect on recent M-series hardware.

<p align="center">
  <svg width="600" height="200" viewBox="0 0 600 200" fill="none" xmlns="http://www.w3.org/2000/svg">
    <rect width="600" height="200" rx="12" fill="#1C1C1E"/>
    <path d="M50 150L150 120L250 130L350 80L450 60L550 40" stroke="#007AFF" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>
    <text x="50" y="180" fill="#8E8E93" font-family="SF Pro, sans-serif" font-size="12">M1</text>
    <text x="250" y="180" fill="#8E8E93" font-family="SF Pro, sans-serif" font-size="12">M2 Max</text>
    <text x="550" y="180" fill="#8E8E93" font-family="SF Pro, sans-serif" font-size="12">M3 Max</text>
    <text x="20" y="40" fill="#8E8E93" font-family="SF Pro, sans-serif" font-size="12" transform="rotate(-90 20 40)">Tokens/sec</text>
  </svg>
</p>
<p align="center"><i>Benchmark: Token throughput on M3 Max (Llama 3.1 8B, 4-bit Quantized)</i></p>

---

## Quick Start

The default path is intentionally small:

```swift
import Conduit

// 1. Initialize your provider
let app = Conduit(.anthropic(apiKey: "sk-ant-..."))

// 2. Create a session with modern async/await
let session = try app.session(model: .anthropic("claude-opus-4-6"))

// 3. Run and get type-safe results
let response = try await session.run("Explain the benefits of Swift Actors.")
print(response)
```

### Provider Swap in One Line

Moving from cloud to local mostly means swapping the provider initializer:

```swift
// From Cloud...
let cloud = Conduit(.openAI(apiKey: "sk-..."))

// ...to Local Apple Silicon (MLX)
let local = Conduit(.mlx())
let localSession = try local.session(model: .mlxLocal("/Users/me/models/Llama-3.2-1B-Instruct-4bit"))
```

---

## Documentation

The docs cover the main pieces without much ceremony:

- [**Getting Started**](docs/guide/getting-started.md): installation and your first generation.
- [**Structured Output**](docs/guide/structured-output.md): type-safe JSON with `@Generable`.
- [**Tool Calling**](docs/guide/tool-calling.md): extending LLMs with native Swift functions.
- [**Streaming**](docs/guide/streaming.md): real-time token streaming with `AsyncSequence`.
- [**Architecture**](docs/guide/architecture.md): how Conduit is put together.

---

## License

Conduit is released under the **MIT License**. See [LICENSE](LICENSE).
