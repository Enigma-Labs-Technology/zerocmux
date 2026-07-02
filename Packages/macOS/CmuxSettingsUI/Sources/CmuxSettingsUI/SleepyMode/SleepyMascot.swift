import Foundation

/// Which mascot/face the Sleepy Mode scene draws.
public enum SleepyMascot: String, CaseIterable, Identifiable, Sendable {
    /// The zerocmux mascot.
    case cmux
    /// A sleepy cat.
    case cat
    /// A friendly ghost.
    case ghost
    /// A face built from the zerocmux `>` chevron logo.
    case logoFace

    /// Stable identity for `Identifiable` (the raw string value).
    public var id: String { rawValue }
}
