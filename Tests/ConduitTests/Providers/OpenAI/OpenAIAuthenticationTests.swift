// OpenAIAuthenticationTests.swift
// Conduit Tests
//
// Tests for OpenAIAuthentication enum cases, resolution, headers, and security.

#if CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
import Foundation
import Testing
@testable import Conduit

@Suite("OpenAIAuthentication Tests")
struct OpenAIAuthenticationTests {

    // MARK: - Enum Cases

    @Test("none case exists and resolves to nil")
    func noneResolves() {
        let auth = OpenAIAuthentication.none
        #expect(auth.resolve() == nil)
    }

    @Test("bearer case stores and resolves the token")
    func bearerResolves() {
        let auth = OpenAIAuthentication.bearer("sk-test123")
        #expect(auth.resolve() == "sk-test123")
    }

    @Test("apiKey case stores key and resolves it")
    func apiKeyResolves() {
        let auth = OpenAIAuthentication.apiKey("azure-key", headerName: "api-key")
        #expect(auth.resolve() == "azure-key")
    }

    @Test("apiKey case uses default headerName of api-key")
    func apiKeyDefaultHeader() {
        let auth = OpenAIAuthentication.apiKey("key123")
        #expect(auth.headerName == "api-key")
    }

    @Test("environment case resolves from environment variable")
    func environmentResolves() {
        // This test checks the mechanism; actual env value depends on environment
        let auth = OpenAIAuthentication.environment("LIKELY_UNSET_VAR_FOR_TESTING_12345")
        #expect(auth.resolve() == nil)
    }

    @Test("auto case checks known env variables")
    func autoChecksEnvVars() {
        let auth = OpenAIAuthentication.auto
        // Cannot guarantee env vars are set, but the mechanism should not crash
        _ = auth.resolve()
    }

    // MARK: - isConfigured

    @Test("none is considered configured")
    func noneIsConfigured() {
        #expect(OpenAIAuthentication.none.isConfigured)
    }

    @Test("bearer with non-empty token is configured")
    func bearerNonEmptyIsConfigured() {
        #expect(OpenAIAuthentication.bearer("sk-test").isConfigured)
    }

    @Test("bearer with empty token is not configured")
    func bearerEmptyNotConfigured() {
        #expect(!OpenAIAuthentication.bearer("").isConfigured)
    }

    @Test("apiKey with non-empty key is configured")
    func apiKeyNonEmptyIsConfigured() {
        #expect(OpenAIAuthentication.apiKey("key123", headerName: "api-key").isConfigured)
    }

    @Test("apiKey with empty key is not configured")
    func apiKeyEmptyNotConfigured() {
        #expect(!OpenAIAuthentication.apiKey("", headerName: "api-key").isConfigured)
    }

    // MARK: - Header Name

    @Test("none has nil header name")
    func noneHeaderName() {
        #expect(OpenAIAuthentication.none.headerName == nil)
    }

    @Test("bearer uses Authorization header")
    func bearerHeaderName() {
        #expect(OpenAIAuthentication.bearer("token").headerName == "Authorization")
    }

    @Test("apiKey uses custom header name")
    func apiKeyHeaderName() {
        #expect(OpenAIAuthentication.apiKey("key", headerName: "x-api-key").headerName == "x-api-key")
    }

    @Test("environment uses Authorization header")
    func environmentHeaderName() {
        #expect(OpenAIAuthentication.environment("VAR").headerName == "Authorization")
    }

    @Test("auto uses Authorization header")
    func autoHeaderName() {
        #expect(OpenAIAuthentication.auto.headerName == "Authorization")
    }

    // MARK: - Header Value

    @Test("none has nil header value")
    func noneHeaderValue() {
        #expect(OpenAIAuthentication.none.headerValue == nil)
    }

    @Test("bearer header value has Bearer prefix")
    func bearerHeaderValue() {
        #expect(OpenAIAuthentication.bearer("sk-test").headerValue == "Bearer sk-test")
    }

    @Test("apiKey header value is the raw key")
    func apiKeyHeaderValue() {
        #expect(OpenAIAuthentication.apiKey("my-key", headerName: "api-key").headerValue == "my-key")
    }

    // MARK: - apply(to:)

    @Test("apply adds auth header to URLRequest")
    func applyAddsHeader() {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        let auth = OpenAIAuthentication.bearer("sk-test")
        auth.apply(to: &request)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test")
    }

    @Test("apply with none does not modify request")
    func applyNoneDoesNotModify() {
        var request = URLRequest(url: URL(string: "https://localhost/v1")!)
        let auth = OpenAIAuthentication.none
        auth.apply(to: &request)
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test("apply with apiKey sets custom header")
    func applyApiKey() {
        var request = URLRequest(url: URL(string: "https://azure.com/openai")!)
        let auth = OpenAIAuthentication.apiKey("azure-key", headerName: "api-key")
        auth.apply(to: &request)
        #expect(request.value(forHTTPHeaderField: "api-key") == "azure-key")
    }

    // MARK: - Convenience Initializers

    @Test("from(apiKey:) creates bearer authentication")
    func fromApiKey() {
        let auth = OpenAIAuthentication.from(apiKey: "sk-test123")
        #expect(auth == .bearer("sk-test123"))
    }

    @Test("for(endpoint:apiKey:) returns .none for Ollama")
    func forEndpointOllama() {
        let auth = OpenAIAuthentication.for(endpoint: .ollama())
        #expect(auth == .none)
    }

    @Test("for(endpoint:apiKey:) returns bearer for OpenAI with key")
    func forEndpointOpenAIWithKey() {
        let auth = OpenAIAuthentication.for(endpoint: .openAI, apiKey: "sk-test")
        #expect(auth == .bearer("sk-test"))
    }

    @Test("for(endpoint:apiKey:) returns environment for OpenAI without key")
    func forEndpointOpenAIWithoutKey() {
        let auth = OpenAIAuthentication.for(endpoint: .openAI)
        #expect(auth == .environment("OPENAI_API_KEY"))
    }

    @Test("for(endpoint:apiKey:) returns bearer for OpenRouter with key")
    func forEndpointOpenRouterWithKey() {
        let auth = OpenAIAuthentication.for(endpoint: .openRouter, apiKey: "or-key")
        #expect(auth == .bearer("or-key"))
    }

    @Test("for(endpoint:apiKey:) returns environment for OpenRouter without key")
    func forEndpointOpenRouterWithoutKey() {
        let auth = OpenAIAuthentication.for(endpoint: .openRouter)
        #expect(auth == .environment("OPENROUTER_API_KEY"))
    }

    @Test("for(endpoint:apiKey:) returns apiKey for Azure with key")
    func forEndpointAzureWithKey() {
        let auth = OpenAIAuthentication.for(
            endpoint: .azure(resource: "res", deployment: "dep", apiVersion: "v1"),
            apiKey: "azure-key"
        )
        #expect(auth == .apiKey("azure-key", headerName: "api-key"))
    }

    @Test("for(endpoint:apiKey:) returns environment for Azure without key")
    func forEndpointAzureWithoutKey() {
        let auth = OpenAIAuthentication.for(
            endpoint: .azure(resource: "res", deployment: "dep", apiVersion: "v1")
        )
        #expect(auth == .environment("AZURE_OPENAI_API_KEY"))
    }

    @Test("for(endpoint:apiKey:) returns bearer for custom with key")
    func forEndpointCustomWithKey() {
        let url = URL(string: "https://custom.com/v1")!
        let auth = OpenAIAuthentication.for(endpoint: .custom(url), apiKey: "my-key")
        #expect(auth == .bearer("my-key"))
    }

    @Test("for(endpoint:apiKey:) returns auto for custom without key")
    func forEndpointCustomWithoutKey() {
        let url = URL(string: "https://custom.com/v1")!
        let auth = OpenAIAuthentication.for(endpoint: .custom(url))
        #expect(auth == .auto)
    }

    // MARK: - Equatable

    @Test("Same bearer tokens are equal")
    func sameBearerTokensEqual() {
        #expect(OpenAIAuthentication.bearer("token") == .bearer("token"))
    }

    @Test("Different bearer tokens are not equal")
    func differentBearerTokensNotEqual() {
        #expect(OpenAIAuthentication.bearer("token1") != .bearer("token2"))
    }

    @Test("Same apiKey with same header are equal")
    func sameApiKeysEqual() {
        let a = OpenAIAuthentication.apiKey("key", headerName: "api-key")
        let b = OpenAIAuthentication.apiKey("key", headerName: "api-key")
        #expect(a == b)
    }

    @Test("Same apiKey with different headers are not equal")
    func sameKeyDifferentHeaderNotEqual() {
        let a = OpenAIAuthentication.apiKey("key", headerName: "api-key")
        let b = OpenAIAuthentication.apiKey("key", headerName: "x-api-key")
        #expect(a != b)
    }

    @Test("Different enum cases are not equal")
    func differentCasesNotEqual() {
        #expect(OpenAIAuthentication.none != .auto)
        #expect(OpenAIAuthentication.bearer("key") != .apiKey("key"))
        #expect(OpenAIAuthentication.bearer("key") != .none)
    }

    @Test("none equals none")
    func noneEqualsNone() {
        #expect(OpenAIAuthentication.none == .none)
    }

    @Test("auto equals auto")
    func autoEqualsAuto() {
        #expect(OpenAIAuthentication.auto == .auto)
    }

    @Test("environment with same variable name are equal")
    func sameEnvironmentEqual() {
        #expect(OpenAIAuthentication.environment("VAR") == .environment("VAR"))
    }

    @Test("environment with different variable names are not equal")
    func differentEnvironmentNotEqual() {
        #expect(OpenAIAuthentication.environment("VAR1") != .environment("VAR2"))
    }

    // MARK: - Hashable

    @Test("Hashing works for set usage")
    func hashableForSet() {
        var set: Set<OpenAIAuthentication> = []
        set.insert(.none)
        set.insert(.bearer("key"))
        set.insert(.auto)
        // Due to security-aware hashing, different bearers hash the same
        // but the set still works correctly via Equatable
        set.insert(.bearer("other-key"))
        #expect(set.count >= 3)
    }

    // MARK: - Debug Description

    @Test("debugDescription redacts bearer token")
    func debugDescriptionRedactsBearer() {
        let auth = OpenAIAuthentication.bearer("sk-secret-key")
        #expect(auth.debugDescription == "OpenAIAuthentication.bearer(***)")
        #expect(!auth.debugDescription.contains("sk-secret-key"))
    }

    @Test("debugDescription redacts apiKey")
    func debugDescriptionRedactsApiKey() {
        let auth = OpenAIAuthentication.apiKey("my-secret", headerName: "api-key")
        #expect(auth.debugDescription.contains("***"))
        #expect(!auth.debugDescription.contains("my-secret"))
        #expect(auth.debugDescription.contains("api-key"))
    }

    @Test("debugDescription shows environment variable name")
    func debugDescriptionShowsEnvVar() {
        let auth = OpenAIAuthentication.environment("OPENAI_API_KEY")
        #expect(auth.debugDescription.contains("OPENAI_API_KEY"))
    }

    @Test("debugDescription for none")
    func debugDescriptionNone() {
        #expect(OpenAIAuthentication.none.debugDescription == "OpenAIAuthentication.none")
    }

    @Test("debugDescription for auto")
    func debugDescriptionAuto() {
        #expect(OpenAIAuthentication.auto.debugDescription == "OpenAIAuthentication.auto")
    }

    @Test("description matches debugDescription")
    func descriptionMatchesDebug() {
        let auth = OpenAIAuthentication.bearer("test")
        #expect(auth.description == auth.debugDescription)
    }

    // MARK: - Sendable

    @Test("Sendable conformance compiles")
    func sendableConformance() {
        let auth: Sendable = OpenAIAuthentication.bearer("test")
        #expect(auth is OpenAIAuthentication)
    }
}

#endif // CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
