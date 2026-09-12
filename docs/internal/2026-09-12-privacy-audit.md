# Privacy audit — 2026-09-12

Baseline: `f60bf965cd` (`main`, v1.2.4). Scope: first-party macOS app, local
packages, CLI, shell hooks, agent-chat, and an initial scan of the Rust TUI.
This is a source review, not a completed runtime network audit.

The requested invariant is zero external telemetry, with Sparkle update checks
as the sole automatic background check. The July upstream-sync specification
also permits configured GitHub PR probes; whether that exception remains is
awaiting clarification. Browser navigation, SSH, and configured agent providers
are functional network features whose treatment also needs to be explicit.

## Findings and implementation

| Path | Baseline behavior | Disposition |
| --- | --- | --- |
| `Packages/macOS/CmuxUpdater/.../UpdateSettings.swift` | Registers `SUSendProfileInfo=false`, but persisted `true` wins and the migration does not clear it. | Force false every time settings are applied. |
| `Packages/macOS/CmuxUpdater/.../UpdateDriver+SPUUpdaterDelegate.swift` | Resolves the appcast without enforcing the profile preference. | Reassert `updater.sendsSystemProfile=false` when resolving the feed, before Sparkle builds profile query parameters. Covers manual and scheduled checks, including later preference changes. |
| `Sources/CmuxRuntimeDebugCapture*.swift` | Environment-configured HTTP POST to arbitrary `baseURL/api/logs`; payload includes terminal probe data and a surface identifier. The only current caller is under `#if DEBUG` in `GhosttyTerminalView.swift`. | Delete HTTP sender/configuration/sequence; retain optional probes only in the local tagged debug log, enabled with `CMUX_RUNTIME_DEBUG_LOG=1`. Old URL/token/session variables have no effect. |
| `Sources/AppDelegate.swift`, `Sources/FeatureFlags.swift` | Anonymous telemetry hardcoded off; feature flags are local. `MacSentryStartupPolicy` remains for XCTest detection. | No live Sentry initialization found in the inspected app startup. |
| Ghostty build scripts | `build-ghosttykit-xcframework.sh` and `build-ghostty-cli-helper.sh` pass `-Dsentry=false`; archive validator rejects native Sentry markers. | Existing protection retained. This pass has not independently audited all vendored native code. |
| Xcode SwiftPM lockfile and `agent-chat/package.json` | No Sentry/PostHog or other recognized analytics SDK in these dependency declarations. | Retained; this is not proof that every dependency is network-free. |

## Functional network paths awaiting policy decisions

| Feature | Source / trigger | Open question |
| --- | --- | --- |
| GitHub PR status | `CmuxGit` request coordinator and probe service; `SidebarCatalogSection.showPullRequests` defaults true; shell integration also participates in PR updates. | Preserve current behavior, make explicit opt-in, or remove background polling? Any change must cover both app and shell paths. |
| Remote Markdown images | `MarkdownWebRenderer.imageLoadTask` calls `MarkdownRemoteImageFetcher` for remote image scheme requests when rendering a document. | Require a load action, prohibit remote images, or preserve automatic loading? |
| React Grab | `Sources/Panels/ReactGrab.swift` downloads a script from `unpkg.com` when invoked; no external prefetch caller was found. | Counts as a user-requested feature download under the narrower policy; would need bundling/removal under an absolute network ban. |
| Browser and remote sessions | WKWebView navigation, SSH transports, configured remote daemon downloads and WebSockets. | Preserve traffic required by user-requested workflows? |
| Agent chat | Loopback HTTP/WebSocket sidecar; remote catalog has been removed. User-launched agent CLIs can contact their configured providers. | Clarify app-owned traffic versus traffic from programs the user launches. |
| Rust remote transports | TUI includes direct/relay/Iroh providers and user-configured remote transport code. | Initial scan only; provider activation and discovery need further review before claiming an absolute egress guarantee. |

Local socket/feed status events named “telemetry” are not by themselves external
analytics. Their destinations and consumers, rather than their names, determine
whether they violate the policy.

## Validation

`UpdatePrivacyTests` exercises persisted preferences before and after the
migration, repeated application without overriding disabled update checks, and
the real Sparkle feed-resolution callback against a temporary fixture bundle.
The Sparkle test does not start the updater or contact the network.

Tests are committed separately from the fix and submitted to GitHub Actions.
No local tests are run. Tagged build and CI outcomes belong in the PR handoff;
until they complete, the implementation is unverified. No packet capture or
idle/startup egress observation has been performed in this pass.
