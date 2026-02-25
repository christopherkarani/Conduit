// OpenAICapabilitiesTests.swift
// Conduit Tests
//
// Tests for OpenAICapabilities option set flags, presets, and methods.

#if CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
import Foundation
import Testing
@testable import Conduit

@Suite("OpenAICapabilities Tests")
struct OpenAICapabilitiesTests {

    // MARK: - Individual Capability Flags

    @Test("Each capability flag has a unique raw value")
    func uniqueRawValues() {
        let flags: [OpenAICapabilities] = [
            .textGeneration, .streaming, .embeddings,
            .imageGeneration, .transcription, .functionCalling,
            .jsonMode, .vision, .textToSpeech,
            .parallelFunctionCalling, .structuredOutputs
        ]
        let rawValues = flags.map(\.rawValue)
        let uniqueValues = Set(rawValues)
        #expect(rawValues.count == uniqueValues.count)
    }

    @Test("Capability raw values are powers of 2")
    func rawValuesArePowersOf2() {
        #expect(OpenAICapabilities.textGeneration.rawValue == 1)
        #expect(OpenAICapabilities.streaming.rawValue == 2)
        #expect(OpenAICapabilities.embeddings.rawValue == 4)
        #expect(OpenAICapabilities.imageGeneration.rawValue == 8)
        #expect(OpenAICapabilities.transcription.rawValue == 16)
        #expect(OpenAICapabilities.functionCalling.rawValue == 32)
        #expect(OpenAICapabilities.jsonMode.rawValue == 64)
        #expect(OpenAICapabilities.vision.rawValue == 128)
        #expect(OpenAICapabilities.textToSpeech.rawValue == 256)
        #expect(OpenAICapabilities.parallelFunctionCalling.rawValue == 512)
        #expect(OpenAICapabilities.structuredOutputs.rawValue == 1024)
    }

    // MARK: - Preset Capability Sets

    @Test("OpenAI preset includes all expected capabilities")
    func openAIPreset() {
        let caps = OpenAICapabilities.openAI
        #expect(caps.contains(.textGeneration))
        #expect(caps.contains(.streaming))
        #expect(caps.contains(.embeddings))
        #expect(caps.contains(.imageGeneration))
        #expect(caps.contains(.transcription))
        #expect(caps.contains(.functionCalling))
        #expect(caps.contains(.jsonMode))
        #expect(caps.contains(.vision))
        #expect(caps.contains(.textToSpeech))
        #expect(caps.contains(.parallelFunctionCalling))
        #expect(caps.contains(.structuredOutputs))
    }

    @Test("OpenRouter preset includes expected capabilities")
    func openRouterPreset() {
        let caps = OpenAICapabilities.openRouter
        #expect(caps.contains(.textGeneration))
        #expect(caps.contains(.streaming))
        #expect(caps.contains(.embeddings))
        #expect(caps.contains(.functionCalling))
        #expect(caps.contains(.jsonMode))
        #expect(caps.contains(.vision))
        #expect(!caps.contains(.imageGeneration))
        #expect(!caps.contains(.transcription))
        #expect(!caps.contains(.textToSpeech))
    }

    @Test("Ollama preset includes expected capabilities")
    func ollamaPreset() {
        let caps = OpenAICapabilities.ollama
        #expect(caps.contains(.textGeneration))
        #expect(caps.contains(.streaming))
        #expect(caps.contains(.embeddings))
        #expect(caps.contains(.vision))
        #expect(!caps.contains(.imageGeneration))
        #expect(!caps.contains(.transcription))
        #expect(!caps.contains(.functionCalling))
        #expect(!caps.contains(.textToSpeech))
    }

    @Test("textOnly preset contains only textGeneration and streaming")
    func textOnlyPreset() {
        let caps = OpenAICapabilities.textOnly
        #expect(caps.contains(.textGeneration))
        #expect(caps.contains(.streaming))
        #expect(!caps.contains(.embeddings))
        #expect(!caps.contains(.imageGeneration))
        #expect(!caps.contains(.functionCalling))
    }

    @Test("all preset includes every capability")
    func allPreset() {
        let caps = OpenAICapabilities.all
        #expect(caps == .openAI)
    }

    // MARK: - supports / supportsAll / supportsAny

    @Test("supports returns true for contained capability")
    func supportsContained() {
        let caps = OpenAICapabilities.openAI
        #expect(caps.supports(.textGeneration))
        #expect(caps.supports(.vision))
    }

    @Test("supports returns false for non-contained capability")
    func supportsNotContained() {
        let caps = OpenAICapabilities.textOnly
        #expect(!caps.supports(.embeddings))
        #expect(!caps.supports(.imageGeneration))
    }

    @Test("supportsAll returns true when all capabilities present")
    func supportsAllPresent() {
        let caps = OpenAICapabilities.openAI
        let required: OpenAICapabilities = [.textGeneration, .streaming, .vision]
        #expect(caps.supportsAll(required))
    }

    @Test("supportsAll returns false when some capabilities missing")
    func supportsAllMissing() {
        let caps = OpenAICapabilities.textOnly
        let required: OpenAICapabilities = [.textGeneration, .embeddings]
        #expect(!caps.supportsAll(required))
    }

    @Test("supportsAny returns true when at least one capability present")
    func supportsAnyPresent() {
        let caps = OpenAICapabilities.textOnly
        let check: OpenAICapabilities = [.textGeneration, .embeddings]
        #expect(caps.supportsAny(check))
    }

    @Test("supportsAny returns false when no capabilities present")
    func supportsAnyNonePresent() {
        let caps = OpenAICapabilities.textOnly
        let check: OpenAICapabilities = [.imageGeneration, .transcription]
        #expect(!caps.supportsAny(check))
    }

    // MARK: - missing(from:)

    @Test("missing returns capabilities that are not present")
    func missingReturnsAbsent() {
        let caps = OpenAICapabilities.textOnly
        let required: OpenAICapabilities = [.textGeneration, .embeddings, .vision]
        let missing = caps.missing(from: required)
        #expect(missing.contains(.embeddings))
        #expect(missing.contains(.vision))
        #expect(!missing.contains(.textGeneration))
    }

    @Test("missing returns empty when all capabilities present")
    func missingReturnsEmptyWhenAllPresent() {
        let caps = OpenAICapabilities.openAI
        let required: OpenAICapabilities = [.textGeneration, .streaming]
        let missing = caps.missing(from: required)
        #expect(missing.isEmpty)
    }

    // MARK: - Descriptions

    @Test("descriptions returns human-readable names")
    func descriptionsHumanReadable() {
        let caps: OpenAICapabilities = [.textGeneration, .streaming]
        let descs = caps.descriptions
        #expect(descs.contains("Text Generation"))
        #expect(descs.contains("Streaming"))
        #expect(descs.count == 2)
    }

    @Test("descriptions returns empty array for no capabilities")
    func descriptionsEmpty() {
        let caps = OpenAICapabilities(rawValue: 0)
        #expect(caps.descriptions.isEmpty)
    }

    @Test("All individual capabilities have descriptions")
    func allCapabilitiesHaveDescriptions() {
        let allIndividual: [OpenAICapabilities] = [
            .textGeneration, .streaming, .embeddings,
            .imageGeneration, .transcription, .functionCalling,
            .jsonMode, .vision, .textToSpeech,
            .parallelFunctionCalling, .structuredOutputs
        ]
        for cap in allIndividual {
            #expect(!cap.descriptions.isEmpty)
            #expect(cap.descriptions.count == 1)
        }
    }

    // MARK: - CustomStringConvertible

    @Test("Description for capabilities with flags lists them")
    func descriptionWithFlags() {
        let caps: OpenAICapabilities = [.textGeneration]
        #expect(caps.description.contains("Text Generation"))
        #expect(caps.description.hasPrefix("OpenAICapabilities("))
    }

    @Test("Description for empty capabilities says none")
    func descriptionEmpty() {
        let caps = OpenAICapabilities(rawValue: 0)
        #expect(caps.description == "OpenAICapabilities(none)")
    }

    // MARK: - OptionSet Operations

    @Test("Union of capability sets works")
    func unionWorks() {
        let a: OpenAICapabilities = [.textGeneration]
        let b: OpenAICapabilities = [.streaming]
        let combined = a.union(b)
        #expect(combined.contains(.textGeneration))
        #expect(combined.contains(.streaming))
    }

    @Test("Intersection of capability sets works")
    func intersectionWorks() {
        let a: OpenAICapabilities = [.textGeneration, .streaming, .vision]
        let b: OpenAICapabilities = [.streaming, .vision, .embeddings]
        let common = a.intersection(b)
        #expect(common.contains(.streaming))
        #expect(common.contains(.vision))
        #expect(!common.contains(.textGeneration))
        #expect(!common.contains(.embeddings))
    }

    @Test("Subtracting capability sets works")
    func subtractingWorks() {
        let a: OpenAICapabilities = [.textGeneration, .streaming, .vision]
        let b: OpenAICapabilities = [.streaming]
        let result = a.subtracting(b)
        #expect(result.contains(.textGeneration))
        #expect(result.contains(.vision))
        #expect(!result.contains(.streaming))
    }

    // MARK: - Endpoint Default Capabilities

    @Test("OpenAI endpoint returns openAI capabilities")
    func openAIEndpointCapabilities() {
        #expect(OpenAIEndpoint.openAI.defaultCapabilities == .openAI)
    }

    @Test("OpenRouter endpoint returns openRouter capabilities")
    func openRouterEndpointCapabilities() {
        #expect(OpenAIEndpoint.openRouter.defaultCapabilities == .openRouter)
    }

    @Test("Ollama endpoint returns ollama capabilities")
    func ollamaEndpointCapabilities() {
        #expect(OpenAIEndpoint.ollama().defaultCapabilities == .ollama)
    }

    @Test("Azure endpoint returns expected capabilities")
    func azureEndpointCapabilities() {
        let caps = OpenAIEndpoint.azure(resource: "r", deployment: "d", apiVersion: "v").defaultCapabilities
        #expect(caps.contains(.textGeneration))
        #expect(caps.contains(.streaming))
        #expect(caps.contains(.functionCalling))
        #expect(caps.contains(.jsonMode))
    }

    @Test("Custom endpoint returns textOnly capabilities")
    func customEndpointCapabilities() {
        let url = URL(string: "https://custom.com/v1")!
        #expect(OpenAIEndpoint.custom(url).defaultCapabilities == .textOnly)
    }

    // MARK: - Hashable / Sendable

    @Test("Capabilities are hashable for set usage")
    func hashable() {
        var set: Set<OpenAICapabilities> = []
        set.insert(.textOnly)
        set.insert(.openAI)
        set.insert(.textOnly)
        #expect(set.count == 2)
    }

    @Test("Sendable conformance compiles")
    func sendableConformance() {
        let caps: Sendable = OpenAICapabilities.openAI
        #expect(caps is OpenAICapabilities)
    }
}

#endif // CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
