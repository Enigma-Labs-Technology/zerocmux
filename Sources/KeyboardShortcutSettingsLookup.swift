import Foundation

extension KeyboardShortcutSettings {
    static func shortcutIfBound(for action: Action) -> StoredShortcut? {
        #if DEBUG
        shortcutLookupObserver?(action)
        if let override = shortcutOverridesForTesting[action] {
            return override.isUnbound ? nil : override
        }
        #endif

        if let data = UserDefaults.standard.data(forKey: action.defaultsKey),
           let shortcut = try? JSONDecoder().decode(StoredShortcut.self, from: data) {
            return shortcut.isUnbound ? nil : shortcut
        }

        if let managedShortcut = settingsFileStore.override(for: action) {
            return managedShortcut.isUnbound ? nil : managedShortcut
        }

        let defaultShortcut = action.defaultShortcut
        return defaultShortcut.isUnbound ? nil : defaultShortcut
    }

    static func shortcut(for action: Action) -> StoredShortcut {
        shortcutIfBound(for: action) ?? .unbound
    }

    static func menuShortcut(for action: Action) -> StoredShortcut {
        guard !KeyboardShortcutRecorderActivity.isAnyRecorderActive else {
            return .unbound
        }
        return shortcut(for: action)
    }

    static func isManagedBySettingsFile(_ action: Action) -> Bool {
        settingsFileStore.isManagedByFile(action)
    }

    static func unbindShortcut(for action: Action) {
        setShortcut(.unbound, for: action)
    }

    #if DEBUG
    private static var shortcutOverridesForTesting: [Action: StoredShortcut] = [:]

    static func shortcutOverrideForTesting(for action: Action) -> StoredShortcut? {
        shortcutOverridesForTesting[action]
    }

    static func setShortcutOverrideForTesting(_ shortcut: StoredShortcut?, for action: Action) {
        if let shortcut {
            shortcutOverridesForTesting[action] = shortcut
        } else {
            shortcutOverridesForTesting.removeValue(forKey: action)
        }
    }

    static func removeAllShortcutOverridesForTesting() {
        shortcutOverridesForTesting.removeAll()
    }
    #endif

    static func settingsFileManagedSubtitle(for action: Action) -> String? {
        guard isManagedBySettingsFile(action) else { return nil }
        return String(localized: "settings.shortcuts.managedByFile", defaultValue: "Managed in zerocmux.json")
    }

}
