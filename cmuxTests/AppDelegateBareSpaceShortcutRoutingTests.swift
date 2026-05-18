import AppKit
import XCTest

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

@MainActor
final class AppDelegateBareSpaceShortcutRoutingTests: XCTestCase {
    private var originalSettingsFileStore: KeyboardShortcutSettingsFileStore!

    override func setUp() {
        super.setUp()
        executionTimeAllowance = 30
        originalSettingsFileStore = KeyboardShortcutSettings.installIsolatedTestFileStore(prefix: "zerocmux-bare-space-shortcuts")
        #if DEBUG
        KeyboardShortcutSettings.removeAllShortcutOverridesForTesting()
        #endif
    }

    override func tearDown() {
        #if DEBUG
        KeyboardShortcutSettings.removeAllShortcutOverridesForTesting()
        #endif
        KeyboardShortcutSettings.settingsFileStore = originalSettingsFileStore
        super.tearDown()
    }

    func testBareSpaceShortcutDispatchesConfiguredAction() {
        let context = makeShortcutRoutingContext()
        defer { context.cleanup() }

        let initialCount = context.manager.tabs.count
        let shortcut = StoredShortcut(key: "space", command: false, shift: false, option: false, control: false)

        withTemporaryShortcut(action: .newTab, shortcut: shortcut) {
            guard let event = makeKeyDownEvent(key: " ", keyCode: 49, windowNumber: context.eventWindowNumber) else {
                XCTFail("Failed to construct Space event")
                return
            }

#if DEBUG
            XCTAssertTrue(context.appDelegate.debugHandleCustomShortcut(event: event))
#else
            XCTFail("debugHandleCustomShortcut is only available in DEBUG")
#endif
        }

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertEqual(context.manager.tabs.count, initialCount + 1, "Bare Space should dispatch when explicitly configured")
    }

    func testBareSpaceChordPrefixArmsConfiguredShortcut() {
        let context = makeShortcutRoutingContext()
        defer { context.cleanup() }

        let initialCount = context.manager.tabs.count
        let shortcut = StoredShortcut(
            key: "space",
            command: false,
            shift: false,
            option: false,
            control: false,
            chordKey: "n"
        )

        withTemporaryShortcut(action: .newTab, shortcut: shortcut) {
            guard let prefixEvent = makeKeyDownEvent(key: " ", keyCode: 49, windowNumber: context.eventWindowNumber),
                  let actionEvent = makeKeyDownEvent(key: "n", keyCode: 45, windowNumber: context.eventWindowNumber) else {
                XCTFail("Failed to construct Space chord events")
                return
            }

#if DEBUG
            XCTAssertTrue(context.appDelegate.debugHandleCustomShortcut(event: prefixEvent))
            XCTAssertEqual(context.manager.tabs.count, initialCount, "Bare Space prefix must not fire the action early")
            XCTAssertTrue(context.appDelegate.debugHandleCustomShortcut(event: actionEvent))
#else
            XCTFail("debugHandleCustomShortcut is only available in DEBUG")
#endif
        }

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertEqual(context.manager.tabs.count, initialCount + 1, "Bare Space chord should dispatch on the second stroke")
    }

    func testCreateMainWindowUsesPersistedGeometryWhenNoSourceWindow() throws {
        let previousShared = AppDelegate.shared
        let appDelegate = AppDelegate()
        defer { AppDelegate.shared = previousShared }

        let isolatedDefaults = makeIsolatedDefaults()
        let defaults = isolatedDefaults.defaults
        appDelegate.debugPersistedWindowGeometryDefaultsForTesting = defaults
        defer { defaults.removePersistentDomain(forName: isolatedDefaults.suiteName) }
        let persistedGeometryKey = AppDelegate.debugPersistedWindowGeometryDefaultsKey
        var windowId: UUID?
        defer {
            if let windowId {
                closeWindow(withId: windowId)
            }
        }

        let screen = try XCTUnwrap(NSScreen.main ?? NSScreen.screens.first)
        let visibleFrame = screen.visibleFrame
        let savedWidth = max(
            CGFloat(SessionPersistencePolicy.minimumWindowWidth),
            min(1_100, visibleFrame.width - 40)
        )
        let savedHeight = max(
            CGFloat(SessionPersistencePolicy.minimumWindowHeight),
            min(760, visibleFrame.height - 40)
        )
        let savedFrame = CGRect(
            x: visibleFrame.midX - savedWidth / 2,
            y: visibleFrame.midY - savedHeight / 2,
            width: savedWidth,
            height: savedHeight
        )
        let payload = AppDelegate.PersistedWindowGeometry(
            version: AppDelegate.persistedWindowGeometrySchemaVersion,
            frame: SessionRectSnapshot(savedFrame),
            display: SessionDisplaySnapshot(
                displayID: screen.cmuxDisplayID,
                frame: SessionRectSnapshot(screen.frame),
                visibleFrame: SessionRectSnapshot(screen.visibleFrame)
            )
        )
        defaults.set(try JSONEncoder().encode(payload), forKey: persistedGeometryKey)

        let createdWindowId = appDelegate.createMainWindow(shouldActivate: false, sourceWindow: nil)
        windowId = createdWindowId

        let window = try XCTUnwrap(window(withId: createdWindowId))
        XCTAssertEqual(window.frame.minX, savedFrame.minX, accuracy: 1)
        XCTAssertEqual(window.frame.minY, savedFrame.minY, accuracy: 1)
        XCTAssertEqual(window.frame.width, savedFrame.width, accuracy: 1)
        XCTAssertEqual(window.frame.height, savedFrame.height, accuracy: 1)
    }

    private func makeKeyDownEvent(
        key: String,
        keyCode: UInt16,
        windowNumber: Int
    ) -> NSEvent? {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: windowNumber,
            context: nil,
            characters: key,
            charactersIgnoringModifiers: key,
            isARepeat: false,
            keyCode: keyCode
        )
    }

    private func withTemporaryShortcut(
        action: KeyboardShortcutSettings.Action,
        shortcut: StoredShortcut,
        _ body: () -> Void
    ) {
        #if DEBUG
        let originalOverride = KeyboardShortcutSettings.shortcutOverrideForTesting(for: action)
        defer {
            KeyboardShortcutSettings.setShortcutOverrideForTesting(originalOverride, for: action)
        }
        KeyboardShortcutSettings.setShortcutOverrideForTesting(shortcut, for: action)
        body()
        #else
        let hadPersistedShortcut = UserDefaults.standard.object(forKey: action.defaultsKey) != nil
        let originalShortcut = KeyboardShortcutSettings.shortcut(for: action)
        defer {
            if hadPersistedShortcut {
                KeyboardShortcutSettings.setShortcut(originalShortcut, for: action)
            } else {
                KeyboardShortcutSettings.resetShortcut(for: action)
            }
        }
        KeyboardShortcutSettings.setShortcut(shortcut, for: action)
        body()
        #endif
    }

    private struct ShortcutRoutingContext {
        let appDelegate: AppDelegate
        let manager: TabManager
        let window: NSWindow
        let windowId: UUID
        let eventWindowNumber: Int
        let previousShared: AppDelegate?
        let previousActiveManager: TabManager?

        @MainActor
        func cleanup() {
            appDelegate.unregisterMainWindowContextForTesting(windowId: windowId, notifyChange: false)
            window.makeFirstResponder(nil)
            window.contentView = nil
            window.orderOut(nil)
            window.close()
            for workspace in manager.tabs {
                manager.closeWorkspace(workspace)
            }
            AppDelegate.shared = previousShared
            if let previousActiveManager {
                TerminalController.shared.setActiveTabManager(previousActiveManager)
            }
        }
    }

    private func makeShortcutRoutingContext() -> ShortcutRoutingContext {
        let previousShared = AppDelegate.shared
        let previousActiveManager = previousShared?.tabManager
        let appDelegate = AppDelegate()
        let manager = TabManager()
        let windowId = UUID()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 240),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.identifier = NSUserInterfaceItemIdentifier("cmux.main.\(windowId.uuidString)")
        AppDelegate.shared = appDelegate
        appDelegate.registerMainWindowContextForTesting(
            windowId: windowId,
            tabManager: manager,
            window: window,
            notifyChange: false
        )
        return ShortcutRoutingContext(
            appDelegate: appDelegate,
            manager: manager,
            window: window,
            windowId: windowId,
            eventWindowNumber: 0,
            previousShared: previousShared,
            previousActiveManager: previousActiveManager
        )
    }

    private func window(withId windowId: UUID) -> NSWindow? {
        let identifier = "cmux.main.\(windowId.uuidString)"
        return NSApp.windows.first(where: { $0.identifier?.rawValue == identifier })
    }

    private func closeWindow(withId windowId: UUID) {
        guard let window = window(withId: windowId) else { return }
        window.performClose(nil)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
    }

    private func makeIsolatedDefaults() -> (defaults: UserDefaults, suiteName: String) {
        let suiteName = "zerocmux-bare-space-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Failed to create isolated UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }
}
