# AnyLanguageModel Parity Plan (Tool/Generable/Guide)

## Executive Summary
This plan brings Conduit’s structured output and tool-calling API to feature parity with AnyLanguageModel’s `Tool`/`Generable`/`Guide` stack. It uses AnyLanguageModel as the behavior source of truth, enumerates all dependency types and supporting files, and outlines phased implementation steps with concrete Conduit files to modify.

## AnyLanguageModel Dependencies & Supporting Types (Authoritative Sources)
> These are the exact dependencies and supporting types AnyLanguageModel uses for Tool/Generable/Guide parity. Each bullet includes file paths and anchor snippets.

### Core Types
- **GenerationGuide** — `AnyLanguageModel-main-2/Sources/AnyLanguageModel/GenerationGuide.swift`
  - Guides for strings, numbers, and arrays.
  - Snippets:
    ```swift
    public struct GenerationGuide<Value> {}
    public static func pattern<Output>(_ regex: Regex<Output>) -> GenerationGuide<String>
    public static func range(_ range: ClosedRange<Int>) -> GenerationGuide<Int>
    public static func count<Element>(_ range: ClosedRange<Int>) -> GenerationGuide<[Element]>
    public static func minimumCount(_ count: Int) -> GenerationGuide<Value> // [Never] macro support
    ```

- **GenerationSchema** — `AnyLanguageModel-main-2/Sources/AnyLanguageModel/GenerationSchema.swift`
  - JSON-schema-like model describing object/array/string/number/etc.
  - Snippets:
    ```swift
    public struct GenerationSchema: Sendable, Codable, CustomDebugStringConvertible {
        indirect enum Node: Sendable, Codable {
            case object(ObjectNode)
            case array(ArrayNode)
            case string(StringNode)
            case number(NumberNode)
            case boolean
            case anyOf([Node])
            case ref(String)
        }
    }
    static let omitAdditionalPropertiesKey = CodingUserInfoKey(rawValue: "GenerationSchema.omitAdditionalProperties")!
    ```

- **GeneratedContent** — `AnyLanguageModel-main-2/Sources/AnyLanguageModel/GeneratedContent.swift`
  - Runtime JSON-like content with `Kind` and `json` initializer.
  - Snippets:
    ```swift
    public struct GeneratedContent: Sendable, Equatable, Generable, CustomDebugStringConvertible, Codable {
        public static var generationSchema: GenerationSchema { ... }
        public init(json: String) throws { ... } // supports incomplete JSON
    }

    public enum Kind: Equatable, Sendable {
        case null, bool(Bool), number(Double), string(String)
        case array([GeneratedContent])
        case structure(properties: [String: GeneratedContent], orderedKeys: [String])
    }
    ```

### Prompt/Instructions
- **Prompt** — `AnyLanguageModel-main-2/Sources/AnyLanguageModel/Prompt.swift`
  - Result builder for prompts + `PromptRepresentable`.
  - Snippets:
    ```swift
    public init(@PromptBuilder _ content: () throws -> Prompt) rethrows

    @resultBuilder
    public struct PromptBuilder {
        public static func buildBlock<each P>(_ components: repeat each P) -> Prompt
        where repeat each P: PromptRepresentable
    }
    ```

- **Instructions** — `AnyLanguageModel-main-2/Sources/AnyLanguageModel/Instructions.swift`
  - Result builder mirroring Prompt.
  - Snippets:
    ```swift
    public init(@InstructionsBuilder _ content: () throws -> Instructions) rethrows

    @resultBuilder
    public struct InstructionsBuilder {
        public static func buildBlock<each I>(_ components: repeat each I) -> Instructions
        where repeat each I: InstructionsRepresentable
    }
    ```

### Transcript & Tool Calling
- **Transcript** — `AnyLanguageModel-main-2/Sources/AnyLanguageModel/Transcript.swift`
  - Conversation storage, tool calls, tool outputs, and tool definitions.
  - Snippets:
    ```swift
    public enum Entry { case instructions(Instructions), prompt(Prompt), toolCalls(ToolCalls), toolOutput(ToolOutput), response(Response) }
    public struct ToolCall { public var toolName: String; public var arguments: GeneratedContent }
    public struct ToolOutput { public var toolName: String; public var segments: [Segment] }
    public struct ToolDefinition { public var name: String; public var description: String; internal let parameters: GenerationSchema }
    ```

- **Tool protocol** — `AnyLanguageModel-main-2/Sources/AnyLanguageModel/Tool.swift`
  - Typed tool contract with schema injection support.
  - Snippets:
    ```swift
    public protocol Tool<Arguments, Output>: Sendable {
        associatedtype Output: PromptRepresentable
        associatedtype Arguments: ConvertibleFromGeneratedContent
        var parameters: GenerationSchema { get }
        var includesSchemaInInstructions: Bool { get }
        func call(arguments: Self.Arguments) async throws -> Self.Output
    }
    ```

### Generable & Macros
- **Generable protocol + macros** — `AnyLanguageModel-main-2/Sources/AnyLanguageModel/Generable.swift`
  - Snippets:
    ```swift
    public protocol Generable: ConvertibleFromGeneratedContent, ConvertibleToGeneratedContent {
        associatedtype PartiallyGenerated: ConvertibleFromGeneratedContent = Self
        static var generationSchema: GenerationSchema { get }
    }

    @attached(extension, conformances: Generable, names: named(init(_:)), named(generatedContent))
    public macro Generable(description: String? = nil)

    @attached(peer)
    public macro Guide<T>(description: String? = nil, _ guides: GenerationGuide<T>...) where T: Generable
    @attached(peer)
    public macro Guide<RegexOutput>(description: String? = nil, _ guides: Regex<RegexOutput>)
    ```

- **SwiftSyntax/SwiftCompilerPlugin macros**
  - `AnyLanguageModel-main-2/Sources/AnyLanguageModelMacros/GenerableMacro.swift`
    ```swift
    import SwiftCompilerPlugin
    import SwiftSyntax
    import SwiftSyntaxMacros
    public struct GenerableMacro: MemberMacro, ExtensionMacro { ... }
    ```
  - `AnyLanguageModel-main-2/Sources/AnyLanguageModelMacros/GuideMacro.swift`
    ```swift
    import SwiftSyntax
    import SwiftSyntaxMacros
    public struct GuideMacro: PeerMacro { ... }
    ```
  - `AnyLanguageModel-main-2/Sources/AnyLanguageModelMacros/Plugin.swift`
    ```swift
    @main
    struct AnyLanguageModelMacrosPlugin: CompilerPlugin {
        let providingMacros: [any Macro.Type] = [GenerableMacro.self, GuideMacro.self]
    }
    ```
  - `AnyLanguageModel-main-2/Package.swift`
    ```swift
    .package(url: "https://github.com/swiftlang/swift-syntax", from: "600.0.0")
    .macro(name: "AnyLanguageModelMacros", dependencies: [
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
    ])
    ```

### Foundation/CoreFoundation/Regex Usage
- **Foundation/CoreFoundation**
  - `AnyLanguageModel-main-2/Sources/AnyLanguageModel/GeneratedContent.swift`
    ```swift
    import CoreFoundation
    ```
  - `AnyLanguageModel-main-2/Sources/AnyLanguageModel/GenerationGuide.swift`
    ```swift
    import struct Foundation.Decimal
    import class Foundation.NSDecimalNumber
    ```

- **Regex**
  - `AnyLanguageModel-main-2/Sources/AnyLanguageModel/GenerationGuide.swift`
    ```swift
    public static func pattern<Output>(_ regex: Regex<Output>) -> GenerationGuide<String>
    ```
  - `AnyLanguageModel-main-2/Sources/AnyLanguageModel/GenerationSchema.swift`
    ```swift
    public init<RegexOutput>(..., guides: [Regex<RegexOutput>] = [])
    ```

## Type Map & Collision Notes
| AnyLanguageModel | Conduit |
| --- | --- |
| Partial | PartiallyGenerated |
| GenerationSchema | GenerationSchema |
| GeneratedContent | GeneratedContent |
| Tool | Tool |
| ToolCall | ToolCall |
| ToolOutput | ToolOutput |
| ToolDefinition | Transcript.ToolDefinition |

**Prompt collision note:** Conduit currently exposes `Prompt()` and `PromptContent`, while AnyLanguageModel defines a `Prompt` type. For parity, rename `PromptContent` or the `Prompt()` function to avoid ambiguity when mirroring AnyLanguageModel APIs.

## Conduit Current Touchpoints (Parity Targets)
- **Generable protocol + macros**: `Sources/Conduit/Core/Protocols/Generable.swift`, `Sources/Conduit/Core/Macros/GenerableMacros.swift`, `Sources/ConduitMacros/GenerableMacro.swift`, `Sources/ConduitMacros/GuideMacro.swift`
- **GenerationSchema**: `Sources/Conduit/Core/Types/GenerationSchema.swift`
- **GeneratedContent**: `Sources/Conduit/Core/Types/GeneratedContent.swift`
- **Tooling**: `Sources/Conduit/Core/Protocols/Tool.swift`, `Sources/Conduit/Core/Types/ToolMessage.swift`
- **Prompt/Instructions builder**: `Sources/Conduit/Builders/PromptBuilder.swift`, `Sources/Conduit/Builders/MessageBuilder.swift`

## Phase 0 — Discovery & Parity Matrix
**Goal:** Establish a one-to-one mapping for AnyLanguageModel types to Conduit equivalents and confirm gaps.

**Tasks:**
1. Inventory AnyLanguageModel features vs Conduit (Tool, Generable, Guide, GenerationSchema, GeneratedContent, Prompt/Instructions, Transcript).
2. Define parity acceptance criteria and tests to target (macro expansions, schema JSON, tool-call transcript shapes).

**Conduit files to review/modify:**
- `Sources/Conduit/Core/Protocols/Generable.swift`
- `Sources/Conduit/Core/Macros/GenerableMacros.swift`
- `Sources/ConduitMacros/GenerableMacro.swift`
- `Sources/ConduitMacros/GuideMacro.swift`
- `Sources/Conduit/Core/Types/GenerationSchema.swift`
- `Sources/Conduit/Core/Types/GeneratedContent.swift`
- `Sources/Conduit/Core/Protocols/Tool.swift`
- `Sources/Conduit/Core/Types/ToolMessage.swift`
- `Sources/Conduit/Builders/PromptBuilder.swift`

## Phase 1 — GenerationGuide Parity
**Goal:** Mirror AnyLanguageModel’s guide API surface and mapping behavior.

**Tasks:**
1. Add a Conduit `GenerationGuide` equivalent or extend `Constraint` utilities to mirror AnyLanguageModel guide signatures.
2. Implement guide-to-schema mapping so `@Guide(..., .pattern(regex))` maps to schema pattern (String constraint) and `.anyOf`, `.constant`, `.range`, `.minimum`, `.maximum`, `.count`, `.minimumCount`, `.maximumCount`, `.element` map to Conduit `GenerationSchema` constraints.
3. Provide special overloads for `[Never]` count guides to support macro expansion parity.

**Relevant AnyLanguageModel references:**
- `AnyLanguageModel-main-2/Sources/AnyLanguageModel/GenerationGuide.swift`
  - String guides + Regex: `.pattern(_ regex: Regex<Output>)`
  - Numeric guides: `.minimum`, `.maximum`, `.range`
  - Array count guides: `.count`, `.minimumCount`, `.maximumCount`

**Conduit files to modify:**
- `Sources/Conduit/Core/Types/Constraint.swift` (extend constraints or add guide mapping layer)
- `Sources/Conduit/Core/Macros/GenerableMacros.swift` (expose Guide overloads mirroring AnyLanguageModel)
- `Sources/ConduitMacros/GenerableMacro.swift` (parse guide attributes and build constraints)

## Phase 2 — GenerationSchema Parity
**Goal:** Align Conduit `GenerationSchema` with AnyLanguageModel `GenerationSchema` (JSON schema structure, $defs, optional properties).

**Tasks:**
1. Add JSON-schema export capability and `$defs` support mirroring AnyLanguageModel’s `GenerationSchema` root/defs model.
2. Include `omitAdditionalPropertiesKey`-like behavior to control `additionalProperties` when encoding to JSON.
3. Implement `anyOf` representation, object required list, and array min/max items parity.

**Relevant AnyLanguageModel references:**
- `AnyLanguageModel-main-2/Sources/AnyLanguageModel/GenerationSchema.swift`
  - `Node` enum (`object`, `array`, `string`, `number`, `boolean`, `anyOf`, `ref`)
  - `omitAdditionalPropertiesKey` userInfo key
  - Property init overloads for Generable vs String+Regex

**Conduit files to modify:**
- `Sources/Conduit/Core/Types/GenerationSchema.swift`
- `Sources/Conduit/Providers/Extensions` (GenerationSchema JSON encoding helpers, if needed)

## Phase 3 — GeneratedContent Parity
**Goal:** Ensure Conduit’s `GeneratedContent` matches AnyLanguageModel’s `GeneratedContent` semantics.

**Tasks:**
1. Ensure `GeneratedContent` includes `id`, `Kind`, and ordered object keys.
2. Implement `init(json:)` that supports incomplete JSON (same strategy as AnyLanguageModel).
3. Add typed value accessors and helper conversions for `Generable` types.

**Relevant AnyLanguageModel references:**
- `AnyLanguageModel-main-2/Sources/AnyLanguageModel/GeneratedContent.swift`
  - `init(json:)` with incomplete JSON recovery
  - `Kind` enum storing ordered keys

**Conduit files to modify:**
- `Sources/Conduit/Core/Types/GeneratedContent.swift`
- `Sources/Conduit/Utilities/JsonRepair.swift` (if needed for incomplete JSON handling)
- `Sources/Conduit/Core/Types/GenerationID.swift` (if needed to mirror `GenerationID` usage)

## Phase 4 — Prompt & Instructions Builders
**Goal:** Match AnyLanguageModel’s `Prompt`/`Instructions` DSL behavior and `*Representable` protocols.

**Tasks:**
1. Implement `Prompt`, `Instructions`, `PromptRepresentable`, and `InstructionsRepresentable` in Conduit (or adapt existing builders).
2. Add `@resultBuilder` for prompt/instruction building using string-based segments with newline joining.
3. Ensure type erasure (Accepts `String`, arrays, and custom representables) matches AnyLanguageModel behavior.

**Relevant AnyLanguageModel references:**
- `AnyLanguageModel-main-2/Sources/AnyLanguageModel/Prompt.swift`
- `AnyLanguageModel-main-2/Sources/AnyLanguageModel/Instructions.swift`

**Conduit files to modify:**
- `Sources/Conduit/Builders/PromptBuilder.swift`
- `Sources/Conduit/Builders/MessageBuilder.swift`
- `Sources/Conduit/Core/Types/Message.swift` (if integrating prompt/instructions into messages)

## Phase 5 — Transcript, ToolCall, ToolOutput, ToolDefinition
**Goal:** Align Conduit’s tool-calling transcript structures with AnyLanguageModel’s model.

**Tasks:**
1. Add a `Transcript` type to Conduit or augment existing message history types to track `instructions`, `prompt`, `toolCalls`, `toolOutput`, `response` entries.
2. Implement `ToolCall`, `ToolOutput`, `ToolDefinition` equivalents with `GeneratedContent`-style arguments and schema references.
3. Add conversion layer for provider tool-calling logic to emit/consume transcript entries.

**Relevant AnyLanguageModel references:**
- `AnyLanguageModel-main-2/Sources/AnyLanguageModel/Transcript.swift`
  - `Entry`, `Segment`, `ToolCall`, `ToolOutput`, `ToolDefinition`

**Conduit files to modify:**
- `Sources/Conduit/Core/Types/ToolMessage.swift`
- `Sources/Conduit/Core/Types/Message.swift`
- `Sources/Conduit/Core/Types/GenerateConfig.swift` (if tool schema needs injection)

## Phase 6 — Tool Protocol Parity & Execution Pipeline
**Goal:** Align Conduit `Tool` with AnyLanguageModel `Tool` semantics, including schema injection and structured outputs.

**Tasks:**
1. Ensure `Tool` supports optional `includesSchemaInInstructions` and defaults to `true`.
2. Support arguments decoding via `GeneratedContent` equivalent, and output segments for string/structured values.
3. Align tool name defaults and validation with AnyLanguageModel behavior.

**Relevant AnyLanguageModel references:**
- `AnyLanguageModel-main-2/Sources/AnyLanguageModel/Tool.swift`

**Conduit files to modify:**
- `Sources/Conduit/Core/Protocols/Tool.swift`
- `Sources/Conduit/Core/Types/ToolMessage.swift`
- `Sources/Conduit/Core/Tools/ToolExecutor.swift`

## Phase 7 — Macro & SwiftSyntax Parity
**Goal:** Mirror AnyLanguageModel macro behavior, including `@Guide` parsing, partials, and schema generation.

**Tasks:**
1. Update Conduit macros to parse `@Guide` attributes with AnyLanguageModel-compatible overloads: description-only, description + `GenerationGuide` list, and Regex guide.
2. Ensure macros emit: memberwise init, `init(from:)`, `generableContent`, schema, partial type, and prompt/instructions representations (matching AnyLanguageModel’s macro output).
3. Align macro registration with SwiftCompilerPlugin and SwiftSyntax dependencies.

**Relevant AnyLanguageModel references:**
- `AnyLanguageModel-main-2/Sources/AnyLanguageModel/Generable.swift`
- `AnyLanguageModel-main-2/Sources/AnyLanguageModelMacros/GenerableMacro.swift`
- `AnyLanguageModel-main-2/Sources/AnyLanguageModelMacros/GuideMacro.swift`
- `AnyLanguageModel-main-2/Sources/AnyLanguageModelMacros/Plugin.swift`
- `AnyLanguageModel-main-2/Package.swift`

**Conduit files to modify:**
- `Sources/Conduit/Core/Macros/GenerableMacros.swift`
- `Sources/ConduitMacros/GenerableMacro.swift`
- `Sources/ConduitMacros/GuideMacro.swift`
- `Sources/ConduitMacros/ConduitMacrosPlugin.swift`
- `Package.swift` (macro target dependencies if mismatched)

## Phase 8 — Provider Integrations & GenerationSchema Injection
**Goal:** Ensure structured schema/tool definitions flow into provider prompts and tool-calling APIs as AnyLanguageModel does.

**Tasks:**
1. Ensure tool schemas are encoded to JSON schema and sent to providers that accept JSON schema (OpenAI, Anthropic, etc.).
2. Align tool call parsing and tool output handling with transcript entries.
3. Validate schema injection toggles (similar to `includesSchemaInInstructions`).

**Conduit files to modify:**
- `Sources/Conduit/Providers/OpenAI/*`
- `Sources/Conduit/Providers/Anthropic/*`
- `Sources/Conduit/Providers/FoundationModels/*`
- `Sources/Conduit/Providers/MLX/*` (if schema injection needed)

## Phase 9 — Tests & Validation
**Goal:** Prove parity via macro expansion tests and runtime schema/guide conversions.

**Tasks:**
1. Add macro expansion tests mirroring AnyLanguageModel’s `GenerableMacroTests`.
2. Add JSON schema encoding tests for guide constraints and `$defs` references.
3. Add tool call parsing/execution tests that check `ToolCall/ToolOutput` roundtrip.

**Conduit files to modify:**
- `Tests/ConduitMacrosTests/GenerableMacroTests.swift`
- `Tests/ConduitMacrosTests/GuideMacroTests.swift`
- `Tests/ConduitTests/*` (new structured output parity tests)

## Implementation Timeline (Sequential)
1. **Week 1**: Phase 0–2 (guide/schema parity, JSON schema export)
2. **Week 2**: Phase 3–5 (GeneratedContent/Transcript/Prompt/Instructions)
3. **Week 3**: Phase 6–7 (Tool protocol + macros)
4. **Week 4**: Phase 8–9 (provider integration + tests)

## Risks & Mitigations
- **Regex API mismatch (Swift Regex)**: Confirm Swift version compatibility and add fallback if needed.
- **GenerationSchema encoding differences**: Add golden JSON tests to avoid subtle provider regressions.
- **Macro expansion drift**: Mirror AnyLanguageModel macro signatures and add dedicated regression tests.

## Success Criteria
- Conduit supports the full AnyLanguageModel guide API surface.
- Structured output serialization matches AnyLanguageModel JSON schema shape.
- Tool calling uses transcript types with schema injection parity.
- Macro expansion and runtime behavior match AnyLanguageModel in functional tests.
