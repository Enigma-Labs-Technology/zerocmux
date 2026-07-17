# Upstream sync with zero-telemetry policy — July 2026

**Date:** 2026-07-16
**Status:** Approved
**Target:** merge `manaflow-ai/cmux@a5a70ff906` (1,140 commits, 2026-07-01 → 2026-07-16) into zerocmux `main`.

## Goal

Bring zerocmux fully up to date with upstream cmux while preserving the fork's
privacy invariant:

> No automatic network egress except Sparkle updates fetched from zerocmux's
> own GitHub releases, plus user-configured GitHub-API features (CmuxGit PR
> probe). Anything that communicates with cmux, a cmux-hosted service, or any
> other external service is excluded or explicitly removed.

Precedent: merge commit `0aa50abca` ("Merge upstream cmux ... with
zero-telemetry policy", 2026-07-02), which established the exclusion list this
design extends. Merge-base is `8850142b8e`.

## Approach (decided)

Single true git merge on branch `merge/upstream-2026-07-16` with the policy
applied in the merge commit itself, followed by CI-fixup commits on the same
PR branch. Alternatives considered and rejected: staged checkpoint merges
(~4x audit/build overhead for the same conflict set) and a cherry-pick
allowlist (infeasible at this volume; destroys the shared merge-base that
makes future syncs cheap).

## Exclusion policy for this delta

All exclusions from `0aa50abca` carry forward unchanged:

- `web/` app, Cloudflare `workers/`, cloud-VM workflows
- `ios/` companion app, `Packages/iOS/`, `Sources/Mobile/` (mobile host,
  pairing, push/presence/device registry)
- Hosted `Packages/Shared` packages: `CMUXAuthCore`, `CmuxAuthRuntime`,
  `CMUXMobileCore`, `CmuxAgentChat`, `CmuxSyncStore`, `CmuxAPIClient`
- StackAuth SDK and hosted account flows
- PostHog analytics, Sentry crash reporting (app and CLI) and their SPM deps
- `CmuxFeedback`, profiling email submitter, `sendAnonymousTelemetry` setting
- `homebrew-cmux` submodule; upstream appcast URLs

New exclusions introduced by this delta:

- **`Packages/Shared/CmuxIrohTransport`** — Iroh p2p relay transport.
  Consumed only by the excluded iOS app and `Sources/Mobile` host; connects
  to managed relay servers with minted credentials.
- **`services/`** (`iroh-relay-minter`) — hosted relay credential service.
- **`vault/`** (top-level Go tool) — uploads local agent transcripts to cmux
  Vault cloud storage via Stack Auth device-code login and S3. NOTE: distinct
  from the fork's local `Packages/macOS/CMUXAgentVault` and
  `Sources/VaultAgentRegistry.swift`, which stay. Document the naming
  collision in fork docs.
- **`.asc/`** and all TestFlight / App Store Connect workflows.
- **Vercel deploy configs** (`.vercelignore`), cmux-branded README
  translations (`README.<lang>.md`), marketing/launch blog posts.
- **agent-chat remote model catalog** (see Inclusions — the sidecar is kept,
  the catalog fetch is removed).

## Inclusions

- **`cmux-tui/`** — full adoption. Rust tmux-style TUI multiplexer; fully
  local (PTYs, Ghostty VT engine, local JSON-lines control socket). Verified
  by endpoint grep during the audit gate. Builds with cargo; compiles
  `libghostty-vt.a` from the ghostty submodule via zig.
- **`agent-chat/`** — adopted with the remote model-catalog machinery
  removed entirely: the `https://cmux.dev/api/agent-models` fetch, its ETag
  revalidation/cache, and the `CMUX_AGENT_MODELS_URL` override. Models come
  from built-in lists plus models reported by installed agent CLIs. The
  loopback, token-protected sidecar behavior is unchanged.
- **`Native/DiffSidecar`** — local Rust diff-viewer backend.
- **All improvements to `Sources/`, `Packages/macOS/`, `CLI/`, `daemon/`,
  `cmuxTests/`, `cmuxUITests/`, `tests/`, `tests_v2/`, `scripts/`,
  `webviews/`, `docs/`** — taken from upstream's side, then policy-scrubbed.
- **GPL bundling (upstream #8212)** — adapted to the fork's release pipeline
  (bundle license text + corresponding-source directions in the DMG).
- **GitHub-API fixes** (e.g. unauthenticated sidebar polling fix #8190) —
  merged into the kept CmuxGit integration. Decision: GitHub-API features
  stay (user's own account/repos, user-configured), consistent with the
  prior merge.

## Merge mechanics

1. Branch `merge/upstream-2026-07-16` off `main`; `git merge upstream/main`.
2. Conflict rules:
   - Paths deleted by the fork (excluded surfaces): stay deleted. New
     upstream files under excluded trees are removed in the merge commit.
   - Fork-owned identity: keep ours — bundle IDs
     (`com.kernelalex.zerocmux.*`), socket names/state dirs, `SUFeedURL` /
     appcast fallback, release/signing workflows (AWS-OIDC, protected `v*`
     tags), runner config (Blacksmith / GitHub-hosted), `CHANGELOG.md`,
     `README.md`, versioning, `.gitmodules`.
   - Everything else: take upstream's side, then scrub references to
     excluded modules from `cmux.xcodeproj`, `cmux.xcworkspace`,
     `Package.swift` files, and CI workflows.
3. Submodules: take upstream's pointers (`ghostty` → `bb30526cd`,
   `vendor/bonsplit` → `10563e2fd`) after verifying the fork's
   crash-report-subdir override commit is an ancestor of the new ghostty
   SHA. If it is not, reapply the override, push it to the submodule remote
   FIRST, and only then commit the pointer (CLAUDE.md submodule safety).
   `homebrew-cmux` is not added.

## Telemetry audit (hard gate before the PR is marked ready)

Documented in the PR description:

- Tree greps over the merged result: `posthog`, `sentry`, `stackauth`,
  `telemetry`, `cmux.com`, `cmux.dev`, `manaflow`, `iroh`, `feedback`,
  crash-report and appcast URLs. Every hit must be (a) nonexistent because
  the path is excluded, (b) a comment/doc/test-fixture with no runtime
  effect, or (c) explicitly justified in the PR.
- SPM audit: no analytics/crash-reporting SDKs in any `Package.swift` or
  `Package.resolved`.
- `agent-chat` and `cmux-tui`: no network code paths that bind or connect
  beyond loopback.

## Build and test verification

- All local SwiftPM packages build.
- GhosttyKit.xcframework rebuilt for the new ghostty SHA (ReleaseFast; via
  the build-ghosttykit workflow if local zig cannot link on this host).
- Tagged Debug app builds via `./scripts/reload.sh --tag <tag>`.
- `cmux-tui`: `cargo build -p cmux-tui`. `agent-chat`: bun install/build.
- Unit tests and tests_v2 run via GitHub Actions (never locally, per
  CLAUDE.md). CI failures fixed in follow-up commits on the PR branch.

## Deliverable

A PR to `main` containing the policy-documented merge commit plus fixups, a
CHANGELOG entry, and fork-doc updates (CLAUDE.md layout notes for
`cmux-tui`/`agent-chat`, the vault naming note).

## Error handling

- Ambiguous conflicts in kept code: prefer upstream, then re-verify fork
  constraints (localization, shortcut policy, latency-sensitive paths).
- Ghostty override missing from the new SHA: reapply + push to the
  submodule remote before the parent pointer commit.
- agent-chat tests that depended on the remote catalog: rewrite against
  local fixtures; if not practical, state that explicitly rather than
  shipping a fake test (test quality policy).
