#if canImport(UIKit)
import Foundation
import SwiftUI
import UIKit

/// Recovers application view type names from an opaque, already-mounted
/// SwiftUI hosting view without casting its unknown generic content type.
enum MountedHostingViewReflector {
    static func components(in hostingView: UIView) -> [RenderedComponent] {
        let frame = hostingView.bounds
        return applicationTypes(in: hostingView).map {
            RenderedComponent(
                name: readableName(from: $0),
                qualifiedName: $0,
                frame: frame,
                children: []
            )
        }
    }

    static func applicationTypes(in root: Any) -> [String] {
        var result: [String] = []
        var visitedObjects = Set<ObjectIdentifier>()
        var visitedValueCount = 0

        func walk(_ value: Any, depth: Int) {
            guard depth < 24, visitedValueCount < 1_000 else { return }
            visitedValueCount += 1

            let mirror = Mirror(reflecting: value)
            if mirror.displayStyle == .class, let object = value as AnyObject? {
                guard visitedObjects.insert(ObjectIdentifier(object)).inserted else { return }
            }

            let type = String(reflecting: type(of: value))
            if isApplicationType(type), isLikelyComponentType(type) {
                result.append(type)
            }
            appendPreferredNestedComponentTypes(in: type, to: &result)
            for child in mirror.children {
                walk(child.value, depth: depth + 1)
            }
        }

        walk(root, depth: 0)

        var deduplicated: [String] = []
        for type in result where !deduplicated.contains(type) {
            deduplicated.append(type)
        }
        return deduplicated
    }

    private static func isApplicationType(_ type: String) -> Bool {
        let frameworkPrefixes = [
            "Swift.", "SwiftUI.", "SwiftUICore.", "Foundation.", "CoreFoundation.",
            "CoreGraphics.", "UIKit.", "__C.", "AttributeGraph.", "SwiftUIInspector.",
        ]
        return !frameworkPrefixes.contains { type.hasPrefix($0) }
    }

    private static func appendPreferredNestedComponentTypes(in text: String, to result: inout [String]) {
        let module = preferredModuleName
        guard !module.isEmpty else { return }
        let normalized = text.replacingOccurrences(
            of: #"\.\(unknown context at \$[0-9a-f]+\)"#,
            with: "",
            options: .regularExpression
        )
        let pattern = #"[A-Za-z_][A-Za-z0-9_]*\.[A-Za-z_][A-Za-z0-9_]*"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return }
        let range = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)

        for match in expression.matches(in: normalized, range: range) {
            guard let matchRange = Range(match.range, in: normalized) else { continue }
            let candidate = String(normalized[matchRange])
            if candidate.hasPrefix("\(module)."), isLikelyComponentType(candidate) {
                result.append(candidate)
            }
        }
    }

    private static func isLikelyComponentType(_ type: String) -> Bool {
        let name = readableName(from: type)
        let suffixes = [
            "View", "Screen", "Section", "Card", "Row", "Header", "Footer", "Button",
        ]
        return suffixes.contains { name.hasSuffix($0) }
    }

    private static func readableName(from qualifiedName: String) -> String {
        let withoutContext = qualifiedName.replacingOccurrences(
            of: #"\.\(unknown context at \$[0-9a-f]+\)"#,
            with: "",
            options: .regularExpression
        )
        return withoutContext.split(separator: ".").last.map(String.init) ?? withoutContext
    }

    private static var preferredModuleName: String {
        let executable = Bundle.main.object(forInfoDictionaryKey: "CFBundleExecutable") as? String
        return executable?.replacingOccurrences(of: " ", with: "_") ?? ""
    }
}
#endif
