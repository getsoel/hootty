// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Klaude",
    platforms: [.macOS(.v14)],
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
        .target(name: "KlaudeCore", path: "Sources/KlaudeCore"),
        .executableTarget(
            name: "Klaude",
            dependencies: ["CGhostty", "KlaudeCore"],
            path: "Sources/Klaude",
            exclude: ["Info.plist"],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-sectcreate",
                              "-Xlinker", "__TEXT",
                              "-Xlinker", "__info_plist",
                              "-Xlinker", "Sources/Klaude/Info.plist"]),
            ]
        ),
        .testTarget(name: "KlaudeCoreTests", dependencies: ["KlaudeCore"]),
    ]
)
