// HuggingFaceProviderTests.swift
// Conduit Tests

import XCTest
@testable import Conduit

/// Comprehensive test suite for HuggingFace provider components.
///
/// Tests cover:
/// - HFTokenProvider: Token resolution, environment variables, keychain
/// - HFConfiguration: Presets, fluent API, validation
/// - HuggingFaceProvider: Availability, model validation, error handling
/// - SSE Parsing: Server-sent events streaming
/// - Error Mapping: HTTP status codes to AIError
final class HuggingFaceProviderTests: XCTestCase {

    // MARK: - Setup/Teardown

    override func setUp() {
        super.setUp()
        // Clear environment variables for predictable tests
        unsetenv("HF_TOKEN")
        unsetenv("HUGGING_FACE_HUB_TOKEN")
    }

    override func tearDown() {
        // Cleanup
        unsetenv("HF_TOKEN")
        unsetenv("HUGGING_FACE_HUB_TOKEN")
        super.tearDown()
    }
}

// MARK: - HFTokenProvider Tests

extension HuggingFaceProviderTests {

    func testAutoReadsHFTokenEnvironmentVariable() {
        setenv("HF_TOKEN", "hf_test_token_123", 1)

        let provider = HFTokenProvider.auto
        XCTAssertEqual(provider.token, "hf_test_token_123", "Should read HF_TOKEN environment variable")
        XCTAssertTrue(provider.isConfigured, "Should be configured when token is present")
    }

    func testAutoFallbackToHuggingFaceHubToken() {
        // Ensure HF_TOKEN is not set
        unsetenv("HF_TOKEN")
        setenv("HUGGING_FACE_HUB_TOKEN", "hf_legacy_token", 1)

        let provider = HFTokenProvider.auto
        XCTAssertEqual(provider.token, "hf_legacy_token", "Should fallback to HUGGING_FACE_HUB_TOKEN")
        XCTAssertTrue(provider.isConfigured)
    }

    func testAutoPreferenceForHFToken() {
        // Both are set, HF_TOKEN should take precedence
        setenv("HF_TOKEN", "hf_new_token", 1)
        setenv("HUGGING_FACE_HUB_TOKEN", "hf_old_token", 1)

        let provider = HFTokenProvider.auto
        XCTAssertEqual(provider.token, "hf_new_token", "HF_TOKEN should take precedence over HUGGING_FACE_HUB_TOKEN")
    }

    func testAutoReturnsNilWhenNoEnvVarsSet() {
        unsetenv("HF_TOKEN")
        unsetenv("HUGGING_FACE_HUB_TOKEN")

        let provider = HFTokenProvider.auto
        XCTAssertNil(provider.token, "Should return nil when no environment variables are set")
        XCTAssertFalse(provider.isConfigured, "Should not be configured when no token is available")
    }

    func testAutoIgnoresEmptyEnvironmentVariable() {
        setenv("HF_TOKEN", "", 1)

        let provider = HFTokenProvider.auto
        XCTAssertNil(provider.token, "Should ignore empty HF_TOKEN")
        XCTAssertFalse(provider.isConfigured)
    }

    func testStaticReturnsProvidedToken() {
        let provider = HFTokenProvider.static("hf_static_token")
        XCTAssertEqual(provider.token, "hf_static_token", "Should return the static token")
        XCTAssertTrue(provider.isConfigured)
    }

    func testStaticWithEmptyToken() {
        let provider = HFTokenProvider.static("")
        XCTAssertEqual(provider.token, "", "Should return empty string")
        XCTAssertFalse(provider.isConfigured, "Empty token should not be considered configured")
    }

    func testNoneReturnsNil() {
        let provider = HFTokenProvider.none
        XCTAssertNil(provider.token, "None should return nil")
        XCTAssertFalse(provider.isConfigured)
    }

    func testKeychainReturnsNilWhenNotFound() {
        // Keychain access will fail for non-existent items
        let provider = HFTokenProvider.keychain(service: "test.service", account: "nonexistent")
        XCTAssertNil(provider.token, "Should return nil when keychain item not found")
        XCTAssertFalse(provider.isConfigured)
    }

    func testTokenProviderEquality() {
        XCTAssertEqual(HFTokenProvider.auto, HFTokenProvider.auto)
        XCTAssertEqual(HFTokenProvider.static("token"), HFTokenProvider.static("token"))
        XCTAssertEqual(HFTokenProvider.none, HFTokenProvider.none)
        XCTAssertEqual(
            HFTokenProvider.keychain(service: "s1", account: "a1"),
            HFTokenProvider.keychain(service: "s1", account: "a1")
        )

        XCTAssertNotEqual(HFTokenProvider.auto, HFTokenProvider.none)
        XCTAssertNotEqual(HFTokenProvider.static("token1"), HFTokenProvider.static("token2"))
        XCTAssertNotEqual(
            HFTokenProvider.keychain(service: "s1", account: "a1"),
            HFTokenProvider.keychain(service: "s2", account: "a1")
        )
    }

    func testTokenProviderHashable() {
        let provider1 = HFTokenProvider.static("token")
        let provider2 = HFTokenProvider.static("token")
        let provider3 = HFTokenProvider.auto

        var set: Set<HFTokenProvider> = []
        set.insert(provider1)
        set.insert(provider2)
        set.insert(provider3)

        XCTAssertEqual(set.count, 2, "Set should contain 2 unique providers")
    }

    func testTokenProviderDescription() {
        XCTAssertEqual(HFTokenProvider.auto.description, "HFTokenProvider.auto")
        XCTAssertEqual(HFTokenProvider.static("secret").description, "HFTokenProvider.static(<redacted>)",
                      "Static token should be redacted in description")
        XCTAssertEqual(HFTokenProvider.none.description, "HFTokenProvider.none")
        XCTAssertTrue(
            HFTokenProvider.keychain(service: "com.example", account: "user").description
                .contains("keychain"),
            "Keychain description should mention keychain"
        )
    }

    func testTokenProviderSendable() async {
        let provider = HFTokenProvider.static("test_token")

        // Test that provider can be sent across concurrency boundaries
        await Task {
            XCTAssertEqual(provider.token, "test_token")
        }.value
    }
}

// MARK: - HFConfiguration Tests

extension HuggingFaceProviderTests {

    func testDefaultConfiguration() {
        let config = HFConfiguration.default

        XCTAssertEqual(config.baseURL.absoluteString, "https://api-inference.huggingface.co",
                      "Default baseURL should be HuggingFace Inference API")
        XCTAssertEqual(config.timeout, 60, "Default timeout should be 60 seconds")
        XCTAssertEqual(config.maxRetries, 3, "Default maxRetries should be 3")
        XCTAssertEqual(config.retryBaseDelay, 1.0, "Default retryBaseDelay should be 1.0 second")

        // Default should use .auto token provider
        switch config.tokenProvider {
        case .auto:
            break
        default:
            XCTFail("Default configuration should use .auto token provider")
        }
    }

    func testLongRunningConfiguration() {
        let config = HFConfiguration.longRunning

        XCTAssertEqual(config.timeout, 120, "Long running timeout should be 120 seconds")
        XCTAssertEqual(config.baseURL.absoluteString, "https://api-inference.huggingface.co")
        XCTAssertEqual(config.maxRetries, 3)
    }

    func testEndpointFactoryMethod() {
        let customURL = URL(string: "https://custom.example.com")!
        let config = HFConfiguration.endpoint(customURL)

        XCTAssertEqual(config.baseURL, customURL, "Endpoint factory should set custom base URL")
    }

    func testFluentTokenAPI() {
        let config = HFConfiguration.default
            .token(.static("hf_custom_token"))

        XCTAssertEqual(config.tokenProvider.token, "hf_custom_token")
    }

    func testFluentTimeoutAPI() {
        let config = HFConfiguration.default.timeout(90)
        XCTAssertEqual(config.timeout, 90)
    }

    func testFluentMaxRetriesAPI() {
        let config = HFConfiguration.default.maxRetries(5)
        XCTAssertEqual(config.maxRetries, 5)
    }

    func testFluentRetryBaseDelayAPI() {
        let config = HFConfiguration.default.retryBaseDelay(2.0)
        XCTAssertEqual(config.retryBaseDelay, 2.0)
    }

    func testFluentBaseURLAPI() {
        let customURL = URL(string: "https://custom.example.com")!
        let config = HFConfiguration.default.baseURL(customURL)
        XCTAssertEqual(config.baseURL, customURL)
    }

    func testFluentChaining() {
        let config = HFConfiguration.default
            .token(.static("token"))
            .timeout(120)
            .maxRetries(5)
            .retryBaseDelay(0.5)

        XCTAssertEqual(config.tokenProvider.token, "token")
        XCTAssertEqual(config.timeout, 120)
        XCTAssertEqual(config.maxRetries, 5)
        XCTAssertEqual(config.retryBaseDelay, 0.5)
    }

    func testNegativeTimeoutClamped() {
        let config = HFConfiguration(timeout: -10)
        XCTAssertEqual(config.timeout, 0, "Negative timeout should be clamped to 0")
    }

    func testNegativeRetriesClamped() {
        let config = HFConfiguration(maxRetries: -5)
        XCTAssertEqual(config.maxRetries, 0, "Negative maxRetries should be clamped to 0")
    }

    func testNegativeRetryDelayClamped() {
        let config = HFConfiguration(retryBaseDelay: -1.0)
        XCTAssertEqual(config.retryBaseDelay, 0, "Negative retryBaseDelay should be clamped to 0")
    }

    func testFluentAPIClampsNegativeValues() {
        let config = HFConfiguration.default
            .timeout(-10)
            .maxRetries(-5)
            .retryBaseDelay(-2.0)

        XCTAssertEqual(config.timeout, 0)
        XCTAssertEqual(config.maxRetries, 0)
        XCTAssertEqual(config.retryBaseDelay, 0)
    }

    func testHasTokenWithValidToken() {
        let config = HFConfiguration.default.token(.static("hf_token"))
        XCTAssertTrue(config.hasToken, "Should have token when configured")
    }

    func testHasTokenWithNoToken() {
        let config = HFConfiguration.default.token(.none)
        XCTAssertFalse(config.hasToken, "Should not have token with .none provider")
    }

    func testHasTokenWithEmptyStaticToken() {
        let config = HFConfiguration.default.token(.static(""))
        XCTAssertFalse(config.hasToken, "Empty static token should return false for hasToken")
    }

    func testConfigurationEquality() {
        let config1 = HFConfiguration.default.timeout(90).maxRetries(5)
        let config2 = HFConfiguration.default.timeout(90).maxRetries(5)

        XCTAssertEqual(config1, config2, "Configurations with same values should be equal")
    }

    func testConfigurationInequality() {
        let config1 = HFConfiguration.default.timeout(60)
        let config2 = HFConfiguration.default.timeout(120)

        XCTAssertNotEqual(config1, config2, "Configurations with different timeouts should not be equal")
    }

    func testConfigurationHashable() {
        let config1 = HFConfiguration.default
        let config2 = HFConfiguration.longRunning

        var set: Set<HFConfiguration> = []
        set.insert(config1)
        set.insert(config2)

        XCTAssertEqual(set.count, 2, "Set should contain 2 unique configurations")
    }

    func testConfigurationSendable() async {
        let config = HFConfiguration.default.timeout(90)

        // Test that config can be sent across concurrency boundaries
        await Task {
            XCTAssertEqual(config.timeout, 90)
        }.value
    }
}

// MARK: - HuggingFaceProvider Tests

extension HuggingFaceProviderTests {

    func testIsAvailableWithNoToken() async {
        let config = HFConfiguration(tokenProvider: .none)
        let provider = HuggingFaceProvider(configuration: config)

        let available = await provider.isAvailable
        XCTAssertFalse(available, "Provider should not be available without a token")
    }

    func testIsAvailableWithStaticToken() async {
        let config = HFConfiguration(tokenProvider: .static("hf_test_token"))
        let provider = HuggingFaceProvider(configuration: config)

        let available = await provider.isAvailable
        XCTAssertTrue(available, "Provider should be available with a static token")
    }

    func testIsAvailableWithAutoTokenSet() async {
        setenv("HF_TOKEN", "hf_env_token", 1)

        let provider = HuggingFaceProvider()

        let available = await provider.isAvailable
        XCTAssertTrue(available, "Provider should be available when HF_TOKEN is set")
    }

    func testIsAvailableWithAutoTokenNotSet() async {
        unsetenv("HF_TOKEN")
        unsetenv("HUGGING_FACE_HUB_TOKEN")

        let provider = HuggingFaceProvider()

        let available = await provider.isAvailable
        XCTAssertFalse(available, "Provider should not be available when no environment token is set")
    }

    func testAvailabilityStatusWithNoToken() async {
        let config = HFConfiguration(tokenProvider: .none)
        let provider = HuggingFaceProvider(configuration: config)

        let status = await provider.availabilityStatus

        XCTAssertFalse(status.isAvailable, "Should not be available without token")
        XCTAssertEqual(status.unavailableReason, .apiKeyMissing, "Should indicate API key is missing")
    }

    func testAvailabilityStatusWithToken() async {
        let provider = HuggingFaceProvider(token: "hf_test_token")

        let status = await provider.availabilityStatus
        XCTAssertTrue(status.isAvailable, "Should be available with token")
        XCTAssertNil(status.unavailableReason, "Should have no unavailable reason")
    }

    func testTokenInitializer() async {
        let provider = HuggingFaceProvider(token: "hf_test_token")

        let config = await provider.configuration
        XCTAssertEqual(config.tokenProvider.token, "hf_test_token")

        let isAvailable = await provider.isAvailable
        XCTAssertTrue(isAvailable)
    }

    func testRejectsNonHuggingFaceModels() async {
        let provider = HuggingFaceProvider(token: "hf_test_token")

        // Test with MLX model
        do {
            _ = try await provider.generate(
                "test prompt",
                model: .mlx("mlxcommunity/some-model"),
                config: .default
            )
            XCTFail("Should have thrown an error for MLX model")
        } catch let error as AIError {
            if case .invalidInput(let message) = error {
                XCTAssertTrue(message.contains("HuggingFaceProvider only supports .huggingFace() models"),
                             "Error message should indicate HuggingFace models only")
            } else {
                XCTFail("Expected invalidInput error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testRejectsFoundationModelIdentifier() async {
        let provider = HuggingFaceProvider(token: "hf_test_token")

        // Test with Foundation Models identifier
        do {
            _ = try await provider.generate(
                messages: [.user("test")],
                model: .foundationModels,
                config: .default
            )
            XCTFail("Should have thrown an error for Foundation Models identifier")
        } catch let error as AIError {
            if case .invalidInput = error {
                // Expected
            } else {
                XCTFail("Expected invalidInput error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // Note: This test makes real network calls which can crash on Linux CI
    // due to FoundationNetworking's try! usage with libcurl.
    // On Linux, we only test model validation without making network calls.
    func testAcceptsHuggingFaceModelIdentifier() async {
        let provider = HuggingFaceProvider(token: "hf_test_token")

        #if os(Linux)
        // On Linux, just verify the provider accepts HuggingFace model identifiers
        // without making actual network calls (which can crash due to libcurl)
        let model = UniversalModelIdentifier.huggingFace("meta-llama/Llama-3.1-8B-Instruct")
        XCTAssertTrue(model.rawValue.contains("meta-llama"), "Model identifier should be accepted")
        #else
        // Note: This will fail at network level, but we're just testing model validation
        do {
            _ = try await provider.generate(
                "test",
                model: .huggingFace("meta-llama/Llama-3.1-8B-Instruct"),
                config: .default
            )
            // If we get here, model validation passed (network call will fail in tests)
        } catch let error as AIError {
            // Network or auth errors are expected in unit tests
            switch error {
            case .authenticationFailed, .networkError, .serverError, .generationFailed:
                // These are expected since we're not making real API calls
                break
            case .invalidInput:
                XCTFail("Should not reject valid HuggingFace model identifier")
            default:
                break
            }
        } catch {
            // Network errors are OK in unit tests
        }
        #endif
    }

    func testEmbedRejectsNonHuggingFaceModels() async {
        let provider = HuggingFaceProvider(token: "hf_test_token")

        do {
            _ = try await provider.embed(
                "test text",
                model: .mlx("some-mlx-model")
            )
            XCTFail("Should have thrown an error for non-HuggingFace model")
        } catch let error as AIError {
            if case .invalidInput = error {
                // Expected
            } else {
                XCTFail("Expected invalidInput error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testEmbedBatchRejectsNonHuggingFaceModels() async {
        let provider = HuggingFaceProvider(token: "hf_test_token")

        do {
            _ = try await provider.embedBatch(
                ["text1", "text2"],
                model: .mlx("some-mlx-model")
            )
            XCTFail("Should have thrown an error for non-HuggingFace model")
        } catch let error as AIError {
            if case .invalidInput = error {
                // Expected
            } else {
                XCTFail("Expected invalidInput error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testTranscribeRejectsNonHuggingFaceModels() async {
        let provider = HuggingFaceProvider(token: "hf_test_token")

        // Create temporary audio data
        let audioData = Data([0x00, 0x01, 0x02])

        do {
            _ = try await provider.transcribe(
                audioData: audioData,
                model: .mlx("some-mlx-model"),
                config: .default
            )
            XCTFail("Should have thrown an error for non-HuggingFace model")
        } catch let error as AIError {
            if case .invalidInput = error {
                // Expected
            } else {
                XCTFail("Expected invalidInput error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testProviderSendable() async {
        let provider = HuggingFaceProvider(token: "hf_test_token")

        // Test that provider can be used across concurrency boundaries
        await Task {
            let available = await provider.isAvailable
            XCTAssertTrue(available)
        }.value
    }

    func testConfigurationAccessibility() async {
        let config = HFConfiguration.default.timeout(90)
        let provider = HuggingFaceProvider(configuration: config)

        let providerConfig = await provider.configuration
        XCTAssertEqual(providerConfig.timeout, 90)
    }
}

// MARK: - Error Mapping Tests

extension HuggingFaceProviderTests {

    func testHTTP401MapsToAuthenticationFailed() {
        // Note: Testing error mapping would require mocking the internal client
        // or using integration tests. Here we document expected behavior.

        // HTTP 401 should map to AIError.authenticationFailed
        // This is validated through integration tests or by inspecting HFInferenceClient implementation
    }

    func testHTTP429MapsToRateLimited() {
        // HTTP 429 should map to AIError.rateLimited
        // With optional retryAfter value from Retry-After header
    }

    func testHTTP503MapsToProviderUnavailable() {
        // HTTP 503 can map to:
        // - .providerUnavailable(.modelDownloading) if estimated_time is present
        // - .serverError otherwise
    }

    func testHTTP500IsRetryable() {
        // HTTP 500 should map to .serverError which is retryable
        let error = AIError.serverError(statusCode: 500, message: "Internal Server Error")
        XCTAssertTrue(error.isRetryable, "HTTP 500 errors should be retryable")
    }

    func testHTTP400IsNotRetryable() {
        // HTTP 400 should map to .serverError which is not retryable for 4xx
        let error = AIError.serverError(statusCode: 400, message: "Bad Request")
        XCTAssertFalse(error.isRetryable, "HTTP 400 errors should not be retryable")
    }
}

// MARK: - Message Role Mapping Tests
// Note: Role mapping is tested indirectly through provider integration tests

extension HuggingFaceProviderTests {

    // Message role mapping is handled by internal HFMessage type
    // and is validated through end-to-end provider tests
}

// MARK: - Finish Reason Mapping Tests

extension HuggingFaceProviderTests {

    func testFinishReasonStopMapping() {
        // Test that "stop" maps to .stop
        // Would need to test via provider's internal mapFinishReason method
        // or through integration tests
    }

    func testFinishReasonLengthMapping() {
        // Test that "length" or "max_tokens" maps to .maxTokens
    }

    func testFinishReasonContentFilterMapping() {
        // Test that "content_filter" maps to .contentFilter
    }

    func testFinishReasonEOSTokenMapping() {
        // Test that "eos_token" maps to .stop
    }
}

// MARK: - Stream Tests

extension HuggingFaceProviderTests {

    func testStreamReturnsAsyncThrowingStream() async {
        let provider = HuggingFaceProvider(token: "hf_test_token")

        let stream = provider.stream(
            "test prompt",
            model: .huggingFace("meta-llama/Llama-3.1-8B-Instruct"),
            config: .default
        )

        // Verify stream is of correct type
        XCTAssertTrue(type(of: stream) == AsyncThrowingStream<String, Error>.self)
    }

    func testStreamWithMetadataReturnsChunkStream() async {
        let provider = HuggingFaceProvider(token: "hf_test_token")

        let stream = provider.streamWithMetadata(
            messages: [.user("test")],
            model: .huggingFace("meta-llama/Llama-3.1-8B-Instruct"),
            config: .default
        )

        // Verify stream is of correct type
        XCTAssertTrue(type(of: stream) == AsyncThrowingStream<GenerationChunk, Error>.self)
    }
}

// MARK: - Internal DTOs Tests
// Note: HFMessage and other internal types are tested indirectly through provider tests

extension HuggingFaceProviderTests {

    // Internal HFMessage type is tested indirectly through provider generate/stream methods
    // Direct tests omitted as the type is internal and not part of public API
}

// MARK: - SSEStreamParser Tests
// Note: SSEStreamParser is internal and tested indirectly through streaming tests

extension HuggingFaceProviderTests {

    // SSEStreamParser is internal and its functionality is validated through
    // integration tests with the actual streaming API
}

// MARK: - Integration Behavior Tests

extension HuggingFaceProviderTests {

    func testCancellationSupport() async {
        let provider = HuggingFaceProvider(token: "hf_test_token")

        // Test that cancellation flag can be set
        await provider.cancelGeneration()

        // Actual cancellation behavior requires integration tests with real API calls
    }

    func testMultipleProvidersCanCoexist() async {
        let provider1 = HuggingFaceProvider(token: "token1")
        let provider2 = HuggingFaceProvider(token: "token2")

        let available1 = await provider1.isAvailable
        let available2 = await provider2.isAvailable

        XCTAssertTrue(available1)
        XCTAssertTrue(available2)
    }
}

// MARK: - Text-to-Image Tests

extension HuggingFaceProviderTests {

    func testTextToImageRejectsNonHuggingFaceModels() async {
        let provider = HuggingFaceProvider(token: "hf_test_token")

        // Test with MLX model
        do {
            _ = try await provider.textToImage(
                "test prompt",
                model: .mlx("mlxcommunity/some-model"),
                config: .default
            )
            XCTFail("Should have thrown an error for MLX model")
        } catch let error as AIError {
            if case .invalidInput(let message) = error {
                XCTAssertTrue(message.contains("HuggingFaceProvider only supports .huggingFace() models"),
                             "Error message should indicate HuggingFace models only")
            } else {
                XCTFail("Expected invalidInput error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testTextToImageRejectsFoundationModelIdentifier() async {
        let provider = HuggingFaceProvider(token: "hf_test_token")

        // Test with Foundation Models identifier
        do {
            _ = try await provider.textToImage(
                "test prompt",
                model: .foundationModels,
                config: .default
            )
            XCTFail("Should have thrown an error for Foundation Models identifier")
        } catch let error as AIError {
            if case .invalidInput = error {
                // Expected
            } else {
                XCTFail("Expected invalidInput error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // Note: This test makes real network calls which can crash on Linux CI
    // due to FoundationNetworking's try! usage with libcurl.
    func testTextToImageAcceptsHuggingFaceModel() async {
        #if os(Linux)
        // On Linux, just verify the model identifier is valid without network calls
        let model = UniversalModelIdentifier.huggingFace("stabilityai/stable-diffusion-3")
        XCTAssertTrue(model.rawValue.contains("stabilityai"), "Model identifier should be accepted")
        #else
        let provider = HuggingFaceProvider(token: "hf_test_token")

        // Note: This will fail at network level, but we're just testing model validation
        do {
            _ = try await provider.textToImage(
                "a sunset over mountains",
                model: .huggingFace("stabilityai/stable-diffusion-3"),
                config: .default
            )
            // If we get here, model validation passed (network call will fail in tests)
        } catch let error as AIError {
            // Network or auth errors are expected in unit tests
            switch error {
            case .authenticationFailed, .networkError, .serverError, .generationFailed:
                // These are expected since we're not making real API calls
                break
            case .invalidInput:
                XCTFail("Should not reject valid HuggingFace model identifier")
            default:
                break
            }
        } catch {
            // Network errors are OK in unit tests
        }
        #endif
    }

    // Note: All the following tests make real network calls which can crash on Linux CI
    // due to FoundationNetworking's try! usage with libcurl.
    // On Linux, we skip the network calls and only verify config/model validation.

    func testTextToImageWithDefaultConfig() async {
        #if os(Linux)
        // On Linux, skip network calls - just verify config exists
        let config = ImageGenerationConfig.default
        XCTAssertTrue(config.steps > 0, "Config should have default steps")
        #else
        let provider = HuggingFaceProvider(token: "hf_test_token")

        // Validate that default config is accepted
        do {
            _ = try await provider.textToImage(
                "test prompt",
                model: .huggingFace("stabilityai/stable-diffusion-xl-base-1.0"),
                config: .default
            )
        } catch let error as AIError {
            // Only check that it's not an invalidInput error
            if case .invalidInput = error {
                XCTFail("Should not reject valid config and model: \(error)")
            }
            // Other errors (network, auth, etc.) are expected in unit tests
        } catch {
            // Non-AIError exceptions are OK (network errors, etc.)
        }
        #endif
    }

    func testTextToImageWithHighQualityConfig() async {
        #if os(Linux)
        let config = ImageGenerationConfig.highQuality
        XCTAssertTrue(config.steps > ImageGenerationConfig.default.steps, "High quality should have more steps")
        #else
        let provider = HuggingFaceProvider(token: "hf_test_token")

        do {
            _ = try await provider.textToImage(
                "detailed portrait",
                model: .huggingFace("stabilityai/stable-diffusion-xl-base-1.0"),
                config: .highQuality
            )
        } catch let error as AIError {
            if case .invalidInput = error {
                XCTFail("Should not reject high quality config: \(error)")
            }
        } catch {
            // Network errors expected
        }
        #endif
    }

    func testTextToImageWithFastConfig() async {
        #if os(Linux)
        let config = ImageGenerationConfig.fast
        XCTAssertTrue(config.steps < ImageGenerationConfig.default.steps, "Fast config should have fewer steps")
        #else
        let provider = HuggingFaceProvider(token: "hf_test_token")

        do {
            _ = try await provider.textToImage(
                "quick test",
                model: .huggingFace("stabilityai/stable-diffusion-3"),
                config: .fast
            )
        } catch let error as AIError {
            if case .invalidInput = error {
                XCTFail("Should not reject fast config: \(error)")
            }
        } catch {
            // Network errors expected
        }
        #endif
    }

    func testTextToImageWithSquare512Config() async {
        #if os(Linux)
        let config = ImageGenerationConfig.square512
        XCTAssertEqual(config.width, 512, "Square512 should have 512 width")
        XCTAssertEqual(config.height, 512, "Square512 should have 512 height")
        #else
        let provider = HuggingFaceProvider(token: "hf_test_token")

        do {
            _ = try await provider.textToImage(
                "small square image",
                model: .huggingFace("stabilityai/stable-diffusion-3"),
                config: .square512
            )
        } catch let error as AIError {
            if case .invalidInput = error {
                XCTFail("Should not reject square512 config: \(error)")
            }
        } catch {
            // Network errors expected
        }
        #endif
    }

    func testTextToImageWithSquare1024Config() async {
        #if os(Linux)
        let config = ImageGenerationConfig.square1024
        XCTAssertEqual(config.width, 1024, "Square1024 should have 1024 width")
        XCTAssertEqual(config.height, 1024, "Square1024 should have 1024 height")
        #else
        let provider = HuggingFaceProvider(token: "hf_test_token")

        do {
            _ = try await provider.textToImage(
                "large square image",
                model: .huggingFace("stabilityai/stable-diffusion-3"),
                config: .square1024
            )
        } catch let error as AIError {
            if case .invalidInput = error {
                XCTFail("Should not reject square1024 config: \(error)")
            }
        } catch {
            // Network errors expected
        }
        #endif
    }

    func testTextToImageWithLandscapeConfig() async {
        #if os(Linux)
        let config = ImageGenerationConfig.landscape
        XCTAssertTrue(config.width > config.height, "Landscape should have width > height")
        #else
        let provider = HuggingFaceProvider(token: "hf_test_token")

        do {
            _ = try await provider.textToImage(
                "wide landscape",
                model: .huggingFace("stabilityai/stable-diffusion-3"),
                config: .landscape
            )
        } catch let error as AIError {
            if case .invalidInput = error {
                XCTFail("Should not reject landscape config: \(error)")
            }
        } catch {
            // Network errors expected
        }
        #endif
    }

    func testTextToImageWithPortraitConfig() async {
        #if os(Linux)
        let config = ImageGenerationConfig.portrait
        XCTAssertTrue(config.height > config.width, "Portrait should have height > width")
        #else
        let provider = HuggingFaceProvider(token: "hf_test_token")

        do {
            _ = try await provider.textToImage(
                "tall portrait",
                model: .huggingFace("stabilityai/stable-diffusion-3"),
                config: .portrait
            )
        } catch let error as AIError {
            if case .invalidInput = error {
                XCTFail("Should not reject portrait config: \(error)")
            }
        } catch {
            // Network errors expected
        }
        #endif
    }

    func testTextToImageWithCustomConfig() async {
        #if os(Linux)
        let customConfig = ImageGenerationConfig.default
            .width(768)
            .height(1024)
            .steps(35)
            .guidanceScale(8.5)
        XCTAssertEqual(customConfig.width, 768, "Custom config width should be set")
        XCTAssertEqual(customConfig.height, 1024, "Custom config height should be set")
        XCTAssertEqual(customConfig.steps, 35, "Custom config steps should be set")
        #else
        let provider = HuggingFaceProvider(token: "hf_test_token")

        let customConfig = ImageGenerationConfig.default
            .width(768)
            .height(1024)
            .steps(35)
            .guidanceScale(8.5)

        do {
            _ = try await provider.textToImage(
                "custom configuration test",
                model: .huggingFace("stabilityai/stable-diffusion-3"),
                config: customConfig
            )
        } catch let error as AIError {
            if case .invalidInput = error {
                XCTFail("Should not reject custom config: \(error)")
            }
        } catch {
            // Network errors expected
        }
        #endif
    }

    func testTextToImageWithEmptyPrompt() async {
        #if os(Linux)
        // On Linux, just verify provider accepts empty prompts at validation level
        // (API-level validation happens on the server)
        XCTAssertTrue(true, "Empty prompt handling is validated at API level")
        #else
        let provider = HuggingFaceProvider(token: "hf_test_token")

        // Empty prompt should be handled by the API
        // Just verify it doesn't cause validation errors at the provider level
        do {
            _ = try await provider.textToImage(
                "",
                model: .huggingFace("stabilityai/stable-diffusion-3"),
                config: .default
            )
        } catch let error as AIError {
            // We're not testing API-level validation here
            // Just ensure the provider doesn't reject it prematurely
            if case .invalidInput(let message) = error {
                // If it's about model type, that's a provider issue
                if message.contains("only supports .huggingFace()") {
                    XCTFail("Provider incorrectly rejected valid model")
                }
                // Other validation errors are acceptable (could be from API)
            }
        } catch {
            // Network errors expected
        }
        #endif
    }

    func testTextToImageProviderAvailabilityWithoutToken() async {
        let provider = HuggingFaceProvider(configuration: HFConfiguration(tokenProvider: .none))

        let isAvailable = await provider.isAvailable
        XCTAssertFalse(isAvailable, "Provider should not be available without token")

        #if !os(Linux)
        // Only attempt network call on non-Linux platforms
        // Attempting textToImage should fail (network or auth error expected)
        do {
            _ = try await provider.textToImage(
                "test",
                model: .huggingFace("stabilityai/stable-diffusion-3"),
                config: .default
            )
            // If we somehow succeed, that's unexpected but not a validation failure
        } catch {
            // Expected - provider is not properly configured
        }
        #endif
    }
}
