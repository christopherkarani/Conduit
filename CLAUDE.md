# CLAUDE.md

Guidance for Claude Code (and other AI assistants) when working in this repository.

## Project Overview

**Conduit** is a type-safe Swift 6.2 framework that provides a single, unified API
over many cloud and on-device LLM providers (Anthropic, OpenAI, OpenRouter, Ollama,
Kimi, MiniMax, HuggingFace, MLX, CoreML, llama.cpp, and Apple Foundation Models).

- Current version: `conduitVersion = "0.6.0"` (`Sources/Conduit/Conduit.swift:82`)
- Swift tools version: `6.2` (`Package.swift:1`)
- Platforms: iOS 17+, macOS 14+, visionOS 1+, Linux (cloud providers only)
- License: MIT

The package is deliberately split into two products so end users can opt into a
minimal surface or the full implementation:

- `Conduit` — the **facade** product (`Sources/ConduitFacade/ConduitFacade.swift`).
  Exposes the small, agent-friendly API: `Conduit`, `Provider`, `Session`,
  `Model`, `RunOptions`, `ToolSetBuilder`.
- `ConduitAdvanced` — the full implementation surface
  (`Sources/Conduit/` — note: the directory named `Conduit` maps to the
  `ConduitAdvanced` target in `Package.swift`). Use when callers need direct
  provider actors, protocols, and low-level controls.
- `ConduitMacros` — the Swift macro compiler plugin (`@Generable`, `@Guide`).

## Repository Layout

```
.
├── Package.swift                 # SPM manifest, traits, targets
├── Sources/
│   ├── Conduit/                  # → target: ConduitAdvanced (full surface)
│   │   ├── Conduit.swift         # version + re-export markers
│   │   ├── ConduitAPI.swift      # facade-style `Conduit`/`Provider`/`Session`
│   │   ├── ChatSession.swift     # @Observable stateful multi-turn session
│   │   ├── Builders/             # MessageBuilder, ResultBuilders
│   │   ├── Core/
│   │   │   ├── Protocols/        # AIProvider, TextGenerator, EmbeddingGenerator,
│   │   │   │                     # Transcriber, TokenCounter, ImageGenerator,
│   │   │   │                     # Tool, Generable
│   │   │   ├── Types/            # Message, Transcript, GeneratedContent,
│   │   │   │                     # GenerationSchema, GenerateConfig, etc.
│   │   │   ├── Streaming/        # GenerationChunk, StreamingResult
│   │   │   ├── Tools/            # ToolExecutor (tool-call loop)
│   │   │   ├── Errors/           # AIError, CloudError, ResourceError, ToolError
│   │   │   ├── Logging/          # ConduitLogger (swift-log)
│   │   │   └── Macros/           # GenerableMacros declarations
│   │   ├── Providers/
│   │   │   ├── Anthropic/        # AnthropicProvider (Claude)
│   │   │   ├── OpenAI/           # OpenAIProvider (+ Azure, Ollama, OpenRouter)
│   │   │   ├── MLX/              # MLXProvider, image, caches
│   │   │   ├── CoreML/           # CoreMLProvider (swift-transformers)
│   │   │   ├── FoundationModels/ # Apple Foundation Models (iOS 26+)
│   │   │   ├── HuggingFace/      # HuggingFaceProvider
│   │   │   ├── Kimi/             # Moonshot Kimi (OpenAI-compatible)
│   │   │   ├── MiniMax/          # MiniMax (OpenAI-compatible)
│   │   │   ├── Llama/            # llama.cpp via llama.swift
│   │   │   └── Extensions/       # Schema + StructuredOutput wiring
│   │   ├── ImageGeneration/      # DiffusionModelRegistry/Downloader
│   │   ├── Services/             # HFMetadataService, VLMDetector, MLX checks
│   │   ├── Utilities/            # JsonRepair, PartialJSONDecoder, SSEParser, GlobMatcher
│   │   └── Documentation.docc/   # DocC catalog
│   ├── ConduitFacade/
│   │   └── ConduitFacade.swift   # → target: Conduit (thin facade re-exports)
│   └── ConduitMacros/
│       ├── ConduitMacrosPlugin.swift
│       ├── GenerableMacro.swift  # @Generable expansion
│       └── GuideMacro.swift      # @Guide expansion
├── Tests/
│   ├── ConduitTests/             # Core + provider unit tests
│   │   ├── Core/                 # Generation, streaming, tools, JSON repair
│   │   ├── Providers/            # Anthropic, OpenAI, CoreML, Llama, etc.
│   │   ├── Builders/             # MessageBuilder tests
│   │   ├── ImageGeneration/
│   │   ├── Utilities/            # Parity tests for JSON/SSE/PartialJSON
│   │   ├── DocumentationExamplesTests.swift  # compiles doc snippets
│   │   └── LinuxCompatibilityTests.swift
│   ├── ConduitMLXTests/          # MLX-only tests (opt-in)
│   └── ConduitMacrosTests/       # @Generable / @Guide macro tests
├── docs/                         # VitePress site (guide/ + providers/)
├── .github/workflows/            # linux.yml, claude.yml, deploy-docs.yml
├── .swiftlint.yml                # SwiftLint config
├── AGENTS.md                     # Rules for AI agents working here
├── front-facing-api.md           # Canonical summary of the Conduit facade API
└── README.md
```

> Important path gotcha: `Package.swift` places the `ConduitAdvanced` target at
> `path: "Sources/Conduit"`, and the `Conduit` target at `path: "Sources/ConduitFacade"`.
> **The directory name does not match the target name.** When adding files, make sure
> they land under the correct directory for the target you mean to modify.

## Build, Test, Lint

Everything is SwiftPM. There is no Xcode project to regenerate.

```bash
# Build (no traits — minimal, Linux-friendly)
swift build

# Full test suite
swift test

# Focused test filters (verified in AGENTS.md)
swift test --filter DocumentationExamplesTests
swift test --filter TextEmbeddingCacheTests
swift test --filter JsonRepairTests
swift test --filter AnthropicIntegrationTests            # skips without key
ANTHROPIC_API_KEY=sk-ant-... swift test --filter AnthropicIntegrationTests

# Macro target only (matches Linux CI `test-macros` job)
swift build --target ConduitMacros
swift test --filter ConduitMacrosTests

# Enable provider traits (Linux CI runs this combo)
swift test --traits OpenAI,Anthropic,Kimi,MiniMax
```

Linux CI (`.github/workflows/linux.yml`) runs three jobs on every push:
`build-and-test` (no traits, with coverage), `test-macros`, and
`test-with-providers` (with `OpenAI,Anthropic,Kimi,MiniMax`). Keep these green.

SwiftLint config lives in `.swiftlint.yml`. Notable limits:
- `line_length` warning 120 / error 150 (comments and URLs ignored)
- `file_length` warning 500 / error 1100
- `function_body_length` warning 50 / error 120
- `function_parameter_count` warning 6 / error 8

## Package Traits (feature flags)

No traits are enabled by default, which keeps the default build lightweight and
Linux-compatible. Each trait defines a compile flag used throughout the code:

| Trait             | Compile flag               | What it enables                                  |
|-------------------|----------------------------|--------------------------------------------------|
| `OpenAI`          | `CONDUIT_TRAIT_OPENAI`     | OpenAI / Azure / Ollama / custom endpoints       |
| `OpenRouter`      | `CONDUIT_TRAIT_OPENROUTER` | OpenRouter via OpenAIProvider                    |
| `Anthropic`       | `CONDUIT_TRAIT_ANTHROPIC`  | AnthropicProvider                                |
| `Kimi`            | `CONDUIT_TRAIT_KIMI`       | Moonshot Kimi (requires `OpenAI` too)            |
| `MiniMax`         | `CONDUIT_TRAIT_MINIMAX`    | MiniMax (requires `OpenAI` too)                  |
| `MLX`             | `CONDUIT_TRAIT_MLX`        | On-device MLX (Apple Silicon only)               |
| `CoreML`          | `CONDUIT_TRAIT_COREML`     | Core ML via swift-transformers                   |
| `HuggingFaceHub`  | —                          | HuggingFace Hub downloads                        |
| `Llama`           | —                          | llama.cpp via llama.swift                        |

Guard provider-specific code with the matching flag. MLX additionally needs a
`canImport(MLX)` guard because the dependency is only added when
`CONDUIT_INCLUDE_MLX_DEPS=1` is set in the environment (see `Package.swift:7-10`):

```swift
#if CONDUIT_TRAIT_ANTHROPIC
let provider = AnthropicProvider(configuration: .standard(apiKey: key))
#endif

#if CONDUIT_TRAIT_MLX && canImport(MLX)
let provider = MLXProvider()
#endif
```

MLX dependencies are intentionally opt-in at **package resolution** time:

```bash
CONDUIT_INCLUDE_MLX_DEPS=1 swift build --traits MLX
CONDUIT_SKIP_MLX_DEPS=1    swift build        # default-ish behavior
```

## Architecture Cheat Sheet

### Protocol hierarchy (`Sources/Conduit/Core/Protocols/`)
- `AIProvider` — actor-based umbrella protocol (availability, cancellation).
- `TextGenerator` — `generate` / `stream` / `streamWithMetadata`. Every provider implements this.
- `EmbeddingGenerator`, `Transcriber`, `ImageGenerator`, `TokenCounter` — optional capabilities.
- `Tool<Arguments, Output>` — user-defined tools invoked during tool-call loops.
- `Generable` — types the model can emit as structured output (usually via the `@Generable` macro).

Every concrete provider is a Swift **actor** (e.g. `actor AnthropicProvider`,
`actor OpenAIProvider`, `actor MLXProvider`). All public types are `Sendable`
and the advanced target has `StrictConcurrency` enabled as an experimental
feature. Preserve these guarantees when adding code.

### Key types (`Sources/Conduit/Core/Types/`)
`Message`, `Prompt`, `Instructions`, `Transcript`, `GenerateConfig`,
`GenerationResult`, `GenerationChunk`, `GenerationSchema`, `GeneratedContent`,
`DynamicGenerationSchema`, `ModelIdentifier`, `ModelCapabilities`,
`ProviderRuntimeCapabilities`, `UsageStats`, `TokenLogprob`, `RateLimitInfo`,
`ImageGenerationConfig`, `GeneratedImage`.

Note for doc/example updates (from `AGENTS.md`): current API names are
`GeneratedContent`, `GenerationSchema`, `Tool`, `Transcript`. **Do not**
reintroduce legacy terms like `StructuredContent`, `Schema`, or `AITool`.

### Facade API (`Sources/Conduit/ConduitAPI.swift` + `Sources/ConduitFacade/ConduitFacade.swift`)
Canonical surface for agents and human callers:

```swift
import Conduit

let app = Conduit(.anthropic(apiKey: "sk-ant-..."))
let session = try app.session(model: .anthropic("claude-opus-4-6")) {
    $0.run { $0.maxTokens = 300; $0.temperature = 0.2 }
    $0.tools { MyTool(); AnotherTool() }        // ToolSetBuilder
}
let reply = try await session.run("Summarize this PR.")
```

- `Model` uses a `family` enum (`.openAI`, `.anthropic`, `.mlx`, `.mlxLocal`,
  `.llama`, `.coreML`, `.foundationModels`, `.kimi`, `.miniMax`, `.huggingFace`,
  `.custom`) plus an `id` string.
- `Provider.custom(_:mapModel:prepare:release:)` is the extensibility hook —
  every built-in provider factory ultimately delegates to it.
- Keep the `front-facing-api.md` file in sync when you change this surface.

### ChatSession (`Sources/Conduit/ChatSession.swift`)
`@Observable` actor-friendly session for multi-turn chat, with history
management, `send(_:)` / `stream(_:)`, tool execution via `ToolExecutor`,
cancellation via `cancel()`, and an opt-in `WarmupConfig` (`.default` or
`.eager`) for MLX-style first-message latency.

### Macros (`Sources/ConduitMacros/`)
- `@Generable` synthesizes `GeneratedContent`, `GenerationSchema`, a
  memberwise init, an `init(_: GeneratedContent)`, a `PartiallyGenerated` shim,
  and prompt/instructions representations. Works for `struct` and `enum`.
- `@Guide(description:...)` attaches natural-language descriptions and value
  constraints (ranges, counts, etc.) to properties.
- Macro output must **qualify type references** to avoid collisions when the
  containing target shadows `Conduit` (see commit `583c724`). Do not revert
  those qualifications.

## Conventions and Invariants

1. **Swift 6.2 strict concurrency.** Everything public must be `Sendable`.
   Providers are actors; don't introduce shared mutable state without a lock.
   `ChatSession` uses `NSLock` and never holds it across `await`.
2. **Traits gate providers.** Any new provider code must live behind its
   `CONDUIT_TRAIT_*` flag (and `canImport(...)` where needed). Do not import
   provider-specific SDKs from trait-agnostic files.
3. **Module layout.** Do not move files between `Sources/Conduit/` (the
   `ConduitAdvanced` target) and `Sources/ConduitFacade/` (the `Conduit`
   target) without understanding the facade/advanced split.
4. **Linux must keep building.** Cloud providers, utilities, and macros must
   compile on Linux. MLX, CoreML, and Foundation Models are Apple-only.
   `Tests/ConduitTests/LinuxCompatibilityTests.swift` guards this.
5. **Macros must stay hermetic.** The macro target uses a dedicated module
   cache (`-module-cache-path .build/conduit-module-cache`). Don't add
   dependencies that break Linux macro builds — `test-macros` CI runs on Linux.
6. **Tool + Generable wiring.** When adding new provider-specific structured
   output, extend `Sources/Conduit/Providers/Extensions/` rather than the core
   types, and add coverage in `Tests/ConduitTests/Core/StructuredOutput*.swift`.
7. **Documentation.** Code examples live in both `docs/` (VitePress) and
   `Sources/Conduit/Documentation.docc/`. `DocumentationExamplesTests` compiles
   the snippets — if you change an example, run that filter.
8. **No planning docs in commits.** Per `AGENTS.md`: never commit ad-hoc
   planning `.md` files. Ask if you're unsure whether a new markdown file
   belongs in the repo.
9. **SwiftLint.** Stay under the limits in `.swiftlint.yml`. If you legitimately
   need to exceed a limit (as the `OpenAIProvider` already does), prefer a
   localized `// swiftlint:disable:next ...` rather than changing global config.
10. **Don't introduce `XCTest`.** Tests use the Swift `Testing` framework.

## Adding a New Provider (checklist)

1. Create `Sources/Conduit/Providers/<Name>/` with `*Provider.swift`,
   `*Configuration.swift`, `*ModelID.swift`, and auth helpers as needed.
2. Mark the actor `public actor <Name>Provider: AIProvider, TextGenerator`
   (add other capability protocols as applicable).
3. Add a `.trait(...)` in `Package.swift` and a matching
   `.define("CONDUIT_TRAIT_<NAME>", .when(traits: ["<Name>"]))` in all three
   affected targets (`ConduitAdvanced`, `Conduit`, `ConduitTests`, and
   `ConduitMLXTests` if relevant).
4. Wrap all provider code in `#if CONDUIT_TRAIT_<NAME>` and, for native SDKs,
   also in `#if canImport(<SDK>)`.
5. Add a facade factory in `ConduitAPI.swift` (and re-export in
   `ConduitFacade.swift` if it needs to be visible from the minimal module).
6. Add unit tests in `Tests/ConduitTests/Providers/<Name>/` and update the
   Linux CI trait list in `.github/workflows/linux.yml` if the provider should
   be covered there.
7. Add documentation in `docs/providers/<name>.md` and the matching entry in
   `Sources/Conduit/Documentation.docc/Providers/`.

## Common Tasks

- **Update front-facing API** → edit `ConduitAPI.swift` + `ConduitFacade.swift`,
  then refresh `front-facing-api.md`, the `docs/guide/` pages, and the DocC
  catalog so examples still compile under `DocumentationExamplesTests`.
- **Change provider defaults** → update the provider's `*Configuration.swift`
  and the facade `*Options` struct in `ConduitAPI.swift` side by side.
- **Bump `conduitVersion`** → `Sources/Conduit/Conduit.swift:82`. The version
  is re-exported through the facade as `Conduit.conduitVersion`.
- **Touch streaming** → remember to update both `stream(_:)` and
  `streamWithMetadata(...)`, and add an entry to
  `Tests/ConduitTests/Core/StreamingCancellationTests.swift` when behavior
  changes around cancellation.

## Git / Workflow

- `main` is the integration branch. Feature branches follow names like
  `feature/*`, `fix-*`, or `claude/*` for AI-driven work.
- This file (`CLAUDE.md`) is listed in `.gitignore` under the
  "Claude Code - ignore completely" section. If you are committing an update
  to it, you will need `git add -f CLAUDE.md`, and you should double-check
  with the user that committing the file is intended (see `AGENTS.md` rule on
  planning docs).
- Never commit secrets. Cloud provider tests read keys from environment
  variables (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `OPENROUTER_API_KEY`,
  `MOONSHOT_API_KEY`, `MINIMAX_API_KEY`, `HF_TOKEN`) and skip when absent.

## Useful References

- `AGENTS.md` — short list of verified workflows and recent corrections.
- `front-facing-api.md` — canonical summary of the `Conduit` facade surface.
- `docs/guide/architecture.md` — protocol hierarchy walkthrough.
- `docs/guide/getting-started.md` — installation, traits, quick start.
- `README.md` — top-level overview with platform/Swift badges.
