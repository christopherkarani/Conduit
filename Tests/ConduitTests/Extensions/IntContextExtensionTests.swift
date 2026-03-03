// IntContextExtensionTests.swift
// ConduitTests

import Foundation
import Testing
@testable import Conduit

@Suite("Int Context Extension Tests")
struct IntContextExtensionTests {

    // MARK: - Context Window Constants

    @Test("context4K is 4096")
    func context4K() {
        #expect(Int.context4K == 4_096)
    }

    @Test("context8K is 8192")
    func context8K() {
        #expect(Int.context8K == 8_192)
    }

    @Test("context16K is 16384")
    func context16K() {
        #expect(Int.context16K == 16_384)
    }

    @Test("context32K is 32768")
    func context32K() {
        #expect(Int.context32K == 32_768)
    }

    @Test("context64K is 65536")
    func context64K() {
        #expect(Int.context64K == 65_536)
    }

    @Test("context128K is 131072")
    func context128K() {
        #expect(Int.context128K == 131_072)
    }

    @Test("context200K is 200000")
    func context200K() {
        #expect(Int.context200K == 200_000)
    }

    @Test("context1M is 1000000")
    func context1M() {
        #expect(Int.context1M == 1_000_000)
    }

    // MARK: - contextDescription

    @Test("Standard sizes have colloquial descriptions",
          arguments: [
            (Int.context4K, "4K"),
            (Int.context8K, "8K"),
            (Int.context16K, "16K"),
            (Int.context32K, "32K"),
            (Int.context64K, "64K"),
            (Int.context128K, "128K"),
            (Int.context200K, "200K"),
            (Int.context1M, "1M")
          ])
    func standardContextDescriptions(size: Int, expected: String) {
        #expect(size.contextDescription == expected)
    }

    @Test("Non-standard sizes use binary K")
    func nonStandardDescription() {
        let size = 2048
        #expect(size.contextDescription == "2K")
    }

    @Test("Large non-standard sizes use M")
    func largeSizeDescription() {
        let size = 2_000_000
        #expect(size.contextDescription == "2M")
    }

    @Test("Small values shown as-is")
    func smallSizeDescription() {
        let size = 512
        #expect(size.contextDescription == "512")
    }

    // MARK: - isStandardContextSize

    @Test("Standard sizes return true for isStandardContextSize",
          arguments: [
            Int.context4K,
            .context8K,
            .context16K,
            .context32K,
            .context64K,
            .context128K,
            .context200K,
            .context1M
          ])
    func isStandard(size: Int) {
        #expect(size.isStandardContextSize)
    }

    @Test("Non-standard size returns false")
    func isNotStandard() {
        #expect(!2048.isStandardContextSize)
        #expect(!10000.isStandardContextSize)
    }
}
