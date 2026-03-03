# Chat Session

Manage multi-turn conversations with automatic tool execution and SwiftUI integration.

## Overview

`ChatSession` is a generic, `@Observable` actor that manages conversation state, streams responses, executes tools automatically, and integrates with SwiftUI. It wraps any `TextGenerator` provider and handles the complexity of multi-turn interactions.

## Creating a Session

```swift
let provider = AnthropicProvider(apiKey: "sk-ant-...")
let session = ChatSession(
    provider: provider,
    model: .claudeSonnet45,
    config: .default.temperature(0.7)
)
```

With a tool executor:

```swift
let executor = ToolExecutor()
await executor.register(WeatherTool())

let session = ChatSession(
    provider: provider,
    model: .claudeSonnet45,
    config: .default.tools([WeatherTool()]),
    toolExecutor: executor
)
```

## Sending Messages

### Full Response

```swift
let response = try await session.send("What's the capital of France?")
print(response) // "The capital of France is Paris."
```

### Streaming Response

```swift
for try await text in session.stream("Tell me about Swift concurrency") {
    print(text, terminator: "")
}
```

## System Prompts

Set a system prompt to guide the assistant's behavior:

```swift
await session.setSystemPrompt("You are a Swift programming expert. Be concise.")
```

## Conversation History

ChatSession manages message history automatically. You can also manipulate it:

```swift
// Undo the last user-assistant exchange
await session.undoLastExchange()

// Clear all history
await session.clearHistory()

// Inject previously saved history
await session.injectHistory(savedMessages)
```

## Cancellation

Cancel an in-progress generation:

```swift
await session.cancel()
```

## Automatic Tool Execution

When configured with a `ToolExecutor`, ChatSession handles the full tool loop automatically:

1. User sends a message
2. Model responds with a tool call
3. ChatSession executes the tool
4. Tool result is sent back to the model
5. Model produces a final text response

This happens transparently — the caller just sees the final response:

```swift
// Tools are called automatically behind the scenes
let response = try await session.send("What's the weather in Tokyo?")
// response contains the final answer incorporating weather data
```

## SwiftUI Integration

Since ChatSession is `@Observable`, it integrates with SwiftUI:

```swift
struct ChatView: View {
    @State private var session = ChatSession(
        provider: AnthropicProvider(apiKey: "sk-ant-..."),
        model: .claudeSonnet45
    )
    @State private var input = ""
    @State private var messages: [String] = []

    var body: some View {
        VStack {
            ScrollView {
                ForEach(messages, id: \.self) { message in
                    Text(message)
                }
            }

            HStack {
                TextField("Message", text: $input)
                Button("Send") {
                    let prompt = input
                    input = ""
                    Task {
                        let response = try await session.send(prompt)
                        messages.append("You: \(prompt)")
                        messages.append("AI: \(response)")
                    }
                }
            }
        }
    }
}
```

## Warmup

Pre-warm the provider for faster first responses:

```swift
let session = ChatSession(
    provider: provider,
    model: .claudeSonnet45,
    warmup: .eager  // Warm up immediately on init
)
```
