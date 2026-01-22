# AnyLanguageModel Parity - Implementation Overview

## Summary

This document provides an overview of work completed to align Conduit's structured output (Tool/Generable/Guide) with AnyLanguageModel (ALM).

**Status**: Core architecture ~70-80% complete. Remaining work focuses on structured output parsing/streaming updates, utilities, and test coverage.

---

## What's Been Done

### 1. Plan Document Created
- ✅ `docs/AnyLanguageModelParityPlan.md` created with full dependency list from ALM, rename map, and phased implementation steps

### 2. Core Types Ported from AnyLanguageModel
Successfully ported these ALM types into Conduit (`Sources/Conduit/Core/Types/` and `Core/Protocols/`):
- ✅ `ConvertibleFromGeneratedContent.swift` - Protocol for converting from GeneratedContent
- ✅ `ConvertibleToGeneratedContent.swift` - Protocol for converting to GeneratedContent
- ✅ `GenerationGuide.swift` - Constraint DSL matching ALM (GenerationGuide<T>, static methods like `.range()`, `.pattern()`)
- ✅ `GenerationSchema.swift` - Full schema system with `GenerationSchema.Property`, `.primit()`, `.anyOf()`, `.array()`, `.reference()`, encodable to JSON
- ✅ `GeneratedContent.swift` - Content representation with `Kind` enum, incomplete JSON parsing, `jsonString` property
- ✅ `GenerationID.swift` - UUID-based generation identifier
- ✅ `SendableMetatype.swift` - Type-erased metatype wrapper
- ✅ `Prompt.swift` - Prompt type with `PromptRepresentable`, `ConduitPromptBuilder`, `String`/`Array` extensions
- ✅ `Instructions.swift` - Instructions type with `InstructionsRepresentable`, `ConduitInstructionsBuilder`, `String`/`Array` extensions
- ✅ `Transcript.swift` - Full transcript system including `Segment`, `ToolCall`, `ToolCalls`, `ToolOutput`, `ToolDefinition`, `Response`, `Entry`

### 3. Generable Protocol Updated
File: `Sources/Conduit/Core/Protocols/Generable.swift`
- ✅ Replaced `GenerableContentConvertible` with ALM's protocols (`ConvertibleFromGeneratedContent`, `ConvertibleToGeneratedContent`)
- ✅ Updated `Generable` protocol signature:
  - `associatedtype PartiallyGenerated: ConvertibleFromGeneratedContent = Self` (default provided)
  - `static var generationSchema: GenerationSchema { get }`
- ✅ Ported built-in conformances: `Bool`, `String`, `Int`, `Float`, `Double`, `Decimal`, `Array`, `Optional`, `Never`
- ✅ Added macro declarations matching ALM (including `@attached` attributes)
- ✅ Added `GeneratedContentConversionError` enum

### 4. Tool Protocol Aligned with AnyLanguageModel
File: `Sources/Conduit/Core/Protocols/Tool.swift` (renamed from Tool)
- ✅ Updated to ALM's exact `Tool` protocol shape:
  - `associatedtype Arguments: ConvertibleFromGeneratedContent` (not `Generable`)
  - `associatedtype Output: PromptRepresentable`
  - Properties: `name`, `description`, `parameters`, `includesSchemaInInstructions`
  - Methods: `call(arguments:)`, `makeOutputSegments(from:)`
- ✅ Added default implementations (name, includesSchemaInInstructions, parameters from GenerationSchema)
- ✅ Added helper method `makeOutputSegments(from: GeneratedContent) -> [Transcript.Segment]`

### 5. Tool Executor Updated
File: `Sources/Conduit/Core/Tools/ToolExecutor.swift`
- ✅ Updated registry to `[any Tool]` (was `Tool`)
- ✅ Changed `execute(toolCall:)` return type to `Transcript.ToolOutput`
- ✅ Updated to use `tool.makeOutputSegments(from:)` for segment generation
- ✅ `execute(toolCalls:)` uses `withThrowingTaskGroup` for concurrent execution

### 6. Tool Data Models Updated
File: `Sources/Conduit/Core/Types/ToolMessage.swift` (extensions on Transcript)
- ✅ `Transcript.ToolCall` init from JSON, `argumentsData()`, `argumentsString``, JSON conversion helpers
- ✅ `Transcript.ToolOutput` constructors: `init(call:segments:)`, `init(call:result:)`, `text` property
- ✅ `Message.toolOutput()` static methods using `Transcript.ToolOutput`
- ✅ `Transcript.ToolCall` collection helpers (filter by name, calls matching)

File: `Sources/Conduit/Core/Streaming/GenerationChunk.swift`
- ✅ Changed `completedToolCalls` type to `[Transcript.ToolCall]?` (was `[ToolCall]?`)

File: `Sources/Conduit/Core/Types/GenerateConfig.swift`
- ✅ Already uses `Transcript.ToolDefinition` (port of ALM's `Transcript.ToolDefinition`)
- ✅ Has `tools(_:)` overloads accepting `[Transcript.ToolDefinition]` and `[any Tool]`
- ✅ Uses `Transcript.ToolDefinition(tool:)` for Tool instance mapping

### 7. Prompt Builder Renamed
Files: `Sources/Conduit/Builders/PromptBuilder.swift` and `Conduit.swift`
- ✅ Renamed `PromptContent` → `ConduitPromptContent` (to avoid collision with ALM's `Prompt` type)
- ✅ Renamed `PromptBuilder` → `ConduitPromptBuilder` (avoid collision with ALM's `Prompt` builder pattern)
- ✅ Renamed `Prompt()` function → `ConduitPrompt()` (avoid collision with ALM's `Prompt()` initializer)

### 8. Legacy Macro Declarations Made Doc-Only
File: `Sources/Conduit/Core/Macros/GenerableMacros.swift`
- ✅ Made documentation-only placeholder (prevents "Invalid redeclaration" LSP errors from duplicate macro symbols)
- Real macro declarations live in `Generable.swift` and `GenerableMacro.swift`

---

## What's Left to Do

### Priority 1: Update Structured Output Parsing/Streaming
**Files**: `Sources/Conduit/Providers/Extensions/TextGenerator+StructuredOutput.swift`, `TextGenerator+StructuredStreaming.swift`

**Required changes**:
- Ensure structured output uses `GeneratedContent` throughout
- Update method signatures:
  - `T.schema` → `T.generationSchema`
  - `T(from: content)` → `T(content:)` (matching ALM's `init(_:)`)
  - `T.Partial` → `T.PartiallyGenerated`
- Update parsing logic:
  - Replace `JsonRepair.parse(text)` with `GeneratedContent(json:)` or `JsonRepair.tryParse()` returning `GeneratedContent?`
  - Replace `try T(from: content)` with `try T(content)` (where content is `GeneratedContent`)
  - Update `T.schema.description` to `T.generationSchema.description`
- Update streaming methods to use `T.PartiallyGenerated` throughout

**Known issues**:
- `TextGenerator+StructuredOutput.swift:42` - `let schemaJSON = T.schema.description` fails; needs `T.generationSchema.description`
- `TextGenerator+StructuredStreaming.swift` - Contains multiple legacy structured output references in streaming helpers
- `StreamingResult` uses `PartiallyGenerated` but some references may still use `Partial` (need to verify)

### Priority 2: Update JsonRepair Utilities
**File**: `Sources/Conduit/Utilities/JsonRepair.swift`

**Required changes**:
- Return `GeneratedContent` from JsonRepair parsing helpers
- Add/replace existing parse methods with:
  - `init(json: String) throws -> GeneratedContent`
  - `init(incomplete: String) throws -> GeneratedContent` (mirrors ALM's incomplete JSON handling)
- Ensure JSON parsing works correctly with `GeneratedContent`'s constructors
- Update all doc comments and internal helpers to reference `GeneratedContent`

### Priority 3: Update GenerationResult (if needed)
**File**: `Sources/Conduit/Core/Types/GenerationResult.swift`

**Current state**: Already uses `Transcript.ToolCall` for `toolCalls`

**Needed**: Verify no remaining references to deprecated structured output types in tool-related types; likely minimal changes required

### Priority 4: LSP Diagnostics Cleanup
**Current LSP errors**:
- `GenerableMacros.swift`: "Invalid redeclaration" (expected - it's now doc-only)
- Streaming files: `T.PartiallyGenerated` errors (expected to resolve once structured output updates)
- `TextGenerator+StructuredOutput.swift`: Ambiguous type errors (will resolve when `GeneratedContent` used everywhere)

**Action**: Run `swift build` after updating structured output utilities to verify errors clear

### Priority 5: Add Comprehensive Test Coverage
**Files**: `Tests/ConduitTests/` and `Tests/ConduitMacrosTests/`

**Needed tests**:
- Generable macro tests:
  - Struct with `@Generable` description
  - Memberwise initializer synthesis
  - `PartiallyGenerated` nested type generation
  - `asPartiallyGenerated()` method (non-throwing)
  - `generationSchema` property
  - Enum support (with and without associated values)
  - `@Guide` macro with typed constraints (`GenerationGuide<T>`, regex guides)
- Tool protocol tests:
  - Tool implementation with `Generable` Arguments
  - `makeOutputSegments(from:)` verification
  - Tool executor tests (registration, execution, concurrent execution)
- GeneratedContent tests:
  - `GeneratedContent(json:)` for complete JSON
  - `GeneratedContent(incomplete:)` for partial JSON
  - Roundtrip conversion: `type → GeneratedContent → type`
- Streaming tests:
  - `StreamingResult` yields `T.PartiallyGenerated` elements
  - Partial tool call accumulation and completion
  - Integration with `JsonRepair` for robust parsing
- Verify all LSP errors are resolved

---

## Overall Goal

Align Conduit's structured output and tool calling system to be **100% compatible with AnyLanguageModel's API**, including:

- **Protocol parity**: `Generable` uses ALM's `GenerationSchema`, `ConvertibleFromGeneratedContent`, `ConvertibleToGeneratedContent`
- **Tool parity**: `Tool` protocol matches ALM shape exactly
- **Data types**: `GeneratedContent`, `GenerationGuide`, `Prompt`, `Instructions`, `Transcript` with full feature parity
- **Macro behavior**: `@Generable` and `@Guide` macros generate ALM-compatible code (memberwise init, partial types, schema generation)
- **Streaming**: Uses `PartiallyGenerated` and `GeneratedContent` throughout

---

## Implementation Notes for Continuation

1. **Start with Priority 1** (structured output parsing/streaming)
   - Update `TextGenerator+StructuredOutput.swift` first (simpler, non-streaming path)
   - Then update `TextGenerator+StructuredStreaming.swift`
   - These files are heavily coupled; update both to avoid breaking one before the other

2. **Then Priority 2** (JsonRepair utilities)
   - Update `JsonRepair.swift` to return `GeneratedContent`
   - This is a dependency for the structured output files, so update it first

3. **Build and verify at each milestone**
   - After Priority 1: Run `swift build` to check for LSP errors
   - After Priority 2: Run `swift build` + `swift test` to verify JsonRepair works
   - After all priorities: Full test suite run

4. **Test coverage focus**
   - Ensure new `Generable` features are tested (enums, memberwise init, PartiallyGenerated)
   - Ensure `Tool` protocol works with ALM-shaped `makeOutputSegments(from:)`
   - Test edge cases: incomplete JSON, partial types, streaming interruptions

5. **Final verification**
   - Run `swift test` after all changes
   - Ensure no LSP errors remain
   - Verify `GeneratedContent` parsing works for both complete and incomplete JSON
   - Confirm streaming yields `PartiallyGenerated` correctly

---

## File Reference Summary for Continuation

### Key Files to Modify (Priority Order)

1. **`Sources/Conduit/Utilities/JsonRepair.swift`** - Update return types, add JSON inits
2. **`Sources/Conduit/Providers/Extensions/TextGenerator+StructuredOutput.swift`** - Use `GeneratedContent` throughout, update `T.schema` → `T.generationSchema`
3. **`Sources/Conduit/Providers/Extensions/TextGenerator+StructuredStreaming.swift`** - Use `GeneratedContent` throughout, update `T.Partial` → `T.PartiallyGenerated`
4. **`Sources/Conduit/Core/Streaming/StreamingResult.swift`** - Verify all Partial references updated (optional cleanup)
5. **`Tests/ConduitTests/`** - Add Generable/Tool/GeneratedContent/JsonRepair test suites

### Key Type Mappings (Internal → ALM)
- `Partial` → `PartiallyGenerated`
- `T.schema` → `T.generationSchema`
- `T(from: content)` → `T(content:)`

### API Shape Targets (from ALM)
- Generable protocol: Uses `ConvertibleFromGeneratedContent`, `ConvertibleToGeneratedContent`, `GenerationSchema`, `PartiallyGenerated`
- Tool protocol: Uses `Arguments: ConvertibleFromGeneratedContent`, `Output: PromptRepresentable`, `GenerationSchema`
- Prompt: Has `PromptRepresentable` and `ConduitPromptBuilder`
- Instructions: Has `InstructionsRepresentable` and `ConduitInstructionsBuilder`
- Transcript: Includes `ToolCall`, `ToolCalls`, `ToolOutput`, `ToolDefinition`

---

**Next Steps**: Execute Priority 1 (JsonRepair utilities), then Priority 1 (structured output), build/verify, then add tests (Priorities 4-5).
