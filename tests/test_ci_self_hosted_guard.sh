#!/usr/bin/env bash
# Pins macOS jobs to the ephemeral self-hosted Tart pool and rejects cloud
# provider labels. Linux jobs use self-contained RunsOn Flex labels.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CI_FILE="$ROOT_DIR/.github/workflows/ci.yml"
GHOSTTYKIT_FILE="$ROOT_DIR/.github/workflows/build-ghosttykit.yml"
COMPAT_FILE="$ROOT_DIR/.github/workflows/ci-macos-compat.yml"
E2E_FILE="$ROOT_DIR/.github/workflows/test-e2e.yml"
TMUX_CORPUS_FILE="$ROOT_DIR/.github/workflows/tmux-corpus.yml"
IOS_FILE="$ROOT_DIR/.github/workflows/test-ios.yml"
CLA_GUARD_FILE="$ROOT_DIR/.github/workflows/cla-policy-guard.yml"

check_cla_guard_runner() {
  if ! grep -Fqx '    runs-on: ubuntu-24.04' "$CLA_GUARD_FILE"; then
    echo "FAIL: cla-policy-guard.yml must use the fixed GitHub-hosted ubuntu-24.04 runner"
    exit 1
  fi

  if grep -Eq '^    runs-on:.*(vars\.LINUX_RUNNER|blacksmith-|self-hosted)' "$CLA_GUARD_FILE"; then
    echo "FAIL: cla-policy-guard.yml must not allow a variable or self-hosted runner override"
    exit 1
  fi

  echo "PASS: CLA policy guard uses the fixed GitHub-hosted runner"
}

check_runner() {
  local file="$1" job="$2" pattern="$3" description="$4"
  local job_body
  job_body="$(awk -v job="$job" '
    $0 ~ "^  "job":" { in_job=1; next }
    in_job && /^  [^[:space:]]/ { in_job=0 }
    in_job { print }
  ' "$file")"
  if ! grep -Eq "$pattern" <<<"$job_body"; then
    echo "FAIL: $job in $(basename "$file") must use $description"
    exit 1
  fi
  echo "PASS: $job uses $description"
}

if grep -R -n -E 'depot-|Depot' "$WORKFLOW_DIR"; then
  echo "FAIL: workflows must not reference Depot after the RunsOn migration"
  exit 1
fi

if grep -R -n -E 'runs-on:.*(macos-(latest|[0-9]+)|warp-macos|blacksmith-)|os: (macos-(latest|[0-9]+)|warp-macos|blacksmith-)' "$WORKFLOW_DIR"; then
  echo "FAIL: macOS workflows must route through the Tart self-hosted pool"
  exit 1
fi

if grep -R -n -E 'runs-on:.*(extras=.*otel|/otel([/+]|$))' "$WORKFLOW_DIR"; then
  echo "FAIL: RunsOn labels must not enable OTEL telemetry"
  exit 1
fi
printf '%s\n' "$@" > "$CMUX_WEB_TEST_RUNNER_ARGS_LOG"
EOF
  chmod +x "$fixture_dir/bin/bun"

  if ! PATH="$fixture_dir/bin:/usr/bin:/bin" \
    CMUX_WEB_TEST_RUNNER_ARGS_LOG="$args_log" \
    /bin/bash "$fixture_runner"; then
    rm -rf "$fixture_dir"
    echo "FAIL: shared web test runner default discovery should execute"
    exit 1
  fi

  expected_args=$'test\n--isolate\n./scripts/alpha_spec.mts\n./tests/beta.test.ts\n./tests/nested/gamma_test.tsx\n./tests/nested/omega.spec.mjs'
  if [[ "$(cat "$args_log")" != "$expected_args" ]]; then
    echo "FAIL: shared web test runner must sort recursive Bun test patterns and exclude hidden dependencies"
    cat "$args_log"
    rm -rf "$fixture_dir"
    exit 1
  fi

  if PATH="$fixture_dir/bin:/usr/bin:/bin" \
    CMUX_WEB_TEST_RUNNER_ARGS_LOG="$args_log" \
    CMUX_WEB_TEST_RUNNER_BUN_VERSION="1.2.14" \
    /bin/bash "$fixture_runner" >/dev/null 2>&1; then
    echo "FAIL: shared web test runner must reject Bun versions with process-global mock leakage"
    rm -rf "$fixture_dir"
    exit 1
  fi

  if PATH="$fixture_dir/bin:/usr/bin:/bin" \
    CMUX_WEB_TEST_RUNNER_ARGS_LOG="$args_log" \
    CMUX_WEB_TEST_RUNNER_BUN_VERSION="1.3.13" \
    /bin/bash "$fixture_runner" >/dev/null 2>&1; then
    echo "FAIL: shared web test runner must enforce the patch-level Bun isolation boundary"
    rm -rf "$fixture_dir"
    exit 1
  fi

  if ! PATH="$fixture_dir/bin:/usr/bin:/bin" \
    CMUX_WEB_TEST_RUNNER_ARGS_LOG="$args_log" \
    /bin/bash "$fixture_runner" \
    --coverage -t "fixture runs" --bail=2 --parallel=2; then
    rm -rf "$fixture_dir"
    echo "FAIL: shared web test runner option-only discovery should execute"
    exit 1
  fi
  expected_args+=$'\n--coverage\n-t\nfixture runs\n--bail=2\n--parallel=2'
  if [[ "$(cat "$args_log")" != "$expected_args" ]]; then
    echo "FAIL: option-only runs must retain sorted discovery before forwarding options"
    cat "$args_log"
    rm -rf "$fixture_dir"
    exit 1
  fi

  if ! PATH="$fixture_dir/bin:/usr/bin:/bin" \
    CMUX_WEB_TEST_RUNNER_ARGS_LOG="$args_log" \
    /bin/bash "$fixture_runner" --changed=main; then
    rm -rf "$fixture_dir"
    echo "FAIL: shared web test runner changed-file discovery should execute"
    exit 1
  fi
  expected_args=$'test\n--isolate\n--changed=main'
  if [[ "$(cat "$args_log")" != "$expected_args" ]]; then
    echo "FAIL: changed-file selection must retain Bun-owned discovery"
    cat "$args_log"
    rm -rf "$fixture_dir"
    exit 1
  fi

  if ! PATH="$fixture_dir/bin:/usr/bin:/bin" \
    CMUX_WEB_TEST_RUNNER_ARGS_LOG="$args_log" \
    /bin/bash "$fixture_runner" tests/beta; then
    rm -rf "$fixture_dir"
    echo "FAIL: shared web test runner explicit filter should execute"
    exit 1
  fi
  expected_args=$'test\n--isolate\ntests/beta'
  if [[ "$(cat "$args_log")" != "$expected_args" ]]; then
    echo "FAIL: explicit test filters must remain scoped instead of expanding to every test"
    cat "$args_log"
    rm -rf "$fixture_dir"
    exit 1
  fi

  if ! PATH="$fixture_dir/bin:/usr/bin:/bin" \
    CMUX_WEB_TEST_RUNNER_ARGS_LOG="$args_log" \
    /bin/bash "$fixture_runner" --bail tests/beta; then
    rm -rf "$fixture_dir"
    echo "FAIL: shared web test runner optional flag plus filter should execute"
    exit 1
  fi
  expected_args=$'test\n--isolate\n--bail\ntests/beta'
  if [[ "$(cat "$args_log")" != "$expected_args" ]]; then
    echo "FAIL: optional-valued flags must not consume a following test filter"
    cat "$args_log"
    rm -rf "$fixture_dir"
    exit 1
  fi

  for live_mode in --watch --hot; do
    if ! PATH="$fixture_dir/bin:/usr/bin:/bin" \
      CMUX_WEB_TEST_RUNNER_ARGS_LOG="$args_log" \
      /bin/bash "$fixture_runner" "$live_mode"; then
      rm -rf "$fixture_dir"
      echo "FAIL: shared web test runner $live_mode mode should execute"
      exit 1
    fi
    expected_args=$'test\n--isolate\n'"$live_mode"
    if [[ "$(cat "$args_log")" != "$expected_args" ]]; then
      echo "FAIL: $live_mode mode must delegate live test discovery to Bun"
      cat "$args_log"
      rm -rf "$fixture_dir"
      exit 1
    fi
  done

  cat > "$fixture_dir/web/bunfig.toml" <<'EOF'
[test]
root = "tests"
EOF
  if ! PATH="$fixture_dir/bin:/usr/bin:/bin" \
    CMUX_WEB_TEST_RUNNER_ARGS_LOG="$args_log" \
    /bin/bash "$fixture_runner"; then
    rm -rf "$fixture_dir"
    echo "FAIL: shared web test runner configured-root discovery should execute"
    exit 1
  fi
  expected_args=$'test\n--isolate'
  if [[ "$(cat "$args_log")" != "$expected_args" ]]; then
    echo "FAIL: default root-bearing Bun config must retain Bun-owned discovery"
    cat "$args_log"
    rm -rf "$fixture_dir"
    exit 1
  fi
  rm -f "$fixture_dir/web/bunfig.toml"

  if ! PATH="$fixture_dir/bin:/usr/bin:/bin" \
    CMUX_WEB_TEST_RUNNER_ARGS_LOG="$args_log" \
    /bin/bash "$fixture_runner" --config=ci.bunfig.toml; then
    rm -rf "$fixture_dir"
    echo "FAIL: shared web test runner alternate-config discovery should execute"
    exit 1
  fi
  expected_args=$'test\n--isolate\n--config=ci.bunfig.toml'
  if [[ "$(cat "$args_log")" != "$expected_args" ]]; then
    echo "FAIL: alternate Bun configs must retain Bun-owned discovery"
    cat "$args_log"
    rm -rf "$fixture_dir"
    exit 1
  fi

  cat > "$fixture_dir/bin/find" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "./tests/beta.test.ts"
exit 1
EOF
  chmod +x "$fixture_dir/bin/find"
  rm -f "$args_log"
  if PATH="$fixture_dir/bin:/usr/bin:/bin" \
    CMUX_WEB_TEST_RUNNER_ARGS_LOG="$args_log" \
    /bin/bash "$fixture_runner" \
    >"$fixture_dir/discovery.stdout" 2>"$fixture_dir/discovery.stderr"; then
    echo "FAIL: shared web test runner must reject partial discovery results"
    rm -rf "$fixture_dir"
    exit 1
  fi
  if ! grep -Fq "Web test discovery failed" "$fixture_dir/discovery.stderr"; then
    echo "FAIL: shared web test runner must explain discovery failures"
    cat "$fixture_dir/discovery.stderr"
    rm -rf "$fixture_dir"
    exit 1
  fi
  if [[ -e "$args_log" ]]; then
    echo "FAIL: shared web test runner must not execute Bun after discovery fails"
    cat "$args_log"
    rm -rf "$fixture_dir"
    exit 1
  fi
  rm -f "$fixture_dir/bin/find"

  mkdir -p "$fixture_dir/empty/scripts"
  cp "$ROOT_DIR/web/scripts/run-tests.sh" "$fixture_dir/empty/scripts/run-tests.sh"
  if ! PATH="$fixture_dir/bin:/usr/bin:/bin" \
    CMUX_WEB_TEST_RUNNER_ARGS_LOG="$args_log" \
    /bin/bash "$fixture_dir/empty/scripts/run-tests.sh" \
    --pass-with-no-tests; then
    rm -rf "$fixture_dir"
    echo "FAIL: shared web test runner must honor --pass-with-no-tests"
    exit 1
  fi
  expected_args=$'test\n--isolate\n--pass-with-no-tests'
  if [[ "$(cat "$args_log")" != "$expected_args" ]]; then
    echo "FAIL: --pass-with-no-tests must retain Bun-owned empty discovery"
    cat "$args_log"
    rm -rf "$fixture_dir"
    exit 1
  fi

  if PATH="$fixture_dir/bin:/usr/bin:/bin" \
    CMUX_WEB_TEST_RUNNER_ARGS_LOG="$args_log" \
    /bin/bash "$fixture_dir/empty/scripts/run-tests.sh" \
    >"$fixture_dir/empty.stdout" 2>"$fixture_dir/empty.stderr"; then
    rm -rf "$fixture_dir"
    echo "FAIL: shared web test runner must fail when no tests exist"
    exit 1
  fi
  if ! grep -Fq "No web test files found" "$fixture_dir/empty.stderr"; then
    echo "FAIL: shared web test runner must explain an empty test suite"
    cat "$fixture_dir/empty.stderr"
    rm -rf "$fixture_dir"
    exit 1
  fi

  rm -rf "$fixture_dir"
  trap - EXIT
  echo "PASS: shared web test runner sorts recursive discovery and fails closed when empty"
}

check_tmux_terminal_nightly_isolation() {
  check_macos_runner "$TMUX_CORPUS_FILE" "terminal-nightly"

  if ! awk '
    /^  terminal-nightly:/ { in_job=1; next }
    in_job && /^  [^[:space:]#][^:]*:[[:space:]]*(#.*)?$/ { in_job=0 }
    in_job && /CMUX_DERIVED_DATA_PATH/ { saw_env=1 }
    in_job && /-derivedDataPath "\$CMUX_DERIVED_DATA_PATH"/ { saw_flag=1 }
    in_job && /scripts\/ci\/xcodebuild_noninteractive\.py/ { saw_noninteractive=1 }
    in_job && /SWIFT_BACKTRACE: "interactive=no,timeout=0s,symbolicate=off,color=no"/ { saw_backtrace=1 }
    in_job && /All failures are expected, treating as pass/ { saw_expected_failure_handling=1 }
    END { exit !(saw_env && saw_flag && saw_noninteractive && saw_backtrace && saw_expected_failure_handling) }
  ' "$TMUX_CORPUS_FILE"; then
    echo "FAIL: tmux corpus terminal-nightly must use isolated DerivedData, the noninteractive xcodebuild wrapper, and expected-failure handling"
    exit 1
  fi

  echo "PASS: tmux corpus terminal-nightly uses isolated DerivedData, noninteractive xcodebuild, and expected-failure handling"
}

check_no_bare_github_hosted_runners() {
  # Every product CI job must route its runner through a repo variable (LINUX_RUNNER,
  # MACOS_RUNNER_*) so the Blacksmith<->Warp / Blacksmith<->macos-26 overflow
  # switch is a single repo-variable flip with no PR. A bare GitHub-hosted
  # label (ubuntu-*, macos-NN) cannot be redirected, so it is forbidden.
  # The CLA policy guard is a separate immutable control-plane job and is
  # intentionally exempted below because it must never honor a repository
  # variable or self-hosted runner override.
  # Bare paid-provider labels (blacksmith-*, warp-*, depot-*) stay allowed for
  # deliberate single-runner pins such as the testmanagerd-wedged
  # `app-host-unit-tests` job.
  local hits
  # cla-policy-guard.yml and web-complexity-trusted.yml are control-plane
  # workflows. They deliberately run on GitHub-hosted ephemeral runners so
  # untrusted policy/source bytes cannot redirect execution to a persistent
  # or contributor-controlled machine. Exempt both files here instead.
  hits="$(grep -rnE "runs-on:[[:space:]]*(ubuntu-[a-z0-9.]+|macos-[a-z0-9]+)([[:space:]]*$|[[:space:]]+#)" "$ROOT_DIR/.github/workflows" | grep -v "github-hosted-required" | grep -v "/cla-policy-guard.yml:" | grep -v "/web-complexity-trusted.yml:" || true)"
  if [[ -n "$hits" ]]; then
    echo "FAIL: these jobs use a bare GitHub-hosted runner; route them through vars.LINUX_RUNNER / vars.MACOS_RUNNER_IOS so Blacksmith<->overflow stays a repo-variable flip:"
    echo "$hits"
    exit 1
  fi
  echo "PASS: no workflow pins a bare GitHub-hosted runner; all route through runner repo variables"
}

check_no_self_hosted_fleet_runners() {
  # Required jobs route through repository variables. Forbid hardcoded fleet
  # labels so Tart cutover and paid-provider fallback remain configuration
  # changes and a physical host label cannot bypass the isolated VM pool.
  # Allowed macOS labels (none carried by any fleet runner):
  #   blacksmith-{6,12}vcpu-macos-{15,26,latest}, warp-macos-15-arm64-6x,
  #   depot-macos-{latest,14}.
  # NOTE: reload-build.yml is the dev-build offload path (workflow_dispatch,
  # not required CI) and intentionally targets the fleet via a free-form input;
  # this guard only inspects runner-selection lines, not its input description.
  local fleet='macos-26|warp-macos-26-arm64-6x|cmux-aws-macos|zerocmux-macos|cmux-local-macos|macfleet|tart-[a-z0-9-]+|(^|[^a-z0-9-])mac4([^a-z0-9]|$)|(^|[^a-z0-9-])mac-mini([^a-z0-9]|$)|slot-[0-9]|xcode-[0-9]+-[0-9]|(^|[^a-z0-9-])zerocmux([^a-z0-9-]|$)'
  local allowed='blacksmith-(6|12)vcpu-macos-(15|26|latest)|warp-macos-15-arm64-6x|depot-macos-(latest|14)'

  # Bare self-hosted/macOS/ARM64 targeting (inline array or multi-line list).
  # Case-sensitive: GitHub's auto labels are `macOS`/`ARM64`, distinct from the
  # lowercase `macos`/`arm64` inside cloud labels like warp-macos-15-arm64-6x.
  local selfhosted='(^|[^A-Za-z0-9_-])(self-hosted|macOS|ARM64)([^A-Za-z0-9_-]|$)'
  local forbidden="${fleet}|${selfhosted}"

  # Self-test the matcher so a future edit cannot silently narrow it: every
  # known fleet/self-hosted label must be caught, every allowed cloud label
  # must pass. Probes are raw YAML values (no path:lineno: prefix).
  local probe
  for probe in 'runs-on: macfleet' '- tart-canary' '- tart-dual' '- tart-small' '- tart-macos-26' '- tart-ios' '- mac4' '- mac-mini' '- slot-3' '- xcode-26-3' '- zerocmux' \
               "runs-on: \${{ vars.X || 'macos-26' }}" '- warp-macos-26-arm64-6x' \
               '- cmux-aws-macos-15' '- zerocmux-macos-26' '- self-hosted' '- macOS' '- ARM64' \
               'runs-on: [self-hosted, macOS, ARM64]'; do
    if ! printf '%s\n' "$probe" | grep -Eq "($forbidden)"; then
      echo "FAIL: fleet-runner guard self-test missed a known fleet/self-hosted label: $probe"
      exit 1
    fi
  done
  for probe in "runs-on: \${{ vars.X || 'blacksmith-6vcpu-macos-26' }}" \
               "runs-on: \${{ vars.X || 'blacksmith-12vcpu-macos-26' }}" \
               "runs-on: \${{ vars.MACOS_RUNNER_15 || 'warp-macos-15-arm64-6x' }}" \
               '- warp-macos-15-arm64-6x' '- depot-macos-latest' '- blacksmith-6vcpu-macos-15' \
               '- blacksmith-4vcpu-ubuntu-2404'; do
    if printf '%s\n' "$probe" | sed -E "s/($allowed)//g" | grep -Eq "($forbidden)"; then
      echo "FAIL: fleet-runner guard self-test false-positived a cloud label: $probe"
      exit 1
    fi
  done

  probe="runs-on: \${{ vars.USE_TART == '1' && 'tart-canary' || 'blacksmith-6vcpu-macos-15' }}"
  if ! printf '%s\n' "$probe" | sed -E "s/($allowed)//g" | grep -Eq "($forbidden)"; then
    echo "FAIL: fleet-runner guard self-test let an allowed fallback mask a forbidden label: $probe"
    exit 1
  fi

  local e2e_tart_option_line e2e_tart_dual_option_line e2e_tart_small_option_line e2e_tart_tahoe_option_line ios_tart_option_line
  e2e_tart_option_line="$(awk '
    /^      runner:$/ { in_runner=1; next }
    in_runner && /^      [A-Za-z0-9_-]+:/ { in_runner=0; in_options=0 }
    in_runner && /^        options:$/ { in_options=1; next }
    in_options && /^        [A-Za-z0-9_-]+:/ { in_options=0 }
    in_options && /^          - tart-canary$/ { print FNR }
  ' "$E2E_FILE")"
  e2e_tart_dual_option_line="$(awk '
    /^      runner:$/ { in_runner=1; next }
    in_runner && /^      [A-Za-z0-9_-]+:/ { in_runner=0; in_options=0 }
    in_runner && /^        options:$/ { in_options=1; next }
    in_options && /^        [A-Za-z0-9_-]+:/ { in_options=0 }
    in_options && /^          - tart-dual$/ { print FNR }
  ' "$E2E_FILE")"
  e2e_tart_small_option_line="$(awk '
    /^      runner:$/ { in_runner=1; next }
    in_runner && /^      [A-Za-z0-9_-]+:/ { in_runner=0; in_options=0 }
    in_runner && /^        options:$/ { in_options=1; next }
    in_options && /^        [A-Za-z0-9_-]+:/ { in_options=0 }
    in_options && /^          - tart-small$/ { print FNR }
  ' "$E2E_FILE")"
  ios_tart_option_line="$(awk '
    /^      runner:$/ { in_runner=1; next }
    in_runner && /^      [A-Za-z0-9_-]+:/ { in_runner=0; in_options=0 }
    in_runner && /^        options:$/ { in_options=1; next }
    in_options && /^        [A-Za-z0-9_-]+:/ { in_options=0 }
    in_options && /^          - tart-ios$/ { print FNR }
  ' "$IOS_FILE")"

  local hits="" line content content_without_allowed
  # Inspect runner-selection lines only: runs-on:, matrix `os:`, and scalar list
  # items (`  - <label>`, which covers dispatch runner dropdowns and multi-line
  # `runs-on:` arrays). `- name:` / `- uses:` step entries have a colon and are
  # excluded. grep matches against file CONTENT; strip the `path:lineno:` prefix
  # before matching the value so the checkout path (which contains "zerocmux") can
  # never match the bare `zerocmux` label.
  while IFS= read -r line; do
    content="${line#*:*:}"
    content_without_allowed="$(printf '%s\n' "$content" | sed -E "s/($allowed)//g")"
    printf '%s\n' "$content_without_allowed" | grep -Eq "($forbidden)" || continue
    if [[ -n "$e2e_tart_option_line" ]] && [[ "$line" == "$E2E_FILE:$e2e_tart_option_line:"* ]]; then
      continue
    fi
    if [[ -n "$e2e_tart_dual_option_line" ]] && [[ "$line" == "$E2E_FILE:$e2e_tart_dual_option_line:"* ]]; then
      continue
    fi
    if [[ -n "$e2e_tart_small_option_line" ]] && [[ "$line" == "$E2E_FILE:$e2e_tart_small_option_line:"* ]]; then
      continue
    fi
    if [[ -n "$ios_tart_option_line" ]] && [[ "$line" == "$IOS_FILE:$ios_tart_option_line:"* ]]; then
      continue
    fi
    hits+="$line"$'\n'
  done < <(grep -rnE "(runs-on:|[[:space:]]os:[[:space:]]|^[[:space:]]*-[[:space:]]+[A-Za-z0-9._-]+[[:space:]]*$)" "$ROOT_DIR/.github/workflows")
  if [[ -n "$hits" ]]; then
    echo "FAIL: workflow references a self-hosted mac fleet label or bare self-hosted runner in a runner-selection position."
    echo "      Use a cloud label so required jobs never land on a mini that can't foreground a GUI app:"
    echo "      blacksmith-{6,12}vcpu-macos-{15,26,latest} / warp-macos-15-arm64-6x / depot-macos-{latest,14}."
    echo "$hits"
    exit 1
  fi
  echo "PASS: no workflow can route a required job to a self-hosted mac fleet runner (cloud only)"
}

check_cla_guard_runner

# ci.yml jobs
check_runner "$CI_FILE" "workflow-guard-tests" 'runs-on: tartelet' "Tartelet self-hosted"
check_runner "$CI_FILE" "app-host-unit-tests" 'runs-on: tartelet' "Tartelet self-hosted"
check_runner "$CI_FILE" "swift-package-tests" 'runs-on: tartelet' "Tartelet self-hosted"
check_runner "$CI_FILE" "tests-build-and-lag" 'runs-on: tartelet' "Tartelet self-hosted"
check_runner "$CI_FILE" "release-build" 'runs-on: tartelet' "Tartelet self-hosted"
check_runner "$CI_FILE" "ui-regressions" 'runs-on: tartelet' "Tartelet self-hosted"

# build-ghosttykit.yml
check_runner "$GHOSTTYKIT_FILE" "build-ghosttykit" 'runs-on: tartelet' "Tartelet self-hosted"

# ci-macos-compat.yml uses matrix.os.
check_runner "$COMPAT_FILE" "compat-tests" 'os: tartelet' "Tartelet self-hosted"

# release.yml jobs
check_runner "$RELEASE_FILE" "build-ghostty-cli-helper" 'runs-on: tartelet' "Tartelet self-hosted"
check_runner "$RELEASE_FILE" "build-sign-notarize" 'runs-on: \[tartelet, zerocmux-signing\]' "Tartelet self-hosted signing"

# Other macOS workflows
check_runner "$NIGHTLY_FILE" "build-sign-notarize-nightly" 'runs-on: tartelet' "Tartelet self-hosted"
check_runner "$TMUX_FILE" "terminal-nightly" 'runs-on: tartelet' "Tartelet self-hosted"
check_runner "$TUI_FILE" "test" "matrix\.os == 'macos' && 'tartelet'" "Tartelet self-hosted for macOS"
check_runner "$TEST_MACOS_FILE" "tests" 'runs-on: tartelet' "Tartelet self-hosted"
check_runner "$E2E_FILE" "e2e" "&& 'tartelet' \|\| inputs\.runner" "Tartelet self-hosted"
check_runner "$PERF_FILE" "activation-session-benchmark" "&& 'tartelet' \|\| inputs\.runner" "Tartelet self-hosted"
check_runner "$RELOAD_FILE" "build" 'runs-on: \$\{\{ inputs\.runner \}\}' "the Tart-only dispatch input"

if ! grep -Fq 'default: tartelet' "$RELOAD_FILE"; then
  echo "FAIL: reload-build.yml must default to the Tart self-hosted pool"
  exit 1
fi
