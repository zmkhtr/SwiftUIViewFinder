/// Controls whether root-value inspection may execute application `body`
/// properties outside SwiftUI's mounted environment.
public enum BodyEvaluationPolicy: Sendable {
    /// Never execute application view bodies.
    ///
    /// This is the safe default. It avoids traps from `@EnvironmentObject`,
    /// environment values, and other dynamic properties that SwiftUI has not
    /// installed on the reflected view value.
    case disabled

    /// Execute application view bodies during root-value inspection.
    ///
    /// This can recover deeper conceptual hierarchies, but may crash when a
    /// body reads SwiftUI-managed dynamic properties. Use only in controlled
    /// research experiments.
    case unsafe
}

/// Configuration for root-value hierarchy inspection.
public struct HierarchyOptions: Sendable {
    /// Maximum recursion depth for body evaluation and reflected storage.
    public var maximumDepth: Int

    /// Include SwiftUI and other framework wrapper nodes in the output.
    public var includeFrameworkTypes: Bool

    /// Module prefixes treated as framework implementation details.
    public var frameworkModulePrefixes: [String]

    /// Whether application view bodies may be executed by the inspector.
    public var bodyEvaluationPolicy: BodyEvaluationPolicy

    public init(
        maximumDepth: Int = 40,
        includeFrameworkTypes: Bool = false,
        frameworkModulePrefixes: [String] = HierarchyOptions.defaultFrameworkModulePrefixes,
        bodyEvaluationPolicy: BodyEvaluationPolicy = .disabled
    ) {
        self.maximumDepth = maximumDepth
        self.includeFrameworkTypes = includeFrameworkTypes
        self.frameworkModulePrefixes = frameworkModulePrefixes
        self.bodyEvaluationPolicy = bodyEvaluationPolicy
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
        "SwiftUIInspector.",
    ]
}
