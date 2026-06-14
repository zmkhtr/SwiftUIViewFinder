import SwiftUIInspector
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        SwiftUIInspector.enable(mode: .overlayAndLogs)

        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = DemoTabBarController()
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}
