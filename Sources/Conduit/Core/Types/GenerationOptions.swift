// GenerationOptions.swift
// Conduit

/// Options that control how the model generates its response to a prompt.
///
/// This mirrors the public API shape used by AnyLanguageModel / Foundation Models,
/// and is used by `Transcript.Prompt`.
public struct GenerationOptions: Sendable, Equatable, Codable {
    /// A type that defines how values are sampled from a probability distribution.
    public struct SamplingMode: Sendable, Equatable, Codable {
        enum Mode: Equatable, Codable {
            case greedy
            case topK(Int, seed: UInt64?)
            case nucleus(Double, seed: UInt64?)
        }

        let mode: Mode

        /// A sampling mode that always chooses the most likely token.
        public static var greedy: SamplingMode {
            SamplingMode(mode: .greedy)
        }

        /// A sampling mode that considers a fixed number of high-probability tokens.
        ///
        /// Also known as top-k.
        public static func random(top k: Int, seed: UInt64? = nil) -> SamplingMode {
            SamplingMode(mode: .topK(k, seed: seed))
        }

        /// A sampling mode that considers a variable number of high-probability tokens
        /// based on the specified threshold.
        ///
        /// Also known as top-p or nucleus sampling.
        public static func random(probabilityThreshold: Double, seed: UInt64? = nil) -> SamplingMode {
            SamplingMode(mode: .nucleus(probabilityThreshold, seed: seed))
        }
    }

    /// A sampling strategy for how the model picks tokens when generating a response.
    public var sampling: SamplingMode?

    /// Temperature influences the confidence of the models response.
    ///
    /// The value of this property must be a number between `0` and `1` inclusive.
    public var temperature: Double?

    /// The maximum number of tokens the model is allowed to produce in its response.
    public var maximumResponseTokens: Int?

    /// Creates generation options that control token sampling behavior.
    public init(
        sampling: SamplingMode? = nil,
        temperature: Double? = nil,
        maximumResponseTokens: Int? = nil
    ) {
        self.sampling = sampling
        self.temperature = temperature
        self.maximumResponseTokens = maximumResponseTokens
    }
}

/// A protocol for model-specific generation options.
public protocol CustomGenerationOptions: Equatable, Sendable {}

extension Never: CustomGenerationOptions {}
extension Dictionary: CustomGenerationOptions where Key == String, Value == JSONValue {}

// MARK: - GenerateConfig Bridge

extension GenerationOptions {
    /// Converts prompt-level options into provider runtime generation config.
    ///
    /// - Parameters:
    ///   - responseFormat: Optional response format to carry into the runtime config.
    ///   - base: Base config to preserve non-option defaults.
    /// - Returns: A `GenerateConfig` populated from these options.
    public func toGenerateConfig(
        responseFormat: ResponseFormat? = nil,
        base: GenerateConfig = .default
    ) -> GenerateConfig {
        GenerateConfig(options: self, responseFormat: responseFormat, base: base)
    }
}
