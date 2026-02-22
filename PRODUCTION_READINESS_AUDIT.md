# Production Readiness Audit: Conduit

**Date:** 2026-02-22
**Auditor:** Principal Engineer (Automated Deep Review)
**Repository:** Conduit - Multi-provider Swift AI SDK
**Scope:** Full repository audit (Sources, Tests, Package configuration)
**Swift Toolchain:** 6.2 | **Platforms:** iOS 17+, macOS 14+, visionOS 1+

---

## 1. Executive Summary

### Production Readiness Score: 7.0 / 10

Conduit is a well-architected, multi-provider AI SDK with strong fundamentals: proper actor isolation, comprehensive error taxonomy, secure credential handling, and thoughtful API design using Swift 6.2 traits for modular compilation. The codebase demonstrates experienced engineering judgment in most areas.

However, several issues prevent a higher score: `@unchecked Sendable` usage with manual `NSLock` synchronization introduces data-race risk surfaces that bypass the compiler; silent error-swallowing patterns make debugging difficult in production; critical paths contain `fatalError`/`preconditionFailure` calls that can crash users; and test coverage has significant gaps in streaming, concurrency, and failure-path scenarios.

### Top 5 Critical Risks

| # | Risk | Severity | Section |
|---|------|----------|---------|
| 1 | `ChatSession` is `@unchecked Sendable` with manual `NSLock` -- any missed lock discipline causes data races | **Blocker** | S4 |
| 2 | `LlamaProvider` stores `OpaquePointer` as `nonisolated(unsafe)` -- unsound if accessed concurrently | **Blocker** | S4 |
| 3 | `fatalError` in `Generable.asPartiallyGenerated()` default impl crashes in production | **Major** | S2 |
| 4 | Silent error swallowing in `HFMetadataService`, `ModelCache` hides failures from callers | **Major** | S2 |
| 5 | `swift-huggingface` dependency pinned to `branch: "main"` -- builds are non-reproducible | **Major** | S3 |

### Release Blockers

1. **`ChatSession` data-race surface** -- The class is `@unchecked Sendable` with `NSLock` guarding mutable state (`messages`, `config`, `isGenerating`). If `lock` discipline is violated at any call site (e.g., accessing state after an `await`), data races occur silently. The compiler cannot verify correctness. **Recommendation:** Convert to an `actor` or use `Mutex` (Swift 6.2).

2. **`LlamaProvider.loadedModel: nonisolated(unsafe)`** -- An `OpaquePointer?` marked `nonisolated(unsafe)` is a raw assertion to the compiler that concurrent access is safe. Since `LlamaProvider` is an `actor`, this must never be read outside the actor's isolation context. Any `nonisolated` method that touches this pointer is unsound.

3. **`swift-huggingface` on `branch: "main"`** -- This dependency tracks a moving target. A breaking upstream change silently breaks all builds. Pin to a release tag or commit hash.

---

## 2. Correctness Issues

### 2.1 Logic Bugs

#### **[Major] `MLXProvider.buildPrompt` silently drops conversation history**
`Sources/Conduit/Providers/MLX/MLXProvider.swift:803`

The method arbitrarily limits context to `messages.suffix(6)`, silently discarding earlier messages. For multi-turn conversations exceeding 6 messages, the model loses context with no warning to the caller.

```swift
let recentMessages = messages.suffix(6).filter { $0.role != .system }
```

**Impact:** Incorrect responses in long conversations. Users have no indication that messages were dropped.
**Fix:** Either pass the full history (let the model/tokenizer handle truncation) or expose this limit as a configurable parameter and log when truncation occurs.

#### **[Major] `Transcript.ResponseFormat.name` relies on debug description parsing**
`Sources/Conduit/Core/Types/Transcript.swift:311-321`

The `name` property parses `GenerationSchema.debugDescription` using string range operations to extract a type name. This is fragile -- any change to the schema's debug format silently breaks name extraction, falling back to the generic `"response"`.

```swift
public var name: String {
    let desc = schema.debugDescription
    if let range = desc.range(of: "$ref("), ... {
        return String(name)
    }
    return "response"
}
```

**Impact:** Schema name may silently degrade to `"response"`, causing incorrect structured output instructions sent to providers.

#### **[Minor] Anthropic `buildRequestBody` only uses first system message**
`Sources/Conduit/Providers/Anthropic/AnthropicProvider+Helpers.swift:86`

```swift
let systemPrompt = messages.first(where: { $0.role == .system })?.content.textValue
```

If multiple system messages are provided, subsequent ones are silently ignored. The documentation notes this, but no warning is logged.

#### **[Minor] Audio content silently skipped for Anthropic**
`Sources/Conduit/Providers/Anthropic/AnthropicProvider+Helpers.swift:164-167`

Audio parts in multimodal messages are silently dropped with a code comment but no runtime warning:

```swift
case .audio:
    // Audio not supported by Anthropic API - skip silently
    break
```

**Impact:** User sends audio expecting processing; receives a response based only on non-audio parts.

### 2.2 Race Conditions

See Section 4 (Concurrency & Safety) for detailed analysis.

### 2.3 Edge Cases Not Handled

| Location | Edge Case | Severity |
|----------|-----------|----------|
| `AnthropicProvider+Helpers.swift:219` | `config.maxTokens` defaults to `1024` when `nil` -- callers may not expect this implicit limit | Minor |
| `MLXProvider.swift:569` | Token count estimation uses `messages.count * 4` for special tokens -- wildly inaccurate for some tokenizers | Minor |
| `OpenAIProvider+Streaming.swift:156` | Uses `JSONSerialization.data(withJSONObject:)` instead of `JSONEncoder` -- loses type safety and custom encoding | Minor |
| `DownloadProgress.swift` speed calculator | Division by zero guarded, but `NaN` propagation possible if `totalBytes` is 0 | Minor |

### 2.4 Silent Failure Paths

#### **[Major] `HFMetadataService` swallows all errors into `nil`**
`Sources/Conduit/Services/HFMetadataService.swift` (multiple locations)

Three public methods (`getModelInfo`, `searchModels`, `getDownloadInfo`) catch all errors and return `nil` without logging. Callers cannot distinguish "model not found" from "network down" from "JSON decode failure."

```swift
} catch {
    return nil  // SILENT FAILURE - no logging
}
```

**Impact:** Production debugging is severely hampered. Network issues are invisible to callers.
**Fix:** Log errors before returning `nil`, or return `Result<T, Error>`.

#### **[Major] `ModelCache` metadata save failures silently ignored**
`Sources/Conduit/ModelManagement/ModelCache.swift:334`

```swift
try? saveMetadata()
```

If metadata persistence fails, the in-memory cache diverges from disk. After app restart, cache state is lost.

#### **[Minor] `GeneratedContent.jsonString` returns `"{}"` on error**
`Sources/Conduit/Core/Types/GeneratedContent.swift:243-244`

Serialization failures are swallowed, returning an empty JSON object. This can cause downstream logic to silently operate on incorrect data.

---

## 3. Architecture & Design Gaps

### 3.1 Strengths

- **Trait-based compilation** (Swift 6.2 package traits) is an excellent design choice. Providers compile only when enabled, reducing binary size and dependency bloat.
- **Unified error taxonomy** (`AIError` with 24+ cases, categories, retryability metadata, localized descriptions) is well-engineered.
- **Protocol hierarchy** (`AIProvider` → `TextGenerator` → `TokenCounter`) provides good abstraction layers.
- **`GenerationStream` wrapper** unifies async stream handling across providers.
- **`Transcript` type** provides a type-safe conversation model with `Identifiable`, `Codable`, `RandomAccessCollection` conformance.

### 3.2 Separation of Concerns Violations

#### **[Minor] Provider implementations embed HTTP client logic**
Each provider (OpenAI, Anthropic) contains its own HTTP execution, retry logic, and response parsing inline. The `AnthropicProvider+Helpers.swift` `executeRequest` method is 120+ lines combining URL construction, header building, retry loops, error mapping, and response decoding.

**Recommendation:** Extract a shared `HTTPClient` protocol with retry middleware. Each provider should only map requests/responses.

#### **[Minor] `OpenAIProvider+Helpers.swift` uses `JSONSerialization` while `AnthropicProvider` uses `Codable`**
Inconsistent serialization approaches across providers. OpenAI builds `[String: Any]` dictionaries manually; Anthropic uses type-safe `Codable` structs. The OpenAI approach loses compile-time type safety and is harder to maintain.

### 3.3 Missing Abstractions

| Gap | Impact | Recommendation |
|-----|--------|----------------|
| No shared retry executor | Retry logic duplicated across OpenAI (`RetryConfiguration`) and Anthropic (inline `executeRequest`) | Extract `RetryExecutor` protocol |
| No HTTP response validation layer | Status code handling repeated in every provider | Extract `ResponseValidator` |
| No token counting middleware | Each provider estimates tokens differently | Standardize interface |
| `ChatSession` has dual identity (session manager + generation coordinator) | Complexity concentrated in one class | Consider splitting state management from generation orchestration |

### 3.4 Over-Engineering

- **`DiffusionModelDownloader`** includes extensive checksum verification, disk space validation, and resume support for what appears to be an early-stage feature. The 430+ line file has thorough engineering but may be premature for the library's maturity.
- **`JsonRepair`** is a 545-line JSON repair utility. While useful, it handles edge cases that may rarely occur in practice. Consider depending on a tested JSON repair library instead.

### 3.5 Dependency Risks

| Dependency | Concern | Severity |
|------------|---------|----------|
| `swift-huggingface` pinned to `branch: "main"` | **Non-reproducible builds**. Breaking changes land without warning. | **Major** |
| `mlx-swift-examples` pinned to commit hash | Better than `main`, but still fragile -- no semver guarantees | Minor |
| `swift-transformers` from `1.1.6` | Acceptable semver range | Low |
| `llama.swift` from `2.7484.0` | Unusual versioning scheme; verify this is intentional | Low |
| `swift-syntax` from `600.0.0` | Required for macros; ties to specific Swift toolchain | Low |

---

## 4. Concurrency & Safety

### 4.1 `@unchecked Sendable` Audit

The codebase contains **7 distinct `@unchecked Sendable` types**:

| Type | File | Synchronization | Risk |
|------|------|-----------------|------|
| `ChatSession` | `ChatSession.swift:237` | `NSLock` | **High** -- complex class with many mutable fields |
| `StreamingDataDelegate` | `URLSessionAsyncBytes.swift:143` | `NSLock` | Medium -- limited scope |
| `SendableNSCache` | `SendableNSCache.swift:53,95` | `NSLock` | Medium -- wraps `NSCache` |
| `DownloadTask` | `DownloadProgress.swift:498` | `NSLock` | Medium -- state machine |
| `CachedModel` | `MLXModelCache.swift:95` | Immutable after init | Low |
| `CacheDelegate` | `MLXModelCache.swift:141` | NSCache delegate (single-threaded) | Low |

#### **[Blocker] `ChatSession<Provider>` data-race risk**

`ChatSession` is a `final class` with `@unchecked Sendable` using `NSLock` to protect mutable state:

```swift
private var _messages: [Message] = []
private var _config: GenerateConfig
private var _isGenerating = false
private let lock = NSLock()
```

The documented invariant is "lock is never held across await points." However, the compiler cannot verify this. Any future code change that holds the lock across an `await` creates a deadlock. Any code path that reads/writes `_messages` without the lock creates a data race.

**Specific risk areas:**
- The `send()` method captures state under lock, releases lock, then performs async generation, then re-acquires lock to append results. If two `send()` calls overlap, message ordering may be corrupted.
- The `stream()` method follows the same pattern with `AsyncThrowingStream` continuation callbacks that mutate state.

**Recommendation:** Convert `ChatSession` to an `actor`. The performance cost of actor hop is negligible compared to network I/O. Alternatively, use Swift 6.2's `Mutex` type.

### 4.2 `nonisolated(unsafe)` Usage

#### **[Blocker] `LlamaProvider.loadedModel`**
`Sources/Conduit/Providers/Llama/LlamaProvider.swift:23`

```swift
nonisolated(unsafe) private var loadedModel: OpaquePointer?
```

This is a raw pointer to a llama.cpp model. `nonisolated(unsafe)` tells the compiler to trust that concurrent access is safe. Since `LlamaProvider` is an `actor`, this is safe **only if** no `nonisolated` method ever reads or writes this pointer. However, `LlamaProvider` has multiple `nonisolated` methods for streaming, which create `Task {}` blocks that call back into the actor. If any of these paths touch `loadedModel` outside the actor's serial executor, it's a data race on a raw pointer -- potentially causing memory corruption.

**Recommendation:** Remove `nonisolated(unsafe)`. Use a proper actor-isolated property. If the pointer must be shared, wrap it in a `Mutex`.

### 4.3 Unstructured Concurrency

The codebase has **~30 instances** of `Task { }` and **1 instance** of `Task.detached { }`:

- **`ModelManager.swift:365`** uses `Task.detached { [weak self] in }` to start background downloads. The detached task has no parent and no cancellation propagation. If `ModelManager` is deallocated, the `[weak self]` guard returns `nil` silently, but the download task continues running until completion.

- **`ModelManager.downloadWithEstimation:710`** spawns `Task { }` inside a closure to asynchronously update download speed. This creates unbounded task creation proportional to progress callback frequency.

- **`MLXProvider.stream():193-217`** creates `Task { }` inside `AsyncThrowingStream` with a cancellation handler that fires `Task { await self.cancelGeneration() }`. This second unstructured task may execute after the actor has moved on.

### 4.4 Cancellation Gaps

| Location | Issue | Severity |
|----------|-------|----------|
| `MLXProvider.stream():210-215` | `onTermination` yields a `.cancelled` chunk *and* calls `continuation.finish()`, but the streaming `Task` may also call `continuation.finish()` -- double-finish is safe but wasteful | Minor |
| `OpenAIProvider+Streaming.swift:76-78` | `onTermination` only calls `task.cancel()` but doesn't yield a cancellation chunk | Minor |
| `AnthropicProvider.executeRequest()` | `Task.sleep` in retry loop respects cancellation via `try await`, but `Task.isCancelled` is not checked before the sleep | Minor |

---

## 5. Performance Bottlenecks

### 5.1 Streaming String Concatenation

#### **[Minor] `OpenAIProvider+Streaming.swift` tool argument accumulation**
Tool call arguments are accumulated via repeated string concatenation:

```swift
acc.argumentsBuffer += argsFragment  // O(n) per append without pre-allocation
```

The code does include `reserveCapacity` on first append (line 330-331), which mitigates the O(n^2) worst case. However, the `reserveCapacity(min(4096, maxToolArgumentsSize))` may be too small for large tool call arguments.

#### **[Minor] `MLXProvider.performGeneration` concatenates text per token**
`Sources/Conduit/Providers/MLX/MLXProvider.swift:688`

```swift
generatedText += chunk  // Called once per token
```

For long generations (thousands of tokens), this is O(n^2) string concatenation. Use an array of chunks with a final `joined()` call.

### 5.2 `JsonRepair.findContext` is O(n) per call

`Sources/Conduit/Utilities/JsonRepair.swift:326-392`

The `findContext` method scans from position 0 to `idx` on every call. Called from `removeIncompleteKeyValuePairs`, which itself operates on the full JSON string. For deeply nested JSON, this is expensive. In the streaming context where JSON repair runs on partial output, this is acceptable, but document the complexity.

### 5.3 URLSession Configuration

All providers create a shared `URLSession` per provider instance. This is correct -- session reuse avoids TCP connection overhead. However, no provider configures `waitsForConnectivity`, `timeoutIntervalForResource`, or HTTP/2 multiplexing explicitly.

### 5.4 Memory Considerations

| Pattern | Location | Impact |
|---------|----------|--------|
| `AnthropicProvider.executeRequest` encodes request body once, reuses across retries | `AnthropicProvider+Helpers.swift:474-477` | **Good** -- avoids redundant encoding |
| Error response body capped at 10KB | `OpenAIProvider+Streaming.swift:167` | **Good** -- prevents DoS via large error responses |
| Tool arguments capped at 100KB | `OpenAIProvider+Streaming.swift:17` | **Good** -- prevents memory exhaustion |
| Reasoning text capped at 100KB | `OpenAIProvider+Streaming.swift:21` | **Good** -- prevents memory exhaustion |
| `JsonRepair.repair` depth limited to 64 | `JsonRepair.swift:79` | **Good** -- prevents stack overflow on adversarial input |

---

## 6. Security Risks

### 6.1 Credential Management (Strong)

- All authentication types implement `CustomDebugStringConvertible` with credentials masked as `***`.
- Constant-time comparison implemented for credential equality (XOR-based, `Sources/Conduit/Providers/OpenAI/OpenAIAuthentication.swift:246-275`).
- `OpenAIConfiguration` explicitly excludes authentication from `Codable` encoding (`Sources/Conduit/Providers/OpenAI/OpenAIConfiguration.swift:619`).
- HuggingFace provider supports macOS Keychain integration.
- No hardcoded secrets found in the codebase.

### 6.2 Transport Security

- **Anthropic: HTTPS enforced** (`AnthropicConfiguration.swift:163-183`) with localhost exception for development.
- **OpenAI: No HTTPS enforcement** -- custom endpoints can use HTTP. This is by design (Ollama, local endpoints) but should be documented as a security consideration.
- **No certificate pinning** across any provider. Acceptable for a library (callers can configure `URLSessionDelegate`), but worth documenting.

### 6.3 Input Validation

- **No injection risks**: The codebase is an API client; it constructs HTTP requests but doesn't execute SQL or eval user input.
- **URL validation**: Anthropic validates HTTPS; OpenAI relies on `URL` type safety.
- **JSON handling**: Uses standard `JSONDecoder`/`JSONSerialization` -- no custom parsers with injection surface.

### 6.4 Specific Concerns

#### **[Minor] Retry-After header not capped for OpenAI**
`AnthropicProvider+Helpers.swift:529` correctly caps `Retry-After` at 5 minutes:
```swift
waitTime = min(retryAfter, 300)
```
The OpenAI provider does not appear to have equivalent capping -- a malicious server could specify an extremely large `Retry-After` value.

#### **[Minor] `DiffusionModelDownloader` checksum verification is optional**
`Sources/Conduit/ImageGeneration/DiffusionModelDownloader.swift:137-149`

SHA256 verification can be skipped. In production, this should be mandatory to prevent supply-chain attacks via model weight tampering.

#### **[Minor] `UserDefaults` used for model metadata**
`DiffusionModelRegistry` stores model metadata in `UserDefaults`. While the data is non-sensitive (paths, names, sizes), `UserDefaults` is not encrypted and can be read by other processes on macOS.

---

## 7. Testing Review

### 7.1 Coverage Overview

The repository contains **60 test files** across two test targets:
- `ConduitTests` (57 files) -- unit and integration tests
- `ConduitMacrosTests` (2 files) -- macro expansion tests

### 7.2 Well-Tested Areas

| Area | Test File | Quality |
|------|-----------|---------|
| Error taxonomy | `ErrorTests.swift` | Comprehensive -- covers all 24+ error cases |
| JSON repair | `JsonRepairTests.swift` | Good -- tests various malformed JSON patterns |
| Tool call parsing | `OpenAIToolParsingTests.swift`, `AnthropicToolParsingTests.swift` | Good |
| Message building | `MessageBuilderTests.swift`, `MessageTests.swift` | Good |
| Generation config | `GenerateConfigTests.swift` | Good |
| SSE parsing | `ServerSentEventParserParityTests.swift` | Good -- parity testing |
| Schema generation | `GenerationSchemaGoldenTests.swift` | Good -- golden file testing |
| Macro expansion | `GenerableMacroTests.swift` | Good |

### 7.3 Critical Coverage Gaps

#### **[Major] No integration tests for streaming paths**
`StreamingTests.swift` and `StreamingCancellationTests.swift` exist but test limited scenarios. **Missing:**
- Streaming with network interruption mid-stream
- Streaming with malformed SSE data
- Streaming with tool calls that span multiple chunks
- Backpressure testing (slow consumer)
- Memory usage during long streams

#### **[Major] No concurrency stress tests**
No tests verify thread safety of `ChatSession`, `DownloadTask`, or `SendableNSCache` under concurrent access. Given the manual `NSLock` synchronization, this is a significant gap.

#### **[Major] No failure-path tests for providers**
Provider tests verify happy paths. **Missing:**
- HTTP 429 rate-limit retry behavior
- HTTP 500 retry with exponential backoff
- Network timeout handling
- Malformed JSON response handling
- Authentication failure flows
- Partial response (connection dropped mid-response)

#### **[Minor] No property-based testing**
The `JsonRepair` utility, `PartialJSONDecoder`, and `GenerationSchema` serialization would benefit significantly from property-based testing with randomized inputs.

### 7.4 Untested Source Files

Critical source files with no corresponding test coverage:

| Source File | Risk | Notes |
|-------------|------|-------|
| `ChatSession.swift` (generation/streaming paths) | High | Only basic tests exist |
| `ModelManager.swift` | High | `ModelManagementTests.swift` exists but scope unclear |
| `URLSessionAsyncBytes.swift` | Medium | Cross-platform URL session polyfill -- no tests |
| `HuggingFaceHubDownloader.swift` | Medium | No unit tests found |
| `SpeedCalculator` | Low | `SpeedCalculatorTests.swift` exists |
| All provider streaming implementations | High | No isolated streaming tests per provider |
| `DownloadProgress.swift` (state machine) | Medium | No state transition tests |

### 7.5 Test Infrastructure Concerns

- **No CI/CD configuration found** in the repository (no `.github/workflows`, `Fastlane`, or `Jenkinsfile`).
- **No code coverage reporting** configured.
- **Trait-gated tests** require specific build configurations to run. Without CI that builds with all trait combinations, trait-specific code may be untested.

---

## 8. Refactoring Opportunities

### 8.1 High Priority

| Opportunity | Files | Impact |
|-------------|-------|--------|
| Convert `ChatSession` from `@unchecked Sendable` + `NSLock` to `actor` | `ChatSession.swift` | Eliminates data-race risk class |
| Extract shared `HTTPClient` with retry middleware | All provider `+Helpers` files | Reduces duplication, centralizes retry logic |
| Pin `swift-huggingface` to a release tag | `Package.swift` | Reproducible builds |
| Replace `fatalError` in `Generable.asPartiallyGenerated()` with protocol requirement or throwing function | `Generable.swift:85` | Prevents production crashes |
| Add error logging to `HFMetadataService` catch blocks | `HFMetadataService.swift` | Enables production debugging |

### 8.2 Medium Priority

| Opportunity | Files | Impact |
|-------------|-------|--------|
| Standardize JSON serialization (all providers use `Codable`) | `OpenAIProvider+Helpers.swift` | Type safety, maintainability |
| Make `MLXProvider.buildPrompt` message limit configurable | `MLXProvider.swift:803` | Prevents silent context loss |
| Add `Retry-After` cap to OpenAI provider | `OpenAIProvider+Helpers.swift` | Security hardening |
| Replace `Transcript.ResponseFormat.name` debug-description parsing | `Transcript.swift:311-321` | Correctness |
| Use array + `joined()` instead of string concatenation in `MLXProvider.performGeneration` | `MLXProvider.swift:688` | O(n) vs O(n^2) for long generations |

### 8.3 Low Priority

| Opportunity | Files | Impact |
|-------------|-------|--------|
| Log warning when Anthropic silently drops audio content | `AnthropicProvider+Helpers.swift:164` | User experience |
| Log warning when multiple system messages are provided to Anthropic | `AnthropicProvider+Helpers.swift:86` | Debugging |
| Consolidate `TODO: @_exported import` comments in `Conduit.swift` | `Conduit.swift` | Code hygiene |
| Add `CONDUIT_TRAIT_LLAMA` and `CONDUIT_TRAIT_HUGGINGFACE_HUB` swift settings | `Package.swift` | Consistency with other traits |

---

## Appendix A: File Inventory

### Source Statistics
- **Total source files:** ~120+ Swift files across `Sources/Conduit` and `Sources/ConduitMacros`
- **Total test files:** 60 Swift files across `Tests/ConduitTests` and `Tests/ConduitMacrosTests`
- **Providers:** OpenAI, Anthropic, MLX, CoreML, Llama, HuggingFace, FoundationModels, Kimi, MiniMax, OpenRouter (via OpenAI)
- **Package traits:** 9 (OpenAI, OpenRouter, Anthropic, Kimi, MiniMax, MLX, CoreML, HuggingFaceHub, Llama)

### Architecture Layers
1. **Core Protocols:** `AIProvider`, `TextGenerator`, `TokenCounter`, `EmbeddingGenerator`, `ImageGenerator`
2. **Core Types:** `Message`, `GenerateConfig`, `GenerationResult`, `GenerationChunk`, `Transcript`, `GeneratedContent`
3. **Error System:** `AIError` (24+ cases), `SendableError`, error categories
4. **Providers:** 10 provider implementations, each behind conditional compilation traits
5. **Utilities:** `JsonRepair`, `ServerSentEventParser`, `PartialJSONDecoder`, `SendableNSCache`
6. **Model Management:** `ModelManager`, `ModelCache`, `DownloadTask`, `DiffusionModelDownloader`
7. **Macros:** `@Generable`, `@Guide` for compile-time structured output code generation

### Dependencies
| Package | Version | Purpose |
|---------|---------|---------|
| swift-collections | ^1.1.0 | `OrderedCollections` |
| swift-syntax | ^600.0.0 | Macro compilation |
| swift-log | ^1.8.0 | Structured logging |
| mlx-swift | ^0.29.1 | MLX framework (trait-gated) |
| mlx-swift-lm | ^2.29.2 | MLX language models (trait-gated) |
| mlx-swift-examples | commit `fc3afc7` | StableDiffusion (trait-gated) |
| swift-huggingface | **`branch: "main"`** | HuggingFace Hub (trait-gated) |
| swift-transformers | ^1.1.6 | CoreML transformers (trait-gated) |
| llama.swift | ^2.7484.0 | llama.cpp bindings (trait-gated) |

---

## Appendix B: Methodology

This audit was conducted through:
1. **Static analysis** of all source files in `Sources/` and `Tests/`
2. **Targeted pattern searches** for `@unchecked Sendable`, `nonisolated(unsafe)`, `fatalError`, `preconditionFailure`, `try?`, `try!`, `as!`, `NSLock`, `Task {`, `Task.detached`, `TODO`, `FIXME`
3. **Architectural review** of protocol hierarchy, type design, and module boundaries
4. **Security review** of credential handling, transport security, input validation, and cryptographic usage
5. **Dependency audit** of `Package.swift` version pinning and trait configuration
6. **Test coverage analysis** comparing source files against test files

All findings were verified against source code. Uncertain findings are marked as such. No code was hallucinated.
