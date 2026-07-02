import Foundation

enum AppBundleIconPersistencePolicy {
    private static let stableReleaseBundleIdentifier = "com.kernelalex.zerocmux"
    private static let stableReleaseAppBundleName = "zerocmux.app"
    static let disablePersistenceArgument = "--zerocmux-disable-bundle-icon-persistence"
    static let disablePersistenceDefaultsKey = "cmuxDisableBundleIconPersistence"

    static func updateDisableDefault(defaults: UserDefaults, launchArguments: [String]) {
        defaults.set(
            launchArguments.contains(disablePersistenceArgument),
            forKey: disablePersistenceDefaultsKey
        )
    }

    static func shouldPersist(
        bundleIdentifier: String?,
        appBundleLastPathComponent: String?,
        persistenceDisabled: Bool = false
    ) -> Bool {
        guard !persistenceDisabled else {
            return false
        }

        // Channel variants own their identity through build-time bundle metadata.
        // Persisted Finder icons would override that metadata and can leak into
        // packaged artifacts after CI smoke launches the app bundle.
        return bundleIdentifier == stableReleaseBundleIdentifier
            && appBundleLastPathComponent == stableReleaseAppBundleName
    }
}
