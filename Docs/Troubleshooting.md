# Troubleshooting

## No Components Found

Confirm ViewFinder is enabled before inspection:

```swift
ViewFinder.enable(mode: .logs)
ViewFinder.inspect(RootView())
```

`ViewFinder.inspect` intentionally returns an empty report while mode is `.off`.

## Only The Root Appears

Root-value inspection may not cross `AnyView`, lazy containers, closures,
environment-dependent content, or views whose body cannot be evaluated safely
outside SwiftUI's normal update cycle.

## Private Rendered Graph Is Empty

Common causes:

- The hosting view is not attached and rendered.
- The current OS does not export the private `_ViewDebug.properties` setter.
- SwiftUI changed its private ABI.

Check `RenderedHierarchySnapshot.requestedAllProperties`. It is `false` on the
tested iOS 15.5 runtime.

## UIKit Hierarchy Only

UIKit traversal does not normally expose nested SwiftUI components. Use the root
SwiftUI modifier or the research rendered-graph probe.

## Overlay Or Inspector Not Appearing

They are not implemented at the Phase 2 decision gate. The `.overlay` and
`.overlayAndLogs` cases reserve the intended API surface; only log output exists.

## Multi-Window And SceneDelegate

`UIKitHierarchyInspector.inspectForegroundWindows()` scans active foreground
window scenes. Live SwiftUI graph access per scene is not implemented yet.

## iOS 15 Test Bundle Fails To Load

Do not hard-link private Swift ABI symbols. The package uses `dlsym` so missing
symbols degrade to an unavailable rendered-graph path instead of a launch
failure.
