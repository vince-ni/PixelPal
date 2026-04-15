// swift-tools-version: 5.9
import PackageDescription

// Explicitly pin to Swift 5 language mode. Without this, an Xcode 16 toolchain
// (Swift 6 by default) promotes Sendability and actor-isolation warnings into
// fatal errors. The codebase is Swift 5-clean; Swift 6 migration is its own
// piece of work, not a precondition for CI.

let package = Package(
    name: "PixelPal",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "PixelPalCore",
            path: "Sources/PixelPalCore"
        ),
        .executableTarget(
            name: "PixelPal",
            dependencies: ["PixelPalCore"],
            path: "Sources/PixelPal"
        ),
        .testTarget(
            name: "PixelPalTests",
            dependencies: ["PixelPalCore"],
            path: "Tests/PixelPalTests"
        )
    ],
    swiftLanguageVersions: [.v5]
)
