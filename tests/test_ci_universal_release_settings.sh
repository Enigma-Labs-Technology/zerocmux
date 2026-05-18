#!/usr/bin/env bash
# Regression test for universal GhosttyKit and Release build settings.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_SCRIPT="$ROOT_DIR/scripts/build-ghosttykit-xcframework.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

if ! grep -Fq -- '-Dxcframework-target=universal' "$BUILD_SCRIPT"; then
  echo "FAIL: $BUILD_SCRIPT must build GhosttyKit with -Dxcframework-target=universal"
  exit 1
fi

for file in \
  "$ROOT_DIR/.github/workflows/build-ghosttykit.yml" \
  "$ROOT_DIR/scripts/ensure-ghosttykit.sh" \
  "$ROOT_DIR/scripts/build-sign-upload.sh"
do
  if ! grep -Fq -- 'build-ghosttykit-xcframework.sh' "$file"; then
    echo "FAIL: $file must build GhosttyKit through build-ghosttykit-xcframework.sh"
    exit 1
  fi
done

if ! grep -Fq -- 'LEGACY_TAG="xcframework-${{ steps.ghostty-sha.outputs.sha }}"' "$ROOT_DIR/.github/workflows/build-ghosttykit.yml"; then
  echo "FAIL: build-ghosttykit.yml must skip builds when a legacy SHA-only release already exists"
  exit 1
fi

BIN_DIR="$TMP_DIR/bin"
NO_CRASH_DIR="$TMP_DIR/no-crash-option"
WITH_CRASH_DIR="$TMP_DIR/with-crash-option"
mkdir -p "$BIN_DIR" "$NO_CRASH_DIR/src/build" "$WITH_CRASH_DIR/src/build"
touch "$NO_CRASH_DIR/build.zig" "$WITH_CRASH_DIR/build.zig"
printf 'const option_name = "sentry";\n' > "$NO_CRASH_DIR/src/build/Config.zig"
printf 'const option_name = "crash-report-subdir";\n' > "$WITH_CRASH_DIR/src/build/Config.zig"

cat > "$BIN_DIR/zig" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" > "${TEST_ZIG_LOG:?}"
EOF
chmod +x "$BIN_DIR/zig"

NO_CRASH_LOG="$TMP_DIR/no-crash.log"
TEST_ZIG_LOG="$NO_CRASH_LOG" \
GHOSTTYKIT_GHOSTTY_DIR="$NO_CRASH_DIR" \
GHOSTTYKIT_ZIG="$BIN_DIR/zig" \
  "$BUILD_SCRIPT" >/dev/null

if grep -Fq -- '-Dcrash-report-subdir=' "$NO_CRASH_LOG"; then
  echo "FAIL: GhosttyKit build wrapper passed -Dcrash-report-subdir to a Ghostty revision that does not support it"
  exit 1
fi

WITH_CRASH_LOG="$TMP_DIR/with-crash.log"
TEST_ZIG_LOG="$WITH_CRASH_LOG" \
GHOSTTYKIT_GHOSTTY_DIR="$WITH_CRASH_DIR" \
GHOSTTYKIT_ZIG="$BIN_DIR/zig" \
  "$BUILD_SCRIPT" >/dev/null

if ! grep -Fq -- '-Dcrash-report-subdir=zerocmux/crash' "$WITH_CRASH_LOG"; then
  echo "FAIL: GhosttyKit build wrapper did not pass -Dcrash-report-subdir when Ghostty supports it"
  exit 1
fi

if ! grep -Fq -- 'ensure-ghosttykit.sh' "$ROOT_DIR/scripts/setup.sh"; then
  echo "FAIL: scripts/setup.sh must prepare GhosttyKit through ensure-ghosttykit.sh"
  exit 1
fi

if ! awk '
  /\/\* Release \*\// { in_release=1; next }
  in_release && /ONLY_ACTIVE_ARCH = YES;/ { saw_yes=1 }
  in_release && /ONLY_ACTIVE_ARCH = NO;/ { saw_no=1 }
  in_release && /name = Release;/ { in_release=0 }
  END { exit !(saw_no && !saw_yes) }
' "$ROOT_DIR/cmux.xcodeproj/project.pbxproj"; then
  echo "FAIL: Release configurations in project.pbxproj must use ONLY_ACTIVE_ARCH = NO"
  exit 1
fi

echo "PASS: GhosttyKit builds universal and Release configs disable ONLY_ACTIVE_ARCH"
