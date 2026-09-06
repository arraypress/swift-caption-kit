// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CaptionKitLite",
    platforms: [
        .macOS(.v26),
        .iOS(.v26)
    ],
    products: [
        // The caption engine — model, grouping, renderer, export. Headless:
        // no UI frameworks, no network, no AI. The whole pipeline runs in a
        // unit test or a command-line tool.
        .library(
            name: "CaptionKitLite",
            targets: ["CaptionKitLite"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/arraypress/swift-subtitle-kit.git", from: "0.1.0"),
        // Background separation by depth. The only external package: 186
        // lines, no model weights, no dependencies of its own. Everything
        // else here is an Apple framework.
        .package(url: "https://github.com/arraypress/swift-depth-blur.git", from: "0.1.0"),
    ],
    targets: [
        .target(
            name: "CaptionKitLite",
            dependencies: [
                .product(name: "SubtitleKit", package: "swift-subtitle-kit"),
                .product(name: "DepthBlur", package: "swift-depth-blur"),
            ]
        ),
        .testTarget(
            name: "CaptionKitLiteTests",
            dependencies: ["CaptionKitLite"]
        ),
    ]
)
