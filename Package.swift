// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Hootty",
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
        .target(name: "HoottyCore", path: "Sources/HoottyCore"),
        .executableTarget(
            name: "Hootty",
            dependencies: ["CGhostty", "HoottyCore"],
            path: "Sources/Hootty",
            exclude: ["Info.plist"],
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
