# July 2026 Upstream Sync (Zero-Telemetry) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Tasks 2–9 share one in-progress merge working state (a single `git merge --no-commit`); they MUST run in order, in one session/worktree, with no `git reset`/`git checkout .` between them. Subagent-per-task execution is NOT suitable for Tasks 2–9.

**Goal:** Merge upstream `manaflow-ai/cmux@a5a70ff9063` (1,140 commits, 2026-07-01 → 2026-07-16) into zerocmux as one policy-documented merge commit plus follow-up CI fixes, preserving zero telemetry.

**Architecture:** Single true git merge on branch `merge/upstream-2026-07-16` (spec: `docs/superpowers/specs/2026-07-16-upstream-sync-zero-telemetry-design.md`). 518 of 695 conflicts are delete-side (excluded surfaces) and resolve mechanically; 177 are real content conflicts resolved per policy groups; then policy scrub, agent-chat catalog removal, submodule pointer sync, telemetry audit gate, build verification, merge commit, PR + CI fixups.

**Tech Stack:** git (merge-tree dry-runs), Swift/SwiftPM/xcodebuild, Rust/cargo (cmux-tui, DiffSidecar), bun/TypeScript (agent-chat), zig (GhosttyKit), GitHub Actions.

## Global Constraints

- Privacy invariant (spec, verbatim): "No automatic network egress except Sparkle updates fetched from zerocmux's own GitHub releases, plus user-configured GitHub-API features (CmuxGit PR probe). Anything that communicates with cmux, a cmux-hosted service, or any other external service is excluded or explicitly removed."
- No analytics/crash SDKs in any `Package.swift`/`Package.resolved` (no posthog-ios, sentry-cocoa, StackAuth).
- Fork identity is kept everywhere: bundle IDs `com.kernelalex.zerocmux.*`, zerocmux socket names/state dirs, `SUFeedURL` pointing at zerocmux releases, fork version `1.2.1`/build `89` (bump later via release flow, not this merge).
- Module names remain `cmux`/`cmux_DEV` (precedent from prior merge `0aa50abca`).
- Never run E2E/UI/python tests locally; CI only (CLAUDE.md testing policy). `./scripts/test-unit.sh` is allowed but prefer CI.
- Local builds only via `./scripts/reload.sh --tag upstream-sync-2026-07` or `xcodebuild ... -derivedDataPath /tmp/zerocmux-upstream-sync-2026-07`.
- Submodule safety: a submodule pointer may only be committed after the pointed-to commit is reachable from the submodule remote's `main` (verify with `git merge-base --is-ancestor`).
- Working directory: `/Users/alex/zerocmux`. Scratch dir for generated lists: `${SCRATCH:=/tmp/zerocmux-upstream-sync-scratch}` (create it; any path works — regenerate lists rather than trusting stale copies).

## Pinned SHAs

| Ref | SHA |
|---|---|
| upstream/main (merge target) | `a5a70ff9063…` (`git rev-parse upstream/main` must start with `a5a70ff906`) |
| merge-base | `8850142b8e` |
| fork main at planning time | `bf987c68b` |
| ghostty pointer: fork → upstream | `541e5e89db0448d5cd85a7b348d8f6a64618c900` → `bb30526cdab8f5fb08ae43e404e3aacc40d3ffc3` |
| vendor/bonsplit pointer: fork → upstream | `01751efce3f01becea98a13efe48d4a011223b7d` → `10563e2fda6fc18c47adf1864d55e0e25087a864` |

## Excluded-path manifest (authoritative for Tasks 2, 5, 9)

Directories/files that must NOT exist in the merged tree:

```
web/  workers/  ios/  services/  vault/  homebrew-cmux  .asc/  .vercelignore
Packages/iOS/  Packages/Shared/  Sources/Mobile/
README.<lang>.md  (all upstream README translations: ar bs da de es fr it ja km ko no pl pt-BR ru th tr uk vi zh-CN zh-TW)
.github/workflows/{cloud-vm-migrate,cloud-vm-smoke,ios-app-store,ios-appstore-upload,ios-screenshots,ios-streamed-validate,ios-testflight,iroh-relay-minter,presence,docs-channels,docs-deploy-reusable,claude,sdk-publish-crates,sdk-publish-go,sdk-publish-java,sdk-publish-npm,sdk-publish-python,tui-publish-npm,tui-publish-pypi,cmux-tui-artifacts,cmux-tui-build-package,cmux-tui-nightly,cmux-tui-release-cut,cmux-tui-release}.yml
```

Kept new workflows: `.github/workflows/cmux-tui.yml` (CI build/test lane only; adapt runners in Task 8).
Kept new dirs: `cmux-tui/`, `agent-chat/` (catalog machinery removed in Task 6), `Native/DiffSidecar` growth.

---

### Task 1: Preflight — refs, worktree state, conflict inventory

**Files:**
- Create: `$SCRATCH/conflicted-files.txt`, `$SCRATCH/conflicts-real.txt`, `$SCRATCH/conflicts-deleted.txt`

**Interfaces:**
- Produces: the three conflict-list files consumed by Tasks 2 and 4; confirmed-clean starting state.

- [ ] **Step 1: Verify branch, refs, and clean tree**

```bash
cd /Users/alex/zerocmux
git status --porcelain            # expect: empty
git branch --show-current         # expect: merge/upstream-2026-07-16
git rev-parse --short upstream/main   # expect: a5a70ff906
git merge-base main upstream/main | cut -c1-10   # expect: 8850142b8e
git log --oneline -1              # expect: 749f6fff77 Add design spec …
```

If upstream/main does not match, STOP and re-fetch `git fetch upstream main --no-tags`; if it moved past `a5a70ff906`, flag to the user before proceeding (spec pins this SHA).

- [ ] **Step 1b: Populate submodules (this checkout has `ghostty` unpopulated)**

```bash
git -C /Users/alex/zerocmux submodule update --init ghostty vendor/bonsplit
git -C /Users/alex/zerocmux/ghostty rev-parse --short HEAD   # expect: 541e5e89d
git -C /Users/alex/zerocmux/vendor/bonsplit rev-parse --short HEAD   # expect: 01751efce
```

(Use `git -C <path>` rather than `cd` throughout Task 7 — a shell left inside an unpopulated submodule directory makes parent-repo git commands fail with "fatal: in unpopulated submodule".)

- [ ] **Step 2: Regenerate the conflict inventory**

```bash
export SCRATCH=/tmp/zerocmux-upstream-sync-scratch; mkdir -p $SCRATCH
git merge-tree --write-tree --name-only main upstream/main > $SCRATCH/merge-dryrun.txt; echo "exit=$?"
# expect: exit=1  (conflicts exist)
awk 'NR>1 && $0=="" {exit} NR>1 {print}' $SCRATCH/merge-dryrun.txt > $SCRATCH/conflicted-files.txt
git ls-tree -r --name-only main > $SCRATCH/main-files.txt
comm -12 <(sort $SCRATCH/conflicted-files.txt) <(sort $SCRATCH/main-files.txt) > $SCRATCH/conflicts-real.txt
comm -23 <(sort $SCRATCH/conflicted-files.txt) <(sort $SCRATCH/main-files.txt) > $SCRATCH/conflicts-deleted.txt
wc -l $SCRATCH/conflicts-real.txt $SCRATCH/conflicts-deleted.txt
# expect: ~177 real, ~518 deleted (exact numbers may differ by ±0 if refs unchanged)
```

- [ ] **Step 3: Sanity-check the deleted list is 100% excluded-surface paths**

```bash
grep -vE '^(web/|workers/|ios/|services/|vault/|\.asc/|Packages/iOS/|Packages/Shared/|Sources/Mobile/|README\.[a-zA-Z-]+\.md|\.github/workflows/(cloud-vm|ios-|iroh-|presence|docs-|claude|sdk-publish|tui-publish|cmux-tui-)|homebrew-cmux|\.vercelignore)' $SCRATCH/conflicts-deleted.txt
```

Expected: a small remainder (files upstream deleted that the fork modified, e.g. moved files). Each remaining line must be inspected in Task 4 Step 1 — they are "we modified / they deleted" conflicts, resolved by following upstream's move/rename unless the fork's modification was policy-relevant.

### Task 2: Start the merge and resolve all mechanical conflicts

**Files:**
- Modify: entire working tree (merge in progress, `MERGE_HEAD` set)

**Interfaces:**
- Consumes: `$SCRATCH/conflicts-deleted.txt` from Task 1.
- Produces: a working tree where only the ~177 real content conflicts remain unresolved (`git diff --name-only --diff-filter=U`).

- [ ] **Step 1: Begin the merge**

```bash
git merge --no-commit --no-ff upstream/main || true
git diff --name-only --diff-filter=U | wc -l   # expect: ~695
```

- [ ] **Step 2: Resolve delete-side conflicts on excluded trees (keep deleted)**

```bash
for p in web workers ios services vault .asc Packages/iOS Packages/Shared Sources/Mobile; do
  git rm -r --cached --ignore-unmatch -q -- "$p"; rm -rf "$p"
done
git rm --cached --ignore-unmatch -q -- .vercelignore homebrew-cmux 'README.*.md' && rm -f .vercelignore
git checkout --ours -- README.md 2>/dev/null; git add README.md
```

Note: `git rm` on the excluded trees also removes upstream files that were ADDED under those trees and auto-staged without conflict — that is intended and required.

- [ ] **Step 3: Drop excluded workflows; keep cmux-tui CI**

```bash
cd .github/workflows
git rm --ignore-unmatch -q cloud-vm-*.yml ios-*.yml iroh-relay-minter.yml presence.yml docs-channels.yml docs-deploy-reusable.yml claude.yml sdk-publish-*.yml tui-publish-*.yml cmux-tui-artifacts.yml cmux-tui-build-package.yml cmux-tui-nightly.yml cmux-tui-release-cut.yml cmux-tui-release.yml
git status --porcelain -- . | grep -c '^UU'   # count remaining workflow conflicts; expect 6 (ci, ci-macos-compat, nightly, perf-activation, release, test-e2e)
cd /Users/alex/zerocmux
```

- [ ] **Step 4: Keep the fork's .gitmodules**

```bash
git checkout --ours -- .gitmodules && git add .gitmodules
git config -f .gitmodules --get-regexp path
# expect exactly two: ghostty, vendor/bonsplit (no homebrew-cmux)
```

- [ ] **Step 5: Verify only real conflicts remain**

```bash
git diff --name-only --diff-filter=U | sort > $SCRATCH/remaining.txt
comm -23 $SCRATCH/remaining.txt <(sort $SCRATCH/conflicts-real.txt)
# expect: empty (nothing unresolved outside the real-conflict list)
wc -l < $SCRATCH/remaining.txt   # expect: ~177 or fewer
```

### Task 3: Resolve fork-identity conflicts (ours-with-ports)

**Files (all from `$SCRATCH/conflicts-real.txt`):**
- Modify: `CHANGELOG.md`, `README.md` (done in Task 2), `CLAUDE.md`, `CONTRIBUTING.md`, `.coderabbit.yaml`, `.greptile/config.json`, `.greptile/files.json`, `.github/workflows/release.yml`, `.github/workflows/nightly.yml`, `scripts/build-sign-upload.sh`, `Resources/bin/zerocmux-claude-wrapper`, `Packages/macOS/CmuxUpdater/Sources/CmuxUpdater/UpdateDriver.swift`, `UpdateDriver+SPUUpdaterDelegate.swift`, `UpdateStateModel+ErrorFormatting.swift`, `Tests/CmuxUpdaterTests/UpdateStateModelTests.swift`

**Interfaces:**
- Produces: all fork-identity files staged; appcast/bundle/runner identity unchanged from fork `main`.

- [ ] **Step 1: Keep ours where fork owns the file wholesale**

```bash
git checkout --ours -- CHANGELOG.md CONTRIBUTING.md .coderabbit.yaml .greptile/config.json .greptile/files.json
git add CHANGELOG.md CONTRIBUTING.md .coderabbit.yaml .greptile/config.json .greptile/files.json
```

- [ ] **Step 2: CLAUDE.md — keep fork guide, port new upstream operational rules**

Open the conflicted `CLAUDE.md`; resolve every hunk to the fork's text, then read upstream's version (`git show upstream/main:CLAUDE.md`) and manually port only NEW operational guidance that applies to kept surfaces (e.g. cmux-tui dev-loop notes if present). Do not port web/ios/cloud/mobile sections. `git add CLAUDE.md`.

- [ ] **Step 3: Release pipeline files — fork side wins, port kept-surface fixes**

For each of `.github/workflows/release.yml`, `.github/workflows/nightly.yml`, `scripts/build-sign-upload.sh`:
resolve to the fork side first (`git checkout --ours -- <file>`), then diff upstream's changes since merge-base and port ONLY hunks that are (a) bug fixes to steps the fork also runs, or (b) the GPL/corresponding-source bundling from upstream #8212:

```bash
git diff 8850142b8e upstream/main -- .github/workflows/release.yml scripts/build-sign-upload.sh | less
git log --oneline 8850142b8e..upstream/main -- scripts/build-sign-upload.sh   # locate #8212 hunks
```

Port the #8212 GPL bundling by hand, replacing upstream source-offer URLs (`manaflow-ai/cmux`) with `Enigma-Labs-Technology/zerocmux`. Keep fork runner labels (`zerocmux-signing`, Blacksmith/GitHub-hosted), AWS-OIDC signing, and `zerocmux-macos.dmg` asset name. `git add` each file.

- [ ] **Step 4: CmuxUpdater — take upstream logic, keep fork feed identity**

```bash
git checkout --theirs -- Packages/macOS/CmuxUpdater/Sources/CmuxUpdater/UpdateDriver.swift Packages/macOS/CmuxUpdater/Sources/CmuxUpdater/UpdateDriver+SPUUpdaterDelegate.swift Packages/macOS/CmuxUpdater/Sources/CmuxUpdater/UpdateStateModel+ErrorFormatting.swift Packages/macOS/CmuxUpdater/Tests/CmuxUpdaterTests/UpdateStateModelTests.swift
grep -rn "manaflow\|cmux/releases" Packages/macOS/CmuxUpdater/Sources | grep -v zerocmux
```

Every hit from the grep must be edited to the fork's appcast (`https://github.com/Enigma-Labs-Technology/zerocmux/releases/...`) or removed; check fork `main`'s version of the same lines for the exact fork values (`git show main:Packages/macOS/CmuxUpdater/Sources/CmuxUpdater/UpdateDriver.swift | grep -n releases`). Then `git add` the four files.

- [ ] **Step 5: zerocmux-claude-wrapper — 3-way port**

Upstream modified their `cmux-claude-wrapper`; the fork renamed it. Take the fork file, apply upstream's behavioral diff:

```bash
git checkout --ours -- Resources/bin/zerocmux-claude-wrapper
git diff 8850142b8e upstream/main -- Resources/bin/cmux-claude-wrapper > $SCRATCH/wrapper.diff
```

Apply `$SCRATCH/wrapper.diff` hunks by hand (paths/names differ). Keep zerocmux socket/env names. `git add Resources/bin/zerocmux-claude-wrapper`.

- [ ] **Step 6: Stage check**

```bash
git diff --name-only --diff-filter=U | grep -cE '^(CHANGELOG|README|CLAUDE|CONTRIBUTING|\.coderabbit|\.greptile|Resources/bin/|Packages/macOS/CmuxUpdater)'   # expect: 0
```

### Task 4: Resolve kept-code content conflicts (theirs-then-readapt), group by group

**Files:** the remainder of `$SCRATCH/conflicts-real.txt` (~120 files), in these groups:
(a) `CLI/` + `daemon/` (b) `Packages/macOS/` non-updater (c) `Sources/` (d) `cmuxTests/` + `cmuxUITests/` (e) `tests/*.py`, `tests/*.sh` (f) `docs/`, `skills/`, `.github/` non-workflow, `scripts/` remainder (g) `Resources/` assets + `Localizable.xcstrings` (h) `cmux.xcodeproj/project.pbxproj`, `Package.resolved`, `cmux.xcworkspace/contents.xcworkspacedata`, `webviews/`

**Interfaces:**
- Consumes: conflict lists from Task 1.
- Produces: `git diff --diff-filter=U` empty; zero unresolved paths.

**Resolution procedure for every file in groups (a)–(f):** start from upstream's side, then re-apply the fork's still-relevant adaptations. The fork's adaptations are discoverable per file with:

```bash
git log --oneline 8850142b8e..main -- <file>       # fork-era commits touching it
git diff upstream/main main -- <file>              # net fork delta vs upstream
```

Re-apply only deltas that are fork identity (zerocmux names/slugs/sockets, runner guards, `Enigma-Labs-Technology` remotes, alarm/timeout bounds added for fork CI) or policy (removed telemetry hooks). Do NOT re-apply stale workarounds that upstream has since fixed properly — check upstream's log for the same lines first.

- [ ] **Step 1: Inspect the Task-1-Step-3 remainder (we-modified/they-deleted files)**

For each remaining line from Task 1 Step 3 (e.g. possibly `scripts/lib/mobile-attach.sh`, moved test harness files): check usage with `git grep -l <basename> -- scripts tests tests_v2 .github` on OURS side. If used only by excluded surfaces → `git rm`; if upstream renamed/moved it → follow the move and re-apply fork deltas at the new path.

- [ ] **Step 2: Group (a) CLI + daemon** — apply the procedure to `CLI/cmux.swift`, `CLI/cmux_open.swift`, `CLI/CMUXCLI+AgentHookDefinitions.swift`, `CLI/CMUXCLI+AutoNaming.swift`, `CLI/CMUXCLI+SessionsList.swift`, `daemon/remote/cmd/cmuxd-remote/cli.go`, `cli_test.go`, `daemon/remote/README.md`. Verify: `git diff --name-only --diff-filter=U -- CLI daemon` → empty.

- [ ] **Step 3: Group (b) Packages/macOS** — same procedure for the ~14 remaining files (CmuxControlSocket, CmuxGit `PullRequestProbeService+Fetch.swift` (take upstream's unauthenticated-polling fix wholesale), CmuxRemoteSession, CmuxRemoteWorkspace, CmuxSettings, CmuxSettingsUI, CmuxTerminal, CmuxTerminalCore, CMUXAgentLaunch). After resolving, quick build gate:

```bash
for p in CmuxControlSocket CmuxGit CmuxRemoteSession CmuxRemoteWorkspace CmuxSettings CmuxSettingsUI CmuxTerminal CmuxTerminalCore CMUXAgentLaunch; do swift build --package-path Packages/macOS/$p || echo "FAIL $p"; done
# expect: no FAIL lines (some may need Task 5's scrub first — record failures, do not force)
```

- [ ] **Step 4: Group (c) Sources/** — same procedure for the ~35 app files (AppDelegate, TerminalController±, TabManager±, ContentView, GhosttyTerminalView, RemoteTmux* cluster, SessionIndex*, Settings*, Workspace, cmuxApp, Cloud/VMClient*, Auth/AuthEnvironment, CloudVMActionLauncher, Panels/BrowserPanel, Panels/CmuxWebView, App/*). For `Sources/Cloud/*` and `Sources/Auth/AuthEnvironment.swift` and `CloudVMActionLauncher.swift`: fork side is the already-neutered variant — keep ours unless upstream's change is a pure compile-compat fix. Note honored pitfalls: `TerminalWindowPortal.swift` hitTest guard, `ContentView.swift` TabItemView equatable contract, `GhosttyTerminalView.swift` forceRefresh (no allocations).

- [ ] **Step 5: Group (d) cmuxTests + cmuxUITests** — same procedure (~25 files). Fork-era test bounds (perl alarm, 300s bounds) must survive where the fork added them.

- [ ] **Step 6: Group (e) python/shell tests** — same procedure (~50 files). Fork deltas here are mostly zerocmux naming, socket paths, and CI-runner guards (`test_ci_self_hosted_guard.sh`, `test_ci_change_areas.py` fork expectations) — re-apply them on top of upstream's side.

- [ ] **Step 7: Group (f) docs/skills/scripts remainder** — same procedure. `docs/ghostty-fork.md`: merge both (fork's fork-notes + upstream's new conflict notes). `scripts/reload.sh`: take upstream, re-apply fork tag/socket naming (`zerocmux-debug-<tag>`), verify by reading the final file for `zerocmux` consistency. `scripts/ghosttykit-checksums.txt`: resolve to OURS for now — Task 7 regenerates it.

- [ ] **Step 8: Group (g) Resources** — `Localizable.xcstrings`: union-merge (take upstream, re-add fork-only keys from ours; JSON — validate with `python3 -c "import json;json.load(open('Resources/Localizable.xcstrings'))"`). `agent-session-react/`, `agent-session-solid/`, `markdown-viewer/` chunks: generated assets — take upstream's side verbatim.

- [ ] **Step 9: Group (h) project files** — `cmux.xcodeproj/project.pbxproj`: start from upstream (`git checkout --theirs`), then (1) restore fork identity settings by diffing against ours: `PRODUCT_BUNDLE_IDENTIFIER = com.kernelalex.zerocmux*`, display name, `MARKETING_VERSION = 1.2.1`, `CURRENT_PROJECT_VERSION = 89`, team/signing; (2) delete file/target references to excluded paths (search for `Mobile`, `Iroh`, `Shared/Cmux`, verify against Task 5 greps). `cmux.xcworkspace/contents.xcworkspacedata`: keep upstream, remove excluded package entries. `Package.resolved`: resolve to OURS for now — regenerated in Task 10. `webviews/` (3 files): theirs-then-readapt like group (c).

- [ ] **Step 10: Zero unresolved**

```bash
git diff --name-only --diff-filter=U   # expect: empty
git status --porcelain | grep -c '^UU'  # expect: 0
```

### Task 5: Policy scrub of auto-merged content

Auto-merged (non-conflicted) upstream changes to KEPT files can reference excluded modules (new call sites for MobileHost/Iroh/etc.). Compile errors catch Swift cases; greps catch the rest.

**Files:**
- Modify: any staged file failing the greps below; likely includes `Sources/IrohTransportDebugMenuButtons.swift` (new upstream file → delete), `Sources/TerminalController+MobileChat.swift`, `+MobileWorkspaceList.swift`, `+MobileScrollPrefetch.swift` (fork previously excluded these — if the merge re-added them, delete and remove call sites), `Sources/cmuxApp.swift` debug-menu wiring.

**Interfaces:**
- Produces: a tree where the Task 9 audit greps pass; consumed by all build tasks.

- [ ] **Step 1: Find and remove re-grown excluded references**

```bash
git grep -ln "import CmuxIrohTransport\|MobileHostService\|MobileHostIroh\|CmuxAuthRuntime\|CMUXMobileCore\|CmuxSyncStore\|CmuxAPIClient\|import CmuxAgentChat" -- Sources Packages CLI cmuxTests cmuxUITests
```

For each hit: if the whole file exists only to serve an excluded surface → `git rm` it and remove its references (Xcode project, callers). If it's a kept file with an excluded call site → delete the call site hunk (compare fork `main`'s version of the file for the previous clean shape: `git show main:<file>`).

```bash
git grep -ln "posthog\|PostHog\|Sentry\|sentry\|StackAuth\|stackauth\|sendAnonymousTelemetry" -- Sources Packages CLI agent-chat cmux-tui webviews scripts
```

Same treatment. Exception: `ghostty/`-related sentry build flags are the submodule's (off flavor) and live outside this repo.

- [ ] **Step 2: Settings/palette/socket surface check**

```bash
git grep -in "mobile\|pairing\|iroh" -- Sources/SettingsNavigation.swift Sources/KeyboardShortcutSettings.swift Packages/macOS/CmuxSettings Packages/macOS/CmuxSettingsUI | grep -vi "kiroHooks"
```

Remove any re-grown Mobile/pairing settings rows, shortcut actions, palette entries, and socket command registrations (`git grep -n "mobile" -- Packages/macOS/CmuxControlSocket/Sources`). Each removal must delete the full shared-behavior path (settings key + UI row + palette + socket command + docs), not one surface (CLAUDE.md shared-behavior policy).

- [ ] **Step 3: Stage everything and re-run the two greps above** — expect empty output (excluding `kiroHooks` false positives and comment/doc mentions, which must be individually justified in the Task 9 audit notes).

### Task 6: agent-chat — remove the remote model catalog

**Files:**
- Modify: `agent-chat/catalog.ts`, `agent-chat/README.md`
- Possibly modify: `agent-chat/server.ts` (only if the compile/typecheck breaks; the public store API is preserved)
- Test: agent-chat's existing test suite (`cd agent-chat && bun test`), plus the catalog tests it ships — rewrite fetch-dependent cases to construct the store and assert local-only behavior.

**Interfaces:**
- Consumes: upstream `agent-chat/` as merged in Task 2 (no conflicts expected in it).
- Produces: `AgentModelCatalogStore` with the same public members used by `server.ts` (`payload`, `hasPayload`, `provider(id)`, `subscribe(listener)`, `refreshIfStale()`, `refresh()`, exported instance `agentModelCatalog`, `AGENT_MODEL_CATALOG_TTL_MS`) but zero network I/O.

- [ ] **Step 1: Locate current usage (verify the interface contract)**

```bash
grep -n "agentModelCatalog\|AgentModelCatalogStore\|CMUX_AGENT_MODELS_URL" agent-chat/*.ts agent-chat/src/*.ts* | grep -v test
```

Expected: `server.ts:19` import; a background `applyAgentModelCatalog()` call near `server.ts:1862`; no other non-test consumers. If more appear, extend Step 3 to keep those members too.

- [ ] **Step 2: Replace the store class in `agent-chat/catalog.ts`**

Delete `PersistedCatalog`, `CatalogStoreOptions`, `DEFAULT_URL`, `DEFAULT_CACHE`, the `AgentModelCatalogStore` class body, and the fs/env plumbing; keep all exported interfaces, `validateAgentModelCatalog`, `mergeCatalogModels`, `selectEnabledModel`, and `AGENT_MODEL_CATALOG_TTL_MS`. Replace the class with:

```typescript
// zerocmux: the upstream store fetched https://cmux.com/api/agent-models with
// ETag revalidation and an on-disk cache. zerocmux ships no remote catalog:
// models come from the built-in lists plus models reported by installed agent
// CLIs (mergeCatalogModels). The store keeps its upstream surface so server.ts
// is unchanged, but it never performs network or file I/O.
export class AgentModelCatalogStore {
  private state: AgentModelCatalogPayload | null = null;
  private listeners = new Set<(payload: AgentModelCatalogPayload) => void>();

  get payload(): AgentModelCatalogPayload | null { return this.state; }
  get hasPayload(): boolean { return this.state !== null; }
  provider(id: string): AgentModelProviderCatalog | undefined {
    return this.state?.providers[id as keyof AgentModelCatalogPayload["providers"]];
  }
  subscribe(listener: (payload: AgentModelCatalogPayload) => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }
  /** Local-only: apply a caller-supplied payload (e.g. tests, future local config). */
  apply(input: unknown): boolean {
    const payload = validateAgentModelCatalog(input);
    const changed = JSON.stringify(payload) !== JSON.stringify(this.state);
    this.state = payload;
    if (changed) for (const listener of this.listeners) listener(payload);
    return changed;
  }
  isStale(): boolean { return false; }
  refreshIfStale(): Promise<boolean> { return Promise.resolve(false); }
  refresh(): Promise<boolean> { return Promise.resolve(false); }
}

export const agentModelCatalog = new AgentModelCatalogStore();
```

Remove now-unused imports (`homedir`, `existsSync`, `readFileSync`, `mkdir`, `writeFile`, `rename`, `dirname`, `join`, `basename`) — keep any still used by other functions in the file.

- [ ] **Step 3: Update `agent-chat/README.md`** — replace the "Model catalog" paragraph with: models come from built-in lists plus models reported by installed provider CLIs; zerocmux performs no remote catalog fetch.

- [ ] **Step 4: Typecheck, test, verify no-network**

```bash
cd agent-chat && bun install && bunx tsc --noEmit 2>/dev/null || bun build server.ts --target=bun >/dev/null; bun test; cd ..
grep -rn "cmux\.com\|cmux\.dev\|CMUX_AGENT_MODELS_URL" agent-chat --include='*.ts' --include='*.tsx' | grep -v test | grep -v fixtures
# expect: no hits (gallery-fixtures.ts sample-text link is allowed; keep it out via the fixtures filter, note it in audit)
```

Rewrite fetch-dependent catalog tests against `store.apply(payload)`; delete tests that exist solely to test HTTP/ETag/cache behavior. If bun is unavailable on this machine, record that and defer test execution to CI (do not skip the greps).

- [ ] **Step 5: Stage** — `git add agent-chat`.

### Task 7: Submodules — ghostty + bonsplit pointer sync

**Files:**
- Modify: gitlinks `ghostty`, `vendor/bonsplit`; `scripts/ghosttykit-checksums.txt`

**Interfaces:**
- Produces: submodule pointers at upstream's SHAs (or a fork-pushed descendant of ghostty's), both reachable from their remotes; consumed by Task 10 builds.

- [ ] **Step 1: Fetch and identify the crash-report override commit**

```bash
cd ghostty && git fetch origin && git log --oneline -15 541e5e89db0448d5cd85a7b348d8f6a64618c900 | grep -i "crash\|report\|subdir"
```

Record the override commit SHA `<OVR>` (message per prior merge: crash-report-subdir override). Also consult `docs/ghostty-fork.md` which documents fork changes.

- [ ] **Step 2: Check ancestry in the new pointer**

```bash
git merge-base --is-ancestor <OVR> bb30526cdab8f5fb08ae43e404e3aacc40d3ffc3 && echo CONTAINED || echo MISSING
```

- If CONTAINED: `git checkout bb30526cdab8f5fb08ae43e404e3aacc40d3ffc3`.
- If MISSING: `git checkout -b zerocmux-sync-2026-07 bb30526cd… && git cherry-pick <OVR>`, then push to the submodule remote and verify reachability BEFORE the parent commit: `git push origin zerocmux-sync-2026-07` and confirm `git merge-base --is-ancestor HEAD origin/zerocmux-sync-2026-07`. If the fork lacks push rights to `manaflow-ai/ghostty`, STOP and ask the user (a fork-owned ghostty remote is a scope decision).

```bash
cd .. && git add ghostty
```

- [ ] **Step 3: bonsplit pointer**

```bash
cd vendor/bonsplit && git fetch origin && git checkout 10563e2fda6fc18c47adf1864d55e0e25087a864 && git merge-base --is-ancestor HEAD origin/main && echo OK
cd ../.. && git add vendor/bonsplit
# expect: OK
```

- [ ] **Step 4: GhosttyKit rebuild** — attempt locally, fall back to CI:

```bash
cd ghostty && zig build -Demit-xcframework=true -Dxcframework-target=universal -Doptimize=ReleaseFast && cd ..
```

If zig cannot link on this host (known issue on macOS 26 per prior merge), leave the checksums file as-is with a `# regenerated by build-ghosttykit workflow post-merge` note, and run the `build-ghosttykit.yml` workflow after push (Task 11). If the local build succeeds, regenerate `scripts/ghosttykit-checksums.txt` the same way fork commit `a9e8a9eab` did (see `git show a9e8a9eab` for format) and `git add` it.

### Task 8: cmux-tui adoption + CI lane

**Files:**
- Modify: `.github/workflows/cmux-tui.yml` (runner labels), staged as part of the merge.

**Interfaces:**
- Consumes: `cmux-tui/` merged cleanly in Task 2; ghostty submodule from Task 7.
- Produces: building cmux-tui workspace + a CI lane on fork runners.

- [ ] **Step 1: Verify no-phone-home (audit preview)**

```bash
grep -rniE "https?://" cmux-tui/crates cmux-tui/frontends --include='*.rs' | grep -viE "localhost|127\.0\.0\.1|\.test|example|doc|license"
# expect: only cmux-tui-core/src/browser.rs google.com/search?q= (user-typed URL-bar search default — user-initiated browsing, justified in audit)
```

- [ ] **Step 2: Adapt `cmux-tui.yml` runners** — edit `runs-on:` entries to the fork's runner set (match what fork's `ci.yml` uses — Blacksmith/GitHub-hosted labels; read fork `ci.yml` for the exact strings). Remove any upload/publish steps (artifacts to external stores) if present; keep build+test. `git add .github/workflows/cmux-tui.yml`.

- [ ] **Step 3: Local build proof**

```bash
cd cmux-tui && cargo build -p cmux-tui 2>&1 | tail -3 && cd ..
# expect: "Finished" line. Needs zig 0.15.2 + Rust toolchain; if zig linking fails on this host, defer to the CI lane and record it.
```

### Task 9: Telemetry audit gate (hard gate)

**Files:**
- Create: `$SCRATCH/audit-notes.md` (findings; pasted into the PR description in Task 11)

**Interfaces:**
- Consumes: fully staged merge tree.
- Produces: audit-notes.md where every grep hit is dispositioned (excluded-path/comment-only/justified). PR cannot go ready-for-review without this.

- [ ] **Step 1: Excluded trees are gone**

```bash
for p in web workers ios services vault .asc Packages/iOS Packages/Shared Sources/Mobile .vercelignore homebrew-cmux; do git ls-files --error-unmatch "$p" 2>/dev/null && echo "FAIL: $p present"; done
# expect: no FAIL lines
ls README.*.md 2>/dev/null; # expect: no such files
```

- [ ] **Step 2: Endpoint/SDK greps over the staged tree**

```bash
git grep -inE "posthog|sentry|stackauth|sendAnonymousTelemetry" -- ':!ghostty' ':!vendor' > $SCRATCH/audit-1.txt
git grep -inE "cmux\.com|cmux\.dev|manaflow" -- ':!ghostty' ':!vendor' ':!docs/superpowers' ':!CHANGELOG.md' > $SCRATCH/audit-2.txt
git grep -inE "iroh" -- ':!ghostty' ':!vendor' | grep -vi kiroHooks > $SCRATCH/audit-3.txt
git grep -inE "appcast|SUFeedURL" -- Resources Packages Sources > $SCRATCH/audit-4.txt
wc -l $SCRATCH/audit-*.txt
```

Disposition every line in `$SCRATCH/audit-notes.md`. Allowed categories only: (a) comments/docs/test fixtures with no runtime effect; (b) fork's own release URLs (`Enigma-Labs-Technology/zerocmux`); (c) upstream attribution in licenses/readmes. Anything else = fix before proceeding. audit-4 must show ONLY the fork appcast URL.

- [ ] **Step 3: SPM dependency audit**

```bash
git grep -in "posthog\|sentry\|stack-auth\|stackauth" -- '**/Package.swift' 'cmux.xcodeproj/project.pbxproj' '**/Package.resolved'; # expect: empty
```

- [ ] **Step 4: Loopback-only check for sidecars** — confirm `agent-chat/server.ts` binds `127.0.0.1` (grep `serve(` / `hostname`) and Task 6 Step 4 grep is still clean; cmux-tui per Task 8 Step 1. Record in notes.

### Task 10: Build verification and the merge commit

**Interfaces:**
- Consumes: fully resolved, scrubbed, audited index.
- Produces: the policy merge commit on `merge/upstream-2026-07-16`.

- [ ] **Step 1: Swift package sweep**

```bash
for d in Packages/macOS/*/Package.swift; do p=$(dirname $d); echo "== $p"; swift build --package-path $p 2>&1 | tail -1; done
# expect: "Build complete!" for every package; fix compile fallout (usually Task 5 scrub leftovers) before continuing
```

- [ ] **Step 2: Resolve Package.resolved + app compile check**

```bash
xcodebuild -project cmux.xcodeproj -scheme zerocmux -resolvePackageDependencies -derivedDataPath /tmp/zerocmux-upstream-sync-2026-07
git add cmux.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
xcodebuild -project cmux.xcodeproj -scheme zerocmux -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/zerocmux-upstream-sync-2026-07 build 2>&1 | tail -5
# expect: BUILD SUCCEEDED (requires GhosttyKit from Task 7; if deferred to CI, run the compile check in CI instead and say so)
```

- [ ] **Step 3: Re-verify audit greps still pass** (Task 9 Steps 2–3 commands; build fixes can reintroduce references).

- [ ] **Step 4: Commit the merge** with this message (adjust counts only if refs changed):

```
Merge upstream cmux (manaflow-ai/cmux@a5a70ff906) with zero-telemetry policy

Sync 1,140 upstream commits (Jul 1 – Jul 16) into zerocmux while preserving
the fork's privacy posture: no automatic network egress except Sparkle
updates from the zerocmux GitHub releases and the user-configured CmuxGit
GitHub probe.

Excluded hosted/telemetry surfaces new in this window:
- CmuxIrohTransport (p2p relay transport; consumed only by the excluded
  iOS app and Sources/Mobile host) and services/iroh-relay-minter
- vault/ cloud transcript sync (Stack Auth device login + S3 upload)
- iOS/TestFlight/App Store lanes (.asc/, ios-*.yml), web/ and workers/
  growth, presence/docs-deploy/SDK-publish/tui-publish workflows
- agent-chat remote model catalog (cmux.com/api/agent-models fetch, ETag
  cache, CMUX_AGENT_MODELS_URL) — sidecar kept fully local

Adopted local-first additions: cmux-tui (Rust TUI multiplexer, local
socket only), agent-chat loopback sidecar, Native/DiffSidecar Rust diff
backend, GPL corresponding-source bundling (repointed to this fork), and
all Sources/Packages/CLI/daemon/test improvements. GitHub-API integration
kept with upstream's unauthenticated-polling fix.

Submodules: ghostty -> <final SHA>, vendor/bonsplit -> 10563e2fd;
homebrew-cmux remains excluded. Fork identity preserved (bundle IDs,
sockets, appcast, AWS-OIDC release pipeline, 1.2.1/89).

Spec: docs/superpowers/specs/2026-07-16-upstream-sync-zero-telemetry-design.md

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
```

```bash
git commit -F <message file>; git log -1 --format='%h %s'; git status --porcelain | head
# expect: merge commit created; status clean (or only untracked scratch)
```

### Task 11: PR, CI fixups, docs

**Files:**
- Modify: `CHANGELOG.md`, `CLAUDE.md` (fork docs notes)

**Interfaces:**
- Consumes: the merge commit.
- Produces: a green PR against `main`.

- [ ] **Step 1: CHANGELOG + doc notes commit** — add a CHANGELOG "Unreleased" entry summarizing the sync; add CLAUDE.md layout notes: `cmux-tui/` (local Rust TUI), `agent-chat/` (loopback sidecar, no remote catalog), and the vault naming note ("upstream `vault/` cloud sync is excluded; the fork's `CMUXAgentVault`/`VaultAgentRegistry` are unrelated local features"). Commit.

- [ ] **Step 2: Push and open a draft PR**

```bash
git push -u origin merge/upstream-2026-07-16
gh pr create --repo Enigma-Labs-Technology/zerocmux --draft --title "Merge upstream cmux a5a70ff906 with zero-telemetry policy" --body-file <body with audit notes from $SCRATCH/audit-notes.md>
```

PR body ends with: `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.

- [ ] **Step 3: If GhosttyKit was deferred: run `gh workflow run build-ghosttykit.yml`**, wait, update `scripts/ghosttykit-checksums.txt` from its output, commit.

- [ ] **Step 4: Watch CI; land fixups as follow-up commits**

```bash
gh pr checks --watch
```

Expected failure classes (from last sync's 20 fixups): runner labels, guard scripts (`test_ci_self_hosted_guard.sh`, change-area expectations), generated asset drift, phantom SPM refs, warning budgets (`.github/swift-file-length-budget.tsv` conflicts were resolved in Task 4f — budgets may need bumps for grown files). One fixup commit per failure class, referencing the failing job. Iterate until green, then mark the PR ready for review. Do NOT merge the PR without the user's go-ahead.

---

## Self-review notes

- Spec coverage: exclusions (Tasks 2, 5, 9), inclusions cmux-tui/agent-chat/DiffSidecar/GPL/GitHub-fixes (Tasks 8, 6, 2, 3, 4b), merge mechanics + submodule safety (Tasks 2–4, 7), audit gate (Task 9), build/test verification (Tasks 10, 11), deliverable PR + docs (Task 11), error handling (Task 4 procedure, Task 7 MISSING branch, Task 6 bun-unavailable branch). No gaps found.
- The 177-file resolution cannot enumerate final code per file; the plan pins the per-file discovery commands (`git log/diff` against merge-base and fork main) and per-group verification gates instead. This is deliberate, not a placeholder.
- Type consistency: the Task 6 store keeps exactly the members `server.ts` consumes (verified against upstream `server.ts:19,1862` and `catalog.ts:152-238`).
