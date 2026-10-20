// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "HideNotch",
    defaultLocalization: "en",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.10.0"),
    ],
    targets: [
        .target(name: "HideNotchCore", dependencies: [.product(name: "Sparkle", package: "Sparkle")],
                resources: [.process("Resources")]),
        .executableTarget(name: "HideNotch", dependencies: ["HideNotchCore"]),
        .executableTarget(name: "IconGen", dependencies: ["HideNotchCore"]),
        .testTarget(name: "HideNotchTests", dependencies: ["HideNotchCore"]),
    ]
)
