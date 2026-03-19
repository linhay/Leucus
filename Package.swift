// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CanvasTerminalKit",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CanvasTerminalKit",
            targets: ["CanvasTerminalKit"]
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
            name: "CanvasTerminalKit",
            dependencies: [
                "InfiniteCanvasKit",
                .product(name: "GhosttyTerminal", package: "libghostty-spm-main"),
            ]
        ),
        .testTarget(
            name: "InfiniteCanvasKitTests",
            dependencies: ["InfiniteCanvasKit"]
        ),
        .testTarget(
            name: "CanvasTerminalKitTests",
            dependencies: ["CanvasTerminalKit"]
        ),
    ]
)
