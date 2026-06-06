#if canImport(Darwin)
import Darwin
#endif
#if canImport(UIKit)
import Foundation
import SwiftUI
import UIKit

@MainActor
private protocol ViewFinderDebugDataProvider: AnyObject {
    func viewFinderDebugData() -> [_ViewDebug.Data]
}

extension _UIHostingView: ViewFinderDebugDataProvider {
    fileprivate func viewFinderDebugData() -> [_ViewDebug.Data] {
        _viewDebugData()
    }
}

/// Output from SwiftUI's private rendered-graph debug-data hook.
public struct RenderedHierarchySnapshot: Sendable {
    /// JSON emitted by SwiftUI's private debug-data serializer.
    public let json: String

    /// Type-like string values found in the serialized graph.
    public let discoveredTypeNames: [String]

    /// Whether the current SwiftUI runtime exposed the private switch needed
    /// to request all debug graph properties.
    public let requestedAllProperties: Bool
}

/// Research-only access to SwiftUI's private rendered graph debug data.
///
/// This relies on underscored APIs and can break in any OS or Xcode release.
@MainActor
public enum PrivateRenderedHierarchyProbe {
    private static var didRequestAllProperties = false

    /// Requests the minimal private graph properties needed for component
    /// names and frames before SwiftUI creates the graph.
    ///
    /// Returns `false` when the current runtime does not expose the required
    /// private ABI symbol.
    @discardableResult
    public static func prepareForGraphCreation() -> Bool {
        let requested = requestSafeViewDebugProperties()
        didRequestAllProperties = didRequestAllProperties || requested
        return requested
    }

    /// Renders a supplied root in an internal hosting view and captures private
    /// SwiftUI debug graph data.
    public static func capture<Content: View>(
        rootView: Content,
        size: CGSize = CGSize(width: 390, height: 844)
    ) -> RenderedHierarchySnapshot? {
        let requestedAllProperties = prepareForGraphCreation()

        let hostingView = _UIHostingView(rootView: rootView)
        hostingView.frame = CGRect(origin: .zero, size: size)
        let window = UIWindow(frame: hostingView.frame)
        window.addSubview(hostingView)
        window.isHidden = false
        hostingView.setNeedsLayout()
        hostingView.layoutIfNeeded()
        hostingView._renderForTest(interval: 0)

        let snapshot = capture(
            from: hostingView,
            requestedAllProperties: requestedAllProperties
        )
        window.isHidden = true
        return snapshot
    }

    /// Captures private SwiftUI debug graph data from a known hosting view.
    public static func capture<Content: View>(
        from hostingView: _UIHostingView<Content>
    ) -> RenderedHierarchySnapshot? {
        capture(
            from: hostingView,
            requestedAllProperties: didRequestAllProperties
        )
    }

    /// Captures debug data from an opaque mounted hosting view using protocol
    /// witness dispatch, preserving its actual generic content specialization.
    public static func capture(fromUnknownHostingView hostingView: UIView) -> RenderedHierarchySnapshot? {
        guard let debugData = debugData(fromUnknownHostingView: hostingView),
              let data = _ViewDebug.serializedData(debugData),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }

        return RenderedHierarchySnapshot(
            json: json,
            discoveredTypeNames: discoverTypeLikeStrings(in: data),
            requestedAllProperties: didRequestAllProperties
        )
    }

    static func reflectedComponents(fromUnknownHostingView hostingView: UIView) -> [RenderedComponent] {
        guard let debugData = debugData(fromUnknownHostingView: hostingView) else {
            return MountedHostingViewReflector.components(in: hostingView)
        }
        return ReflectedRenderedGraphParser.parse(debugData)
    }

    private static func capture<Content: View>(
        from hostingView: _UIHostingView<Content>,
        requestedAllProperties: Bool
    ) -> RenderedHierarchySnapshot? {
        let debugData = hostingView._viewDebugData()
        guard let data = _ViewDebug.serializedData(debugData),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }

        return RenderedHierarchySnapshot(
            json: json,
            discoveredTypeNames: discoverTypeLikeStrings(in: data),
            requestedAllProperties: requestedAllProperties
        )
    }

    private static func debugData(fromUnknownHostingView hostingView: UIView) -> [_ViewDebug.Data]? {
        (hostingView as? any ViewFinderDebugDataProvider)?.viewFinderDebugData()
    }

    private static func requestSafeViewDebugProperties() -> Bool {
        guard let handle = dlopen(nil, RTLD_NOW),
              let symbol = dlsym(
                handle,
                "$s7SwiftUI10_ViewDebugO10propertiesAC10PropertiesVvsZ"
              ) else {
            return false
        }

        typealias PropertiesSetter = @convention(thin) (_ViewDebug.Properties) -> Void
        let setter = unsafeBitCast(symbol, to: PropertiesSetter.self)
        setter([.type, .position, .size])
        return true
    }

    private static func discoverTypeLikeStrings(in data: Data) -> [String] {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) else {
            return []
        }

        var values: [String] = []
        collectTypeLikeStrings(from: jsonObject, into: &values)
        return Array(Set(values)).sorted()
    }

    private static func collectTypeLikeStrings(from value: Any, into result: inout [String]) {
        if let string = value as? String,
           string.contains("."),
           string.first?.isUppercase == true || string.contains("View") {
            result.append(string)
            return
        }

        if let dictionary = value as? [String: Any] {
            for (key, child) in dictionary {
                if key.localizedCaseInsensitiveContains("type"), let typeName = child as? String {
                    result.append(typeName)
                }
                collectTypeLikeStrings(from: child, into: &result)
            }
            return
        }

        if let array = value as? [Any] {
            for child in array {
                collectTypeLikeStrings(from: child, into: &result)
            }
        }
    }

}
#endif
