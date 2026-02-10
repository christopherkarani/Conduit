// OpenAIProviderStructuredOutputTests.swift
// Conduit Tests
//
// Tests for OpenRouter/OpenAI structured output support.

#if CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
import Foundation
import Testing
@testable import Conduit

@Generable
private struct TestSchema {
    let name: String
}

@Generable
private struct UserSchema {
    let userID: Int
    let name: String
}

@Generable
private struct MovieReviewSchema {
    let rating: Int
    let summary: String
}

// MARK: - Test Suite

@Suite("OpenAI Provider Structured Output Tests")
struct OpenAIProviderStructuredOutputTests {

    // MARK: - ResponseFormat Type Tests

    @Suite("ResponseFormat Type")
    struct ResponseFormatTypeTests {

        @Test("ResponseFormat has text case")
        func textCase() {
            let format = ResponseFormat.text
            if case .text = format {
                // Expected
            } else {
                Issue.record("Expected text response format")
            }
        }

        @Test("ResponseFormat has jsonObject case")
        func jsonObjectCase() {
            let format = ResponseFormat.jsonObject
            if case .jsonObject = format {
                // Expected
            } else {
                Issue.record("Expected jsonObject response format")
            }
        }

        @Test("ResponseFormat has jsonSchema case with schema and name")
        func jsonSchemaCase() {
            let schema = TestSchema.generationSchema

            let format = ResponseFormat.jsonSchema(name: "TestSchema", schema: schema)

            if case .jsonSchema(let name, let extractedSchema) = format {
                #expect(name == "TestSchema")
                #expect(extractedSchema.debugDescription.contains("object(1 properties)"))
            } else {
                Issue.record("Expected jsonSchema case")
            }
        }

        @Test("ResponseFormat conforms to Sendable")
        func sendableConformance() {
            let format: ResponseFormat = .jsonObject
            let _: any Sendable = format
        }

        @Test("ResponseFormat conforms to Codable")
        func codableConformance() throws {
            let original = ResponseFormat.jsonObject
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()

            let data = try encoder.encode(original)
            let decoded = try decoder.decode(ResponseFormat.self, from: data)

            if case .jsonObject = decoded {
                // Expected
            } else {
                Issue.record("Expected jsonObject response format")
            }
        }

        @Test("jsonSchema ResponseFormat round-trips through Codable")
        func jsonSchemaRoundTrip() throws {
            let schema = UserSchema.generationSchema

            let original = ResponseFormat.jsonSchema(name: "User", schema: schema)
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()

            let data = try encoder.encode(original)
            let decoded = try decoder.decode(ResponseFormat.self, from: data)

            if case .jsonSchema(let name, let decodedSchema) = decoded {
                #expect(name == "User")
                #expect(decodedSchema.debugDescription.contains("object(2 properties)"))
            } else {
                Issue.record("Expected jsonSchema response format")
            }
        }
    }

    // MARK: - GenerateConfig Integration Tests

    @Suite("GenerateConfig Integration")
    struct GenerateConfigIntegrationTests {

        @Test("GenerateConfig has responseFormat property")
        func responseFormatProperty() {
            let config = GenerateConfig.default
            if case .none = config.responseFormat {
                // Expected
            } else {
                Issue.record("Expected responseFormat to be nil")
            }
        }

        @Test("GenerateConfig fluent API for setting responseFormat")
        func fluentAPIResponseFormat() {
            let config = GenerateConfig.default
                .responseFormat(.jsonObject)

            if case .jsonObject? = config.responseFormat {
                // Expected
            } else {
                Issue.record("Expected jsonObject response format")
            }
        }

        @Test("GenerateConfig fluent API preserves other settings")
        func fluentAPIPreservesSettings() {
            let config = GenerateConfig.default
                .temperature(0.5)
                .maxTokens(500)
                .responseFormat(.jsonObject)

            #expect(config.temperature == 0.5)
            #expect(config.maxTokens == 500)
            if case .jsonObject? = config.responseFormat {
                // Expected
            } else {
                Issue.record("Expected jsonObject response format")
            }
        }

        @Test("GenerateConfig with jsonSchema responseFormat")
        func jsonSchemaResponseFormat() {
            let schema = MovieReviewSchema.generationSchema

            let config = GenerateConfig.default
                .responseFormat(.jsonSchema(name: "MovieReview", schema: schema))

            if case .jsonSchema(let name, _) = config.responseFormat {
                #expect(name == "MovieReview")
            } else {
                Issue.record("Expected jsonSchema response format")
            }
        }

        @Test("GenerateConfig responseFormat is included in Codable")
        func responseFormatCodable() throws {
            let config = GenerateConfig.default
                .responseFormat(.jsonObject)

            let encoder = JSONEncoder()
            let decoder = JSONDecoder()

            let data = try encoder.encode(config)
            let decoded = try decoder.decode(GenerateConfig.self, from: data)

            if case .jsonObject? = decoded.responseFormat {
                // Expected
            } else {
                Issue.record("Expected jsonObject response format")
            }
        }

        @Test("GenerateConfig responseFormat nil is preserved in Codable")
        func responseFormatNilCodable() throws {
            let config = GenerateConfig.default

            let encoder = JSONEncoder()
            let decoder = JSONDecoder()

            let data = try encoder.encode(config)
            let decoded = try decoder.decode(GenerateConfig.self, from: data)

            if case .none = decoded.responseFormat {
                // Expected
            } else {
                Issue.record("Expected responseFormat to be nil")
            }
        }
    }

    // MARK: - Compatibility Tests

    @Suite("Compatibility")
    struct CompatibilityTests {

        @Test("responseFormat preserved in config copy")
        func responseFormatPreservedInCopy() {
            let config = GenerateConfig.default
                .responseFormat(.jsonObject)
                .temperature(0.5)

            if case .jsonObject? = config.responseFormat {
                // Expected
            } else {
                Issue.record("Expected jsonObject response format")
            }
            #expect(config.temperature == 0.5)

            let modified = config.maxTokens(500)

            if case .jsonObject? = modified.responseFormat {
                // Expected
            } else {
                Issue.record("Expected jsonObject response format")
            }
            #expect(modified.temperature == 0.5)
            #expect(modified.maxTokens == 500)
        }
    }
}

#endif // CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
