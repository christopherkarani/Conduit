// ToolMessage.swift
// Conduit

import Foundation

// MARK: - Transcript.ToolCall Helpers

extension Transcript.ToolCall {

    /// Creates a new tool call from JSON string arguments.
    ///
    /// - Parameters:
    ///   - id: A unique identifier for this call.
    ///   - toolName: The name of the tool to invoke.
    ///   - argumentsJSON: The JSON string containing the arguments.
    /// - Throws: `GeneratedContentError.typeMismatch` if the JSON string cannot be parsed.
    public init(id: String, toolName: String, argumentsJSON: String) throws {
        self.init(id: id, toolName: toolName, arguments: try GeneratedContent(json: argumentsJSON))
    }

    /// Returns the arguments serialized as JSON Data.
    ///
    /// Use this method to pass arguments to a `Tool` instance.
    ///
    /// - Returns: JSON-encoded Data of the arguments.
    public func argumentsData() throws -> Data {
        Data(arguments.jsonString.utf8)
    }

    /// The arguments as a JSON string.
    public var argumentsString: String {
        arguments.jsonString
    }
}

// MARK: - Transcript.ToolOutput Helpers

extension Transcript.ToolOutput {

    /// Creates a tool output from a tool call and segments.
    ///
    /// - Parameters:
    ///   - call: The original tool call.
    ///   - segments: Output segments to include.
    public init(call: Transcript.ToolCall, segments: [Transcript.Segment]) {
        self.init(id: call.id, toolName: call.toolName, segments: segments)
    }

    /// Creates a tool output from a tool call and PromptRepresentable output.
    ///
    /// - Parameters:
    ///   - call: The original tool call.
    ///   - result: The result conforming to PromptRepresentable.
    public init(call: Transcript.ToolCall, result: some PromptRepresentable) {
        self.init(
            id: call.id,
            toolName: call.toolName,
            segments: [
                .text(Transcript.TextSegment(content: Prompt(result).description))
            ]
        )
    }

    /// The tool output as a single string.
    public var text: String {
        segments.map { segment in
            switch segment {
            case .text(let textSegment):
                return textSegment.content
            case .structure(let structuredSegment):
                return structuredSegment.content.jsonString
            case .image(let imageSegment):
                switch imageSegment.source {
                case .data(_, let mimeType):
                    return "<image:\(mimeType)>"
                case .url(let url):
                    return url.absoluteString
                }
            }
        }.joined(separator: "\n")
    }
}

// MARK: - Message Extension

extension Message {

    /// Creates a tool output message.
    ///
    /// Use this factory method to create a message containing the result
    /// of a tool execution. The message will have the `.tool` role.
    ///
    /// - Parameter output: The tool output to include in the message.
    /// - Returns: A message with `role: .tool` containing the tool result.
    public static func toolOutput(_ output: Transcript.ToolOutput) -> Message {
        Message(
            role: .tool,
            content: toolOutputContent(from: output.segments),
            metadata: MessageMetadata(
                custom: [
                    "tool_call_id": output.id,
                    "tool_name": output.toolName
                ]
            )
        )
    }

    /// Creates a tool output message from a tool call and result content.
    ///
    /// - Parameters:
    ///   - call: The tool call that was executed.
    ///   - content: The textual content of the result.
    /// - Returns: A message with `role: .tool` containing the tool result.
    public static func toolOutput(call: Transcript.ToolCall, content: String) -> Message {
        toolOutput(
            Transcript.ToolOutput(
                id: call.id,
                toolName: call.toolName,
                segments: [.text(Transcript.TextSegment(content: content))]
            )
        )
    }

    /// Creates a tool output message from a tool call and PromptRepresentable result.
    ///
    /// - Parameters:
    ///   - call: The tool call that was executed.
    ///   - result: The result conforming to PromptRepresentable.
    /// - Returns: A message with `role: .tool` containing the tool result.
    public static func toolOutput(call: Transcript.ToolCall, result: some PromptRepresentable) -> Message {
        toolOutput(Transcript.ToolOutput(call: call, result: result))
    }

    private static func toolOutputContent(from segments: [Transcript.Segment]) -> Message.Content {
        let parts = segments.compactMap { segment -> Message.ContentPart? in
            switch segment {
            case .text(let textSegment):
                return .text(textSegment.content)
            case .structure(let structuredSegment):
                return .text(structuredSegment.content.jsonString)
            case .image(let imageSegment):
                switch imageSegment.source {
                case .data(let data, let mimeType):
                    return .image(Message.ImageContent(base64Data: data.base64EncodedString(), mimeType: mimeType))
                case .url(let url):
                    return .text(url.absoluteString)
                }
            }
        }

        guard !parts.isEmpty else {
            return .text("")
        }

        if parts.count == 1, case .text(let text) = parts[0] {
            return .text(text)
        }

        return .parts(parts)
    }
}

// MARK: - Transcript.ToolCall Collection Extension

extension Collection where Element == Transcript.ToolCall {

    /// Finds a tool call by name.
    ///
    /// - Parameter name: The tool name to search for.
    /// - Returns: The first tool call with the matching name, or `nil`.
    public func call(named name: String) -> Transcript.ToolCall? {
        first { $0.toolName == name }
    }

    /// Filters tool calls by name.
    ///
    /// - Parameter name: The tool name to filter by.
    /// - Returns: All tool calls with the matching name.
    public func calls(named name: String) -> [Transcript.ToolCall] {
        filter { $0.toolName == name }
    }
}
