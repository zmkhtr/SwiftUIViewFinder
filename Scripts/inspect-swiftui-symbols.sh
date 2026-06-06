#!/usr/bin/env bash

set -euo pipefail

sdk_path="$(xcrun --show-sdk-path --sdk iphonesimulator)"
swiftui_tbd="$sdk_path/System/Library/Frameworks/SwiftUI.framework/SwiftUI.tbd"
swiftui_interface="$sdk_path/System/Library/Frameworks/SwiftUI.framework/Modules/SwiftUI.swiftmodule/arm64-apple-ios-simulator.swiftinterface"
core_tbd="$sdk_path/System/Library/Frameworks/SwiftUICore.framework/SwiftUICore.tbd"
core_interface="$sdk_path/System/Library/Frameworks/SwiftUICore.framework/Modules/SwiftUICore.swiftmodule/arm64-apple-ios-simulator.swiftinterface"

echo "SDK: $sdk_path"
echo
echo "SwiftUI interface findings"
rg -n "viewDebugData|makeViewDebugData|_UIHostingView" "$swiftui_interface" || true
echo
echo "SwiftUICore interface findings"
rg -n "_ViewDebug|serializedData" "$core_interface" || true
echo
echo "Exported debug symbols"
rg -n "ViewDebug|viewDebugData|makeViewDebugData" "$swiftui_tbd" "$core_tbd" || true
