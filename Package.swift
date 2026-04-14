// swift-tools-version: 5.9
import PackageDescription

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
    ]
)
