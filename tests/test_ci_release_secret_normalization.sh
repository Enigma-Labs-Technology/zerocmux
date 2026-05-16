#!/usr/bin/env bash
# Ensures release AWS Secrets Manager values can be stored as either plaintext
# or AWS console key/value JSON and still become the canonical env vars.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
ENV_FILE="$TMP_DIR/github-env"
trap 'rm -rf "$TMP_DIR"' EXIT

export GITHUB_ENV="$ENV_FILE"
export RUNNER_TEMP="$TMP_DIR"
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

sparkle_env_value="$(awk '
  $0 == "SPARKLE_PRIVATE_KEY=" {
    print "cleared"
    exit
  }
' "$ENV_FILE")"
if [[ "$sparkle_env_value" != "cleared" ]]; then
  echo "FAIL: expected SPARKLE_PRIVATE_KEY to be cleared from GITHUB_ENV" >&2
  exit 1
fi

sparkle_key_file="$(awk -v name="SPARKLE_PRIVATE_KEY_FILE" '
  index($0, name "<<") == 1 {
    getline value
    print value
    exit
  }
' "$ENV_FILE")"
if [[ ! -f "$sparkle_key_file" ]]; then
  echo "FAIL: expected normalized Sparkle private key file to exist" >&2
  exit 1
fi
if [[ "$(cat "$sparkle_key_file")" != "sparkle64" ]]; then
  echo "FAIL: normalized Sparkle private key file contains unexpected content" >&2
  exit 1
fi

key_file_mode="$(stat -f '%Lp' "$sparkle_key_file" 2>/dev/null || stat -c '%a' "$sparkle_key_file")"
if [[ "$key_file_mode" != "600" ]]; then
  echo "FAIL: expected Sparkle private key file mode 600, got $key_file_mode" >&2
  exit 1
fi

echo "PASS: release secret normalization supports plaintext and AWS key/value JSON"
