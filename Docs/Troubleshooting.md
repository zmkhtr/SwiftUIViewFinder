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
environment-dependent content, or descendants created only inside custom
`body` properties. ViewFinder deliberately does not execute application bodies
by default because doing so outside SwiftUI can crash.

## Missing ObservableObject Crash

Update to ViewFinder 0.1.1 or later. Version 0.1.0 evaluated application bodies
outside SwiftUI's mounted environment, which could trigger:

```text
Fatal error: No ObservableObject of type ... found
```

The safe default no longer evaluates application bodies.

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

The basic mounted overlay requires a SwiftUI runtime that exposes private
`_ViewDebug` properties. It works on the tested iOS 26.2 simulator and is not
available on the tested iOS 15.5 simulator. The inspector panel and selection
mode are not implemented yet.

## Multi-Window And SceneDelegate

`UIKitHierarchyInspector.inspectForegroundWindows()` scans active foreground
window scenes. Live SwiftUI graph access per scene is not implemented yet.

## iOS 15 Test Bundle Fails To Load

Do not hard-link private Swift ABI symbols. The package uses `dlsym` so missing
symbols degrade to an unavailable rendered-graph path instead of a launch
failure.
