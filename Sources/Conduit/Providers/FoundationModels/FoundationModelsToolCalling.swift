// FoundationModelsToolCalling.swift
// Conduit

import Foundation

#if canImport(FoundationModels)

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
struct FoundationModelsToolCallingContext: Sendable, Equatable {
    static let envelopeKey = "conduit_tool_call"

    let nonce: String

    static func make() -> Self {
        Self(nonce: UUID().uuidString)
    }
}

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
enum FoundationModelsToolPromptBuilder {
    static func buildPrompt(
        basePrompt: String,
        tools: [Transcript.ToolDefinition],
        toolChoice: ToolChoice,
        context: FoundationModelsToolCallingContext,
        responseFormat: ResponseFormat?
    ) -> String {
        guard !tools.isEmpty else {
            return appendResponseFormatInstruction(to: basePrompt, responseFormat: responseFormat)
        }

        var prompt = """
        \(basePrompt)

        Available tools:
        \(toolDefinitionsText(for: tools))

        If you decide to use a tool, respond with only a single JSON object in this exact format and no surrounding text:
        \(toolEnvelopeExample(tools: tools, context: context))

        Never emit that JSON envelope unless you are requesting a tool call.
        Never invent placeholder tool names, argument keys, or argument values.
        The "tool" field must be one of the real tool names listed above.
        If tool results are already present in the conversation, use them directly to answer the user.
        Never claim you cannot browse, search, or access external information when a tool result is already present.
        Do not call the same tool again with weaker or emptier arguments after you already have a usable result.
        """

        switch toolChoice {
        case .auto:
            break
        case .required:
            prompt += "\nYou must request one tool call before giving a final answer."
        case .none:
            prompt += "\nDo not call any tools. Answer directly."
        case .named(let name):
            prompt += "\nIf a tool is required, you must call the tool named exactly \"\(name)\"."
        }

        return appendResponseFormatInstruction(to: prompt, responseFormat: responseFormat)
    }

    static func appendResponseFormatInstruction(to prompt: String, responseFormat: ResponseFormat?) -> String {
        guard let responseFormat else { return prompt }

        switch responseFormat {
        case .text:
            return prompt
        case .jsonObject:
            return """
            \(prompt)

            Return valid JSON only. Do not wrap the JSON in markdown code fences.
            """
        case .jsonSchema(let name, let schema):
            let schemaString = schemaJSONString(schema)
            return """
            \(prompt)

            Return valid JSON only. Do not wrap the JSON in markdown code fences.
            The response must conform to the JSON schema named "\(name)":
            \(schemaString)
            """
        }
    }

    private static func toolDefinitionsText(for tools: [Transcript.ToolDefinition]) -> String {
        tools.map { tool in
            let schema = schemaJSONString(tool.parameters)
            return """
            \(tool.name):
              Description: \(tool.description)
              Parameters JSON Schema: \(schema)
            """
        }.joined(separator: "\n\n")
    }

    private static func toolEnvelopeExample(
        tools: [Transcript.ToolDefinition],
        context: FoundationModelsToolCallingContext
    ) -> String {
        guard let tool = tools.first else {
            return #"{"conduit_tool_call":{"nonce":"\#(context.nonce)","tool":"tool_name","arguments":{}}}"#
        }

        let envelope: [String: Any] = [
            FoundationModelsToolCallingContext.envelopeKey: [
                "nonce": context.nonce,
                "tool": tool.name,
                "arguments": exampleArguments(for: tool),
            ],
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8)
        else {
            return #"{"conduit_tool_call":{"nonce":"\#(context.nonce)","tool":"\#(tool.name)","arguments":{}}}"#
        }

        return json
    }

    private static func exampleArguments(for tool: Transcript.ToolDefinition) -> [String: Any] {
        switch tool.name {
        case "websearch":
            return [
                "detail": "compact",
                "maxResults": 3,
                "query": "latest official Foundation Models documentation",
            ]
        default:
            return [:]
        }
    }

    private static func schemaJSONString(_ schema: GenerationSchema) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(schema),
              let string = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return string
    }
}

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
enum FoundationModelsToolParser {
    static func parseToolCalls(
        from content: String,
        availableTools: [Transcript.ToolDefinition],
        context: FoundationModelsToolCallingContext
    ) -> [Transcript.ToolCall]? {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        if let calls = parseToolCallsFromExactEnvelope(trimmed, availableTools: availableTools, context: context) {
            return calls
        }

        for candidate in extractJSONObjectCandidates(from: content) {
            if let calls = parseToolCallsFromExactEnvelope(candidate, availableTools: availableTools, context: context) {
                return calls
            }
        }

        return nil
    }

    private static func parseToolCallsFromExactEnvelope(
        _ candidate: String,
        availableTools: [Transcript.ToolDefinition],
        context: FoundationModelsToolCallingContext
    ) -> [Transcript.ToolCall]? {
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.first == "{", trimmed.last == "}" else {
            return nil
        }

        guard let data = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let envelope = json[FoundationModelsToolCallingContext.envelopeKey] as? [String: Any]
        else {
            return nil
        }

        if let nonce = envelope["nonce"] as? String, nonce != context.nonce {
            return nil
        }

        guard let rawToolName = (envelope["tool"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !rawToolName.isEmpty,
            let tool = resolveTool(named: rawToolName, availableTools: availableTools)
        else {
            return nil
        }

        let argumentsJSON: String
        if let arguments = envelope["arguments"] {
            guard JSONSerialization.isValidJSONObject(arguments),
                  let argumentsData = try? JSONSerialization.data(withJSONObject: arguments, options: [.sortedKeys]),
                  let argumentsString = String(data: argumentsData, encoding: .utf8)
            else {
                return nil
            }
            argumentsJSON = argumentsString
        } else {
            argumentsJSON = "{}"
        }

        guard let toolCall = try? Transcript.ToolCall(
            id: envelope["id"] as? String ?? UUID().uuidString,
            toolName: tool.name,
            argumentsJSON: argumentsJSON
        ) else {
            return nil
        }

        return [toolCall]
    }

    private static func extractJSONObjectCandidates(from content: String) -> [String] {
        var candidates: [String] = []
        var objectStart: String.Index?
        var depth = 0
        var inString = false
        var isEscaped = false
        var index = content.startIndex

        while index < content.endIndex {
            let character = content[index]

            if inString {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == "\"" {
                    inString = false
                }
            } else {
                switch character {
                case "\"":
                    inString = true
                case "{":
                    if depth == 0 {
                        objectStart = index
                    }
                    depth += 1
                case "}":
                    guard depth > 0 else { break }
                    depth -= 1
                    if depth == 0, let objectStart {
                        candidates.append(String(content[objectStart ... index]))
                    }
                default:
                    break
                }
            }

            index = content.index(after: index)
        }

        return candidates
    }

    private static func resolveTool(
        named rawToolName: String,
        availableTools: [Transcript.ToolDefinition]
    ) -> Transcript.ToolDefinition? {
        if let exact = availableTools.first(where: { $0.name == rawToolName }) {
            return exact
        }

        let prefixMatches = availableTools.filter {
            $0.name.hasPrefix(rawToolName) || rawToolName.hasPrefix($0.name)
        }
        if prefixMatches.count == 1 {
            return prefixMatches[0]
        }

        let normalizedRaw = normalizeToolName(rawToolName)
        let normalizedMatches = availableTools.filter { normalizeToolName($0.name) == normalizedRaw }
        if normalizedMatches.count == 1 {
            return normalizedMatches[0]
        }

        return nil
    }

    private static func normalizeToolName(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
    }
}

#endif
