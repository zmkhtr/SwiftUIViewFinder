# Changelog

## 0.6.0

SwiftUIInspector's first consolidated release packages the complete runtime
inspector under one consistent repository, product, module, and import name.

### Highlights

- Enable global inspection once from SwiftUI `App.init()` or UIKit
  `AppDelegate`.
- Identify the active application view across tabs, navigation pushes,
  hidden-tab destinations, sheets, and full-screen presentations.
- Inspect SwiftUI views hosted by UIKit with `UIHostingController`, including
  hosted tab-bar children and pushed destinations.
- Draw a non-interactive pass-through overlay that keeps the inspected
  application responsive.
- Emit change-based hierarchy and mounted-type logs.
- Use lightweight navigation signatures, cached inspection results, bounded
  reflection, and transition-aware host selection to minimize runtime cost.

### SwiftUI Navigation And Presentation

- Tracks registered `TabView` roots and follows the selected tab.
- Follows navigation-controller pushes and app-owned full-screen
  presentations.
- Handles destinations that hide the tab bar.
- Hides the overlay during sheets and system presentations so controls such as
  `FamilyActivityPicker` remain interactive.
- Ignores inactive branches, dismissed presentation controllers, stale root
  identities, and hidden hosting views.

### UIKit Support

- Supports both scene-based windows and classic `AppDelegate` windows.
- Detects visible UIKit view controllers and SwiftUI content hosted inside
  `UIHostingController`.
- Includes a runnable Tuist UIKit demo with a UIKit root tab, a directly hosted
  SwiftUI tab, a pushed SwiftUI screen, and an end-to-end UI test.

### Inspection And Research APIs

- Preserves explicit `SwiftUIInspector.inspect(...)` hierarchy inspection.
- Provides opt-in `.swiftUIInspectorComponent()` source markers.
- Recovers application component names nested inside SwiftUI wrappers and
  erased root storage.
- Avoids evaluating environment-dependent application view bodies by default.
- Retains unsafe body evaluation as an explicit research-only option.

### Packaging And Documentation

- Renames the package product, module, and import to `SwiftUIInspector`.
- Supports Swift Package Manager and Tuist external dependencies.
- Adds runtime screenshots, architecture notes, research findings,
  troubleshooting guidance, and UIKit setup documentation.

> SwiftUIInspector uses private SwiftUI runtime APIs and is intended only for
> debug and research builds.
