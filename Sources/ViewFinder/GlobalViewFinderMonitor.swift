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
    private var lastMountedTypesText: String?
    private var lastMountedRootsText: String?
    private var lastCandidateText: String?
    private var registeredTabComponents: [RenderedComponent] = []

    func start(mode: InspectionMode, style: OverlayStyle, tabComponents: [Any.Type]) {
        self.mode = mode
        self.style = style
        if !tabComponents.isEmpty {
            registeredTabComponents = tabComponents.map { type in
                let qualifiedName = String(reflecting: type)
                let name = qualifiedName.split(separator: ".").last.map(String.init) ?? qualifiedName
                return RenderedComponent(
                    name: name,
                    qualifiedName: qualifiedName,
                    frame: nil,
                    children: []
                )
            }
        }

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
              let (hostingView, components) = frontmostRenderedComponents(in: sourceWindow),
              let overlayHost = overlayHost(for: sourceWindow) else {
            overlayManager.hide()
            return
        }

        let convertedComponents = components.map { converted($0, from: hostingView, to: overlayHost) }
        let visibleComponents = convertedComponents
            .flatMap(\.flattened)
            .filter { component in
                guard let frame = component.frame else { return false }
                return frame.width > 8
                    && frame.height > 8
                    && frame.intersects(overlayHost.bounds)
            }

        logIfChanged(convertedComponents)
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

    private func frontmostRenderedComponents(in window: UIWindow) -> (UIView, [RenderedComponent])? {
        let hostingViews = window.allDescendantsInFrontToBack()
            .filter {
                String(describing: type(of: $0)).contains("HostingView")
                    && $0.isEffectivelyVisible
                    && $0.bounds.width > 8
                    && $0.bounds.height > 8
            }

        let candidates = hostingViews.compactMap { hostingView -> (UIView, [RenderedComponent])? in
            let rendered = PrivateRenderedHierarchyProbe
                .reflectedComponents(fromUnknownHostingView: hostingView)
            let mounted = MountedHostingViewReflector.components(in: hostingView)
            let components = mounted.isEmpty ? rendered : mounted
            return components.isEmpty ? nil : (hostingView, components)
        }
        let candidateText = candidates.enumerated().map { index, candidate in
            let names = candidate.1.flatMap(\.flattened).map(\.name).joined(separator: ", ")
            return "\(index): \(type(of: candidate.0)) [\(names)]"
        }.joined(separator: "\n")
        if mode.includesLogs, candidateText != lastCandidateText {
            lastCandidateText = candidateText
            print("[ViewFinder] Visible hosting candidates:\n\(candidateText)")
        }

        for (hostingView, renderedComponents) in candidates.reversed() {
                if let activeComponent = activeComponent(in: hostingView, window: window) {
                    return (hostingView, [activeComponent])
                }
                let mountedComponents = MountedHostingViewReflector.components(in: hostingView)
                let mountedTypes = mountedComponents.map(\.qualifiedName)
                let mountedText = mountedTypes.joined(separator: "\n")
                if mode.includesLogs, mountedText != lastMountedTypesText {
                    lastMountedTypesText = mountedText
                    print("[ViewFinder] Current mounted application types:\n\(mountedText)")
                }
                return (
                    hostingView,
                    replacingStaleRoot(
                        in: renderedComponents,
                        with: mountedComponents.last
                    )
                )
        }
        return nil
    }

    private func activeComponent(in hostingView: UIView, window: UIWindow) -> RenderedComponent? {
        guard let selectedIndex = selectedTabIndex(in: window) else { return nil }
        if hasPresentedViewController(in: window) || hasPushedViewController(in: window) {
            return nil
        }
        if registeredTabComponents.indices.contains(selectedIndex) {
            let component = registeredTabComponents[selectedIndex]
            return RenderedComponent(
                name: component.name,
                qualifiedName: component.qualifiedName,
                frame: hostingView.bounds,
                children: []
            )
        }
        let roots = PrivateRenderedHierarchyProbe.currentRoots(fromUnknownHostingView: hostingView)
        let rootsText = roots.map { $0.formattedTree() }.joined(separator: "\n")
        if mode.includesLogs, rootsText != lastMountedRootsText {
            lastMountedRootsText = rootsText
            print("[ViewFinder] Current mounted root values:\n\(rootsText)")
        }
        guard let root = roots.last, root.children.indices.contains(selectedIndex) else {
            return nil
        }
        let child = root.children[selectedIndex]
        return RenderedComponent(
            name: child.name,
            qualifiedName: child.qualifiedName,
            frame: hostingView.bounds,
            children: []
        )
    }

    private func hasPresentedViewController(in window: UIWindow) -> Bool {
        window.rootViewController?.presentedViewController != nil
    }

    private func hasPushedViewController(in window: UIWindow) -> Bool {
        allViewControllers(from: window.rootViewController).contains {
            ($0 as? UINavigationController)?.viewControllers.count ?? 0 > 1
        }
    }

    private func allViewControllers(from controller: UIViewController?) -> [UIViewController] {
        guard let controller else { return [] }
        return [controller]
            + controller.children.flatMap { allViewControllers(from: $0) }
            + allViewControllers(from: controller.presentedViewController)
    }

    private func selectedTabIndex(in window: UIWindow) -> Int? {
        let tabBars = ([window] + window.allDescendantsInFrontToBack())
            .compactMap { $0 as? UITabBar }
            .filter(\.isEffectivelyVisible)
        guard let tabBar = tabBars.first,
              let selectedItem = tabBar.selectedItem,
              let items = tabBar.items else {
            return nil
        }
        return items.firstIndex(of: selectedItem)
    }

    private func replacingStaleRoot(
        in renderedComponents: [RenderedComponent],
        with currentComponent: RenderedComponent?
    ) -> [RenderedComponent] {
        guard renderedComponents.count == 1,
              let renderedRoot = renderedComponents.first,
              let currentComponent,
              !renderedRoot.flattened.contains(where: {
                  $0.qualifiedName == currentComponent.qualifiedName
              }) else {
            return renderedComponents
        }

        return [
            RenderedComponent(
                name: currentComponent.name,
                qualifiedName: currentComponent.qualifiedName,
                frame: renderedRoot.frame,
                children: renderedRoot.children
            )
        ]
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
