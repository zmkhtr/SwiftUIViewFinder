#if canImport(UIKit)
import SwiftUI
import Testing
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
#endif
