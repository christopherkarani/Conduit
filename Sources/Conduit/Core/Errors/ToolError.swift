// ToolError.swift
// Conduit

import Foundation

public enum ToolError: Error, Sendable, LocalizedError, CustomStringConvertible {

    case invalidToolName(name: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case .invalidToolName(let name, let reason):
            return "Invalid tool name '\(name)': \(reason)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .invalidToolName:
            return "Use a tool name containing only alphanumeric characters, underscores, and hyphens."
        }
    }

    public var description: String {
        errorDescription ?? "Unknown tool error"
    }
}
