// ToolExecutor.swift
// Conduit
//
// Actor for managing tool registration and execution.

import Foundation

// MARK: - ToolExecutor

/// An actor that manages tool registration and execution for LLM interactions.
///
/// `ToolExecutor` provides type-safe tool execution with automatic argument
/// parsing using the `Generable` protocol. It handles the tool call loop,
/// executing tools when the LLM requests them and returning results.
///
/// ## Usage
///
/// ```swift
/// // Define a tool
/// struct WeatherTool: Tool {
///     @Generable
///     struct Arguments {
///         @Guide("City name") let city: String
///     }
///
///     let description = "Get weather for a city"
///
///     func call(arguments: Arguments) async throws -> String {
///         return "Weather in \(arguments.city): 22°C, Sunny"
///     }
/// }
///
/// // Create executor and register tools
/// let executor = ToolExecutor()
/// await executor.register(WeatherTool())
///
/// // Execute a tool call from LLM
/// let result = try await executor.execute(toolCall: toolCall)
/// ```
///
/// ## Thread Safety
///
/// `ToolExecutor` is an actor, ensuring thread-safe access to registered tools
/// and safe concurrent execution.
public actor ToolExecutor {

    // MARK: - Properties

    /// Registered tools indexed by name.
    private var tools: [String: any Tool] = [:]

    // MARK: - Initialization

    /// Creates an empty tool executor.
    public init() {}

    /// Creates a tool executor with the given tools.
    ///
    /// - Parameter tools: Tools to register initially.
    public init(tools: [any Tool]) {
        for tool in tools {
            self.tools[tool.name] = tool
        }
    }

    // MARK: - Registration

    /// Registers a tool for execution.
    ///
    /// - Parameter tool: The tool to register.
    /// - Note: If a tool with the same name exists, it will be replaced.
    public func register<T: Tool>(_ tool: T) {
        tools[tool.name] = tool
    }

    /// Registers multiple tools for execution.
    ///
    /// - Parameter toolsToRegister: The tools to register.
    public func register(_ toolsToRegister: [any Tool]) {
        for tool in toolsToRegister {
            tools[tool.name] = tool
        }
    }

    /// Unregisters a tool by name.
    ///
    /// - Parameter name: The name of the tool to unregister.
    /// - Returns: `true` if the tool was found and removed.
    @discardableResult
    public func unregister(name: String) -> Bool {
        tools.removeValue(forKey: name) != nil
    }

    /// Returns all registered tool names.
    public var registeredToolNames: [String] {
        Array(tools.keys)
    }

    /// Returns the schemas for all registered tools.
    ///
    /// Use this to provide tool definitions to the LLM.
    public var toolDefinitions: [Transcript.ToolDefinition] {
        tools.values.map { tool in
            Transcript.ToolDefinition(tool: tool)
        }
    }

    // MARK: - Execution

    /// Executes a tool call from the LLM.
    ///
    /// - Parameter toolCall: The tool call to execute.
    /// - Returns: The result of the tool execution.
    /// - Throws: `AIError.invalidInput` if the tool is not registered,
    ///           or any error from the tool execution.
    public func execute(toolCall: Transcript.ToolCall) async throws -> Transcript.ToolOutput {
        guard let tool = tools[toolCall.toolName] else {
            throw AIError.invalidInput("Tool not found: \(toolCall.toolName)")
        }

        let segments = try await tool.makeOutputSegments(from: toolCall.arguments)
        return Transcript.ToolOutput(
            id: toolCall.id,
            toolName: toolCall.toolName,
            segments: segments
        )
    }

    /// Executes multiple tool calls concurrently.
    ///
    /// - Parameter toolCalls: The tool calls to execute.
    /// - Returns: Results for each tool call, in order.
    /// - Throws: If any tool execution fails or the task is cancelled.
    public func execute(toolCalls: [Transcript.ToolCall]) async throws -> [Transcript.ToolOutput] {
        try Task.checkCancellation()
        guard !toolCalls.isEmpty else { return [] }

        return try await withThrowingTaskGroup(of: (Int, Transcript.ToolOutput).self) { group in
            for (index, toolCall) in toolCalls.enumerated() {
                try Task.checkCancellation()

                group.addTask { [self] in
                    let output = try await self.execute(toolCall: toolCall)
                    return (index, output)
                }
            }

            var results: [(Int, Transcript.ToolOutput)] = []
            results.reserveCapacity(toolCalls.count)

            for try await result in group {
                results.append(result)
            }

            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }
}
