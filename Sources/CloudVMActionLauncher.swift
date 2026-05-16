import AppKit
import Foundation

@MainActor
final class CloudVMActionLauncher {
    static let shared = CloudVMActionLauncher()

    private init() {}

    func terminateAll() {
    }

    @discardableResult
    func start(socketPath: String, preferredWindow: NSWindow?) -> Bool {
        _ = socketPath
        presentStartFailure(
            summary: String(
                localized: "command.cloudVM.failed.removed",
                defaultValue: "Hosted Cloud VMs are not available in zerocmux because the web backend has been removed. Use zerocmux ssh for remote workspaces."
            ),
            output: "",
            preferredWindow: preferredWindow
        )
        return false
    }

    private func presentStartFailure(summary: String, output: String, preferredWindow: NSWindow?) {
        let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
        let limitedOutput = String(trimmedOutput.prefix(2000))
        let informativeText = limitedOutput.isEmpty
            ? summary
            : "\(summary)\n\n\(limitedOutput)"

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(localized: "command.cloudVM.failed.title", defaultValue: "Couldn't Start Cloud VM")
        alert.informativeText = informativeText
        alert.addButton(withTitle: String(localized: "common.ok", defaultValue: "OK"))

        if let preferredWindow {
            alert.beginSheetModal(for: preferredWindow, completionHandler: nil)
        } else if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            alert.beginSheetModal(for: window, completionHandler: nil)
        } else {
            _ = alert.runModal()
        }
    }
}
