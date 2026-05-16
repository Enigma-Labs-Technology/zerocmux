#!/usr/bin/env bash
# Ensures workflow entitlement rewrites do not use plutil dotted key paths.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if rg -n 'plutil -replace com\.apple\.(application-identifier|developer\.team-identifier)' \
  "$ROOT_DIR/.github/workflows/release.yml" \
  "$ROOT_DIR/.github/workflows/nightly.yml"; then
  echo "FAIL: dotted entitlement keys must be mutated as literal plist keys, not plutil key paths" >&2
  exit 1
fi

python3 - "$ROOT_DIR/cmux.release.entitlements" "$ROOT_DIR/cmux.nightly.entitlements" <<'PY'
import plistlib
import sys

required = [
    "com.apple.application-identifier",
    "com.apple.developer.team-identifier",
]

for path in sys.argv[1:]:
    with open(path, "rb") as handle:
        entitlements = plistlib.load(handle)
    missing = [key for key in required if key not in entitlements]
    if missing:
        raise SystemExit(f"FAIL: {path} missing entitlement key(s): {' '.join(missing)}")
PY

echo "PASS: entitlement rewrite guards use literal key-safe mutation"
