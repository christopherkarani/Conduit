---
layout: home

hero:
  name: Conduit
  text: Unified Swift SDK for LLM Inference
  tagline: One protocol-driven API for Anthropic, OpenAI, MLX, HuggingFace, and more. Swap providers with a single initializer.
  image:
    src: /conduit-logo.svg
    alt: Conduit
  actions:
    - theme: brand
      text: Get Started
      link: /guide/getting-started
    - theme: alt
      text: View on GitHub
      link: https://github.com/christopherkarani/Conduit

features:
  - icon: "🔌"
    title: 10 Providers, One API
    details: Anthropic, OpenAI, OpenRouter, Ollama, MLX, HuggingFace, Kimi, MiniMax, CoreML, llama.cpp, and Apple Foundation Models — all through TextGenerator.
  - icon: "🔒"
    title: Swift 6.2 Concurrency
    details: Every provider is an actor. All types are Sendable. Full strict concurrency safety out of the box.
  - icon: "🏗️"
    title: Structured Output
    details: The @Generable macro synthesizes JSON schemas and typed initializers. Get validated Swift values directly from LLM responses.
  - icon: "🛠️"
    title: Tool Calling
    details: Define Swift tools that models can invoke. ChatSession handles the full tool loop automatically.
  - icon: "📦"
    title: Trait-Based Compilation
    details: Only compile the providers you need. No traits enabled by default keeps the package lightweight and Linux-compatible.
  - icon: "🍎"
    title: Apple Platform Native
    details: SwiftUI integration with @Observable ChatSession, on-device MLX inference, and Foundation Models support on iOS 26+.
---
