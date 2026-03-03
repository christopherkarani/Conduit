// WarmupConfigTests.swift
// ConduitTests

import Foundation
import Testing
@testable import Conduit

@Suite("WarmupConfig Tests")
struct WarmupConfigTests {

    // MARK: - Static Presets

    @Test("default preset has warmupOnInit false")
    func defaultPreset() {
        let config = WarmupConfig.default

        #expect(!config.warmupOnInit)
        #expect(config.prefillChars == 50)
        #expect(config.warmupTokens == 5)
    }

    @Test("eager preset has warmupOnInit true")
    func eagerPreset() {
        let config = WarmupConfig.eager

        #expect(config.warmupOnInit)
        #expect(config.prefillChars == 50)
        #expect(config.warmupTokens == 5)
    }

    // MARK: - Custom Initialization

    @Test("Custom init stores all properties")
    func customInit() {
        let config = WarmupConfig(
            warmupOnInit: true,
            prefillChars: 100,
            warmupTokens: 10
        )

        #expect(config.warmupOnInit)
        #expect(config.prefillChars == 100)
        #expect(config.warmupTokens == 10)
    }

    @Test("Default parameter values in init")
    func defaultParameters() {
        let config = WarmupConfig()

        #expect(!config.warmupOnInit)
        #expect(config.prefillChars == 50)
        #expect(config.warmupTokens == 5)
    }

    // MARK: - Mutability

    @Test("Properties are mutable")
    func mutability() {
        var config = WarmupConfig.default

        config.warmupOnInit = true
        config.prefillChars = 200
        config.warmupTokens = 20

        #expect(config.warmupOnInit)
        #expect(config.prefillChars == 200)
        #expect(config.warmupTokens == 20)
    }

    // MARK: - Sendable

    @Test("WarmupConfig is Sendable")
    func sendable() {
        let config = WarmupConfig.eager
        Task {
            // This compiles only if WarmupConfig is Sendable
            _ = config.warmupOnInit
        }
    }
}
