public import Foundation

/// A request for the zerocmux destination profile an import entry should write to.
public enum BrowserImportDestinationRequest: Equatable, Sendable {
    /// Import into the existing zerocmux profile with this identifier.
    case existing(UUID)
    /// Create a new zerocmux profile with this display name, then import into it.
    case createNamed(String)
}
