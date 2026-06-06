# Xcode 26.2 SDK Symbol Findings

Observed on June 6, 2026.

The iPhone Simulator SDK Swift interfaces expose:

```swift
final public func _viewDebugData() -> [SwiftUICore._ViewDebug.Data]
public static func serializedData(_ viewDebugData: [SwiftUICore._ViewDebug.Data]) -> Foundation.Data?
```

The SwiftUICore text-based stub also exports compatibility symbols for:

```text
SwiftUI._ViewDebug.properties
SwiftUI._ViewDebug.Data.data
SwiftUI._ViewDebug.Data.childData
SwiftUI.ViewGraph.viewDebugData()
```

Useful demangled symbols:

```text
SwiftUI._UIHostingView._viewDebugData() -> [SwiftUI._ViewDebug.Data]
SwiftUI._UIHostingView.makeViewDebugData() -> Foundation.Data?
SwiftUI.ViewGraph.viewDebugData() -> [SwiftUI._ViewDebug.Data]
static SwiftUI._ViewDebug.makeDebugData(subgraph:) -> [SwiftUI._ViewDebug.Data]
```

The private properties setter:

```text
$s7SwiftUI10_ViewDebugO10propertiesAC10PropertiesVvsZ
```

is available on the tested iOS 26.2 runtime and absent on the tested iOS 15.5
runtime.
