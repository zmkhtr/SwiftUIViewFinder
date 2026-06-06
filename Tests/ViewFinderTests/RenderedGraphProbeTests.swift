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

@Test
func parsesApplicationTypeNestedInsideFrameworkWrapper() {
    let json = """
    [{
      "properties": [
        {"attribute": {
          "type": "SwiftUI.ModifiedContent<Khatm.HomeScreen, SwiftUI._PaddingLayout>",
          "readableType": "ModifiedContent<HomeScreen, _PaddingLayout>",
          "flags": 0
        }},
        {"attribute": {"type": "__C.CGPoint", "readableType": "CGPoint", "value": [12, 24]}},
        {"attribute": {"type": "__C.CGSize", "readableType": "CGSize", "value": [100, 80]}}
      ],
      "children": []
    }]
    """

    let components = RenderedGraphParser.parse(json: json)

    #expect(components.first?.name == "HomeScreen")
    #expect(components.first?.frame == CGRect(x: 12, y: 24, width: 100, height: 80))
}

@Test
func replacesStaleRenderedRootWithCurrentSafeRoot() {
    let frame = CGRect(x: 0, y: 62, width: 402, height: 778)
    let rendered = RenderedComponent(
        name: "OnboardingScreen",
        qualifiedName: "Khatm.OnboardingScreen",
        frame: frame,
        children: []
    )
    let current = ComponentNode(
        name: "ContentView",
        qualifiedName: "Khatm.ContentView",
        origin: .rootValue
    )

    let components = RenderedComponentReconciler.reconcile(
        renderedRoots: [rendered],
        currentRoots: [current]
    )

    #expect(components.first?.name == "ContentView")
    #expect(components.first?.qualifiedName == "Khatm.ContentView")
    #expect(components.first?.frame == frame)
}
#endif
