#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
GHOSTTY_DIR="${GHOSTTYKIT_GHOSTTY_DIR:-$PROJECT_DIR/ghostty}"
ZIG_BIN="${GHOSTTYKIT_ZIG:-zig}"

if [[ ! -f "$GHOSTTY_DIR/build.zig" ]]; then
  echo "error: Ghostty source is missing at $GHOSTTY_DIR" >&2
  exit 1
fi

args=(
  build
  -Demit-xcframework=true
  -Demit-macos-app=false
  -Dxcframework-target=universal
  -Doptimize=ReleaseFast
  -Dsentry=false
)

if grep -Fq '"crash-report-subdir"' "$GHOSTTY_DIR/src/build/Config.zig" 2>/dev/null; then
  args+=("-Dcrash-report-subdir=${GHOSTTYKIT_CRASH_REPORT_SUBDIR:-zerocmux/crash}")
else
  echo "==> Ghostty does not support -Dcrash-report-subdir; using its default crash report path."
fi

(
  cd "$GHOSTTY_DIR"
  "$ZIG_BIN" "${args[@]}"
)
