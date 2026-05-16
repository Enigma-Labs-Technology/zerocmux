#!/usr/bin/env bash
# Ensures release AWS Secrets Manager values can be stored as either plaintext
# or AWS console key/value JSON and still become the canonical env vars.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$(mktemp)"
trap 'rm -f "$ENV_FILE"' EXIT

export GITHUB_ENV="$ENV_FILE"
export APPLE_CERTIFICATE_BASE64='{"APPLE_CERTIFICATE_BASE64":"cert64"}'
export APPLE_CERTIFICATE_PASSWORD='plain-password'
export APPLE_SIGNING_IDENTITY='{"apple_signing_identity":"Developer ID Application: Example"}'
export APPLE_ID='"developer@example.com"'
export APPLE_APP_SPECIFIC_PASSWORD='{"APPLE_APP_SPECIFIC_PASSWORD":"app-pass"}'
export APPLE_TEAM_ID='TEAM123456'
export APPLE_RELEASE_PROVISIONING_PROFILE_BASE64='{"APPLE_RELEASE_PROVISIONING_PROFILE_BASE64":"profile64"}'
export SPARKLE_PRIVATE_KEY='{"SPARKLE_PRIVATE_KEY":"sparkle64"}'

python3 "$ROOT_DIR/scripts/normalize_release_secrets.py" >/dev/null

assert_env_value() {
  local name="$1"
  local expected="$2"
  local actual
  actual="$(awk -v name="$name" '
    index($0, name "<<") == 1 {
      getline value
      print value
      exit
    }
  ' "$ENV_FILE")"

  if [[ "$actual" != "$expected" ]]; then
    echo "FAIL: expected $name to normalize to '$expected', got '$actual'" >&2
    exit 1
  fi
}

assert_env_value APPLE_CERTIFICATE_BASE64 cert64
assert_env_value APPLE_CERTIFICATE_PASSWORD plain-password
assert_env_value APPLE_SIGNING_IDENTITY "Developer ID Application: Example"
assert_env_value APPLE_ID developer@example.com
assert_env_value APPLE_APP_SPECIFIC_PASSWORD app-pass
assert_env_value APPLE_TEAM_ID TEAM123456
assert_env_value APPLE_RELEASE_PROVISIONING_PROFILE_BASE64 profile64
assert_env_value SPARKLE_PRIVATE_KEY sparkle64

echo "PASS: release secret normalization supports plaintext and AWS key/value JSON"
