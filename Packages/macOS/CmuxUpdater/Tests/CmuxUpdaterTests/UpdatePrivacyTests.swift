import Foundation
import Sparkle
import Testing
@testable import CmuxUpdater

@Suite struct UpdatePrivacyTests {
    @Test(arguments: [false, true])
    func applyingSettingsDisablesPreviouslyEnabledProfile(migrationAlreadyRan: Bool) throws {
        let suiteName = "zerocmux.update-privacy.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(migrationAlreadyRan, forKey: UpdateSettings.migrationKey)
        defaults.set(true, forKey: UpdateSettings.sendProfileInfoKey)

        UpdateSettings().apply(to: defaults)

        #expect(!defaults.bool(forKey: UpdateSettings.sendProfileInfoKey))
    }

    @Test func applyingSettingsReassertsPrivacyWithoutChangingUpdatePreferences() throws {
        let suiteName = "zerocmux.update-privacy.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = UpdateSettings()
        settings.apply(to: defaults)
        defaults.set(false, forKey: UpdateSettings.automaticChecksKey)
        defaults.set(true, forKey: UpdateSettings.sendProfileInfoKey)

        settings.apply(to: defaults)

        #expect(!defaults.bool(forKey: UpdateSettings.sendProfileInfoKey))
        #expect(!defaults.bool(forKey: UpdateSettings.automaticChecksKey))
    }

    @MainActor
    @Test func resolvingSparkleFeedDisablesProfileBeforeRequestParametersAreBuilt() throws {
        let bundleID = "zerocmux.update-privacy.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: bundleID))
        defer { defaults.removePersistentDomain(forName: bundleID) }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(bundleID)
        let contents = root.appendingPathComponent("PrivacyFixture.app/Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let plist = try PropertyListSerialization.data(fromPropertyList: [
            "CFBundleIdentifier": bundleID,
            "CFBundleName": "PrivacyFixture",
            "CFBundleVersion": "1",
            "CFBundlePackageType": "APPL",
        ], format: .xml, options: 0)
        try plist.write(to: contents.appendingPathComponent("Info.plist"))
        let bundle = try #require(Bundle(url: contents.deletingLastPathComponent()))
        let driver = UpdateDriver(
            model: UpdateStateModel(),
            log: NoopUpdateLog(),
            clock: SystemUpdateClock(),
            infoFeedURLProvider: { nil }
        )
        let updater = SPUUpdater(
            hostBundle: bundle,
            applicationBundle: bundle,
            userDriver: driver,
            delegate: driver
        )

        // Never start Sparkle or perform network I/O. Its public feed getter invokes the
        // same delegate used before Sparkle constructs the outgoing profile parameters.
        for _ in 0..<2 {
            updater.sendsSystemProfile = true
            #expect(updater.sendsSystemProfile)
            #expect(updater.feedURL != nil)
            #expect(!updater.sendsSystemProfile)
        }
    }
}
