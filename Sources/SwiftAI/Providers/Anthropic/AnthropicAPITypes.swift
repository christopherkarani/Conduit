// AnthropicAPITypes.swift
// SwiftAI
//
// Data Transfer Objects for Anthropic Messages API.

import Foundation

// MARK: - AnthropicMessagesRequest

/// Request body for Anthropic Messages API.
///
/// Represents the HTTP request body sent to the `/v1/messages` endpoint.
/// All fields use snake_case naming to match the API specification.
///
/// ## Usage
/// ```swift
/// let request = AnthropicMessagesRequest(
///     model: "claude-opus-4-5-20251101",
///     messages: [
///         MessageContent(role: "user", content: "Hello, Claude!")
///     ],
///     maxTokens: 1024,
///     temperature: 0.7
/// )
/// ```
///
/// ## API Reference
/// - Endpoint: `POST /v1/messages`
/// - Documentation: https://docs.anthropic.com/en/api/messages
internal struct AnthropicMessagesRequest: Codable, Sendable {

    // MARK: - Properties

    /// The model identifier to use for generation.
    ///
    /// Example: `"claude-opus-4-5-20251101"`
    let model: String

    /// The conversation history as an array of message objects.
    ///
    /// Each message must have a `role` ("user" or "assistant") and `content`.
    let messages: [MessageContent]

    /// Maximum number of tokens to generate.
    ///
    /// This is a required field in the Anthropic API.
    let maxTokens: Int

    /// System prompt to guide the model's behavior.
    ///
    /// Optional. Sets context and instructions for the assistant.
    let system: String?

    /// Sampling temperature (0.0 to 1.0).
    ///
    /// Optional. Controls randomness in generation.
    /// - 0.0: Deterministic
    /// - 1.0: Maximum randomness
    let temperature: Double?

    /// Nucleus sampling parameter (0.0 to 1.0).
    ///
    /// Optional. Controls diversity via cumulative probability.
    let topP: Double?

    /// Top-k sampling parameter.
    ///
    /// Optional. Limits vocabulary to the k most likely tokens.
    let topK: Int?

    /// Whether to stream the response.
    ///
    /// Optional. When `true`, returns Server-Sent Events.
    let stream: Bool?

    /// Extended thinking configuration.
    ///
    /// When provided, enables extended thinking mode where the model
    /// reasons longer before responding.
    ///
    /// Optional. When `nil`, thinking is disabled (default behavior).
    let thinking: ThinkingRequest?

    /// Sequences that will cause the model to stop generating.
    ///
    /// Optional. When any of these sequences is encountered, generation stops.
    let stopSequences: [String]?

    /// Request metadata for tracking and analytics.
    ///
    /// Optional. Contains user ID for per-user usage tracking.
    let metadata: Metadata?

    /// Service tier for capacity management.
    ///
    /// Optional. Controls routing priority for the request.
    /// - `"auto"`: Automatic tier selection (default)
    /// - `"standard_only"`: Standard capacity only, no priority routing
    let serviceTier: String?

    /// Tools available for the model to use.
    ///
    /// Optional. When provided, allows the model to call these tools during generation.
    let tools: [ToolDefinitionRequest]?

    /// Controls how the model chooses tools.
    ///
    /// Optional. Specifies whether tool use is automatic, required, or specific.
    let toolChoice: ToolChoiceRequest?

    // MARK: - Coding Keys

    /// Maps Swift property names to API's snake_case fields.
    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case maxTokens = "max_tokens"
        case system
        case temperature
        case topP = "top_p"
        case topK = "top_k"
        case stream
        case thinking
        case stopSequences = "stop_sequences"
        case metadata
        case serviceTier = "service_tier"
        case tools
        case toolChoice = "tool_choice"
    }

    // MARK: - ToolDefinitionRequest

    /// Tool definition for Anthropic's API format.
    ///
    /// Represents a tool that Claude can call during generation.
    struct ToolDefinitionRequest: Codable, Sendable {
        /// The tool's unique name.
        let name: String

        /// Human-readable description of what the tool does.
        let description: String

        /// JSON Schema for the tool's input parameters.
        let inputSchema: InputSchema

        enum CodingKeys: String, CodingKey {
            case name
            case description
            case inputSchema = "input_schema"
        }

        /// JSON Schema wrapper for input parameters.
        struct InputSchema: Codable, Sendable {
            let type: String
            let properties: [String: PropertySchema]
            let required: [String]?
            let additionalProperties: Bool?

            enum CodingKeys: String, CodingKey {
                case type
                case properties
                case required
                case additionalProperties
            }
        }

        /// Schema for a single property in the input.
        struct PropertySchema: Codable, Sendable {
            let type: SchemaType
            let description: String?
            let items: ItemSchema?
            let properties: [String: PropertySchema]?
            let required: [String]?
            let additionalProperties: Bool?
            let enumValues: [String]?
            let minimum: Int?
            let maximum: Int?
            let minLength: Int?
            let maxLength: Int?
            let pattern: String?
            let const: String?

            enum CodingKeys: String, CodingKey {
                case type
                case description
                case items
                case properties
                case required
                case additionalProperties
                case enumValues = "enum"
                case minimum
                case maximum
                case minLength
                case maxLength
                case pattern
                case const
            }
        }

        /// Schema for array items.
        struct ItemSchema: Codable, Sendable {
            let type: SchemaType
            let description: String?

            enum CodingKeys: String, CodingKey {
                case type
                case description
            }
        }

        /// JSON Schema type - can be a single type or array (for nullable).
        enum SchemaType: Codable, Sendable {
            case single(String)
            case multiple([String])

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let string = try? container.decode(String.self) {
                    self = .single(string)
                } else if let array = try? container.decode([String].self) {
                    self = .multiple(array)
                } else {
                    throw DecodingError.typeMismatch(
                        SchemaType.self,
                        DecodingError.Context(codingPath: decoder.codingPath,
                                              debugDescription: "Expected String or [String]")
                    )
                }
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                switch self {
                case .single(let type):
                    try container.encode(type)
                case .multiple(let types):
                    try container.encode(types)
                }
            }
        }
    }

    // MARK: - ToolChoiceRequest

    /// Tool choice configuration for Anthropic's API.
    ///
    /// Controls how the model decides whether to use tools.
    struct ToolChoiceRequest: Codable, Sendable {
        /// The type of tool choice.
        ///
        /// - `"auto"`: Model decides whether to use tools
        /// - `"any"`: Model must use at least one tool
        /// - `"tool"`: Model must use the specific tool named
        let type: String

        /// Specific tool name (only for type="tool").
        let name: String?
    }

    // MARK: - ThinkingRequest

    /// Extended thinking request configuration.
    ///
    /// Sent to the API when extended thinking is enabled. Specifies the
    /// thinking mode and token budget for the internal reasoning process.
    ///
    /// ## Usage
    /// ```swift
    /// let thinking = ThinkingRequest(
    ///     type: "enabled",
    ///     budget_tokens: 1024
    /// )
    /// ```
    ///
    /// ## API Format
    /// ```json
    /// {
    ///   "thinking": {
    ///     "type": "enabled",
    ///     "budget_tokens": 1024
    ///   }
    /// }
    /// ```
    struct ThinkingRequest: Codable, Sendable {

        /// Type of thinking (always "enabled" when present).
        ///
        /// The API currently only supports the "enabled" type.
        /// Future versions may support additional thinking modes.
        let type: String

        /// Token budget for thinking.
        ///
        /// Controls how many tokens the model can use for internal
        /// reasoning before generating the response.
        let budget_tokens: Int
    }

    // MARK: - Metadata

    /// Request metadata for tracking and analytics.
    ///
    /// Contains user identification for per-user usage tracking and analytics
    /// in the Anthropic dashboard.
    ///
    /// ## Usage
    /// ```swift
    /// let metadata = Metadata(userId: "user_12345")
    /// ```
    ///
    /// ## API Format
    /// ```json
    /// {
    ///   "metadata": {
    ///     "user_id": "user_12345"
    ///   }
    /// }
    /// ```
    struct Metadata: Codable, Sendable {

        /// User ID for tracking usage per user.
        ///
        /// This allows you to track usage and costs by user in
        /// the Anthropic console and API responses.
        let userId: String

        // MARK: - Coding Keys

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
        }
    }

    // MARK: - MessageContent

    /// A single message in the conversation.
    ///
    /// Represents one turn in the chat, with a role and content.
    ///
    /// ## Roles
    /// - `"user"`: Message from the human
    /// - `"assistant"`: Message from Claude
    struct MessageContent: Codable, Sendable {

        /// The role of the message sender.
        ///
        /// Must be either `"user"` or `"assistant"`.
        let role: String

        /// The content of the message (text or multimodal).
        ///
        /// Supports both simple text strings and multimodal content with images.
        let content: ContentType

        // MARK: - ContentType

        /// Content type - text or multipart (for vision).
        ///
        /// Anthropic's API supports two formats:
        /// - Simple string: `"content": "Hello"`
        /// - Array of parts: `"content": [{"type":"text","text":"Hello"},{"type":"image",...}]`
        enum ContentType: Codable, Sendable {
            /// Simple text content.
            case text(String)

            /// Multipart content (text + images).
            case multipart([ContentPart])

            // MARK: - Codable

            /// Encodes content to JSON.
            ///
            /// - Text: Encoded as a simple string
            /// - Multipart: Encoded as an array of content parts
            ///
            /// - Parameter encoder: The encoder to write to.
            /// - Throws: `EncodingError` if encoding fails.
            func encode(to encoder: Encoder) throws {
                switch self {
                case .text(let str):
                    var container = encoder.singleValueContainer()
                    try container.encode(str)

                case .multipart(let parts):
                    var container = encoder.unkeyedContainer()
                    for part in parts {
                        try container.encode(part)
                    }
                }
            }

            /// Decodes content from JSON.
            ///
            /// Tries string first, then array of parts.
            ///
            /// - Parameter decoder: The decoder to read from.
            /// - Throws: `DecodingError` if neither format matches.
            init(from decoder: Decoder) throws {
                // Try string first
                if let str = try? decoder.singleValueContainer().decode(String.self) {
                    self = .text(str)
                } else {
                    // Try array of parts
                    var container = try decoder.unkeyedContainer()
                    var parts: [ContentPart] = []
                    while !container.isAtEnd {
                        parts.append(try container.decode(ContentPart.self))
                    }
                    self = .multipart(parts)
                }
            }
        }

        // MARK: - ContentPart

        /// Content part for multimodal messages.
        ///
        /// Represents a single piece of content (text or image) in a multimodal message.
        struct ContentPart: Codable, Sendable {
            /// The type of content ("text" or "image").
            let type: String

            /// The text content (for text parts).
            let text: String?

            /// The image source (for image parts).
            let source: ImageSource?

            /// Image source with base64 data.
            ///
            /// Anthropic expects images in this format:
            /// ```json
            /// {
            ///   "type": "image",
            ///   "source": {
            ///     "type": "base64",
            ///     "media_type": "image/jpeg",
            ///     "data": "base64-encoded-data"
            ///   }
            /// }
            /// ```
            struct ImageSource: Codable, Sendable {
                /// Source type (always "base64").
                let type: String

                /// Media type ("image/jpeg", "image/png", "image/gif", "image/webp").
                let mediaType: String

                /// Base64-encoded image data.
                let data: String

                // MARK: - Coding Keys

                enum CodingKeys: String, CodingKey {
                    case type
                    case mediaType = "media_type"
                    case data
                }
            }
        }
    }
}

// MARK: - AnthropicMessagesResponse

/// Response body from Anthropic Messages API.
///
/// Represents the HTTP response body from the `/v1/messages` endpoint
/// for non-streaming requests.
///
/// ## Usage
/// ```swift
/// let data = try await performRequest()
/// let response = try JSONDecoder().decode(AnthropicMessagesResponse.self, from: data)
/// print(response.content.first?.text ?? "")
/// ```
///
/// ## API Reference
/// - Endpoint: `POST /v1/messages`
/// - Documentation: https://docs.anthropic.com/en/api/messages
internal struct AnthropicMessagesResponse: Codable, Sendable {

    // MARK: - Properties

    /// Unique identifier for the message.
    ///
    /// Example: `"msg_abc123"`
    let id: String

    /// The object type (always `"message"`).
    let type: String

    /// The role of the responder (always `"assistant"`).
    let role: String

    /// Array of content blocks in the response.
    ///
    /// Typically contains a single text block, but can include multiple blocks
    /// for tool use or structured responses.
    let content: [ContentBlock]

    /// The model used for generation.
    ///
    /// Example: `"claude-opus-4-5-20251101"`
    let model: String

    /// The reason generation stopped.
    ///
    /// Common values:
    /// - `"end_turn"`: Natural completion
    /// - `"max_tokens"`: Hit token limit
    /// - `"stop_sequence"`: Hit a stop sequence
    let stopReason: String

    /// Token usage statistics for this request.
    let usage: Usage

    // MARK: - Coding Keys

    /// Maps Swift property names to API's snake_case fields.
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case role
        case content
        case model
        case stopReason = "stop_reason"
        case usage
    }

    // MARK: - ContentBlock

    /// A single content block in the response.
    ///
    /// Content blocks can be text, thinking, tool use, or other structured data.
    ///
    /// ## Types
    /// - `"text"`: Plain text content (response to user)
    /// - `"thinking"`: Extended thinking process (internal reasoning)
    /// - `"tool_use"`: Tool/function call (not implemented here)
    ///
    /// ## Extended Thinking
    ///
    /// When extended thinking is enabled, the response may contain both
    /// thinking blocks and text blocks:
    /// - **Thinking blocks**: Internal reasoning (not shown to user)
    /// - **Text blocks**: Final response (shown to user)
    struct ContentBlock: Codable, Sendable {

        /// The type of content block.
        ///
        /// Common values:
        /// - `"text"`: Plain text content
        /// - `"thinking"`: Extended thinking process
        let type: String

        /// The text content (if type is "text" or "thinking").
        ///
        /// For "text" blocks, contains the response to show the user.
        /// For "thinking" blocks, contains the internal reasoning process.
        ///
        /// Optional because other block types (like "tool_use") don't have text.
        let text: String?
    }

    // MARK: - Usage

    /// Token usage statistics.
    ///
    /// Tracks tokens consumed by the request and response.
    struct Usage: Codable, Sendable {

        /// Number of tokens in the input (prompt).
        let inputTokens: Int

        /// Number of tokens in the output (completion).
        let outputTokens: Int

        // MARK: - Coding Keys

        /// Maps Swift property names to API's snake_case fields.
        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
        }
    }
}

// MARK: - AnthropicErrorResponse

/// Error response from Anthropic API.
///
/// Represents the HTTP response body when an error occurs.
///
/// ## Usage
/// ```swift
/// if httpResponse.statusCode != 200 {
///     let errorResponse = try JSONDecoder().decode(AnthropicErrorResponse.self, from: data)
///     throw AIError.serverError(
///         statusCode: httpResponse.statusCode,
///         message: errorResponse.error.message
///     )
/// }
/// ```
///
/// ## API Reference
/// - Documentation: https://docs.anthropic.com/en/api/errors
internal struct AnthropicErrorResponse: Codable, Sendable {

    /// The error details.
    let error: ErrorDetail

    // MARK: - ErrorDetail

    /// Detailed information about an API error.
    struct ErrorDetail: Codable, Sendable {

        /// The error type.
        ///
        /// Common values:
        /// - `"invalid_request_error"`: Invalid request parameters
        /// - `"authentication_error"`: Invalid API key
        /// - `"permission_error"`: Insufficient permissions
        /// - `"not_found_error"`: Resource not found
        /// - `"rate_limit_error"`: Rate limit exceeded
        /// - `"api_error"`: Internal server error
        let type: String

        /// Human-readable error message.
        ///
        /// Describes what went wrong and may include suggestions.
        let message: String
    }
}

// MARK: - AnthropicStreamEvent

/// Server-Sent Event types for streaming responses.
///
/// Anthropic's streaming API emits different event types as the response
/// is generated. This enum represents all possible event types.
///
/// ## Usage
/// ```swift
/// for try await event in streamEvents {
///     switch event {
///     case .messageStart(let start):
///         print("Message started: \(start.message.role)")
///     case .contentBlockDelta(let delta):
///         print(delta.delta.text, terminator: "")
///     case .messageStop:
///         print("\nComplete!")
///     default:
///         break
///     }
/// }
/// ```
///
/// ## Event Flow
/// 1. `messageStart`: Message metadata
/// 2. `contentBlockStart`: Content block begins
/// 3. `contentBlockDelta`: Text chunks (multiple)
/// 4. `contentBlockStop`: Content block ends
/// 5. `messageStop`: Message complete
///
/// ## API Reference
/// - Documentation: https://docs.anthropic.com/en/api/streaming
internal enum AnthropicStreamEvent: Sendable {

    /// Message started event.
    ///
    /// Emitted first, contains initial message metadata.
    case messageStart(MessageStart)

    /// Content block started event.
    ///
    /// Emitted when a new content block begins (text, tool use, etc).
    case contentBlockStart(ContentBlockStart)

    /// Content block delta event.
    ///
    /// Emitted for each chunk of text in a content block.
    /// This is the primary event for streaming text.
    case contentBlockDelta(ContentBlockDelta)

    /// Content block stopped event.
    ///
    /// Emitted when a content block is complete.
    case contentBlockStop

    /// Message stopped event.
    ///
    /// Emitted last, indicates the message is complete.
    case messageStop

    /// Message delta event.
    ///
    /// Emitted near the end of streaming with final usage statistics
    /// and the stop reason.
    case messageDelta(MessageDelta)

    /// Streaming error event.
    ///
    /// Emitted when an error occurs during streaming.
    case error(StreamError)

    /// Ping keep-alive event.
    ///
    /// Heartbeat event sent periodically to keep the connection alive.
    case ping

    // MARK: - MessageStart

    /// Data for `message_start` event.
    ///
    /// Contains initial metadata about the message being generated.
    struct MessageStart: Codable, Sendable {

        /// The message metadata.
        let message: MessageMetadata

        /// Initial message metadata.
        struct MessageMetadata: Codable, Sendable {

            /// Unique message identifier.
            let id: String

            /// Object type (always `"message"`).
            let type: String

            /// Role (always `"assistant"`).
            let role: String

            /// Initial content blocks (typically empty).
            let content: [String]

            /// Model being used.
            let model: String

            /// Initial stop reason (typically `null`).
            let stopReason: String?

            /// Initial stop sequence (typically `null`).
            let stopSequence: String?

            // MARK: - Coding Keys

            enum CodingKeys: String, CodingKey {
                case id
                case type
                case role
                case content
                case model
                case stopReason = "stop_reason"
                case stopSequence = "stop_sequence"
            }
        }
    }

    // MARK: - ContentBlockStart

    /// Data for `content_block_start` event.
    ///
    /// Indicates a new content block is starting.
    struct ContentBlockStart: Codable, Sendable {

        /// Index of this content block in the message.
        let index: Int

        /// The content block metadata.
        let contentBlock: ContentBlockMetadata

        /// Content block metadata.
        struct ContentBlockMetadata: Codable, Sendable {

            /// Block type (e.g., `"text"`, `"tool_use"`).
            let type: String

            /// Initial text (typically empty for text blocks).
            let text: String?
        }

        // MARK: - Coding Keys

        enum CodingKeys: String, CodingKey {
            case index
            case contentBlock = "content_block"
        }
    }

    // MARK: - ContentBlockDelta

    /// Data for `content_block_delta` event.
    ///
    /// Contains incremental text chunks for streaming.
    struct ContentBlockDelta: Codable, Sendable {

        /// Index of the content block being updated.
        let index: Int

        /// The incremental delta.
        let delta: Delta

        /// Incremental text delta.
        struct Delta: Codable, Sendable {

            /// Delta type (always `"text_delta"` for text).
            let type: String

            /// The text chunk to append.
            let text: String
        }
    }

    // MARK: - MessageDelta

    /// Message delta event containing final usage statistics.
    ///
    /// Sent at the end of a streaming response with the stop reason
    /// and token usage counts.
    ///
    /// ## JSON Structure
    /// ```json
    /// {
    ///   "type": "message_delta",
    ///   "delta": {
    ///     "stop_reason": "end_turn",
    ///     "stop_sequence": null
    ///   },
    ///   "usage": {
    ///     "input_tokens": 25,
    ///     "output_tokens": 150
    ///   }
    /// }
    /// ```
    struct MessageDelta: Codable, Sendable {

        /// The delta containing stop information.
        let delta: Delta

        /// Token usage statistics.
        let usage: Usage

        /// Delta containing stop reason information.
        struct Delta: Codable, Sendable {

            /// The reason generation stopped.
            ///
            /// Possible values:
            /// - `"end_turn"`: Natural completion
            /// - `"max_tokens"`: Token limit reached
            /// - `"stop_sequence"`: Stop sequence encountered
            /// - `"tool_use"`: Tool call requested
            let stopReason: String?

            /// The stop sequence that triggered termination.
            ///
            /// Only populated if `stopReason` is `"stop_sequence"`.
            let stopSequence: String?

            // MARK: - Coding Keys

            enum CodingKeys: String, CodingKey {
                case stopReason = "stop_reason"
                case stopSequence = "stop_sequence"
            }
        }

        /// Token usage statistics from the streaming response.
        struct Usage: Codable, Sendable {

            /// Number of tokens in the input prompt.
            let inputTokens: Int

            /// Number of tokens in the generated output.
            let outputTokens: Int

            // MARK: - Coding Keys

            enum CodingKeys: String, CodingKey {
                case inputTokens = "input_tokens"
                case outputTokens = "output_tokens"
            }
        }
    }

    // MARK: - StreamError

    /// Error event during streaming.
    ///
    /// Contains error details when an error occurs during a streaming response.
    ///
    /// ## JSON Structure
    /// ```json
    /// {
    ///   "type": "error",
    ///   "error": {
    ///     "type": "overloaded_error",
    ///     "message": "Overloaded"
    ///   }
    /// }
    /// ```
    struct StreamError: Codable, Sendable {

        /// The error details.
        let error: ErrorDetail

        /// Detailed information about the streaming error.
        struct ErrorDetail: Codable, Sendable {

            /// The error type.
            ///
            /// Common values:
            /// - `"overloaded_error"`: Server overloaded
            /// - `"api_error"`: Internal API error
            /// - `"rate_limit_error"`: Rate limit exceeded
            let type: String

            /// Human-readable error message.
            let message: String
        }
    }
}
