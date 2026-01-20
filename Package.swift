// swift-tools-version: 6.2
import PackageDescription
import CompilerPluginSupport

// MARK: - Package Definition

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
            name: "MLX",
            description: "Enable MLX on-device inference (Apple Silicon only)"
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
                // MLX dependencies (only included when MLX trait is enabled)
                .product(name: "MLX", package: "mlx-swift", condition: .when(traits: ["MLX"])),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm", condition: .when(traits: ["MLX"])),
                .product(name: "MLXLLM", package: "mlx-swift-lm", condition: .when(traits: ["MLX"])),
                .product(name: "MLXVLM", package: "mlx-swift-lm", condition: .when(traits: ["MLX"])),
                .product(name: "StableDiffusion", package: "mlx-swift-examples", condition: .when(traits: ["MLX"])),
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "ConduitTests",
            dependencies: ["Conduit"],
            swiftSettings: [
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
