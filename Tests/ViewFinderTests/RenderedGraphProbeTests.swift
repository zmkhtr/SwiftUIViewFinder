#if canImport(UIKit)
import SwiftUI
import Testing
import UIKit
@testable import ViewFinder

private struct RenderedProbeScreen: View {
    var body: some View {
        VStack {
            RenderedProbeHeader()
            RenderedProbeCard()
        }
    }
}

private struct RenderedProbeHeader: View {
    var body: some View {
        Text("Header")
    }
}

private struct RenderedProbeCard: View {
    var body: some View {
        Text("Card")
    }
}

@MainActor
@Test
func privateRenderedGraphContainsApplicationTypeNames() {
    let snapshot = PrivateRenderedHierarchyProbe.capture(rootView: RenderedProbeScreen())
    let typeNames = snapshot?.discoveredTypeNames ?? []

    print("[ViewFinder] Private rendered-graph types:\n\(typeNames.joined(separator: "\n"))")

    #expect(snapshot != nil)
    if snapshot?.requestedAllProperties == true {
        for expectedName in ["RenderedProbeScreen", "RenderedProbeHeader", "RenderedProbeCard"] {
            #expect(
                typeNames.contains { $0.contains(expectedName) },
                "Missing \(expectedName). Serialized graph: \(snapshot?.json ?? "nil")"
            )
        }
    } else {
        #expect(typeNames.isEmpty)
    }
}

@MainActor
@Test
func capturesFromMountedHostingViewWithUnknownContentType() {
    #expect(PrivateRenderedHierarchyProbe.prepareForGraphCreation())

    let hostingView = _UIHostingView(rootView: RenderedProbeScreen())
    hostingView.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
    let window = UIWindow(frame: hostingView.frame)
    window.addSubview(hostingView)
    window.isHidden = false
    hostingView.layoutIfNeeded()
    hostingView._renderForTest(interval: 0)

    let snapshot = PrivateRenderedHierarchyProbe.capture(
        fromUnknownHostingView: hostingView as UIView
    )
    let components = RenderedGraphParser.parse(json: snapshot?.json ?? "")

    #expect(snapshot != nil)
    #expect(components.flatMap(\.flattened).contains { $0.name == "RenderedProbeScreen" })
}
#endif
