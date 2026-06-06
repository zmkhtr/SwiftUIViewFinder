/// Configuration for root-value hierarchy inspection.
public struct HierarchyOptions: Sendable {
    /// Maximum recursion depth for body evaluation and reflected storage.
    public var maximumDepth: Int

    /// Include SwiftUI and other framework wrapper nodes in the output.
    public var includeFrameworkTypes: Bool

    /// Module prefixes treated as framework implementation details.
    public var frameworkModulePrefixes: [String]

    public init(
        maximumDepth: Int = 40,
        includeFrameworkTypes: Bool = false,
        frameworkModulePrefixes: [String] = HierarchyOptions.defaultFrameworkModulePrefixes
    ) {
        self.maximumDepth = maximumDepth
        self.includeFrameworkTypes = includeFrameworkTypes
        self.frameworkModulePrefixes = frameworkModulePrefixes
    }

    public static let defaultFrameworkModulePrefixes = [
        "Swift.",
        "SwiftUI.",
        "SwiftUICore.",
        "Foundation.",
        "CoreFoundation.",
        "CoreGraphics.",
        "UIKit.",
        "AppKit.",
        "Combine.",
        "Observation.",
        "ViewFinder.",
    ]
}
