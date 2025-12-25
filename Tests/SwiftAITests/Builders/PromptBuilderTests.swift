// PromptBuilderTests.swift
// SwiftAITests

import Testing
@testable import SwiftAI

@Suite("PromptBuilder Tests")
struct PromptBuilderTests {

    // MARK: - SystemInstruction Tests

    @Test("SystemInstruction renders its content")
    func systemInstructionRendering() {
        let instruction = SystemInstruction("You are helpful.")

        #expect(instruction.render() == "You are helpful.")
    }

    // MARK: - UserQuery Tests

    @Test("UserQuery renders its content")
    func userQueryRendering() {
        let query = UserQuery("What is Swift?")

        #expect(query.render() == "What is Swift?")
    }

    // MARK: - Context Tests

    @Test("Context without label renders content only")
    func contextWithoutLabel() {
        let context = Context("Some background info")

        #expect(context.render() == "Some background info")
    }

    @Test("Context with label renders formatted output")
    func contextWithLabel() {
        let context = Context("Code snippet here", label: "Code")

        #expect(context.render() == "[Code]\nCode snippet here")
    }

    // MARK: - Examples Tests

    @Test("Examples renders input-output pairs")
    func examplesRendering() {
        let examples = Examples([
            (input: "What is 2+2?", output: "4"),
            (input: "What is 3+3?", output: "6")
        ])

        let rendered = examples.render()

        #expect(rendered.contains("Input: What is 2+2?"))
        #expect(rendered.contains("Output: 4"))
        #expect(rendered.contains("Input: What is 3+3?"))
        #expect(rendered.contains("Output: 6"))
    }

    @Test("Empty examples renders empty string")
    func emptyExamples() {
        let examples = Examples([])

        #expect(examples.render().isEmpty)
    }

    // MARK: - PromptContent Tests

    @Test("PromptContent combines multiple components")
    func promptContentCombinesComponents() {
        let prompt = Prompt {
            SystemInstruction("You are helpful.")
            UserQuery("Hello!")
        }

        #expect(prompt.components.count == 2)

        let rendered = prompt.render()
        #expect(rendered.contains("You are helpful."))
        #expect(rendered.contains("Hello!"))
    }

    @Test("PromptContent.toMessages converts SystemInstruction to system message")
    func toMessagesSystemInstruction() {
        let prompt = Prompt {
            SystemInstruction("Be helpful.")
        }

        let messages = prompt.toMessages()

        #expect(messages.count == 1)
        #expect(messages[0].role == .system)
        #expect(messages[0].content.textValue == "Be helpful.")
    }

    @Test("PromptContent.toMessages converts UserQuery to user message")
    func toMessagesUserQuery() {
        let prompt = Prompt {
            UserQuery("Hello!")
        }

        let messages = prompt.toMessages()

        #expect(messages.count == 1)
        #expect(messages[0].role == .user)
        #expect(messages[0].content.textValue == "Hello!")
    }

    @Test("PromptContent.toMessages converts Examples to alternating messages")
    func toMessagesExamples() {
        let prompt = Prompt {
            Examples([
                (input: "Q1", output: "A1"),
                (input: "Q2", output: "A2")
            ])
        }

        let messages = prompt.toMessages()

        #expect(messages.count == 4)
        #expect(messages[0].role == .user)
        #expect(messages[0].content.textValue == "Q1")
        #expect(messages[1].role == .assistant)
        #expect(messages[1].content.textValue == "A1")
        #expect(messages[2].role == .user)
        #expect(messages[2].content.textValue == "Q2")
        #expect(messages[3].role == .assistant)
        #expect(messages[3].content.textValue == "A2")
    }

    @Test("PromptContent.toMessages converts Context to user message")
    func toMessagesContext() {
        let prompt = Prompt {
            Context("Background info", label: "Background")
        }

        let messages = prompt.toMessages()

        #expect(messages.count == 1)
        #expect(messages[0].role == .user)
        #expect(messages[0].content.textValue == "[Background]\nBackground info")
    }

    @Test("Complex prompt converts to correct message sequence")
    func complexPromptToMessages() {
        let prompt = Prompt {
            SystemInstruction("You are a math tutor.")
            Context("Student is learning basics", label: "Background")
            Examples([
                (input: "2+2", output: "4")
            ])
            UserQuery("What is 5+5?")
        }

        let messages = prompt.toMessages()

        #expect(messages.count == 5)
        #expect(messages[0].role == .system)
        #expect(messages[1].role == .user)  // Context
        #expect(messages[2].role == .user)  // Example input
        #expect(messages[3].role == .assistant)  // Example output
        #expect(messages[4].role == .user)  // UserQuery
    }

    // MARK: - Conditional Support

    @Test("Conditional components included when true")
    func conditionalTrue() {
        let includeContext = true

        let prompt = Prompt {
            SystemInstruction("System")
            if includeContext {
                Context("Included context")
            }
            UserQuery("Query")
        }

        #expect(prompt.components.count == 3)
    }

    @Test("Conditional components excluded when false")
    func conditionalFalse() {
        let includeContext = false

        let prompt = Prompt {
            SystemInstruction("System")
            if includeContext {
                Context("Excluded context")
            }
            UserQuery("Query")
        }

        // Should have system + empty component + query = 3 components
        // but empty component renders to empty string
        let rendered = prompt.render()
        #expect(!rendered.contains("Excluded context"))
        #expect(rendered.contains("System"))
        #expect(rendered.contains("Query"))
    }

    @Test("If-else selects correct branch")
    func ifElseBranching() {
        let isExpert = false

        let prompt = Prompt {
            if isExpert {
                SystemInstruction("Technical mode")
            } else {
                SystemInstruction("Simple mode")
            }
        }

        let messages = prompt.toMessages()

        #expect(messages.count == 1)
        #expect(messages[0].content.textValue == "Simple mode")
    }

    // MARK: - Loop Support

    @Test("For-in loop creates multiple components")
    func forInLoop() {
        let topics = ["Swift", "Concurrency", "Actors"]

        let prompt = Prompt {
            SystemInstruction("You are a teacher.")
            for topic in topics {
                Context("Topic: \(topic)")
            }
        }

        let messages = prompt.toMessages()

        // 1 system + 3 contexts
        #expect(messages.count == 4)
    }

    // MARK: - String Literal Support

    @Test("PromptContent can be created from string literal")
    func stringLiteralSupport() {
        let prompt: PromptContent = "Simple prompt"

        #expect(prompt.render() == "Simple prompt")

        let messages = prompt.toMessages()
        #expect(messages.count == 1)
        #expect(messages[0].role == .user)
    }

    // MARK: - Custom Description

    @Test("PromptContent description returns rendered content")
    func descriptionReturnsRender() {
        let prompt = Prompt {
            UserQuery("Test")
        }

        #expect(prompt.description == "Test")
    }
}
