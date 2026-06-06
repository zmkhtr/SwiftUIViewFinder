#if canImport(UIKit)
import CoreGraphics
import Foundation

/// An application component recovered from SwiftUI's private rendered graph.
public struct RenderedComponent: Equatable, Sendable {
    public let name: String
    public let qualifiedName: String
    public let frame: CGRect?
    public let children: [RenderedComponent]

    public init(
        name: String,
        qualifiedName: String,
        frame: CGRect?,
        children: [RenderedComponent]
    ) {
        self.name = name
        self.qualifiedName = qualifiedName
        self.frame = frame
        self.children = children
    }

    public var flattened: [RenderedComponent] {
        [self] + children.flatMap(\.flattened)
    }

    public func formattedTree() -> String {
        formattedLines(prefix: "", isLast: true, isRoot: true).joined(separator: "\n")
    }

    private func formattedLines(prefix: String, isLast: Bool, isRoot: Bool) -> [String] {
        let marker = isRoot ? "" : (isLast ? "└─ " : "├─ ")
        let frameText = frame.map { " \($0.integral)" } ?? ""
        let line = prefix + marker + name + frameText
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

enum RenderedGraphParser {
    static func parse(json: String) -> [RenderedComponent] {
        guard let data = json.data(using: .utf8),
              let roots = try? JSONSerialization.jsonObject(with: data) as? [Any] else {
            return []
        }

        return roots.flatMap { parseNode($0, inheritedFrame: nil) }
    }

    private static func parseNode(_ value: Any, inheritedFrame: CGRect?) -> [RenderedComponent] {
        guard let dictionary = value as? [String: Any] else {
            return []
        }

        let properties = dictionary["properties"] as? [[String: Any]] ?? []
        let frame = frame(from: properties) ?? inheritedFrame
        let type = applicationType(from: properties)
        let childValues = dictionary["children"] as? [Any] ?? []
        let children = childValues.flatMap { parseNode($0, inheritedFrame: frame) }

        guard let type else {
            return children
        }

        let name = readableName(from: type)
        let collapsedChildren = children.filter { $0.name != name }
        return [
            RenderedComponent(
                name: name,
                qualifiedName: type,
                frame: frame,
                children: collapsedChildren
            )
        ]
    }

    private static func applicationType(from properties: [[String: Any]]) -> String? {
        let candidates = properties.compactMap { property -> String? in
            guard let attribute = property["attribute"] as? [String: Any],
                  let type = attribute["type"] as? String else {
                return nil
            }
            return isApplicationType(type) ? type : nil
        }
        return candidates.first
    }

    private static func isApplicationType(_ type: String) -> Bool {
        let frameworkPrefixes = [
            "Swift.", "SwiftUI.", "SwiftUICore.", "Foundation.", "CoreFoundation.",
            "CoreGraphics.", "UIKit.", "__C.", "AttributeGraph.", "ViewFinder.",
        ]
        return !frameworkPrefixes.contains { type.hasPrefix($0) }
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

    private static func frame(from properties: [[String: Any]]) -> CGRect? {
        var position: CGPoint?
        var size: CGSize?

        for property in properties {
            guard let attribute = property["attribute"] as? [String: Any],
                  let readableType = attribute["readableType"] as? String,
                  let values = attribute["value"] as? [NSNumber],
                  values.count == 2 else {
                continue
            }

            if readableType == "CGPoint" {
                position = CGPoint(x: values[0].doubleValue, y: values[1].doubleValue)
            } else if readableType == "CGSize" {
                size = CGSize(width: values[0].doubleValue, height: values[1].doubleValue)
            }
        }

        guard let position, let size, size.width > 1, size.height > 1 else {
            return nil
        }
        return CGRect(origin: position, size: size)
    }
}
#endif
