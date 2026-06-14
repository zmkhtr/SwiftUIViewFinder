#if canImport(UIKit)
import UIKit

/// Console-only UIKit hierarchy fallback for the Phase 2 prototype.
@MainActor
public enum UIKitHierarchyInspector {
    /// Inspects every foreground window and returns UIKit class-name trees.
    public static func inspectForegroundWindows() -> InspectionReport {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .flatMap(\.windows)

        return InspectionReport(
            roots: windows.map { inspect(view: $0) },
            warnings: [
                "UIKit traversal normally exposes hosting/container classes, not nested SwiftUI component names."
            ]
        )
    }

    private static func inspect(view: UIView) -> ComponentNode {
        let qualifiedName = String(reflecting: type(of: view))
        return ComponentNode(
            name: String(describing: type(of: view)),
            qualifiedName: qualifiedName,
            origin: .uiKit,
            children: view.subviews.map(inspect(view:))
        )
    }
}
#endif
