// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CaptionKit",
    platforms: [
        .macOS(.v26),
        .iOS(.v26)
    ],
    products: [
        // The caption engine — model, grouping, renderer, export, and the
        // automatic passes (emphasis, emoji, hook title, translation
        // re-timing). Headless: no UI frameworks, no network, no generative
        // AI. The whole pipeline runs in a unit test or a command-line tool.
        //
        // One product. CaptionStyles (the style model and presets) and
        // CaptionCore (words, cards, layout, export plumbing) stay separate
        // TARGETS — they keep the style data free of AVFoundation and Vision —
        // but CaptionKit re-exports both, and nothing outside this package
        // imports them on their own any more: the editor engine that did is
        // archived.
        .library(
            name: "CaptionKit",
            targets: ["CaptionKit"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/arraypress/swift-subtitle-kit.git", from: "0.1.0"),
        // Background separation by depth. The only external package: 186
        // lines, no model weights, no dependencies of its own. Everything
        // else here is an Apple framework.
        .package(url: "https://github.com/arraypress/swift-depth-blur.git", from: "0.1.0"),
        // Style slots, `--var` and catalogue checks, shared with imagine and song.
        .package(url: "https://github.com/arraypress/swift-recipe-kit.git", from: "0.2.0"),
    ],
    targets: [
        .target(
            name: "CaptionStyles",
            dependencies: [
                .product(name: "RecipeKit", package: "swift-recipe-kit"),
            ]
        ),
        .target(
            name: "CaptionCore",
            dependencies: [
                "CaptionStyles",
                .product(name: "SubtitleKit", package: "swift-subtitle-kit"),
            ]
        ),
        .target(
            name: "CaptionKit",
            dependencies: [
                "CaptionCore",
                "CaptionStyles",
                .product(name: "DepthBlur", package: "swift-depth-blur"),
            ]
        ),
        .testTarget(
            name: "CaptionKitTests",
            dependencies: ["CaptionKit", "CaptionCore", "CaptionStyles"]
        ),
    ]
)

// Swift 7's import rule, today: a file must import every module whose members
// it uses, rather than leaning on another file's imports.
for target in package.targets where target.type != .system && target.type != .binary && target.type != .plugin {
    target.swiftSettings = (target.swiftSettings ?? []) + [.enableUpcomingFeature("MemberImportVisibility")]
}
