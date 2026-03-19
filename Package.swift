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
    targets: [
        .target(
            name: "CanvasTerminalKit"
        ),
        .testTarget(
            name: "CanvasTerminalKitTests",
            dependencies: ["CanvasTerminalKit"]
        ),
    ]
)
