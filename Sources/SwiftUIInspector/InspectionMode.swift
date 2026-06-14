/// Controls which SwiftUIInspector output mechanisms are active.
public enum InspectionMode: String, CaseIterable, Codable, Sendable {
    case overlay
    case logs
    case overlayAndLogs
    case off

    var includesLogs: Bool {
        self == .logs || self == .overlayAndLogs
    }

    var includesOverlay: Bool {
        self == .overlay || self == .overlayAndLogs
    }
}

/// Controls the amount of information shown by component overlays.
public enum OverlayStyle: String, CaseIterable, Codable, Sendable {
    case compact
    case detailed
}
