// RetryConfigurationTests.swift
// Conduit Tests
//
// Tests for RetryConfiguration, RetryStrategy, and RetryableErrorType.

#if CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
import Foundation
import Testing
@testable import Conduit

// MARK: - RetryConfiguration Tests

@Suite("RetryConfiguration Tests")
struct RetryConfigurationTests {

    // MARK: - Static Presets

    @Test("Default preset has expected values")
    func defaultPreset() {
        let config = RetryConfiguration.default
        #expect(config.maxRetries == 3)
        #expect(config.baseDelay == 1.0)
        #expect(config.maxDelay == 30.0)
        #expect(config.retryableStatusCodes == [408, 429, 500, 502, 503, 504])
        #expect(config.retryableErrors == [.timeout, .connectionLost, .serverError, .rateLimited])
    }

    @Test("Aggressive preset has expected values")
    func aggressivePreset() {
        let config = RetryConfiguration.aggressive
        #expect(config.maxRetries == 5)
        #expect(config.baseDelay == 0.5)
        #expect(config.maxDelay == 15.0)
        #expect(config.strategy == .exponentialWithJitter())
    }

    @Test("Conservative preset has expected values")
    func conservativePreset() {
        let config = RetryConfiguration.conservative
        #expect(config.maxRetries == 2)
        #expect(config.baseDelay == 2.0)
        #expect(config.maxDelay == 60.0)
        #expect(config.strategy == .exponentialBackoff())
    }

    @Test("None preset disables retries")
    func nonePreset() {
        let config = RetryConfiguration.none
        #expect(config.maxRetries == 0)
    }

    // MARK: - Init Clamping

    @Test("Negative maxRetries is clamped to zero")
    func negativeMaxRetriesClamped() {
        let config = RetryConfiguration(maxRetries: -5)
        #expect(config.maxRetries == 0)
    }

    @Test("Negative baseDelay is clamped to zero")
    func negativeBaseDelayClamped() {
        let config = RetryConfiguration(baseDelay: -2.0)
        #expect(config.baseDelay == 0.0)
    }

    @Test("maxDelay is clamped to at least baseDelay")
    func maxDelayClampedToBaseDelay() {
        let config = RetryConfiguration(baseDelay: 10.0, maxDelay: 5.0)
        #expect(config.maxDelay == 10.0)
    }

    // MARK: - Delay Calculation

    @Test("Delay for attempt 0 is always zero")
    func delayForAttemptZero() {
        let config = RetryConfiguration.default
        #expect(config.delay(forAttempt: 0) == 0)
    }

    @Test("Delay is capped at maxDelay")
    func delayCappedAtMaxDelay() {
        let config = RetryConfiguration(
            maxRetries: 10,
            baseDelay: 1.0,
            maxDelay: 5.0,
            strategy: .exponentialBackoff(multiplier: 10.0)
        )
        let delay = config.delay(forAttempt: 5)
        #expect(delay <= 5.0)
    }

    @Test("Immediate strategy returns zero delay for all attempts")
    func immediateStrategyZeroDelay() {
        let config = RetryConfiguration(strategy: .immediate)
        for attempt in 0...5 {
            #expect(config.delay(forAttempt: attempt) == 0)
        }
    }

    @Test("Fixed strategy returns constant delay")
    func fixedStrategyConstantDelay() {
        let config = RetryConfiguration(strategy: .fixed(delay: 2.5), maxDelay: 100.0)
        #expect(config.delay(forAttempt: 1) == 2.5)
        #expect(config.delay(forAttempt: 2) == 2.5)
        #expect(config.delay(forAttempt: 5) == 2.5)
    }

    @Test("Exponential backoff doubles delay each attempt")
    func exponentialBackoffDoublesDelay() {
        let config = RetryConfiguration(
            baseDelay: 1.0,
            maxDelay: 1000.0,
            strategy: .exponentialBackoff(multiplier: 2.0)
        )
        #expect(config.delay(forAttempt: 1) == 1.0)   // 1.0 * 2^0 = 1.0
        #expect(config.delay(forAttempt: 2) == 2.0)   // 1.0 * 2^1 = 2.0
        #expect(config.delay(forAttempt: 3) == 4.0)   // 1.0 * 2^2 = 4.0
        #expect(config.delay(forAttempt: 4) == 8.0)   // 1.0 * 2^3 = 8.0
    }

    @Test("Exponential with jitter returns non-negative delay close to base exponential")
    func exponentialWithJitterReturnsNonNegative() {
        let config = RetryConfiguration(
            baseDelay: 1.0,
            maxDelay: 1000.0,
            strategy: .exponentialWithJitter(multiplier: 2.0, jitterFactor: 0.1)
        )
        for _ in 0..<20 {
            let delay = config.delay(forAttempt: 1)
            #expect(delay >= 0)
            // With jitterFactor 0.1, delay for attempt 1 should be baseDelay +/- 10%
            #expect(delay >= 0.9)
            #expect(delay <= 1.1)
        }
    }

    // MARK: - shouldRetry(statusCode:)

    @Test("Default config retries 429 status code")
    func shouldRetry429() {
        let config = RetryConfiguration.default
        #expect(config.shouldRetry(statusCode: 429))
    }

    @Test("Default config retries 500 status code")
    func shouldRetry500() {
        let config = RetryConfiguration.default
        #expect(config.shouldRetry(statusCode: 500))
    }

    @Test("Default config retries 502 status code")
    func shouldRetry502() {
        let config = RetryConfiguration.default
        #expect(config.shouldRetry(statusCode: 502))
    }

    @Test("Default config retries 503 status code")
    func shouldRetry503() {
        let config = RetryConfiguration.default
        #expect(config.shouldRetry(statusCode: 503))
    }

    @Test("Default config retries 504 status code")
    func shouldRetry504() {
        let config = RetryConfiguration.default
        #expect(config.shouldRetry(statusCode: 504))
    }

    @Test("Default config retries 408 status code")
    func shouldRetry408() {
        let config = RetryConfiguration.default
        #expect(config.shouldRetry(statusCode: 408))
    }

    @Test("Default config does not retry 200")
    func shouldNotRetry200() {
        let config = RetryConfiguration.default
        #expect(!config.shouldRetry(statusCode: 200))
    }

    @Test("Default config does not retry 401")
    func shouldNotRetry401() {
        let config = RetryConfiguration.default
        #expect(!config.shouldRetry(statusCode: 401))
    }

    @Test("Default config does not retry 403")
    func shouldNotRetry403() {
        let config = RetryConfiguration.default
        #expect(!config.shouldRetry(statusCode: 403))
    }

    @Test("Default config does not retry 404")
    func shouldNotRetry404() {
        let config = RetryConfiguration.default
        #expect(!config.shouldRetry(statusCode: 404))
    }

    // MARK: - shouldRetry(errorType:)

    @Test("Default config retries timeout errors")
    func shouldRetryTimeout() {
        let config = RetryConfiguration.default
        #expect(config.shouldRetry(errorType: .timeout))
    }

    @Test("Default config retries connectionLost errors")
    func shouldRetryConnectionLost() {
        let config = RetryConfiguration.default
        #expect(config.shouldRetry(errorType: .connectionLost))
    }

    @Test("Default config retries serverError errors")
    func shouldRetryServerError() {
        let config = RetryConfiguration.default
        #expect(config.shouldRetry(errorType: .serverError))
    }

    @Test("Default config retries rateLimited errors")
    func shouldRetryRateLimited() {
        let config = RetryConfiguration.default
        #expect(config.shouldRetry(errorType: .rateLimited))
    }

    @Test("Default config does not retry dnsFailure errors")
    func shouldNotRetryDnsFailure() {
        let config = RetryConfiguration.default
        #expect(!config.shouldRetry(errorType: .dnsFailure))
    }

    @Test("Default config does not retry sslError errors")
    func shouldNotRetrySslError() {
        let config = RetryConfiguration.default
        #expect(!config.shouldRetry(errorType: .sslError))
    }

    // MARK: - Fluent API

    @Test("Fluent maxRetries returns updated copy")
    func fluentMaxRetries() {
        let config = RetryConfiguration.default.maxRetries(7)
        #expect(config.maxRetries == 7)
        #expect(RetryConfiguration.default.maxRetries == 3)
    }

    @Test("Fluent maxRetries clamps negative to zero")
    func fluentMaxRetriesClamps() {
        let config = RetryConfiguration.default.maxRetries(-1)
        #expect(config.maxRetries == 0)
    }

    @Test("Fluent baseDelay returns updated copy")
    func fluentBaseDelay() {
        let config = RetryConfiguration.default.baseDelay(5.0)
        #expect(config.baseDelay == 5.0)
    }

    @Test("Fluent baseDelay clamps negative to zero")
    func fluentBaseDelayClampsNegative() {
        let config = RetryConfiguration.default.baseDelay(-1.0)
        #expect(config.baseDelay == 0.0)
    }

    @Test("Fluent maxDelay returns updated copy and clamps to baseDelay")
    func fluentMaxDelay() {
        let config = RetryConfiguration.default.baseDelay(10.0).maxDelay(5.0)
        #expect(config.maxDelay == 10.0)
    }

    @Test("Fluent strategy returns updated copy")
    func fluentStrategy() {
        let config = RetryConfiguration.default.strategy(.immediate)
        #expect(config.strategy == .immediate)
    }

    @Test("Fluent retryableStatusCodes returns updated copy")
    func fluentRetryableStatusCodes() {
        let codes: Set<Int> = [500]
        let config = RetryConfiguration.default.retryableStatusCodes(codes)
        #expect(config.retryableStatusCodes == [500])
    }

    @Test("Fluent retryableErrors returns updated copy")
    func fluentRetryableErrors() {
        let errors: Set<RetryableErrorType> = [.timeout]
        let config = RetryConfiguration.default.retryableErrors(errors)
        #expect(config.retryableErrors == [.timeout])
    }

    @Test("Fluent disabled sets maxRetries to zero")
    func fluentDisabled() {
        let config = RetryConfiguration.aggressive.disabled()
        #expect(config.maxRetries == 0)
    }

    // MARK: - Codable

    @Test("RetryConfiguration round-trips through JSON encoding and decoding")
    func retryConfigurationCodableRoundTrip() throws {
        let original = RetryConfiguration(
            maxRetries: 4,
            baseDelay: 2.0,
            maxDelay: 20.0,
            strategy: .fixed(delay: 3.0),
            retryableStatusCodes: [429, 503],
            retryableErrors: [.timeout, .rateLimited]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RetryConfiguration.self, from: data)

        #expect(decoded.maxRetries == original.maxRetries)
        #expect(decoded.baseDelay == original.baseDelay)
        #expect(decoded.maxDelay == original.maxDelay)
        #expect(decoded.strategy == original.strategy)
        #expect(decoded.retryableStatusCodes == original.retryableStatusCodes)
        #expect(decoded.retryableErrors == original.retryableErrors)
    }

    @Test("RetryConfiguration default preset round-trips through JSON")
    func defaultPresetCodableRoundTrip() throws {
        let original = RetryConfiguration.default
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RetryConfiguration.self, from: data)
        #expect(decoded == original)
    }

    @Test("RetryConfiguration aggressive preset round-trips through JSON")
    func aggressivePresetCodableRoundTrip() throws {
        let original = RetryConfiguration.aggressive
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RetryConfiguration.self, from: data)
        #expect(decoded == original)
    }

    @Test("RetryConfiguration none preset round-trips through JSON")
    func nonePresetCodableRoundTrip() throws {
        let original = RetryConfiguration.none
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RetryConfiguration.self, from: data)
        #expect(decoded == original)
    }

    // MARK: - Hashable / Equatable

    @Test("Equal configurations are equal")
    func equalConfigurationsAreEqual() {
        let a = RetryConfiguration.default
        let b = RetryConfiguration.default
        #expect(a == b)
    }

    @Test("Different configurations are not equal")
    func differentConfigurationsAreNotEqual() {
        let a = RetryConfiguration.default
        let b = RetryConfiguration.aggressive
        #expect(a != b)
    }

    @Test("Sendable conformance compiles")
    func sendableConformance() {
        let config: Sendable = RetryConfiguration.default
        #expect(config is RetryConfiguration)
    }
}

// MARK: - RetryStrategy Tests

@Suite("RetryStrategy Tests")
struct RetryStrategyTests {

    @Test("Immediate strategy always returns 0")
    func immediateAlwaysZero() {
        let strategy = RetryStrategy.immediate
        #expect(strategy.delay(forAttempt: 1, baseDelay: 5.0) == 0)
        #expect(strategy.delay(forAttempt: 10, baseDelay: 5.0) == 0)
    }

    @Test("Fixed strategy returns constant value regardless of attempt")
    func fixedReturnsConstant() {
        let strategy = RetryStrategy.fixed(delay: 3.5)
        #expect(strategy.delay(forAttempt: 1, baseDelay: 1.0) == 3.5)
        #expect(strategy.delay(forAttempt: 5, baseDelay: 1.0) == 3.5)
    }

    @Test("Exponential backoff with multiplier 2 doubles per attempt")
    func exponentialBackoffMultiplier2() {
        let strategy = RetryStrategy.exponentialBackoff(multiplier: 2.0)
        #expect(strategy.delay(forAttempt: 1, baseDelay: 1.0) == 1.0)
        #expect(strategy.delay(forAttempt: 2, baseDelay: 1.0) == 2.0)
        #expect(strategy.delay(forAttempt: 3, baseDelay: 1.0) == 4.0)
    }

    @Test("Exponential backoff with multiplier 3 triples per attempt")
    func exponentialBackoffMultiplier3() {
        let strategy = RetryStrategy.exponentialBackoff(multiplier: 3.0)
        #expect(strategy.delay(forAttempt: 1, baseDelay: 1.0) == 1.0)
        #expect(strategy.delay(forAttempt: 2, baseDelay: 1.0) == 3.0)
        #expect(strategy.delay(forAttempt: 3, baseDelay: 1.0) == 9.0)
    }

    @Test("Exponential with jitter returns non-negative values")
    func exponentialWithJitterNonNegative() {
        let strategy = RetryStrategy.exponentialWithJitter(multiplier: 2.0, jitterFactor: 0.5)
        for _ in 0..<50 {
            let delay = strategy.delay(forAttempt: 1, baseDelay: 1.0)
            #expect(delay >= 0)
        }
    }

    @Test("Strategies with different cases are not equal")
    func differentStrategiesNotEqual() {
        #expect(RetryStrategy.immediate != RetryStrategy.fixed(delay: 0))
        #expect(RetryStrategy.exponentialBackoff() != RetryStrategy.exponentialWithJitter())
    }

    @Test("RetryStrategy Codable round-trip for each case")
    func strategyCodableRoundTrip() throws {
        let strategies: [RetryStrategy] = [
            .immediate,
            .fixed(delay: 2.5),
            .exponentialBackoff(multiplier: 3.0),
            .exponentialWithJitter(multiplier: 2.0, jitterFactor: 0.2)
        ]

        for original in strategies {
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(RetryStrategy.self, from: data)
            #expect(decoded == original)
        }
    }
}

// MARK: - RetryableErrorType Tests

@Suite("RetryableErrorType Tests")
struct RetryableErrorTypeTests {

    @Test("CaseIterable includes all cases")
    func caseIterableIncludesAllCases() {
        let allCases = RetryableErrorType.allCases
        #expect(allCases.contains(.timeout))
        #expect(allCases.contains(.connectionLost))
        #expect(allCases.contains(.serverError))
        #expect(allCases.contains(.rateLimited))
        #expect(allCases.contains(.dnsFailure))
        #expect(allCases.contains(.sslError))
        #expect(allCases.count == 6)
    }

    @Test("URLError.timedOut maps to .timeout")
    func timedOutMapsToTimeout() {
        let urlError = URLError(.timedOut)
        #expect(RetryableErrorType.from(urlError) == .timeout)
    }

    @Test("URLError.networkConnectionLost maps to .connectionLost")
    func networkConnectionLostMaps() {
        let urlError = URLError(.networkConnectionLost)
        #expect(RetryableErrorType.from(urlError) == .connectionLost)
    }

    @Test("URLError.notConnectedToInternet maps to .connectionLost")
    func notConnectedToInternetMaps() {
        let urlError = URLError(.notConnectedToInternet)
        #expect(RetryableErrorType.from(urlError) == .connectionLost)
    }

    @Test("URLError.dnsLookupFailed maps to .dnsFailure")
    func dnsLookupFailedMaps() {
        let urlError = URLError(.dnsLookupFailed)
        #expect(RetryableErrorType.from(urlError) == .dnsFailure)
    }

    @Test("URLError.cannotFindHost maps to .dnsFailure")
    func cannotFindHostMaps() {
        let urlError = URLError(.cannotFindHost)
        #expect(RetryableErrorType.from(urlError) == .dnsFailure)
    }

    @Test("URLError.secureConnectionFailed maps to .sslError")
    func secureConnectionFailedMaps() {
        let urlError = URLError(.secureConnectionFailed)
        #expect(RetryableErrorType.from(urlError) == .sslError)
    }

    @Test("SSL certificate errors are not retryable")
    func sslCertificateErrorsNotRetryable() {
        let untrusted = URLError(.serverCertificateUntrusted)
        #expect(RetryableErrorType.from(untrusted) == nil)

        let badDate = URLError(.serverCertificateHasBadDate)
        #expect(RetryableErrorType.from(badDate) == nil)

        let notYetValid = URLError(.serverCertificateNotYetValid)
        #expect(RetryableErrorType.from(notYetValid) == nil)

        let unknownRoot = URLError(.serverCertificateHasUnknownRoot)
        #expect(RetryableErrorType.from(unknownRoot) == nil)

        let clientRejected = URLError(.clientCertificateRejected)
        #expect(RetryableErrorType.from(clientRejected) == nil)

        let clientRequired = URLError(.clientCertificateRequired)
        #expect(RetryableErrorType.from(clientRequired) == nil)
    }

    @Test("Unrecognized URLError returns nil")
    func unrecognizedURLErrorReturnsNil() {
        let urlError = URLError(.cancelled)
        #expect(RetryableErrorType.from(urlError) == nil)
    }

    @Test("RetryableErrorType raw values are stable strings")
    func rawValuesAreStableStrings() {
        #expect(RetryableErrorType.timeout.rawValue == "timeout")
        #expect(RetryableErrorType.connectionLost.rawValue == "connectionLost")
        #expect(RetryableErrorType.serverError.rawValue == "serverError")
        #expect(RetryableErrorType.rateLimited.rawValue == "rateLimited")
        #expect(RetryableErrorType.dnsFailure.rawValue == "dnsFailure")
        #expect(RetryableErrorType.sslError.rawValue == "sslError")
    }

    @Test("RetryableErrorType Codable round-trip")
    func codableRoundTrip() throws {
        for errorType in RetryableErrorType.allCases {
            let data = try JSONEncoder().encode(errorType)
            let decoded = try JSONDecoder().decode(RetryableErrorType.self, from: data)
            #expect(decoded == errorType)
        }
    }
}

#endif // CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
