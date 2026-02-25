# Streaming

Receive tokens in real time with `AsyncThrowingStream`.

## Overview

Every Conduit provider supports streaming generation. There are two streaming methods: a simple one that yields `String` tokens, and a rich one that yields `GenerationChunk` values with metadata like token counts, speed, and finish reasons.

## Simple Text Streaming

Use `stream()` for straightforward token-by-token output:

```swift
for try await text in provider.stream("Tell me a joke", model: .claudeSonnet45) {
    print(text, terminator: "")
}
print() // newline after stream completes
```

The return type is `AsyncThrowingStream<String, Error>`. Each element is a text fragment (usually one or a few tokens).

## Rich Streaming with Metadata

Use `streamWithMetadata()` to access per-chunk metadata:

```swift
let messages = Messages {
    Message.system("You are a helpful assistant.")
    Message.user("Explain Swift concurrency")
}

let stream = provider.streamWithMetadata(
    messages: messages,
    model: .claudeSonnet45,
    config: .default
)

for try await chunk in stream {
    // The generated text fragment
    print(chunk.text, terminator: "")

    // Real-time performance metrics
    if let speed = chunk.tokensPerSecond {
        // e.g. 45.2 tokens/sec
    }

    // Detect stream completion
    if let reason = chunk.finishReason {
        print("\nFinished: \(reason)")
    }
}
```

### GenerationChunk Fields

`GenerationChunk` includes:

| Property | Type | Description |
|----------|------|-------------|
| `text` | `String` | The generated text fragment |
| `tokenCount` | `Int` | Number of tokens in this chunk |
| `tokensPerSecond` | `Double?` | Current generation speed |
| `isComplete` | `Bool` | Whether this is the final chunk |
| `finishReason` | `FinishReason?` | Why generation stopped (`.stop`, `.maxTokens`, `.toolCall`, etc.) |
| `usage` | `UsageStats?` | Token usage breakdown (prompt + completion) |
| `partialToolCall` | `PartialToolCall?` | In-progress tool call data |
| `completedToolCalls` | `[Transcript.ToolCall]?` | Fully assembled tool calls |
| `reasoningDetails` | `[ReasoningDetail]?` | Extended thinking content |

## Streaming Tool Calls

When the model invokes tools during streaming, you receive `PartialToolCall` chunks as argument JSON is assembled:

```swift
for try await chunk in stream {
    if let partial = chunk.partialToolCall {
        // partial.toolName — which tool is being called
        // partial.argumentsFragment — incremental JSON fragment
        // partial.index — progress indicator (0...100)
    }

    if let completed = chunk.completedToolCalls {
        for toolCall in completed {
            // Full tool call ready for execution
        }
    }
}
```

## Streaming Structured Output

When using `@Generable` types with streaming, incomplete JSON is progressively recovered into a `PartiallyGenerated` instance. See [Structured Output](/guide/structured-output) for details.

## Cancellation

Cancel a streaming generation by cancelling the enclosing `Task`:

```swift
let task = Task {
    for try await text in provider.stream("Write a long essay...", model: .claudeSonnet45) {
        print(text, terminator: "")
    }
}

// Cancel after 5 seconds
try await Task.sleep(for: .seconds(5))
task.cancel()
```

You can also call `cancelGeneration()` on the provider directly:

```swift
await provider.cancelGeneration()
```

## Collecting Stream Results

Accumulate a full response from a stream:

```swift
var fullText = ""
for try await chunk in provider.streamWithMetadata(messages: messages, model: .claudeSonnet45, config: .default) {
    fullText += chunk.text

    if let usage = chunk.usage {
        print("Total tokens: \(usage.totalTokens)")
    }
}
print(fullText)
```
