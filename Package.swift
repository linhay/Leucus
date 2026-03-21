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
            name: "WebCard",
            targets: ["WebCard"]
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
            name: "CardHubService",
            targets: ["CardHubService"]
        ),
        .library(
            name: "InfiniteCanvasKit",
            targets: ["InfiniteCanvasKit"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/linhay/libghostty.git", exact: "0.0.2"),
        .package(url: "https://github.com/linhay/STFilePath.git", from: "1.3.0"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", from: "2.3.0"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.106.0"),
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
                .product(name: "GhosttyKit", package: "libghostty"),
                .product(name: "GhosttyTerminal", package: "libghostty"),
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
            name: "WebCard",
            dependencies: [],
            path: "Sources/WebCard"
        ),
        .target(
            name: "CardHubService",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
            ],
            path: "Sources/CardHubService"
        ),
        .target(
            name: "CanvasKit",
            dependencies: [
                "InfiniteCanvasKit",
                "TerminalCard",
                "FolderCard",
                "WebCard",
                "CardHubService",
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
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
        .testTarget(
            name: "WebCardTests",
            dependencies: ["WebCard"],
            path: "Tests/WebCardTests"
        ),
        .testTarget(
            name: "CardHubServiceTests",
            dependencies: [
                "CardHubService",
                .product(name: "XCTVapor", package: "vapor"),
            ],
            path: "Tests/CardHubServiceTests"
        ),
    ]
)
