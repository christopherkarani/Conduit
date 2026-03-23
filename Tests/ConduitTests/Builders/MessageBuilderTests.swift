// MessageBuilderTests.swift
// ConduitTests

import Testing
@testable import ConduitAdvanced

@Suite("MessageBuilder Tests")
struct MessageBuilderTests {

    // MARK: - Basic Building

    @Test("Single message creates array with one element")
    func singleMessage() {
        let messages = Messages {
            Message.user("Hello")
        }

        #expect(messages.count == 1)
        #expect(messages[0].role == .user)
        #expect(messages[0].content.textValue == "Hello")
    }

    @Test("Multiple messages creates array in order")
    func multipleMessages() {
        let messages = Messages {
            Message.system("You are helpful.")
            Message.user("Hello!")
            Message.assistant("Hi there!")
        }

        #expect(messages.count == 3)
        #expect(messages[0].role == .system)
        #expect(messages[1].role == .user)
        #expect(messages[2].role == .assistant)
    }

    @Test("Empty builder produces empty array")
    func emptyBuilder() {
        let messages = Messages { }

        #expect(messages.isEmpty)
    }

    // MARK: - Conditional Support

    @Test("If without else - condition true includes message")
    func ifWithoutElseTrue() {
        let includeContext = true

        let messages = Messages {
            Message.system("System")
            if includeContext {
                Message.user("Context included")
            }
        }

        #expect(messages.count == 2)
        #expect(messages[1].content.textValue == "Context included")
    }

    @Test("If without else - condition false excludes message")
    func ifWithoutElseFalse() {
        let includeContext = false

        let messages = Messages {
            Message.system("System")
            if includeContext {
                Message.user("Context included")
            }
        }

        #expect(messages.count == 1)
        #expect(messages[0].role == .system)
    }

    @Test("If-else uses first branch when true")
    func ifElseTrue() {
        let isExpert = true

        let messages = Messages {
            if isExpert {
                Message.system("Technical mode")
            } else {
                Message.system("Simple mode")
            }
        }

        #expect(messages.count == 1)
        #expect(messages[0].content.textValue == "Technical mode")
    }

    @Test("If-else uses second branch when false")
    func ifElseFalse() {
        let isExpert = false

        let messages = Messages {
            if isExpert {
                Message.system("Technical mode")
            } else {
                Message.system("Simple mode")
            }
        }

        #expect(messages.count == 1)
        #expect(messages[0].content.textValue == "Simple mode")
    }

    // MARK: - Loop Support

    @Test("For-in loop creates messages for each iteration")
    func forInLoop() {
        let examples = [
            (question: "Q1", answer: "A1"),
            (question: "Q2", answer: "A2")
        ]

        let messages = Messages {
            for example in examples {
                Message.user(example.question)
                Message.assistant(example.answer)
            }
        }

        #expect(messages.count == 4)
        #expect(messages[0].content.textValue == "Q1")
        #expect(messages[1].content.textValue == "A1")
        #expect(messages[2].content.textValue == "Q2")
        #expect(messages[3].content.textValue == "A2")
    }

    @Test("For-in with empty array produces empty result")
    func forInEmptyArray() {
        let items: [String] = []

        let messages = Messages {
            for item in items {
                Message.user(item)
            }
        }

        #expect(messages.isEmpty)
    }

    // MARK: - Array Inclusion

    @Test("Existing array can be included directly")
    func includeExistingArray() {
        let history: [Message] = [
            .user("Previous question"),
            .assistant("Previous answer")
        ]

        let messages = Messages {
            Message.system("System")
            history
            Message.user("New question")
        }

        #expect(messages.count == 4)
        #expect(messages[0].role == .system)
        #expect(messages[1].content.textValue == "Previous question")
        #expect(messages[2].content.textValue == "Previous answer")
        #expect(messages[3].content.textValue == "New question")
    }

    // MARK: - Combined Features

    @Test("Conditionals and loops can be mixed")
    func mixedConditionalsAndLoops() {
        let includeExamples = true
        let examples = ["Ex1", "Ex2"]

        let messages = Messages {
            Message.system("System")

            if includeExamples {
                for example in examples {
                    Message.user(example)
                }
            }

            Message.user("Query")
        }

        #expect(messages.count == 4)
        #expect(messages[0].role == .system)
        #expect(messages[1].content.textValue == "Ex1")
        #expect(messages[2].content.textValue == "Ex2")
        #expect(messages[3].content.textValue == "Query")
    }

    @Test("Nested conditionals work correctly")
    func nestedConditionals() {
        let outer = true
        let inner = true

        let messages = Messages {
            if outer {
                Message.user("Outer")
                if inner {
                    Message.user("Inner")
                }
            }
        }

        #expect(messages.count == 2)
        #expect(messages[0].content.textValue == "Outer")
        #expect(messages[1].content.textValue == "Inner")
    }

    // MARK: - Array Extension

    @Test("Array.build creates messages using builder syntax")
    func arrayBuildExtension() {
        let messages: [Message] = .build {
            Message.system("System")
            Message.user("User")
        }

        #expect(messages.count == 2)
        #expect(messages[0].role == .system)
        #expect(messages[1].role == .user)
    }
}
