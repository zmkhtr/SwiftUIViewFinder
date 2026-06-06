#if canImport(UIKit)
import SwiftUI
import UIKit
import os

@MainActor
final class MountedViewInspector {
    static let shared = MountedViewInspector()

    private let overlayManager = ViewFinderOverlayManager()
    private let logger = Logger(subsystem: "ViewFinder", category: "RenderedGraph")
    private weak var locator: UIView?
    private var mode: InspectionMode = .off
    private var style: OverlayStyle = .compact
    private var refreshTimer: Timer?
    private var lastHierarchyText: String?

    func startMonitoring(from locator: UIView, mode: InspectionMode, style: OverlayStyle) {
        if self.locator === locator,
           self.mode == mode,
           self.style == style,
           refreshTimer != nil {
            return
        }

        self.locator = locator
        self.mode = mode
        self.style = style

        guard mode != .off else {
            stopMonitoring(from: locator)
            return
        }

        _ = PrivateRenderedHierarchyProbe.prepareForGraphCreation()
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
        refreshTimer?.tolerance = 0.15

        DispatchQueue.main.async { [weak self] in
            self?.refresh()
        }
    }

    func stopMonitoring(from locator: UIView) {
        guard self.locator === locator else { return }
        refreshTimer?.invalidate()
        refreshTimer = nil
        self.locator = nil
        lastHierarchyText = nil
        overlayManager.hide()
    }

    private func refresh() {
        guard let locator, mode != .off else {
            return
        }

        guard let hostingView = hostingView(near: locator),
              let snapshot = PrivateRenderedHierarchyProbe.capture(fromUnknownHostingView: hostingView) else {
            if mode.includesLogs, lastHierarchyText != "(graph unavailable)" {
                print("[ViewFinder] Mounted SwiftUI hosting view debug data is unavailable.")
                NSLog("[ViewFinder] Mounted SwiftUI hosting view debug data is unavailable.")
                logger.warning("Mounted SwiftUI hosting view debug data is unavailable.")
                lastHierarchyText = "(graph unavailable)"
            }
            overlayManager.showStatus("ViewFinder: graph unavailable", relativeTo: locator)
            return
        }

        let roots = RenderedGraphParser.parse(json: snapshot.json)
        let components = roots.flatMap(\.flattened)

        let tree = roots.map { $0.formattedTree() }.joined(separator: "\n")
        if mode.includesLogs, tree != lastHierarchyText {
            print("[ViewFinder] Rendered component hierarchy:\n\n\(tree.isEmpty ? "(no application components found)" : tree)")
            NSLog(
                "[ViewFinder] Rendered component hierarchy:\n\n%@",
                tree.isEmpty ? "(no application components found)" : tree
            )
            logger.info("Rendered component hierarchy:\n\(tree.isEmpty ? "(no application components found)" : tree, privacy: .public)")
        }
        lastHierarchyText = tree

        if mode.includesOverlay {
            if components.contains(where: { $0.frame != nil }) {
                overlayManager.show(components: components, relativeTo: hostingView, style: style)
            } else {
                overlayManager.showStatus("ViewFinder: no component frames", relativeTo: hostingView)
            }
        } else {
            overlayManager.hide()
        }
    }

    private func hostingView(near view: UIView) -> UIView? {
        var candidate = view.superview
        while let current = candidate {
            if String(describing: type(of: current)).contains("HostingView") {
                return current
            }
            candidate = current.superview
        }

        return view.window?
            .allDescendants()
            .filter { String(describing: type(of: $0)).contains("HostingView") }
            .max { $0.bounds.width * $0.bounds.height < $1.bounds.width * $1.bounds.height }
    }
}

struct ViewFinderLocator: UIViewRepresentable {
    let mode: InspectionMode
    let overlayStyle: OverlayStyle

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.alpha = 0
        MountedViewInspector.shared.startMonitoring(
            from: view,
            mode: mode,
            style: overlayStyle
        )
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        MountedViewInspector.shared.startMonitoring(
            from: uiView,
            mode: mode,
            style: overlayStyle
        )
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: ()) {
        MountedViewInspector.shared.stopMonitoring(from: uiView)
    }
}

@MainActor
private final class ViewFinderOverlayManager {
    private weak var overlayView: UIView?

    func show(components: [RenderedComponent], relativeTo hostingView: UIView, style: OverlayStyle) {
        hide()

        guard let window = hostingView.window else {
            return
        }

        let container = UIView(frame: window.bounds)
        container.backgroundColor = .clear
        container.isUserInteractionEnabled = false
        container.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.accessibilityIdentifier = "ViewFinderOverlay"

        let visibleComponents = components
            .compactMap { component -> (RenderedComponent, CGRect)? in
                guard let frame = component.frame else { return nil }
                let converted = hostingView.convert(frame, to: window)
                guard converted.intersects(window.bounds), converted.width > 8, converted.height > 8 else {
                    return nil
                }
                return (component, converted)
            }
            .prefix(40)

        for (component, frame) in visibleComponents {
            let border = UIView(frame: frame)
            border.layer.borderColor = UIColor.systemPink.withAlphaComponent(0.8).cgColor
            border.layer.borderWidth = 1
            border.backgroundColor = UIColor.systemPink.withAlphaComponent(0.04)

            let label = UILabel()
            label.text = style == .detailed
                ? "\(component.name) \(Int(frame.width))×\(Int(frame.height))"
                : component.name
            label.font = .monospacedSystemFont(ofSize: 9, weight: .semibold)
            label.textColor = .white
            label.backgroundColor = UIColor.systemPink.withAlphaComponent(0.9)
            label.numberOfLines = 1
            label.sizeToFit()
            label.frame.size.width += 6
            label.frame.size.height += 2
            label.frame.origin = CGPoint(x: 0, y: 0)
            border.addSubview(label)
            container.addSubview(border)
        }

        window.addSubview(container)
        overlayView = container
    }

    func showStatus(_ text: String, relativeTo view: UIView) {
        hide()
        guard let window = view.window else { return }

        let label = UILabel()
        label.text = text
        label.font = .monospacedSystemFont(ofSize: 11, weight: .bold)
        label.textColor = .white
        label.backgroundColor = UIColor.systemPink.withAlphaComponent(0.92)
        label.layer.cornerRadius = 6
        label.layer.masksToBounds = true
        label.textAlignment = .center
        label.frame = CGRect(x: 12, y: window.safeAreaInsets.top + 8, width: 220, height: 28)
        label.isUserInteractionEnabled = false
        label.accessibilityIdentifier = "ViewFinderOverlayStatus"
        window.addSubview(label)
        overlayView = label
    }

    func hide() {
        overlayView?.removeFromSuperview()
    }
}

private extension UIView {
    func allDescendants() -> [UIView] {
        subviews + subviews.flatMap { $0.allDescendants() }
    }
}
#endif
