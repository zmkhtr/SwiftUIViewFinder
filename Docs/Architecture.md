# Architecture

## Current Phase 2 Architecture

```text
Concrete Root View
  -> StaticViewHierarchyInspector
  -> evaluate application body values
  -> reflect framework wrapper storage
  -> filter framework types
  -> ComponentNode tree

Known _UIHostingView<Content>
  -> enable private _ViewDebug properties
  -> render graph
  -> _viewDebugData()
  -> serialized JSON
  -> discovered application type names

Foreground UIWindow
  -> UIKitHierarchyInspector
  -> UIView class-name tree
```

## Public Surface

The package product and public module are both named `ViewFinder`.

```swift
ViewFinder.enable()
ViewFinder.enable(mode: .logs)
ViewFinder.disable()
ViewFinder.setMode(.off)
ViewFinder.inspect(rootView)
```

SwiftUI integration:

```swift
RootView()
    .enableViewFinder(mode: .logs)
```

## Root-Value Inspector

`StaticViewHierarchyInspector` treats application-defined types as meaningful
component nodes. For those nodes it evaluates `body`. For framework nodes it
reflects stored values until it finds more values conforming to `View`.

Framework wrappers are collapsed by default. This produces a useful conceptual
component hierarchy, but it is not a rendered hierarchy.

## Private Rendered-Graph Probe

`PrivateRenderedHierarchyProbe` is iOS-only and research-only.

It dynamically resolves:

```text
$s7SwiftUI10_ViewDebugO10propertiesAC10PropertiesVvsZ
```

That symbol is the Swift ABI setter for private `_ViewDebug.properties`. Dynamic
resolution is required because the symbol does not exist on every supported OS.

When available, the probe requests `.all`, creates or receives a known generic
`_UIHostingView<Content>`, and serializes `_viewDebugData()`.

## Why Global Inspection Is Not Solved Yet

An app's visible hosting view has an unknown generic `Content` type. Swift-only
methods such as `_viewDebugData()` are not Objective-C selectors, so they cannot
be invoked with ordinary Objective-C runtime messaging. Phase 3 needs a robust
way to invoke the method or reach `ViewGraph` without knowing `Content`.

Potential approaches:

1. Install a root integration before graph creation and retain a typed probe.
2. Call private Swift functions through carefully validated ABI entry points.
3. Discover a non-generic hosting or graph protocol with equivalent debug data.
4. Add a tiny representable at the root to locate its containing host.

## Planned Phase 3

The serialized graph is recursive and noisy. A hierarchy engine should:

1. Decode `children`, `properties`, and attribute dictionaries structurally.
2. Select type attributes from application modules.
3. Collapse framework wrappers.
4. Preserve the nearest position and size metadata.
5. Distinguish conceptual component nodes from render leaves.
6. Measure performance on large graphs.

Only after this tree is reliable should selection and overlay work begin.

## Source Discovery

The current graph payload has no source field. Source discovery should be an
independent debug-symbol subsystem, likely combining recovered type names with
dSYM/DWARF or a build-time source index.
