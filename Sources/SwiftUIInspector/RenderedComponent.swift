import CoreGraphics
import Foundation

/// An application component recovered from SwiftUI's private rendered graph.
public struct RenderedComponent: Equatable, Sendable {
    public let name: String
    public let qualifiedName: String
    public let frame: CGRect?
    public let sourceLocation: String?
    public let children: [RenderedComponent]

    public init(
        name: String,
        qualifiedName: String,
        frame: CGRect?,
        sourceLocation: String? = nil,
        children: [RenderedComponent]
    ) {
        self.name = name
        self.qualifiedName = qualifiedName
        self.frame = frame
        self.sourceLocation = sourceLocation
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
        let sourceText = sourceLocation.map { " [\($0)]" } ?? ""
        let line = prefix + marker + name + frameText + sourceText
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
            if isApplicationType(type) {
                return type
            }
            return nestedApplicationType(in: type)
        }
        return candidates.first
    }

    private static func nestedApplicationType(in type: String) -> String? {
        let pattern = #"[A-Za-z_][A-Za-z0-9_]*\.(?:\(unknown context at \$[0-9a-f]+\)\.)?[A-Za-z_][A-Za-z0-9_]*"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(type.startIndex..<type.endIndex, in: type)
        for match in expression.matches(in: type, range: range) {
            guard let matchRange = Range(match.range, in: type) else {
                continue
            }
            let candidate = String(type[matchRange])
            if isApplicationType(candidate) {
                return candidate
            }
        }
        return nil
    }

    private static func isApplicationType(_ type: String) -> Bool {
        let frameworkPrefixes = [
            "Swift.", "SwiftUI.", "SwiftUICore.", "Foundation.", "CoreFoundation.",
            "CoreGraphics.", "UIKit.", "__C.", "AttributeGraph.", "SwiftUIInspector.",
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

enum RenderedComponentReconciler {
    static func reconcile(
        renderedRoots: [RenderedComponent],
        currentRoots: [ComponentNode]
    ) -> [RenderedComponent] {
        guard renderedRoots.count == 1,
              currentRoots.count == 1,
              let renderedRoot = renderedRoots.first,
              let currentRoot = currentRoots.first,
              !renderedRoot.flattened.contains(where: { $0.qualifiedName == currentRoot.qualifiedName })
        else {
            return renderedRoots
        }

        return [
            RenderedComponent(
                name: currentRoot.name,
                qualifiedName: currentRoot.qualifiedName,
                frame: renderedRoot.frame,
                sourceLocation: renderedRoot.sourceLocation,
                children: renderedRoot.children
            )
        ]
    }
}

enum ReflectedRenderedGraphParser {
    static func parse(_ value: Any) -> [RenderedComponent] {
        let components = collectionElements(of: value).flatMap { parseNode($0, inheritedFrame: nil) }
        let preferred = components.flatMap { preferredModuleComponents(in: $0) }
        return preferred.isEmpty ? components : preferred
    }

    private static func parseNode(_ value: Any, inheritedFrame: CGRect?) -> [RenderedComponent] {
        let fields = Dictionary(
            uniqueKeysWithValues: Mirror(reflecting: value).children.compactMap { child in
                child.label.map { ($0, child.value) }
            }
        )
        guard let properties = fields["properties"] ?? fields["data"],
              let childrenValue = fields["children"] ?? fields["childData"] else {
            return collectionElements(of: value).flatMap { parseNode($0, inheritedFrame: inheritedFrame) }
        }

        let attributes = propertyValues(from: properties)
        let position = attributes["position"] as? CGPoint
        let size = attributes["size"] as? CGSize
        let frame = position.flatMap { position in
            size.map { CGRect(origin: position, size: $0) }
        } ?? inheritedFrame
        let children = collectionElements(of: childrenValue)
            .flatMap { parseNode($0, inheritedFrame: frame) }

        let valueType = attributes["value"].flatMap {
            applicationType(in: String(reflecting: $0))
        }
        let declaredType = (attributes["type"] as? String).flatMap(applicationType(in:))
        guard let applicationType = valueType ?? declaredType else {
            return children
        }

        let name = readableName(from: applicationType)
        return [
            RenderedComponent(
                name: name,
                qualifiedName: applicationType,
                frame: frame,
                children: children.filter { $0.name != name }
            )
        ]
    }

    private static func propertyValues(from value: Any) -> [String: Any] {
        var result: [String: Any] = [:]
        for entry in collectionElements(of: value) {
            let pair = Array(Mirror(reflecting: entry).children)
            guard pair.count == 2 else { continue }
            let reflectedKey = String(reflecting: pair[0].value)
            let key = reflectedKey.split(separator: ".").last.map(String.init) ?? reflectedKey
            let propertyValue = unwrapAny(pair[1].value)
            result[key] = key == "type" ? String(reflecting: propertyValue) : propertyValue
        }
        return result
    }

    private static func collectionElements(of value: Any) -> [Any] {
        Array(Mirror(reflecting: value).children.map(\.value))
    }

    private static func unwrapAny(_ value: Any) -> Any {
        let mirror = Mirror(reflecting: value)
        guard String(reflecting: mirror.subjectType) == "Any",
              let child = mirror.children.first else {
            return value
        }
        return child.value
    }

    private static func applicationType(in type: String) -> String? {
        let pattern = #"[A-Za-z_][A-Za-z0-9_]*\.(?:\(unknown context at \$[0-9a-f]+\)\.)?[A-Za-z_][A-Za-z0-9_]*"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let range = NSRange(type.startIndex..<type.endIndex, in: type)
        let candidates = expression.matches(in: type, range: range).compactMap { match -> String? in
            guard let range = Range(match.range, in: type) else { return nil }
            let candidate = String(type[range])
            return isApplicationType(candidate) ? candidate : nil
        }
        return candidates.first(where: { $0.hasPrefix("\(preferredModuleName).") })
            ?? candidates.first
    }

    private static func isApplicationType(_ type: String) -> Bool {
        !HierarchyOptions.defaultFrameworkModulePrefixes.contains { type.hasPrefix($0) }
            && !type.hasPrefix("__C.")
            && !type.hasPrefix("AttributeGraph.")
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

    private static func preferredModuleComponents(in component: RenderedComponent) -> [RenderedComponent] {
        let children = component.children.flatMap { preferredModuleComponents(in: $0) }
        if component.qualifiedName.hasPrefix("\(preferredModuleName).") {
            return [
                RenderedComponent(
                    name: component.name,
                    qualifiedName: component.qualifiedName,
                    frame: component.frame,
                    sourceLocation: component.sourceLocation,
                    children: children
                )
            ]
        }
        return children
    }

    private static var preferredModuleName: String {
        let executable = Bundle.main.object(forInfoDictionaryKey: "CFBundleExecutable") as? String
        return executable?.replacingOccurrences(of: " ", with: "_") ?? ""
    }
}
