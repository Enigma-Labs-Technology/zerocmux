import Testing
@testable import CmuxSettings

@Test func markerFilesAreVariantAware() {
    #expect(SocketPathMarkerFiles.variant(
        bundleIdentifier: "com.kernelalex.zerocmux",
        environment: [:]
    ) == .stable)
    #expect(SocketPathMarkerFiles.variant(
        bundleIdentifier: "com.kernelalex.zerocmux.nightly",
        environment: [:]
    ) == .nightly(slug: nil))
    #expect(SocketPathMarkerFiles.variant(
        bundleIdentifier: "com.kernelalex.zerocmux.debug.agent",
        environment: [:]
    ) == .dev(slug: "agent"))
    #expect(SocketPathMarkerFiles.variant(
        bundleIdentifier: "com.kernelalex.zerocmux.debug",
        environment: ["CMUX_TAG": "Issue 3542"]
    ) == .dev(slug: "issue-3542"))
    #expect(SocketPathMarkerFiles.variant(
        bundleIdentifier: "com.kernelalex.zerocmux.debug",
        environment: ["CMUX_TAG": "café"]
    ) == .dev(slug: "caf"))
}

@Test func defaultSocketPathsStayVariantScoped() {
    #expect(SocketPathMarkerFiles.defaultSocketPath(
        bundleIdentifier: "com.kernelalex.zerocmux",
        environment: [:],
        isDebugBuild: false,
        stableSocketPath: "/stable/zerocmux.sock"
    ) == "/stable/zerocmux.sock")
    #expect(SocketPathMarkerFiles.defaultSocketPath(
        bundleIdentifier: "com.kernelalex.zerocmux.nightly",
        environment: [:],
        isDebugBuild: false,
        stableSocketPath: "/stable/zerocmux.sock"
    ) == "/tmp/zerocmux-nightly.sock")
    #expect(SocketPathMarkerFiles.defaultSocketPath(
        bundleIdentifier: "com.kernelalex.zerocmux.staging.my-feature",
        environment: [:],
        isDebugBuild: false,
        stableSocketPath: "/stable/zerocmux.sock"
    ) == "/tmp/zerocmux-staging-my-feature.sock")
    #expect(SocketPathMarkerFiles.defaultSocketPath(
        bundleIdentifier: "com.kernelalex.zerocmux.debug",
        environment: ["CMUX_TAG": "Issue 3542"],
        isDebugBuild: false,
        stableSocketPath: "/stable/zerocmux.sock"
    ) == "/tmp/zerocmux-debug-issue-3542.sock")
}
