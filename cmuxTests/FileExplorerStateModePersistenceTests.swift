import Foundation
import XCTest

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

final class FileExplorerStateModePersistenceTests: XCTestCase {
    private let modeKey = "rightSidebar.mode"
    private let dockEnabledKey = RightSidebarBetaFeatureSettings.dockEnabledKey

    func testFeedStoredModeSurvivesByDefault() {
        withTemporaryDefaults { defaults in
            defaults.set(RightSidebarMode.feed.rawValue, forKey: modeKey)

            let state = FileExplorerState(defaults: defaults)

            XCTAssertEqual(state.mode, .feed)
            XCTAssertEqual(defaults.string(forKey: modeKey), RightSidebarMode.feed.rawValue)
        }
    }

    func testModeSetterClampsUnavailableBetaModes() {
        withTemporaryDefaults { defaults in
            defaults.set(false, forKey: dockEnabledKey)
            let state = FileExplorerState(defaults: defaults)

            state.mode = .feed
            XCTAssertEqual(state.mode, .feed)
            XCTAssertEqual(defaults.string(forKey: modeKey), RightSidebarMode.feed.rawValue)

            defaults.set(true, forKey: dockEnabledKey)
            state.mode = .dock
            XCTAssertEqual(state.mode, .dock)
            XCTAssertEqual(defaults.string(forKey: modeKey), RightSidebarMode.dock.rawValue)

            defaults.set(false, forKey: dockEnabledKey)
            state.refreshModeAvailability()
            XCTAssertEqual(state.mode, .files)
            XCTAssertEqual(defaults.string(forKey: modeKey), RightSidebarMode.files.rawValue)
        }
    }

    func testCLIArgumentNormalizerMapsVaultAndSessionsToSessions() {
        XCTAssertEqual(RightSidebarMode.from(cliArgument: "files"), .files)
        XCTAssertEqual(RightSidebarMode.from(cliArgument: "find"), .find)
        XCTAssertEqual(RightSidebarMode.from(cliArgument: "vault"), .sessions)
        XCTAssertEqual(RightSidebarMode.from(cliArgument: "sessions"), .sessions)
        XCTAssertEqual(RightSidebarMode.from(cliArgument: "feed"), .feed)
        XCTAssertEqual(RightSidebarMode.from(cliArgument: "dock"), .dock)
        XCTAssertEqual(RightSidebarMode.from(cliArgument: " Vault "), .sessions)
        XCTAssertNil(RightSidebarMode.from(cliArgument: "unknown"))
    }

    private func withTemporaryDefaults(_ body: (UserDefaults) -> Void) {
        let suiteName = "FileExplorerStateModePersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        body(defaults)
    }
}
