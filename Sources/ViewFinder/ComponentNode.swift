import Foundation

/// The mechanism that discovered a component node.
public enum ComponentOrigin: String, Codable, Sendable {
    case rootValue
    case evaluatedBody
    case reflectedStorage
    case renderedGraph
    case uiKit
}

/// A discovered component or framework view in an inspection hierarchy.
public struct ComponentNode: Codable, Equatable, Sendable {
    /// A short, human-readable type name.
    public let name: String

    /// The full reflected Swift type name when available.
    public let qualifiedName: String

    /// The mechanism that discovered this node.
    public let origin: ComponentOrigin

    /// Child components after wrapper filtering.
    public var children: [ComponentNode]

    public init(
        name: String,
        qualifiedName: String,
        origin: ComponentOrigin,
        children: [ComponentNode] = []
    ) {
        self.name = name
        self.qualifiedName = qualifiedName
        self.origin = origin
        self.children = children
    }

    /// Formats the hierarchy as a tree suitable for console output.
    public func formattedTree() -> String {
        formattedLines(prefix: "", isLast: true, isRoot: true).joined(separator: "\n")
    }

    /// Returns all names in depth-first order.
    public var flattenedNames: [String] {
        [name] + children.flatMap(\.flattenedNames)
    }

    private func formattedLines(prefix: String, isLast: Bool, isRoot: Bool) -> [String] {
        let marker = isRoot ? "" : (isLast ? "└─ " : "├─ ")
        let line = prefix + marker + name
        let childPrefix = isRoot ? "" : prefix + (isLast ? "   " : "│  ")

        return [line] + children.enumerated().flatMap { index, child in
            child.formattedLines(
                prefix: childPrefix,
                isLast: index == children.count - 1,
                isRoot: false
            )
        }
    }
}

/// A complete result from one hierarchy inspection attempt.
public struct InspectionReport: Sendable {
    /// The discovered component roots.
    public let roots: [ComponentNode]

    /// Warnings explaining incomplete or uncertain output.
    public let warnings: [String]

    public init(roots: [ComponentNode], warnings: [String] = []) {
        self.roots = roots
        self.warnings = warnings
    }

    /// Formats all discovered roots and warnings for console output.
    public func formatted() -> String {
        let tree = roots.map { $0.formattedTree() }.joined(separator: "\n")
        guard !warnings.isEmpty else {
            return tree
        }

        let warningText = warnings.map { "[ViewFinder] Warning: \($0)" }.joined(separator: "\n")
        return tree.isEmpty ? warningText : "\(tree)\n\n\(warningText)"
    }
}
