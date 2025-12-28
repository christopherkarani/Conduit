// AIToolExecutorTests.swift
// SwiftAI Tests
//
// Comprehensive tests for the AIToolExecutor actor.

import Foundation
import Testing
@testable import SwiftAI

// MARK: - Mock Tools

/// A simple mock tool for testing basic functionality.
struct MockTool: AITool {
    struct Arguments: Generable {
        let input: String

        static var schema: Schema {
            .object(
                name: "MockArguments",
                description: "Arguments for mock tool",
                properties: [
                    "input": Schema.Property(
                        schema: .string(constraints: []),
                        description: "The input string",
                        isRequired: true
                    )
                ]
            )
        }

        typealias Partial = Arguments

        var generableContent: StructuredContent {
            .object(["input": .string(input)])
        }

        init(from structuredContent: StructuredContent) throws {
            let obj = try structuredContent.object
            guard let inputContent = obj["input"] else {
                throw StructuredContentError.missingKey("input")
            }
            self.input = try inputContent.string
        }

        init(input: String) {
            self.input = input
        }
    }

    let name = "mock_tool"
    let description = "A mock tool for testing"

    func call(arguments: Arguments) async throws -> String {
        return "Result: \(arguments.input)"
    }
}

/// A second mock tool for testing multiple tool registration.
struct AnotherMockTool: AITool {
    struct Arguments: Generable {
        let value: Int

        static var schema: Schema {
            .object(
                name: "AnotherMockArguments",
                description: "Arguments for another mock tool",
                properties: [
                    "value": Schema.Property(
                        schema: .integer(constraints: []),
                        description: "The integer value",
                        isRequired: true
                    )
                ]
            )
        }

        typealias Partial = Arguments

        var generableContent: StructuredContent {
            .object(["value": .number(Double(value))])
        }

        init(from structuredContent: StructuredContent) throws {
            let obj = try structuredContent.object
            guard let valueContent = obj["value"] else {
                throw StructuredContentError.missingKey("value")
            }
            self.value = try valueContent.int
        }

        init(value: Int) {
            self.value = value
        }
    }

    let name = "another_tool"
    let description = "Another mock tool for testing"

    func call(arguments: Arguments) async throws -> String {
        return "Value doubled: \(arguments.value * 2)"
    }
}

/// A mock tool that throws an error for testing error handling.
struct FailingTool: AITool {
    struct Arguments: Generable {
        let shouldFail: Bool

        static var schema: Schema {
            .object(
                name: "FailingToolArguments",
                description: "Arguments for failing tool",
                properties: [
                    "shouldFail": Schema.Property(
                        schema: .boolean(constraints: []),
                        description: "Whether to fail",
                        isRequired: true
                    )
                ]
            )
        }

        typealias Partial = Arguments

        var generableContent: StructuredContent {
            .object(["shouldFail": .bool(shouldFail)])
        }

        init(from structuredContent: StructuredContent) throws {
            let obj = try structuredContent.object
            guard let shouldFailContent = obj["shouldFail"] else {
                throw StructuredContentError.missingKey("shouldFail")
            }
            self.shouldFail = try shouldFailContent.bool
        }

        init(shouldFail: Bool) {
            self.shouldFail = shouldFail
        }
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
struct SlowTool: AITool {
    struct Arguments: Generable {
        let delay: Double
        let id: String

        static var schema: Schema {
            .object(
                name: "SlowToolArguments",
                description: "Arguments for slow tool",
                properties: [
                    "delay": Schema.Property(
                        schema: .number(constraints: []),
                        description: "Delay in seconds",
                        isRequired: true
                    ),
                    "id": Schema.Property(
                        schema: .string(constraints: []),
                        description: "Identifier for the call",
                        isRequired: true
                    )
                ]
            )
        }

        typealias Partial = Arguments

        var generableContent: StructuredContent {
            .object([
                "delay": .number(delay),
                "id": .string(id)
            ])
        }

        init(from structuredContent: StructuredContent) throws {
            let obj = try structuredContent.object
            guard let delayContent = obj["delay"] else {
                throw StructuredContentError.missingKey("delay")
            }
            guard let idContent = obj["id"] else {
                throw StructuredContentError.missingKey("id")
            }
            self.delay = try delayContent.double
            self.id = try idContent.string
        }

        init(delay: Double, id: String) {
            self.delay = delay
            self.id = id
        }
    }

    let name = "slow_tool"
    let description = "A slow tool for testing concurrency"

    func call(arguments: Arguments) async throws -> String {
        try await Task.sleep(nanoseconds: UInt64(arguments.delay * 1_000_000_000))
        return "Completed: \(arguments.id)"
    }
}

/// A tool with a custom name for testing name replacement.
struct CustomNameTool: AITool {
    struct Arguments: Generable {
        static var schema: Schema {
            .object(name: "EmptyArgs", description: "No arguments", properties: [:])
        }
        typealias Partial = Arguments
        var generableContent: StructuredContent { .object([:]) }
        init(from structuredContent: StructuredContent) throws {}
        init() {}
    }

    let customName: String
    var name: String { customName }
    let description = "A tool with custom name"

    init(name: String) {
        self.customName = name
    }

    func call(arguments: Arguments) async throws -> String {
        return "Custom tool: \(customName)"
    }
}

// MARK: - Test Suite

@Suite("AIToolExecutor Tests")
struct AIToolExecutorTests {

    // MARK: - Registration Tests

    @Suite("Registration")
    struct RegistrationTests {

        @Test("Register single tool")
        func registerSingleTool() async {
            let executor = AIToolExecutor()
            await executor.register(MockTool())

            let names = await executor.registeredToolNames
            #expect(names.contains("mock_tool"))
            #expect(names.count == 1)
        }

        @Test("Register multiple tools")
        func registerMultipleTools() async {
            let executor = AIToolExecutor()
            await executor.register(MockTool())
            await executor.register(AnotherMockTool())

            let names = await executor.registeredToolNames
            #expect(names.count == 2)
            #expect(names.contains("mock_tool"))
            #expect(names.contains("another_tool"))
        }

        @Test("Register tools via array")
        func registerToolsViaArray() async {
            let executor = AIToolExecutor()
            await executor.register([MockTool(), AnotherMockTool(), FailingTool()])

            let names = await executor.registeredToolNames
            #expect(names.count == 3)
            #expect(names.contains("mock_tool"))
            #expect(names.contains("another_tool"))
            #expect(names.contains("failing_tool"))
        }

        @Test("Get tool definitions")
        func getToolDefinitions() async {
            let executor = AIToolExecutor()
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
            let executor = AIToolExecutor()

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
            let tools: [any AITool] = [MockTool(), AnotherMockTool()]
            let executor = AIToolExecutor(tools: tools)

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
            let executor = AIToolExecutor()
            await executor.register(MockTool())

            let toolCall = try AIToolCall(
                id: "call_123",
                toolName: "mock_tool",
                argumentsJSON: #"{"input": "test value"}"#
            )

            let output = try await executor.execute(toolCall: toolCall)
            #expect(output.id == "call_123")
            #expect(output.toolName == "mock_tool")
            #expect(output.content == "Result: test value")
        }

        @Test("Execute returns correct AIToolOutput")
        func executeReturnsCorrectOutput() async throws {
            let executor = AIToolExecutor()
            await executor.register(AnotherMockTool())

            let toolCall = try AIToolCall(
                id: "call_456",
                toolName: "another_tool",
                argumentsJSON: #"{"value": 21}"#
            )

            let output = try await executor.execute(toolCall: toolCall)
            #expect(output.id == "call_456")
            #expect(output.toolName == "another_tool")
            #expect(output.content == "Value doubled: 42")
        }

        @Test("Execute non-existent tool throws toolNotFound")
        func executeNonExistentToolThrows() async throws {
            let executor = AIToolExecutor()
            await executor.register(MockTool())

            let toolCall = try AIToolCall(
                id: "call_789",
                toolName: "nonexistent_tool",
                argumentsJSON: #"{}"#
            )

            await #expect(throws: AIToolError.self) {
                _ = try await executor.execute(toolCall: toolCall)
            }
        }

        @Test("Execute with invalid arguments throws error")
        func executeWithInvalidArgumentsThrows() async throws {
            let executor = AIToolExecutor()
            await executor.register(MockTool())

            // Missing required "input" field
            let toolCall = try AIToolCall(
                id: "call_invalid",
                toolName: "mock_tool",
                argumentsJSON: #"{"wrong_key": "value"}"#
            )

            await #expect(throws: AIToolError.self) {
                _ = try await executor.execute(toolCall: toolCall)
            }
        }

        @Test("Multiple sequential executions work")
        func multipleSequentialExecutions() async throws {
            let executor = AIToolExecutor()
            await executor.register(MockTool())

            for i in 1...5 {
                let toolCall = try AIToolCall(
                    id: "call_\(i)",
                    toolName: "mock_tool",
                    argumentsJSON: #"{"input": "test \#(i)"}"#
                )

                let output = try await executor.execute(toolCall: toolCall)
                #expect(output.id == "call_\(i)")
                #expect(output.content == "Result: test \(i)")
            }
        }
    }

    // MARK: - Concurrent Execution Tests

    @Suite("Concurrent Execution")
    struct ConcurrentExecutionTests {

        @Test("Execute multiple tools concurrently")
        func executeMultipleToolsConcurrently() async throws {
            let executor = AIToolExecutor()
            await executor.register(MockTool())
            await executor.register(AnotherMockTool())

            let toolCalls = [
                try AIToolCall(
                    id: "call_1",
                    toolName: "mock_tool",
                    argumentsJSON: #"{"input": "first"}"#
                ),
                try AIToolCall(
                    id: "call_2",
                    toolName: "another_tool",
                    argumentsJSON: #"{"value": 10}"#
                ),
                try AIToolCall(
                    id: "call_3",
                    toolName: "mock_tool",
                    argumentsJSON: #"{"input": "third"}"#
                )
            ]

            let outputs = try await executor.execute(toolCalls: toolCalls)
            #expect(outputs.count == 3)

            // Results should be in order
            #expect(outputs[0].id == "call_1")
            #expect(outputs[0].content == "Result: first")
            #expect(outputs[1].id == "call_2")
            #expect(outputs[1].content == "Value doubled: 20")
            #expect(outputs[2].id == "call_3")
            #expect(outputs[2].content == "Result: third")
        }

        @Test("Results maintain order regardless of completion time")
        func resultsMaintainOrder() async throws {
            let executor = AIToolExecutor()
            await executor.register(SlowTool())

            // Create calls with varying delays - later ones complete faster
            let toolCalls = [
                try AIToolCall(
                    id: "slow",
                    toolName: "slow_tool",
                    argumentsJSON: #"{"delay": 0.05, "id": "A"}"#
                ),
                try AIToolCall(
                    id: "medium",
                    toolName: "slow_tool",
                    argumentsJSON: #"{"delay": 0.02, "id": "B"}"#
                ),
                try AIToolCall(
                    id: "fast",
                    toolName: "slow_tool",
                    argumentsJSON: #"{"delay": 0.01, "id": "C"}"#
                )
            ]

            let outputs = try await executor.execute(toolCalls: toolCalls)

            // Despite completing in different order, results should be sorted by original index
            #expect(outputs[0].id == "slow")
            #expect(outputs[0].content == "Completed: A")
            #expect(outputs[1].id == "medium")
            #expect(outputs[1].content == "Completed: B")
            #expect(outputs[2].id == "fast")
            #expect(outputs[2].content == "Completed: C")
        }

        @Test("Partial failure breaks concurrent execution")
        func partialFailureBreaksConcurrentExecution() async throws {
            let executor = AIToolExecutor()
            await executor.register(MockTool())
            await executor.register(FailingTool())

            let toolCalls = [
                try AIToolCall(
                    id: "call_1",
                    toolName: "mock_tool",
                    argumentsJSON: #"{"input": "success"}"#
                ),
                try AIToolCall(
                    id: "call_2",
                    toolName: "failing_tool",
                    argumentsJSON: #"{"shouldFail": true}"#
                ),
                try AIToolCall(
                    id: "call_3",
                    toolName: "mock_tool",
                    argumentsJSON: #"{"input": "also success"}"#
                )
            ]

            // The whole batch should fail if any tool fails
            await #expect(throws: AIToolError.self) {
                _ = try await executor.execute(toolCalls: toolCalls)
            }
        }

        @Test("Cancellation is respected")
        func cancellationIsRespected() async throws {
            let executor = AIToolExecutor()
            await executor.register(SlowTool())

            let toolCalls = [
                try AIToolCall(
                    id: "call_1",
                    toolName: "slow_tool",
                    argumentsJSON: #"{"delay": 10.0, "id": "very slow"}"#
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

        @Test("AIToolError.toolNotFound has correct tool name")
        func toolNotFoundHasCorrectName() async throws {
            let executor = AIToolExecutor()
            await executor.register(MockTool())

            let toolCall = try AIToolCall(
                id: "call_1",
                toolName: "missing_tool",
                argumentsJSON: #"{}"#
            )

            do {
                _ = try await executor.execute(toolCall: toolCall)
                Issue.record("Expected toolNotFound error")
            } catch let error as AIToolError {
                if case .toolNotFound(let name) = error {
                    #expect(name == "missing_tool")
                } else {
                    Issue.record("Expected toolNotFound error, got: \(error)")
                }
            }
        }

        @Test("AIToolError.executionFailed wraps underlying error")
        func executionFailedWrapsUnderlyingError() async throws {
            let executor = AIToolExecutor()
            await executor.register(FailingTool())

            let toolCall = try AIToolCall(
                id: "call_1",
                toolName: "failing_tool",
                argumentsJSON: #"{"shouldFail": true}"#
            )

            do {
                _ = try await executor.execute(toolCall: toolCall)
                Issue.record("Expected executionFailed error")
            } catch let error as AIToolError {
                if case .executionFailed(let tool, let underlying) = error {
                    #expect(tool == "failing_tool")
                    #expect(underlying.localizedDescription.contains("Intentional test failure"))
                } else {
                    Issue.record("Expected executionFailed error, got: \(error)")
                }
            }
        }

        @Test("Proper error propagation from tool call")
        func properErrorPropagation() async throws {
            let executor = AIToolExecutor()
            await executor.register(FailingTool())

            // Test that successful call works
            let successCall = try AIToolCall(
                id: "success",
                toolName: "failing_tool",
                argumentsJSON: #"{"shouldFail": false}"#
            )

            let successOutput = try await executor.execute(toolCall: successCall)
            #expect(successOutput.content == "Success")

            // Test that failure propagates correctly
            let failCall = try AIToolCall(
                id: "fail",
                toolName: "failing_tool",
                argumentsJSON: #"{"shouldFail": true}"#
            )

            await #expect(throws: AIToolError.self) {
                _ = try await executor.execute(toolCall: failCall)
            }
        }
    }

    // MARK: - Unregistration Tests

    @Suite("Unregistration")
    struct UnregistrationTests {

        @Test("Unregister single tool")
        func unregisterSingleTool() async {
            let executor = AIToolExecutor()
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
            let executor = AIToolExecutor()
            await executor.register(MockTool())

            let removed = await executor.unregister(name: "nonexistent_tool")
            #expect(removed == false)

            let names = await executor.registeredToolNames
            #expect(names.count == 1)
            #expect(names.contains("mock_tool"))
        }

        @Test("Unregister all tools")
        func unregisterAllTools() async {
            let executor = AIToolExecutor()
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
            let executor = AIToolExecutor()

            let names = await executor.registeredToolNames
            let definitions = await executor.toolDefinitions

            #expect(names.isEmpty)
            #expect(definitions.isEmpty)
        }

        @Test("Execute on empty executor throws toolNotFound")
        func executeOnEmptyExecutorThrows() async throws {
            let executor = AIToolExecutor()

            let toolCall = try AIToolCall(
                id: "call_1",
                toolName: "any_tool",
                argumentsJSON: #"{}"#
            )

            await #expect(throws: AIToolError.self) {
                _ = try await executor.execute(toolCall: toolCall)
            }
        }

        @Test("Execute batch on empty array returns empty results")
        func executeBatchOnEmptyArrayReturnsEmpty() async throws {
            let executor = AIToolExecutor()
            await executor.register(MockTool())

            let outputs = try await executor.execute(toolCalls: [])
            #expect(outputs.isEmpty)
        }

        @Test("Tool with empty arguments works")
        func toolWithEmptyArgumentsWorks() async throws {
            let executor = AIToolExecutor()
            await executor.register(CustomNameTool(name: "empty_args_tool"))

            let toolCall = try AIToolCall(
                id: "call_1",
                toolName: "empty_args_tool",
                argumentsJSON: #"{}"#
            )

            let output = try await executor.execute(toolCall: toolCall)
            #expect(output.content == "Custom tool: empty_args_tool")
        }

        @Test("Executor is an actor and thread-safe")
        func executorIsActorAndThreadSafe() async {
            let executor = AIToolExecutor()

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
