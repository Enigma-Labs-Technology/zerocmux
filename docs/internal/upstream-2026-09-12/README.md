# Upstream integration and privacy review

Target: `manaflow-ai/cmux@309513b40839520d239aed67d420b6e4e06f4e41`.
Fork starting point: `bc9b1a6e9c624ab64dec153d08f3d87792ca9e2e`.
Shared base: `afe629534f52f748282543c13521186e19ea8781`.

The integration contains 4,819 upstream commits. It preserves upstream ancestry
and applies the fork policy to the resulting merge tree; historical upstream
commits are not rewritten. [The commit ledger](incoming-commits.csv) identifies
182 non-merge commits whose diffs match telemetry-related terms. Its path counts
are classification aids, not evidence that every historical tree was telemetry-free.
Path counts describe the initial merge tree before the integration follow-ups;
relocated desktop code and later test exclusions can change those counts.

## Policy changes

- Sentry initialization, PostHog analytics and remote feature-flag fetching remain
  removed. Flags use local overrides and built-in defaults.
- Sparkle system profiles are forced off at settings initialization and feed
  resolution. Update feeds and download fallbacks use the fork's GitHub releases.
  The fork's universal nightly artifact contract is retained.
- Remote browser suggestions and GitHub PR polling now require explicit settings
  opt-in. Existing explicit choices remain effective.
- External debug-log posting remains removed. Optional debug probes use the
  local tagged log only.
- Hosted Cloud clients, fleet polling, VPN/tunnel services, mobile pairing,
  push/presence, hosted authentication, feedback upload, and related UI are
  excluded. Hosted commands return an unavailable response. Cloud policy remains
  disabled regardless of managed preferences.
- `web/`, `workers/`, `ios/`, `services/`, `vault/`, hosted shared packages,
  Stack Auth, and the tunnel extension remain excluded.
- The local agent-chat sidecar retains its loopback/token boundary and local model
  catalog. Local socket/feed events are not external analytics.

Local Git utilities, syntax highlighting, and agent session records that became
shared with excluded mobile features were moved or retained in local domains.
The local agent registry supports restore bindings and sidebar rosters without
phone transcript synchronization. Generic surface catalog data and algorithms
remain available without a hosted fleet provider.

User-requested browser navigation, SSH/remote transports, configured providers,
and configured automation remain functional network features. Existing configured
GitHub PR status integration is retained. These are distinct from project-owned
analytics; this integration does not sandbox arbitrary user programs or websites.

## Fetched computer-use dependency

The helper is pinned to `manaflow-ai/cmux-cua@7a57a7c79522ece017a3ae4ef7884a24d7eec270`.
Its original Rust executable reports to PostHog, includes an install ping that
bypasses its telemetry opt-out, and has a separate update checker/installer.

`patches/cmux-cua-zero-telemetry.patch` removes the reporting and update transport
modules, entry-point reporting, the install event, and the update-check MCP tool.
Legacy telemetry invocations are rejected; update commands report that zerocmux
owns updates. The helper's status reports telemetry disabled without reading or
creating an installation identifier.

The build requires the matching audited revision, materializes the pristine
pinned Git tree, applies the patch, and compiles from a source/cache slot keyed by
both revision and patch hash. It never compiles uncommitted changes from an
override checkout. A built-binary check rejects known reporting/update markers
and requires the compiled zerocmux policy marker. The helper has the fork's own
TCC bundle identifier, `com.kernelalex.zerocmux.cua`.

## Bundled TUI source

The upstream reload script fetched a rolling binary from `files.cmux.com`, which
could differ from the audited source. The fork now compiles the bundled TUI from
this checkout with Cargo's locked dependencies and the app's architectures.
External manifest and prebuilt-binary overrides are rejected; the app records the
TUI source tree identity. Iroh stays excluded from the default feature set.

The hosted `cmux-tui-artifacts.yml` publisher and web installer remain excluded.
Their two source-text tests are recorded in the exclusion ledger; executable
manifest digest, artifact-set, size, and provenance validation tests are retained.

The bundled TUI no longer starts the hosted Cloud VM usage poller from inherited
`CMUX_CODEROUTER_URL` / `CMUX_VM_ID` or `model-plane.env` settings. A process-level
loopback regression observed the unwanted request on the test-only commit
`72dc73db88` before removal; the test remains to guard both legacy inputs.

Tagged builds no longer seed hosted API, Iroh broker, or authentication settings.
The reload script also preserves real directories at its compatibility-link path.

## Native dependency builds

- Ghostty: `abd40f6e472d57f2d4bb182004bb5f3fac8df961`.
- Bonsplit: `faf84186d5c64dcec330d4f352e5aed8cffc89f0`.

Both revisions were verified reachable from their remote `main` branches.
GhosttyKit builds with `ReleaseFast`, `sentry=false`, `i18n=false`, and the
`zerocmux/crash` subdirectory. Its cache key includes those build options so
incompatible cached artifacts cannot be reused.

## Verification status

The tagged app/CLI, privacy-patched computer-use helper, and source-built TUI
have compiled. The full `zerocmux-unit` test target also compiled successfully
with the tagged derived-data path. No tests
have been run locally; local validation consists of compilation, project wiring,
and built-artifact inspection.

GitHub Actions passed 1,256 package tests covering the updater, local agent launch
and journal, core, Git, settings, and Settings UI. The helper reporting/update
refusal tests passed inside an outbound-network-denying sandbox. The opt-in
regression commit failed on exactly the two new assertions before the fix, then
passed afterward. The TUI binary unit suite passed 1,655 tests (plus 11 hook
tests); its broader CLI/integration suite is still being verified.

Tests solely for removed hosted/mobile services are excluded alongside their
implementations; local tests retain coverage through local action paths.
[The exclusion ledger](excluded-test-paths.json) records that cleanup.

The repository has no registered macOS self-hosted runner. A GitHub-hosted macOS
privacy workflow supplies the focused package, helper, and TUI lanes. Legacy CI
lanes requiring upstream runner infrastructure remain separate from these
results. A known-endpoint scan of the assembled native binaries found no
PostHog/Sentry ingest or helper install-event markers; that scan is a supporting
artifact check, not a complete observation of every runtime network path.

## Background CI review

The stale Go daemon lane was removed after upstream deleted its implementation.
The real CI aggregate remains authoritative; the imported fallback that falsely
reported successful skipped CI was removed. Windows target setup now selects the
TUI pinned Rust toolchain, and Cargo build diagnostics remain visible in the
Valgrind lane. Generated webview assets were rebuilt from the merged sources.
Obsolete hosted SDK publisher workflow assertions are recorded in the exclusion
ledger; runtime protocol, SDK artifact, and provenance checks remain enabled.
