// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SwiftUIViewFinder",
    platforms: [
        .iOS(.v15),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "ViewFinder",
            targets: ["ViewFinder"]
        ),
        .library(
            name: "viewFinder",
            targets: ["ViewFinder"]
        ),
        .executable(
            name: "ViewFinderResearch",
            targets: ["ViewFinderResearch"]
        ),
    ],
    targets: [
        .target(
            name: "ViewFinder"
        ),
        .executableTarget(
            name: "ViewFinderResearch",
            dependencies: ["ViewFinder"]
        ),
        .testTarget(
            name: "ViewFinderTests",
            dependencies: ["ViewFinder"]
        ),
    ]
)
