import SwiftUI

public extension View {
    /// Enables the Phase 2 console inspector from a single SwiftUI root.
    ///
    /// The modifier evaluates and reflects the root value once when it appears.
    /// It does not map nodes to pixels and does not traverse SwiftUI's live graph.
    func enableViewFinder(
        mode: InspectionMode = .overlayAndLogs,
        overlayStyle: OverlayStyle = .compact
    ) -> some View {
        modifier(
            ViewFinderRootModifier(
                contentForInspection: self,
                mode: mode,
                overlayStyle: overlayStyle
            )
        )
    }
}

private struct ViewFinderRootModifier<InspectedContent: View>: ViewModifier {
    let contentForInspection: InspectedContent
    let mode: InspectionMode
    let overlayStyle: OverlayStyle

    func body(content: Content) -> some View {
        content.onAppear {
            ViewFinder.enable(mode: mode)
            ViewFinder.inspect(contentForInspection)
            _ = overlayStyle
        }
    }
}
