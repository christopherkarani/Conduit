// Schema+ProviderConversion.swift
// SwiftAI
//
// Schema conversion to provider-specific tool formats.

import Foundation
import OrderedCollections

// MARK: - Schema to JSON Schema Conversion

extension Schema {

    /// Converts this Schema to a JSON Schema dictionary for provider APIs.
    ///
    /// This format is compatible with both Anthropic and OpenAI tool definitions.
    ///
    /// - Returns: A dictionary representing the JSON Schema.
    public func toJSONSchema() -> [String: Any] {
        switch self {
        case .string(let constraints):
            var schema: [String: Any] = ["type": "string"]
            applyStringConstraints(constraints, to: &schema)
            return schema

        case .integer(let constraints):
            var schema: [String: Any] = ["type": "integer"]
            applyIntegerConstraints(constraints, to: &schema)
            return schema

        case .number(let constraints):
            var schema: [String: Any] = ["type": "number"]
            applyNumberConstraints(constraints, to: &schema)
            return schema

        case .boolean(_):
            return ["type": "boolean"]

        case .array(let items, let constraints):
            var schema: [String: Any] = [
                "type": "array",
                "items": items.toJSONSchema()
            ]
            applyArrayConstraints(constraints, to: &schema)
            return schema

        case .object(_, let description, let properties):
            var props: [String: Any] = [:]
            var required: [String] = []

            for (key, prop) in properties {
                var propSchema = prop.schema.toJSONSchema()
                if let propDesc = prop.description {
                    propSchema["description"] = propDesc
                }
                props[key] = propSchema
                if prop.isRequired {
                    required.append(key)
                }
            }

            var schema: [String: Any] = [
                "type": "object",
                "properties": props
            ]

            if !required.isEmpty {
                schema["required"] = required
            }

            if let desc = description {
                schema["description"] = desc
            }

            // Anthropic requires additionalProperties: false
            schema["additionalProperties"] = false

            return schema

        case .optional(let wrapped):
            // For optional, we return the inner type
            // The optionality is handled by not including in "required"
            return wrapped.toJSONSchema()

        case .anyOf(_, let description, let schemas):
            var schema: [String: Any] = [
                "anyOf": schemas.map { $0.toJSONSchema() }
            ]
            if let desc = description {
                schema["description"] = desc
            }
            return schema
        }
    }

    // MARK: - Constraint Application

    private func applyStringConstraints(_ constraints: [StringConstraint], to schema: inout [String: Any]) {
        for constraint in constraints {
            switch constraint {
            case .pattern(let pattern):
                schema["pattern"] = pattern
            case .constant(let value):
                schema["const"] = value
            case .anyOf(let values):
                schema["enum"] = values
            case .minLength(let length):
                schema["minLength"] = length
            case .maxLength(let length):
                schema["maxLength"] = length
            }
        }
    }

    private func applyIntegerConstraints(_ constraints: [IntConstraint], to schema: inout [String: Any]) {
        for constraint in constraints {
            switch constraint {
            case .range(let lower, let upper):
                if let min = lower {
                    schema["minimum"] = min
                }
                if let max = upper {
                    schema["maximum"] = max
                }
            }
        }
    }

    private func applyNumberConstraints(_ constraints: [DoubleConstraint], to schema: inout [String: Any]) {
        for constraint in constraints {
            switch constraint {
            case .range(let lower, let upper):
                if let min = lower {
                    schema["minimum"] = min
                }
                if let max = upper {
                    schema["maximum"] = max
                }
            }
        }
    }

    private func applyArrayConstraints(_ constraints: [ArrayConstraint], to schema: inout [String: Any]) {
        for constraint in constraints {
            switch constraint {
            case .count(let lower, let upper):
                if let min = lower {
                    schema["minItems"] = min
                }
                if let max = upper {
                    schema["maxItems"] = max
                }
            }
        }
    }
}

// MARK: - AnyAITool Conversion

extension AnyAITool {

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
    public func toOpenAIFormat() -> Any {
        switch self {
        case .auto:
            return "auto"
        case .required:
            return "required"
        case .none:
            return "none"
        case .tool(let name):
            return ["type": "function", "function": ["name": name]]
        }
    }
}

// MARK: - Collection Extension for Tool Conversion

extension Collection where Element == AnyAITool {

    /// Converts all tools to Anthropic's format.
    ///
    /// - Returns: An array of tool dictionaries for Anthropic's API.
    public func toAnthropicFormat() -> [[String: Any]] {
        map { $0.toAnthropicFormat() }
    }

    /// Converts all tools to OpenAI's format.
    ///
    /// - Returns: An array of tool dictionaries for OpenAI's API.
    public func toOpenAIFormat() -> [[String: Any]] {
        map { $0.toOpenAIFormat() }
    }
}
