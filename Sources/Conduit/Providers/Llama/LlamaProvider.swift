// LlamaProvider.swift
// Conduit

import Foundation

#if Llama && canImport(LlamaSwift)
@preconcurrency import LlamaSwift

/// Native llama.cpp provider backed by `LlamaSwift`.
///
/// Use `.llama("/path/to/model.gguf")` model identifiers with this provider.
public actor LlamaProvider: AIProvider, TextGenerator {

    public typealias Response = GenerationResult
    public typealias StreamChunk = GenerationChunk
    public typealias ModelID = ModelIdentifier

    /// Runtime configuration for llama.cpp.
    public let configuration: LlamaConfiguration

    private var backendInitialized = false
    private var loadedModelPath: String?
    nonisolated(unsafe) private var loadedModel: OpaquePointer?
    private var isCancelled = false

    public init(configuration: LlamaConfiguration = .default) {
        self.configuration = configuration
    }

    deinit {
        if let loadedModel {
            llama_model_free(loadedModel)
        }
    }

    // MARK: - Availability

    public var isAvailable: Bool {
        get async { true }
    }

    public var availabilityStatus: ProviderAvailability {
        get async { .available }
    }

    // MARK: - Generation

    public func generate(
        _ prompt: String,
        model: ModelIdentifier,
        config: GenerateConfig
    ) async throws -> String {
        let result = try await generate(
            messages: [.user(prompt)],
            model: model,
            config: config
        )
        return result.text
    }

    public func generate(
        messages: [Message],
        model: ModelIdentifier,
        config: GenerateConfig
    ) async throws -> GenerationResult {
        do {
            return try performGeneration(messages: messages, model: model, config: config)
        } catch {
            throw mapError(error)
        }
    }

    public nonisolated func stream(
        _ prompt: String,
        model: ModelIdentifier,
        config: GenerateConfig
    ) -> AsyncThrowingStream<String, Error> {
        let chunkStream = stream(messages: [.user(prompt)], model: model, config: config)
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await chunk in chunkStream {
                        if !chunk.text.isEmpty {
                            continuation.yield(chunk.text)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
                Task { await self.cancelGeneration() }
            }
        }
    }

    public nonisolated func streamWithMetadata(
        messages: [Message],
        model: ModelIdentifier,
        config: GenerateConfig
    ) -> AsyncThrowingStream<GenerationChunk, Error> {
        stream(messages: messages, model: model, config: config)
    }

    public nonisolated func stream(
        messages: [Message],
        model: ModelIdentifier,
        config: GenerateConfig
    ) -> AsyncThrowingStream<GenerationChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                await self.performStreamingGeneration(
                    messages: messages,
                    model: model,
                    config: config,
                    continuation: continuation
                )
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
                Task { await self.cancelGeneration() }
            }
        }
    }

    public func cancelGeneration() async {
        isCancelled = true
    }
}

// MARK: - Private Implementation

extension LlamaProvider {
    private struct RuntimeOptions: Sendable {
        let contextSize: UInt32
        let batchSize: UInt32
        let threads: Int32
        let maxTokens: Int
        let seed: UInt32
        let temperature: Float
        let topP: Float
        let topK: Int32?
        let repetitionPenalty: Float
        let repeatLastTokens: Int32
        let frequencyPenalty: Float
        let presencePenalty: Float
        let mirostat: LlamaConfiguration.MirostatMode?
        let stopSequences: [String]
    }

    private func performGeneration(
        messages: [Message],
        model: ModelIdentifier,
        config: GenerateConfig
    ) throws -> GenerationResult {
        guard !messages.isEmpty else {
            throw AIError.invalidInput("Messages cannot be empty")
        }

        isCancelled = false
        let startTime = Date()

        let modelPath = try resolveModelPath(from: model)
        let modelPointer = try ensureModelLoaded(at: modelPath)
        let options = makeRuntimeOptions(from: config)

        let prompt = try buildPrompt(from: messages, model: modelPointer)
        guard let vocab = llama_model_get_vocab(modelPointer) else {
            throw AIError.generationFailed(underlying: SendableError(LlamaProviderError.contextInitializationFailed))
        }

        let promptTokens = try tokenize(text: prompt, vocab: vocab)

        let contextParams = createContextParams(from: options)
        guard let context = llama_init_from_model(modelPointer, contextParams) else {
            throw AIError.generationFailed(underlying: SendableError(LlamaProviderError.contextInitializationFailed))
        }
        defer { llama_free(context) }

        if llama_get_memory(context) == nil {
            throw AIError.invalidInput("The selected GGUF model cannot be used for causal text generation")
        }

        llama_set_causal_attn(context, true)
        llama_set_warmup(context, false)
        llama_set_n_threads(context, options.threads, options.threads)

        var batch = llama_batch_init(Int32(options.batchSize), 0, 1)
        defer { llama_batch_free(batch) }

        let hasEncoder = try prepareInitialBatch(
            batch: &batch,
            promptTokens: promptTokens,
            model: modelPointer,
            vocab: vocab,
            context: context,
            batchSize: options.batchSize
        )

        guard let sampler = llama_sampler_chain_init(llama_sampler_chain_default_params()) else {
            throw AIError.generationFailed(underlying: SendableError(LlamaProviderError.decodingFailed))
        }
        defer { llama_sampler_free(sampler) }
        let samplerPtr = UnsafeMutablePointer<llama_sampler>(sampler)
        configureSampler(sampler: samplerPtr, options: options)

        var generatedText = ""
        var completionTokens = 0
        var finishReason: FinishReason = .maxTokens
        var nCur: Int32 = hasEncoder ? 1 : batch.n_tokens

        for _ in 0..<options.maxTokens {
            if Task.isCancelled || isCancelled {
                finishReason = .cancelled
                break
            }

            let nextToken = llama_sampler_sample(sampler, context, batch.n_tokens - 1)
            llama_sampler_accept(sampler, nextToken)

            if llama_vocab_is_eog(vocab, nextToken) {
                finishReason = .stop
                break
            }

            if let piece = tokenToText(vocab: vocab, token: nextToken), !piece.isEmpty {
                generatedText += piece
            }
            completionTokens += 1

            if trimMatchedStopSequence(in: &generatedText, stopSequences: options.stopSequences) {
                finishReason = .stopSequence
                break
            }

            batch.n_tokens = 1
            batch.token[0] = nextToken
            batch.pos[0] = nCur
            batch.n_seq_id[0] = 1
            if let seqIDs = batch.seq_id, let seqID = seqIDs[0] {
                seqID[0] = 0
            }
            batch.logits[0] = 1
            nCur += 1

            guard llama_decode(context, batch) == 0 else {
                throw AIError.generationFailed(underlying: SendableError(LlamaProviderError.decodingFailed))
            }
        }

        let duration = Date().timeIntervalSince(startTime)
        let tokensPerSecond = duration > 0 ? Double(completionTokens) / duration : 0

        return GenerationResult(
            text: generatedText,
            tokenCount: completionTokens,
            generationTime: duration,
            tokensPerSecond: tokensPerSecond,
            finishReason: finishReason,
            usage: UsageStats(promptTokens: promptTokens.count, completionTokens: completionTokens)
        )
    }

    private func performStreamingGeneration(
        messages: [Message],
        model: ModelIdentifier,
        config: GenerateConfig,
        continuation: AsyncThrowingStream<GenerationChunk, Error>.Continuation
    ) async {
        do {
            guard !messages.isEmpty else {
                throw AIError.invalidInput("Messages cannot be empty")
            }

            isCancelled = false
            let startTime = Date()

            let modelPath = try resolveModelPath(from: model)
            let modelPointer = try ensureModelLoaded(at: modelPath)
            let options = makeRuntimeOptions(from: config)

            let prompt = try buildPrompt(from: messages, model: modelPointer)
            guard let vocab = llama_model_get_vocab(modelPointer) else {
                throw AIError.generationFailed(underlying: SendableError(LlamaProviderError.contextInitializationFailed))
            }

            let promptTokens = try tokenize(text: prompt, vocab: vocab)

            let contextParams = createContextParams(from: options)
            guard let context = llama_init_from_model(modelPointer, contextParams) else {
                throw AIError.generationFailed(underlying: SendableError(LlamaProviderError.contextInitializationFailed))
            }
            defer { llama_free(context) }

            if llama_get_memory(context) == nil {
                throw AIError.invalidInput("The selected GGUF model cannot be used for causal text generation")
            }

            llama_set_causal_attn(context, true)
            llama_set_warmup(context, false)
            llama_set_n_threads(context, options.threads, options.threads)

            var batch = llama_batch_init(Int32(options.batchSize), 0, 1)
            defer { llama_batch_free(batch) }

            let hasEncoder = try prepareInitialBatch(
                batch: &batch,
                promptTokens: promptTokens,
                model: modelPointer,
                vocab: vocab,
                context: context,
                batchSize: options.batchSize
            )

            guard let sampler = llama_sampler_chain_init(llama_sampler_chain_default_params()) else {
                throw AIError.generationFailed(underlying: SendableError(LlamaProviderError.decodingFailed))
            }
            defer { llama_sampler_free(sampler) }
            let samplerPtr = UnsafeMutablePointer<llama_sampler>(sampler)
            configureSampler(sampler: samplerPtr, options: options)

            var completionTokens = 0
            var finishReason: FinishReason = .maxTokens
            var nCur: Int32 = hasEncoder ? 1 : batch.n_tokens
            var pendingText = ""
            let maxStopSequenceLength = options.stopSequences.map(\.count).max() ?? 0
            let holdbackCount = max(0, maxStopSequenceLength - 1)

            for _ in 0..<options.maxTokens {
                if Task.isCancelled || isCancelled {
                    finishReason = .cancelled
                    break
                }

                let nextToken = llama_sampler_sample(sampler, context, batch.n_tokens - 1)
                llama_sampler_accept(sampler, nextToken)

                if llama_vocab_is_eog(vocab, nextToken) {
                    finishReason = .stop
                    break
                }

                completionTokens += 1
                let elapsed = Date().timeIntervalSince(startTime)
                let tokensPerSecond = elapsed > 0 ? Double(completionTokens) / elapsed : 0

                if let piece = tokenToText(vocab: vocab, token: nextToken), !piece.isEmpty {
                    pendingText += piece

                    if trimMatchedStopSequence(in: &pendingText, stopSequences: options.stopSequences) {
                        if !pendingText.isEmpty {
                            continuation.yield(
                                GenerationChunk(
                                    text: pendingText,
                                    tokenCount: 1,
                                    tokensPerSecond: tokensPerSecond,
                                    isComplete: false
                                )
                            )
                            pendingText.removeAll(keepingCapacity: true)
                        }
                        finishReason = .stopSequence
                        break
                    }

                    if holdbackCount == 0 {
                        continuation.yield(
                            GenerationChunk(
                                text: pendingText,
                                tokenCount: 1,
                                tokensPerSecond: tokensPerSecond,
                                isComplete: false
                            )
                        )
                        pendingText.removeAll(keepingCapacity: true)
                    } else if pendingText.count > holdbackCount {
                        let safeCount = pendingText.count - holdbackCount
                        let safeText = String(pendingText.prefix(safeCount))
                        pendingText.removeFirst(safeCount)
                        continuation.yield(
                            GenerationChunk(
                                text: safeText,
                                tokenCount: 1,
                                tokensPerSecond: tokensPerSecond,
                                isComplete: false
                            )
                        )
                    }
                }

                batch.n_tokens = 1
                batch.token[0] = nextToken
                batch.pos[0] = nCur
                batch.n_seq_id[0] = 1
                if let seqIDs = batch.seq_id, let seqID = seqIDs[0] {
                    seqID[0] = 0
                }
                batch.logits[0] = 1
                nCur += 1

                guard llama_decode(context, batch) == 0 else {
                    throw AIError.generationFailed(underlying: SendableError(LlamaProviderError.decodingFailed))
                }
            }

            if finishReason != .stopSequence, !pendingText.isEmpty {
                let elapsed = Date().timeIntervalSince(startTime)
                let tokensPerSecond = elapsed > 0 ? Double(completionTokens) / elapsed : 0
                continuation.yield(
                    GenerationChunk(
                        text: pendingText,
                        tokenCount: 0,
                        tokensPerSecond: tokensPerSecond,
                        isComplete: false
                    )
                )
            }

            continuation.yield(
                GenerationChunk(
                    text: "",
                    tokenCount: 0,
                    isComplete: true,
                    finishReason: finishReason,
                    usage: UsageStats(promptTokens: promptTokens.count, completionTokens: completionTokens)
                )
            )
            continuation.finish()
        } catch {
            continuation.finish(throwing: mapError(error))
        }
    }
}

// MARK: - Llama Runtime Helpers

extension LlamaProvider {
    private func resolveModelPath(from model: ModelIdentifier) throws -> String {
        guard case .llama(let path) = model else {
            throw AIError.invalidInput("LlamaProvider only supports .llama() models")
        }

        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            throw AIError.invalidInput("Model path cannot be empty")
        }
        return trimmedPath
    }

    private func ensureModelLoaded(at path: String) throws -> OpaquePointer {
        if let loadedModel, loadedModelPath == path {
            return loadedModel
        }

        guard FileManager.default.fileExists(atPath: path) else {
            throw AIError.modelNotFound(.llama(path))
        }

        if !backendInitialized {
            llama_backend_init()
            backendInitialized = true
        }

        if let loadedModel {
            llama_model_free(loadedModel)
            self.loadedModel = nil
            self.loadedModelPath = nil
        }

        let modelParams = createModelParams()
        guard let model = llama_model_load_from_file(path, modelParams) else {
            throw AIError.generationFailed(underlying: SendableError(LlamaProviderError.modelLoadFailed))
        }

        self.loadedModel = model
        self.loadedModelPath = path
        return model
    }

    private func createModelParams() -> llama_model_params {
        var params = llama_model_default_params()
        params.n_gpu_layers = configuration.gpuLayers
        params.use_mmap = configuration.useMemoryMapping
        params.use_mlock = configuration.lockMemory
        return params
    }

    private func createContextParams(from options: RuntimeOptions) -> llama_context_params {
        var params = llama_context_default_params()
        params.n_ctx = options.contextSize
        params.n_batch = options.batchSize
        params.n_threads = options.threads
        params.n_threads_batch = options.threads
        return params
    }

    private func makeRuntimeOptions(from config: GenerateConfig) -> RuntimeOptions {
        let maxTokens = max(1, config.maxTokens ?? configuration.defaultMaxTokens)
        let normalizedTopP = min(1, max(0, config.topP))
        let normalizedTemperature = max(0, config.temperature)
        let normalizedTopK: Int32? = config.topK.map { Int32(max(0, $0)) }
        let seed = config.seed.map { UInt32(truncatingIfNeeded: $0) } ?? UInt32.random(in: 0...UInt32.max)

        return RuntimeOptions(
            contextSize: configuration.contextSize,
            batchSize: configuration.batchSize,
            threads: max(1, configuration.threadCount),
            maxTokens: maxTokens,
            seed: seed,
            temperature: normalizedTemperature,
            topP: normalizedTopP,
            topK: normalizedTopK,
            repetitionPenalty: config.repetitionPenalty,
            repeatLastTokens: configuration.repeatLastTokens,
            frequencyPenalty: config.frequencyPenalty,
            presencePenalty: config.presencePenalty,
            mirostat: configuration.mirostat,
            stopSequences: config.stopSequences.filter { !$0.isEmpty }
        )
    }

    private func configureSampler(
        sampler: UnsafeMutablePointer<llama_sampler>,
        options: RuntimeOptions
    ) {
        if options.repetitionPenalty != 1.0 || options.frequencyPenalty != 0.0 || options.presencePenalty != 0.0 {
            llama_sampler_chain_add(
                sampler,
                llama_sampler_init_penalties(
                    options.repeatLastTokens,
                    options.repetitionPenalty,
                    options.frequencyPenalty,
                    options.presencePenalty
                )
            )
        }

        if let mirostat = options.mirostat {
            llama_sampler_chain_add(sampler, llama_sampler_init_temp(options.temperature))

            switch mirostat {
            case .v1(let tau, let eta):
                llama_sampler_chain_add(
                    sampler,
                    llama_sampler_init_mirostat(
                        Int32(options.contextSize),
                        options.seed,
                        tau,
                        eta,
                        100
                    )
                )
            case .v2(let tau, let eta):
                llama_sampler_chain_add(
                    sampler,
                    llama_sampler_init_mirostat_v2(options.seed, tau, eta)
                )
            }
            return
        }

        if options.temperature == 0 {
            llama_sampler_chain_add(sampler, llama_sampler_init_top_k(1))
            llama_sampler_chain_add(sampler, llama_sampler_init_top_p(1.0, 1))
            llama_sampler_chain_add(sampler, llama_sampler_init_greedy())
            return
        }

        if let topK = options.topK, topK > 0 {
            llama_sampler_chain_add(sampler, llama_sampler_init_top_k(topK))
        }
        if options.topP < 1.0 {
            llama_sampler_chain_add(sampler, llama_sampler_init_top_p(options.topP, 1))
        }
        llama_sampler_chain_add(sampler, llama_sampler_init_temp(options.temperature))
        llama_sampler_chain_add(sampler, llama_sampler_init_dist(options.seed))
    }

    private func buildPrompt(from messages: [Message], model: OpaquePointer) throws -> String {
        try validateMessages(messages)

        let mappedMessages = messages.compactMap { message -> (role: String, content: String)? in
            let text = message.content.textValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }

            switch message.role {
            case .system:
                return ("system", text)
            case .user:
                return ("user", text)
            case .assistant:
                return ("assistant", text)
            case .tool:
                let toolName = message.metadata?.custom?["tool_name"] ?? "tool"
                return ("user", "Tool(\(toolName)) output: \(text)")
            }
        }

        guard !mappedMessages.isEmpty else {
            throw AIError.invalidInput("Messages must contain at least one text segment")
        }

        if let formatted = try? applyTemplate(messages: mappedMessages, model: model) {
            return formatted
        }

        return fallbackPrompt(messages: mappedMessages)
    }

    private func validateMessages(_ messages: [Message]) throws {
        for message in messages {
            if case .parts(let parts) = message.content {
                for part in parts {
                    switch part {
                    case .text:
                        continue
                    case .image, .audio:
                        throw AIError.invalidInput("LlamaProvider supports text-only prompts")
                    }
                }
            }
        }
    }

    private func applyTemplate(
        messages: [(role: String, content: String)],
        model: OpaquePointer
    ) throws -> String {
        let cRoles = messages.map { strdup($0.role) }
        let cContents = messages.map { strdup($0.content) }

        defer {
            cRoles.forEach { free($0) }
            cContents.forEach { free($0) }
        }

        var cMessages = [llama_chat_message]()
        cMessages.reserveCapacity(messages.count)
        for index in 0..<messages.count {
            cMessages.append(
                llama_chat_message(
                    role: cRoles[index],
                    content: cContents[index]
                )
            )
        }

        let template = llama_model_chat_template(model, nil)
        let requiredSize = llama_chat_apply_template(
            template,
            cMessages,
            cMessages.count,
            true,
            nil,
            0
        )

        guard requiredSize > 0 else {
            throw LlamaProviderError.templateFormattingFailed
        }

        var buffer = [CChar](repeating: 0, count: Int(requiredSize) + 1)
        let written = llama_chat_apply_template(
            template,
            cMessages,
            cMessages.count,
            true,
            &buffer,
            Int32(buffer.count)
        )

        guard written > 0 else {
            throw LlamaProviderError.templateFormattingFailed
        }

        return buffer.withUnsafeBytes { rawBuffer in
            String(decoding: rawBuffer.prefix(Int(written)), as: UTF8.self)
        }
    }

    private func fallbackPrompt(messages: [(role: String, content: String)]) -> String {
        var lines = [String]()
        lines.reserveCapacity(messages.count + 1)

        for message in messages {
            let role: String
            switch message.role {
            case "system":
                role = "System"
            case "assistant":
                role = "Assistant"
            default:
                role = "User"
            }
            lines.append("\(role): \(message.content)")
        }

        lines.append("Assistant:")
        return lines.joined(separator: "\n")
    }

    private func tokenize(text: String, vocab: OpaquePointer) throws -> [llama_token] {
        let utf8Count = text.utf8.count
        let maxTokens = Int32(max(8, utf8Count * 2))
        let tokens = UnsafeMutablePointer<llama_token>.allocate(capacity: Int(maxTokens))
        defer { tokens.deallocate() }

        let tokenCount = llama_tokenize(
            vocab,
            text,
            Int32(utf8Count),
            tokens,
            maxTokens,
            true,
            true
        )

        guard tokenCount > 0 else {
            throw AIError.generationFailed(underlying: SendableError(LlamaProviderError.tokenizationFailed))
        }

        return Array(UnsafeBufferPointer(start: tokens, count: Int(tokenCount)))
    }

    private func prepareInitialBatch(
        batch: inout llama_batch,
        promptTokens: [llama_token],
        model: OpaquePointer,
        vocab: OpaquePointer,
        context: OpaquePointer,
        batchSize: UInt32
    ) throws -> Bool {
        let effectiveBatchSize = max(1, Int(batchSize))

        let hasEncoder = llama_model_has_encoder(model)
        let hasDecoder = llama_model_has_decoder(model)

        if hasEncoder {
            var start = 0
            while start < promptTokens.count {
                let end = min(start + effectiveBatchSize, promptTokens.count)
                let chunk = promptTokens[start..<end]

                batch.n_tokens = Int32(chunk.count)
                for (offset, token) in chunk.enumerated() {
                    let index = offset
                    batch.token[index] = token
                    batch.pos[index] = Int32(start + offset)
                    batch.n_seq_id[index] = 1
                    if let seqIDs = batch.seq_id, let seqID = seqIDs[index] {
                        seqID[0] = 0
                    }
                    batch.logits[index] = 0
                }

                guard llama_encode(context, batch) == 0 else {
                    throw AIError.generationFailed(underlying: SendableError(LlamaProviderError.encodingFailed))
                }

                start = end
            }

            if hasDecoder {
                var decoderStart = llama_model_decoder_start_token(model)
                if decoderStart == LLAMA_TOKEN_NULL {
                    decoderStart = llama_vocab_bos(vocab)
                }

                batch.n_tokens = 1
                batch.token[0] = decoderStart
                batch.pos[0] = 0
                batch.n_seq_id[0] = 1
                if let seqIDs = batch.seq_id, let seqID = seqIDs[0] {
                    seqID[0] = 0
                }
                batch.logits[0] = 1

                guard llama_decode(context, batch) == 0 else {
                    throw AIError.generationFailed(underlying: SendableError(LlamaProviderError.decodingFailed))
                }
            } else {
                throw AIError.invalidInput("Encoder-only model is not supported for text generation")
            }
        } else {
            var start = 0
            while start < promptTokens.count {
                let end = min(start + effectiveBatchSize, promptTokens.count)
                let chunk = promptTokens[start..<end]
                let isLastChunk = end == promptTokens.count

                batch.n_tokens = Int32(chunk.count)
                for (offset, token) in chunk.enumerated() {
                    let index = offset
                    batch.token[index] = token
                    batch.pos[index] = Int32(start + offset)
                    batch.n_seq_id[index] = 1
                    if let seqIDs = batch.seq_id, let seqID = seqIDs[index] {
                        seqID[0] = 0
                    }
                    batch.logits[index] = 0
                }

                if isLastChunk, batch.n_tokens > 0 {
                    batch.logits[Int(batch.n_tokens) - 1] = 1
                }

                guard llama_decode(context, batch) == 0 else {
                    throw AIError.generationFailed(underlying: SendableError(LlamaProviderError.decodingFailed))
                }

                start = end
            }
        }

        return hasEncoder
    }

    private func tokenToText(vocab: OpaquePointer, token: llama_token) -> String? {
        var capacity: Int32 = 64
        var buffer = UnsafeMutablePointer<CChar>.allocate(capacity: Int(capacity))
        defer { buffer.deallocate() }

        var written = llama_token_to_piece(
            vocab,
            token,
            buffer,
            capacity,
            0,
            false
        )

        if written < 0 {
            capacity = -written
            buffer.deallocate()
            buffer = UnsafeMutablePointer<CChar>.allocate(capacity: Int(capacity))
            written = llama_token_to_piece(
                vocab,
                token,
                buffer,
                capacity,
                0,
                false
            )
        }

        let count = Int(max(0, written))
        guard count > 0 else { return nil }

        let rawPointer = UnsafeRawPointer(buffer)
        let u8Pointer = rawPointer.assumingMemoryBound(to: UInt8.self)
        let bytes = UnsafeBufferPointer(start: u8Pointer, count: count)
        return String(decoding: bytes, as: UTF8.self)
    }

    private func trimMatchedStopSequence(in text: inout String, stopSequences: [String]) -> Bool {
        for sequence in stopSequences where text.hasSuffix(sequence) {
            text = String(text.dropLast(sequence.count))
            return true
        }
        return false
    }

    private func mapError(_ error: Error) -> AIError {
        if let aiError = error as? AIError {
            return aiError
        }
        return .generationFailed(underlying: SendableError(error))
    }
}

private enum LlamaProviderError: Error {
    case modelLoadFailed
    case contextInitializationFailed
    case tokenizationFailed
    case encodingFailed
    case decodingFailed
    case templateFormattingFailed
}

#else

/// Fallback stub when `LlamaSwift` is not linked.
public actor LlamaProvider: AIProvider, TextGenerator {
    public typealias Response = GenerationResult
    public typealias StreamChunk = GenerationChunk
    public typealias ModelID = ModelIdentifier

    public let configuration: LlamaConfiguration

    public init(configuration: LlamaConfiguration = .default) {
        self.configuration = configuration
    }

    public var isAvailable: Bool {
        get async { false }
    }

    public var availabilityStatus: ProviderAvailability {
        get async { .unavailable(.deviceNotSupported) }
    }

    public func generate(
        _ prompt: String,
        model: ModelIdentifier,
        config: GenerateConfig
    ) async throws -> String {
        throw AIError.providerUnavailable(reason: .deviceNotSupported)
    }

    public func generate(
        messages: [Message],
        model: ModelIdentifier,
        config: GenerateConfig
    ) async throws -> GenerationResult {
        throw AIError.providerUnavailable(reason: .deviceNotSupported)
    }

    public nonisolated func stream(
        _ prompt: String,
        model: ModelIdentifier,
        config: GenerateConfig
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: AIError.providerUnavailable(reason: .deviceNotSupported))
        }
    }

    public nonisolated func streamWithMetadata(
        messages: [Message],
        model: ModelIdentifier,
        config: GenerateConfig
    ) -> AsyncThrowingStream<GenerationChunk, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: AIError.providerUnavailable(reason: .deviceNotSupported))
        }
    }

    public nonisolated func stream(
        messages: [Message],
        model: ModelIdentifier,
        config: GenerateConfig
    ) -> AsyncThrowingStream<GenerationChunk, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: AIError.providerUnavailable(reason: .deviceNotSupported))
        }
    }

    public func cancelGeneration() async {}
}

#endif
