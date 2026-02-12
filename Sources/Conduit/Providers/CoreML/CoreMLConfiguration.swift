// CoreMLConfiguration.swift
// Conduit

import Foundation

#if canImport(CoreML)
import CoreML
#endif

/// Configuration for Core ML text generation via `CoreMLProvider`.
public struct CoreMLConfiguration: Sendable, Hashable, Codable {

    /// Message dictionary format used by tokenizer chat templates.
    ///
    /// Keys and values mirror `swift-transformers` chat template expectations while
    /// remaining independent of tokenizer module types.
    public typealias ChatTemplateMessage = [String: JSONValue]

    /// Tool specification dictionary format used by tokenizer chat templates.
    ///
    /// Tool specs are passed to tokenizers when prompt formatting uses chat templates.
    public typealias ToolSpecification = [String: JSONValue]

    /// Compute unit preference used when loading the compiled model.
    public enum ComputeUnits: String, Sendable, Hashable, Codable, CaseIterable {
        case cpuOnly
        case cpuAndGPU
        case cpuAndNeuralEngine
        case all

        #if canImport(CoreML)
        var mlComputeUnits: MLComputeUnits {
            switch self {
            case .cpuOnly:
                return .cpuOnly
            case .cpuAndGPU:
                return .cpuAndGPU
            case .cpuAndNeuralEngine:
                return .cpuAndNeuralEngine
            case .all:
                return .all
            }
        }
        #endif
    }

    /// Input prompt formatting strategy.
    public enum PromptFormatting: String, Sendable, Hashable, Codable, CaseIterable {
        /// Build a role-prefixed plain-text prompt (for tokenizers without chat templates).
        case rolePrefixedText

        /// Format messages through tokenizer chat templates.
        case tokenizerChatTemplate
    }

    /// Tool schema conversion strategy when using tokenizer chat templates.
    public enum ToolSpecificationStrategy: String, Sendable, Hashable, Codable, CaseIterable {
        /// Do not pass tool specifications to the tokenizer.
        case none

        /// Convert tools to OpenAI-style function specs.
        case openAIFunction
    }

    /// Compute units preference for model execution.
    public var computeUnits: ComputeUnits

    /// Default maximum output tokens when `GenerateConfig.maxTokens` is unset.
    public var defaultMaxTokens: Int

    /// Prompt formatting strategy used before tokenization.
    public var promptFormatting: PromptFormatting

    /// Strategy for converting `GenerateConfig.tools` into template tool specs.
    public var toolSpecificationStrategy: ToolSpecificationStrategy

    /// Optional literal chat template override.
    ///
    /// When set and `promptFormatting == .tokenizerChatTemplate`, this template
    /// is used instead of the tokenizer's built-in template.
    public var chatTemplate: String?

    /// Optional extra variables available to chat-template rendering.
    public var additionalTemplateContext: [String: JSONValue]?

    /// Creates a Core ML configuration.
    public init(
        computeUnits: ComputeUnits = .all,
        defaultMaxTokens: Int = 512,
        promptFormatting: PromptFormatting = .rolePrefixedText,
        toolSpecificationStrategy: ToolSpecificationStrategy = .openAIFunction,
        chatTemplate: String? = nil,
        additionalTemplateContext: [String: JSONValue]? = nil
    ) {
        self.computeUnits = computeUnits
        self.defaultMaxTokens = max(1, defaultMaxTokens)
        self.promptFormatting = promptFormatting
        self.toolSpecificationStrategy = toolSpecificationStrategy
        if let chatTemplate, !chatTemplate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.chatTemplate = chatTemplate
        } else {
            self.chatTemplate = nil
        }
        self.additionalTemplateContext = additionalTemplateContext?.isEmpty == true ? nil : additionalTemplateContext
    }
}

public extension CoreMLConfiguration {
    /// Default balanced Core ML configuration.
    static let `default` = CoreMLConfiguration()
}
