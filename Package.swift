// swift-tools-version: 5.10
import PackageDescription

// Pinned to Swift 5 language mode. Without this, an Xcode 16 toolchain
// (Swift 6 by default) promotes Sendability and actor-isolation warnings into
// fatal errors. The codebase is Swift 5-clean; Swift 6 migration is its own
// piece of work, not a precondition for CI.
//
// swift-tools 5.10 (minimum required Xcode 15.3) is needed to declare the
// swift-testing dependency below. Xcode 15 does not ship `Testing` as a
// system framework — it has to come through SPM. Xcode 16+ will prefer its
// built-in copy, and this declaration is forward-compatible.

let package = Package(
    name: "PixelPal",
    platforms: [.macOS(.v14)],
    dependencies: [
        // Pinned to exact 0.10.0 because later tags (0.11+, 0.99.0) ship a
        // swift-tools-version: 6.0 manifest, which Xcode 15 cannot parse —
        // resolution would fail before tests ever run. 0.10.0 is the last
        // release in the swift-tools 5.10 line and contains the API surface
        // we use (@Suite, @Test, #expect, #require).
        .package(url: "https://github.com/swiftlang/swift-testing.git", exact: "0.10.0"),
    ],
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
            dependencies: [
                "PixelPalCore",
                .product(name: "Testing", package: "swift-testing"),
            ],
            path: "Tests/PixelPalTests"
        )
    ],
    swiftLanguageVersions: [.v5]
)
