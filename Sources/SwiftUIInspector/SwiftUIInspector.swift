import SwiftUI
import Foundation
import os

/// Global entry point for the SwiftUIInspector research prototype.
@MainActor
public enum SwiftUIInspector {
    private static let logger = Logger(subsystem: "SwiftUIInspector", category: "RootValue")

    /// The currently active inspection mode.
    public private(set) static var mode: InspectionMode = .off

    /// Enables SwiftUIInspector globally.
    ///
    /// Global activation configures console and overlay behavior.
    public static func enable(
        mode: InspectionMode = .overlayAndLogs,
        overlayStyle: OverlayStyle = .compact,
        tabComponents: [Any.Type] = []
    ) {
        self.mode = mode
        #if canImport(UIKit)
        GlobalSwiftUIInspectorMonitor.shared.start(
            mode: mode,
            style: overlayStyle,
            tabComponents: tabComponents
        )
        #endif
    }

    /// Disables all SwiftUIInspector work.
    public static func disable() {
        mode = .off
        #if canImport(UIKit)
        GlobalSwiftUIInspectorMonitor.shared.stop()
        #endif
    }

    /// Changes the active inspection mode.
    public static func setMode(_ mode: InspectionMode) {
        self.mode = mode
        #if canImport(UIKit)
        GlobalSwiftUIInspectorMonitor.shared.start(mode: mode, style: .compact, tabComponents: [])
        #endif
    }

    /// Inspects a concrete SwiftUI root value and optionally prints the result.
    @discardableResult
    public static func inspect<Root: View>(
        _ root: Root,
        options: HierarchyOptions = .init()
    ) -> InspectionReport {
        guard mode != .off else {
            return InspectionReport(roots: [])
        }

        let report = StaticViewHierarchyInspector(options: options).inspect(root)
        if mode.includesLogs {
            let formatted = report.formatted()
            print("[SwiftUIInspector] Root-value component hierarchy:\n\n\(formatted)")
            NSLog("[SwiftUIInspector] Root-value component hierarchy:\n\n%@", formatted)
            logger.info("Root-value component hierarchy:\n\(formatted, privacy: .public)")
        }
        return report
    }
}
