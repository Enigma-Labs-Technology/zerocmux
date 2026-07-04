#!/usr/bin/env bash
# Guard release/nightly provenance attestation against transient Sigstore/Rekor
# network failures without making attestation optional.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ACTION='actions/attest-build-provenance@a2bbfa25375fe432b6a289bc6b6cd05ecd0c4c32'

# zerocmux: the fork release/nightly pipelines do not (yet) build or publish
# cmuxd-remote daemon assets, so there is nothing to attest on that lane.
# (The app/DMG provenance attestation lives in the workflows themselves.)
# Re-enable the upstream retry-pattern checks when a daemon asset lane exists.
if grep -q "attest-remote-daemon" "$ROOT_DIR/.github/workflows/nightly.yml" "$ROOT_DIR/.github/workflows/release.yml" 2>/dev/null; then
  echo "FAIL: remote-daemon attestation steps exist; restore the retry-pattern checks in this guard" >&2
  exit 1
fi
echo "PASS: no remote-daemon asset lane; attestation retry guard not applicable"
