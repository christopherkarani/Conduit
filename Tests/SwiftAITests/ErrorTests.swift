// ErrorTests.swift
// SwiftAI

import XCTest
@testable import SwiftAI

final class ErrorTests: XCTestCase {

    // MARK: - AIError Description Tests

    func testAllErrorCasesHaveDescriptions() {
        // Test that all 18 error cases have non-empty errorDescription
        let errors: [AIError] = [
            .providerUnavailable(reason: .deviceNotSupported),
            .modelNotFound(.llama3_2_1b),
            .modelNotCached(.llama3_2_1b),
            .authenticationFailed("Invalid API key"),
            .unsupportedModel(variant: "Flux Schnell", reason: "Not supported"),
            .generationFailed(underlying: SendableError(NSError(domain: "test", code: 0))),
            .tokenLimitExceeded(count: 5000, limit: 4096),
            .contentFiltered(reason: "Policy violation"),
            .cancelled,
            .timeout(30),
            .networkError(URLError(.notConnectedToInternet)),
            .serverError(statusCode: 500, message: "Internal error"),
            .rateLimited(retryAfter: 60),
            .insufficientMemory(required: .gigabytes(8), available: .gigabytes(4)),
            .downloadFailed(underlying: SendableError(NSError(domain: "test", code: 0))),
            .fileError(underlying: SendableError(NSError(domain: "test", code: 0))),
            .invalidInput("Empty prompt"),
            .unsupportedAudioFormat("wav"),
            .unsupportedLanguage("Klingon")
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error \(error) should have description")
            XCTAssertFalse(error.errorDescription!.isEmpty, "Error \(error) description should not be empty")
        }
    }

    func testProviderUnavailableDescription() {
        let error = AIError.providerUnavailable(reason: .deviceNotSupported)
        XCTAssertTrue(error.errorDescription!.contains("unavailable"))
        XCTAssertTrue(error.errorDescription!.contains("not supported"))
    }

    func testModelNotFoundDescription() {
        let error = AIError.modelNotFound(.llama3_2_1b)
        XCTAssertTrue(error.errorDescription!.contains("not found"))
        // Model identifier has "Llama" with capital L
        XCTAssertTrue(error.errorDescription!.lowercased().contains("llama"))
    }

    func testModelNotCachedDescription() {
        let error = AIError.modelNotCached(.llama3_2_1b)
        XCTAssertTrue(error.errorDescription!.contains("not cached"))
    }

    func testAuthenticationFailedDescription() {
        let error = AIError.authenticationFailed("Invalid key")
        XCTAssertTrue(error.errorDescription!.contains("Authentication failed"))
        XCTAssertTrue(error.errorDescription!.contains("Invalid key"))
    }

    func testUnsupportedModelDescription() {
        let error = AIError.unsupportedModel(
            variant: "Flux Schnell",
            reason: "Requires different architecture"
        )
        XCTAssertTrue(error.errorDescription!.contains("Unsupported model variant"))
        XCTAssertTrue(error.errorDescription!.contains("Flux Schnell"))
        XCTAssertTrue(error.errorDescription!.contains("Requires different architecture"))
    }

    func testGenerationFailedDescription() {
        let underlying = SendableError(localizedDescription: "Out of memory")
        let error = AIError.generationFailed(underlying: underlying)
        XCTAssertTrue(error.errorDescription!.contains("Generation failed"))
        XCTAssertTrue(error.errorDescription!.contains("Out of memory"))
    }

    func testTokenLimitExceededDescription() {
        let error = AIError.tokenLimitExceeded(count: 5000, limit: 4096)
        XCTAssertTrue(error.errorDescription!.contains("Token limit exceeded"))
        XCTAssertTrue(error.errorDescription!.contains("5000"))
        XCTAssertTrue(error.errorDescription!.contains("4096"))
    }

    func testContentFilteredDescription() {
        let errorWithReason = AIError.contentFiltered(reason: "Inappropriate content")
        XCTAssertTrue(errorWithReason.errorDescription!.contains("Content filtered"))
        XCTAssertTrue(errorWithReason.errorDescription!.contains("Inappropriate content"))

        let errorWithoutReason = AIError.contentFiltered(reason: nil)
        XCTAssertTrue(errorWithoutReason.errorDescription!.contains("Content filtered"))
        XCTAssertTrue(errorWithoutReason.errorDescription!.contains("safety"))
    }

    func testCancelledDescription() {
        let error = AIError.cancelled
        XCTAssertTrue(error.errorDescription!.contains("cancelled"))
    }

    func testTimeoutDescription() {
        let error = AIError.timeout(30)
        XCTAssertTrue(error.errorDescription!.contains("timed out"))
        XCTAssertTrue(error.errorDescription!.contains("30"))
    }

    func testNetworkErrorDescription() {
        let error = AIError.networkError(URLError(.notConnectedToInternet))
        XCTAssertTrue(error.errorDescription!.contains("Network error"))
    }

    func testServerErrorDescription() {
        let errorWithMessage = AIError.serverError(statusCode: 500, message: "Internal error")
        XCTAssertTrue(errorWithMessage.errorDescription!.contains("Server error"))
        XCTAssertTrue(errorWithMessage.errorDescription!.contains("500"))
        XCTAssertTrue(errorWithMessage.errorDescription!.contains("Internal error"))

        let errorWithoutMessage = AIError.serverError(statusCode: 404, message: nil)
        XCTAssertTrue(errorWithoutMessage.errorDescription!.contains("404"))
    }

    func testRateLimitedDescription() {
        let errorWithRetry = AIError.rateLimited(retryAfter: 60)
        XCTAssertTrue(errorWithRetry.errorDescription!.contains("Rate limited"))
        XCTAssertTrue(errorWithRetry.errorDescription!.contains("60"))

        let errorWithoutRetry = AIError.rateLimited(retryAfter: nil)
        XCTAssertTrue(errorWithoutRetry.errorDescription!.contains("Rate limited"))
    }

    func testInsufficientMemoryDescription() {
        let error = AIError.insufficientMemory(required: .gigabytes(8), available: .gigabytes(4))
        XCTAssertTrue(error.errorDescription!.contains("Insufficient memory"))
    }

    func testDownloadFailedDescription() {
        let error = AIError.downloadFailed(underlying: SendableError(localizedDescription: "Network timeout"))
        XCTAssertTrue(error.errorDescription!.contains("Download failed"))
        XCTAssertTrue(error.errorDescription!.contains("Network timeout"))
    }

    func testFileErrorDescription() {
        let error = AIError.fileError(underlying: SendableError(localizedDescription: "Permission denied"))
        XCTAssertTrue(error.errorDescription!.contains("File error"))
        XCTAssertTrue(error.errorDescription!.contains("Permission denied"))
    }

    func testInvalidInputDescription() {
        let error = AIError.invalidInput("Empty prompt")
        XCTAssertTrue(error.errorDescription!.contains("Invalid input"))
        XCTAssertTrue(error.errorDescription!.contains("Empty prompt"))
    }

    func testUnsupportedAudioFormatDescription() {
        let error = AIError.unsupportedAudioFormat("wav")
        XCTAssertTrue(error.errorDescription!.contains("Unsupported audio format"))
        XCTAssertTrue(error.errorDescription!.contains("wav"))
    }

    func testUnsupportedLanguageDescription() {
        let error = AIError.unsupportedLanguage("Klingon")
        XCTAssertTrue(error.errorDescription!.contains("Unsupported language"))
        XCTAssertTrue(error.errorDescription!.contains("Klingon"))
    }

    // MARK: - Recovery Suggestion Tests

    func testRecoverySuggestions() {
        let modelNotCachedError = AIError.modelNotCached(.llama3_2_1b)
        XCTAssertNotNil(modelNotCachedError.recoverySuggestion)
        XCTAssertTrue(modelNotCachedError.recoverySuggestion!.lowercased().contains("download"))

        let modelNotFoundError = AIError.modelNotFound(.llama3_2_1b)
        XCTAssertNotNil(modelNotFoundError.recoverySuggestion)
        XCTAssertTrue(modelNotFoundError.recoverySuggestion!.contains("Check"))

        let authError = AIError.authenticationFailed("Invalid key")
        XCTAssertNotNil(authError.recoverySuggestion)
        XCTAssertTrue(authError.recoverySuggestion!.contains("API key"))

        let unsupportedModelError = AIError.unsupportedModel(variant: "Flux", reason: "Not available")
        XCTAssertNotNil(unsupportedModelError.recoverySuggestion)
        XCTAssertTrue(unsupportedModelError.recoverySuggestion!.contains("supported model variant"))

        let tokenError = AIError.tokenLimitExceeded(count: 5000, limit: 4096)
        XCTAssertNotNil(tokenError.recoverySuggestion)
        XCTAssertTrue(tokenError.recoverySuggestion!.contains("4096"))

        let networkError = AIError.networkError(URLError(.notConnectedToInternet))
        XCTAssertNotNil(networkError.recoverySuggestion)
        XCTAssertTrue(networkError.recoverySuggestion!.contains("connection"))

        let cancelledError = AIError.cancelled
        XCTAssertNil(cancelledError.recoverySuggestion)
    }

    func testRecoverySuggestionForProviderUnavailable() {
        let deviceError = AIError.providerUnavailable(reason: .deviceNotSupported)
        XCTAssertNotNil(deviceError.recoverySuggestion)
        XCTAssertTrue(deviceError.recoverySuggestion!.contains("Apple Silicon"))

        let osError = AIError.providerUnavailable(reason: .osVersionNotMet(required: "iOS 26"))
        XCTAssertNotNil(osError.recoverySuggestion)
        XCTAssertTrue(osError.recoverySuggestion!.contains("iOS 26"))

        let intelligenceError = AIError.providerUnavailable(reason: .appleIntelligenceDisabled)
        XCTAssertNotNil(intelligenceError.recoverySuggestion)
        XCTAssertTrue(intelligenceError.recoverySuggestion!.contains("Apple Intelligence"))

        let downloadingError = AIError.providerUnavailable(reason: .modelDownloading(progress: 0.5))
        XCTAssertNotNil(downloadingError.recoverySuggestion)
        XCTAssertTrue(downloadingError.recoverySuggestion!.contains("Wait"))

        let notDownloadedError = AIError.providerUnavailable(reason: .modelNotDownloaded)
        XCTAssertNotNil(notDownloadedError.recoverySuggestion)
        XCTAssertTrue(notDownloadedError.recoverySuggestion!.contains("Download"))

        let noNetworkError = AIError.providerUnavailable(reason: .noNetwork)
        XCTAssertNotNil(noNetworkError.recoverySuggestion)
        XCTAssertTrue(noNetworkError.recoverySuggestion!.contains("internet"))

        let apiKeyError = AIError.providerUnavailable(reason: .apiKeyMissing)
        XCTAssertNotNil(apiKeyError.recoverySuggestion)
        XCTAssertTrue(apiKeyError.recoverySuggestion!.contains("API key"))

        let memoryError = AIError.providerUnavailable(
            reason: .insufficientMemory(required: .gigabytes(8), available: .gigabytes(4))
        )
        XCTAssertNotNil(memoryError.recoverySuggestion)
        XCTAssertTrue(memoryError.recoverySuggestion!.contains("memory"))

        let unknownError = AIError.providerUnavailable(reason: .unknown("Test"))
        XCTAssertNil(unknownError.recoverySuggestion)
    }

    // MARK: - Retryability Tests

    func testNetworkErrorIsRetryable() {
        let error = AIError.networkError(URLError(.timedOut))
        XCTAssertTrue(error.isRetryable)
    }

    func testRateLimitedIsRetryable() {
        let error = AIError.rateLimited(retryAfter: 60)
        XCTAssertTrue(error.isRetryable)
    }

    func testTimeoutIsRetryable() {
        let error = AIError.timeout(30)
        XCTAssertTrue(error.isRetryable)
    }

    func testServer500IsRetryable() {
        let error = AIError.serverError(statusCode: 500, message: nil)
        XCTAssertTrue(error.isRetryable)
    }

    func testServer503IsRetryable() {
        let error = AIError.serverError(statusCode: 503, message: nil)
        XCTAssertTrue(error.isRetryable)
    }

    func testServer400IsNotRetryable() {
        let error = AIError.serverError(statusCode: 400, message: nil)
        XCTAssertFalse(error.isRetryable)
    }

    func testServer404IsNotRetryable() {
        let error = AIError.serverError(statusCode: 404, message: nil)
        XCTAssertFalse(error.isRetryable)
    }

    func testCancelledIsNotRetryable() {
        let error = AIError.cancelled
        XCTAssertFalse(error.isRetryable)
    }

    func testInvalidInputIsNotRetryable() {
        let error = AIError.invalidInput("Bad input")
        XCTAssertFalse(error.isRetryable)
    }

    func testGenerationFailedIsRetryable() {
        let error = AIError.generationFailed(underlying: SendableError(NSError(domain: "", code: 0)))
        XCTAssertTrue(error.isRetryable)
    }

    func testDownloadFailedIsRetryable() {
        let error = AIError.downloadFailed(underlying: SendableError(NSError(domain: "", code: 0)))
        XCTAssertTrue(error.isRetryable)
    }

    func testProviderUnavailableRetryability() {
        let modelDownloadingError = AIError.providerUnavailable(reason: .modelDownloading(progress: 0.5))
        XCTAssertTrue(modelDownloadingError.isRetryable)

        let noNetworkError = AIError.providerUnavailable(reason: .noNetwork)
        XCTAssertTrue(noNetworkError.isRetryable)

        let deviceError = AIError.providerUnavailable(reason: .deviceNotSupported)
        XCTAssertFalse(deviceError.isRetryable)

        let osError = AIError.providerUnavailable(reason: .osVersionNotMet(required: "iOS 26"))
        XCTAssertFalse(osError.isRetryable)
    }

    func testModelNotFoundIsNotRetryable() {
        let error = AIError.modelNotFound(.llama3_2_1b)
        XCTAssertFalse(error.isRetryable)
    }

    func testContentFilteredIsNotRetryable() {
        let error = AIError.contentFiltered(reason: "Policy violation")
        XCTAssertFalse(error.isRetryable)
    }

    func testUnsupportedModelIsNotRetryable() {
        let error = AIError.unsupportedModel(variant: "Flux", reason: "Not available")
        XCTAssertFalse(error.isRetryable)
    }

    // MARK: - Error Category Tests

    func testErrorCategories() {
        XCTAssertEqual(AIError.providerUnavailable(reason: .deviceNotSupported).category, .provider)
        XCTAssertEqual(AIError.modelNotFound(.llama3_2_1b).category, .provider)
        XCTAssertEqual(AIError.modelNotCached(.llama3_2_1b).category, .provider)
        XCTAssertEqual(AIError.authenticationFailed("test").category, .provider)
        XCTAssertEqual(AIError.unsupportedModel(variant: "Flux", reason: "Not available").category, .provider)

        let generationError = AIError.generationFailed(underlying: SendableError(NSError(domain: "", code: 0)))
        XCTAssertEqual(generationError.category, .generation)
        XCTAssertEqual(AIError.tokenLimitExceeded(count: 5000, limit: 4096).category, .generation)
        XCTAssertEqual(AIError.contentFiltered(reason: nil).category, .generation)
        XCTAssertEqual(AIError.cancelled.category, .generation)
        XCTAssertEqual(AIError.timeout(30).category, .generation)

        XCTAssertEqual(AIError.networkError(URLError(.timedOut)).category, .network)
        XCTAssertEqual(AIError.serverError(statusCode: 500, message: nil).category, .network)
        XCTAssertEqual(AIError.rateLimited(retryAfter: nil).category, .network)

        let memoryError = AIError.insufficientMemory(required: .gigabytes(8), available: .gigabytes(4))
        XCTAssertEqual(memoryError.category, .resource)
        let downloadError = AIError.downloadFailed(underlying: SendableError(NSError(domain: "", code: 0)))
        XCTAssertEqual(downloadError.category, .resource)
        let fileError = AIError.fileError(underlying: SendableError(NSError(domain: "", code: 0)))
        XCTAssertEqual(fileError.category, .resource)

        XCTAssertEqual(AIError.invalidInput("test").category, .input)
        XCTAssertEqual(AIError.unsupportedAudioFormat("wav").category, .input)
        XCTAssertEqual(AIError.unsupportedLanguage("test").category, .input)
    }

    func testErrorCategoryDisplayNames() {
        XCTAssertEqual(AIError.ErrorCategory.provider.displayName, "Provider Error")
        XCTAssertEqual(AIError.ErrorCategory.generation.displayName, "Generation Error")
        XCTAssertEqual(AIError.ErrorCategory.network.displayName, "Network Error")
        XCTAssertEqual(AIError.ErrorCategory.resource.displayName, "Resource Error")
        XCTAssertEqual(AIError.ErrorCategory.input.displayName, "Input Error")
    }

    func testErrorCategoryAllCases() {
        let allCategories = AIError.ErrorCategory.allCases
        XCTAssertEqual(allCategories.count, 5)
        XCTAssertTrue(allCategories.contains(.provider))
        XCTAssertTrue(allCategories.contains(.generation))
        XCTAssertTrue(allCategories.contains(.network))
        XCTAssertTrue(allCategories.contains(.resource))
        XCTAssertTrue(allCategories.contains(.input))
    }

    // MARK: - Convenience Initializer Tests

    func testGenerationConvenienceInitializer() {
        let underlyingError = NSError(
            domain: "TestDomain",
            code: 42,
            userInfo: [NSLocalizedDescriptionKey: "Test error"]
        )
        let aiError = AIError.generation(underlyingError)

        if case .generationFailed(let wrapped) = aiError {
            XCTAssertTrue(wrapped.localizedDescription.contains("Test error"))
        } else {
            XCTFail("Expected generationFailed case")
        }
    }

    func testDownloadConvenienceInitializer() {
        let underlyingError = NSError(
            domain: "TestDomain",
            code: 42,
            userInfo: [NSLocalizedDescriptionKey: "Download error"]
        )
        let aiError = AIError.download(underlyingError)

        if case .downloadFailed(let wrapped) = aiError {
            XCTAssertTrue(wrapped.localizedDescription.contains("Download error"))
        } else {
            XCTFail("Expected downloadFailed case")
        }
    }

    func testFileConvenienceInitializer() {
        let underlyingError = NSError(
            domain: "TestDomain",
            code: 42,
            userInfo: [NSLocalizedDescriptionKey: "File error"]
        )
        let aiError = AIError.file(underlyingError)

        if case .fileError(let wrapped) = aiError {
            XCTAssertTrue(wrapped.localizedDescription.contains("File error"))
        } else {
            XCTFail("Expected fileError case")
        }
    }

    // MARK: - CustomStringConvertible Tests

    func testCustomStringConvertible() {
        let error = AIError.modelNotFound(.llama3_2_1b)
        XCTAssertFalse(error.description.isEmpty)
        XCTAssertEqual(error.description, error.errorDescription)
    }
}

// MARK: - SendableError Tests

final class SendableErrorTests: XCTestCase {

    func testInitFromError() {
        let original = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Original message"])
        let wrapped = SendableError(original)

        XCTAssertEqual(wrapped.localizedDescription, "Original message")
        XCTAssertFalse(wrapped.debugDescription.isEmpty)
    }

    func testInitWithDescriptions() {
        let error = SendableError(
            localizedDescription: "User message",
            debugDescription: "Debug message"
        )

        XCTAssertEqual(error.localizedDescription, "User message")
        XCTAssertEqual(error.debugDescription, "Debug message")
    }

    func testInitWithDefaultDebugDescription() {
        let error = SendableError(localizedDescription: "Test message")

        XCTAssertEqual(error.localizedDescription, "Test message")
        XCTAssertEqual(error.debugDescription, "Test message")
    }

    func testEquatable() {
        let error1 = SendableError(localizedDescription: "Test", debugDescription: "Debug")
        let error2 = SendableError(localizedDescription: "Test", debugDescription: "Debug")
        let error3 = SendableError(localizedDescription: "Different", debugDescription: "Debug")
        let error4 = SendableError(localizedDescription: "Test", debugDescription: "Different")

        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
        XCTAssertNotEqual(error1, error4)
    }

    func testHashable() {
        let error1 = SendableError(localizedDescription: "Test", debugDescription: "Debug")
        let error2 = SendableError(localizedDescription: "Test", debugDescription: "Debug")
        let error3 = SendableError(localizedDescription: "Different", debugDescription: "Debug")

        var set = Set<SendableError>()
        set.insert(error1)
        set.insert(error2)
        set.insert(error3)

        XCTAssertEqual(set.count, 2) // error1 and error2 are the same
    }

    func testCustomStringConvertible() {
        let error = SendableError(localizedDescription: "Test message", debugDescription: "Debug info")
        XCTAssertEqual(error.description, "Test message")
    }

    func testPreservesURLErrorDescription() {
        let urlError = URLError(.notConnectedToInternet)
        let wrapped = SendableError(urlError)

        XCTAssertFalse(wrapped.localizedDescription.isEmpty)
        XCTAssertFalse(wrapped.debugDescription.isEmpty)
    }
}

// MARK: - ModelSize Tests

final class ModelSizeTests: XCTestCase {

    func testApproximateRAM() {
        XCTAssertEqual(ModelSize.tiny.approximateRAM, .megabytes(512))
        XCTAssertEqual(ModelSize.small.approximateRAM, .gigabytes(2))
        XCTAssertEqual(ModelSize.medium.approximateRAM, .gigabytes(8))
        XCTAssertEqual(ModelSize.large.approximateRAM, .gigabytes(16))
        XCTAssertEqual(ModelSize.xlarge.approximateRAM, .gigabytes(32))
    }

    func testDisplayName() {
        XCTAssertTrue(ModelSize.tiny.displayName.contains("Tiny"))
        XCTAssertTrue(ModelSize.small.displayName.contains("Small"))
        XCTAssertTrue(ModelSize.medium.displayName.contains("Medium"))
        XCTAssertTrue(ModelSize.large.displayName.contains("Large"))
        XCTAssertTrue(ModelSize.xlarge.displayName.contains("Extra Large"))

        // Check that display names include RAM ranges
        XCTAssertTrue(ModelSize.tiny.displayName.contains("500MB"))
        XCTAssertTrue(ModelSize.small.displayName.contains("2GB"))
        XCTAssertTrue(ModelSize.medium.displayName.contains("8GB"))
        XCTAssertTrue(ModelSize.large.displayName.contains("32GB"))
    }

    func testMinimumRAMBytes() {
        XCTAssertEqual(ModelSize.tiny.minimumRAMBytes, 0)
        XCTAssertEqual(ModelSize.small.minimumRAMBytes, 500_000_000)
        XCTAssertEqual(ModelSize.medium.minimumRAMBytes, 2_000_000_000)
        XCTAssertEqual(ModelSize.large.minimumRAMBytes, 8_000_000_000)
        XCTAssertEqual(ModelSize.xlarge.minimumRAMBytes, 32_000_000_000)
    }

    func testForAvailableRAM() {
        // Test tiny recommendation (< 500MB usable)
        XCTAssertEqual(ModelSize.forAvailableRAM(400_000_000), .tiny)

        // Test small recommendation (500MB - 2GB usable)
        XCTAssertEqual(ModelSize.forAvailableRAM(1_000_000_000), .small)

        // Test medium recommendation (2GB - 8GB usable)
        XCTAssertEqual(ModelSize.forAvailableRAM(4_000_000_000), .medium)

        // Test large recommendation (8GB - 32GB usable)
        XCTAssertEqual(ModelSize.forAvailableRAM(16_000_000_000), .large)

        // Test xlarge recommendation (> 32GB usable)
        XCTAssertEqual(ModelSize.forAvailableRAM(64_000_000_000), .xlarge)
    }

    func testForAvailableRAMWith80PercentHeadroom() {
        // 10GB total = 8GB usable (80%) = should recommend large
        XCTAssertEqual(ModelSize.forAvailableRAM(10_000_000_000), .large)

        // 3GB total = 2.4GB usable (80%) = should recommend medium
        XCTAssertEqual(ModelSize.forAvailableRAM(3_000_000_000), .medium)
    }

    func testComparable() {
        XCTAssertLessThan(ModelSize.tiny, ModelSize.small)
        XCTAssertLessThan(ModelSize.small, ModelSize.medium)
        XCTAssertLessThan(ModelSize.medium, ModelSize.large)
        XCTAssertLessThan(ModelSize.large, ModelSize.xlarge)

        XCTAssertGreaterThan(ModelSize.xlarge, ModelSize.tiny)
        XCTAssertGreaterThan(ModelSize.large, ModelSize.medium)
    }

    func testSorting() {
        let sizes: [ModelSize] = [.xlarge, .tiny, .large, .small, .medium]
        let sorted = sizes.sorted()

        XCTAssertEqual(sorted, [.tiny, .small, .medium, .large, .xlarge])
    }

    func testCaseIterable() {
        let allCases = ModelSize.allCases
        XCTAssertEqual(allCases.count, 5)
        XCTAssertTrue(allCases.contains(.tiny))
        XCTAssertTrue(allCases.contains(.small))
        XCTAssertTrue(allCases.contains(.medium))
        XCTAssertTrue(allCases.contains(.large))
        XCTAssertTrue(allCases.contains(.xlarge))
    }

    func testCustomStringConvertible() {
        XCTAssertEqual(ModelSize.tiny.description, ModelSize.tiny.displayName)
        XCTAssertEqual(ModelSize.small.description, ModelSize.small.displayName)
        XCTAssertFalse(ModelSize.medium.description.isEmpty)
    }

    func testCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for size in ModelSize.allCases {
            let encoded = try encoder.encode(size)
            let decoded = try decoder.decode(ModelSize.self, from: encoded)
            XCTAssertEqual(size, decoded)
        }
    }
}

// MARK: - DeviceCapabilities Tests

final class DeviceCapabilitiesTests: XCTestCase {

    func testInitialization() {
        let capabilities = DeviceCapabilities(
            totalRAM: 16_000_000_000,
            availableRAM: 8_000_000_000,
            chipType: "Apple M2",
            neuralEngineCores: 16,
            supportsMLX: true,
            supportsFoundationModels: false
        )

        XCTAssertEqual(capabilities.totalRAM, 16_000_000_000)
        XCTAssertEqual(capabilities.availableRAM, 8_000_000_000)
        XCTAssertEqual(capabilities.chipType, "Apple M2")
        XCTAssertEqual(capabilities.neuralEngineCores, 16)
        XCTAssertTrue(capabilities.supportsMLX)
        XCTAssertFalse(capabilities.supportsFoundationModels)
    }

    func testCurrentReturnsValidData() {
        let capabilities = DeviceCapabilities.current()

        XCTAssertGreaterThan(capabilities.totalRAM, 0)
        XCTAssertGreaterThanOrEqual(capabilities.availableRAM, 0)
        XCTAssertLessThanOrEqual(capabilities.availableRAM, capabilities.totalRAM)
    }

    func testRecommendedModelSize() {
        let capabilities = DeviceCapabilities(
            totalRAM: 16_000_000_000,
            availableRAM: 8_000_000_000,
            supportsMLX: true,
            supportsFoundationModels: false
        )

        let recommended = capabilities.recommendedModelSize()

        // Should return a valid ModelSize
        XCTAssertTrue(ModelSize.allCases.contains(recommended))

        // With 8GB available: 8GB * 0.8 = 6.4GB usable
        // 6.4GB >= 2GB threshold → .medium
        // (Large requires 8GB+ after headroom)
        XCTAssertEqual(recommended, .medium)
    }

    func testCanRunModel() {
        let capabilities = DeviceCapabilities(
            totalRAM: 8_000_000_000,
            availableRAM: 4_000_000_000,
            supportsMLX: true,
            supportsFoundationModels: false
        )

        XCTAssertTrue(capabilities.canRunModel(ofSize: .tiny))
        XCTAssertTrue(capabilities.canRunModel(ofSize: .small))
        XCTAssertTrue(capabilities.canRunModel(ofSize: .medium))
        XCTAssertFalse(capabilities.canRunModel(ofSize: .large))
        XCTAssertFalse(capabilities.canRunModel(ofSize: .xlarge))
    }

    func testFormattedRAM() {
        let capabilities = DeviceCapabilities.current()

        XCTAssertFalse(capabilities.formattedTotalRAM.isEmpty)
        XCTAssertFalse(capabilities.formattedAvailableRAM.isEmpty)

        // Should contain "GB" or "MB"
        let totalFormatted = capabilities.formattedTotalRAM
        XCTAssertTrue(totalFormatted.contains("GB") || totalFormatted.contains("MB"))
    }

    #if arch(arm64)
    func testAppleSiliconDetection() {
        let capabilities = DeviceCapabilities.current()
        XCTAssertTrue(capabilities.supportsMLX, "Apple Silicon devices should support MLX")
    }
    #else
    func testNonAppleSiliconDetection() {
        let capabilities = DeviceCapabilities.current()
        XCTAssertFalse(capabilities.supportsMLX, "Non-Apple Silicon devices should not support MLX")
    }
    #endif

    func testHashable() {
        let cap1 = DeviceCapabilities(
            totalRAM: 16_000_000_000,
            availableRAM: 8_000_000_000,
            supportsMLX: true,
            supportsFoundationModels: false
        )

        let cap2 = DeviceCapabilities(
            totalRAM: 16_000_000_000,
            availableRAM: 8_000_000_000,
            supportsMLX: true,
            supportsFoundationModels: false
        )

        let cap3 = DeviceCapabilities(
            totalRAM: 8_000_000_000,
            availableRAM: 4_000_000_000,
            supportsMLX: false,
            supportsFoundationModels: false
        )

        XCTAssertEqual(cap1, cap2)
        XCTAssertNotEqual(cap1, cap3)

        var set = Set<DeviceCapabilities>()
        set.insert(cap1)
        set.insert(cap2)
        set.insert(cap3)

        XCTAssertEqual(set.count, 2) // cap1 and cap2 are the same
    }

    func testCustomStringConvertible() {
        let capabilities = DeviceCapabilities(
            totalRAM: 16_000_000_000,
            availableRAM: 8_000_000_000,
            chipType: "Apple M2",
            neuralEngineCores: 16,
            supportsMLX: true,
            supportsFoundationModels: false
        )

        let description = capabilities.description
        XCTAssertFalse(description.isEmpty)
        XCTAssertTrue(description.contains("RAM"))
        XCTAssertTrue(description.contains("Apple M2"))
        XCTAssertTrue(description.contains("16"))
        XCTAssertTrue(description.contains("MLX"))
    }
}

// MARK: - ByteCount Tests

final class ByteCountTests: XCTestCase {

    func testInitialization() {
        let count = ByteCount(1_000_000_000)
        XCTAssertEqual(count.bytes, 1_000_000_000)
    }

    func testMegabytesFactory() {
        let count = ByteCount.megabytes(100)
        XCTAssertEqual(count.bytes, 100_000_000)
    }

    func testGigabytesFactory() {
        let count = ByteCount.gigabytes(4)
        XCTAssertEqual(count.bytes, 4_000_000_000)
    }

    func testFormatted() {
        let count = ByteCount.gigabytes(4)
        let formatted = count.formatted

        XCTAssertFalse(formatted.isEmpty)
        // Should contain "GB" or "4"
        XCTAssertTrue(formatted.contains("GB") || formatted.contains("4"))
    }

    func testFormattedMegabytes() {
        let count = ByteCount.megabytes(500)
        let formatted = count.formatted

        XCTAssertFalse(formatted.isEmpty)
        XCTAssertTrue(formatted.contains("MB") || formatted.contains("500"))
    }

    func testComparable() {
        let smaller = ByteCount.megabytes(500)
        let larger = ByteCount.gigabytes(2)

        XCTAssertLessThan(smaller, larger)
        XCTAssertGreaterThan(larger, smaller)
    }

    func testEquatable() {
        let megabytes1000 = ByteCount.megabytes(1000)
        let bytes1Billion = ByteCount(1_000_000_000)
        let gigabytes2 = ByteCount.gigabytes(2)

        XCTAssertEqual(megabytes1000, bytes1Billion)
        XCTAssertNotEqual(megabytes1000, gigabytes2)
    }

    func testHashable() {
        let count1 = ByteCount.gigabytes(4)
        let count2 = ByteCount(4_000_000_000)
        let count3 = ByteCount.gigabytes(8)

        var set = Set<ByteCount>()
        set.insert(count1)
        set.insert(count2)
        set.insert(count3)

        XCTAssertEqual(set.count, 2) // count1 and count2 are the same
    }

    func testSorting() {
        let counts = [
            ByteCount.gigabytes(8),
            ByteCount.megabytes(500),
            ByteCount.gigabytes(2),
            ByteCount.megabytes(100)
        ]

        let sorted = counts.sorted()

        XCTAssertEqual(sorted[0], ByteCount.megabytes(100))
        XCTAssertEqual(sorted[1], ByteCount.megabytes(500))
        XCTAssertEqual(sorted[2], ByteCount.gigabytes(2))
        XCTAssertEqual(sorted[3], ByteCount.gigabytes(8))
    }
}
