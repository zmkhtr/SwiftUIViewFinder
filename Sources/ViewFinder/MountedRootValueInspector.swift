#if canImport(UIKit)
import SwiftUI

@MainActor
enum MountedRootValueInspector {
    static func currentRoots<Root: View>(in root: Root) -> [ComponentNode] {
        collectApplicationViews(in: root, depth: 0, includeImmediateBody: true)
    }

    private static func collectApplicationViews(
        in value: Any,
        depth: Int,
        includeImmediateBody: Bool
    ) -> [ComponentNode] {
        guard depth < 48 else { return [] }

        if let view = value as? any View {
            let type = String(reflecting: type(of: view))
            if isApplicationType(type) {
                let children = includeImmediateBody
                    ? immediateApplicationChildren(of: view)
                    : []
                return [
                    ComponentNode(
                        name: readableName(from: type),
                        qualifiedName: type,
                        origin: .reflectedStorage,
                        children: children
                    )
                ]
            }
        }

        return Mirror(reflecting: value).children.flatMap {
            collectApplicationViews(
                in: $0.value,
                depth: depth + 1,
                includeImmediateBody: includeImmediateBody
            )
        }
    }

    private static func immediateApplicationChildren(of view: any View) -> [ComponentNode] {
        inspectImmediateBody(of: view)
    }

    private static func inspectImmediateBody<V: View>(of view: V) -> [ComponentNode] {
        guard V.Body.self != Never.self else { return [] }
        return collectApplicationViews(in: view.body, depth: 0, includeImmediateBody: false)
    }

    private static func isApplicationType(_ type: String) -> Bool {
        !HierarchyOptions.defaultFrameworkModulePrefixes.contains { type.hasPrefix($0) }
            && !type.hasPrefix("__C.")
            && !type.hasPrefix("AttributeGraph.")
            && !type.hasPrefix("ViewFinder.")
    }

    private static func readableName(from qualifiedName: String) -> String {
        let withoutContext = qualifiedName.replacingOccurrences(
            of: #"\.\(unknown context at \$[0-9a-f]+\)"#,
            with: "",
            options: .regularExpression
        )
        let beforeGeneric = withoutContext.split(separator: "<", maxSplits: 1).first.map(String.init)
            ?? withoutContext
        return beforeGeneric.split(separator: ".").last.map(String.init) ?? beforeGeneric
    }
}
#endif
