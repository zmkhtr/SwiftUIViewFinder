import SwiftUI

public extension View {
    /// Enables safe mounted component logging and overlays.
    ///
    /// The modifier does not execute application view bodies or use SwiftUI's
    /// private rendered-graph serializer.
    func enableViewFinder(
        mode: InspectionMode = .overlayAndLogs,
        overlayStyle: OverlayStyle = .compact
    ) -> some View {
        return modifier(
            ViewFinderRootModifier(
                contentForInspection: self,
                mode: mode,
                overlayStyle: overlayStyle
            )
        )
    }

    /// Marks this exact mounted component for reliable live overlay tracking.
    ///
    /// Use this on custom component instances when SwiftUI's private rendered
    /// graph erases their boundary, such as children inside `TabView`.
    func viewFinderComponent(
        isActive: Bool = true,
        fileID: StaticString = #fileID,
        line: UInt = #line
    ) -> some View {
        modifier(
            ViewFinderComponentModifier(
                componentType: Self.self,
                isActive: isActive,
                sourceLocation: "\(fileID):\(line)"
            )
        )
    }
}

private struct ViewFinderRootModifier<InspectedContent: View>: ViewModifier {
    let contentForInspection: InspectedContent
    let mode: InspectionMode
    let overlayStyle: OverlayStyle
    @State private var markedComponents: [RenderedComponent] = []

    func body(content: Content) -> some View {
        let currentRoots = StaticViewHierarchyInspector()
            .inspect(contentForInspection)
            .roots

        content
            .coordinateSpace(name: ViewFinderCoordinateSpace.root)
            .onPreferenceChange(ViewFinderComponentPreferenceKey.self) {
                markedComponents = $0
            }
            .overlay {
                #if canImport(UIKit)
                ViewFinderLocator(
                    mode: mode,
                    overlayStyle: overlayStyle,
                    currentRoots: currentRoots,
                    markedComponents: markedComponents
                )
                    .allowsHitTesting(false)
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

private enum ViewFinderCoordinateSpace {
    static let root = "ViewFinder.RootCoordinateSpace"
}

private struct ViewFinderComponentModifier<Component: View>: ViewModifier {
    let componentType: Component.Type
    let isActive: Bool
    let sourceLocation: String

    func body(content: Content) -> some View {
        content.background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: ViewFinderComponentPreferenceKey.self,
                    value: isActive ? [
                        RenderedComponent(
                            name: readableName,
                            qualifiedName: qualifiedName,
                            frame: proxy.frame(in: .named(ViewFinderCoordinateSpace.root)),
                            sourceLocation: sourceLocation,
                            children: []
                        )
                    ] : []
                )
            }
        }
    }

    private var qualifiedName: String {
        String(reflecting: componentType)
    }

    private var readableName: String {
        let beforeGeneric = qualifiedName.split(separator: "<", maxSplits: 1).first.map(String.init)
            ?? qualifiedName
        return beforeGeneric.split(separator: ".").last.map(String.init) ?? beforeGeneric
    }
}

private struct ViewFinderComponentPreferenceKey: PreferenceKey {
    static let defaultValue: [RenderedComponent] = []

    static func reduce(value: inout [RenderedComponent], nextValue: () -> [RenderedComponent]) {
        value.append(contentsOf: nextValue())
    }
}
