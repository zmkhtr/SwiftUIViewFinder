import SwiftUI
import Testing
@testable import SwiftUIInspector

private struct TestHomeScreen: View {
    var body: some View {
        VStack {
            TestProfileHeaderView()
            TestUserCardView()
        }
    }
}

private struct TestProfileHeaderView: View {
    var body: some View {
        TestAvatarView()
    }
}

private struct TestUserCardView: View {
    var body: some View {
        Text("User")
    }
}

private struct TestAvatarView: View {
    var body: some View {
        Image(systemName: "person.circle")
    }
}

@MainActor
@Test
func recoversApplicationViewNamesFromRootValue() {
    let report = StaticViewHierarchyInspector(
        options: HierarchyOptions(bodyEvaluationPolicy: .unsafe)
    ).inspect(TestHomeScreen())
    let names = report.roots.flatMap(\.flattenedNames)

    #expect(names.contains("TestHomeScreen"))
    #expect(names.contains("TestProfileHeaderView"))
    #expect(names.contains("TestUserCardView"))
    #expect(names.contains("TestAvatarView"))
}

@MainActor
@Test
func filtersFrameworkWrapperTypesByDefault() {
    let report = StaticViewHierarchyInspector(
        options: HierarchyOptions(bodyEvaluationPolicy: .unsafe)
    ).inspect(TestHomeScreen())
    let names = report.roots.flatMap(\.flattenedNames)

    #expect(!names.contains("VStack"))
    #expect(!names.contains("TupleView"))
    #expect(!names.contains("ModifiedContent"))
}

private final class MissingEnvironmentModel: ObservableObject {}

private struct EnvironmentDependentView: View {
    @EnvironmentObject private var model: MissingEnvironmentModel

    var body: some View {
        Text(String(describing: model))
    }
}

@MainActor
@Test
func doesNotEvaluateEnvironmentDependentBodyByDefault() {
    let report = StaticViewHierarchyInspector().inspect(EnvironmentDependentView())

    #expect(report.roots.flatMap(\.flattenedNames) == ["EnvironmentDependentView"])
    #expect(report.warnings.contains { $0.contains("were not evaluated") })
}

@MainActor
@Test
func disabledGlobalEntryPointDoesNoInspection() {
    SwiftUIInspector.disable()

    let report = SwiftUIInspector.inspect(TestHomeScreen())

    #expect(report.roots.isEmpty)
}

@Test
func formatsComponentTree() {
    let tree = ComponentNode(
        name: "HomeScreen",
        qualifiedName: "Demo.HomeScreen",
        origin: .rootValue,
        children: [
            ComponentNode(
                name: "AvatarView",
                qualifiedName: "Demo.AvatarView",
                origin: .evaluatedBody
            )
        ]
    )

    #expect(tree.formattedTree() == "HomeScreen\n└─ AvatarView")
}
