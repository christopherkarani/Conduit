// swift-tools-version: 6.2
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "Conduit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "Conduit",
            targets: ["Conduit"]
        ),
    ],
    traits: [
        .trait(
            name: "OpenAI",
            description: "Enable OpenAI-compatible providers (OpenAI, Azure OpenAI, Ollama, custom endpoints)"
        ),
        .trait(
            name: "OpenRouter",
            description: "Enable OpenRouter support (OpenAI-compatible via OpenAIProvider)"
        ),
        .trait(
            name: "Anthropic",
            description: "Enable Anthropic Claude provider support"
        ),
        .trait(
            name: "MLX",
            description: "Enable MLX on-device inference (Apple Silicon only)"
        ),
        .trait(
            name: "HuggingFaceHub",
            description: "Enable Hugging Face Hub downloads via swift-huggingface"
        ),
        .trait(
            name: "Llama",
            description: "Enable llama.cpp local inference via llama.swift"
        ),
        .default(enabledTraits: []),
    ],
    dependencies: [
        // MARK: Cross-Platform Dependencies
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.1.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.8.0"),

        // MARK: MLX Dependencies (Apple Silicon Only)
        .package(url: "https://github.com/ml-explore/mlx-swift.git", from: "0.29.1"),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm.git", from: "2.29.2"),
        .package(url: "https://github.com/ml-explore/mlx-swift-examples.git", revision: "fc3afc7cdbc4b6120d210c4c58c6b132ce346775"),

        // MARK: Hugging Face Hub (Optional)
        .package(url: "https://github.com/huggingface/swift-huggingface", branch: "main"),

        // MARK: llama.cpp (Optional)
        .package(url: "https://github.com/mattt/llama.swift", .upToNextMajor(from: "2.7484.0")),
    ],
    targets: [
        .macro(
            name: "ConduitMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
            ],
            path: "Sources/ConduitMacros"
        ),
        .target(
            name: "Conduit",
            dependencies: [
                "ConduitMacros",
                .product(name: "OrderedCollections", package: "swift-collections"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "HuggingFace", package: "swift-huggingface", condition: .when(traits: ["HuggingFaceHub"])),
                // MLX dependencies (only included when MLX trait is enabled)
                .product(name: "MLX", package: "mlx-swift", condition: .when(traits: ["MLX"])),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm", condition: .when(traits: ["MLX"])),
                .product(name: "MLXLLM", package: "mlx-swift-lm", condition: .when(traits: ["MLX"])),
                .product(name: "MLXVLM", package: "mlx-swift-lm", condition: .when(traits: ["MLX"])),
                .product(name: "StableDiffusion", package: "mlx-swift-examples", condition: .when(traits: ["MLX"])),
                .product(name: "LlamaSwift", package: "llama.swift", condition: .when(traits: ["Llama"])),
            ],
            swiftSettings: [
                .define("CONDUIT_TRAIT_OPENAI", .when(traits: ["OpenAI"])),
                .define("CONDUIT_TRAIT_OPENROUTER", .when(traits: ["OpenRouter"])),
                .define("CONDUIT_TRAIT_ANTHROPIC", .when(traits: ["Anthropic"])),
                .define("CONDUIT_TRAIT_MLX", .when(traits: ["MLX"])),
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "ConduitTests",
            dependencies: [
                "Conduit",
            ],
            swiftSettings: [
                .define("CONDUIT_TRAIT_OPENAI", .when(traits: ["OpenAI"])),
                .define("CONDUIT_TRAIT_OPENROUTER", .when(traits: ["OpenRouter"])),
                .define("CONDUIT_TRAIT_ANTHROPIC", .when(traits: ["Anthropic"])),
                .define("CONDUIT_TRAIT_MLX", .when(traits: ["MLX"])),
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "ConduitMacrosTests",
            dependencies: [
                "Conduit",
                "ConduitMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ],
            path: "Tests/ConduitMacrosTests"
        ),
    ]
)
