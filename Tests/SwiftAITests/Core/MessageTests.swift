// MessageTests.swift
// SwiftAITests

import Foundation
import Testing
@testable import SwiftAI

/// Tests for Phase 4: Message Types & Content System
@Suite("Message Types")
struct MessageTests {

    // MARK: - Message Creation Tests

    @Test("System message creation")
    func systemMessageCreation() {
        let message = Message.system("You are helpful.")

        #expect(message.role == .system)
        #expect(message.content.textValue == "You are helpful.")
        #expect(message.metadata == nil)
    }

    @Test("User message creation")
    func userMessageCreation() {
        let message = Message.user("Hello")

        #expect(message.role == .user)
        #expect(message.content.textValue == "Hello")
    }

    @Test("Assistant message creation")
    func assistantMessageCreation() {
        let message = Message.assistant("Hi there!")

        #expect(message.role == .assistant)
        #expect(message.content.textValue == "Hi there!")
    }

    @Test("User message with named parameter")
    func userMessageNamedParameter() {
        let message = Message.user(text: "Test")

        #expect(message.role == .user)
        #expect(message.content.textValue == "Test")
    }

    @Test("Message with metadata")
    func messageWithMetadata() {
        let metadata = MessageMetadata(
            tokenCount: 42,
            generationTime: 1.5,
            model: "llama3_2_1b",
            tokensPerSecond: 28.0
        )

        let message = Message(
            role: .assistant,
            content: .text("Response"),
            metadata: metadata
        )

        #expect(message.metadata?.tokenCount == 42)
        #expect(message.metadata?.generationTime == 1.5)
        #expect(message.metadata?.model == "llama3_2_1b")
        #expect(message.metadata?.tokensPerSecond == 28.0)
    }

    // MARK: - Role Tests

    @Test("All role cases exist")
    func allRoleCases() {
        let roles = Message.Role.allCases

        #expect(roles.count == 4)
        #expect(roles.contains(.system))
        #expect(roles.contains(.user))
        #expect(roles.contains(.assistant))
        #expect(roles.contains(.tool))
    }

    @Test("Role raw values")
    func roleRawValues() {
        #expect(Message.Role.system.rawValue == "system")
        #expect(Message.Role.user.rawValue == "user")
        #expect(Message.Role.assistant.rawValue == "assistant")
        #expect(Message.Role.tool.rawValue == "tool")
    }

    // MARK: - Content Tests

    @Test("Content text value extraction")
    func contentTextValue() {
        let content = Message.Content.text("Hello World")

        #expect(content.textValue == "Hello World")
        #expect(!content.isEmpty)
    }

    @Test("Multipart content text value extraction")
    func multipartContentTextValue() {
        let content = Message.Content.parts([
            .text("First"),
            .image(Message.ImageContent(base64Data: "abc123")),
            .text("Second")
        ])

        #expect(content.textValue == "First\nSecond")
        #expect(!content.isEmpty)
    }

    @Test("Content isEmpty property")
    func contentIsEmpty() {
        let emptyContent = Message.Content.text("")
        let nonEmptyContent = Message.Content.text("Hello")

        #expect(emptyContent.isEmpty)
        #expect(!nonEmptyContent.isEmpty)
    }

    @Test("Empty parts content is empty")
    func emptyPartsContentIsEmpty() {
        let content = Message.Content.parts([])

        #expect(content.isEmpty)
        #expect(content.textValue.isEmpty)
    }

    @Test("Image-only parts has empty text")
    func imageOnlyPartsIsEmpty() {
        let content = Message.Content.parts([
            .image(Message.ImageContent(base64Data: "abc123"))
        ])

        #expect(content.isEmpty)
        #expect(content.textValue.isEmpty)
    }

    // MARK: - ImageContent Tests

    @Test("ImageContent default MIME type")
    func imageContentInit() {
        let image = Message.ImageContent(base64Data: "abc123")

        #expect(image.base64Data == "abc123")
        #expect(image.mimeType == "image/jpeg") // default
    }

    @Test("ImageContent custom MIME type")
    func imageContentWithCustomMimeType() {
        let pngImage = Message.ImageContent(base64Data: "xyz789", mimeType: "image/png")

        #expect(pngImage.base64Data == "xyz789")
        #expect(pngImage.mimeType == "image/png")
    }

    // MARK: - MessageMetadata Tests

    @Test("MessageMetadata initialization")
    func messageMetadataInitialization() {
        let metadata = MessageMetadata(
            tokenCount: 100,
            generationTime: 1.5,
            model: "llama-3.2-1b",
            tokensPerSecond: 66.7
        )

        #expect(metadata.tokenCount == 100)
        #expect(metadata.generationTime == 1.5)
        #expect(metadata.model == "llama-3.2-1b")
        #expect(metadata.tokensPerSecond == 66.7)
        #expect(metadata.custom == nil)
    }

    @Test("MessageMetadata with custom fields")
    func messageMetadataWithCustom() {
        let metadata = MessageMetadata(
            custom: ["key": "value", "foo": "bar"]
        )

        #expect(metadata.custom?["key"] == "value")
        #expect(metadata.custom?["foo"] == "bar")
    }

    @Test("MessageMetadata Codable round-trip")
    func messageMetadataCodable() throws {
        let original = MessageMetadata(tokenCount: 50, model: "test-model")
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MessageMetadata.self, from: encoded)

        #expect(original == decoded)
    }

    // MARK: - Codable Round-Trip Tests

    @Test("Message Codable round-trip")
    func messageCodableRoundTrip() throws {
        let original = Message.user("Test message")
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Message.self, from: encoded)

        #expect(original.id == decoded.id)
        #expect(original.role == decoded.role)
        #expect(original.content.textValue == decoded.content.textValue)
    }

    @Test("Content.text Codable round-trip")
    func contentTextCodableRoundTrip() throws {
        let content = Message.Content.text("Hello")
        let encoded = try JSONEncoder().encode(content)
        let decoded = try JSONDecoder().decode(Message.Content.self, from: encoded)

        #expect(content.textValue == decoded.textValue)
    }

    @Test("Content.parts Codable round-trip")
    func contentPartsCodableRoundTrip() throws {
        let content = Message.Content.parts([
            .text("Hello"),
            .text("World")
        ])
        let encoded = try JSONEncoder().encode(content)
        let decoded = try JSONDecoder().decode(Message.Content.self, from: encoded)

        #expect(content.textValue == decoded.textValue)
    }

    @Test("Content.parts with image Codable round-trip")
    func contentPartImageCodableRoundTrip() throws {
        let imageContent = Message.ImageContent(base64Data: "abc123", mimeType: "image/png")
        let content = Message.Content.parts([
            .text("What's this?"),
            .image(imageContent)
        ])
        let encoded = try JSONEncoder().encode(content)
        let decoded = try JSONDecoder().decode(Message.Content.self, from: encoded)

        // Extract the image from decoded
        if case .parts(let parts) = decoded {
            #expect(parts.count == 2)
            if case .image(let decodedImage) = parts[1] {
                #expect(decodedImage.base64Data == "abc123")
                #expect(decodedImage.mimeType == "image/png")
            } else {
                Issue.record("Expected image part")
            }
        } else {
            Issue.record("Expected parts content")
        }
    }

    @Test("Role Codable round-trip for all cases", arguments: Message.Role.allCases)
    func roleCodableRoundTrip(role: Message.Role) throws {
        let encoded = try JSONEncoder().encode(role)
        let decoded = try JSONDecoder().decode(Message.Role.self, from: encoded)
        #expect(role == decoded)
    }

    // MARK: - Equality Tests

    @Test("Message equality")
    func messageEquality() {
        let id = UUID()
        let timestamp = Date()

        let message1 = Message(id: id, role: .user, content: .text("Hello"), timestamp: timestamp)
        let message2 = Message(id: id, role: .user, content: .text("Hello"), timestamp: timestamp)

        #expect(message1 == message2)
    }

    @Test("Message inequality")
    func messageInequality() {
        let message1 = Message.user("Hello")
        let message2 = Message.user("World")

        #expect(message1 != message2)
    }

    @Test("Content equality")
    func contentEquality() {
        let content1 = Message.Content.text("Hello")
        let content2 = Message.Content.text("Hello")

        #expect(content1 == content2)
    }

    @Test("ContentPart equality")
    func contentPartEquality() {
        let part1 = Message.ContentPart.text("Hello")
        let part2 = Message.ContentPart.text("Hello")

        #expect(part1 == part2)
    }

    @Test("ImageContent equality")
    func imageContentEquality() {
        let image1 = Message.ImageContent(base64Data: "abc", mimeType: "image/png")
        let image2 = Message.ImageContent(base64Data: "abc", mimeType: "image/png")

        #expect(image1 == image2)
    }

    // MARK: - Hashable Tests

    @Test("Message is Hashable")
    func messageHashable() {
        let message1 = Message.user("Test")
        let message2 = Message.user("Test2")

        var messageSet: Set<Message> = []
        messageSet.insert(message1)
        messageSet.insert(message2)

        #expect(messageSet.count == 2)
    }

    @Test("Content is Hashable")
    func contentHashable() {
        let content1 = Message.Content.text("Hello")
        let content2 = Message.Content.text("World")

        var contentSet: Set<Message.Content> = []
        contentSet.insert(content1)
        contentSet.insert(content2)

        #expect(contentSet.count == 2)
    }

    // MARK: - JSON Format Tests

    @Test("Content.text JSON format")
    func contentTextJSONFormat() throws {
        let content = Message.Content.text("Hello")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let json = try encoder.encode(content)
        let jsonString = String(data: json, encoding: .utf8)!

        #expect(jsonString.contains("\"type\":\"text\""))
        #expect(jsonString.contains("\"text\":\"Hello\""))
    }

    @Test("Content.parts JSON format")
    func contentPartsJSONFormat() throws {
        let content = Message.Content.parts([.text("Test")])
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let json = try encoder.encode(content)
        let jsonString = String(data: json, encoding: .utf8)!

        #expect(jsonString.contains("\"type\":\"parts\""))
        #expect(jsonString.contains("\"parts\""))
    }

    @Test("ContentPart.text JSON format")
    func contentPartTextJSONFormat() throws {
        let part = Message.ContentPart.text("Hello")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let json = try encoder.encode(part)
        let jsonString = String(data: json, encoding: .utf8)!

        #expect(jsonString.contains("\"type\":\"text\""))
        #expect(jsonString.contains("\"text\":\"Hello\""))
    }

    @Test("ContentPart.image JSON format")
    func contentPartImageJSONFormat() throws {
        let part = Message.ContentPart.image(Message.ImageContent(base64Data: "abc", mimeType: "image/png"))
        let encoder = JSONEncoder()
        let json = try encoder.encode(part)

        // Decode as dictionary to verify structure
        let dict = try JSONDecoder().decode([String: String].self, from: json)
        #expect(dict["type"] == "image")
        #expect(dict["base64Data"] == "abc")
        #expect(dict["mimeType"] == "image/png")
    }
}
