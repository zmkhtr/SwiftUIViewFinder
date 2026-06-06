import SwiftUI
import ViewFinder

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
private enum ViewFinderResearch {
    @MainActor
    static func main() {
        ViewFinder.enable(mode: .logs)
        let report = ViewFinder.inspect(
            HomeScreen(),
            options: HierarchyOptions(bodyEvaluationPolicy: .unsafe)
        )

        guard report.roots.first?.flattenedNames.contains("ProfileHeaderView") == true else {
            fatalError("The prototype did not recover expected application component names.")
        }
    }
}
