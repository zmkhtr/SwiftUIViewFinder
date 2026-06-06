/// Controls which ViewFinder output mechanisms are active.
///
/// Overlay modes are reserved for a later milestone. During the Phase 2
/// prototype, modes containing logs emit console hierarchy reports.
public enum InspectionMode: String, CaseIterable, Codable, Sendable {
    case overlay
    case logs
    case overlayAndLogs
    case off

    var includesLogs: Bool {
        self == .logs || self == .overlayAndLogs
    }
}

/// Controls the amount of information shown by a future component overlay.
public enum OverlayStyle: String, CaseIterable, Codable, Sendable {
    case compact
    case detailed
}
