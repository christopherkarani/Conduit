// AITool.swift
// SwiftAI
//
// Type-safe tool/function calling protocol for LLM integration.
// Renamed from "Tool" to "AITool" to avoid conflicts with SwiftAgents.

import Foundation

// MARK: - PromptRepresentable Protocol

/// A type that can be represented in a prompt sent to language models.
///
/// Types conforming to this protocol can be converted to text content,
/// enabling them to be included in LLM conversations. This is used for
/// tool outputs and other structured content.
///
/// ## Basic Conformance
///
/// For simple text output:
///
/// ```swift
/// struct WeatherResult: PromptRepresentable, Sendable {
///     let temperature: Int
///     let conditions: String
///
///     var text: String {
///         "Temperature: \(temperature)C, Conditions: \(conditions)"
///     }
/// }
/// ```
///
/// ## Thread Safety
///
/// All conforming types must be `Sendable` for safe use across actor boundaries.
public protocol PromptRepresentable: Sendable {
    /// The text representation of this content for inclusion in prompts.
    var text: String { get }
}

/// String naturally conforms to PromptRepresentable.
extension String: PromptRepresentable {
    public var text: String { self }
}

// MARK: - AITool Protocol

/// A function that language models can invoke to perform specific tasks.
///
/// Tools extend LLM capabilities by providing access to external functions,
/// APIs, and data sources with full type safety. The `AITool` protocol is
/// named to avoid conflicts with other frameworks (e.g., SwiftAgents) that
/// may define a `Tool` type.
///
/// ## Example
///
/// ```swift
/// struct WeatherTool: AITool {
///     @Generable
///     struct Arguments {
///         @Guide("City name") let city: String
///         @Guide("Unit", .anyOf(["celsius", "fahrenheit"])) let unit: String?
///     }
///
///     let description = "Get weather for a city"
///
///     func call(arguments: Arguments) async throws -> String {
///         return "Weather in \(arguments.city): 22C"
///     }
/// }
/// ```
///
/// ## Default Implementations
///
/// The protocol provides default implementations for:
/// - `name`: Derived from the type name (e.g., `WeatherTool`)
/// - `parameters`: Derived from `Arguments.schema`
/// - `call(_:)`: JSON decoding wrapper around `call(arguments:)`
///
/// ## Thread Safety
///
/// All conforming types must be `Sendable` to safely cross actor boundaries
/// during concurrent tool execution.
///
/// ## Usage with LLMs
///
/// Tools are typically registered with an LLM session and invoked automatically
/// when the model generates a tool call:
///
/// ```swift
/// let tools: [any AITool] = [WeatherTool(), SearchTool()]
/// let response = try await llm.reply(
///     to: messages,
///     tools: tools
/// )
/// ```
public protocol AITool: Sendable {

    // MARK: - Associated Types

    /// The input parameters required to execute this tool.
    ///
    /// This type must conform to `Generable` to enable automatic schema
    /// generation and JSON deserialization from LLM tool calls.
    ///
    /// ## Example
    ///
    /// ```swift
    /// @Generable
    /// struct Arguments {
    ///     @Guide("The search query") let query: String
    ///     @Guide("Maximum results", .range(1...100)) let maxResults: Int?
    /// }
    /// ```
    associatedtype Arguments: Generable

    /// The output type returned by this tool.
    ///
    /// Must conform to `PromptRepresentable` to enable the result to be
    /// included in subsequent prompts to the LLM.
    ///
    /// Common output types:
    /// - `String`: Simple text responses
    /// - Custom types conforming to `PromptRepresentable`
    associatedtype Output: PromptRepresentable

    // MARK: - Properties

    /// A unique name for this tool used by the LLM to reference it.
    ///
    /// The name should be descriptive and follow naming conventions
    /// expected by the target LLM (e.g., snake_case for OpenAI).
    ///
    /// Default implementation returns the type name (e.g., `WeatherTool`).
    ///
    /// ## Example
    ///
    /// ```swift
    /// var name: String { "get_weather" }
    /// ```
    var name: String { get }

    /// A natural language description that provides context about this tool to the LLM.
    ///
    /// This description helps the model understand when and how to use the tool.
    /// Be specific about the tool's purpose, expected inputs, and outputs.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var description: String {
    ///     "Get current weather conditions for a specified city. " +
    ///     "Returns temperature, humidity, and conditions."
    /// }
    /// ```
    var description: String { get }

    /// The schema specification of parameters this tool accepts.
    ///
    /// Describes the structure and constraints of the arguments that can be
    /// passed to this tool, enabling language models to generate valid tool calls.
    ///
    /// Default implementation returns `Arguments.schema`.
    static var parameters: Schema { get }

    // MARK: - Methods

    /// Executes the tool with typed arguments.
    ///
    /// This is the primary method to implement for tool functionality.
    /// Arguments are strongly typed and validated before this method is called.
    ///
    /// ## Implementation Guidelines
    ///
    /// - Handle errors gracefully and throw descriptive errors
    /// - Support cancellation via `Task.checkCancellation()`
    /// - Return results that can be meaningfully included in prompts
    ///
    /// ## Example
    ///
    /// ```swift
    /// func call(arguments: Arguments) async throws -> String {
    ///     try Task.checkCancellation()
    ///     let weather = try await weatherService.fetch(city: arguments.city)
    ///     return "Temperature: \(weather.temp)C, Conditions: \(weather.conditions)"
    /// }
    /// ```
    ///
    /// - Parameter arguments: The typed input parameters for tool execution.
    /// - Returns: The result of the tool execution.
    /// - Throws: Any errors that occur during tool execution.
    func call(arguments: Arguments) async throws -> Output

    /// Executes the tool from JSON-encoded arguments.
    ///
    /// This method is used by LLM integrations to invoke tools from JSON
    /// responses. The default implementation handles decoding and delegates
    /// to `call(arguments:)`.
    ///
    /// - Parameter data: JSON-encoded arguments for the tool.
    /// - Returns: The result of the tool execution.
    /// - Throws: `AIToolError.invalidArgumentEncoding` if decoding fails,
    ///           or any errors from `call(arguments:)`.
    func call(_ data: Data) async throws -> any PromptRepresentable
}

// MARK: - Default Implementations

extension AITool where Arguments: Generable {

    /// Default implementation of the tool's name.
    ///
    /// Returns the type name directly (e.g., `WeatherTool` becomes `"WeatherTool"`).
    public var name: String {
        String(describing: Self.self)
    }

    /// Default implementation of parameters using the Arguments schema.
    public static var parameters: Schema {
        Arguments.schema
    }

    /// Default implementation of the JSON call method.
    ///
    /// Decodes the JSON data into Arguments and calls the typed method.
    ///
    /// - Parameter data: JSON-encoded arguments.
    /// - Returns: The result of calling `call(arguments:)`.
    /// - Throws: `AIToolError.invalidArgumentEncoding` if JSON is invalid,
    ///           or any error from the underlying tool execution.
    public func call(_ data: Data) async throws -> any PromptRepresentable {
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw AIToolError.invalidArgumentEncoding
        }

        do {
            let content = try StructuredContent(json: jsonString)
            let arguments = try Arguments(from: content)
            return try await call(arguments: arguments)
        } catch let error as AIToolError {
            throw error
        } catch {
            throw AIToolError.invalidArgumentEncoding
        }
    }
}

// MARK: - AIToolError

/// Errors that can occur during tool operations.
///
/// `AIToolError` provides specific error cases for tool-related failures,
/// enabling precise error handling in tool execution flows.
///
/// ## Usage
///
/// ```swift
/// do {
///     let result = try await tool.call(data)
/// } catch let error as AIToolError {
///     switch error {
///     case .toolNotFound(let name):
///         print("Unknown tool: \(name)")
///     case .invalidArgumentEncoding:
///         print("Failed to decode tool arguments")
///     case .executionFailed(let tool, let underlying):
///         print("Tool \(tool) failed: \(underlying)")
///     }
/// }
/// ```
public enum AIToolError: Error, Sendable, LocalizedError {

    /// The requested tool was not found.
    ///
    /// This occurs when attempting to invoke a tool by name that
    /// is not registered with the current session.
    ///
    /// - Parameter name: The name of the tool that was not found.
    case toolNotFound(name: String)

    /// Failed to decode the tool arguments from JSON.
    ///
    /// This occurs when the JSON data provided to `call(_:)` cannot
    /// be decoded into the tool's `Arguments` type.
    case invalidArgumentEncoding

    /// Tool execution failed with an underlying error.
    ///
    /// This wraps errors thrown by the tool's `call(arguments:)` method.
    ///
    /// - Parameters:
    ///   - tool: The name of the tool that failed.
    ///   - underlying: The error that caused the failure.
    case executionFailed(tool: String, underlying: Error)

    // MARK: - LocalizedError

    /// A localized description of the error.
    public var errorDescription: String? {
        switch self {
        case .toolNotFound(let name):
            return "Tool not found: '\(name)'"

        case .invalidArgumentEncoding:
            return "Failed to decode tool arguments from JSON"

        case .executionFailed(let tool, let underlying):
            return "Tool '\(tool)' execution failed: \(underlying.localizedDescription)"
        }
    }

    /// A localized suggestion for recovering from the error.
    public var recoverySuggestion: String? {
        switch self {
        case .toolNotFound:
            return "Verify the tool name and ensure it is registered with the session."

        case .invalidArgumentEncoding:
            return "Check that the JSON arguments match the tool's expected schema."

        case .executionFailed:
            return "Review the underlying error and tool implementation."
        }
    }
}

// MARK: - Type Erasure

/// A type-erased wrapper for any AITool.
///
/// Use `AnyAITool` when you need to work with heterogeneous collections
/// of tools or store tools with different argument/output types.
///
/// ## Usage
///
/// ```swift
/// let tools: [AnyAITool] = [
///     AnyAITool(WeatherTool()),
///     AnyAITool(SearchTool())
/// ]
///
/// for tool in tools {
///     print("Tool: \(tool.name) - \(tool.description)")
/// }
/// ```
public struct AnyAITool: Sendable {

    /// The unique name of the wrapped tool.
    public let name: String

    /// The description of the wrapped tool.
    public let description: String

    /// The parameter schema for the wrapped tool.
    public let parameters: Schema

    /// The type-erased call function.
    private let _call: @Sendable (Data) async throws -> any PromptRepresentable

    /// Creates a type-erased wrapper around an AITool.
    ///
    /// - Parameter tool: The tool to wrap.
    public init<T: AITool>(_ tool: T) {
        self.name = tool.name
        self.description = tool.description
        self.parameters = T.parameters
        self._call = { data in
            try await tool.call(data)
        }
    }

    /// Executes the wrapped tool with JSON-encoded arguments.
    ///
    /// - Parameter data: JSON-encoded arguments.
    /// - Returns: The result of the tool execution.
    /// - Throws: Any errors from the underlying tool.
    public func call(_ data: Data) async throws -> any PromptRepresentable {
        try await _call(data)
    }
}
