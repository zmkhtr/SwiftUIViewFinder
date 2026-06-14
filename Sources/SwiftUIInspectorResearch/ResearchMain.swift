import SwiftUI
import SwiftUIInspector

private struct HomeScreen: View {
    var body: some View {
        VStack {
            ProfileHeaderView()
            UserCardView()
        }
    }
}

private struct ProfileHeaderView: View {
    var body: some View {
        AvatarView()
    }
}

private struct UserCardView: View {
    var body: some View {
        Text("User")
    }
}

private struct AvatarView: View {
    var body: some View {
        Image(systemName: "person.circle")
    }
}

@main
private enum SwiftUIInspectorResearch {
    @MainActor
    static func main() {
        SwiftUIInspector.enable(mode: .logs)
        let report = SwiftUIInspector.inspect(
            HomeScreen(),
            options: HierarchyOptions(bodyEvaluationPolicy: .unsafe)
        )

        guard report.roots.first?.flattenedNames.contains("ProfileHeaderView") == true else {
            fatalError("The prototype did not recover expected application component names.")
        }
    }
}
