# Research Findings

## Status

Phase 1 and Phase 2 were completed on June 6, 2026.

Environment:

- Xcode 26.2 (17C52)
- Apple Swift 6.2.3
- iOS 26.2 simulator
- iOS 15.5 simulator

## Question

Can SwiftUI component names be recovered automatically without modifying every
existing view?

## Answer

**Yes, conditionally.**

Meaningful application component names survive in:

1. A concrete root `View` value, where custom bodies can be evaluated and
   framework wrapper storage can be reflected.
2. SwiftUI's private rendered debug graph on iOS 26.2, after enabling all private
   `_ViewDebug` properties before graph creation.

The second path is the important finding because it also exposes rendered graph
structure, position, and size. It is private, version-dependent, and not yet
accessible globally from an arbitrary existing host.

## Runtime Model

Apple describes SwiftUI view values as short-lived inputs to a long-lived
dependency graph. SwiftUI evaluates a view's `body`, updates graph attributes,
and discards the body value. This explains why UIKit traversal alone cannot
reliably recover nested SwiftUI components and why reflecting only a
`_UIHostingView` is insufficient.

Relevant primary sources:

- [Demystify SwiftUI](https://developer.apple.com/videos/play/wwdc2021/10022/)
- [Explore SwiftUI animation](https://developer.apple.com/videos/play/wwdc2023/10156/)
- [Mirror](https://developer.apple.com/documentation/swift/mirror)
- [SwiftUI View](https://developer.apple.com/documentation/swiftui/view)
- [Swift runtime source](https://github.com/swiftlang/swift)

## SDK Symbol Findings

The Xcode 26.2 iPhone Simulator SDK exposes these underscored APIs in Swift
interfaces or text-based stubs:

```text
SwiftUI._UIHostingView._viewDebugData()
SwiftUI._UIHostingView.makeViewDebugData()
SwiftUI.ViewGraph.viewDebugData()
SwiftUI._ViewDebug.serializedData(_:)
SwiftUI._ViewDebug.properties
SwiftUI._ViewDebug.Data.data
SwiftUI._ViewDebug.Data.childData
```

`_ViewDebug.Property` supports:

```text
type
value
transform
position
size
environment
phase
layoutComputer
displayList
```

There is no source-file or line property.

Run `Scripts/inspect-swiftui-symbols.sh` to repeat the SDK inspection.

## Experiment A: Root-Value Reflection

Method:

1. Accept one concrete root `View`.
2. Evaluate application-defined `body` properties.
3. Reflect stored children inside SwiftUI framework wrappers.
4. Filter framework types such as `VStack`, `TupleView`, and `ModifiedContent`.

Result:

```text
HomeScreen
├─ ProfileHeaderView
│  └─ AvatarView
└─ UserCardView
```

Confidence: **high for simple eager view composition**, lower for lazy,
type-erased, stateful, or environment-dependent content.

This path satisfies the one-integration-point requirement, but it does not map
components to rendered pixels.

## Experiment B: Private Rendered Graph

Method:

1. Resolve the hidden Swift ABI setter for `_ViewDebug.properties` at runtime.
2. Set the properties to `.all` before creating a hosting graph.
3. Render a `_UIHostingView`.
4. Call `_viewDebugData()`.
5. Serialize through `_ViewDebug.serializedData(_:)`.

Result on iOS 26.2:

- Recovered `RenderedProbeScreen`
- Recovered `RenderedProbeHeader`
- Recovered `RenderedProbeCard`
- Recovered nested graph `children`
- Recovered `CGPoint` positions and `CGSize` sizes
- Recovered substantial framework wrapper and attribute noise
- Recovered no source file or line

Example payload fragments:

```json
{
  "type": "ViewFinderTests...RenderedProbeScreen",
  "readableType": "RenderedProbeScreen"
}
```

```json
{
  "type": "__C.CGSize",
  "value": [56, 42.666666666666664],
  "readableType": "CGSize"
}
```

Confidence: **high on the tested iOS 26.2 simulator**, unknown on other modern
versions until a compatibility matrix is built.

## Cross-Version Finding

On iOS 15.5:

- `_UIHostingView._viewDebugData()` is available.
- `_ViewDebug.serializedData(_:)` is available.
- The hidden `_ViewDebug.properties` setter used by the prototype is absent.
- Without that setter, serialized graph data is empty in the current experiment.

The package resolves the setter dynamically, so it still loads and supports the
root-value path on iOS 15.

## Failed Experiments

### UIKit traversal only

Result: finds windows, UIKit views, and hosting containers, but not the nested
SwiftUI component hierarchy.

### Unattached `_UIHostingView`

Result: `_viewDebugData()` serialized to `[]`.

### Attached host without enabling debug properties

Result: `_viewDebugData()` still serialized to `[]`.

### Hard-linking `_ViewDebug.properties`

Result: worked on iOS 26.2, but prevented the test bundle from loading on iOS
15.5 because the symbol does not exist there. Replaced with `dlsym`.

### Mirror alone

Result: useful for a supplied root value, but it cannot traverse SwiftUI's
already-rendered private graph globally.

## Source Recovery

No source path or line was present in the tested private graph payload. Runtime
type metadata provides type names, not declaration source locations.

Potential future debug-only approaches:

- Search dSYM DWARF for recovered type names.
- Resolve symbols with `dladdr` and demangle Swift symbols.
- Correlate graph types with a build-time source index.

Expected outcome: file-level recovery may be achievable with debug symbols;
reliable line-level recovery for a rendered component is unlikely without a
build-time index or compiler instrumentation.

## Feasibility Assessment

| Capability | Assessment |
| --- | --- |
| Recover custom component names from one root integration | Proven |
| Recover nested custom names from rendered SwiftUI graph | Proven on iOS 26.2 |
| Recover rendered positions and sizes | Proven on iOS 26.2 |
| Globally inspect an arbitrary existing generic hosting view | Not yet proven |
| Work through private graph path on iOS 15.5 | Not with the current symbol path |
| Recover source file or line from graph payload | Not present |
| Build overlay now | Premature |

## Phase 2 Decision

Proceed to Phase 3 hierarchy reconstruction.

The next phase must first parse and filter the rendered graph and prove access
to a real app's existing hosting graph. Overlay and inspector UI work remains
blocked until that succeeds.
