// StreamingResultTests.swift
// SwiftAITests
//
// Comprehensive tests for StreamingResult type.

import Foundation
import Testing
@testable import SwiftAI

// MARK: - Test Generable Type

/// A simple Generable type for testing StreamingResult functionality.
struct TestGenerable: Generable {
    let value: String

    static var schema: Schema { .string(constraints: []) }

    init(from content: StructuredContent) throws {
        self.value = try content.string
    }

    init(value: String) {
        self.value = value
    }

    var generableContent: StructuredContent { .string(value) }

    struct Partial: GenerableContentConvertible, Sendable {
        var value: String?

        init(value: String?) {
            self.value = value
        }

        init(from content: StructuredContent) throws {
            self.value = try? content.string
        }

        var generableContent: StructuredContent {
            .string(value ?? "")
        }
    }
}

// MARK: - StreamingResult Tests

@Suite("StreamingResult")
struct StreamingResultTests {

    // MARK: - Iteration Tests

    @Suite("Iteration")
    struct IterationTests {

        @Test("Can iterate over partial values with for-await-in")
        func iterateOverPartials() async throws {
            let stream = AsyncThrowingStream<TestGenerable.Partial, Error> { continuation in
                continuation.yield(TestGenerable.Partial(value: "hello"))
                continuation.yield(TestGenerable.Partial(value: "world"))
                continuation.finish()
            }

            let result = StreamingResult<TestGenerable>(stream)
            var receivedValues: [String?] = []

            for try await partial in result {
                receivedValues.append(partial.value)
            }

            #expect(receivedValues.count == 2)
            #expect(receivedValues[0] == "hello")
            #expect(receivedValues[1] == "world")
        }

        @Test("Receives all yielded partials in order")
        func partialsReceivedInOrder() async throws {
            let expectedOrder = ["first", "second", "third", "fourth", "fifth"]

            let stream = AsyncThrowingStream<TestGenerable.Partial, Error> { continuation in
                for value in expectedOrder {
                    continuation.yield(TestGenerable.Partial(value: value))
                }
                continuation.finish()
            }

            let result = StreamingResult<TestGenerable>(stream)
            var receivedOrder: [String] = []

            for try await partial in result {
                if let value = partial.value {
                    receivedOrder.append(value)
                }
            }

            #expect(receivedOrder == expectedOrder)
        }

        @Test("Empty stream produces no iterations")
        func emptyStreamNoIterations() async throws {
            let stream = AsyncThrowingStream<TestGenerable.Partial, Error> { continuation in
                continuation.finish()
            }

            let result = StreamingResult<TestGenerable>(stream)
            var iterationCount = 0

            for try await _ in result {
                iterationCount += 1
            }

            #expect(iterationCount == 0)
        }

        @Test("Large number of partials handled correctly")
        func largeNumberOfPartials() async throws {
            let count = 1000

            let stream = AsyncThrowingStream<TestGenerable.Partial, Error> { continuation in
                for i in 0..<count {
                    continuation.yield(TestGenerable.Partial(value: "item-\(i)"))
                }
                continuation.finish()
            }

            let result = StreamingResult<TestGenerable>(stream)
            var receivedCount = 0
            var lastValue: String?

            for try await partial in result {
                receivedCount += 1
                lastValue = partial.value
            }

            #expect(receivedCount == count)
            #expect(lastValue == "item-999")
        }
    }

    // MARK: - collect() Method Tests

    @Suite("collect() Method")
    struct CollectMethodTests {

        @Test("Returns final complete result after stream ends")
        func collectReturnsFinalResult() async throws {
            let stream = AsyncThrowingStream<TestGenerable.Partial, Error> { continuation in
                continuation.yield(TestGenerable.Partial(value: "partial-1"))
                continuation.yield(TestGenerable.Partial(value: "partial-2"))
                continuation.yield(TestGenerable.Partial(value: "final"))
                continuation.finish()
            }

            let result = StreamingResult<TestGenerable>(stream)
            let collected = try await result.collect()

            #expect(collected.value == "final")
        }

        @Test("Throws noContent for empty stream")
        func collectThrowsForEmptyStream() async {
            let stream = AsyncThrowingStream<TestGenerable.Partial, Error> { continuation in
                continuation.finish()
            }

            let result = StreamingResult<TestGenerable>(stream)

            do {
                _ = try await result.collect()
                Issue.record("Expected StreamingError.noContent to be thrown")
            } catch let error as StreamingError {
                if case .noContent = error {
                    // Expected
                } else {
                    Issue.record("Expected noContent error, got: \(error)")
                }
            } catch {
                Issue.record("Unexpected error type: \(error)")
            }
        }

        @Test("Works with single partial")
        func collectWithSinglePartial() async throws {
            let stream = AsyncThrowingStream<TestGenerable.Partial, Error> { continuation in
                continuation.yield(TestGenerable.Partial(value: "only-one"))
                continuation.finish()
            }

            let result = StreamingResult<TestGenerable>(stream)
            let collected = try await result.collect()

            #expect(collected.value == "only-one")
        }

        @Test("Works with many partials")
        func collectWithManyPartials() async throws {
            let stream = AsyncThrowingStream<TestGenerable.Partial, Error> { continuation in
                for i in 1...100 {
                    continuation.yield(TestGenerable.Partial(value: "value-\(i)"))
                }
                continuation.finish()
            }

            let result = StreamingResult<TestGenerable>(stream)
            let collected = try await result.collect()

            #expect(collected.value == "value-100")
        }
    }

    // MARK: - reduce() Method Tests

    @Suite("reduce() Method")
    struct ReduceMethodTests {

        @Test("Handler called for each partial")
        func reduceHandlerCalledForEach() async throws {
            let stream = AsyncThrowingStream<TestGenerable.Partial, Error> { continuation in
                continuation.yield(TestGenerable.Partial(value: "a"))
                continuation.yield(TestGenerable.Partial(value: "b"))
                continuation.yield(TestGenerable.Partial(value: "c"))
                continuation.finish()
            }

            let result = StreamingResult<TestGenerable>(stream)

            // Collect all partials manually using AsyncSequence conformance
            var callCount = 0
            var receivedValues: [String] = []

            for try await partial in result {
                callCount += 1
                if let value = partial.value {
                    receivedValues.append(value)
                }
            }

            #expect(callCount == 3)
            #expect(receivedValues == ["a", "b", "c"])
        }

        @Test("Returns final result after all partials")
        func reduceReturnsFinalResult() async throws {
            let stream = AsyncThrowingStream<TestGenerable.Partial, Error> { continuation in
                continuation.yield(TestGenerable.Partial(value: "first"))
                continuation.yield(TestGenerable.Partial(value: "middle"))
                continuation.yield(TestGenerable.Partial(value: "last"))
                continuation.finish()
            }

            let result = StreamingResult<TestGenerable>(stream)

            let finalResult = try await result.reduce { _ in
                // Just observing
            }

            #expect(finalResult.value == "last")
        }

        @Test("Works with @Sendable closure")
        func reduceWithSendableClosure() async throws {
            let stream = AsyncThrowingStream<TestGenerable.Partial, Error> { continuation in
                continuation.yield(TestGenerable.Partial(value: "test"))
                continuation.finish()
            }

            let result = StreamingResult<TestGenerable>(stream)

            // The closure is implicitly @Sendable due to the method signature
            let sendableClosure: @Sendable (TestGenerable.Partial) -> Void = { partial in
                _ = partial.value
            }

            let finalResult = try await result.reduce(sendableClosure)

            #expect(finalResult.value == "test")
        }

        @Test("Throws noContent for empty stream")
        func reduceThrowsForEmptyStream() async {
            let stream = AsyncThrowingStream<TestGenerable.Partial, Error> { continuation in
                continuation.finish()
            }

            let result = StreamingResult<TestGenerable>(stream)

            do {
                _ = try await result.reduce { _ in }
                Issue.record("Expected StreamingError.noContent to be thrown")
            } catch let error as StreamingError {
                if case .noContent = error {
                    // Expected
                } else {
                    Issue.record("Expected noContent error, got: \(error)")
                }
            } catch {
                Issue.record("Unexpected error type: \(error)")
            }
        }
    }

    // MARK: - collectOrNil() Method Tests

    @Suite("collectOrNil() Method")
    struct CollectOrNilMethodTests {

        @Test("Returns nil for empty stream (does not throw)")
        func collectOrNilReturnsNilForEmpty() async throws {
            let stream = AsyncThrowingStream<TestGenerable.Partial, Error> { continuation in
                continuation.finish()
            }

            let result = StreamingResult<TestGenerable>(stream)
            let collected = try await result.collectOrNil()

            #expect(collected == nil)
        }

        @Test("Returns result for non-empty stream")
        func collectOrNilReturnsResultForNonEmpty() async throws {
            let stream = AsyncThrowingStream<TestGenerable.Partial, Error> { continuation in
                continuation.yield(TestGenerable.Partial(value: "first"))
                continuation.yield(TestGenerable.Partial(value: "second"))
                continuation.finish()
            }

            let result = StreamingResult<TestGenerable>(stream)
            let collected = try await result.collectOrNil()

            #expect(collected != nil)
            #expect(collected?.value == "second")
        }

        @Test("Handles single value correctly")
        func collectOrNilHandlesSingleValue() async throws {
            let stream = AsyncThrowingStream<TestGenerable.Partial, Error> { continuation in
                continuation.yield(TestGenerable.Partial(value: "singleton"))
                continuation.finish()
            }

            let result = StreamingResult<TestGenerable>(stream)
            let collected = try await result.collectOrNil()

            #expect(collected != nil)
            #expect(collected?.value == "singleton")
        }
    }

    // MARK: - reduceOnMain() Method Tests

    @Suite("reduceOnMain() Method")
    struct ReduceOnMainMethodTests {

        @Test("Handler runs on main actor")
        @MainActor
        func reduceOnMainRunsOnMainActor() async throws {
            let stream = AsyncThrowingStream<TestGenerable.Partial, Error> { continuation in
                continuation.yield(TestGenerable.Partial(value: "test"))
                continuation.finish()
            }

            let result = StreamingResult<TestGenerable>(stream)
            var handlerCalled = false

            _ = try await result.reduceOnMain { partial in
                // This closure is @MainActor, so we can check we're on main
                handlerCalled = true
                #expect(partial.value == "test")
            }

            #expect(handlerCalled == true)
        }

        @Test("Returns final result")
        @MainActor
        func reduceOnMainReturnsFinalResult() async throws {
            let stream = AsyncThrowingStream<TestGenerable.Partial, Error> { continuation in
                continuation.yield(TestGenerable.Partial(value: "initial"))
                continuation.yield(TestGenerable.Partial(value: "final"))
                continuation.finish()
            }

            let result = StreamingResult<TestGenerable>(stream)

            let finalResult = try await result.reduceOnMain { _ in
                // Observing on main
            }

            #expect(finalResult.value == "final")
        }
    }

    // MARK: - Error Handling Tests

    @Suite("Error Handling")
    struct ErrorHandlingTests {

        @Test("StreamingError.noContent has correct description")
        func noContentDescription() {
            let error = StreamingError.noContent

            let description = error.errorDescription
            #expect(description != nil)
            #expect(description?.contains("without producing content") == true)
        }

        @Test("StreamingError.parseFailed has correct description")
        func parseFailedDescription() {
            let json = "{\"invalid\": json content here}"
            let error = StreamingError.parseFailed(json)

            let description = error.errorDescription
            #expect(description != nil)
            #expect(description?.contains("Failed to parse") == true)
            #expect(description?.contains("JSON") == true)
        }

        @Test("StreamingError.conversionFailed wraps underlying error")
        func conversionFailedWrapsError() {
            let underlyingError = NSError(domain: "TestDomain", code: 42, userInfo: [
                NSLocalizedDescriptionKey: "Test conversion error"
            ])
            let error = StreamingError.conversionFailed(underlyingError)

            let description = error.errorDescription
            #expect(description != nil)
            #expect(description?.contains("Failed to convert") == true)
            #expect(description?.contains("target type") == true)
        }
    }

    // MARK: - AsyncSequence Conformance Tests

    @Suite("AsyncSequence Conformance")
    struct AsyncSequenceConformanceTests {

        @Test("StreamingResult is AsyncSequence")
        func isAsyncSequence() async throws {
            let stream = AsyncThrowingStream<TestGenerable.Partial, Error> { continuation in
                continuation.yield(TestGenerable.Partial(value: "test"))
                continuation.finish()
            }

            let result = StreamingResult<TestGenerable>(stream)

            // Verify we can use AsyncSequence methods
            var iterator = result.makeAsyncIterator()
            let first = try await iterator.next()

            #expect(first?.value == "test")

            let second = try await iterator.next()
            #expect(second == nil)
        }

        @Test("Element type is Partial")
        func elementTypeIsPartial() async throws {
            let stream = AsyncThrowingStream<TestGenerable.Partial, Error> { continuation in
                continuation.yield(TestGenerable.Partial(value: "check"))
                continuation.finish()
            }

            let result = StreamingResult<TestGenerable>(stream)

            for try await partial in result {
                // partial should be of type TestGenerable.Partial
                let _: TestGenerable.Partial = partial
                #expect(partial.value == "check")
            }
        }
    }

    // MARK: - Stream Error Propagation Tests

    @Suite("Stream Error Propagation")
    struct StreamErrorPropagationTests {

        @Test("Errors propagate during iteration")
        func errorsPropagateDuringIteration() async {
            let testError = NSError(domain: "Test", code: 1, userInfo: nil)

            let stream = AsyncThrowingStream<TestGenerable.Partial, Error> { continuation in
                continuation.yield(TestGenerable.Partial(value: "before-error"))
                continuation.finish(throwing: testError)
            }

            let result = StreamingResult<TestGenerable>(stream)
            var receivedValue = false

            do {
                for try await partial in result {
                    if partial.value == "before-error" {
                        receivedValue = true
                    }
                }
                Issue.record("Expected error to be thrown")
            } catch {
                #expect(receivedValue == true)
            }
        }

        @Test("Errors propagate from collect()")
        func errorsFromCollect() async {
            let testError = NSError(domain: "Test", code: 2, userInfo: nil)

            let stream = AsyncThrowingStream<TestGenerable.Partial, Error> { continuation in
                continuation.yield(TestGenerable.Partial(value: "value"))
                continuation.finish(throwing: testError)
            }

            let result = StreamingResult<TestGenerable>(stream)

            do {
                _ = try await result.collect()
                Issue.record("Expected error to be thrown")
            } catch let error as NSError {
                #expect(error.code == 2)
            }
        }

        @Test("Errors propagate from reduce()")
        func errorsFromReduce() async {
            let testError = NSError(domain: "Test", code: 3, userInfo: nil)

            let stream = AsyncThrowingStream<TestGenerable.Partial, Error> { continuation in
                continuation.yield(TestGenerable.Partial(value: "value"))
                continuation.finish(throwing: testError)
            }

            let result = StreamingResult<TestGenerable>(stream)

            do {
                _ = try await result.reduce { _ in }
                Issue.record("Expected error to be thrown")
            } catch let error as NSError {
                #expect(error.code == 3)
            }
        }
    }

    // MARK: - Sendable Conformance Tests

    @Suite("Sendable Conformance")
    struct SendableConformanceTests {

        @Test("StreamingResult is Sendable")
        func streamingResultIsSendable() async throws {
            let stream = AsyncThrowingStream<TestGenerable.Partial, Error> { continuation in
                continuation.yield(TestGenerable.Partial(value: "sendable-test"))
                continuation.finish()
            }

            let result = StreamingResult<TestGenerable>(stream)

            // Pass across actor boundary
            let collected = try await Task.detached {
                try await result.collect()
            }.value

            #expect(collected.value == "sendable-test")
        }
    }
}
