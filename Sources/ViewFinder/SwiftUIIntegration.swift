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
        content
            .background {
                #if canImport(UIKit)
                ViewFinderLocator(mode: mode, overlayStyle: overlayStyle)
                    .frame(width: 0, height: 0)
                #endif
            }
            .onAppear {
                ViewFinder.enable(mode: mode)
                if mode.includesLogs {
                    ViewFinder.inspect(contentForInspection)
                }
            }
            .overlay(alignment: .topLeading) {
                if mode.includesOverlay {
                    Text("ViewFinder active")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(.pink.opacity(0.9), in: RoundedRectangle(cornerRadius: 5))
                        .allowsHitTesting(false)
                        .accessibilityIdentifier("ViewFinderActiveBadge")
                }
            }
    }
}
