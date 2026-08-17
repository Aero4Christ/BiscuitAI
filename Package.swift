// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BiscuitAI",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "BiscuitAI",
            targets: ["BiscuitAI"]
        )
    ],
    targets: [
        .executableTarget(
            name: "BiscuitAI",
            path: "Sources/BiscuitAI",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "BiscuitAITests",
            dependencies: ["BiscuitAI"],
            path: "Tests/BiscuitAITests"
        )
    ]
)
