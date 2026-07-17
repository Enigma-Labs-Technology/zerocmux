# CI runners

Always-on CI runs on Blacksmith and GitHub-hosted runners only. Linux jobs use
`blacksmith-4vcpu-ubuntu-2404`; macOS jobs use `blacksmith-6vcpu-macos-15` for
the Xcode/SDK 15 lanes and `blacksmith-6vcpu-macos-26` for the macOS 26 lanes
(`release-build` in `ci.yml`, release signing in `release.yml`). The manual
`ci-macos-compat.yml` matrix additionally exercises the GitHub-hosted
`macos-14-large` and `macos-26` runners, and `cmux-tui.yml` uses GitHub-hosted
`ubuntu-latest` and `windows-latest` rows in its matrix. We accept the
occasional sub-minute Blacksmith queue rather than overflowing elsewhere:
`warp-*` and `depot-*` labels are never used for always-on lanes and remain
manual break-glass or `workflow_dispatch` choices only.

A few lanes route through repository variables so a runner type can be
switched with a single variable update that takes effect on the next workflow
run, with no PR or commit:

| Variable | Used by | Fallback baked into the workflow |
| ------------------- | ---------------------------------------------------------- | -------------------------------- |
| `LINUX_RUNNER`      | `ci.yml` `linux-preflight` and the `cmux-tui.yml` Linux lanes | `blacksmith-4vcpu-ubuntu-2404`   |
| `MACOS_RUNNER_15`   | manual `test-e2e.yml` / `perf-activation.yml` `auto` runs; the `cmux-tui.yml` macOS row | GitHub-hosted `macos-15` (manual workflows) / `blacksmith-6vcpu-macos-15` (`cmux-tui.yml`) |
| `MACOS_RUNNER_DUAL_XCODE` | `ci.yml` `swift-package-tests` (builds the SDK 15 Ghostty CLI helper, then runs the SDK 26 package tests in the same job) | `blacksmith-6vcpu-macos-15` |

Workflows reference them as
`runs-on: ${{ vars.LINUX_RUNNER || 'blacksmith-4vcpu-ubuntu-2404' }}`. If a
variable is unset the job uses the fallback, so CI is never broken by a missing
variable.

The remaining `ci.yml` jobs are deliberately hard-pinned to Blacksmith labels:
`workflow-guard-tests`, `app-host-unit-tests`, `tests-build-and-lag`, and the
separate `ui-regressions` job on `blacksmith-6vcpu-macos-15`; `release-build`
on `blacksmith-6vcpu-macos-26`; and the Linux jobs (`changes`,
`remote-daemon-tests`, `react-apps-check`, `diff-sidecar-check`, `tests`,
`agent-session-web-resources`, `ci-status`) on
`blacksmith-4vcpu-ubuntu-2404`. There is no standalone
`release-ghostty-cli-helper` job in `ci.yml` — the Ghostty CLI helper is built
inside `swift-package-tests` there, and by `build-ghostty-cli-helper` in
`release.yml`.

## Break-glass: switch a runner type off Blacksmith

We do not auto-overflow. If Blacksmith is genuinely down or queuing for minutes
(not the sub-minute queue we accept by default), manually flip the affected
variable to an explicit cloud label; revert it once Blacksmith recovers. Use
Blacksmith (default):

```bash
gh variable set LINUX_RUNNER            --repo kernelalex/zerocmux -b blacksmith-4vcpu-ubuntu-2404
gh variable set MACOS_RUNNER_15         --repo kernelalex/zerocmux -b blacksmith-6vcpu-macos-15
gh variable set MACOS_RUNNER_DUAL_XCODE --repo kernelalex/zerocmux -b blacksmith-6vcpu-macos-15
```

Break-glass a type to WarpBuild or Depot only when Blacksmith is down or
queuing for minutes (as happened for macOS in
https://github.com/kernelalex/zerocmux/pull/4926). **Set an explicit cloud
label.** Never set any runner variable to a fleet/self-hosted label.

```bash
gh variable set LINUX_RUNNER    --repo kernelalex/zerocmux -b warp-ubuntu-latest-x64-4x
gh variable set MACOS_RUNNER_15 --repo kernelalex/zerocmux -b warp-macos-15-arm64-6x
# or a GUI-capable cloud runner:
gh variable set MACOS_RUNNER_15 --repo kernelalex/zerocmux -b depot-macos-latest
```

Check current values:

```bash
gh variable list --repo kernelalex/zerocmux
```

## Manual runs

`perf-activation.yml` and `test-e2e.yml` keep a `runner` choice input that
defaults to `auto`. Manual `auto` runs follow `MACOS_RUNNER_15` then the
GitHub-hosted `macos-15` fallback, so flipping the repo variable redirects
those workflows. An explicit manual choice wins over the variable; both
dropdowns expose Blacksmith, Warp, and `depot-macos-*` choices, with a Depot
identity guard for GUI-activation runs. `test-e2e.yml` also exposes
`tart-canary`, `tart-dual`, and `tart-small` for targeted isolated-VM
validation. These choices are available only through `workflow_dispatch`;
no always-on lane uses them.

## Guard

`tests/test_ci_self_hosted_guard.sh` (run by the `workflow-guard-tests` job)
pins the expensive macOS lanes to the sanctioned Blacksmith runners:
`app-host-unit-tests`, `tests-build-and-lag`, and `ui-regressions` in `ci.yml`,
`build-ghosttykit` in `build-ghosttykit.yml`, the Blacksmith row of the
`ci-macos-compat.yml` matrix, and `build-ghostty-cli-helper` in `release.yml`
on `blacksmith-6vcpu-macos-15`, plus `release-build` in `ci.yml` and
`build-sign-notarize` in `release.yml` on `blacksmith-6vcpu-macos-26`. It also
fails CI if any always-on workflow
hardcodes a `warp-*` or `depot-*` runner label — those providers stay manual
break-glass only. Keep new labels in `.github/actionlint.yaml`.

## No self-hosted mac-mini fleet in CI

We do not route CI to the persistent self-hosted mac-mini fleet
(`zerocmux-mac-mini`, `studio1`, `mac4-cmuxvnc*`, `zerocmux-austin-mini-*`) for
any job. Those minis carry labels that collide with cloud labels (notably
`macos-26` and `warp-macos-26-arm64-6x`), and GitHub prefers a matching
self-hosted runner, so a required job could silently land on a mini that cannot
foreground a GUI app. It stays `Running Background`, breaking key-window,
pasteboard, IME, and XCUITest behavior. Every macOS lane therefore routes to
Blacksmith or a GitHub-hosted runner, and the guard above fails CI if an
always-on workflow hardcodes a third-party self-hosted-colliding label.

Residual: the guard checks workflow literals, not repo-variable values. Do not
set `MACOS_RUNNER_*` / `LINUX_RUNNER` to a self-hosted label; keep them on
Blacksmith. Fully closing the variable-value path requires removing the
colliding labels from the minis (runner-side, needs org/runner admin).
