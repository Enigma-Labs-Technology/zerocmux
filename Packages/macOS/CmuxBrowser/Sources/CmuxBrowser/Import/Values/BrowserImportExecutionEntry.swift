import Foundation

/// One mapping in an import plan: a set of source profiles and the zerocmux
/// destination they should be written to.
public struct BrowserImportExecutionEntry: Equatable, Sendable {
    /// Source profiles to read data from.
    public var sourceProfiles: [InstalledBrowserProfile]
    /// The zerocmux destination profile request for this entry.
    public var destination: BrowserImportDestinationRequest

    /// Creates an import-plan entry.
    ///
    /// - Parameters:
    ///   - sourceProfiles: Source profiles to read data from.
    ///   - destination: The zerocmux destination profile request.
    public init(sourceProfiles: [InstalledBrowserProfile], destination: BrowserImportDestinationRequest) {
        self.sourceProfiles = sourceProfiles
        self.destination = destination
    }
}
