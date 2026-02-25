# Tool Calling

Define tools that LLMs can invoke and execute them automatically.

## Overview

Conduit's tool system lets you define Swift functions that models can call during generation. The model decides when to use a tool based on the conversation context, Conduit handles argument parsing and execution, and the results flow back to the model for a final response.

## Defining a Tool

Implement the `Tool` protocol:

```swift
@Generable
struct WeatherArguments {
    @Guide("City name to look up weather for")
    let city: String

    @Guide("Temperature unit", .anyOf(["celsius", "fahrenheit"]))
    let unit: String
}

struct WeatherTool: Tool {
    let name = "get_weather"
    let description = "Get the current weather for a city"

    func call(arguments: WeatherArguments) async throws -> String {
        // Your implementation
        return "72F and sunny in \(arguments.city)"
    }
}
```

The `Tool` protocol requires:

| Property | Type | Description |
|----------|------|-------------|
| `name` | `String` | Unique tool identifier (defaults to type name) |
| `description` | `String` | What the tool does (sent to the model) |
| `parameters` | `GenerationSchema` | JSON schema for arguments (auto-derived from `@Generable` Arguments) |
| `call(arguments:)` | `async throws -> Output` | The implementation |

When `Arguments` conforms to `Generable`, the `parameters` schema is derived automatically.

## Adding Tools to Generation

Pass tools through `GenerateConfig`:

```swift
let config = GenerateConfig.default
    .tools([WeatherTool()])
    .toolChoice(.auto)  // Let the model decide

let result = try await provider.generate(
    messages: Messages {
        Message.user("What's the weather in Tokyo?")
    },
    model: .claudeSonnet45,
    config: config
)
```

### Tool Choice Options

- `.auto` — The model decides whether to call a tool (default)
- `.required` — The model must call at least one tool
- `.tool(name:)` — Force a specific tool
- `.none` — Disable tool calling

## The Tool Loop

When a model requests a tool call, the generation result includes tool calls instead of (or alongside) text. A complete tool-calling flow looks like:

```swift
let tools: [any Tool] = [WeatherTool(), SearchTool()]
let config = GenerateConfig.default.tools(tools)

// Step 1: Send user message
var messages = Messages {
    Message.user("What's the weather in Paris?")
}

var result = try await provider.generate(
    messages: messages,
    model: .claudeSonnet45,
    config: config
)

// Step 2: Check for tool calls
while result.hasToolCalls {
    // Add assistant message with tool calls
    messages.append(result.assistantMessage())

    // Execute each tool call
    for toolCall in result.toolCalls {
        let tool = tools.first { $0.name == toolCall.name }!
        let output = try await executeTool(tool, arguments: toolCall.arguments)

        // Add tool result
        messages.append(Message.tool(id: toolCall.id, content: output))
    }

    // Step 3: Send tool results back to the model
    result = try await provider.generate(
        messages: messages,
        model: .claudeSonnet45,
        config: config
    )
}

// Final text response
print(result.text)
```

## ToolExecutor

`ToolExecutor` is an actor that manages tool registration and concurrent execution with retry policies:

```swift
let executor = ToolExecutor()
await executor.register(WeatherTool())
await executor.register(SearchTool())

// Execute a tool call
let output = try await executor.execute(
    toolName: "get_weather",
    arguments: "{\"city\": \"Tokyo\", \"unit\": \"celsius\"}"
)
```

### Retry Policies

Configure how tool failures are retried:

```swift
let executor = ToolExecutor()

// No retries (default)
await executor.setRetryPolicy(.none)

// Retry on retryable AIErrors
await executor.setRetryPolicy(.retryableAIErrors(maxAttempts: 3))

// Retry on all failures except cancellation
await executor.setRetryPolicy(.allFailures(maxAttempts: 5))
```

### Missing Tool Policy

Control what happens when the model calls a tool that isn't registered:

```swift
// Throw an error (default)
let executor = ToolExecutor(missingToolPolicy: .throwError)

// Return an error message as tool output
let executor = ToolExecutor(missingToolPolicy: .emitToolOutput)
```

## Tool Output Types

Tool output must conform to `PromptRepresentable`. Common types work automatically:

- `String` — Direct text output
- Types conforming to `CustomStringConvertible`

## Streaming Tool Calls

During streaming, tool calls arrive progressively as `PartialToolCall` values. See [Streaming](/guide/streaming) for details on handling `partialToolCall` and `completedToolCalls` in `GenerationChunk`.

## ChatSession with Tools

`ChatSession` handles the tool loop automatically. See [Chat Session](/guide/chat-session) for details:

```swift
let session = ChatSession(
    provider: provider,
    model: .claudeSonnet45,
    toolExecutor: executor
)

// Tools are called and results fed back automatically
let response = try await session.send("What's the weather in Tokyo?")
```
