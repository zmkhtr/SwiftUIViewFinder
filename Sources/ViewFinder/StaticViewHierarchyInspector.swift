import SwiftUI

/// Inspects a concrete root `View` value by evaluating application view bodies
/// and reflecting framework wrapper storage.
///
/// This does not inspect SwiftUI's live rendered graph. It is a feasibility
/// prototype that can recover many application component names from one root
/// integration point.
@MainActor
public struct StaticViewHierarchyInspector {
    public let options: HierarchyOptions

    public init(options: HierarchyOptions = .init()) {
        self.options = options
    }

    /// Builds a best-effort component hierarchy from a concrete root view.
    public func inspect<Root: View>(_ root: Root) -> InspectionReport {
        let result = inspectView(root, origin: .rootValue, depth: 0)
        let roots = collapse(result)

        return InspectionReport(
            roots: roots,
            warnings: [
                "This tree comes from a root View value, not SwiftUI's live rendered graph.",
                "Lazy, erased, environment-dependent, and state-dependent descendants may be missing.",
            ]
        )
    }

    private func inspectView<V: View>(
        _ view: V,
        origin: ComponentOrigin,
        depth: Int
    ) -> RawNode {
        let qualifiedName = String(reflecting: V.self)
        let meaningful = isMeaningfulApplicationType(qualifiedName)

        guard depth < options.maximumDepth else {
            return RawNode(
                name: displayName(for: qualifiedName),
                qualifiedName: qualifiedName,
                origin: origin,
                meaningful: meaningful,
                children: []
            )
        }

        let children: [RawNode]
        if meaningful && V.Body.self != Never.self {
            children = [inspectView(view.body, origin: .evaluatedBody, depth: depth + 1)]
        } else {
            children = inspectReflectedStorage(of: view, depth: depth + 1)
        }

        return RawNode(
            name: displayName(for: qualifiedName),
            qualifiedName: qualifiedName,
            origin: origin,
            meaningful: meaningful,
            children: children
        )
    }

    private func inspectExistentialView(
        _ view: any View,
        origin: ComponentOrigin,
        depth: Int
    ) -> RawNode {
        inspectView(view, origin: origin, depth: depth)
    }

    private func inspectReflectedStorage(of value: Any, depth: Int) -> [RawNode] {
        guard depth < options.maximumDepth else {
            return []
        }

        var nodes: [RawNode] = []
        for child in Mirror(reflecting: value).children {
            if let childView = child.value as? any View {
                nodes.append(
                    inspectExistentialView(
                        childView,
                        origin: .reflectedStorage,
                        depth: depth
                    )
                )
            } else if shouldDescendIntoStorage(child.value) {
                nodes.append(contentsOf: inspectReflectedStorage(of: child.value, depth: depth + 1))
            }
        }
        return nodes
    }

    private func shouldDescendIntoStorage(_ value: Any) -> Bool {
        let mirror = Mirror(reflecting: value)
        switch mirror.displayStyle {
        case .tuple, .optional, .collection, .enum:
            return true
        case .struct:
            let typeName = String(reflecting: mirror.subjectType)
            return options.frameworkModulePrefixes.contains { typeName.hasPrefix($0) }
        case .class, .dictionary, .set, .foreignReference, .none:
            return false
        @unknown default:
            return false
        }
    }

    private func collapse(_ node: RawNode) -> [ComponentNode] {
        let children = node.children.flatMap(collapse)
        if node.meaningful || options.includeFrameworkTypes {
            return [
                ComponentNode(
                    name: node.name,
                    qualifiedName: node.qualifiedName,
                    origin: node.origin,
                    children: deduplicated(children)
                )
            ]
        }
        return deduplicated(children)
    }

    private func deduplicated(_ nodes: [ComponentNode]) -> [ComponentNode] {
        var result: [ComponentNode] = []
        for node in nodes where result.last != node {
            result.append(node)
        }
        return result
    }

    private func isMeaningfulApplicationType(_ qualifiedName: String) -> Bool {
        !options.frameworkModulePrefixes.contains { qualifiedName.hasPrefix($0) }
    }

    private func displayName(for qualifiedName: String) -> String {
        let beforeGeneric = qualifiedName.split(separator: "<", maxSplits: 1).first.map(String.init)
            ?? qualifiedName
        return beforeGeneric.split(separator: ".").last.map(String.init) ?? beforeGeneric
    }

    private struct RawNode {
        let name: String
        let qualifiedName: String
        let origin: ComponentOrigin
        let meaningful: Bool
        let children: [RawNode]
    }
}
