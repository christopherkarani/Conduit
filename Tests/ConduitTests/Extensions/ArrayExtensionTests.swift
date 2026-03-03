// ArrayExtensionTests.swift
// ConduitTests

import Foundation
import Testing
@testable import Conduit

@Suite("Array<Message> Extension Tests")
struct ArrayMessageExtensionTests {

    // MARK: - Test Data

    static let sampleMessages: [Message] = [
        .system("You are helpful."),
        .user("Hello!"),
        .assistant("Hi there!"),
        .user("How are you?"),
        .assistant("I'm doing well!")
    ]

    // MARK: - userMessages

    @Test("userMessages filters only user role messages")
    func userMessages() {
        let users = Self.sampleMessages.userMessages
        #expect(users.count == 2)
        #expect(users.allSatisfy { $0.role == .user })
    }

    @Test("userMessages returns empty for no user messages")
    func userMessagesEmpty() {
        let messages: [Message] = [.system("System"), .assistant("Hi")]
        #expect(messages.userMessages.isEmpty)
    }

    // MARK: - assistantMessages

    @Test("assistantMessages filters only assistant role messages")
    func assistantMessages() {
        let assistants = Self.sampleMessages.assistantMessages
        #expect(assistants.count == 2)
        #expect(assistants.allSatisfy { $0.role == .assistant })
    }

    @Test("assistantMessages returns empty for no assistant messages")
    func assistantMessagesEmpty() {
        let messages: [Message] = [.system("System"), .user("Hi")]
        #expect(messages.assistantMessages.isEmpty)
    }

    // MARK: - systemMessage

    @Test("systemMessage returns first system message")
    func systemMessage() {
        let system = Self.sampleMessages.systemMessage
        #expect(system != nil)
        #expect(system?.role == .system)
        #expect(system?.content.textValue == "You are helpful.")
    }

    @Test("systemMessage returns nil when no system message exists")
    func systemMessageNil() {
        let messages: [Message] = [.user("Hello"), .assistant("Hi")]
        #expect(messages.systemMessage == nil)
    }

    // MARK: - withoutSystem

    @Test("withoutSystem removes system messages")
    func withoutSystem() {
        let filtered = Self.sampleMessages.withoutSystem
        #expect(filtered.count == 4)
        #expect(filtered.allSatisfy { $0.role != .system })
    }

    @Test("withoutSystem on messages without system returns all")
    func withoutSystemNoChange() {
        let messages: [Message] = [.user("Hello"), .assistant("Hi")]
        let filtered = messages.withoutSystem
        #expect(filtered.count == 2)
    }

    // MARK: - totalTextLength

    @Test("totalTextLength sums character counts")
    func totalTextLength() {
        let messages: [Message] = [
            .user("Hello"),      // 5 chars
            .assistant("World")  // 5 chars
        ]
        #expect(messages.totalTextLength == 10)
    }

    @Test("totalTextLength is zero for empty array")
    func totalTextLengthEmpty() {
        let messages: [Message] = []
        #expect(messages.totalTextLength == 0)
    }

    @Test("totalTextLength includes system message")
    func totalTextLengthWithSystem() {
        let messages: [Message] = [
            .system("Be brief."),  // 9 chars
            .user("Hi")           // 2 chars
        ]
        #expect(messages.totalTextLength == 11)
    }
}
