// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CanvasTerminalKit",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "TerminalCard",
            targets: ["TerminalCard"]
        ),
        .library(
            name: "CanvasKit",
            targets: ["CanvasKit"]
        ),
        .library(
            name: "InfiniteCanvasKit",
            targets: ["InfiniteCanvasKit"]
        ),
    ],
    dependencies: [
        .package(path: "/Users/linhey/Downloads/libghostty-spm-main"),
    ],
    targets: [
        .target(
            name: "InfiniteCanvasKit"
        ),
        .target(
            name: "TerminalCard",
            dependencies: [
                .product(name: "GhosttyKit", package: "libghostty-spm-main"),
                .product(name: "GhosttyTerminal", package: "libghostty-spm-main"),
            ],
            path: "Sources/TerminalCard",
            swiftSettings: [
                .unsafeFlags(["-swift-version", "5"]),
                .unsafeFlags(["-Xfrontend", "-strict-concurrency=minimal"]),
            ]
        ),
        .target(
            name: "CanvasKit",
            dependencies: [
                "InfiniteCanvasKit",
                "TerminalCard",
            ]
        ),
        .testTarget(
            name: "InfiniteCanvasKitTests",
            dependencies: ["InfiniteCanvasKit"]
        ),
        .testTarget(
            name: "TerminalCardTests",
            dependencies: ["TerminalCard"],
            path: "Tests/TerminalCardTests"
        ),
    ]
)
