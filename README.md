# SwiftAI

A unified Swift SDK for LLM inference across multiple providers.

[![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2017%20|%20macOS%2014%20|%20visionOS%201-blue.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Overview

SwiftAI provides a clean, idiomatic Swift interface for LLM inference across three providers:

| Provider | Use Case | Connectivity |
|----------|----------|--------------|
| **MLX** | Local inference on Apple Silicon | Offline |
| **HuggingFace** | Cloud inference via HF Inference API | Online |
| **Apple Foundation Models** | System-integrated on-device AI (iOS 26+) | Offline |

## Quick Start

```swift
import SwiftAI

// Simple generation
let provider = MLXProvider()
let response = try await provider.generate(
    "Explain quantum computing",
    model: .llama3_2_1B,
    config: .default
)

// Streaming
for try await chunk in provider.stream("Tell me a story", model: .llama3_2_3B) {
    print(chunk.text, terminator: "")
}

// Embeddings
let embedding = try await provider.embed("Hello world", model: .bgeSmall)
```

## Design Principles

1. **Explicit Model Selection** — No "magic" auto-selection; you choose your provider
2. **Swift 6.2 Concurrency** — Actors, Sendable types, AsyncSequence throughout
3. **Protocol-Oriented** — Provider abstraction via protocols with associated types
4. **Progressive Disclosure** — Simple API for beginners, full control for experts

## Installation

Add SwiftAI to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/christopherkarani/SwiftAI", from: "1.0.0")
]
```

## Documentation

- [API Specification](SwiftAI-API-Specification.md) - Complete API reference
- [Implementation Plan](.claude/artifacts/planning/implementation-plan.md) - Development roadmap

## Development with Claude Code

This project is configured for development with Claude Code. The configuration includes:

### Sub-Agents

| Agent | Model | Purpose |
|-------|-------|---------|
| `research-agent` | haiku | API docs, library research |
| `planning-agent` | opus | Phase breakdown, task lists |
| `protocol-architect` | opus | Protocol design, generics |
| `api-designer` | opus | Progressive disclosure, APIs |
| `macro-engineer` | sonnet | @StructuredOutput macros |
| `provider-implementer` | sonnet | MLX/HF/FM providers |
| `streaming-specialist` | sonnet | AsyncSequence work |
| `test-engineer` | sonnet | Unit/integration tests |
| `debug-agent` | sonnet | Bug fixes |
| `code-reviewer` | sonnet | Quality review |
| `implementation-checker` | sonnet | Phase verification |
| `swiftagents-integrator` | sonnet | SwiftAgents compat |

### Slash Commands

```bash
/phase 1        # Start working on phase 1
/verify-phase   # Verify current phase completion
/review         # Run code review
/test           # Run test suite
/lint           # Run SwiftLint
/status         # Show implementation progress
```

### MCP Servers

- **Context7**: Up-to-date library documentation
- **GitHub**: PR and issue management
- **Sequential Thinking**: Complex architectural decisions

### Getting Started with Claude Code

1. Open the project in Claude Code
2. Run `/status` to see implementation progress
3. Run `/phase 1` to start development
4. Use sub-agents for specialized tasks

## Requirements

- Swift 6.2+
- iOS 17+ / macOS 14+ / visionOS 1+
- Apple Silicon (for MLX provider)

## Related Projects

- [SwiftAgents](https://github.com/christopherkarani/SwiftAgents) - LangChain-style AI orchestration for Swift

## License

MIT License - see [LICENSE](LICENSE) for details.
