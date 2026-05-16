#!/usr/bin/env bash
# Ensures the release artifact scanner fails closed when a checked secret value
# appears in generated artifacts.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

export APPLE_APP_SPECIFIC_PASSWORD="zerocmux-test-secret"
printf 'public artifact content\n' > "$TMP_DIR/clean.txt"
python3 "$ROOT_DIR/scripts/verify_release_artifacts_no_secrets.py" "$TMP_DIR" >/dev/null

printf 'leaked %s\n' "$APPLE_APP_SPECIFIC_PASSWORD" > "$TMP_DIR/leaky.txt"
if python3 "$ROOT_DIR/scripts/verify_release_artifacts_no_secrets.py" "$TMP_DIR" >/dev/null 2>&1; then
  echo "FAIL: release artifact scanner missed seeded secret leak" >&2
  exit 1
fi

unset APPLE_APP_SPECIFIC_PASSWORD
export SPARKLE_PRIVATE_KEY_FILE="$TMP_DIR/sparkle-private-key"
printf 'sparkle-file-backed-secret\n' > "$SPARKLE_PRIVATE_KEY_FILE"
rm -f "$TMP_DIR/leaky.txt"
printf 'public artifact content\n' > "$TMP_DIR/clean.txt"
python3 "$ROOT_DIR/scripts/verify_release_artifacts_no_secrets.py" "$TMP_DIR/clean.txt" >/dev/null

printf 'leaked %s\n' "sparkle-file-backed-secret" > "$TMP_DIR/leaky-sparkle.txt"
if python3 "$ROOT_DIR/scripts/verify_release_artifacts_no_secrets.py" "$TMP_DIR/leaky-sparkle.txt" >/dev/null 2>&1; then
  echo "FAIL: release artifact scanner missed file-backed Sparkle private key leak" >&2
  exit 1
fi

echo "PASS: release artifact scanner detects seeded secret leaks"
