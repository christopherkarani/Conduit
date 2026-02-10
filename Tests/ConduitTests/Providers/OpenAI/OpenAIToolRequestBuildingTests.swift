// OpenAIToolRequestBuildingTests.swift
// Conduit Tests
//
// Tests for OpenRouter/OpenAI tool calling configuration support.

#if CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
import Foundation
import Testing
@testable import Conduit

@Generable
private struct WeatherArgs {
    let city: String
}

@Generable
private struct SearchArgs {
    let query: String
}

@Generable
private struct EmptyArgs {}

@Generable
private struct QueryArgs {
    let query: String
}

@Generable
private struct CreateUserArgs {
    let name: String
    let age: Int
    let active: Bool
}

@Generable
private struct Address {
    let street: String
    let city: String
}

@Generable
private struct UserArgs {
    let name: String
    let address: Address
}

@Generable
private struct TagArgs {
    let tags: [String]
}

// MARK: - Test Suite

@Suite("OpenAI Tool Request Building Tests")
struct OpenAIToolRequestBuildingTests {

    // MARK: - Transcript.ToolDefinition Type Tests

    @Suite("Transcript.ToolDefinition Type")
    struct ToolDefinitionTypeTests {

        @Test("Transcript.ToolDefinition creation with name, description, parameters")
        func toolDefinitionInit() {
            let schema = WeatherArgs.generationSchema

            let tool = Transcript.ToolDefinition(
                name: "get_weather",
                description: "Get weather for a city",
                parameters: schema
            )

            #expect(tool.name == "get_weather")
            #expect(tool.description == "Get weather for a city")
        }

        @Test("Transcript.ToolDefinition conforms to Sendable")
        func sendableConformance() {
            let schema = EmptyArgs.generationSchema
            let tool: any Sendable = Transcript.ToolDefinition(
                name: "test",
                description: "Test tool",
                parameters: schema
            )
            #expect(tool is Transcript.ToolDefinition)
        }

        @Test("Transcript.ToolDefinition Codable round-trip")
        func codableRoundTrip() throws {
            let schema = SearchArgs.generationSchema

            let original = Transcript.ToolDefinition(
                name: "search",
                description: "Search the web",
                parameters: schema
            )

            let encoded = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(Transcript.ToolDefinition.self, from: encoded)

            #expect(decoded.name == original.name)
            #expect(decoded.description == original.description)
        }
    }

    // MARK: - ToolChoice Type Tests

    @Suite("ToolChoice Type")
    struct ToolChoiceTypeTests {

        @Test("ToolChoice has all cases")
        func allCases() {
            let auto = ToolChoice.auto
            let none = ToolChoice.none
            let required = ToolChoice.required
            let specific = ToolChoice.tool(name: "test_tool")

            // Verify each case exists
            if case .auto = auto { } else { Issue.record("Expected .auto") }
            if case .none = none { } else { Issue.record("Expected .none") }
            if case .required = required { } else { Issue.record("Expected .required") }
            if case .tool(let name) = specific {
                #expect(name == "test_tool")
            } else {
                Issue.record("Expected .tool")
            }
        }

        @Test("ToolChoice conforms to Sendable")
        func sendableConformance() {
            let choice: any Sendable = ToolChoice.auto
            #expect(choice is ToolChoice)
        }

        @Test("ToolChoice Codable round-trip")
        func codableRoundTrip() throws {
            let choices: [ToolChoice] = [.auto, .none, .required, .tool(name: "weather")]

            for original in choices {
                let encoded = try JSONEncoder().encode(original)
                let decoded = try JSONDecoder().decode(ToolChoice.self, from: encoded)
                #expect(original == decoded)
            }
        }
    }

    // MARK: - GenerateConfig Tools Integration Tests

    @Suite("GenerateConfig Tools Integration")
    struct GenerateConfigToolsIntegrationTests {

        @Test("GenerateConfig has tools property")
        func toolsProperty() {
            let config = GenerateConfig.default
            #expect(config.tools.isEmpty)
        }

        @Test("GenerateConfig fluent API for tools")
        func fluentAPITools() {
            let schema = EmptyArgs.generationSchema
            let tool = Transcript.ToolDefinition(name: "test", description: "Test", parameters: schema)

            let config = GenerateConfig.default.tools([tool])

            #expect(config.tools.count == 1)
            #expect(config.tools.first?.name == "test")
        }

        @Test("GenerateConfig fluent API for multiple tools")
        func fluentAPIMultipleTools() {
            let schema = EmptyArgs.generationSchema

            let tool1 = Transcript.ToolDefinition(name: "tool1", description: "Tool 1", parameters: schema)
            let tool2 = Transcript.ToolDefinition(name: "tool2", description: "Tool 2", parameters: schema)

            let config = GenerateConfig.default.tools([tool1, tool2])

            #expect(config.tools.count == 2)
        }

        @Test("GenerateConfig has toolChoice property")
        func toolChoiceProperty() {
            let config = GenerateConfig.default
            #expect(config.toolChoice == .auto)
        }

        @Test("GenerateConfig fluent API for toolChoice")
        func fluentAPIToolChoice() {
            let schema = EmptyArgs.generationSchema
            let tool = Transcript.ToolDefinition(name: "test", description: "Test", parameters: schema)

            let config = GenerateConfig.default
                .tools([tool])
                .toolChoice(.required)

            #expect(config.toolChoice == .required)
        }

        @Test("GenerateConfig has parallelToolCalls property")
        func parallelToolCallsProperty() {
            let config = GenerateConfig.default
            #expect(config.parallelToolCalls == nil)
        }

        @Test("GenerateConfig fluent API for parallelToolCalls")
        func fluentAPIParallelToolCalls() {
            let schema = EmptyArgs.generationSchema
            let tool = Transcript.ToolDefinition(name: "test", description: "Test", parameters: schema)

            let config = GenerateConfig.default
                .tools([tool])
                .parallelToolCalls(false)

            #expect(config.parallelToolCalls == false)
        }

        @Test("GenerateConfig tools preserved in config copy")
        func toolsPreservedInCopy() {
            let schema = EmptyArgs.generationSchema
            let tool = Transcript.ToolDefinition(name: "test", description: "Test", parameters: schema)

            let config = GenerateConfig.default
                .tools([tool])
                .toolChoice(.auto)
                .parallelToolCalls(true)
                .temperature(0.5)

            let modified = config.maxTokens(1000)

            #expect(modified.tools.count == 1)
            #expect(modified.toolChoice == .auto)
            #expect(modified.parallelToolCalls == true)
            #expect(modified.temperature == 0.5)
            #expect(modified.maxTokens == 1000)
        }

        @Test("GenerateConfig tools included in Codable")
        func toolsCodable() throws {
            let schema = WeatherArgs.generationSchema
            let tool = Transcript.ToolDefinition(name: "weather", description: "Get weather", parameters: schema)

            let config = GenerateConfig.default
                .tools([tool])
                .toolChoice(.required)
                .parallelToolCalls(false)

            let encoded = try JSONEncoder().encode(config)
            let decoded = try JSONDecoder().decode(GenerateConfig.self, from: encoded)

            #expect(decoded.tools.count == 1)
            #expect(decoded.tools.first?.name == "weather")
            #expect(decoded.toolChoice == .required)
            #expect(decoded.parallelToolCalls == false)
        }
    }

    // MARK: - Tool schema tests

    @Suite("Tool schema")
    struct ToolSchemaTests {

        @Test("Tool with simple string property")
        func simpleStringProperty() {
            let schema = QueryArgs.generationSchema

            let tool = Transcript.ToolDefinition(name: "search", description: "Search", parameters: schema)
            #expect(tool.name == "search")
        }

        @Test("Tool with multiple property types")
        func multiplePropertyTypes() {
            let schema = CreateUserArgs.generationSchema

            let tool = Transcript.ToolDefinition(
                name: "create_user",
                description: "Create a new user",
                parameters: schema
            )

            #expect(tool.name == "create_user")
        }

        @Test("Tool with nested object property")
        func nestedObjectProperty() {
            let schema = UserArgs.generationSchema

            let tool = Transcript.ToolDefinition(
                name: "create_user",
                description: "Create user with address",
                parameters: schema
            )

            #expect(tool.name == "create_user")
        }

        @Test("Tool with array property")
        func arrayProperty() {
            let schema = TagArgs.generationSchema

            let tool = Transcript.ToolDefinition(
                name: "add_tags",
                description: "Add tags",
                parameters: schema
            )

            #expect(tool.name == "add_tags")
        }
    }
}

#endif // CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
