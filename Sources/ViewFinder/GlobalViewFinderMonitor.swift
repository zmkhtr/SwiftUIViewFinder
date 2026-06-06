#if canImport(UIKit)
import UIKit
import os

@MainActor
final class GlobalViewFinderMonitor {
    static let shared = GlobalViewFinderMonitor()

    private let overlayManager = ViewFinderOverlayManager()
    private let logger = Logger(subsystem: "ViewFinder", category: "GlobalRenderedGraph")
    private var mode: InspectionMode = .off
    private var style: OverlayStyle = .compact
    private var refreshTimer: Timer?
    private var overlayWindow: PassThroughOverlayWindow?
    private var lastHierarchyText: String?

    func start(mode: InspectionMode, style: OverlayStyle) {
        self.mode = mode
        self.style = style

        guard mode != .off else {
            stop()
            return
        }

        PrivateRenderedHierarchyProbe.prepareForGraphCreation()
        guard refreshTimer == nil else {
            refresh()
            return
        }

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
        refreshTimer?.tolerance = 0.1
        DispatchQueue.main.async { [weak self] in
            self?.refresh()
        }
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        overlayManager.hide()
        overlayWindow?.isHidden = true
        overlayWindow = nil
        lastHierarchyText = nil
    }

    private func refresh() {
        guard mode != .off,
              let sourceWindow = frontmostApplicationWindow(),
              let hostingView = frontmostHostingView(in: sourceWindow),
              let overlayHost = overlayHost(for: sourceWindow) else {
            overlayManager.hide()
            return
        }

        let components = PrivateRenderedHierarchyProbe
            .reflectedComponents(fromUnknownHostingView: hostingView)
            .map { converted($0, from: hostingView, to: overlayHost) }
        let visibleComponents = components
            .flatMap(\.flattened)
            .filter { component in
                guard let frame = component.frame else { return false }
                return frame.width > 8
                    && frame.height > 8
                    && frame.intersects(overlayHost.bounds)
            }

        logIfChanged(components)
        if mode.includesOverlay, !visibleComponents.isEmpty {
            overlayManager.show(components: visibleComponents, relativeTo: overlayHost, style: style)
        } else {
            overlayManager.hide()
        }
    }

    private func frontmostApplicationWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .flatMap(\.windows)
            .filter {
                !($0 is PassThroughOverlayWindow)
                    && !$0.isHidden
                    && $0.alpha > 0
                    && $0.windowLevel == .normal
            }
            .sorted { lhs, rhs in
                if lhs.isKeyWindow != rhs.isKeyWindow {
                    return !lhs.isKeyWindow && rhs.isKeyWindow
                }
                return lhs.subviews.count < rhs.subviews.count
            }
            .last
    }

    private func frontmostHostingView(in window: UIWindow) -> UIView? {
        window.allDescendantsInFrontToBack()
            .filter {
                String(describing: type(of: $0)).contains("HostingView")
                    && $0.isEffectivelyVisible
                    && $0.bounds.width > 8
                    && $0.bounds.height > 8
            }
            .first
    }

    private func overlayHost(for sourceWindow: UIWindow) -> UIView? {
        guard let scene = sourceWindow.windowScene else { return nil }
        let window: PassThroughOverlayWindow
        if let overlayWindow, overlayWindow.windowScene === scene {
            window = overlayWindow
        } else {
            overlayWindow?.isHidden = true
            window = PassThroughOverlayWindow(windowScene: scene)
            window.windowLevel = .normal + 1
            window.backgroundColor = .clear
            window.rootViewController = PassThroughOverlayViewController()
            window.isHidden = false
            overlayWindow = window
        }
        window.frame = scene.screen.bounds
        return window.rootViewController?.view
    }

    private func converted(
        _ component: RenderedComponent,
        from hostingView: UIView,
        to overlayHost: UIView
    ) -> RenderedComponent {
        let frame = component.frame.map {
            overlayHost.convert(hostingView.convert($0, to: nil), from: nil)
        }
        return RenderedComponent(
            name: component.name,
            qualifiedName: component.qualifiedName,
            frame: frame,
            sourceLocation: component.sourceLocation,
            children: component.children.map { converted($0, from: hostingView, to: overlayHost) }
        )
    }

    private func logIfChanged(_ components: [RenderedComponent]) {
        guard mode.includesLogs else { return }
        let text = components.map { $0.formattedTree() }.joined(separator: "\n")
        guard text != lastHierarchyText else { return }
        lastHierarchyText = text
        let message = text.isEmpty ? "(no application components found)" : text
        print("[ViewFinder] Global rendered component hierarchy:\n\n\(message)")
        logger.info("Global rendered component hierarchy:\n\(message, privacy: .public)")
    }
}

private final class PassThroughOverlayWindow: UIWindow {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        false
    }
}

private final class PassThroughOverlayViewController: UIViewController {
    override func loadView() {
        view = PassThroughOverlayView(frame: .zero)
        view.backgroundColor = .clear
    }
}

private extension UIView {
    func allDescendantsInFrontToBack() -> [UIView] {
        subviews.reversed().flatMap { [$0] + $0.allDescendantsInFrontToBack() }
    }

    var isEffectivelyVisible: Bool {
        var candidate: UIView? = self
        while let view = candidate {
            if view.isHidden || view.alpha <= 0.01 {
                return false
            }
            candidate = view.superview
        }
        guard let window else { return false }
        let frameInWindow = convert(bounds, to: window)
        return frameInWindow.intersects(window.bounds)
    }
}
#endif
