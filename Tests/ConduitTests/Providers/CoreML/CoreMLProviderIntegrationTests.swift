#if CONDUIT_TRAIT_COREML && canImport(CoreML) && canImport(Tokenizers) && canImport(Generation) && canImport(Models) && canImport(Hub)
import Foundation
import Hub
import Testing
@testable import Conduit

@Generable
private struct CoreMLIntegrationWeatherArgs {
    let city: String
}

private let shouldRunCoreMLProviderIntegrationTests: Bool = {
    let env = ProcessInfo.processInfo.environment
    if env["ENABLE_COREML_TESTS"] == nil && env["CONDUIT_ENABLE_COREML_TESTS"] == nil {
        return false
    }
    if env["CI"] != nil {
        return false
    }
    return true
}()

@Suite("CoreML Provider Integration", .enabled(if: shouldRunCoreMLProviderIntegrationTests))
struct CoreMLProviderIntegrationTests {

    @Test("Snapshot-backed CoreML generate returns text")
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    func snapshotBackedGenerateReturnsText() async throws {
        let modelPath = try await resolveModelPath()
        let provider = CoreMLProvider()
        let config = GenerateConfig.default.maxTokens(16)

        let result = try await provider.generate(
            messages: [.user("Reply with one short sentence saying hello.")],
            model: .coreml(modelPath),
            config: config
        )

        #expect(!result.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        #expect(result.finishReason == .stop)
    }

    @Test("Snapshot-backed CoreML tokenizer-template path supports runtime hooks")
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    func snapshotBackedTokenizerTemplateSupportsRuntimeHooks() async throws {
        let modelPath = try await resolveModelPath()
        let provider = CoreMLProvider(
            configuration: .init(
                promptFormatting: .tokenizerChatTemplate,
                chatTemplate: "{% for message in messages %}{{ message['role'] }}: {{ message['content'] }}\n{% endfor %}assistant:"
            ),
            chatTemplateMessagesHandler: { messages in
                return messages.map { message in
                    [
                        "role": .string(message.role.rawValue),
                        "content": .string(message.content.textValue)
                    ]
                }
            },
            toolSpecificationHandler: { toolDefinitions in
                return toolDefinitions.map { tool in
                    [
                        "type": .string("function"),
                        "function": .object([
                            "name": .string(tool.name),
                            "description": .string(tool.description),
                            "parameters": .object([
                                "type": .string("object"),
                                "properties": .object([
                                    "city": .object(["type": .string("string")])
                                ]),
                                "required": .array([.string("city")])
                            ])
                        ])
                    ]
                }
            }
        )

        let tool = Transcript.ToolDefinition(
            name: "get_weather",
            description: "Get weather for a city",
            parameters: CoreMLIntegrationWeatherArgs.generationSchema
        )
        let config = GenerateConfig.default
            .tools([tool])
            .maxTokens(12)

        let result = try await provider.generate(
            messages: [.user("Say hello and mention Paris.")],
            model: .coreml(modelPath),
            config: config
        )

        #expect(!result.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    // MARK: - Fixtures

    private func resolveModelPath() async throws -> String {
        let env = ProcessInfo.processInfo.environment

        if let explicitPath = env["CONDUIT_COREML_MODEL_PATH"], !explicitPath.isEmpty {
            return explicitPath
        }

        let repoID = env["CONDUIT_COREML_REPO_ID"] ?? "apple/mistral-coreml"
        let snapshotGlob = env["CONDUIT_COREML_SNAPSHOT_GLOB"] ?? "*.mlmodelc/**"
        let modelSubpath = env["CONDUIT_COREML_MODEL_SUBPATH"]

        let hubAPI: HubApi = {
            if let token = env["HF_TOKEN"] ?? env["HUGGING_FACE_HUB_TOKEN"], !token.isEmpty {
                return HubApi(hfToken: token)
            }
            return HubApi()
        }()

        let snapshotURL = try await hubAPI.snapshot(
            from: Hub.Repo(id: repoID),
            matching: [snapshotGlob],
            progressHandler: { _ in }
        )

        if let modelSubpath, !modelSubpath.isEmpty {
            return snapshotURL.appendingPathComponent(modelSubpath).path
        }

        guard let discovered = firstCompiledModel(in: snapshotURL) else {
            throw AIError.modelNotFound(.coreml(snapshotURL.path))
        }
        return discovered.path
    }

    private func firstCompiledModel(in root: URL) -> URL? {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for case let url as URL in enumerator where url.pathExtension.lowercased() == "mlmodelc" {
            return url
        }
        return nil
    }
}
#endif
