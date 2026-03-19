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
    ],
    dependencies: [
        .package(path: "/Users/linhey/Downloads/libghostty-spm-main"),
    ],
    targets: [
        .target(
            name: "CanvasTerminalKit",
            dependencies: [
                .product(name: "GhosttyTerminal", package: "libghostty-spm-main"),
            ]
        ),
        .testTarget(
            name: "CanvasTerminalKitTests",
            dependencies: ["CanvasTerminalKit"]
        ),
    ]
)
