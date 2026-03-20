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
            name: "FolderCard",
            targets: ["FolderCard"]
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
        .package(url: "https://github.com/linhay/STFilePath.git", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "InfiniteCanvasKit",
            dependencies: [
                .product(name: "STFilePath", package: "STFilePath"),
            ]
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
            name: "FolderCard",
            dependencies: [
                "InfiniteCanvasKit",
            ],
            path: "Sources/FolderCard"
        ),
        .target(
            name: "CanvasKit",
            dependencies: [
                "InfiniteCanvasKit",
                "TerminalCard",
                "FolderCard",
            ]
        ),
        .testTarget(
            name: "CanvasKitTests",
            dependencies: [
                "CanvasKit",
                "InfiniteCanvasKit",
                "FolderCard",
            ],
            path: "Tests/CanvasKitTests"
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
        .testTarget(
            name: "FolderCardTests",
            dependencies: ["FolderCard"],
            path: "Tests/FolderCardTests"
        ),
    ]
)
