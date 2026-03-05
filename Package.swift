// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Promptty",
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
        .target(name: "PrompttyCore", path: "Sources/PrompttyCore"),
        .executableTarget(
            name: "Promptty",
            dependencies: ["CGhostty", "PrompttyCore"],
            path: "Sources/Promptty",
            exclude: ["Info.plist"],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-sectcreate",
                              "-Xlinker", "__TEXT",
                              "-Xlinker", "__info_plist",
                              "-Xlinker", "Sources/Promptty/Info.plist"]),
            ]
        ),
        .testTarget(name: "PrompttyCoreTests", dependencies: ["PrompttyCore"]),
    ]
)
