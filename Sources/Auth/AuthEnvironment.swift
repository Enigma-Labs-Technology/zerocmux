import Foundation

enum AuthEnvironmentUnavailable {
    static let message = "Hosted auth is unavailable in zerocmux because the web backend has been removed."
}

/// zerocmux: the hosted-auth environment was removed with the web backend.
/// Only the deep-link callback scheme survives — it names the app's custom
/// URL scheme (`zerocmux://…`, `zerocmux-dev://…` for DEBUG builds), which
/// workspace/pane/surface links are built from. Mirrors the
/// `CMUX_AUTH_CALLBACK_SCHEME` build setting injected into Info.plist.
enum AuthEnvironment {
    static var callbackScheme: String {
        #if DEBUG
        return "zerocmux-dev"
        #else
        return "zerocmux"
        #endif
    }
}
