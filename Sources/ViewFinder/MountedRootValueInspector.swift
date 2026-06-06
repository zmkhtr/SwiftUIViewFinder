#if canImport(UIKit)
import SwiftUI

@MainActor
enum MountedRootValueInspector {
    static func currentRoots<Root: View>(in root: Root) -> [ComponentNode] {
        var visitedValueCount = 0
        return collectApplicationViews(
            in: root,
            depth: 0,
            includeImmediateBody: true,
            visitedValueCount: &visitedValueCount
        )
    }

    private static func collectApplicationViews(
        in value: Any,
        depth: Int,
        includeImmediateBody: Bool,
        visitedValueCount: inout Int
    ) -> [ComponentNode] {
        guard depth < 48, visitedValueCount < 5_000 else { return [] }
        visitedValueCount += 1

        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .class {
            return []
        }

        if let view = value as? any View {
            let type = String(reflecting: type(of: view))
            if isApplicationType(type) {
                let children = includeImmediateBody
                    ? immediateApplicationChildren(of: view, visitedValueCount: &visitedValueCount)
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

        return mirror.children.flatMap {
            collectApplicationViews(
                in: $0.value,
                depth: depth + 1,
                includeImmediateBody: includeImmediateBody,
                visitedValueCount: &visitedValueCount
            )
        }
    }

    private static func immediateApplicationChildren(
        of view: any View,
        visitedValueCount: inout Int
    ) -> [ComponentNode] {
        inspectImmediateBody(of: view, visitedValueCount: &visitedValueCount)
    }

    private static func inspectImmediateBody<V: View>(
        of view: V,
        visitedValueCount: inout Int
    ) -> [ComponentNode] {
        guard V.Body.self != Never.self else { return [] }
        return collectApplicationViews(
            in: view.body,
            depth: 0,
            includeImmediateBody: false,
            visitedValueCount: &visitedValueCount
        )
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
