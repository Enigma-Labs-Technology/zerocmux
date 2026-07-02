import Foundation
import Testing
@testable import CmuxBrowser

@Suite struct BrowserHistoryLocationTests {
    @Test func foldsDebugAndStagingNamespaces() {
        #expect(BrowserHistoryLocation.normalizedNamespace(bundleIdentifier: "com.kernelalex.zerocmux.debug.my-tag") == "com.kernelalex.zerocmux.debug")
        #expect(BrowserHistoryLocation.normalizedNamespace(bundleIdentifier: "com.kernelalex.zerocmux.staging.rc") == "com.kernelalex.zerocmux.staging")
        #expect(BrowserHistoryLocation.normalizedNamespace(bundleIdentifier: "com.kernelalex.zerocmux") == "com.kernelalex.zerocmux")
    }

    @Test func historyFileURLNestsUnderNamespace() {
        let root = URL(fileURLWithPath: "/tmp/appsupport", isDirectory: true)
        let location = BrowserHistoryLocation(applicationSupportDirectory: root, bundleIdentifier: "com.kernelalex.zerocmux.debug.tag")
        #expect(location.namespace == "com.kernelalex.zerocmux.debug")
        #expect(location.historyFileURL.path == "/tmp/appsupport/com.kernelalex.zerocmux.debug/browser_history.json")
    }

    @Test func legacyURLPresentOnlyWhenNamespaceDiffers() {
        let root = URL(fileURLWithPath: "/tmp/appsupport", isDirectory: true)
        let tagged = BrowserHistoryLocation(applicationSupportDirectory: root, bundleIdentifier: "com.kernelalex.zerocmux.debug.tag")
        #expect(tagged.legacyTaggedHistoryFileURL?.path == "/tmp/appsupport/com.kernelalex.zerocmux.debug.tag/browser_history.json")

        let prod = BrowserHistoryLocation(applicationSupportDirectory: root, bundleIdentifier: "com.kernelalex.zerocmux")
        #expect(prod.legacyTaggedHistoryFileURL == nil)
    }
}
