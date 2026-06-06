import SwiftUI

public extension View {
    /// Enables mounted rendered-graph logging and component overlays.
    ///
    /// The modifier does not execute application view bodies. On supported
    /// SwiftUI runtimes it inspects the mounted private rendered graph.
    func enableViewFinder(
        mode: InspectionMode = .overlayAndLogs,
        overlayStyle: OverlayStyle = .compact
    ) -> some View {
        #if canImport(UIKit)
        _ = PrivateRenderedHierarchyProbe.prepareForGraphCreation()
        #endif

        return modifier(
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
        let currentRoots = StaticViewHierarchyInspector()
            .inspect(contentForInspection)
            .roots

        content
            .background {
                #if canImport(UIKit)
                ViewFinderLocator(
                    mode: mode,
                    overlayStyle: overlayStyle,
                    currentRoots: currentRoots
                )
                    .frame(width: 0, height: 0)
                #endif
            }
            .onAppear {
                ViewFinder.enable(mode: mode)
                if mode.includesLogs {
                    ViewFinder.inspect(contentForInspection)
                }
            }
    }
}
