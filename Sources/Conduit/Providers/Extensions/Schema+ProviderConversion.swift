// GenerationSchema+ProviderConversion.swift
// Conduit
//
// GenerationSchema conversion to provider-specific tool formats.

import Foundation

// MARK: - GenerationSchema to JSON schema conversion

extension GenerationSchema {

    /// Converts this GenerationSchema to a JSON schema dictionary for provider APIs.
    public func toJSONSchema() -> [String: Any] {
        let encoder = JSONEncoder()
        let data = (try? encoder.encode(self)) ?? Data()
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return json
    }

    /// Converts this GenerationSchema to a JSON string suitable for embedding in prompts.
    public func toJSONString(prettyPrinted: Bool = true) -> String {
        let json = toJSONSchema()
        guard JSONSerialization.isValidJSONObject(json) else {
            return "{}"
        }

        var options: JSONSerialization.WritingOptions = []
        if prettyPrinted {
            options.insert(.prettyPrinted)
            options.insert(.sortedKeys)
        }

        guard let data = try? JSONSerialization.data(withJSONObject: json, options: options),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}

// MARK: - Tool Conversion

extension Tool {

    /// Converts this tool to Anthropic's tool format.
    ///
    /// - Returns: A dictionary for Anthropic's API.
    public func toAnthropicFormat() -> [String: Any] {
        return [
            "name": name,
            "description": description,
            "input_schema": parameters.toJSONSchema()
        ]
    }

    /// Converts this tool to OpenAI's function format.
    ///
    /// - Returns: A dictionary for OpenAI's API.
    public func toOpenAIFormat() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": parameters.toJSONSchema()
            ]
        ]
    }
}

// MARK: - ToolChoice Conversion

extension ToolChoice {

    /// Converts this tool choice to Anthropic's format.
    ///
    /// - Returns: The tool_choice value for Anthropic's API.
    public func toAnthropicFormat() -> [String: Any] {
        switch self {
        case .auto:
            return ["type": "auto"]
        case .required:
            return ["type": "any"]
        case .none:
            // Anthropic doesn't have explicit "none" - omit tools instead
            return ["type": "auto"]
        case .tool(let name):
            return ["type": "tool", "name": name]
        }
    }

    /// Converts this tool choice to OpenAI's format.
    ///
    /// - Returns: The tool_choice value for OpenAI's API.
    public func toOpenAIFormat() -> [String: Any]? {
        switch self {
        case .auto:
            return nil
        case .required:
            return ["type": "required"]
        case .none:
            return ["type": "none"]
        case .tool(let name):
            return [
                "type": "function",
                "function": ["name": name]
            ]
        }
    }
}
