import XCTest
import AppKit

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

final class KeyboardShortcutSettingsFileStoreStartupTests: XCTestCase {
    private var originalSettingsFileStore: KeyboardShortcutSettingsFileStore!
    private let settingsFileBackupsDefaultsKey = "cmux.settingsFile.backups.v1"
    private let importedManagedDefaultsKey = "cmux.settingsFile.importedManagedDefaults.v1"

    override func setUp() {
        super.setUp()
        originalSettingsFileStore = KeyboardShortcutSettings.settingsFileStore
        KeyboardShortcutSettings.resetAll()
    }

    override func tearDown() {
        KeyboardShortcutSettings.settingsFileStore = originalSettingsFileStore
        AppIconSettings.resetLiveEnvironmentProviderForTesting()
        KeyboardShortcutSettings.resetAll()
        super.tearDown()
    }

    func testSettingsFileStoreParsesNumberedShortcutWithoutConsultingActiveShortcutStore() throws {
        let directoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let activeSettingsFileURL = directoryURL.appendingPathComponent("active.json", isDirectory: false)
        try writeSettingsFile(
            """
            {
              "shortcuts": {
                "openBrowser": "cmd+3"
              }
            }
            """,
            to: activeSettingsFileURL
        )

        KeyboardShortcutSettings.settingsFileStore = KeyboardShortcutSettingsFileStore(
            primaryPath: activeSettingsFileURL.path,
            fallbackPath: nil,
            startWatching: false
        )
        XCTAssertEqual(
            KeyboardShortcutSettings.shortcut(for: .openBrowser),
            StoredShortcut(key: "3", command: true, shift: false, option: false, control: false)
        )

        let parsedSettingsFileURL = directoryURL.appendingPathComponent("parsed.json", isDirectory: false)
        try writeSettingsFile(
            """
            {
              "shortcuts": {
                "selectWorkspaceByNumber": "cmd+7"
              }
            }
            """,
            to: parsedSettingsFileURL
        )

        let store = KeyboardShortcutSettingsFileStore(
            primaryPath: parsedSettingsFileURL.path,
            fallbackPath: nil,
            startWatching: false
        )

        XCTAssertEqual(
            store.override(for: .selectWorkspaceByNumber),
            StoredShortcut(key: "1", command: true, shift: false, option: false, control: false)
        )
    }

    func testSettingsFileShortcutNormalizationAcceptsRecorderConflictingShortcut() {
        KeyboardShortcutSettings.resetAll()
        defer { KeyboardShortcutSettings.resetAll() }

        let shortcut = StoredShortcut(key: "t", command: true, shift: false, option: false, control: false)

        XCTAssertEqual(
            KeyboardShortcutSettings.Action.openBrowser.normalizedSettingsFileShortcut(shortcut),
            shortcut
        )
    }

    func testSettingsFileStoreRestoresAbsentAppIconBackupDuringStartupWithoutTouchingAppKit() throws {
        let isolatedDefaults = try makeIsolatedDefaults()
        let defaults = isolatedDefaults.defaults
        defer { defaults.removePersistentDomain(forName: isolatedDefaults.suiteName) }

        let directoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let managedIconURL = directoryURL.appendingPathComponent("icon.json", isDirectory: false)
        try writeSettingsFile(
            """
            {
              "app": {
                "appIcon": "automatic"
              }
            }
            """,
            to: managedIconURL
        )

        var startObservationCallCount = 0
        var stopObservationCallCount = 0
        var imageRequestCount = 0
        var runtimeIconSetCount = 0
        var dockTileNotificationCount = 0
        AppIconSettings.setLiveEnvironmentProviderForTesting {
            AppIconSettings.Environment(
                isApplicationFinishedLaunching: { false },
                imageForMode: { _ in
                    imageRequestCount += 1
                    return nil
                },
                setApplicationIconImage: { _ in
                    runtimeIconSetCount += 1
                },
                startAppearanceObservation: {
                    startObservationCallCount += 1
                },
                stopAppearanceObservation: {
                    stopObservationCallCount += 1
                },
                notifyDockTilePlugin: {
                    dockTileNotificationCount += 1
                }
            )
        }

        _ = KeyboardShortcutSettingsFileStore(
            primaryPath: managedIconURL.path,
            fallbackPath: nil,
            userDefaults: defaults,
            startWatching: false
        )

        XCTAssertEqual(defaults.string(forKey: AppIconSettings.modeKey), AppIconMode.automatic.rawValue)

        let managedAppearanceURL = directoryURL.appendingPathComponent("appearance.json", isDirectory: false)
        try writeSettingsFile(
            """
            {
              "app": {
                "appearance": "system"
              }
            }
            """,
            to: managedAppearanceURL
        )

        _ = KeyboardShortcutSettingsFileStore(
            primaryPath: managedAppearanceURL.path,
            fallbackPath: nil,
            userDefaults: defaults,
            startWatching: false
        )

        XCTAssertNil(defaults.object(forKey: AppIconSettings.modeKey))
        XCTAssertEqual(defaults.string(forKey: AppearanceSettings.appearanceModeKey), AppearanceMode.system.rawValue)
        XCTAssertEqual(startObservationCallCount, 0)
        XCTAssertEqual(stopObservationCallCount, 0)
        XCTAssertEqual(imageRequestCount, 0)
        XCTAssertEqual(runtimeIconSetCount, 0)
        XCTAssertEqual(dockTileNotificationCount, 0)
    }

    func testSidebarMatchTerminalBackgroundUserDefaultSurvivesSettingsFileReapply() throws {
        let isolatedDefaults = try makeIsolatedDefaults()
        let defaults = isolatedDefaults.defaults
        let key = SidebarMatchTerminalBackgroundSettings.userDefaultsKey
        defer { defaults.removePersistentDomain(forName: isolatedDefaults.suiteName) }

        let directoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let settingsFileURL = directoryURL.appendingPathComponent("cmux.json", isDirectory: false)
        try writeSettingsFile(
            """
            {
              "sidebarAppearance": {
                "matchTerminalBackground": true
              }
            }
            """,
            to: settingsFileURL
        )

        let notificationCenter = NotificationCenter()
        let store = KeyboardShortcutSettingsFileStore(
            primaryPath: settingsFileURL.path,
            fallbackPath: nil,
            notificationCenter: notificationCenter,
            userDefaults: defaults,
            startWatching: true
        )

        XCTAssertEqual(defaults.object(forKey: key) as? Bool, true)

        defaults.set(false, forKey: key)
        try withExtendedLifetime(store) {
            notificationCenter.post(name: UserDefaults.didChangeNotification, object: defaults)
            XCTAssertEqual(defaults.object(forKey: key) as? Bool, false)

            _ = KeyboardShortcutSettingsFileStore(
                primaryPath: settingsFileURL.path,
                fallbackPath: nil,
                additionalFallbackPaths: [],
                userDefaults: defaults,
                startWatching: false
            )
            XCTAssertEqual(defaults.object(forKey: key) as? Bool, false)

            try writeSettingsFile(
                """
                {
                  "sidebarAppearance": {
                    "matchTerminalBackground": false
                  }
                }
                """,
                to: settingsFileURL
            )
            store.reload()
            XCTAssertEqual(defaults.object(forKey: key) as? Bool, false)

            defaults.set(true, forKey: key)
            notificationCenter.post(name: UserDefaults.didChangeNotification, object: defaults)
            XCTAssertEqual(defaults.object(forKey: key) as? Bool, true)
        }
    }

    func testManagedAppearanceUserDefaultSurvivesSettingsFileReapplyUntilFileChanges() throws {
        let isolatedDefaults = try makeIsolatedDefaults()
        let defaults = isolatedDefaults.defaults
        let key = AppearanceSettings.appearanceModeKey
        defer { defaults.removePersistentDomain(forName: isolatedDefaults.suiteName) }

        let directoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let settingsFileURL = directoryURL.appendingPathComponent("cmux.json", isDirectory: false)
        try writeSettingsFile(
            """
            {
              "app": {
                "appearance": "system"
              }
            }
            """,
            to: settingsFileURL
        )

        let notificationCenter = NotificationCenter()
        let store = KeyboardShortcutSettingsFileStore(
            primaryPath: settingsFileURL.path,
            fallbackPath: nil,
            additionalFallbackPaths: [],
            notificationCenter: notificationCenter,
            userDefaults: defaults,
            startWatching: true
        )

        XCTAssertEqual(defaults.string(forKey: key), AppearanceMode.system.rawValue)

        defaults.set(AppearanceMode.light.rawValue, forKey: key)
        try withExtendedLifetime(store) {
            notificationCenter.post(name: UserDefaults.didChangeNotification, object: defaults)
            XCTAssertEqual(defaults.string(forKey: key), AppearanceMode.light.rawValue)

            let relaunchedStore = KeyboardShortcutSettingsFileStore(
                primaryPath: settingsFileURL.path,
                fallbackPath: nil,
                additionalFallbackPaths: [],
                userDefaults: defaults,
                startWatching: false
            )
            XCTAssertEqual(defaults.string(forKey: key), AppearanceMode.light.rawValue)

            try writeSettingsFile(
                """
                {
                  "app": {
                    "appearance": "dark"
                  }
                }
                """,
                to: settingsFileURL
            )
            relaunchedStore.reload()
            XCTAssertEqual(defaults.string(forKey: key), AppearanceMode.dark.rawValue)
        }
    }

    func testManagedBoolUserDefaultSurvivesSettingsFileReapplyUntilFileChanges() throws {
        let isolatedDefaults = try makeIsolatedDefaults()
        let defaults = isolatedDefaults.defaults
        let key = QuitWarningSettings.warnBeforeQuitKey
        defer { defaults.removePersistentDomain(forName: isolatedDefaults.suiteName) }

        let directoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let settingsFileURL = directoryURL.appendingPathComponent("cmux.json", isDirectory: false)
        try writeSettingsFile(
            """
            {
              "app": {
                "warnBeforeQuit": true
              }
            }
            """,
            to: settingsFileURL
        )

        let notificationCenter = NotificationCenter()
        let store = KeyboardShortcutSettingsFileStore(
            primaryPath: settingsFileURL.path,
            fallbackPath: nil,
            additionalFallbackPaths: [],
            notificationCenter: notificationCenter,
            userDefaults: defaults,
            startWatching: true
        )

        XCTAssertEqual(defaults.object(forKey: key) as? Bool, true)

        defaults.set(false, forKey: key)
        try withExtendedLifetime(store) {
            notificationCenter.post(name: UserDefaults.didChangeNotification, object: defaults)
            XCTAssertEqual(defaults.object(forKey: key) as? Bool, false)

            try writeSettingsFile(
                """
                {
                  "app": {
                    "warnBeforeQuit": false
                  }
                }
                """,
                to: settingsFileURL
            )
            defaults.set(true, forKey: key)
            XCTAssertEqual(defaults.object(forKey: key) as? Bool, true)

            store.reload()
            XCTAssertEqual(defaults.object(forKey: key) as? Bool, false)

            defaults.set(true, forKey: key)
            notificationCenter.post(name: UserDefaults.didChangeNotification, object: defaults)
            XCTAssertEqual(defaults.object(forKey: key) as? Bool, true)
        }
    }

    func testSettingsFileStoreAppliesTerminalAgentAutoResumeSetting() throws {
        let isolatedDefaults = try makeIsolatedDefaults()
        let defaults = isolatedDefaults.defaults
        let key = AgentSessionAutoResumeSettings.autoResumeAgentSessionsKey
        defer { defaults.removePersistentDomain(forName: isolatedDefaults.suiteName) }

        let directoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let settingsFileURL = directoryURL.appendingPathComponent("cmux.json", isDirectory: false)
        try writeSettingsFile(
            """
            {
              "terminal": {
                "autoResumeAgentSessions": false
              }
            }
            """,
            to: settingsFileURL
        )

        _ = KeyboardShortcutSettingsFileStore(
            primaryPath: settingsFileURL.path,
            fallbackPath: nil,
            userDefaults: defaults,
            startWatching: false
        )

        XCTAssertEqual(defaults.object(forKey: key) as? Bool, false)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "cmux-settings-startup-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writeSettingsFile(_ contents: String, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }

    private func makeIsolatedDefaults() throws -> (defaults: UserDefaults, suiteName: String) {
        let suiteName = "zerocmux-settings-startup-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw NSError(domain: NSCocoaErrorDomain, code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create isolated UserDefaults suite"
            ])
        }
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }

}
