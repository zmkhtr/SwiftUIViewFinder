#if canImport(UIKit)
import UIKit
import os

private struct NavigationSignature: Equatable {
    let window: ObjectIdentifier
    let selectedTabIndex: Int?
    let navigationDepth: Int
    let topViewController: ObjectIdentifier?
    let hostingViews: [ObjectIdentifier]
    let bounds: CGRect
    let hasPresentation: Bool
}

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
    private var registeredTabComponents: [RenderedComponent] = []
    private var lastNavigationSignature: NavigationSignature?
    private var cachedInspectedComponents: (hostingView: UIView, components: [RenderedComponent])?

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

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
        refreshTimer?.tolerance = 0.03
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
        lastNavigationSignature = nil
        cachedInspectedComponents = nil
    }

    private func refresh() {
        guard mode != .off,
              let sourceWindow = frontmostApplicationWindow() else {
            overlayManager.hide()
            return
        }

        let controllers = allViewControllers(from: sourceWindow.rootViewController)
        let navigationDepth = controllers
            .compactMap { ($0 as? UINavigationController)?.viewControllers.count }
            .max() ?? 0
        let presentedController = presentedViewController(in: sourceWindow)
        let hasPresentation = presentedController != nil
        let presentedControllers = allViewControllers(from: presentedController)
        let hasAppOwnedPresentation = frontmostControllerComponent(
            in: presentedControllers,
            frame: sourceWindow.bounds
        ) != nil
        let hasFullScreenPresentation = hasAppOwnedPresentation
            || (presentedController.map(isFullScreenPresentation) ?? false)
        let controllerTabIndex = controllers
            .compactMap { $0 as? UITabBarController }
            .first(where: { $0.viewIfLoaded?.window === sourceWindow })?
            .selectedIndex
        let lightweightSignature = NavigationSignature(
            window: ObjectIdentifier(sourceWindow),
            selectedTabIndex: controllerTabIndex,
            navigationDepth: navigationDepth,
            topViewController: topViewControllerIdentifier(in: controllers),
            hostingViews: [],
            bounds: sourceWindow.bounds,
            hasPresentation: hasPresentation
        )

        if hasPresentation && !hasFullScreenPresentation {
            overlayManager.hide()
            overlayWindow?.isHidden = true
            lastNavigationSignature = lightweightSignature
            cachedInspectedComponents = nil
            return
        }
        overlayWindow?.isHidden = false

        guard let overlayHost = overlayHost(for: sourceWindow) else {
            overlayManager.hide()
            return
        }

        let convertedComponents: [RenderedComponent]
        if !hasFullScreenPresentation,
           navigationDepth <= 1,
           let selectedTabIndex = controllerTabIndex,
           registeredTabComponents.indices.contains(selectedTabIndex) {
            let component = registeredTabComponents[selectedTabIndex]
            convertedComponents = [
                RenderedComponent(
                    name: component.name,
                    qualifiedName: component.qualifiedName,
                    frame: overlayHost.convert(sourceWindow.bounds, from: sourceWindow),
                    children: []
                )
            ]
            cachedInspectedComponents = nil
            lastNavigationSignature = lightweightSignature
        } else {
            let descendants = sourceWindow.allDescendantsInFrontToBack()
            let hostingViews = descendants.filter {
                String(describing: type(of: $0)).contains("HostingView")
                    && $0.isEffectivelyVisible
                    && $0.bounds.width > 8
                    && $0.bounds.height > 8
            }
            let selectedTabIndex = controllerTabIndex
                ?? selectedTabIndex(in: sourceWindow, descendants: descendants)
            let signature = NavigationSignature(
                window: lightweightSignature.window,
                selectedTabIndex: selectedTabIndex,
                navigationDepth: navigationDepth,
                topViewController: lightweightSignature.topViewController,
                hostingViews: hostingViews.map(ObjectIdentifier.init),
                bounds: lightweightSignature.bounds,
                hasPresentation: false
            )
            if signature != lastNavigationSignature {
                if let component = frontmostControllerComponent(in: controllers, frame: sourceWindow.bounds) {
                    cachedInspectedComponents = (sourceWindow, [component])
                } else {
                    cachedInspectedComponents = frontmostRenderedComponents(hostingViews: hostingViews)
                }
            }
            guard let cachedInspectedComponents else {
                overlayManager.hide()
                lastNavigationSignature = signature
                return
            }
            convertedComponents = cachedInspectedComponents.components.map {
                converted($0, from: cachedInspectedComponents.hostingView, to: overlayHost)
            }
            lastNavigationSignature = signature
        }

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

    private func frontmostRenderedComponents(hostingViews: [UIView]) -> (UIView, [RenderedComponent])? {
        for hostingView in hostingViews.reversed() {
            let mounted = MountedHostingViewReflector.components(in: hostingView)
            let components = mounted.isEmpty
                ? PrivateRenderedHierarchyProbe.reflectedComponents(fromUnknownHostingView: hostingView)
                : mounted
            guard !components.isEmpty else { continue }
            let mountedText = components.map(\.qualifiedName).joined(separator: "\n")
            if mode.includesLogs, mountedText != lastMountedTypesText {
                lastMountedTypesText = mountedText
                print("[ViewFinder] Current mounted application types:\n\(mountedText)")
            }
            return (hostingView, components)
        }
        return nil
    }

    private func presentedViewController(in window: UIWindow) -> UIViewController? {
        allViewControllers(from: window.rootViewController)
            .reversed()
            .first {
                $0.presentingViewController != nil
                    && !$0.isBeingDismissed
                    && $0.viewIfLoaded?.window != nil
            }
    }

    private func isFullScreenPresentation(_ controller: UIViewController) -> Bool {
        if controller.presentationController is UISheetPresentationController {
            return false
        }
        return controller.modalPresentationStyle == .fullScreen
            || controller.modalPresentationStyle == .overFullScreen
            || controller.presentationController?.shouldPresentInFullscreen == true
    }

    private func frontmostControllerComponent(
        in controllers: [UIViewController],
        frame: CGRect
    ) -> RenderedComponent? {
        let module = preferredModuleName
        guard !module.isEmpty else { return nil }
        let pattern = #"[A-Za-z_][A-Za-z0-9_]*\.[A-Za-z_][A-Za-z0-9_]*"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }

        for controller in controllers.reversed() {
            let type = String(reflecting: Swift.type(of: controller))
            let range = NSRange(type.startIndex..<type.endIndex, in: type)
            let candidates = expression.matches(in: type, range: range).compactMap { match -> String? in
                guard let range = Range(match.range, in: type) else { return nil }
                let candidate = String(type[range])
                return candidate.hasPrefix("\(module).") && isLikelyComponentName(candidate)
                    ? candidate
                    : nil
            }
            if let qualifiedName = candidates.last {
                return RenderedComponent(
                    name: qualifiedName.split(separator: ".").last.map(String.init) ?? qualifiedName,
                    qualifiedName: qualifiedName,
                    frame: frame,
                    children: []
                )
            }
        }
        return nil
    }

    private func isLikelyComponentName(_ qualifiedName: String) -> Bool {
        let name = qualifiedName.split(separator: ".").last.map(String.init) ?? qualifiedName
        return ["View", "Screen", "Section", "Card", "Row"].contains {
            name.hasSuffix($0)
        }
    }

    private var preferredModuleName: String {
        let executable = Bundle.main.object(forInfoDictionaryKey: "CFBundleExecutable") as? String
        return executable?.replacingOccurrences(of: " ", with: "_") ?? ""
    }

    private func allViewControllers(from controller: UIViewController?) -> [UIViewController] {
        guard let controller else { return [] }
        return [controller]
            + controller.children.flatMap { allViewControllers(from: $0) }
            + allViewControllers(from: controller.presentedViewController)
    }

    private func selectedTabIndex(
        in window: UIWindow,
        descendants: [UIView]
    ) -> Int? {
        let tabBars = ([window] + descendants)
            .compactMap { $0 as? UITabBar }
            .filter(\.isEffectivelyVisible)
        guard let tabBar = tabBars.first,
              let selectedItem = tabBar.selectedItem,
              let items = tabBar.items else {
            return nil
        }
        return items.firstIndex(of: selectedItem)
    }

    private func topViewControllerIdentifier(in controllers: [UIViewController]) -> ObjectIdentifier? {
        let navigationTop = controllers
            .compactMap { ($0 as? UINavigationController)?.topViewController }
            .last
        guard let top = navigationTop ?? controllers.last else { return nil }
        return ObjectIdentifier(top)
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
            window.isUserInteractionEnabled = false
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

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        nil
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
