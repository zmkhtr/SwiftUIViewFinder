import SwiftUI
import UIKit

final class UIKitHomeViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "UIKit Root"
        view.backgroundColor = .systemBackground

        let titleLabel = UILabel()
        titleLabel.text = "UIKit Root Content"
        titleLabel.font = .preferredFont(forTextStyle: .title1)
        titleLabel.textAlignment = .center

        let pushButton = UIButton(type: .system)
        pushButton.configuration = .filled()
        pushButton.configuration?.title = "Push SwiftUI Screen"
        pushButton.accessibilityIdentifier = "Push SwiftUI Screen"
        pushButton.addTarget(self, action: #selector(pushSwiftUIScreen), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [titleLabel, pushButton])
        stack.axis = .vertical
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
        ])
    }

    @objc
    private func pushSwiftUIScreen() {
        let controller = UIHostingController(rootView: PushedSwiftUIScreen())
        controller.title = "Hosted SwiftUI"
        navigationController?.pushViewController(controller, animated: true)
    }
}
