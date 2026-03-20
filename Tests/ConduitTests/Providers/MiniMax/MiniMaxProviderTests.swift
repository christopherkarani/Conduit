#if CONDUIT_TRAIT_MINIMAX && CONDUIT_TRAIT_OPENAI
import Foundation
import Testing
import Conduit
@testable import ConduitAdvanced

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

@Suite("MiniMax Provider Tests")
struct MiniMaxProviderTests {

    @Test("MiniMaxModelID exposes M2.7 variants and Codable round-trips")
    func miniMaxModelIDRoundTrip() throws {
        let flagship = MiniMaxModelID.minimaxM2_7
        let highspeed = MiniMaxModelID.minimaxM2_7Highspeed

        #expect(flagship.rawValue == "MiniMax-M2.7")
        #expect(flagship.displayName == "MiniMax-M2.7")
        #expect(flagship.provider == .minimax)

        #expect(highspeed.rawValue == "MiniMax-M2.7-highspeed")
        #expect(highspeed.displayName == "MiniMax-M2.7-highspeed")
        #expect(highspeed.provider == .minimax)

        let encodedFlagship = try JSONEncoder().encode(flagship)
        let decodedFlagship = try JSONDecoder().decode(MiniMaxModelID.self, from: encodedFlagship)
        #expect(decodedFlagship.rawValue == flagship.rawValue)
        #expect(decodedFlagship.provider == flagship.provider)

        let encodedHighspeed = try JSONEncoder().encode(highspeed)
        let decodedHighspeed = try JSONDecoder().decode(MiniMaxModelID.self, from: encodedHighspeed)
        #expect(decodedHighspeed.rawValue == highspeed.rawValue)
        #expect(decodedHighspeed.provider == highspeed.provider)
    }

    @Test("ModelIdentifier exposes M2.7 variants and Codable round-trips")
    func modelIdentifierRoundTrip() throws {
        let flagship = ModelIdentifier.minimaxM2_7
        let highspeed = ModelIdentifier.minimaxM2_7Highspeed

        #expect(flagship.rawValue == "MiniMax-M2.7")
        #expect(flagship.provider == .minimax)

        #expect(highspeed.rawValue == "MiniMax-M2.7-highspeed")
        #expect(highspeed.provider == .minimax)

        let encodedFlagship = try JSONEncoder().encode(flagship)
        let decodedFlagship = try JSONDecoder().decode(ModelIdentifier.self, from: encodedFlagship)
        #expect(decodedFlagship.rawValue == flagship.rawValue)
        #expect(decodedFlagship.provider == flagship.provider)

        let encodedHighspeed = try JSONEncoder().encode(highspeed)
        let decodedHighspeed = try JSONDecoder().decode(ModelIdentifier.self, from: encodedHighspeed)
        #expect(decodedHighspeed.rawValue == highspeed.rawValue)
        #expect(decodedHighspeed.provider == highspeed.provider)
    }

    @Test("MiniMax default configuration uses official API base URL")
    func defaultConfigurationBaseURL() {
        let configuration = MiniMaxConfiguration.standard(apiKey: nil)
        #expect(configuration.baseURL.absoluteString == "https://api.minimax.io/v1")
    }

    @Test("Facade Model exposes explicit MiniMax M2.7 selection")
    func facadeModelExplicitMiniMaxSelection() {
        let _ = Conduit.Provider.miniMax()
        let model = Conduit.Model.miniMax("MiniMax-M2.7")

        #expect(model.id == "MiniMax-M2.7")
        #expect(model.family == .miniMax)
    }

    @Test("Facade Provider.miniMax uses MINIMAX_API_KEY environment path")
    func facadeProviderUsesEnvironmentAPIKey() async throws {
        let original = getenv("MINIMAX_API_KEY").map { String(cString: $0) }
        defer {
            if let original {
                setenv("MINIMAX_API_KEY", original, 1)
            } else {
                unsetenv("MINIMAX_API_KEY")
            }
        }

        setenv("MINIMAX_API_KEY", "env-mini-max-key", 1)

        let provider = MiniMaxProvider()
        #expect(await provider.isAvailable)
    }
}

#endif
