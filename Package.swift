// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SwiftUIInspector",
    platforms: [
        .iOS(.v15),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "SwiftUIInspector",
            targets: ["SwiftUIInspector"]
        ),
        .executable(
            name: "SwiftUIInspectorResearch",
            targets: ["SwiftUIInspectorResearch"]
        ),
    ],
    targets: [
        .target(
            name: "SwiftUIInspector"
        ),
        .executableTarget(
            name: "SwiftUIInspectorResearch",
            dependencies: ["SwiftUIInspector"]
        ),
        .testTarget(
            name: "SwiftUIInspectorTests",
            dependencies: ["SwiftUIInspector"]
        ),
    ]
)
