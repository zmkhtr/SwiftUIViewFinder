import SwiftUI

struct SwiftUITabScreen: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "swift")
                .font(.system(size: 60))
            Text("SwiftUI Tab Content")
                .font(.largeTitle.bold())
            Text("This SwiftUI view is a direct child of UITabBarController.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

struct PushedSwiftUIScreen: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.right.square")
                .font(.system(size: 60))
            Text("Hosted SwiftUI Content")
                .font(.largeTitle.bold())
            Text("UIKit pushed this view using UIHostingController.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
