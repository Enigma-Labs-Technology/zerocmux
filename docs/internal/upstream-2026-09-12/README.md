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

The initial sync removed the Go daemon with upstream. The production pass found
that the retained SSH client still requires it, so the fork daemon, asset builder,
manifest generator, and executable asset coverage are restored from `bc9b1a6e9c`.
A focused hosted Go test lane now covers this compatibility component. It has no
analytics client and only serves explicitly configured remote sessions.
The real CI aggregate remains authoritative; the imported fallback that falsely
reported successful skipped CI was removed. Windows target setup now selects the
TUI pinned Rust toolchain, and Cargo build diagnostics remain visible in the
Valgrind lane. Generated webview assets were rebuilt from the merged sources.
Obsolete hosted SDK publisher workflow assertions are recorded in the exclusion
ledger; runtime protocol, SDK artifact, and provenance checks remain enabled.

## Production preparation (2026-09-14)

Candidate: 1.3.0, build 93 (published 1.2.4 uses build 92). No release tag or
production upload has been created. The monotonic check now reads the fork feed.

The release workflow uses the pinned GhosttyKit source-build fallback, requires
SDK 26 explicitly, installs the reviewed source-built TUI, and checks both TUI
and computer-use architectures before signing. The restored SSH asset builder
produced all four target binaries with matching manifest checksums. The official
Go vulnerability scanner found no reachable vulnerabilities using Go 1.27.1.
The release and SSH CI lanes pin that compiler version.

Tagged Debug and isolated unsigned arm64 Release builds at `0291533169`
completed successfully on the local macOS 27 SDK. Updater feed, disabled profile
reporting, computer-use binary policy, TUI source provenance, and canonical
bundled license-file checks passed. All 14 native Release binaries were checked
for known removed reporting markers. The Release packaging steps installed the
reviewed TUI and injected the four-platform SSH manifest with verified checksums.
This is not a signed/notarized universal release validation on SDK 26 or a
complete observation of every runtime network path.

Focused package/helper/TUI checks passed the preceding privacy changes. CI
repairs in `48cb64e825` and `616f26ae84` preserve executable coverage; all 17 SDK
jobs, TUI web/bindings/Windows, and Linux/macOS Clippy passed on `616f26ae84`.
Native tests and signing verification remain deferred at the user's request.
The focused hosted TUI lane now runs a bounded detach/reattach smoke instead of
relying on the older opt-in gate.

The final hosted pass exposed a process ownership defect in the TUI: unrelated
children temporarily inherit close-on-exec marker descriptors during fork. The
cleanup scanner could retain that false ownership evidence and kill another
terminal's process. The deterministic test-only commit `f13fc51baf` failed on
both Linux and macOS in Actions run `34824968380`. The repair ignores
close-on-exec markers on both platforms while preserving explicitly inherited
markers and descendant cleanup. Both platforms passed the focused suite in run
`34830546645`; final commit `0291533169`, including the descriptor-read
optimization and formatting, also passed on both platforms in run
`34832091517`. The regression exercises actual cleanup: scope roots and
explicitly tracked children terminate, while unrelated children survive.

Dependency audit: agent-chat's Bun lockfile had no advisories. The webview
lockfile initially reported 33; narrow updates to the affected build/test
dependencies now pass `bun audit` with none. The frozen install, typecheck, and
production bundle build pass, and every generated shipped webview file is
byte-identical. Root picomatch is also updated, clearing its two advisories.
No new dependency names or reporting SDKs are introduced by these lock changes.

Two advisories remain in OpenTUI 0.1.106's dependency graph:

- `diff` 8.0.2: the affected `parsePatch` implementation is embedded in
  OpenTUI's `DiffRenderable`. The Feed uses Box, ScrollBox, and Text; it never
  constructs that renderable or supplies input to the patch parser.
- `file-type` 16.5.4: Jimp and its affected ASF parser are embedded in the
  separate `@opentui/core/3d` entry point. The Feed imports the default entry
  point; its JavaScript import graph does not load the 3D module.

This is a source reachability assessment for the fork's Feed, not a claim that
the dependency packages themselves are patched. Overriding the transitive npm
versions alone would not replace the vulnerable code embedded inside OpenTUI.
Any future Diff/3D Feed usage must first replace or patch that code. No local
tests were executed; runtime regression coverage remains in hosted CI.


## Final TUI recovery pass

Broader core checks at `0291533169` found a separate persisted-state recovery
bug on both Linux and macOS. Startup terminal repair left live tabs pointing to
a tombstoned terminal, so reopening failed validation. The repair transaction
had already committed, leaving an affected database in that partial state.

Test-only commits `d74ac20fd5` and `24045d35e7` cover empty panes, surviving tabs,
a surviving active tab, and the partial state left by an earlier failed launch.
The first test-only commit reproduced the reopen failure on both platforms in
Actions run `34835461082`. Runtime fix `d7114eb092` uses the shared terminal/tab
removal helper, aligns deletion revisions, and normalizes only affected panes.
It preserves surviving active tabs and makes a second reopen a no-op. The
existing content index supports the new dangling-tab lookup. Two macOS socket
test fixtures also use shorter paths so their intended permission and nested
creation checks reach the bind operation.

The focused Linux/macOS workflow now includes the complete core library test
suite. The preceding final privacy integration run `34832088342` passed 1,790
TUI tests, the original drag and host-disconnect regressions, and the mandatory
attach/detach smoke. All 17 SDK checks passed in `34832088403`, and Valgrind,
Windows, web frontend, and bindings E2E passed in `34832088207`. See PR #10 for
current verification of the subsequent recovery fix and rebuilt artifacts.

A public OSV query of all 608 locked Rust registry versions found
`RUSTSEC-2026-0258` for h2 0.4.15 and the informational unmaintained-package notice
`RUSTSEC-2024-0436` for paste 1.0.15. h2 is absent from the arm64 Release build:
the built hyper and reqwest feature sets exclude HTTP/2, and the bundled TUI
excludes Iroh. The h2 issue remains relevant to optional configurations that
enable that dependency; this is not a clean advisory claim for every feature
combination. Native app/UI tests and signed universal validation remain deferred.
