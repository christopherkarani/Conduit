import Foundation
import Testing
@testable import Conduit

actor TerminationRecorder<T: Sendable> {
    private var value: T?

    func set(_ newValue: T) {
        value = newValue
    }

    func get() -> T? {
        value
    }
}

private func waitForTermination<T: Sendable>(
    _ recorder: TerminationRecorder<T>,
    timeout: Duration = .seconds(1),
    pollInterval: Duration = .milliseconds(10)
) async -> T? {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)

    while clock.now < deadline {
        if let value = await recorder.get() {
            return value
        }
        try? await Task.sleep(for: pollInterval)
    }

    return nil
}

private func isCancelled<T>(
    _ termination: AsyncThrowingStream<T, Error>.Continuation.Termination
) -> Bool {
    switch termination {
    case .cancelled:
        return true
    case .finished:
        return false
    @unknown default:
        return false
    }
}

private func makeNonYieldingStringStream(
    finishAfter: Duration = .milliseconds(250),
    terminationRecorder: TerminationRecorder<AsyncThrowingStream<String, Error>.Continuation.Termination>
) -> AsyncThrowingStream<String, Error> {
    AsyncThrowingStream { continuation in
        continuation.onTermination = { termination in
            Task { await terminationRecorder.set(termination) }
        }

        Task {
            try? await Task.sleep(for: finishAfter)
            continuation.finish()
        }
    }
}

private func makeNonYieldingChunkStream(
    finishAfter: Duration = .milliseconds(250),
    terminationRecorder: TerminationRecorder<AsyncThrowingStream<GenerationChunk, Error>.Continuation.Termination>
) -> AsyncThrowingStream<GenerationChunk, Error> {
    AsyncThrowingStream { continuation in
        continuation.onTermination = { termination in
            Task { await terminationRecorder.set(termination) }
        }

        Task {
            try? await Task.sleep(for: finishAfter)
            continuation.finish()
        }
    }
}

private func consume<S: AsyncSequence & Sendable>(_ sequence: sending S) -> Task<Void, Never> {
    Task {
        do {
            for try await _ in sequence {
            }
        } catch {
        }
    }
}

struct TestModelID: ModelIdentifying {
    let rawValue: String

    var displayName: String { rawValue }

    var provider: ProviderType { .openAI }

    var description: String { rawValue }

    static let test = TestModelID(rawValue: "test")
}

struct FakeTextGenerator: TextGenerator {
    typealias ModelID = TestModelID

    let makeStringStream: @Sendable () -> AsyncThrowingStream<String, Error>
    let makeMetadataStream: @Sendable () -> AsyncThrowingStream<GenerationChunk, Error>

    func generate(_ prompt: String, model: ModelID, config: GenerateConfig) async throws -> String {
        fatalError("Not used by StreamingCancellationTests")
    }

    func generate(messages: [Message], model: ModelID, config: GenerateConfig) async throws -> GenerationResult {
        fatalError("Not used by StreamingCancellationTests")
    }

    func stream(_ prompt: String, model: ModelID, config: GenerateConfig) -> AsyncThrowingStream<String, Error> {
        makeStringStream()
    }

    func streamWithMetadata(
        messages: [Message],
        model: ModelID,
        config: GenerateConfig
    ) -> AsyncThrowingStream<GenerationChunk, Error> {
        makeMetadataStream()
    }
}

@Suite("Streaming Cancellation Propagation")
struct StreamingCancellationTests {

    @Test("GenerationStream.from cancels upstream when consumer cancels")
    func generationStreamFromCancelsUpstream() async {
        let upstreamTermination = TerminationRecorder<AsyncThrowingStream<String, Error>.Continuation.Termination>()
        let upstream = makeNonYieldingStringStream(terminationRecorder: upstreamTermination)

        let wrapped = GenerationStream.from(upstream)

        let consumer = consume(wrapped)
        try? await Task.sleep(for: .milliseconds(50))
        consumer.cancel()
        _ = await consumer.value

        let termination = await waitForTermination(upstreamTermination)
        #expect(termination.map { _ in true } ?? false)
        #expect(termination.map(isCancelled) == true)
    }

    @Test("[Message].stream(with:model:config:) cancels provider metadata stream")
    func messageArrayStreamCancelsUpstreamMetadataStream() async {
        let upstreamTermination = TerminationRecorder<AsyncThrowingStream<GenerationChunk, Error>.Continuation.Termination>()

        let provider = FakeTextGenerator(
            makeStringStream: { AsyncThrowingStream { $0.finish() } },
            makeMetadataStream: {
                makeNonYieldingChunkStream(terminationRecorder: upstreamTermination)
            }
        )

        let messages: [Message] = [
            .user("Hello")
        ]

        let stream = messages.stream(with: provider, model: .test, config: .default)

        let consumer = consume(stream)
        try? await Task.sleep(for: .milliseconds(50))
        consumer.cancel()
        _ = await consumer.value

        let termination = await waitForTermination(upstreamTermination)
        #expect(termination.map { _ in true } ?? false)
        #expect(termination.map(isCancelled) == true)
    }

    @Test("TextGenerator.stream(_:returning:model:config:) cancels upstream string stream")
    func structuredStreamingTransformerCancelsUpstreamStringStream() async {
        let upstreamTermination = TerminationRecorder<AsyncThrowingStream<String, Error>.Continuation.Termination>()

        let provider = FakeTextGenerator(
            makeStringStream: {
                makeNonYieldingStringStream(terminationRecorder: upstreamTermination)
            },
            makeMetadataStream: { AsyncThrowingStream { $0.finish() } }
        )

        let stream = provider.stream(
            "Return JSON",
            returning: String.self,
            model: .test,
            config: .default
        )

        let consumer = consume(stream)
        try? await Task.sleep(for: .milliseconds(50))
        consumer.cancel()
        _ = await consumer.value

        let termination = await waitForTermination(upstreamTermination)
        #expect(termination.map { _ in true } ?? false)
        #expect(termination.map(isCancelled) == true)
    }
}
