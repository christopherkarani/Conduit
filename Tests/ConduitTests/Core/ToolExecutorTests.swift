// ToolExecutorTests.swift
// Conduit Tests
//
// Comprehensive tests for the ToolExecutor actor.

import Foundation
import Testing
@testable import Conduit

// MARK: - Mock Tools

/// A simple mock tool for testing basic functionality.
struct MockTool: Tool {
    @Generable
    struct Arguments {
        let input: String
    }

    let name = "mock_tool"
    let description = "A mock tool for testing"

    func call(arguments: Arguments) async throws -> String {
        "Result: \(arguments.input)"
    }
}

/// A second mock tool for testing multiple tool registration.
struct AnotherMockTool: Tool {
    @Generable
    struct Arguments {
        let value: Int
    }

    let name = "another_tool"
    let description = "Another mock tool for testing"

    func call(arguments: Arguments) async throws -> String {
        "Value doubled: \(arguments.value * 2)"
    }
}

/// A mock tool that always throws for testing error propagation.
struct ThrowingMockTool: Tool {
    @Generable
    struct Arguments {
        let message: String
    }

    struct AlwaysFailsError: Error, LocalizedError {
        var errorDescription: String? { "Always fails" }
    }

    let name = "throwing_mock_tool"
    let description = "A tool that always throws"

    func call(arguments: Arguments) async throws -> String {
        throw AlwaysFailsError()
    }
}

/// A mock tool that throws an error for testing error handling.
struct FailingTool: Tool {
    @Generable
    struct Arguments {
        let shouldFail: Bool
    }

    struct ToolExecutionError: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    let name = "failing_tool"
    let description = "A tool that can fail for testing"

    func call(arguments: Arguments) async throws -> String {
        if arguments.shouldFail {
            throw ToolExecutionError(message: "Intentional test failure")
        }
        return "Success"
    }
}

/// A slow mock tool for testing concurrent execution.
struct SlowTool: Tool {
    @Generable
    struct Arguments {
        let delay: Double
        let requestID: String
    }

    let name = "slow_tool"
    let description = "A slow tool for testing concurrency"

    func call(arguments: Arguments) async throws -> String {
        try await Task.sleep(nanoseconds: UInt64(arguments.delay * 1_000_000_000))
        return "Completed: \(arguments.requestID)"
    }
}

/// A tool with a custom name for testing name replacement.
struct CustomNameTool: Tool {
    @Generable
    struct Arguments {}

    let customName: String
    var name: String { customName }
    let description = "A tool with custom name"

    init(name: String) {
        self.customName = name
    }

    func call(arguments: Arguments) async throws -> String {
        "Custom tool: \(customName)"
    }
}

/// Records tool invocation attempts for retry-policy assertions.
actor FlakyToolAttemptRecorder {
    private var attempts: Int = 0

    func recordAttempt() -> Int {
        attempts += 1
        return attempts
    }

    var attemptCount: Int { attempts }
}

/// A flaky tool that fails with retryable `AIError` for a fixed number of attempts.
struct FlakyRetryableAIErrorTool: Tool {
    @Generable
    struct Arguments {
        let input: String
    }

    let name = "flaky_retryable_ai_error_tool"
    let description = "Fails with AIError.timeout before succeeding"
    let failuresBeforeSuccess: Int
    let recorder: FlakyToolAttemptRecorder

    func call(arguments: Arguments) async throws -> String {
        let attempt = await recorder.recordAttempt()
        guard attempt > failuresBeforeSuccess else {
            throw AIError.timeout(0.01)
        }
        return "Recovered: \(arguments.input)"
    }
}

/// A flaky tool that fails with non-AI errors for a fixed number of attempts.
struct FlakyNonAIErrorTool: Tool {
    @Generable
    struct Arguments {
        let input: String
    }

    struct NonAIError: Error, Sendable {}

    let name = "flaky_non_ai_error_tool"
    let description = "Fails with non-AI errors before succeeding"
    let failuresBeforeSuccess: Int
    let recorder: FlakyToolAttemptRecorder

    func call(arguments: Arguments) async throws -> String {
        let attempt = await recorder.recordAttempt()
        guard attempt > failuresBeforeSuccess else {
            throw NonAIError()
        }
        return "Recovered non-ai: \(arguments.input)"
    }
}

// MARK: - Test Suite

@Suite("ToolExecutor Tests")
struct ToolExecutorTests {

    // MARK: - Registration Tests

    @Suite("Registration")
    struct RegistrationTests {

        @Test("Register single tool")
        func registerSingleTool() async {
            let executor = ToolExecutor()
            await executor.register(MockTool())

            let names = await executor.registeredToolNames
            #expect(names.contains("mock_tool"))
            #expect(names.count == 1)
        }

        @Test("Register multiple tools")
        func registerMultipleTools() async {
            let executor = ToolExecutor()
            await executor.register(MockTool())
            await executor.register(AnotherMockTool())

            let names = await executor.registeredToolNames
            #expect(names.count == 2)
            #expect(names.contains("mock_tool"))
            #expect(names.contains("another_tool"))
        }

        @Test("Register tools via array")
        func registerToolsViaArray() async {
            let executor = ToolExecutor()
            await executor.register([MockTool(), AnotherMockTool(), FailingTool()])

            let names = await executor.registeredToolNames
            #expect(names.count == 3)
            #expect(names.contains("mock_tool"))
            #expect(names.contains("another_tool"))
            #expect(names.contains("failing_tool"))
        }

        @Test("Get tool definitions")
        func getToolDefinitions() async {
            let executor = ToolExecutor()
            await executor.register(MockTool())
            await executor.register(AnotherMockTool())

            let definitions = await executor.toolDefinitions
            #expect(definitions.count == 2)

            let mockDef = definitions.first { $0.name == "mock_tool" }
            #expect(mockDef != nil)
            #expect(mockDef?.description == "A mock tool for testing")

            let anotherDef = definitions.first { $0.name == "another_tool" }
            #expect(anotherDef != nil)
            #expect(anotherDef?.description == "Another mock tool for testing")
        }

        @Test("Replace existing tool with same name")
        func replaceExistingTool() async {
            let executor = ToolExecutor()

            // Register first version
            await executor.register(CustomNameTool(name: "shared_name"))

            // Replace with second version (same name)
            await executor.register(CustomNameTool(name: "shared_name"))

            let names = await executor.registeredToolNames
            #expect(names.count == 1)
            #expect(names.contains("shared_name"))
        }

        @Test("Initialize with tools")
        func initializeWithTools() async {
            let tools: [any Tool] = [MockTool(), AnotherMockTool()]
            let executor = ToolExecutor(tools: tools)

            let names = await executor.registeredToolNames
            #expect(names.count == 2)
            #expect(names.contains("mock_tool"))
            #expect(names.contains("another_tool"))
        }
    }

    // MARK: - Execution Tests

    @Suite("Execution")
    struct ExecutionTests {

        @Test("Execute tool with valid arguments")
        func executeWithValidArguments() async throws {
            let executor = ToolExecutor()
            await executor.register(MockTool())

            let toolCall = try Transcript.ToolCall(
                id: "call_123",
                toolName: "mock_tool",
                argumentsJSON: #"{"input": "test value"}"#
            )

            let output = try await executor.execute(toolCall: toolCall)
            #expect(output.id == "call_123")
            #expect(output.toolName == "mock_tool")
            #expect(output.text == "Result: test value")
        }

        @Test("Execute returns correct Transcript.ToolOutput")
        func executeReturnsCorrectOutput() async throws {
            let executor = ToolExecutor()
            await executor.register(AnotherMockTool())

            let toolCall = try Transcript.ToolCall(
                id: "call_456",
                toolName: "another_tool",
                argumentsJSON: #"{"value": 21}"#
            )

            let output = try await executor.execute(toolCall: toolCall)
            #expect(output.id == "call_456")
            #expect(output.toolName == "another_tool")
            #expect(output.text == "Value doubled: 42")
        }

        @Test("Execute non-existent tool throws toolNotFound")
        func executeNonExistentToolThrows() async throws {
            let executor = ToolExecutor()
            await executor.register(MockTool())

            let toolCall = try Transcript.ToolCall(
                id: "call_789",
                toolName: "nonexistent_tool",
                argumentsJSON: #"{}"#
            )

            await #expect(throws: AIError.self) {
                _ = try await executor.execute(toolCall: toolCall)
            }
        }

        @Test("Execute with invalid arguments throws error")
        func executeWithInvalidArgumentsThrows() async throws {
            let executor = ToolExecutor()
            await executor.register(MockTool())

            // Wrong type for "input" (expects a string)
            let toolCall = try Transcript.ToolCall(
                id: "call_invalid",
                toolName: "mock_tool",
                argumentsJSON: #"{"input": 123}"#
            )

            await #expect(throws: GeneratedContentConversionError.self) {
                _ = try await executor.execute(toolCall: toolCall)
            }
        }

        @Test("Multiple sequential executions work")
        func multipleSequentialExecutions() async throws {
            let executor = ToolExecutor()
            await executor.register(MockTool())

            for i in 1...5 {
                let toolCall = try Transcript.ToolCall(
                    id: "call_\(i)",
                    toolName: "mock_tool",
                    argumentsJSON: #"{"input": "test \#(i)"}"#
                )

                let output = try await executor.execute(toolCall: toolCall)
                #expect(output.id == "call_\(i)")
                #expect(output.text == "Result: test \(i)")
            }
        }
    }

    // MARK: - Concurrent Execution Tests

    @Suite("Concurrent Execution")
    struct ConcurrentExecutionTests {

        @Test("Execute multiple tools concurrently")
        func executeMultipleToolsConcurrently() async throws {
            let executor = ToolExecutor()
            await executor.register(MockTool())
            await executor.register(AnotherMockTool())

            let toolCalls = [
                try Transcript.ToolCall(
                    id: "call_1",
                    toolName: "mock_tool",
                    argumentsJSON: #"{"input": "first"}"#
                ),
                try Transcript.ToolCall(
                    id: "call_2",
                    toolName: "another_tool",
                    argumentsJSON: #"{"value": 10}"#
                ),
                try Transcript.ToolCall(
                    id: "call_3",
                    toolName: "mock_tool",
                    argumentsJSON: #"{"input": "third"}"#
                )
            ]

            let outputs = try await executor.execute(toolCalls: toolCalls)
            #expect(outputs.count == 3)

            // Results should be in order
            #expect(outputs[0].id == "call_1")
            #expect(outputs[0].text == "Result: first")
            #expect(outputs[1].id == "call_2")
            #expect(outputs[1].text == "Value doubled: 20")
            #expect(outputs[2].id == "call_3")
            #expect(outputs[2].text == "Result: third")
        }

        @Test("Results maintain order regardless of completion time")
        func resultsMaintainOrder() async throws {
            let executor = ToolExecutor()
            await executor.register(SlowTool())

            // Create calls with varying delays - later ones complete faster
            let toolCalls = [
                try Transcript.ToolCall(
                    id: "slow",
                    toolName: "slow_tool",
                    argumentsJSON: #"{"delay": 0.05, "requestID": "A"}"#
                ),
                try Transcript.ToolCall(
                    id: "medium",
                    toolName: "slow_tool",
                    argumentsJSON: #"{"delay": 0.02, "requestID": "B"}"#
                ),
                try Transcript.ToolCall(
                    id: "fast",
                    toolName: "slow_tool",
                    argumentsJSON: #"{"delay": 0.01, "requestID": "C"}"#
                )
            ]

            let outputs = try await executor.execute(toolCalls: toolCalls)

            // Despite completing in different order, results should be sorted by original index
            #expect(outputs[0].id == "slow")
            #expect(outputs[0].text == "Completed: A")
            #expect(outputs[1].id == "medium")
            #expect(outputs[1].text == "Completed: B")
            #expect(outputs[2].id == "fast")
            #expect(outputs[2].text == "Completed: C")
        }

        @Test("Partial failure breaks concurrent execution")
        func partialFailureBreaksConcurrentExecution() async throws {
            let executor = ToolExecutor()
            await executor.register(MockTool())
            await executor.register(FailingTool())

            let toolCalls = [
                try Transcript.ToolCall(
                    id: "call_1",
                    toolName: "mock_tool",
                    argumentsJSON: #"{"input": "success"}"#
                ),
                try Transcript.ToolCall(
                    id: "call_2",
                    toolName: "failing_tool",
                    argumentsJSON: #"{"shouldFail": true}"#
                ),
                try Transcript.ToolCall(
                    id: "call_3",
                    toolName: "mock_tool",
                    argumentsJSON: #"{"input": "also success"}"#
                )
            ]

            // The whole batch should fail if any tool fails
            await #expect(throws: FailingTool.ToolExecutionError.self) {
                _ = try await executor.execute(toolCalls: toolCalls)
            }
        }

        @Test("Cancellation is respected")
        func cancellationIsRespected() async throws {
            let executor = ToolExecutor()
            await executor.register(SlowTool())

            let toolCalls = [
                try Transcript.ToolCall(
                    id: "call_1",
                    toolName: "slow_tool",
                    argumentsJSON: #"{"delay": 10.0, "requestID": "very slow"}"#
                )
            ]

            let task = Task {
                try await executor.execute(toolCalls: toolCalls)
            }

            // Cancel after a short delay
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            task.cancel()

            // The task should throw CancellationError
            do {
                _ = try await task.value
                Issue.record("Expected cancellation error")
            } catch is CancellationError {
                // Expected
            } catch {
                // Some other error during cancellation is acceptable
            }
        }
    }

    // MARK: - Error Handling Tests

    @Suite("Error Handling")
    struct ErrorHandlingTests {

        @Test("Tool not found returns invalidInput")
        func toolNotFoundReturnsInvalidInput() async throws {
            let executor = ToolExecutor()
            await executor.register(MockTool())

            let toolCall = try Transcript.ToolCall(
                id: "call_1",
                toolName: "missing_tool",
                argumentsJSON: #"{}"#
            )

            do {
                _ = try await executor.execute(toolCall: toolCall)
                Issue.record("Expected invalidInput error")
            } catch let error as AIError {
                if case .invalidInput(let message) = error {
                    #expect(message.contains("missing_tool"))
                } else {
                    Issue.record("Expected invalidInput error, got: \(error)")
                }
            }
        }

        @Test("Tool error propagates from executor")
        func toolErrorPropagates() async throws {
            let executor = ToolExecutor()
            await executor.register(ThrowingMockTool())

            let toolCall = try Transcript.ToolCall(
                id: "call_1",
                toolName: "throwing_mock_tool",
                argumentsJSON: #"{"message": "test"}"#
            )

            await #expect(throws: ThrowingMockTool.AlwaysFailsError.self) {
                _ = try await executor.execute(toolCall: toolCall)
            }
        }

        @Test("Missing tool can emit non-fatal tool output when configured")
        func missingToolCanEmitOutput() async throws {
            let executor = ToolExecutor(missingToolPolicy: .emitToolOutput)
            await executor.register(MockTool())

            let toolCall = try Transcript.ToolCall(
                id: "call_missing",
                toolName: "missing_tool",
                argumentsJSON: #"{}"#
            )

            let output = try await executor.execute(toolCall: toolCall)
            #expect(output.id == "call_missing")
            #expect(output.toolName == "missing_tool")
            #expect(output.text == "Tool not found: missing_tool")
        }

        @Test("Proper error propagation from tool call")
        func properErrorPropagation() async throws {
            let executor = ToolExecutor()
            await executor.register(FailingTool())

            let successCall = try Transcript.ToolCall(
                id: "success",
                toolName: "failing_tool",
                argumentsJSON: #"{"shouldFail": false}"#
            )

            let successOutput = try await executor.execute(toolCall: successCall)
            #expect(successOutput.text == "Success")

            let failCall = try Transcript.ToolCall(
                id: "fail",
                toolName: "failing_tool",
                argumentsJSON: #"{"shouldFail": true}"#
            )

            await #expect(throws: FailingTool.ToolExecutionError.self) {
                _ = try await executor.execute(toolCall: failCall)
            }
        }
    }

    // MARK: - Unregistration Tests

    @Suite("Retry Policy")
    struct RetryPolicyTests {
        @Test("Default execute remains single attempt without retries")
        func defaultExecuteRemainsSingleAttempt() async throws {
            let recorder = FlakyToolAttemptRecorder()
            let executor = ToolExecutor(
                tools: [FlakyRetryableAIErrorTool(failuresBeforeSuccess: 1, recorder: recorder)]
            )

            let toolCall = try Transcript.ToolCall(
                id: "retry_default",
                toolName: "flaky_retryable_ai_error_tool",
                argumentsJSON: #"{"input":"default"}"#
            )

            await #expect(throws: AIError.self) {
                _ = try await executor.execute(toolCall: toolCall)
            }

            let attempts = await recorder.attemptCount
            #expect(attempts == 1)
        }

        @Test("Retry policy retries retryable AI errors until success")
        func retryPolicyRetriesRetryableAIErrors() async throws {
            let recorder = FlakyToolAttemptRecorder()
            let executor = ToolExecutor(
                tools: [FlakyRetryableAIErrorTool(failuresBeforeSuccess: 1, recorder: recorder)]
            )

            let toolCall = try Transcript.ToolCall(
                id: "retry_ai_error",
                toolName: "flaky_retryable_ai_error_tool",
                argumentsJSON: #"{"input":"value"}"#
            )

            let output = try await executor.execute(
                toolCall: toolCall,
                retryPolicy: .retryableAIErrors(maxAttempts: 2)
            )
            #expect(output.text == "Recovered: value")

            let attempts = await recorder.attemptCount
            #expect(attempts == 2)
        }

        @Test("Retryable AI policy does not retry non-AI errors")
        func retryableAIPolicyDoesNotRetryNonAIError() async throws {
            let recorder = FlakyToolAttemptRecorder()
            let executor = ToolExecutor(
                tools: [FlakyNonAIErrorTool(failuresBeforeSuccess: 1, recorder: recorder)]
            )

            let toolCall = try Transcript.ToolCall(
                id: "retry_non_ai",
                toolName: "flaky_non_ai_error_tool",
                argumentsJSON: #"{"input":"value"}"#
            )

            await #expect(throws: FlakyNonAIErrorTool.NonAIError.self) {
                _ = try await executor.execute(
                    toolCall: toolCall,
                    retryPolicy: .retryableAIErrors(maxAttempts: 2)
                )
            }

            let attempts = await recorder.attemptCount
            #expect(attempts == 1)
        }

        @Test("All-failures policy retries non-AI errors")
        func allFailuresPolicyRetriesNonAIError() async throws {
            let recorder = FlakyToolAttemptRecorder()
            let executor = ToolExecutor(
                tools: [FlakyNonAIErrorTool(failuresBeforeSuccess: 1, recorder: recorder)]
            )

            let toolCall = try Transcript.ToolCall(
                id: "retry_all_failures",
                toolName: "flaky_non_ai_error_tool",
                argumentsJSON: #"{"input":"value"}"#
            )

            let output = try await executor.execute(
                toolCall: toolCall,
                retryPolicy: .allFailures(maxAttempts: 2)
            )
            #expect(output.text == "Recovered non-ai: value")

            let attempts = await recorder.attemptCount
            #expect(attempts == 2)
        }
    }

    @Suite("Unregistration")
    struct UnregistrationTests {

        @Test("Unregister single tool")
        func unregisterSingleTool() async {
            let executor = ToolExecutor()
            await executor.register(MockTool())
            await executor.register(AnotherMockTool())

            let removed = await executor.unregister(name: "mock_tool")
            #expect(removed == true)

            let names = await executor.registeredToolNames
            #expect(names.count == 1)
            #expect(!names.contains("mock_tool"))
            #expect(names.contains("another_tool"))
        }

        @Test("Unregister non-existent tool is safe")
        func unregisterNonExistentToolIsSafe() async {
            let executor = ToolExecutor()
            await executor.register(MockTool())

            let removed = await executor.unregister(name: "nonexistent_tool")
            #expect(removed == false)

            let names = await executor.registeredToolNames
            #expect(names.count == 1)
            #expect(names.contains("mock_tool"))
        }

        @Test("Unregister all tools")
        func unregisterAllTools() async {
            let executor = ToolExecutor()
            await executor.register(MockTool())
            await executor.register(AnotherMockTool())
            await executor.register(FailingTool())

            // Get all names first
            var names = await executor.registeredToolNames
            #expect(names.count == 3)

            // Unregister each tool
            for name in names {
                let removed = await executor.unregister(name: name)
                #expect(removed == true)
            }

            // Verify all removed
            names = await executor.registeredToolNames
            #expect(names.isEmpty)
        }
    }

    // MARK: - Edge Cases

    @Suite("Edge Cases")
    struct EdgeCaseTests {

        @Test("Empty executor returns empty definitions")
        func emptyExecutorReturnsEmptyDefinitions() async {
            let executor = ToolExecutor()

            let names = await executor.registeredToolNames
            let definitions = await executor.toolDefinitions

            #expect(names.isEmpty)
            #expect(definitions.isEmpty)
        }

        @Test("Execute on empty executor throws toolNotFound")
        func executeOnEmptyExecutorThrows() async throws {
            let executor = ToolExecutor()

            let toolCall = try Transcript.ToolCall(
                id: "call_1",
                toolName: "any_tool",
                argumentsJSON: #"{}"#
            )

            await #expect(throws: AIError.self) {
                _ = try await executor.execute(toolCall: toolCall)
            }
        }

        @Test("Execute batch on empty array returns empty results")
        func executeBatchOnEmptyArrayReturnsEmpty() async throws {
            let executor = ToolExecutor()
            await executor.register(MockTool())

            let outputs = try await executor.execute(toolCalls: [])
            #expect(outputs.isEmpty)
        }

        @Test("Tool with empty arguments works")
        func toolWithEmptyArgumentsWorks() async throws {
            let executor = ToolExecutor()
            await executor.register(CustomNameTool(name: "empty_args_tool"))

            let toolCall = try Transcript.ToolCall(
                id: "call_1",
                toolName: "empty_args_tool",
                argumentsJSON: #"{}"#
            )

            let output = try await executor.execute(toolCall: toolCall)
            #expect(output.text == "Custom tool: empty_args_tool")
        }

        @Test("Executor is an actor and thread-safe")
        func executorIsActorAndThreadSafe() async {
            let executor = ToolExecutor()

            // Perform concurrent registrations
            await withTaskGroup(of: Void.self) { group in
                for i in 0..<10 {
                    group.addTask {
                        await executor.register(CustomNameTool(name: "tool_\(i)"))
                    }
                }
            }

            let names = await executor.registeredToolNames
            #expect(names.count == 10)
        }
    }
}
