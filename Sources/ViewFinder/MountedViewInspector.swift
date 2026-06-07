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
    private var currentRoots: [ComponentNode] = []
    private var markedComponents: [RenderedComponent] = []

    func startMonitoring(
        from locator: UIView,
        mode: InspectionMode,
        style: OverlayStyle,
        currentRoots: [ComponentNode],
        markedComponents: [RenderedComponent]
    ) {
        if self.locator === locator,
           self.mode == mode,
           self.style == style,
           self.currentRoots == currentRoots,
           self.markedComponents == markedComponents,
           refreshTimer != nil {
            return
        }

        self.locator = locator
        self.mode = mode
        self.style = style
        self.currentRoots = currentRoots
        self.markedComponents = markedComponents

        guard mode != .off else {
            stopMonitoring(from: locator)
            return
        }

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
        currentRoots = []
        markedComponents = []
        overlayManager.hide()
    }

    private func refresh() {
        guard let locator, mode != .off else {
            return
        }

        guard locator.window != nil else {
            if mode.includesLogs, lastHierarchyText != "(graph unavailable)" {
                print("[ViewFinder] Mounted overlay host is unavailable.")
                NSLog("[ViewFinder] Mounted overlay host is unavailable.")
                logger.warning("Mounted overlay host is unavailable.")
                lastHierarchyText = "(graph unavailable)"
            }
            overlayManager.showStatus("ViewFinder: host unavailable", relativeTo: locator)
            return
        }

        let roots = rootComponents(frame: locator.bounds)
        let components = deduplicated(roots.flatMap(\.flattened) + markedComponents)

        let renderedTree = roots.map { $0.formattedTree() }.joined(separator: "\n")
        let markedTree = markedComponents
            .map {
                "\($0.name)\($0.frame.map { " \($0.integral)" } ?? "")"
                    + ($0.sourceLocation.map { " [\($0)]" } ?? "")
            }
            .joined(separator: "\n")
        let tree = [renderedTree, markedTree]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
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
                overlayManager.show(components: components, relativeTo: locator, style: style)
            } else {
                overlayManager.showStatus("ViewFinder: no component frames", relativeTo: locator)
            }
        } else {
            overlayManager.hide()
        }
    }

    private func deduplicated(_ components: [RenderedComponent]) -> [RenderedComponent] {
        var result: [RenderedComponent] = []
        for component in components where !result.contains(where: {
            $0.qualifiedName == component.qualifiedName && $0.frame == component.frame
        }) {
            result.append(component)
        }
        return result
    }

    private func rootComponents(frame: CGRect) -> [RenderedComponent] {
        currentRoots.map {
            RenderedComponent(
                name: $0.name,
                qualifiedName: $0.qualifiedName,
                frame: frame,
                children: []
            )
        }
    }
}

struct ViewFinderLocator: UIViewRepresentable {
    let mode: InspectionMode
    let overlayStyle: OverlayStyle
    let currentRoots: [ComponentNode]
    let markedComponents: [RenderedComponent]

    func makeUIView(context: Context) -> UIView {
        let view = PassThroughOverlayView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        MountedViewInspector.shared.startMonitoring(
            from: view,
            mode: mode,
            style: overlayStyle,
            currentRoots: currentRoots,
            markedComponents: markedComponents
        )
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        MountedViewInspector.shared.startMonitoring(
            from: uiView,
            mode: mode,
            style: overlayStyle,
            currentRoots: currentRoots,
            markedComponents: markedComponents
        )
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: ()) {
        MountedViewInspector.shared.stopMonitoring(from: uiView)
    }
}

@MainActor
final class ViewFinderOverlayManager {
    private weak var overlayView: UIView?
    private weak var overlayHost: UIView?
    private var renderedComponents: [RenderedComponent] = []
    private var renderedStyle: OverlayStyle?
    private var renderedBounds: CGRect = .null

    func show(components: [RenderedComponent], relativeTo overlayHost: UIView, style: OverlayStyle) {
        if self.overlayHost === overlayHost,
           renderedComponents == components,
           renderedStyle == style,
           renderedBounds == overlayHost.bounds,
           overlayView?.superview === overlayHost {
            return
        }
        hide()

        let container = PassThroughOverlayView(frame: overlayHost.bounds)
        container.backgroundColor = .clear
        container.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.accessibilityIdentifier = "ViewFinderOverlay"
        let safeArea = safeAreaFrame(relativeTo: overlayHost)

        let visibleComponents = components
            .compactMap { component -> (RenderedComponent, CGRect)? in
                guard let frame = component.frame else { return nil }
                guard frame.intersects(overlayHost.bounds), frame.width > 8, frame.height > 8 else {
                    return nil
                }
                return (component, frame)
            }
            .prefix(40)

        for (component, frame) in visibleComponents {
            let border = PassThroughOverlayView(frame: frame)
            border.layer.borderColor = UIColor.systemPink.withAlphaComponent(0.8).cgColor
            border.layer.borderWidth = 1
            border.backgroundColor = UIColor.systemPink.withAlphaComponent(0.04)

            let label = UILabel()
            label.text = style == .detailed
                ? detailedLabel(for: component, frame: frame)
                : component.name
            label.font = .monospacedSystemFont(ofSize: 9, weight: .semibold)
            label.textColor = .white
            label.backgroundColor = UIColor.systemPink.withAlphaComponent(0.9)
            label.numberOfLines = 1
            label.sizeToFit()
            label.frame.size.width += 6
            label.frame.size.height += 2
            label.frame.size.width = min(label.frame.width, safeArea.width)
            label.frame.origin = labelOrigin(
                labelSize: label.frame.size,
                componentFrame: frame,
                safeArea: safeArea
            )
            label.isUserInteractionEnabled = false
            border.addSubview(label)
            container.addSubview(border)
        }

        overlayHost.addSubview(container)
        overlayView = container
        self.overlayHost = overlayHost
        renderedComponents = components
        renderedStyle = style
        renderedBounds = overlayHost.bounds
    }

    func showStatus(_ text: String, relativeTo view: UIView) {
        hide()

        let label = UILabel()
        label.text = text
        label.font = .monospacedSystemFont(ofSize: 11, weight: .bold)
        label.textColor = .white
        label.backgroundColor = UIColor.systemPink.withAlphaComponent(0.92)
        label.layer.cornerRadius = 6
        label.layer.masksToBounds = true
        label.textAlignment = .center
        let safeArea = safeAreaFrame(relativeTo: view)
        label.frame = CGRect(x: safeArea.minX + 12, y: safeArea.minY + 8, width: 220, height: 28)
        label.isUserInteractionEnabled = false
        label.accessibilityIdentifier = "ViewFinderOverlayStatus"
        view.addSubview(label)
        overlayView = label
    }

    func hide() {
        overlayView?.removeFromSuperview()
        overlayView = nil
        overlayHost = nil
        renderedComponents = []
        renderedStyle = nil
        renderedBounds = .null
    }

    private func detailedLabel(for component: RenderedComponent, frame: CGRect) -> String {
        let source = component.sourceLocation.map { " \($0)" } ?? ""
        return "\(component.name) \(Int(frame.width))×\(Int(frame.height))\(source)"
    }

    private func labelOrigin(labelSize: CGSize, componentFrame: CGRect, safeArea: CGRect) -> CGPoint {
        let xInHost = min(
            max(componentFrame.minX + 2, safeArea.minX + 2),
            safeArea.maxX - labelSize.width - 2
        )
        let yInHost = min(
            max(componentFrame.minY + 2, safeArea.minY + 2),
            safeArea.maxY - labelSize.height - 2
        )
        return CGPoint(x: xInHost - componentFrame.minX, y: yInHost - componentFrame.minY)
    }

    private func safeAreaFrame(relativeTo view: UIView) -> CGRect {
        guard let window = view.window else {
            return view.bounds
        }
        return view.convert(window.safeAreaLayoutGuide.layoutFrame, from: window)
            .intersection(view.bounds)
    }
}

final class PassThroughOverlayView: UIView {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        false
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        nil
    }
}

#endif
