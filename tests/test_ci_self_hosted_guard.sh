#!/usr/bin/env bash
# Ensures expensive macOS jobs stay on GitHub Actions runners and release
# signing stays on the dedicated self-hosted signing runner.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORKFLOW_DIR="$ROOT_DIR/.github/workflows"
CI_FILE="$WORKFLOW_DIR/ci.yml"
GHOSTTYKIT_FILE="$WORKFLOW_DIR/build-ghosttykit.yml"
COMPAT_FILE="$WORKFLOW_DIR/ci-macos-compat.yml"
RELEASE_FILE="$WORKFLOW_DIR/release.yml"

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

if grep -R -n -E 'runs-on:.*(warp-macos|blacksmith-|depot-)|os: (warp-macos|blacksmith-|depot-)' "$WORKFLOW_DIR"; then
  echo "FAIL: workflows must not use third-party macOS runner labels"
  exit 1
fi

# ci.yml jobs
check_runner "$CI_FILE" "tests" 'runs-on: macos-latest' "GitHub-hosted macos-latest"
check_runner "$CI_FILE" "tests-build-and-lag" 'runs-on: macos-latest' "GitHub-hosted macos-latest"
check_runner "$CI_FILE" "release-build" 'runs-on: macos-latest' "GitHub-hosted macos-latest"
check_runner "$CI_FILE" "ui-regressions" 'runs-on: macos-latest' "GitHub-hosted macos-latest"

# build-ghosttykit.yml
check_runner "$GHOSTTYKIT_FILE" "build-ghosttykit" 'runs-on: macos-latest' "GitHub-hosted macos-latest"

# ci-macos-compat.yml uses matrix.os.
check_runner "$COMPAT_FILE" "compat-tests" 'os: macos-latest' "GitHub-hosted macos-latest"

# release.yml signing job
check_runner "$RELEASE_FILE" "build-sign-notarize" 'runs-on: \[self-hosted, macOS, zerocmux-signing\]' "self-hosted zerocmux-signing"
