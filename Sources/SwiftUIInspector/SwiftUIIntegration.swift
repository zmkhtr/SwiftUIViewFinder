import SwiftUI

public extension View {
    /// Enables safe mounted component logging and overlays.
    ///
    /// The modifier does not execute application view bodies or use SwiftUI's
    /// private rendered-graph serializer.
    func enableSwiftUIInspector(
        mode: InspectionMode = .overlayAndLogs,
        overlayStyle: OverlayStyle = .compact
    ) -> some View {
        return modifier(
            SwiftUIInspectorRootModifier(
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
    func swiftUIInspectorComponent(
        isActive: Bool = true,
        fileID: StaticString = #fileID,
        line: UInt = #line
    ) -> some View {
        modifier(
            SwiftUIInspectorComponentModifier(
                componentType: Self.self,
                isActive: isActive,
                sourceLocation: "\(fileID):\(line)"
            )
        )
    }
}

private struct SwiftUIInspectorRootModifier<InspectedContent: View>: ViewModifier {
    let contentForInspection: InspectedContent
    let mode: InspectionMode
    let overlayStyle: OverlayStyle
    @State private var markedComponents: [RenderedComponent] = []

    func body(content: Content) -> some View {
        let currentRoots = StaticViewHierarchyInspector()
            .inspect(contentForInspection)
            .roots

        content
            .coordinateSpace(name: SwiftUIInspectorCoordinateSpace.root)
            .onPreferenceChange(SwiftUIInspectorComponentPreferenceKey.self) {
                markedComponents = $0
            }
            .overlay {
                #if canImport(UIKit)
                SwiftUIInspectorLocator(
                    mode: mode,
                    overlayStyle: overlayStyle,
                    currentRoots: currentRoots,
                    markedComponents: markedComponents
                )
                    .allowsHitTesting(false)
                #endif
            }
            .onAppear {
                SwiftUIInspector.enable(mode: mode)
                if mode.includesLogs {
                    SwiftUIInspector.inspect(contentForInspection)
                }
            }
    }
}

private enum SwiftUIInspectorCoordinateSpace {
    static let root = "SwiftUIInspector.RootCoordinateSpace"
}

private struct SwiftUIInspectorComponentModifier<Component: View>: ViewModifier {
    let componentType: Component.Type
    let isActive: Bool
    let sourceLocation: String

    func body(content: Content) -> some View {
        content.background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: SwiftUIInspectorComponentPreferenceKey.self,
                    value: isActive ? [
                        RenderedComponent(
                            name: readableName,
                            qualifiedName: qualifiedName,
                            frame: proxy.frame(in: .named(SwiftUIInspectorCoordinateSpace.root)),
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

private struct SwiftUIInspectorComponentPreferenceKey: PreferenceKey {
    static let defaultValue: [RenderedComponent] = []

    static func reduce(value: inout [RenderedComponent], nextValue: () -> [RenderedComponent]) {
        value.append(contentsOf: nextValue())
    }
}
