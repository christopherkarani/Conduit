// Message.swift
// SwiftAI

import Foundation

// MARK: - MessageMetadata

/// Optional metadata attached to a message.
///
/// Metadata provides additional information about message generation,
/// such as token counts, timing, and custom application-specific data.
///
/// ## Usage
/// ```swift
/// let metadata = MessageMetadata(
///     tokenCount: 42,
///     generationTime: 1.5,
///     model: "llama3_2_1b",
///     tokensPerSecond: 28.0
/// )
/// ```
public struct MessageMetadata: Sendable, Hashable, Codable {

    /// Number of tokens in the message.
    public var tokenCount: Int?

    /// Time taken to generate this message (in seconds).
    public var generationTime: TimeInterval?

    /// The model that generated this message.
    public var model: String?

    /// Tokens generated per second (throughput).
    public var tokensPerSecond: Double?

    /// Custom application-specific metadata.
    public var custom: [String: String]?

    /// Creates message metadata with optional fields.
    ///
    /// - Parameters:
    ///   - tokenCount: Number of tokens in the message.
    ///   - generationTime: Time taken to generate (in seconds).
    ///   - model: The model identifier that generated this message.
    ///   - tokensPerSecond: Generation throughput.
    ///   - custom: Custom key-value pairs for application-specific data.
    public init(
        tokenCount: Int? = nil,
        generationTime: TimeInterval? = nil,
        model: String? = nil,
        tokensPerSecond: Double? = nil,
        custom: [String: String]? = nil
    ) {
        self.tokenCount = tokenCount
        self.generationTime = generationTime
        self.model = model
        self.tokensPerSecond = tokensPerSecond
        self.custom = custom
    }
}

// MARK: - Message

/// A message in a conversation.
///
/// Messages represent individual turns in a chat conversation, with support
/// for text and multimodal content (text + images).
///
/// ## Usage
/// ```swift
/// // Simple text messages
/// let messages: [Message] = [
///     .system("You are a helpful assistant."),
///     .user("What is Swift?"),
///     .assistant("Swift is a programming language...")
/// ]
///
/// // Multimodal message with image
/// let imageMessage = Message(
///     role: .user,
///     content: .parts([
///         .text("What's in this image?"),
///         .image(Message.ImageContent(base64Data: base64String))
///     ])
/// )
/// ```
///
/// ## Roles
/// - `system`: Sets context and behavior for the assistant
/// - `user`: Input from the human user
/// - `assistant`: Response from the AI model
/// - `tool`: Result from a tool/function call
///
/// ## Protocol Conformances
/// - `Identifiable`: Each message has a unique UUID
/// - `Codable`: Full JSON encoding/decoding support
/// - `Hashable`: Can be used in sets and as dictionary keys
/// - `Sendable`: Thread-safe across concurrency boundaries
public struct Message: Sendable, Hashable, Codable, Identifiable {

    /// Unique identifier for this message.
    public let id: UUID

    /// The role that sent this message.
    public let role: Role

    /// The content of the message (text or multimodal).
    public let content: Content

    /// When this message was created.
    public let timestamp: Date

    /// Optional metadata about message generation.
    public let metadata: MessageMetadata?

    /// Creates a new message.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (generated if not provided).
    ///   - role: The sender's role.
    ///   - content: The message content.
    ///   - timestamp: Creation timestamp (defaults to now).
    ///   - metadata: Optional generation metadata.
    public init(
        id: UUID = UUID(),
        role: Role,
        content: Content,
        timestamp: Date = Date(),
        metadata: MessageMetadata? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.metadata = metadata
    }

    // MARK: - Factory Methods

    /// Creates a system message with text content.
    ///
    /// System messages set the assistant's behavior and context.
    ///
    /// ## Usage
    /// ```swift
    /// let systemMsg = Message.system("You are a helpful coding assistant.")
    /// ```
    ///
    /// - Parameter text: The system message text.
    /// - Returns: A message with `role: .system`.
    public static func system(_ text: String) -> Message {
        Message(role: .system, content: .text(text))
    }

    /// Creates a user message with text content.
    ///
    /// User messages represent human input to the conversation.
    ///
    /// ## Usage
    /// ```swift
    /// let userMsg = Message.user("What is Swift?")
    /// ```
    ///
    /// - Parameter text: The user's message text.
    /// - Returns: A message with `role: .user`.
    public static func user(_ text: String) -> Message {
        Message(role: .user, content: .text(text))
    }

    /// Creates an assistant message with text content.
    ///
    /// Assistant messages represent AI-generated responses.
    ///
    /// ## Usage
    /// ```swift
    /// let assistantMsg = Message.assistant("Swift is a programming language...")
    /// ```
    ///
    /// - Parameter text: The assistant's response text.
    /// - Returns: A message with `role: .assistant`.
    public static func assistant(_ text: String) -> Message {
        Message(role: .assistant, content: .text(text))
    }

    /// Creates a user message with text content (alternative syntax).
    ///
    /// This provides a named parameter alternative to the shorthand `user(_:)`.
    ///
    /// ## Usage
    /// ```swift
    /// let userMsg = Message.user(text: "Hello!")
    /// ```
    ///
    /// - Parameter text: The user's message text.
    /// - Returns: A message with `role: .user`.
    public static func user(text: String) -> Message {
        Message(role: .user, content: .text(text))
    }
}

// MARK: - Message.Role

extension Message {

    /// The role of a message sender in a conversation.
    ///
    /// ## Roles
    /// - `system`: Sets behavior and context (typically first message)
    /// - `user`: Human input messages
    /// - `assistant`: AI-generated responses
    /// - `tool`: Results from function/tool calls
    ///
    /// ## Usage
    /// ```swift
    /// let message = Message(role: .user, content: .text("Hello"))
    /// if message.role == .assistant {
    ///     print("AI response")
    /// }
    /// ```
    public enum Role: String, Sendable, Codable, CaseIterable {
        /// System message that sets context and behavior.
        case system

        /// Message from the human user.
        case user

        /// Message from the AI assistant.
        case assistant

        /// Message containing tool/function call results.
        case tool
    }
}

// MARK: - Message.Content

extension Message {

    /// The content of a message, which can be text-only or multimodal.
    ///
    /// ## Cases
    /// - `text(String)`: Simple text content
    /// - `parts([ContentPart])`: Multimodal content (text + images)
    ///
    /// ## Usage
    /// ```swift
    /// // Text content
    /// let textContent = Content.text("Hello!")
    ///
    /// // Multimodal content
    /// let multiContent = Content.parts([
    ///     .text("Describe this image:"),
    ///     .image(ImageContent(base64Data: imageData))
    /// ])
    ///
    /// // Extract text
    /// print(textContent.textValue) // "Hello!"
    /// ```
    ///
    /// ## Codable Representation
    /// - `.text`: `{"type": "text", "text": "..."}`
    /// - `.parts`: `{"type": "parts", "parts": [...]}`
    public enum Content: Sendable, Hashable, Codable {
        /// Plain text content.
        case text(String)

        /// Multimodal content with multiple parts (text and images).
        case parts([ContentPart])

        /// Extracts the text from this content.
        ///
        /// - For `.text`: Returns the string directly.
        /// - For `.parts`: Concatenates all text parts with newlines.
        ///
        /// ## Usage
        /// ```swift
        /// let content = Content.parts([
        ///     .text("Line 1"),
        ///     .image(imageData),
        ///     .text("Line 2")
        /// ])
        /// print(content.textValue) // "Line 1\nLine 2"
        /// ```
        ///
        /// - Returns: The text representation of this content.
        public var textValue: String {
            switch self {
            case .text(let string):
                return string
            case .parts(let parts):
                return parts.compactMap { part in
                    if case .text(let text) = part { return text }
                    return nil
                }.joined(separator: "\n")
            }
        }

        /// Whether this content has no text.
        ///
        /// - Returns: `true` if `textValue` is empty.
        public var isEmpty: Bool {
            textValue.isEmpty
        }

        // MARK: - Codable

        /// Decodes content from JSON.
        ///
        /// - Parameter decoder: The decoder to read from.
        /// - Throws: `DecodingError` if the structure is invalid.
        ///
        /// ## Expected JSON
        /// - Text: `{"type": "text", "text": "..."}`
        /// - Parts: `{"type": "parts", "parts": [...]}`
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: ContentCodingKeys.self)
            let type = try container.decode(ContentType.self, forKey: .type)

            switch type {
            case .text:
                let text = try container.decode(String.self, forKey: .text)
                self = .text(text)
            case .parts:
                let parts = try container.decode([ContentPart].self, forKey: .parts)
                self = .parts(parts)
            }
        }

        /// Encodes content to JSON.
        ///
        /// - Parameter encoder: The encoder to write to.
        /// - Throws: `EncodingError` if encoding fails.
        ///
        /// ## Generated JSON
        /// - Text: `{"type": "text", "text": "..."}`
        /// - Parts: `{"type": "parts", "parts": [...]}`
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: ContentCodingKeys.self)

            switch self {
            case .text(let string):
                try container.encode(ContentType.text, forKey: .type)
                try container.encode(string, forKey: .text)
            case .parts(let parts):
                try container.encode(ContentType.parts, forKey: .type)
                try container.encode(parts, forKey: .parts)
            }
        }
    }

    // MARK: - Content Codable Support

    private enum ContentCodingKeys: String, CodingKey {
        case type
        case text
        case parts
    }

    private enum ContentType: String, Codable {
        case text
        case parts
    }
}

// MARK: - Message.ContentPart

extension Message {

    /// A single part of multimodal message content.
    ///
    /// Content parts allow messages to contain both text and images.
    ///
    /// ## Cases
    /// - `text(String)`: A text segment
    /// - `image(ImageContent)`: An embedded image
    ///
    /// ## Usage
    /// ```swift
    /// let parts: [ContentPart] = [
    ///     .text("What animal is this?"),
    ///     .image(ImageContent(base64Data: imageBase64))
    /// ]
    /// let message = Message(role: .user, content: .parts(parts))
    /// ```
    ///
    /// ## Codable Representation
    /// - `.text`: `{"type": "text", "text": "..."}`
    /// - `.image`: `{"type": "image", "base64Data": "...", "mimeType": "..."}`
    public enum ContentPart: Sendable, Hashable, Codable {
        /// A text segment.
        case text(String)

        /// An embedded image.
        case image(ImageContent)

        // MARK: - Codable

        /// Decodes a content part from JSON.
        ///
        /// - Parameter decoder: The decoder to read from.
        /// - Throws: `DecodingError` if the structure is invalid.
        ///
        /// ## Expected JSON
        /// - Text: `{"type": "text", "text": "..."}`
        /// - Image: `{"type": "image", "base64Data": "...", "mimeType": "..."}`
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: ContentPartCodingKeys.self)
            let type = try container.decode(PartType.self, forKey: .type)

            switch type {
            case .text:
                let text = try container.decode(String.self, forKey: .text)
                self = .text(text)
            case .image:
                let base64Data = try container.decode(String.self, forKey: .base64Data)
                let mimeType = try container.decode(String.self, forKey: .mimeType)
                self = .image(ImageContent(base64Data: base64Data, mimeType: mimeType))
            }
        }

        /// Encodes a content part to JSON.
        ///
        /// - Parameter encoder: The encoder to write to.
        /// - Throws: `EncodingError` if encoding fails.
        ///
        /// ## Generated JSON
        /// - Text: `{"type": "text", "text": "..."}`
        /// - Image: `{"type": "image", "base64Data": "...", "mimeType": "..."}`
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: ContentPartCodingKeys.self)

            switch self {
            case .text(let string):
                try container.encode(PartType.text, forKey: .type)
                try container.encode(string, forKey: .text)
            case .image(let imageContent):
                try container.encode(PartType.image, forKey: .type)
                try container.encode(imageContent.base64Data, forKey: .base64Data)
                try container.encode(imageContent.mimeType, forKey: .mimeType)
            }
        }
    }

    // MARK: - ContentPart Codable Support

    private enum ContentPartCodingKeys: String, CodingKey {
        case type
        case text
        case base64Data
        case mimeType
    }

    private enum PartType: String, Codable {
        case text
        case image
    }
}

// MARK: - Message.ImageContent

extension Message {

    /// Image content embedded in a message.
    ///
    /// Images are represented as Base64-encoded strings with a MIME type.
    ///
    /// ## Usage
    /// ```swift
    /// // From UIImage/NSImage
    /// guard let imageData = image.jpegData(compressionQuality: 0.8),
    ///       let base64String = imageData.base64EncodedString() else {
    ///     return
    /// }
    /// let imageContent = Message.ImageContent(base64Data: base64String)
    ///
    /// // Use in message
    /// let message = Message(
    ///     role: .user,
    ///     content: .parts([
    ///         .text("What's in this image?"),
    ///         .image(imageContent)
    ///     ])
    /// )
    /// ```
    ///
    /// ## Supported MIME Types
    /// - `image/jpeg` (default)
    /// - `image/png`
    /// - `image/gif`
    /// - `image/webp`
    public struct ImageContent: Sendable, Hashable, Codable {

        /// Base64-encoded image data.
        public let base64Data: String

        /// The MIME type of the image (e.g., "image/jpeg", "image/png").
        public let mimeType: String

        /// Creates image content from Base64-encoded data.
        ///
        /// - Parameters:
        ///   - base64Data: The Base64-encoded image string.
        ///   - mimeType: The MIME type (defaults to "image/jpeg").
        public init(base64Data: String, mimeType: String = "image/jpeg") {
            self.base64Data = base64Data
            self.mimeType = mimeType
        }
    }
}
