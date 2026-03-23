# Conduit API Redesign: Local-First Implementation

## TL;DR

> **Quick Summary**: Restructure the Conduit SDK to eliminate type duplication between ConduitAdvanced and ConduitFacade, split GenerateConfig and AIError into domain-specific types, and reorder enums/factories to local-first for better autocomplete ergonomics.
>
> **Deliverables**:
> - ConduitFacade re-exports ConduitAdvanced types via typealias (no duplicates)
> - GenerateConfig split into LocalGenerateConfig + CloudGenerateConfig
> - AIError split into AIError (core) + CloudError + ResourceError + ToolError
> - Model.Family and Provider factories reordered local-first
>
> **Estimated Effort**: Large
> **Parallel Execution**: YES - 5 waves
> **Critical Path**: Task 1 → Task 3 → Task 7 → Task 11 → Task 15

---

## Context

### Original Request
User provided a 5-phase plan for Conduit API restructuring with specific implementation steps for each phase. Key decisions: protocol-based GenerateConfig separation, AIError domain split, local-first ordering.

### Interview Summary
**Key Discussions**:
- ConduitFacade (Sources/ConduitFacade/) is the public facade; ConduitAdvanced (Sources/Conduit/) is the implementation
- Package.swift is correct — no changes needed
- Tests all import `@testable import ConduitAdvanced` — no facade-level tests exist
- GenerateConfig has 22 properties (not 18 as stated in spec)
- AIError has 25 cases with 171 throw sites across 26 files

**Research Findings**:
- `frequencyPenalty`/`presencePenalty` used by LlamaProvider (LOCAL) AND OpenAI/HuggingFace (cloud) — spec says "cloud-only" but reality is mixed
- `userId`/`serviceTier` only used by AnthropicProvider (cloud) + ResultBuilders
- `runtimeFeatures`/`runtimePolicyOverride` only used by MLX (local)
- `returnLogprobs`/`topLogprobs` used by OpenAI streaming + ResultBuilders
- ErrorTests.swift validates ALL AIError cases by exact name — splitting cases to new enums breaks tests
- GenerateConfigTests.swift tests all properties including frequencyPenalty/presencePenalty

### Metis Review
Metis consultation failed (agent error). Self-analysis performed instead.
**Identified Risks**:
- Phase 2: frequencyPenalty/presencePenalty categorization as "cloud-only" is incorrect per codebase
- Phase 3: 171 throw sites need updating; ErrorTests.swift has hard-coded case names
- Phase 2 & 3 have highest blast radius — execute after Phase 1 stabilizes

---

## Work Objectives

### Core Objective
Eliminate type duplication between ConduitAdvanced and ConduitFacade, restructure GenerateConfig and AIError for clearer domain boundaries, and establish local-first ordering for better developer ergonomics.

### Concrete Deliverables
- ConduitFacade.swift with typealias re-exports (no duplicate Model/Provider/Session/Conduit)
- LocalGenerateConfig + CloudGenerateConfig structs composed into GenerateConfig
- CloudError, ResourceError, ToolError enums extracted from AIError
- Model.Family enum reordered with local providers first
- Provider factory methods reordered with MARK comments

### Definition of Done
- [ ] `swift build` passes after each phase
- [ ] `swift test` passes after each phase (or pre-existing failures documented)
- [ ] No duplicate type definitions between ConduitAdvanced and ConduitFacade
- [ ] All existing fluent API calls still work (.temperature(0.8), etc.)

### Must Have
- ConduitFacade re-exports from ConduitAdvanced (no type duplication)
- GenerateConfig backward compatibility via forwarded accessors
- AIError backward compatibility via typealiases in facade
- Local-first ordering in Model.Family and Provider factories

### Must NOT Have (Guardrails)
- No changes to Package.swift
- No new test infrastructure
- No breaking changes to existing public API signatures
- No removal of existing AIError cases (only reorganization)
- No modification of test imports (still `@testable import ConduitAdvanced`)

---

## Verification Strategy (MANDATORY)

> **ZERO HUMAN INTERVENTION** — ALL verification is agent-executed.

### Test Decision
- **Infrastructure exists**: YES (XCTest)
- **Automated tests**: Tests-after (existing tests validate behavior)
- **Framework**: XCTest
- **TDD**: No — existing tests are the acceptance criteria

### QA Policy
After EACH phase:
- `swift build` must pass
- `swift test` must pass (or pre-existing failures documented)
- LSP diagnostics must be clean
- Evidence: terminal output of build/test

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately — safe reorderings):
├── Task 1: Model.Family reorder (local-first) [quick]
├── Task 2: Provider factory reorder (local-first) [quick]

Wave 2 (After Wave 1 — type deduplication):
├── Task 3: Audit duplicate types between ConduitAPI.swift and ConduitFacade.swift [deep]
├── Task 4: Replace facade Model with typealias to ConduitAdvanced.Model [unspecified-high]
├── Task 5: Replace facade ToolSetBuilder with typealias [quick]

Wave 3 (After Wave 2 — GenerateConfig split):
├── Task 6: Create LocalGenerateConfig struct [deep]
├── Task 7: Create CloudGenerateConfig struct [deep]
├── Task 8: Refactor GenerateConfig to compose LocalGenerateConfig + CloudGenerateConfig [ultrabrain]
├── Task 9: Update providers to read from config.local.* and config.cloud.* [unspecified-high]
├── Task 10: Update GenerateConfigTests for new structure [unspecified-high]

Wave 4 (After Wave 3 — AIError split):
├── Task 11: Create CloudError enum with cloud-specific cases [deep]
├── Task 12: Create ResourceError enum with resource cases [deep]
├── Task 13: Create ToolError enum with tool cases [quick]
├── Task 14: Refactor AIError to core cases + re-exports [ultrabrain]
├── Task 15: Update providers to throw appropriate error types [unspecified-high]
├── Task 16: Update ErrorTests for new error structure [unspecified-high]

Wave 5 (After Wave 4 — integration verification):
├── Task 17: Full build + test verification [quick]
├── Task 18: Facade typealias verification [deep]
└── Task 19: Update DocumentationExamplesTests if needed [quick]
```

### Dependency Matrix
- **1**: None → Wave 1
- **2**: None → Wave 1
- **3**: None → Wave 2
- **4**: 3 → Wave 2
- **5**: 3 → Wave 2
- **6**: None → Wave 3
- **7**: None → Wave 3
- **8**: 6, 7 → Wave 3
- **9**: 8 → Wave 3
- **10**: 8 → Wave 3
- **11**: None → Wave 4
- **12**: None → Wave 4
- **13**: None → Wave 4
- **14**: 11, 12, 13 → Wave 4
- **15**: 14 → Wave 4
- **16**: 14 → Wave 4
- **17**: 4, 5, 9, 10, 15, 16 → Wave 5
- **18**: 4, 5 → Wave 5
- **19**: 9, 15 → Wave 5

### Agent Dispatch Summary
- **Wave 1**: 2 tasks — T1→quick, T2→quick
- **Wave 2**: 3 tasks — T3→deep, T4→unspecified-high, T5→quick
- **Wave 3**: 5 tasks — T6→deep, T7→deep, T8→ultrabrain, T9→unspecified-high, T10→unspecified-high
- **Wave 4**: 6 tasks — T11→deep, T12→deep, T13→quick, T14→ultrabrain, T15→unspecified-high, T16→unspecified-high
- **Wave 5**: 3 tasks — T17→quick, T18→deep, T19→quick

---

## TODOs

- [ ] 1. Reorder Model.Family enum to local-first

  **What to do**:
  - Open `Sources/Conduit/ConduitAPI.swift` (line 15-27)
  - Reorder Family enum cases: local providers first (mlx, mlxLocal, llama, coreML, foundationModels), then cloud (openAI, anthropic, huggingFace, kimi, miniMax), then custom
  - Add `// MARK: - Local Providers (Primary)` and `// MARK: - Cloud Providers (Fallback)` comments
  - Open `Sources/ConduitFacade/ConduitFacade.swift` (line 17-29) — apply same reorder to facade's Family enum

  **Must NOT do**:
  - Do not add or remove enum cases
  - Do not change raw values
  - Do not modify any other code in these files

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple reorder, no logic changes
  - **Skills**: []
    - No special skills needed

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Task 2)
  - **Blocks**: None
  - **Blocked By**: None (can start immediately)

  **References**:
  **Pattern References**:
  - `Sources/Conduit/ConduitAPI.swift:15-27` — Current Family enum definition (alphabetical order)
  - `Sources/ConduitFacade/ConduitFacade.swift:17-29` — Duplicate Family enum in facade (same order)

  **Acceptance Criteria**:
  - [ ] Family enum in ConduitAPI.swift has local-first order
  - [ ] Family enum in ConduitFacade.swift has same local-first order
  - [ ] `swift build` passes

  **QA Scenarios**:

  ```
  Scenario: Family.allCases returns local-first order
    Tool: Bash (swift)
    Preconditions: None
    Steps:
      1. Run: swift test --filter GenerateConfigTests 2>&1 | head -5
      2. Verify build succeeds without Family-related errors
    Expected Result: Build succeeds, no compilation errors from Family reorder
    Failure Indicators: Compile error about missing cases or wrong order
    Evidence: .sisyphus/evidence/task-1-family-reorder.log
  ```

  **Commit**: YES (grouped with Wave 1)
  - Message: `refactor(api): reorder Model.Family to local-first`
  - Files: Sources/Conduit/ConduitAPI.swift, Sources/ConduitFacade/ConduitFacade.swift

---

- [ ] 2. Reorder Provider factory methods to local-first

  **What to do**:
  - Open `Sources/Conduit/ConduitAPI.swift` — `extension Provider` (line 296-456)
  - Reorder factory methods: local first (mlx, huggingFace), then cloud (openAI, openRouter, anthropic), then niche (kimi, miniMax), then custom
  - Add `// MARK: - Local (Primary)`, `// MARK: - Cloud (Fallback)`, `// MARK: - Advanced` comments
  - Open `Sources/ConduitFacade/ConduitFacade.swift` — Provider extension (line 160-363) — apply same reorder

  **Must NOT do**:
  - Do not modify method signatures or implementations
  - Do not change conditional compilation guards

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Reorder only, no logic changes
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Task 1)
  - **Blocks**: None
  - **Blocked By**: None

  **References**:
  **Pattern References**:
  - `Sources/Conduit/ConduitAPI.swift:296-456` — Provider factory methods in ConduitAdvanced
  - `Sources/ConduitFacade/ConduitFacade.swift:160-363` — Provider factory methods in facade

  **Acceptance Criteria**:
  - [ ] Provider factories in ConduitAPI.swift appear in local-first order
  - [ ] Provider factories in ConduitFacade.swift appear in local-first order
  - [ ] MARK comments clearly delineate sections
  - [ ] `swift build` passes

  **QA Scenarios**:

  ```
  Scenario: Build succeeds with reordered providers
    Tool: Bash (swift)
    Preconditions: None
    Steps:
      1. Run: swift build 2>&1
      2. Verify BUILD SUCCEEDED
    Expected Result: Build succeeds
    Failure Indicators: Compile error
    Evidence: .sisyphus/evidence/task-2-provider-reorder.log
  ```

  **Commit**: YES (grouped with Wave 1)
  - Message: `refactor(api): reorder Provider factories to local-first`

---

- [ ] 3. Audit duplicate types between ConduitAPI.swift and ConduitFacade.swift

  **What to do**:
  - Read `Sources/Conduit/ConduitAPI.swift` fully
  - Read `Sources/ConduitFacade/ConduitFacade.swift` fully
  - Create a mapping table: every type defined in both files, noting differences
  - Identify which types are exact duplicates vs. facade-specific wrappers
  - Expected findings: Model (duplicate), Model.Family (duplicate), ToolSetBuilder (duplicate), Provider (facade wrapper), Session (facade wrapper), Conduit (facade wrapper)
  - Document the audit results as a comment block or in a separate analysis note

  **Must NOT do**:
  - Do not modify any source files
  - This is a READ-ONLY analysis task

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Thorough analysis needed to avoid breaking changes
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 2
  - **Blocks**: Tasks 4, 5
  - **Blocked By**: None

  **References**:
  **Pattern References**:
  - `Sources/Conduit/ConduitAPI.swift` — ConduitAdvanced type definitions
  - `Sources/ConduitFacade/ConduitFacade.swift` — Facade type definitions

  **Acceptance Criteria**:
  - [ ] Audit document produced with complete type mapping
  - [ ] Each type classified as: exact-duplicate, facade-wrapper, or facade-only

  **QA Scenarios**: None (analysis only)

  **Commit**: NO (analysis task)

---

- [ ] 4. Replace facade Model with typealias to ConduitAdvanced.Model

  **What to do**:
  - In `Sources/ConduitFacade/ConduitFacade.swift`:
    - Remove the duplicate `Model` struct (lines 16-54)
    - Remove the `extension Model` with `fileprivate init(_ raw:)` and `fileprivate var raw` (lines 56-77)
    - Add `public typealias Model = ConduitAdvanced.Model`
    - If ConduitAdvanced.Model doesn't have all the static factory methods (openAI, anthropic, mlx, etc.), add them to ConduitAdvanced.Model first
  - Update any code in ConduitFacade that used `Model(...)` or `model.raw` to work with the shared type
  - The `Provider.custom` factory (line 346-362) uses `Model(advancedModel)` and `mapModel(Model(advancedModel))` — these converters become identity operations since types are now shared

  **Must NOT do**:
  - Do not change ConduitAdvanced's Model definition unless adding missing factory methods
  - Do not change any public API signatures visible to Conduit users

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Moderate complexity — need to verify no breakage in facade wiring
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 2
  - **Blocks**: Wave 5 verification
  - **Blocked By**: Task 3

  **References**:
  **Pattern References**:
  - `Sources/ConduitFacade/ConduitFacade.swift:16-77` — Duplicate Model + raw converters
  - `Sources/Conduit/ConduitAPI.swift:14-100` — Original Model definition with Family and ModelIdentifier bridge

  **API/Type References**:
  - `Sources/Conduit/ConduitAPI.swift:14` — `public struct Model: Sendable, Hashable, Codable, ExpressibleByStringLiteral`
  - `Sources/Conduit/ConduitAPI.swift:54-100` — `extension Model` with `init(_ identifier: ModelIdentifier)` and `asModelIdentifier`

  **Acceptance Criteria**:
  - [ ] Facade has `public typealias Model = ConduitAdvanced.Model` (no duplicate struct)
  - [ ] No `fileprivate init(_ raw:)` or `fileprivate var raw` converters remain for Model
  - [ ] `swift build` passes
  - [ ] `swift test` passes

  **QA Scenarios**:

  ```
  Scenario: Facade re-exports Model from ConduitAdvanced
    Tool: Bash (swift)
    Preconditions: None
    Steps:
      1. Run: swift build 2>&1
      2. Verify BUILD SUCCEEDED
      3. Grep for "public typealias Model" in ConduitFacade.swift
    Expected Result: Build succeeds, typealias exists
    Failure Indicators: Compile error, duplicate type definition
    Evidence: .sisyphus/evidence/task-4-model-typealias.log

  Scenario: Tests still pass after Model deduplication
    Tool: Bash (swift)
    Preconditions: Build succeeds
    Steps:
      1. Run: swift test 2>&1 | tail -20
      2. Verify test results
    Expected Result: Tests pass (same as baseline)
    Failure Indicators: New test failures related to Model
    Evidence: .sisyphus/evidence/task-4-tests.log
  ```

  **Commit**: YES (grouped with Wave 2)
  - Message: `refactor(api): replace facade Model with typealias to ConduitAdvanced.Model`

---

- [ ] 5. Replace facade ToolSetBuilder with typealias

  **What to do**:
  - In `Sources/ConduitFacade/ConduitFacade.swift`:
    - Remove the duplicate `ToolSetBuilder` result builder (lines 127-156)
    - Add `public typealias ToolSetBuilder = ConduitAdvanced.ToolSetBuilder`
    - ConduitAdvanced's ToolSetBuilder (ConduitAPI.swift line 105-134) uses `any Tool` while facade uses `AnyTool = any ConduitAdvanced.Tool` — verify these are equivalent
  - If ConduitAdvanced's ToolSetBuilder doesn't match facade's signature exactly, keep the facade's version instead of typealias

  **Must NOT do**:
  - Do not break any existing call sites that use @ToolSetBuilder

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple replacement if signatures match
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 2
  - **Blocks**: Wave 5 verification
  - **Blocked By**: Task 3

  **References**:
  **Pattern References**:
  - `Sources/ConduitFacade/ConduitFacade.swift:127-156` — Facade ToolSetBuilder using `AnyTool`
  - `Sources/Conduit/ConduitAPI.swift:105-134` — ConduitAdvanced ToolSetBuilder using `any Tool`

  **Acceptance Criteria**:
  - [ ] No duplicate ToolSetBuilder definition in facade
  - [ ] Either typealias or documented reason for keeping facade version
  - [ ] `swift build` passes

  **QA Scenarios**:

  ```
  Scenario: ToolSetBuilder deduplication compiles
    Tool: Bash (swift)
    Preconditions: None
    Steps:
      1. Run: swift build 2>&1
      2. Verify BUILD SUCCEEDED
    Expected Result: Build succeeds
    Failure Indicators: Result builder conformance error
    Evidence: .sisyphus/evidence/task-5-toolsetbuilder.log
  ```

  **Commit**: YES (grouped with Wave 2)

---

- [ ] 6. Create LocalGenerateConfig struct

  **What to do**:
  - In `Sources/Conduit/Core/Types/GenerateConfig.swift`:
    - Add new `LocalGenerateConfig` struct BEFORE the existing `GenerateConfig`
    - Properties (core — used by ALL providers):
      - `maxTokens: Int?`
      - `minTokens: Int?`
      - `temperature: Float`
      - `topP: Float`
      - `topK: Int?`
      - `repetitionPenalty: Float`
      - `stopSequences: [String]`
      - `seed: UInt64?`
      - `returnLogprobs: Bool`
      - `topLogprobs: Int?`
      - `tools: [Transcript.ToolDefinition]`
      - `toolChoice: ToolChoice`
      - `parallelToolCalls: Bool?`
      - `maxToolCalls: Int?`
      - `runtimeFeatures: ProviderRuntimeFeatureConfiguration?`
      - `runtimePolicyOverride: ProviderRuntimePolicyOverride?`
    - Conform to `Sendable, Codable`
    - Provide `init` with all defaults matching current GenerateConfig defaults
    - Provide `static let default`

  **Must NOT do**:
  - Do not modify existing GenerateConfig yet (that's Task 8)
  - Do not add fluent API methods yet

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Must correctly categorize properties as "local" vs "cloud"
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Task 7)
  - **Blocks**: Task 8
  - **Blocked By**: None

  **References**:
  **Pattern References**:
  - `Sources/Conduit/Core/Types/GenerateConfig.swift:44-332` — Current GenerateConfig with all properties

  **Acceptance Criteria**:
  - [ ] LocalGenerateConfig compiles with all 16 properties
  - [ ] Default values match current GenerateConfig defaults
  - [ ] `swift build` passes (GenerateConfig unchanged at this point)

  **QA Scenarios**:

  ```
  Scenario: LocalGenerateConfig compiles with correct defaults
    Tool: Bash (swift)
    Preconditions: None
    Steps:
      1. Run: swift build 2>&1
      2. Verify BUILD SUCCEEDED
    Expected Result: Build succeeds with new struct available
    Failure Indicators: Compile error
    Evidence: .sisyphus/evidence/task-6-localconfig.log
  ```

  **Commit**: YES (grouped with Wave 3)

---

- [ ] 7. Create CloudGenerateConfig struct

  **What to do**:
  - In `Sources/Conduit/Core/Types/GenerateConfig.swift`:
    - Add new `CloudGenerateConfig` struct
    - Properties (cloud-specific — NOT used by local providers):
      - `frequencyPenalty: Float` (default 0.0)
      - `presencePenalty: Float` (default 0.0)
      - `userId: String?` (default nil)
      - `serviceTier: ServiceTier?` (default nil)
      - `reasoning: ReasoningConfig?` (default nil)
      - `responseFormat: ResponseFormat?` (default nil)
    - Conform to `Sendable, Codable`
    - Provide `init` with all defaults
    - Provide `static let default`

  **Must NOT do**:
  - Do not modify existing GenerateConfig yet
  - NOTE: frequencyPenalty/presencePenalty are ALSO used by LlamaProvider — document this as accepted trade-off

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Property categorization has cross-cutting implications
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Task 6)
  - **Blocks**: Task 8
  - **Blocked By**: None

  **References**:
  **Pattern References**:
  - `Sources/Conduit/Core/Types/GenerateConfig.swift:107-239` — Properties being moved to cloud config
  - `Sources/Conduit/Providers/Llama/LlamaProvider.swift:519-537` — LlamaProvider uses frequencyPenalty/presencePenalty (MIXED usage)

  **Acceptance Criteria**:
  - [ ] CloudGenerateConfig compiles with all 6 properties
  - [ ] Default values match current GenerateConfig defaults
  - [ ] `swift build` passes

  **QA Scenarios**:

  ```
  Scenario: CloudGenerateConfig compiles
    Tool: Bash (swift)
    Preconditions: None
    Steps:
      1. Run: swift build 2>&1
    Expected Result: BUILD SUCCEEDED
    Failure Indicators: Compile error
    Evidence: .sisyphus/evidence/task-7-cloudconfig.log
  ```

  **Commit**: YES (grouped with Wave 3)

---

- [ ] 8. Refactor GenerateConfig to compose LocalGenerateConfig + CloudGenerateConfig

  **What to do**:
  - In `Sources/Conduit/Core/Types/GenerateConfig.swift`:
    - Replace all individual properties with two composed properties:
      - `public var local: LocalGenerateConfig`
      - `public var cloud: CloudGenerateConfig`
    - Add forwarded computed properties for backward compatibility (all 22 existing properties):
      - `var maxTokens: Int? { get { local.maxTokens } set { local.maxTokens = newValue } }`
      - (repeat for ALL properties, routing to local.* or cloud.* as appropriate)
    - Update `init` to accept all existing parameters, routing them to local/cloud
    - Update `static let default`, `.creative`, `.precise`, `.code` presets
    - Update all fluent API methods to modify local.* or cloud.* as appropriate
    - Update the `init(options:responseFormat:base:)` bridge
    - Ensure Codable encoding/decoding still works (custom Codable if needed)

  **Must NOT do**:
  - Do NOT break any existing public API — all fluent methods must still work
  - Do NOT change any property names or types

  **Recommended Agent Profile**:
  - **Category**: `ultrabrain`
    - Reason: Complex refactoring with backward compatibility constraints
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 3
  - **Blocks**: Tasks 9, 10
  - **Blocked By**: Tasks 6, 7

  **References**:
  **Pattern References**:
  - `Sources/Conduit/Core/Types/GenerateConfig.swift:44-816` — Entire GenerateConfig to refactor

  **Acceptance Criteria**:
  - [ ] GenerateConfig has `local: LocalGenerateConfig` and `cloud: CloudGenerateConfig` properties
  - [ ] All 22 existing properties still accessible as forwarded computed properties
  - [ ] All fluent API methods (.temperature(), .maxTokens(), etc.) still work
  - [ ] Presets (.default, .creative, .precise, .code) still work
  - [ ] Codable round-trip works (test via existing GenerateConfigTests)
  - [ ] `swift build` passes
  - [ ] `swift test --filter GenerateConfigTests` passes

  **QA Scenarios**:

  ```
  Scenario: GenerateConfig backward compatibility
    Tool: Bash (swift)
    Preconditions: None
    Steps:
      1. Run: swift test --filter GenerateConfigTests 2>&1
      2. Verify all tests pass
    Expected Result: All GenerateConfigTests pass
    Failure Indicators: Test failures in fluent API, clamping, presets, or Codable
    Evidence: .sisyphus/evidence/task-8-config-tests.log

  Scenario: Full build after GenerateConfig refactor
    Tool: Bash (swift)
    Preconditions: None
    Steps:
      1. Run: swift build 2>&1
    Expected Result: BUILD SUCCEEDED
    Failure Indicators: Compile error from any provider accessing config properties
    Evidence: .sisyphus/evidence/task-8-build.log
  ```

  **Commit**: YES (grouped with Wave 3)

---

- [ ] 9. Update providers to read from config.local.* and config.cloud.*

  **What to do**:
  - In each provider file, update property access patterns:
    - `config.temperature` → `config.local.temperature` (or keep using forwarded accessor)
    - `config.frequencyPenalty` → `config.cloud.frequencyPenalty`
    - `config.userId` → `config.cloud.userId`
    - etc.
  - Files to update (where GenerateConfig properties are read):
    - `Sources/Conduit/Providers/Llama/LlamaProvider.swift` — frequencyPenalty, presencePenalty, repetitionPenalty
    - `Sources/Conduit/Providers/HuggingFace/HFInferenceClient.swift` — frequencyPenalty, presencePenalty
    - `Sources/Conduit/Providers/OpenAI/OpenAIProvider+Helpers.swift` — frequencyPenalty, presencePenalty
    - `Sources/Conduit/Providers/Anthropic/AnthropicProvider+Helpers.swift` — userId, serviceTier
    - `Sources/Conduit/Builders/ResultBuilders.swift` — frequencyPenalty, presencePenalty, returnLogprobs, topLogprobs, userId, serviceTier
  - DECISION: Since forwarded accessors exist, this step is OPTIONAL — providers can continue using `config.frequencyPenalty` via the computed property. Only update if we want explicit `config.cloud.frequencyPenalty` for clarity.

  **Must NOT do**:
  - Do not change behavior — only property access path
  - Do not modify property values or logic

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Mechanical but touches many files
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 3
  - **Blocks**: Wave 5
  - **Blocked By**: Task 8

  **References**:
  **Pattern References**:
  - `Sources/Conduit/Providers/Llama/LlamaProvider.swift:519-537`
  - `Sources/Conduit/Providers/HuggingFace/HFInferenceClient.swift:38-39`
  - `Sources/Conduit/Providers/OpenAI/OpenAIProvider+Helpers.swift:128-133`
  - `Sources/Conduit/Providers/Anthropic/AnthropicProvider+Helpers.swift:217,233`
  - `Sources/Conduit/Builders/ResultBuilders.swift:544-566`

  **Acceptance Criteria**:
  - [ ] All provider files updated to use config.local.* or config.cloud.* explicitly
  - [ ] `swift build` passes
  - [ ] `swift test` passes

  **QA Scenarios**:

  ```
  Scenario: All providers compile with new access patterns
    Tool: Bash (swift)
    Preconditions: Task 8 complete
    Steps:
      1. Run: swift build 2>&1
    Expected Result: BUILD SUCCEEDED
    Failure Indicators: Compile error from property access
    Evidence: .sisyphus/evidence/task-9-providers.log
  ```

  **Commit**: YES (grouped with Wave 3)

---

- [ ] 10. Update GenerateConfigTests for new structure

  **What to do**:
  - In `Tests/ConduitTests/Core/GenerateConfigTests.swift`:
    - Verify all existing tests still pass (they should via forwarded accessors)
    - Add new tests for `config.local` and `config.cloud` direct access
    - Add test: `GenerateConfig.default.local.temperature == 0.7`
    - Add test: `GenerateConfig.default.cloud.frequencyPenalty == 0.0`
    - Add Codable round-trip test for LocalGenerateConfig
    - Add Codable round-trip test for CloudGenerateConfig

  **Must NOT do**:
  - Do not remove any existing tests
  - Do not change test imports

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Need to verify test compatibility
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 3
  - **Blocks**: Wave 5
  - **Blocked By**: Task 8

  **References**:
  **Pattern References**:
  - `Tests/ConduitTests/Core/GenerateConfigTests.swift` — Existing test file (535 lines)

  **Acceptance Criteria**:
  - [ ] All existing GenerateConfig tests pass
  - [ ] New tests for local/cloud direct access pass
  - [ ] `swift test --filter GenerateConfigTests` passes

  **QA Scenarios**:

  ```
  Scenario: All GenerateConfig tests pass
    Tool: Bash (swift)
    Preconditions: Task 8 complete
    Steps:
      1. Run: swift test --filter GenerateConfigTests 2>&1
    Expected Result: All tests pass
    Failure Indicators: Test failures
    Evidence: .sisyphus/evidence/task-10-config-tests.log
  ```

  **Commit**: YES (grouped with Wave 3)

---

- [ ] 11. Create CloudError enum

  **What to do**:
  - Create new file or add to `Sources/Conduit/Core/Errors/AIError.swift`:
    - Define `public enum CloudError: Error, Sendable, LocalizedError`
    - Cases:
      - `networkError(URLError)`
      - `serverError(statusCode: Int, message: String?)`
      - `rateLimited(retryAfter: TimeInterval?)`
      - `authenticationFailed(String)`
      - `billingError(String)`
      - `contentFiltered(reason: String?)`
      - `tokenLimitExceeded(count: Int, limit: Int)`
      - `providerUnavailable(reason: UnavailabilityReason)`
    - Implement `errorDescription` for each case (copy from current AIError)
    - Implement `isRetryable` matching current behavior

  **Must NOT do**:
  - Do not remove cases from AIError yet (that's Task 14)
  - Do not update providers yet (that's Task 15)

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Must correctly map error cases and preserve behavior
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 12, 13)
  - **Blocks**: Task 14
  - **Blocked By**: None

  **References**:
  **Pattern References**:
  - `Sources/Conduit/Core/Errors/AIError.swift:30-471` — Current AIError with all cases and descriptions

  **Acceptance Criteria**:
  - [ ] CloudError enum compiles with all 8 cases
  - [ ] errorDescription implemented for all cases
  - [ ] isRetryable implemented
  - [ ] `swift build` passes

  **QA Scenarios**:

  ```
  Scenario: CloudError compiles
    Tool: Bash (swift)
    Preconditions: None
    Steps:
      1. Run: swift build 2>&1
    Expected Result: BUILD SUCCEEDED
    Failure Indicators: Compile error
    Evidence: .sisyphus/evidence/task-11-clouderror.log
  ```

  **Commit**: YES (grouped with Wave 4)

---

- [ ] 12. Create ResourceError enum

  **What to do**:
  - Add to `Sources/Conduit/Core/Errors/AIError.swift` (or new file):
    - Define `public enum ResourceError: Error, Sendable, LocalizedError`
    - Cases:
      - `insufficientMemory(required: ByteCount, available: ByteCount)`
      - `downloadFailed(underlying: SendableError)`
      - `fileError(underlying: SendableError)`
      - `insufficientDiskSpace(required: ByteCount, available: ByteCount)`
      - `checksumMismatch(expected: String, actual: String)`
      - `modelNotCached(ModelIdentifier)`
      - `incompatibleModel(model: ModelIdentifier, reasons: [String])`
    - Implement `errorDescription` for each case

  **Must NOT do**:
  - Do not remove from AIError yet

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 11, 13)
  - **Blocks**: Task 14
  - **Blocked By**: None

  **References**:
  **Pattern References**:
  - `Sources/Conduit/Core/Errors/AIError.swift:132-163` — Resource error cases to extract

  **Acceptance Criteria**:
  - [ ] ResourceError enum compiles with all 7 cases
  - [ ] errorDescription implemented
  - [ ] `swift build` passes

  **QA Scenarios**:

  ```
  Scenario: ResourceError compiles
    Tool: Bash (swift)
    Preconditions: None
    Steps:
      1. Run: swift build 2>&1
    Expected Result: BUILD SUCCEEDED
    Evidence: .sisyphus/evidence/task-12-resourceerror.log
  ```

  **Commit**: YES (grouped with Wave 4)

---

- [ ] 13. Create ToolError enum

  **What to do**:
  - Add to `Sources/Conduit/Core/Errors/AIError.swift` (or new file):
    - Define `public enum ToolError: Error, Sendable, LocalizedError`
    - Cases:
      - `invalidToolName(name: String, reason: String)`
      - `unsupportedAudioFormat(String)`
      - `unsupportedLanguage(String)`
    - Implement `errorDescription`

  **Must NOT do**:
  - Do not remove from AIError yet

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Small enum, 3 cases
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 11, 12)
  - **Blocks**: Task 14
  - **Blocked By**: None

  **References**:
  **Pattern References**:
  - `Sources/Conduit/Core/Errors/AIError.swift:198-206` — Tool error cases

  **Acceptance Criteria**:
  - [ ] ToolError enum compiles with 3 cases
  - [ ] `swift build` passes

  **QA Scenarios**:

  ```
  Scenario: ToolError compiles
    Tool: Bash (swift)
    Preconditions: None
    Steps:
      1. Run: swift build 2>&1
    Expected Result: BUILD SUCCEEDED
    Evidence: .sisyphus/evidence/task-13-toolerror.log
  ```

  **Commit**: YES (grouped with Wave 4)

---

- [ ] 14. Refactor AIError to core cases + re-exports

  **What to do**:
  - In `Sources/Conduit/Core/Errors/AIError.swift`:
    - Remove cases that moved to CloudError: networkError, serverError, rateLimited, authenticationFailed, billingError, contentFiltered, tokenLimitExceeded, providerUnavailable
    - Remove cases that moved to ResourceError: insufficientMemory, downloadFailed, fileError, insufficientDiskSpace, checksumMismatch, modelNotCached, incompatibleModel
    - Remove cases that moved to ToolError: invalidToolName, unsupportedAudioFormat, unsupportedLanguage
    - Keep core cases (~9):
      - `invalidInput(String)`
      - `generationFailed(underlying: SendableError)`
      - `modelNotFound(ModelIdentifier)`
      - `modelNotLoaded(String)`
      - `unsupportedPlatform(String)`
      - `unsupportedModel(variant: String, reason: String)`
      - `cancelled`
      - `timeout(TimeInterval)`
    - Update `errorDescription`, `recoverySuggestion`, `isRetryable`, `category` to only handle core cases
    - Add convenience typealiases: `typealias CloudError = CloudError` (re-export from same module)
    - Update `ErrorCategory` enum to reflect new structure
    - IMPORTANT: Keep backward compatibility via `typealias AIError = AIError` in ConduitFacade if needed

  **Must NOT do**:
  - Do not update providers yet (Task 15)
  - Do not change existing error message text

  **Recommended Agent Profile**:
  - **Category**: `ultrabrain`
    - Reason: Complex refactoring affecting error handling across entire codebase
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 4
  - **Blocks**: Tasks 15, 16
  - **Blocked By**: Tasks 11, 12, 13

  **References**:
  **Pattern References**:
  - `Sources/Conduit/Core/Errors/AIError.swift` — Full AIError to refactor

  **Acceptance Criteria**:
  - [ ] AIError has only core cases (~9)
  - [ ] CloudError, ResourceError, ToolError are accessible
  - [ ] `swift build` will FAIL at this point — providers still reference moved cases (expected)

  **QA Scenarios**: Deferred to Task 15 (providers must be updated first)

  **Commit**: YES (grouped with Wave 4, but commit only after Task 15)

---

- [ ] 15. Update providers to throw appropriate error types

  **What to do**:
  - For each `throw AIError.X` that moved to a new type, update to throw the correct type:
    - `AIError.networkError(...)` → `CloudError.networkError(...)`
    - `AIError.serverError(...)` → `CloudError.serverError(...)`
    - `AIError.rateLimited(...)` → `CloudError.rateLimited(...)`
    - `AIError.authenticationFailed(...)` → `CloudError.authenticationFailed(...)`
    - `AIError.billingError(...)` → `CloudError.billingError(...)`
    - `AIError.contentFiltered(...)` → `CloudError.contentFiltered(...)`
    - `AIError.tokenLimitExceeded(...)` → `CloudError.tokenLimitExceeded(...)`
    - `AIError.providerUnavailable(...)` → `CloudError.providerUnavailable(...)`
    - `AIError.insufficientMemory(...)` → `ResourceError.insufficientMemory(...)`
    - `AIError.downloadFailed(...)` → `ResourceError.downloadFailed(...)`
    - `AIError.fileError(...)` → `ResourceError.fileError(...)`
    - `AIError.insufficientDiskSpace(...)` → `ResourceError.insufficientDiskSpace(...)`
    - `AIError.checksumMismatch(...)` → `ResourceError.checksumMismatch(...)`
    - `AIError.modelNotCached(...)` → `ResourceError.modelNotCached(...)`
    - `AIError.incompatibleModel(...)` → `ResourceError.incompatibleModel(...)`
    - `AIError.invalidToolName(...)` → `ToolError.invalidToolName(...)`
    - `AIError.unsupportedAudioFormat(...)` → `ToolError.unsupportedAudioFormat(...)`
    - `AIError.unsupportedLanguage(...)` → `ToolError.unsupportedLanguage(...)`
  - Files to update (26 files, 171 throw sites — use find-and-replace carefully)
  - IMPORTANT: If provider functions have explicit `throws(AIError)`, change to `throws(any Error)` or add the new error types
  - IMPORTANT: ChatSession.swift catches AIError — update catch blocks to catch all error types

  **Must NOT do**:
  - Do not change error messages or behavior
  - Do not modify error recovery logic

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: High volume of changes across 26 files, must be systematic
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 4
  - **Blocks**: Wave 5
  - **Blocked By**: Task 14

  **References**:
  **Pattern References**:
  - See grep results: 171 `throw AIError.` sites across 26 files

  **Acceptance Criteria**:
  - [ ] All throw sites updated to correct error type
  - [ ] `swift build` passes
  - [ ] `swift test` passes (tests updated in Task 16)

  **QA Scenarios**:

  ```
  Scenario: All providers compile with new error types
    Tool: Bash (swift)
    Preconditions: Task 14 complete
    Steps:
      1. Run: swift build 2>&1
    Expected Result: BUILD SUCCEEDED
    Failure Indicators: Compile error from throw type mismatch
    Evidence: .sisyphus/evidence/task-15-build.log
  ```

  **Commit**: YES (grouped with Wave 4)
  - Message: `refactor(api): split AIError into domain-specific error types`

---

- [ ] 16. Update ErrorTests for new error structure

  **What to do**:
  - In `Tests/ConduitTests/ErrorTests.swift`:
    - Update test for cases that moved to CloudError: create CloudError instances instead of AIError
    - Update test for cases that moved to ResourceError: create ResourceError instances
    - Update test for cases that moved to ToolError: create ToolError instances
    - Keep AIError tests for remaining core cases
    - Add new test class `CloudErrorTests` with description, recovery, retryability tests
    - Add new test class `ResourceErrorTests` with description tests
    - Add new test class `ToolErrorTests` with description tests
    - Update `testAllErrorCasesHaveDescriptions` to only test AIError core cases

  **Must NOT do**:
  - Do not remove test coverage — redistribute tests to new error types

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Substantial test rewrites
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 4
  - **Blocks**: Wave 5
  - **Blocked By**: Task 14

  **References**:
  **Pattern References**:
  - `Tests/ConduitTests/ErrorTests.swift` — Existing error tests (822 lines)

  **Acceptance Criteria**:
  - [ ] All error cases still have test coverage (in AIError, CloudError, ResourceError, or ToolError)
  - [ ] `swift test --filter ErrorTests` passes

  **QA Scenarios**:

  ```
  Scenario: All error tests pass
    Tool: Bash (swift)
    Preconditions: Task 15 complete
    Steps:
      1. Run: swift test --filter ErrorTests 2>&1
    Expected Result: All tests pass
    Failure Indicators: Test failures
    Evidence: .sisyphus/evidence/task-16-error-tests.log
  ```

  **Commit**: YES (grouped with Wave 4)

---

- [ ] 17. Full build + test verification

  **What to do**:
  - Run `swift build` — must pass
  - Run `swift test` — must pass
  - Run `swift test --filter GenerateConfigTests` — must pass
  - Run `swift test --filter ErrorTests` — must pass
  - Document any pre-existing test failures

  **Must NOT do**:
  - Do not modify any source code

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 5
  - **Blocks**: None
  - **Blocked By**: All implementation tasks

  **Acceptance Criteria**:
  - [ ] `swift build` passes
  - [ ] `swift test` passes (or pre-existing failures documented)

  **QA Scenarios**:

  ```
  Scenario: Full verification
    Tool: Bash (swift)
    Preconditions: All tasks complete
    Steps:
      1. Run: swift build 2>&1
      2. Run: swift test 2>&1
    Expected Result: BUILD SUCCEEDED, all tests pass
    Failure Indicators: Any failure
    Evidence: .sisyphus/evidence/task-17-full-verification.log
  ```

  **Commit**: NO (verification only)

---

- [ ] 18. Facade typealias verification

  **What to do**:
  - Verify that importing `Conduit` (the facade) gives access to all re-exported types
  - Check: `Conduit.Model`, `Conduit.Provider`, `Conduit.Session`, `Conduit.Conduit` all resolve
  - Verify no duplicate type definitions remain in ConduitFacade.swift
  - Verify AnyTool, GeneratedImage, ImageGenerationConfig, ImageGenerationProgress typealiases still work

  **Must NOT do**:
  - Do not modify code

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 5
  - **Blocks**: None
  - **Blocked By**: Tasks 4, 5

  **Acceptance Criteria**:
  - [ ] All typealiases in ConduitFacade.swift resolve correctly
  - [ ] No duplicate type definitions remain

  **Commit**: NO (verification only)

---

- [ ] 19. Update DocumentationExamplesTests if needed

  **What to do**:
  - Check `Tests/ConduitTests/DocumentationExamplesTests.swift` for any breakage
  - Update if it references moved error cases or GenerateConfig properties

  **Must NOT do**:
  - Do not change test behavior

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 5
  - **Blocks**: None
  - **Blocked By**: Tasks 9, 15

  **Acceptance Criteria**:
  - [ ] DocumentationExamplesTests compiles and passes

  **Commit**: YES (grouped with Wave 5)

---

## Final Verification Wave (MANDATORY — after ALL implementation tasks)

> 4 review agents run in PARALLEL. ALL must APPROVE.

- [ ] F1. **Plan Compliance Audit** — `oracle`
  Verify: no duplicate types remain, GenerateConfig split works, AIError split works, local-first ordering applied, swift build passes, swift test passes.

- [ ] F2. **Code Quality Review** — `unspecified-high`
  Run `swift build` + `swift test`. Check for `as any`, unused imports, broken typealiases.

- [ ] F3. **Integration Verification** — `unspecified-high`
  Verify facade re-exports work: import Conduit, use Model/Provider/Session/Conduit without qualification.

- [ ] F4. **Scope Fidelity Check** — `deep`
  Verify no Package.swift changes, no new files outside expected scope, no test import changes.

---

## Commit Strategy

- **Wave 1**: `refactor(api): reorder Model.Family and Provider factories to local-first`
- **Wave 2**: `refactor(api): eliminate type duplication via typealias re-exports`
- **Wave 3**: `refactor(api): split GenerateConfig into Local + Cloud composed config`
- **Wave 4**: `refactor(api): split AIError into domain-specific error types`
- **Wave 5**: `test(api): verify full build and test suite after restructuring`

---

## Success Criteria

### Verification Commands
```bash
swift build  # Expected: BUILD SUCCEEDED
swift test   # Expected: All tests pass (or document pre-existing failures)
```

### Final Checklist
- [ ] No duplicate type definitions between ConduitAdvanced and ConduitFacade
- [ ] GenerateConfig has LocalGenerateConfig + CloudGenerateConfig composition
- [ ] AIError split into AIError (core) + CloudError + ResourceError + ToolError
- [ ] Model.Family.allCases returns local-first order
- [ ] Provider factory methods appear in local-first order
- [ ] All existing fluent API calls still work
- [ ] swift build passes
- [ ] swift test passes
