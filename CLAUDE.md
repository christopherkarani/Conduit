# SwiftAI Framework - Claude Code Configuration

> **Project**: SwiftAI - Unified Swift SDK for LLM Inference
> **Swift Version**: 6.2
> **Platforms**: iOS 17+, macOS 14+, visionOS 1+

---

## Project Overview

SwiftAI is a unified Swift SDK providing a clean, idiomatic interface for LLM inference across three providers:
- **MLX**: Local inference on Apple Silicon (offline)
- **HuggingFace**: Cloud inference via HF Inference API (online)  
- **Apple Foundation Models**: System-integrated on-device AI (iOS 26+, offline)

This framework serves as the inference layer for SwiftAgents (github.com/christopherkarani/SwiftAgents).

---

## Design Principles

1. **Explicit Model Selection** — No "magic" auto-selection; developers choose their provider
2. **Swift 6.2 Concurrency** — Actors, Sendable types, AsyncSequence throughout
3. **Protocol-Oriented** — Provider abstraction via protocols with associated types
4. **Composable** — Designed to work with external orchestration layers (agents, RAG)
5. **Progressive Disclosure** — Simple API for beginners, full control for experts

---

## Project Structure

```
SwiftAI/
├── Package.swift
├── Sources/SwiftAI/
│   ├── SwiftAI.swift                    # Re-exports & convenience
│   ├── Core/
│   │   ├── Protocols/                   # AIProvider, TextGenerator, etc.
│   │   ├── Types/                       # ModelIdentifier, Message, etc.
│   │   ├── Streaming/                   # GenerationStream, chunks
│   │   └── Errors/                      # AIError, ProviderError
│   ├── Providers/
│   │   ├── MLX/                         # MLXProvider implementation
│   │   ├── HuggingFace/                 # HuggingFaceProvider
│   │   └── FoundationModels/            # Apple FM wrapper
│   ├── ModelManagement/                 # Download, cache, delete
│   ├── Builders/                        # Result builders
│   └── Macros/                          # @StructuredOutput macro
└── Tests/SwiftAITests/
```

---

## Key Commands

```bash
# Build
swift build

# Test
swift test

# Lint (SwiftLint must be installed)
swiftlint lint --strict

# Format
swift-format format -i -r Sources/ Tests/

# Generate docs
swift package generate-documentation
```

---

## Implementation Plan Reference

The implementation plan is in `.claude/artifacts/planning/implementation-plan.md`.
Follow the 15-phase plan sequentially. Each phase has:
- Objective and deliverables
- Code examples showing target API
- Acceptance criteria checklist

---

## Orchestration Rules

### Sub-Agent Delegation

You are the **orchestrator**. Delegate tasks to specialized sub-agents:

| Agent | Use When | Model |
|-------|----------|-------|
| `research-agent` | Need API docs, library info, Swift 6.2 features | haiku |
| `planning-agent` | Breaking down phases, creating task lists | opus |
| `protocol-architect` | Designing protocols, generics, associated types | opus |
| `macro-engineer` | Implementing @StructuredOutput, swift-syntax | sonnet |
| `provider-implementer` | Building MLX/HF/FM provider code | sonnet |
| `streaming-specialist` | AsyncSequence, GenerationStream work | sonnet |
| `api-designer` | Result builders, fluent APIs, ergonomics | opus |
| `test-engineer` | Writing unit/integration tests | sonnet |
| `debug-agent` | Fixing compilation errors, runtime bugs | sonnet |
| `code-reviewer` | Quality review, Swift conventions | sonnet |
| `implementation-checker` | Verifying phase completion | sonnet |
| `swiftagents-integrator` | Ensuring SwiftAgents compatibility | sonnet |

### Delegation Syntax

```
Use the {agent-name} agent to {task description}
```

Example:
```
Use the protocol-architect agent to design the AIProvider protocol with associated types for Response and StreamChunk
```

### Parallel Execution

For independent tasks, run agents in parallel:
```
In parallel:
1. Use the research-agent to find MLX Swift API documentation
2. Use the protocol-architect to draft the TokenCounter protocol
3. Use the test-engineer to write test stubs for Phase 1
```

### Background Tasks

Code review and debug agents can run in background:
```
In background, use the code-reviewer agent to review the changes in Sources/SwiftAI/Core/
```

---

## Handoff Protocol

### Artifact Storage

Sub-agents write detailed outputs to `.claude/artifacts/`:
```
.claude/artifacts/
├── research/           # API docs, library findings
├── decisions/          # Architecture Decision Records
├── reports/            # Implementation reports
└── reviews/            # Code review findings
```

### Handoff Contract

When delegating, provide:
1. **Task**: Clear objective
2. **Context**: Relevant file paths or artifact references
3. **Output**: Expected deliverable format
4. **Next**: What happens after completion

Example:
```
Use the provider-implementer agent:
- Task: Implement MLXProvider.generate() method
- Context: See Sources/SwiftAI/Core/Protocols/AIProvider.swift
- Output: Complete implementation in Sources/SwiftAI/Providers/MLX/MLXProvider.swift
- Next: implementation-checker will verify against Phase 10 criteria
```

---

## Quality Gates

Before marking any phase complete, verify:

1. **Compilation**: `swift build` passes without warnings
2. **Tests**: `swift test` passes (write tests first when possible)
3. **Lint**: `swiftlint lint --strict` passes
4. **Documentation**: All public APIs have doc comments

Use the `implementation-checker` agent after each phase to verify completion.

---

## Code Style

### Swift Conventions
- Use `actor` for thread-safe providers
- All public types must be `Sendable`
- Prefer `async throws` over callbacks
- Use `AsyncThrowingStream` for streaming
- Explicit `self` in closures
- Trailing closure syntax for single closures

### Naming
- Protocols: `-ing` suffix for capabilities (e.g., `TextGenerating`)
- Types: Descriptive nouns (e.g., `GenerationResult`)
- Methods: Verb phrases (e.g., `generate`, `embed`, `transcribe`)

### Documentation
```swift
/// Brief description.
///
/// Detailed explanation if needed.
///
/// ## Usage
/// ```swift
/// let result = try await provider.generate("Hello", model: .llama3_2_1B)
/// ```
///
/// - Parameters:
///   - prompt: The input text.
///   - model: The model identifier.
/// - Returns: The generated response.
/// - Throws: `AIError` if generation fails.
```

---

## Progressive Disclosure API Design

### Level 1: Simple (1 line)
```swift
let response = try await SwiftAI.generate("Hello", model: .llama3_2_1B)
```

### Level 2: Standard (explicit provider)
```swift
let provider = MLXProvider()
let response = try await provider.generate("Hello", model: .llama3_2_1B, config: .default)
```

### Level 3: Advanced (full control)
```swift
let provider = MLXProvider(configuration: .init(memoryLimit: .gigabytes(8)))
let messages = Messages {
    Message.system("You are helpful.")
    Message.user("Hello")
}
let config = GenerateConfig.default.temperature(0.8).maxTokens(500)
let stream = provider.stream(messages: messages, model: .mlx("custom/model"), config: config)
```

---

## SwiftAgents Integration Points

Key APIs that SwiftAgents depends on:
- `TokenCounter` protocol for memory/context management
- `EmbeddingGenerator` for RAG workflows
- `ModelManager` for downloads and caching
- `GenerationStream` for streaming responses

Ensure these APIs remain stable and well-documented.

---

## Context7 Usage

Always use Context7 for up-to-date documentation:
```
use context7 to get the latest MLX Swift documentation
use context7 to find swift-transformers API examples
```

---

## Do Not

- Do not auto-select providers based on availability
- Do not use deprecated Swift concurrency patterns
- Do not create tight coupling with Apple Foundation Models internals
- Do not skip writing tests for new functionality
- Do not commit code that doesn't compile

---

## Getting Started

1. Read the API specification: `SwiftAI-API-Specification.md`
2. Review implementation plan: `.claude/artifacts/planning/implementation-plan.md`
3. Start with Phase 1: Project Setup & Package.swift
4. After each phase, run `/verify-phase` to check completion

---

## Slash Commands

- `/phase {n}` - Start working on phase N
- `/verify-phase` - Verify current phase is complete
- `/review` - Run code review on recent changes
- `/test` - Run test suite
- `/lint` - Run SwiftLint
- `/status` - Show implementation progress
