# SwiftUIViewFinder

SwiftUIViewFinder is a research-first Swift package exploring a React DevTools-style
component inspector for SwiftUI. Consumers import the package as:

```swift
import ViewFinder
```

The project is an early private-runtime prototype. It can recover meaningful
application component names and display basic non-interactive overlays on
supported SwiftUI runtimes.

## What Works Today

Two console-first inspection paths are implemented:

| Path | Result | Important limitation |
| --- | --- | --- |
| Root-value inspection | Safely recovers custom component values stored at one root integration point | Does not execute application bodies by default |
| Private rendered-graph probe | Recovered nested custom names, graph structure, positions, and sizes on iOS 26.2 | Private ABI; the enabling symbol is absent on iOS 15.5 |
| UIKit fallback | Produces the UIKit view hierarchy | Usually exposes hosting/container classes, not nested SwiftUI components |
| Mounted overlay | Labels recovered application components on the live screen | Basic, non-interactive, and private-runtime dependent |

Validated root-value output:

```text
HomeScreen
├─ ProfileHeaderView
│  └─ AvatarView
└─ UserCardView
```

Validated private graph names on an iOS 26.2 simulator:

```text
RenderedProbeScreen
RenderedProbeHeader
RenderedProbeCard
```

See [Docs/Research.md](Docs/Research.md) for the evidence and limitations.

## Installation

Swift Package Manager:

```swift
dependencies: [
    .package(
        url: "https://github.com/zmkhtr/SwiftUIViewFinder.git",
        from: "0.1.0"
    )
]
```

Then add the `ViewFinder` product to the app target.

## Quick Start

The current SwiftUI modifier performs one console inspection when the root
appears:

```swift
import SwiftUI
import ViewFinder

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .enableViewFinder(mode: .logs)
        }
    }
}
```

Or safely inspect stored values reachable from a concrete root:

```swift
ViewFinder.enable(mode: .logs)
let report = ViewFinder.inspect(RootView())
print(report.formatted())
```

Unsafe body evaluation remains available only for controlled research views
that do not depend on SwiftUI-managed environment or dynamic properties:

```swift
let options = HierarchyOptions(bodyEvaluationPolicy: .unsafe)
ViewFinder.inspect(ResearchRootView(), options: options)
```

Global activation APIs exist, but AppDelegate-only activation cannot yet recover
an already-running live SwiftUI graph:

```swift
ViewFinder.enable()
ViewFinder.setMode(.logs)
ViewFinder.disable()
```

## Run The Prototype

```bash
swift run ViewFinderResearch
swift test
```

The private rendered-graph test requires an iOS simulator:

```bash
xcodebuild test \
  -scheme SwiftUIViewFinder-Package \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Current Decision Gate

**Proceed to Phase 3, with constraints.**

The central hypothesis is validated: custom SwiftUI component names survive in
SwiftUI's private rendered debug graph on at least iOS 26.2. The next work should
focus on:

1. Parsing `_ViewDebug` JSON into a filtered component tree.
2. Accessing the live hosting graph without knowing its generic `Content` type.
3. Testing the private path across iOS versions.
4. Improving frame correlation and overlay filtering.

Do not build the inspector panel until those tasks work on real app hosts.

## Limitations

- This is debug-only research software.
- Private APIs and Swift ABI symbols may change without notice.
- iOS 15.5 does not expose the private `_ViewDebug.properties` setter used by
  the current rendered-graph prototype.
- Safe root-value inspection does not execute custom `body` properties, because
  doing so outside SwiftUI can trap on `@EnvironmentObject` and other dynamic
  properties. Deeper descendants can therefore be missing.
- The private graph payload tested so far contains no source file or line field.
- The current overlay is non-interactive and may contain noisy or overlapping labels.
- UIKit activation alone currently yields only a UIKit hierarchy.

## Documentation

- [Research findings](Docs/Research.md)
- [Architecture](Docs/Architecture.md)
- [Troubleshooting](Docs/Troubleshooting.md)
- [Contributing](CONTRIBUTING.md)

## License

MIT
