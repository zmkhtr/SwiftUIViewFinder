import SwiftUI
import UIKit

final class DemoTabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let uiKitTab = UINavigationController(rootViewController: UIKitHomeViewController())
        uiKitTab.tabBarItem = UITabBarItem(
            title: "UIKit",
            image: UIImage(systemName: "rectangle.3.group"),
            tag: 0
        )

        let swiftUITab = UIHostingController(rootView: SwiftUITabScreen())
        swiftUITab.tabBarItem = UITabBarItem(
            title: "SwiftUI",
            image: UIImage(systemName: "swift"),
            tag: 1
        )

        viewControllers = [uiKitTab, swiftUITab]
    }
}
