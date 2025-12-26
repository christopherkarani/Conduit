// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftAI",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "SwiftAI",
            targets: ["SwiftAI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift.git", from: "0.21.0"),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm.git", from: "2.29.0"),
        .package(url: "https://github.com/huggingface/swift-huggingface.git", from: "0.4.0"),
        .package(url: "https://github.com/ml-explore/mlx-swift-examples.git", revision: "fc3afc7cdbc4b6120d210c4c58c6b132ce346775"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.1.0"),
    ],
    targets: [
        .target(
            name: "SwiftAI",
            dependencies: [
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXVLM", package: "mlx-swift-lm"),
                .product(name: "HuggingFace", package: "swift-huggingface"),
                .product(name: "StableDiffusion", package: "mlx-swift-examples"),
                .product(name: "OrderedCollections", package: "swift-collections"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "SwiftAITests",
            dependencies: ["SwiftAI"]
        ),
    ]
)
