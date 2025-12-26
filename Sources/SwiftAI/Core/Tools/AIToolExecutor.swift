// AIToolExecutor.swift
// SwiftAI
//
// Actor for managing tool registration and execution.

import Foundation

// MARK: - AIToolExecutor

/// An actor that manages tool registration and execution for LLM interactions.
///
/// `AIToolExecutor` provides type-safe tool execution with automatic argument
/// parsing using the `Generable` protocol. It handles the tool call loop,
/// executing tools when the LLM requests them and returning results.
///
/// ## Usage
///
/// ```swift
/// // Define a tool
/// struct WeatherTool: AITool {
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
/// let executor = AIToolExecutor()
/// await executor.register(WeatherTool())
///
/// // Execute a tool call from LLM
/// let result = try await executor.execute(toolCall: toolCall)
/// ```
///
/// ## Thread Safety
///
/// `AIToolExecutor` is an actor, ensuring thread-safe access to registered tools
/// and safe concurrent execution.
public actor AIToolExecutor {

    // MARK: - Properties

    /// Registered tools indexed by name.
    private var tools: [String: AnyAITool] = [:]

    // MARK: - Initialization

    /// Creates an empty tool executor.
    public init() {}

    /// Creates a tool executor with the given tools.
    ///
    /// - Parameter tools: Tools to register initially.
    public init(tools: [any AITool]) {
        for tool in tools {
            self.tools[tool.name] = AnyAITool(tool)
        }
    }

    // MARK: - Registration

    /// Registers a tool for execution.
    ///
    /// - Parameter tool: The tool to register.
    /// - Note: If a tool with the same name exists, it will be replaced.
    public func register<T: AITool>(_ tool: T) {
        tools[tool.name] = AnyAITool(tool)
    }

    /// Registers multiple tools for execution.
    ///
    /// - Parameter toolsToRegister: The tools to register.
    public func register(_ toolsToRegister: [any AITool]) {
        for tool in toolsToRegister {
            tools[tool.name] = AnyAITool(tool)
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
    public var toolDefinitions: [ToolDefinition] {
        tools.values.map { tool in
            ToolDefinition(
                name: tool.name,
                description: tool.description,
                parameters: tool.parameters
            )
        }
    }

    // MARK: - Execution

    /// Executes a tool call from the LLM.
    ///
    /// - Parameter toolCall: The tool call to execute.
    /// - Returns: The result of the tool execution.
    /// - Throws: `AIToolError.toolNotFound` if the tool is not registered,
    ///           or any error from the tool execution.
    public func execute(toolCall: AIToolCall) async throws -> AIToolOutput {
        guard let tool = tools[toolCall.toolName] else {
            throw AIToolError.toolNotFound(name: toolCall.toolName)
        }

        do {
            let argumentsData = try toolCall.argumentsData()
            let result = try await tool.call(argumentsData)
            return AIToolOutput(
                id: toolCall.id,
                toolName: toolCall.toolName,
                content: result.text
            )
        } catch let error as AIToolError {
            throw error
        } catch {
            throw AIToolError.executionFailed(tool: toolCall.toolName, underlying: error)
        }
    }

    /// Executes multiple tool calls concurrently.
    ///
    /// - Parameter toolCalls: The tool calls to execute.
    /// - Returns: Results for each tool call, in order.
    /// - Throws: If any tool execution fails.
    public func execute(toolCalls: [AIToolCall]) async throws -> [AIToolOutput] {
        try await withThrowingTaskGroup(of: (Int, AIToolOutput).self) { group in
            for (index, toolCall) in toolCalls.enumerated() {
                group.addTask {
                    let output = try await self.execute(toolCall: toolCall)
                    return (index, output)
                }
            }

            var results: [(Int, AIToolOutput)] = []
            for try await result in group {
                results.append(result)
            }

            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }
}

// Note: ToolDefinition and ToolChoice are defined in GenerateConfig.swift
// to avoid duplication and maintain a single source of truth.
