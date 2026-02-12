// AnthropicProviderTests.swift
// Conduit
//
// Unit tests for Anthropic provider components.

#if CONDUIT_TRAIT_ANTHROPIC
import Testing
import Foundation
@testable import Conduit

// MARK: - Test Helpers

@Generable
private struct AnthropicStructuredOutputFixture {
    let city: String
    let temperature: Int
}

private struct AnthropicNoopTool: Tool {
    let name = "anthropic_noop_tool"
    let description = "No-op test tool."

    func call(arguments: GeneratedContent) async throws -> String {
        "ok"
    }
}


// MARK: - Configuration Tests

@Suite("Anthropic Configuration Tests")
struct AnthropicConfigurationTests {

    @Test("Default configuration uses Anthropic endpoint")
    func defaultConfiguration() throws {
        let config = try AnthropicConfiguration()
        #expect(config.baseURL.absoluteString == "https://api.anthropic.com")
        #expect(config.apiVersion == "2023-06-01")
        #expect(config.timeout == 60.0)
        #expect(config.maxRetries == 3)
    }

    @Test("Standard config with API key")
    func standardConfig() {
        let config = AnthropicConfiguration.standard(apiKey: "sk-ant-test")
        #expect(config.authentication.apiKey == "sk-ant-test")
        #expect(config.hasValidAuthentication == true)
    }

    @Test("Build headers includes X-Api-Key and anthropic-version")
    func buildHeaders() {
        let config = AnthropicConfiguration.standard(apiKey: "sk-ant-test")
        let headers = config.buildHeaders()

        #expect(headers["X-Api-Key"] == "sk-ant-test")
        #expect(headers["anthropic-version"] == "2023-06-01")
        #expect(headers["Content-Type"] == "application/json")
    }

    @Test("Negative timeout is clamped to zero")
    func timeoutClamping() throws {
        let config = try AnthropicConfiguration(timeout: -10.0)
        #expect(config.timeout == 0.0)
    }

    @Test("Thinking configuration validates budget tokens")
    func thinkingConfig() {
        let thinking = ThinkingConfiguration(enabled: true, budgetTokens: -100)
        #expect(thinking.budgetTokens == 0) // Clamped

        let standard = ThinkingConfiguration.standard
        #expect(standard.enabled == true)
        #expect(standard.budgetTokens == 1024)
    }

    @Test("HTTPS URL is accepted")
    func httpsURLAccepted() throws {
        let config = try AnthropicConfiguration(
            baseURL: makeTestURL("https://custom.api.example.com")
        )
        #expect(config.baseURL.absoluteString == "https://custom.api.example.com")
    }

    @Test("HTTP URL is rejected")
    func httpURLRejected() {
        #expect(throws: AIError.self) {
            _ = try AnthropicConfiguration(
                baseURL: makeTestURL("http://insecure.api.example.com")
            )
        }
    }

    @Test("Localhost HTTP is allowed for development")
    func localhostHTTPAllowed() throws {
        // localhost hostname
        let localhost = try AnthropicConfiguration(
            baseURL: makeTestURL("http://localhost:8080")
        )
        #expect(localhost.baseURL.host == "localhost")

        // 127.0.0.1
        let ipv4 = try AnthropicConfiguration(
            baseURL: makeTestURL("http://127.0.0.1:8080")
        )
        #expect(ipv4.baseURL.host == "127.0.0.1")

        // IPv6 loopback
        let ipv6 = try AnthropicConfiguration(
            baseURL: makeTestURL("http://[::1]:8080")
        )
        #expect(ipv6.baseURL.host == "::1")
    }

    @Test("Fluent baseURL validates HTTPS")
    func fluentBaseURLValidatesHTTPS() throws {
        let config = AnthropicConfiguration.standard(apiKey: "sk-ant-test")

        // HTTPS should work
        let httpsConfig = try config.baseURL(makeTestURL("https://custom.example.com"))
        #expect(httpsConfig.baseURL.absoluteString == "https://custom.example.com")

        // HTTP should throw
        #expect(throws: AIError.self) {
            _ = try config.baseURL(makeTestURL("http://insecure.example.com"))
        }
    }
}

// MARK: - Authentication Tests

@Suite("Anthropic Authentication Tests")
struct AnthropicAuthenticationTests {

    @Test("API key authentication resolves correctly")
    func apiKeyAuth() {
        let auth = AnthropicAuthentication.apiKey("sk-ant-test")
        #expect(auth.apiKey == "sk-ant-test")
        #expect(auth.isValid == true)
    }

    @Test("Auto authentication reads ANTHROPIC_API_KEY env var")
    func autoAuth() {
        // Note: This test depends on environment variable
        // Will be nil if not set, which is expected behavior
        let auth = AnthropicAuthentication.auto
        let envKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]
        #expect(auth.apiKey == envKey)
    }

    @Test("Empty API key is not valid")
    func emptyKeyNotValid() {
        let auth = AnthropicAuthentication.apiKey("")
        #expect(auth.isValid == false)
    }

    @Test("Hashable conformance works")
    func hashableConformance() {
        let auth1 = AnthropicAuthentication.apiKey("key1")
        let auth2 = AnthropicAuthentication.apiKey("key1")
        let auth3 = AnthropicAuthentication.apiKey("key2")

        #expect(auth1 == auth2)
        #expect(auth1 != auth3)
    }
}

// MARK: - Model ID Tests

@Suite("Anthropic Model ID Tests")
struct AnthropicModelIDTests {

    @Test("Static model properties have correct rawValue")
    func staticModels() {
        #expect(AnthropicModelID.claudeOpus45.rawValue == "claude-opus-4-5-20251101")
        #expect(AnthropicModelID.claudeSonnet45.rawValue == "claude-sonnet-4-5-20250929")
        #expect(AnthropicModelID.claude35Sonnet.rawValue == "claude-3-5-sonnet-20241022")
        #expect(AnthropicModelID.claude3Opus.rawValue == "claude-3-opus-20240229")
        #expect(AnthropicModelID.claude3Haiku.rawValue == "claude-3-haiku-20240307")
    }

    @Test("Display name exists")
    func displayName() {
        let model = AnthropicModelID.claudeSonnet45
        #expect(!model.displayName.isEmpty)
        #expect(model.displayName == "claude-sonnet-4-5")
    }

    @Test("Provider type is anthropic")
    func providerType() {
        #expect(AnthropicModelID.claudeOpus45.provider == .anthropic)
    }

    @Test("String literal initialization")
    func stringLiteral() {
        let model: AnthropicModelID = "claude-test-123"
        #expect(model.rawValue == "claude-test-123")
    }

    @Test("Codable encoding and decoding")
    func codable() throws {
        let model = AnthropicModelID.claudeSonnet45
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(model)
        let decoded = try decoder.decode(AnthropicModelID.self, from: data)

        #expect(decoded.rawValue == model.rawValue)
    }
}

// MARK: - Error Mapping Tests

@Suite("Anthropic Error Mapping Tests")
struct AnthropicErrorMappingTests {

    @Test("invalid_request_error maps to invalidInput")
    func invalidRequestError() async {
        let provider = AnthropicProvider(apiKey: "sk-ant-test")
        let errorResponse = AnthropicErrorResponse(
            error: .init(type: "invalid_request_error", message: "Invalid input")
        )
        let aiError = await provider.mapAnthropicError(errorResponse, statusCode: 400)

        if case .invalidInput(let msg) = aiError {
            #expect(msg == "Invalid input")
        } else {
            Issue.record("Expected invalidInput error")
        }
    }

    @Test("authentication_error maps to authenticationFailed")
    func authenticationError() async {
        let provider = AnthropicProvider(apiKey: "sk-ant-test")
        let errorResponse = AnthropicErrorResponse(
            error: .init(type: "authentication_error", message: "Invalid API key")
        )
        let aiError = await provider.mapAnthropicError(errorResponse, statusCode: 401)

        if case .authenticationFailed(let msg) = aiError {
            #expect(msg == "Invalid API key")
        } else {
            Issue.record("Expected authenticationFailed error")
        }
    }

    @Test("rate_limit_error maps to rateLimited")
    func rateLimitError() async {
        let provider = AnthropicProvider(apiKey: "sk-ant-test")
        let errorResponse = AnthropicErrorResponse(
            error: .init(type: "rate_limit_error", message: "Rate limit exceeded")
        )
        let aiError = await provider.mapAnthropicError(errorResponse, statusCode: 429)

        if case .rateLimited = aiError {
            // Success
        } else {
            Issue.record("Expected rateLimited error")
        }
    }

    @Test("timeout_error maps to timeout")
    func timeoutError() async {
        let provider = AnthropicProvider(apiKey: "sk-ant-test")
        let errorResponse = AnthropicErrorResponse(
            error: .init(type: "timeout_error", message: "Request timed out")
        )
        let aiError = await provider.mapAnthropicError(errorResponse, statusCode: 408)

        if case .timeout = aiError {
            // Success
        } else {
            Issue.record("Expected timeout error")
        }
    }

    @Test("unknown error maps to generationFailed")
    func unknownError() async {
        let provider = AnthropicProvider(apiKey: "sk-ant-test")
        let errorResponse = AnthropicErrorResponse(
            error: .init(type: "unknown_future_error", message: "Unknown error")
        )
        let aiError = await provider.mapAnthropicError(errorResponse, statusCode: 500)

        if case .generationFailed = aiError {
            // Success
        } else {
            Issue.record("Expected generationFailed error")
        }
    }
}

// MARK: - Request Building Tests

@Suite("Anthropic Request Building Tests")
struct AnthropicRequestBuildingTests {

    @Test("buildRequestBody creates correct structure")
    func buildRequestBody() async {
        let provider = AnthropicProvider(apiKey: "sk-ant-test")
        let messages = [
            Message.user("Hello"),
            Message.assistant("Hi there")
        ]
        let model = AnthropicModelID.claudeSonnet45
        let config = GenerateConfig(maxTokens: 100, temperature: 0.7)

        let request = await provider.buildRequestBody(
            messages: messages,
            model: model,
            config: config,
            stream: false
        )

        #expect(request.model == "claude-sonnet-4-5-20250929")
        #expect(request.maxTokens == 100)
        #expect(request.temperature != nil)
        #expect(abs(request.temperature! - 0.7) < 0.01) // Floating point comparison
        #expect(request.stream == nil) // False is represented as nil
        #expect(request.messages.count == 2)
    }

    @Test("System messages go in separate field")
    func systemMessageHandling() async {
        let provider = AnthropicProvider(apiKey: "sk-ant-test")
        let messages = [
            Message.system("You are helpful"),
            Message.user("Hello")
        ]
        let model = AnthropicModelID.claudeSonnet45
        let config = GenerateConfig.default

        let request = await provider.buildRequestBody(
            messages: messages,
            model: model,
            config: config
        )

        #expect(request.system == "You are helpful")
        #expect(request.messages.count == 1) // System not in messages array
        #expect(request.messages[0].role == "user")
    }

    @Test("Stream flag sets correctly")
    func streamFlag() async {
        let provider = AnthropicProvider(apiKey: "sk-ant-test")
        let messages = [Message.user("Test")]

        let streamRequest = await provider.buildRequestBody(
            messages: messages,
            model: .claudeSonnet45,
            config: .default,
            stream: true
        )

        #expect(streamRequest.stream == true)
    }

    @Test("Thinking configuration adds thinking field")
    func thinkingInRequest() async {
        var config = AnthropicConfiguration.standard(apiKey: "sk-ant-test")
        config.thinkingConfig = .standard

        let provider = AnthropicProvider(configuration: config)
        let messages = [Message.user("Test")]

        let request = await provider.buildRequestBody(
            messages: messages,
            model: .claudeSonnet45,
            config: .default
        )

        #expect(request.thinking != nil)
        #expect(request.thinking?.type == "enabled")
        #expect(request.thinking?.budget_tokens == 1024)
    }

    @Test("jsonObject responseFormat adds deterministic JSON instruction")
    func jsonObjectResponseFormatInstruction() async {
        let provider = AnthropicProvider(apiKey: "sk-ant-test")
        let messages = [Message.user("Return a JSON object")]
        let config = GenerateConfig.default.responseFormat(.jsonObject)

        let request = await provider.buildRequestBody(
            messages: messages,
            model: .claudeSonnet45,
            config: config
        )

        #expect(request.system != nil)
        #expect(request.system?.contains("Return only valid JSON") == true)
        #expect(request.system?.contains("Do not wrap JSON in markdown") == true)
    }

    @Test("jsonSchema responseFormat appends schema instruction and preserves system prompt")
    func jsonSchemaResponseFormatInstruction() async {
        let provider = AnthropicProvider(apiKey: "sk-ant-test")
        let messages = [
            Message.system("You are a weather assistant."),
            Message.user("Give weather as structured data.")
        ]
        let config = GenerateConfig.default.responseFormat(
            .jsonSchema(
                name: "AnthropicStructuredOutputFixture",
                schema: AnthropicStructuredOutputFixture.generationSchema
            )
        )

        let request = await provider.buildRequestBody(
            messages: messages,
            model: .claudeSonnet45,
            config: config
        )

        #expect(request.system?.contains("You are a weather assistant.") == true)
        #expect(request.system?.contains("Return only valid JSON") == true)
        #expect(request.system?.contains("AnthropicStructuredOutputFixture") == true)
        #expect(request.system?.contains("\"properties\"") == true)
    }

    @Test("responseFormat instruction is not injected when tools are enabled")
    func responseFormatWithToolsDoesNotInjectJSONOnlyInstruction() async {
        let provider = AnthropicProvider(apiKey: "sk-ant-test")
        let messages = [Message.user("Use tool if needed.")]
        let config = GenerateConfig.default
            .tools([AnthropicNoopTool()])
            .responseFormat(.jsonObject)

        let request = await provider.buildRequestBody(
            messages: messages,
            model: .claudeSonnet45,
            config: config
        )

        #expect(request.tools != nil)
        #expect(request.system?.contains("Return only valid JSON") != true)
    }

    @Test("Tool outputs are encoded as tool_result blocks")
    func toolOutputEncoding() async {
        let provider = AnthropicProvider(apiKey: "sk-ant-test")
        let output = Transcript.ToolOutput(
            id: "toolu_123",
            toolName: "get_weather",
            segments: [.text(.init(content: "65 degrees"))]
        )
        let messages = [
            Message.user("What is the weather?"),
            Message.assistant("Let me check."),
            Message.toolOutput(output)
        ]

        let request = await provider.buildRequestBody(
            messages: messages,
            model: .claudeSonnet45,
            config: .default
        )

        #expect(request.messages.count == 3)

        guard let toolMessage = request.messages.last else {
            Issue.record("Missing tool message")
            return
        }

        #expect(toolMessage.role == "user")

        switch toolMessage.content {
        case .multipart(let parts):
            #expect(parts.count == 1)
            let part = parts[0]
            #expect(part.type == "tool_result")
            #expect(part.toolUseId == "toolu_123")
            #expect(part.content == "65 degrees")
        case .text:
            Issue.record("Expected multipart tool_result content")
        }
    }

    @Test("Assistant tool calls are encoded as tool_use blocks")
    func assistantToolCallEncoding() async throws {
        let provider = AnthropicProvider(apiKey: "sk-ant-test")
        let arguments = GeneratedContent(properties: ["expression": "2+2"])
        let toolCall = Transcript.ToolCall(id: "toolu_456", toolName: "calculator", arguments: arguments)
        let messages = [
            Message.assistant("Calling a tool.", toolCalls: [toolCall])
        ]

        let request = await provider.buildRequestBody(
            messages: messages,
            model: .claudeSonnet45,
            config: .default
        )

        #expect(request.messages.count == 1)

        guard let assistantMessage = request.messages.first else {
            Issue.record("Missing assistant message")
            return
        }

        switch assistantMessage.content {
        case .multipart(let parts):
            #expect(parts.count == 2)
            #expect(parts[0].type == "text")
            #expect(parts[1].type == "tool_use")
            #expect(parts[1].id == "toolu_456")
            #expect(parts[1].name == "calculator")
        case .text:
            Issue.record("Expected multipart content with tool_use block")
        }
    }
}

// MARK: - Response Parsing Tests

@Suite("Anthropic Response Parsing Tests")
struct AnthropicResponseParsingTests {

    @Test("Parse successful response")
    func successfulResponse() async throws {
        let provider = AnthropicProvider(apiKey: "sk-ant-test")
        let response = AnthropicMessagesResponse(
            id: "msg_123",
            type: "message",
            role: "assistant",
            content: [
                .init(type: "text", text: "Hello, world!", id: nil, name: nil, input: nil)
            ],
            model: "claude-sonnet-4-5-20250929",
            stopReason: "end_turn",
            usage: .init(inputTokens: 10, outputTokens: 5)
        )

        let result = try await provider.convertToGenerationResult(response, startTime: Date())

        #expect(result.text == "Hello, world!")
        #expect(result.tokenCount == 5)
        #expect(result.finishReason == .stop)
        #expect(result.usage?.promptTokens == 10)
        #expect(result.usage?.completionTokens == 5)
    }

    @Test("Extract text from content blocks")
    func textExtraction() async throws {
        let provider = AnthropicProvider(apiKey: "sk-ant-test")
        let response = AnthropicMessagesResponse(
            id: "msg_123",
            type: "message",
            role: "assistant",
            content: [
                .init(type: "text", text: "Part 1", id: nil, name: nil, input: nil),
                .init(type: "text", text: " Part 2", id: nil, name: nil, input: nil)
            ],
            model: "claude-sonnet-4-5-20250929",
            stopReason: "end_turn",
            usage: .init(inputTokens: 10, outputTokens: 5)
        )

        let result = try await provider.convertToGenerationResult(response, startTime: Date())
        #expect(result.text == "Part 1 Part 2")
    }

    @Test("Filter thinking blocks from response")
    func thinkingBlocks() async throws {
        let provider = AnthropicProvider(apiKey: "sk-ant-test")
        let response = AnthropicMessagesResponse(
            id: "msg_123",
            type: "message",
            role: "assistant",
            content: [
                .init(type: "thinking", text: "Internal reasoning...", id: nil, name: nil, input: nil),
                .init(type: "text", text: "User response", id: nil, name: nil, input: nil)
            ],
            model: "claude-sonnet-4-5-20250929",
            stopReason: "end_turn",
            usage: .init(inputTokens: 10, outputTokens: 15)
        )

        let result = try await provider.convertToGenerationResult(response, startTime: Date())
        #expect(result.text == "User response") // Thinking filtered out
    }

    @Test("Map stop_reason to FinishReason")
    func stopReasonMapping() async throws {
        let provider = AnthropicProvider(apiKey: "sk-ant-test")

        // Test end_turn
        let endTurn = AnthropicMessagesResponse(
            id: "msg_1", type: "message", role: "assistant",
            content: [.init(type: "text", text: "Done", id: nil, name: nil, input: nil)],
            model: "test", stopReason: "end_turn",
            usage: .init(inputTokens: 1, outputTokens: 1)
        )
        let result1 = try await provider.convertToGenerationResult(endTurn, startTime: Date())
        #expect(result1.finishReason == .stop)

        // Test max_tokens
        let maxTokens = AnthropicMessagesResponse(
            id: "msg_2", type: "message", role: "assistant",
            content: [.init(type: "text", text: "Done", id: nil, name: nil, input: nil)],
            model: "test", stopReason: "max_tokens",
            usage: .init(inputTokens: 1, outputTokens: 1)
        )
        let result2 = try await provider.convertToGenerationResult(maxTokens, startTime: Date())
        #expect(result2.finishReason == .maxTokens)
    }
}

// MARK: - Streaming Event Tests

@Suite("Anthropic Streaming Event Tests")
struct AnthropicStreamingEventTests {

    @Test("Parse content_block_delta event")
    func contentBlockDeltaEvent() async throws {
        let provider = AnthropicProvider(apiKey: "sk-ant-test")
        let json = """
        {
            "type": "content_block_delta",
            "index": 0,
            "delta": {
                "type": "text_delta",
                "text": "Hello"
            }
        }
        """
        guard let data = json.data(using: .utf8) else {
            Issue.record("Failed to convert test JSON to Data")
            return
        }

        let event = try await provider.parseStreamEvent(from: data)

        if case .contentBlockDelta(let delta) = event {
            #expect(delta.index == 0)
            #expect(delta.delta.text == "Hello")
        } else {
            Issue.record("Expected content_block_delta event")
        }
    }

    @Test("Parse message_start event")
    func messageStartEvent() async throws {
        let provider = AnthropicProvider(apiKey: "sk-ant-test")
        let json = """
        {
            "type": "message_start",
            "message": {
                "id": "msg_123",
                "type": "message",
                "role": "assistant",
                "content": [],
                "model": "claude-sonnet-4-5-20250929",
                "stop_reason": null,
                "stop_sequence": null
            }
        }
        """
        guard let data = json.data(using: .utf8) else {
            Issue.record("Failed to convert test JSON to Data")
            return
        }

        let event = try await provider.parseStreamEvent(from: data)

        if case .messageStart(let start) = event {
            #expect(start.message.id == "msg_123")
            #expect(start.message.model == "claude-sonnet-4-5-20250929")
        } else {
            Issue.record("Expected message_start event")
        }
    }

    @Test("processStreamEvent only yields chunks for delta events")
    func skipNonDeltaEvents() async throws {
        let provider = AnthropicProvider(apiKey: "sk-ant-test")
        var tokenCount = 0
        var activeToolCalls: [Int: (id: String, name: String, jsonBuffer: String)] = [:]
        var completedToolCalls: [Transcript.ToolCall] = []

        // message_start should not yield
        let messageStart = AnthropicStreamEvent.MessageStart(
            message: .init(id: "msg_1", type: "message", role: "assistant",
                          content: [], model: "test",
                          stopReason: nil, stopSequence: nil)
        )
        let chunk1 = try await provider.processStreamEvent(
            .messageStart(messageStart),
            startTime: Date(),
            totalTokens: &tokenCount,
            activeToolCalls: &activeToolCalls,
            completedToolCalls: &completedToolCalls
        )
        #expect(chunk1 == nil)

        // content_block_stop should not yield
        let stopEvent = AnthropicStreamEvent.ContentBlockStop(index: 0)
        let chunk2 = try await provider.processStreamEvent(
            .contentBlockStop(stopEvent),
            startTime: Date(),
            totalTokens: &tokenCount,
            activeToolCalls: &activeToolCalls,
            completedToolCalls: &completedToolCalls
        )
        #expect(chunk2 == nil)

        // content_block_delta should yield
        let delta = AnthropicStreamEvent.ContentBlockDelta(
            index: 0,
            delta: .init(type: "text_delta", text: "Hi", partialJson: nil)
        )
        let chunk3 = try await provider.processStreamEvent(
            .contentBlockDelta(delta),
            startTime: Date(),
            totalTokens: &tokenCount,
            activeToolCalls: &activeToolCalls,
            completedToolCalls: &completedToolCalls
        )
        #expect(chunk3 != nil)
        #expect(chunk3?.text == "Hi")
    }

    @Test("Unknown event type returns nil")
    func unknownEventType() async throws {
        let provider = AnthropicProvider(apiKey: "sk-ant-test")
        let json = """
        {
            "type": "future_event_type",
            "data": {}
        }
        """
        guard let data = json.data(using: .utf8) else {
            Issue.record("Failed to convert test JSON to Data")
            return
        }

        let event = try await provider.parseStreamEvent(from: data)
        #expect(event == nil) // Unknown types gracefully return nil
    }
}

// MARK: - Provider Availability Tests

@Suite("Anthropic Provider Availability Tests")
struct AnthropicProviderAvailabilityTests {

    @Test("Provider is available with valid API key")
    func availableWithValidKey() async {
        let provider = AnthropicProvider(apiKey: "sk-ant-test")
        let isAvailable = await provider.isAvailable
        #expect(isAvailable == true)
    }

    @Test("Provider unavailable with empty API key")
    func unavailableWithEmptyKey() async {
        let config = AnthropicConfiguration.standard(apiKey: "")
        let provider = AnthropicProvider(configuration: config)
        let isAvailable = await provider.isAvailable
        #expect(isAvailable == false)
    }

    @Test("Availability status returns correct reason")
    func availabilityStatusReason() async {
        let config = AnthropicConfiguration.standard(apiKey: "")
        let provider = AnthropicProvider(configuration: config)
        let status = await provider.availabilityStatus

        #expect(status.isAvailable == false)
        #expect(status.unavailableReason == .apiKeyMissing)
    }
}

#endif // CONDUIT_TRAIT_ANTHROPIC
