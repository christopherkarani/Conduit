// MLXLocalModelSupportTests.swift
// ConduitTests

import Testing
import Conduit
@testable import ConduitAdvanced

#if CONDUIT_TRAIT_MLX && canImport(MLX)
@Suite("MLX Local Model Support")
struct MLXLocalModelSupportTests {

    @Test("facade model exposes local MLX paths")
    func facadeModelSupportsLocalMLXPaths() {
        let path = "/Users/me/models/Qwen3-8B-MLX-bf16"
        let model = Conduit.Model.mlxLocal(path)

        #expect(model.family == .mlxLocal)
        #expect(model.id == path)
    }

    @Test("Conduit facade accepts local MLX models in sessions")
    func facadeConduitAcceptsLocalMLXModels() throws {
        let app = Conduit.Conduit(Conduit.Provider.mlx())

        _ = try app.session(model: Conduit.Model.mlxLocal("/tmp/conduit-local-mlx-model"))
    }

    @Test("ConduitAdvanced accepts local MLX models in sessions")
    func advancedConduitAcceptsLocalMLXModels() throws {
        let app = ConduitAdvanced.Conduit(ConduitAdvanced.Provider.mlx())

        _ = try app.session(model: ConduitAdvanced.Model.mlxLocal("/tmp/conduit-local-mlx-model"))
    }
}
#endif
