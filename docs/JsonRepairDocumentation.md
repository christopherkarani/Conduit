# JsonRepair Documentation

This file documents changes made to support `GeneratedContent` for JSON repair and structured output parsing.

## Background

Conduit now uses AnyLanguageModel's structured output system built around `GeneratedContent`. JsonRepair provides helpers for parsing complete and incomplete JSON into `GeneratedContent`.

## Changes to `JsonRepair.swift`

### 1. Updated Public API

Added two new public static methods that return `GeneratedContent`:

```swift
/// Creates GeneratedContent from a complete JSON string.
///
/// - Parameter json: A complete JSON string.
/// - Returns: GeneratedContent with parsed JSON structure.
public static func from(json: String) throws -> GeneratedContent {
    try GeneratedContent(json: json)
}

/// Creates GeneratedContent from an incomplete JSON string.
///
/// - Parameter json: The potentially incomplete JSON string.
/// - Returns: GeneratedContent that may be incomplete (for incremental parsing).
public static func from(incomplete: String) throws -> GeneratedContent {
    try GeneratedContent(json: json)
}
```

### 2. Implementation Details

Both methods use the existing `GeneratedContent(json:)` initializer internally, which already handles incomplete JSON correctly. The new public methods provide convenient wrappers for the two most common use cases:

- `from(json:)` - Use when you have complete JSON from the model
- `from(incomplete:)` - Use during streaming when JSON may arrive in fragments

### 3. Design Rationale

The `GeneratedContent` type provides these benefits:
- **Better streaming support**: `GeneratedContent.init(json:)` handles incomplete JSON gracefully
- **Simplified parsing**: Single responsibility for JSON parsing
- **Consistency**: Using the same content type throughout Conduit (in both tool calls and structured output)

### 4. Compatibility Note

These changes are **breaking**. Update any code that relied on the older structured output type or custom JSON parsing.

## Testing

To verify these changes work correctly:
```bash
swift test --filter JsonRepairTests
swift build
```

## Migration Guide

If you previously constructed structured output manually, update to `GeneratedContent` and the new JsonRepair helpers:

```swift
// Complete JSON
let content = try GeneratedContent(json: myJSONString)

// Incomplete JSON (streaming)
let partial = try JsonRepair.from(incomplete: partialJSONString)
```

The `GeneratedContent` approach is preferred for new code, especially with streaming and tool calling.
