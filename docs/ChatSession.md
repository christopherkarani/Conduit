# ChatSession

Stateful conversation management with automatic history tracking. Build chat interfaces without manually managing message arrays.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Creating Sessions](#creating-sessions)
- [Sending Messages](#sending-messages)
- [Streaming Responses](#streaming-responses)
- [History Management](#history-management)
- [Warmup Options](#warmup-options)
- [System Prompts](#system-prompts)
- [Memory Considerations](#memory-considerations)
- [SwiftUI Integration](#swiftui-integration)

---

## Overview

`ChatSession` simplifies building conversational AI features:

**Without ChatSession:**
```swift
var messages: [Message] = []
messages.append(.system("You are helpful."))
messages.append(.user("Hello"))
let response = try await provider.generate(messages: messages, ...)
messages.append(.assistant(response.text))
messages.append(.user("Follow up"))
// Manually manage array...
```

**With ChatSession:**
```swift
let session = try await ChatSession(provider: provider, model: model)
let response1 = try await session.send("Hello")
let response2 = try await session.send("Follow up")
// History managed automatically
```

### Benefits

- **Automatic history**: Messages tracked internally
- **Context continuity**: Multi-turn conversations work seamlessly
- **Warmup support**: Fast first response with model preloading
- **Thread-safe**: Actor-based for concurrent access

---

## Quick Start

```swift
import Conduit

// Create session
let session = try await ChatSession(
    provider: MLXProvider(),
    model: .llama3_2_1B,
    systemPrompt: "You are a helpful coding assistant."
)

// Send messages
let response1 = try await session.send("What is a protocol in Swift?")
print(response1)

let response2 = try await session.send("Can you give me an example?")
print(response2)

// The assistant remembers the context!
```

---

## Creating Sessions

### Basic Creation

```swift
let session = try await ChatSession(
    provider: MLXProvider(),
    model: .llama3_2_1B
)
```

### With System Prompt

```swift
let session = try await ChatSession(
    provider: AnthropicProvider(apiKey: "sk-ant-..."),
    model: .claudeSonnet45,
    systemPrompt: "You are a friendly assistant who speaks casually."
)
```

### With Warmup

```swift
let session = try await ChatSession(
    provider: MLXProvider(),
    model: .llama3_2_1B,
    systemPrompt: "You are helpful.",
    warmup: .eager  // Pre-load model
)
```

### With Configuration

```swift
let session = try await ChatSession(
    provider: MLXProvider(),
    model: .llama3_2_1B,
    systemPrompt: "You are a code expert.",
    config: .code,  // Use code preset
    warmup: .default
)
```

---

## Sending Messages

### Simple Send

```swift
let response = try await session.send("What is Swift?")
print(response)  // String response
```

### With Custom Config

```swift
// Override config for specific message
let response = try await session.send(
    "Write a creative poem",
    config: .creative
)
```

### Multiple Turns

```swift
// Conversation flows naturally
let r1 = try await session.send("Tell me about Swift")
let r2 = try await session.send("What about concurrency?")
let r3 = try await session.send("Show me an actor example")
// Each response considers previous context
```

---

## Streaming Responses

### Basic Streaming

```swift
for try await text in session.streamResponse("Tell me a story") {
    print(text, terminator: "")
}
print()
```

### With Progress Tracking

```swift
var totalTokens = 0

for try await text in session.streamResponse("Explain Swift actors") {
    print(text, terminator: "")
    totalTokens += 1  // Approximate
}

print("\nGenerated ~\(totalTokens) tokens")
```

### Streaming with Custom Config

```swift
for try await text in session.streamResponse(
    "Write a poem",
    config: .creative
) {
    print(text, terminator: "")
}
```

---

## History Management

### Access History

```swift
// Get all messages in conversation
let history = await session.messages

for message in history {
    switch message.role {
    case .system:
        print("System: \(message.content.textValue ?? "")")
    case .user:
        print("User: \(message.content.textValue ?? "")")
    case .assistant:
        print("Assistant: \(message.content.textValue ?? "")")
    default:
        break
    }
}
```

### Clear History

```swift
// Start fresh (keeps system prompt)
await session.clearHistory()
```

### History Count

```swift
let messageCount = await session.messages.count
```

### Add Messages Manually

```swift
// Add context from external source
await session.addMessage(.user("Previous context: ..."))
await session.addMessage(.assistant("I understand."))
```

---

## Warmup Options

Warming up preloads the model for faster first response:

| Option | First Message Latency | Use Case |
|--------|----------------------|----------|
| `nil` | 2-4 seconds | Infrequent use, save resources |
| `.default` | 1-2 seconds | Balanced approach |
| `.eager` | 100-300ms | Chat interfaces, real-time apps |

### No Warmup

```swift
// Model loads on first message
let session = try await ChatSession(
    provider: MLXProvider(),
    model: .llama3_2_1B,
    warmup: nil
)
```

### Default Warmup

```swift
// Moderate preloading
let session = try await ChatSession(
    provider: MLXProvider(),
    model: .llama3_2_1B,
    warmup: .default
)
```

### Eager Warmup

```swift
// Full model preload
let session = try await ChatSession(
    provider: MLXProvider(),
    model: .llama3_2_1B,
    warmup: .eager
)
// First response is fast
```

### When to Warm Up

- **Chat apps**: Use `.eager` for responsive UI
- **Background processing**: Use `nil` to save resources
- **Splash screens**: Initialize with `.eager` during app launch

---

## System Prompts

### Setting at Creation

```swift
let session = try await ChatSession(
    provider: provider,
    model: model,
    systemPrompt: """
        You are a Swift programming expert.
        - Provide concise code examples
        - Use modern Swift 6.2 conventions
        - Explain your reasoning
        """
)
```

### Effective System Prompts

```swift
// Be specific about persona
systemPrompt: "You are a friendly cooking assistant who loves Italian cuisine."

// Include behavior guidelines
systemPrompt: """
    You are a code reviewer.
    - Focus on security and performance
    - Be constructive in feedback
    - Suggest improvements, don't just criticize
    """

// Set output format
systemPrompt: """
    You are a data analyst.
    Always respond with:
    1. A brief summary
    2. Key findings (bullet points)
    3. Recommendations
    """
```

---

## Memory Considerations

### Token Limits

Conversations accumulate tokens. Monitor and manage:

```swift
// Check conversation length
let history = await session.messages
let estimatedTokens = history.reduce(0) { sum, msg in
    sum + (msg.content.textValue?.count ?? 0) / 4  // Rough estimate
}

if estimatedTokens > 3000 {
    // Consider clearing or summarizing
    await session.clearHistory()
}
```

### Context Window Management

```swift
// For MLX, you can count tokens accurately
let provider = MLXProvider()

let history = await session.messages
let tokenCount = try await provider.countTokens(in: history, for: model)

if tokenCount.count > 3500 {  // Leave room for response
    // Option 1: Clear
    await session.clearHistory()

    // Option 2: Summarize (advanced)
    // let summary = try await summarize(history)
    // await session.addMessage(.system("Previous context: \(summary)"))
}
```

### Memory on iOS

Be mindful of memory on mobile:

```swift
// Clear history when app backgrounds
NotificationCenter.default.addObserver(
    forName: UIApplication.didEnterBackgroundNotification,
    object: nil,
    queue: .main
) { _ in
    Task {
        await session.clearHistory()
    }
}
```

---

## SwiftUI Integration

### Basic Chat View

```swift
struct ChatView: View {
    @State private var messages: [(role: String, content: String)] = []
    @State private var input = ""
    @State private var isGenerating = false

    let session: ChatSession

    var body: some View {
        VStack {
            ScrollView {
                ForEach(messages.indices, id: \.self) { index in
                    MessageBubble(
                        role: messages[index].role,
                        content: messages[index].content
                    )
                }
            }

            HStack {
                TextField("Message", text: $input)
                    .textFieldStyle(.roundedBorder)

                Button("Send") {
                    Task { await sendMessage() }
                }
                .disabled(input.isEmpty || isGenerating)
            }
            .padding()
        }
    }

    func sendMessage() async {
        let userMessage = input
        input = ""
        isGenerating = true

        messages.append((role: "user", content: userMessage))

        do {
            let response = try await session.send(userMessage)
            messages.append((role: "assistant", content: response))
        } catch {
            messages.append((role: "error", content: error.localizedDescription))
        }

        isGenerating = false
    }
}
```

### With Streaming

```swift
struct StreamingChatView: View {
    @State private var messages: [ChatMessage] = []
    @State private var currentResponse = ""
    @State private var input = ""
    @State private var isGenerating = false

    let session: ChatSession

    var body: some View {
        VStack {
            ScrollView {
                ForEach(messages) { message in
                    MessageBubble(message: message)
                }

                if !currentResponse.isEmpty {
                    MessageBubble(message: ChatMessage(
                        role: .assistant,
                        content: currentResponse
                    ))
                }
            }

            HStack {
                TextField("Message", text: $input)
                Button("Send") {
                    Task { await sendMessage() }
                }
                .disabled(isGenerating)
            }
        }
    }

    func sendMessage() async {
        let userMessage = input
        input = ""
        isGenerating = true
        currentResponse = ""

        messages.append(ChatMessage(role: .user, content: userMessage))

        do {
            for try await text in session.streamResponse(userMessage) {
                currentResponse += text
            }

            // Move to permanent messages
            messages.append(ChatMessage(role: .assistant, content: currentResponse))
            currentResponse = ""
        } catch {
            messages.append(ChatMessage(role: .error, content: error.localizedDescription))
        }

        isGenerating = false
    }
}
```

### ViewModel Pattern

```swift
@Observable
class ChatViewModel {
    var messages: [ChatMessage] = []
    var currentInput = ""
    var isGenerating = false
    var streamingResponse = ""

    private let session: ChatSession

    init(session: ChatSession) {
        self.session = session
    }

    func send() async {
        guard !currentInput.isEmpty else { return }

        let input = currentInput
        currentInput = ""
        isGenerating = true

        messages.append(ChatMessage(role: .user, content: input))

        do {
            for try await text in session.streamResponse(input) {
                await MainActor.run {
                    streamingResponse += text
                }
            }

            await MainActor.run {
                messages.append(ChatMessage(role: .assistant, content: streamingResponse))
                streamingResponse = ""
            }
        } catch {
            await MainActor.run {
                messages.append(ChatMessage(role: .error, content: error.localizedDescription))
            }
        }

        await MainActor.run {
            isGenerating = false
        }
    }

    func clearHistory() async {
        await session.clearHistory()
        await MainActor.run {
            messages = []
        }
    }
}
```

---

## Next Steps

- [Streaming](Streaming.md) - Advanced streaming patterns
- [Providers](Providers/README.md) - Provider-specific considerations
- [Error Handling](ErrorHandling.md) - Handle errors gracefully
- [Model Management](ModelManagement.md) - Download and cache models
