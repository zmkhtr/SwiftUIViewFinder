# UIKit Demo

This UIKit application enables SwiftUIInspector from `AppDelegate` and verifies
two UIKit-to-SwiftUI integration paths:

- A `SwiftUITabScreen` hosted directly inside `UITabBarController`.
- A `PushedSwiftUIScreen` pushed from UIKit with `UIHostingController`.

Generate and test the project:

```bash
cd Example/UIKitDemo
swift package resolve --package-path Tuist
tuist generate --no-open
xcodebuild test \
  -workspace UIKitDemo.xcworkspace \
  -scheme UIKitDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```
