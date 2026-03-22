// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Hootty",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/ChimeHQ/Neon", branch: "main"),
        .package(url: "https://github.com/tree-sitter-grammars/tree-sitter-markdown", from: "0.5.0"),
    ],
    targets: [
        .target(
            name: "CGhostty",
            path: "Sources/CGhostty",
            publicHeadersPath: "include",
            linkerSettings: [
                .unsafeFlags(["-L", "Vendors/lib"]),
                .linkedLibrary("ghostty"),
                .linkedLibrary("c++"),
                .linkedFramework("AppKit"),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("CoreText"),
                .linkedFramework("CoreVideo"),
                .linkedFramework("IOKit"),
                .linkedFramework("IOSurface"),
                .linkedFramework("Metal"),
                .linkedFramework("QuartzCore"),
                .linkedFramework("Carbon"),
            ]
        ),
        .target(
            name: "HoottyCore",
            path: "Sources/HoottyCore"
        ),
        .executableTarget(
            name: "Hootty",
            dependencies: [
                "CGhostty", "HoottyCore",
                .product(name: "Neon", package: "Neon"),
                .product(name: "TreeSitterMarkdown", package: "tree-sitter-markdown"),
            ],
            path: "Sources/Hootty",
            exclude: ["Info.plist"],
            resources: [.copy("Resources/bin"), .copy("Resources/Themes"), .copy("Resources/terminfo"), .copy("Resources/shell-integration")],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-sectcreate",
                              "-Xlinker", "__TEXT",
                              "-Xlinker", "__info_plist",
                              "-Xlinker", "Sources/Hootty/Info.plist"]),
            ]
        ),
        .testTarget(name: "HoottyCoreTests", dependencies: ["HoottyCore"]),
    ]
)
