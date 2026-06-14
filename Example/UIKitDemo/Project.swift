import ProjectDescription

let project = Project(
    name: "UIKitDemo",
    targets: [
        .target(
            name: "UIKitDemo",
            destinations: .iOS,
            product: .app,
            bundleId: "dev.swiftui-inspector.uikit-demo",
            deploymentTargets: .iOS("15.0"),
            infoPlist: .extendingDefault(with: [
                "UILaunchScreen": [:],
            ]),
            sources: ["Sources/**"],
            dependencies: [
                .external(name: "SwiftUIInspector"),
            ]
        ),
        .target(
            name: "UIKitDemoUITests",
            destinations: .iOS,
            product: .uiTests,
            bundleId: "dev.swiftui-inspector.uikit-demo-ui-tests",
            deploymentTargets: .iOS("15.0"),
            infoPlist: .default,
            sources: ["UITests/**"],
            dependencies: [
                .target(name: "UIKitDemo"),
            ]
        ),
    ]
)
