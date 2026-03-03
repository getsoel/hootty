// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Klaude",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "Klaude",
            dependencies: ["SwiftTerm"],
            path: "Sources/Klaude",
            exclude: ["Info.plist"],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-sectcreate",
                              "-Xlinker", "__TEXT",
                              "-Xlinker", "__info_plist",
                              "-Xlinker", "Sources/Klaude/Info.plist"]),
            ]
        ),
    ]
)
