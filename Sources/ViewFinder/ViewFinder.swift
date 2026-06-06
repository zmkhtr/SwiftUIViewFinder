import SwiftUI
import Foundation
import os

/// Global entry point for the ViewFinder research prototype.
@MainActor
public enum ViewFinder {
    private static let logger = Logger(subsystem: "ViewFinder", category: "RootValue")

    /// The currently active inspection mode.
    public private(set) static var mode: InspectionMode = .off

    /// Enables ViewFinder globally.
    ///
    /// Phase 2 note: global activation configures console behavior. It cannot
    /// recover a SwiftUI hierarchy unless a concrete root view or private
    /// rendered-graph probe is provided.
    public static func enable(mode: InspectionMode = .overlayAndLogs) {
        self.mode = mode
    }

    /// Disables all ViewFinder work.
    public static func disable() {
        mode = .off
    }

    /// Changes the active inspection mode.
    public static func setMode(_ mode: InspectionMode) {
        self.mode = mode
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
            print("[ViewFinder] Root-value component hierarchy:\n\n\(formatted)")
            NSLog("[ViewFinder] Root-value component hierarchy:\n\n%@", formatted)
            logger.info("Root-value component hierarchy:\n\(formatted, privacy: .public)")
        }
        return report
    }
}
