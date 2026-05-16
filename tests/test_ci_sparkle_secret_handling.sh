#!/usr/bin/env bash
# Verifies Sparkle private key handling avoids argv/env exposure where possible.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PRIVATE_KEY="AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

if command -v swift >/dev/null 2>&1; then
  SWIFT_MODULE_CACHE="$TMP_DIR/swift-module-cache"
  mkdir -p "$SWIFT_MODULE_CACHE"
  argv_public_key="$(swift -module-cache-path "$SWIFT_MODULE_CACHE" "$ROOT_DIR/scripts/derive_sparkle_public_key.swift" "$PRIVATE_KEY")"
  stdin_public_key="$(printf '%s' "$PRIVATE_KEY" | swift -module-cache-path "$SWIFT_MODULE_CACHE" "$ROOT_DIR/scripts/derive_sparkle_public_key.swift" --stdin)"
  if [[ -z "$stdin_public_key" || "$stdin_public_key" != "$argv_public_key" ]]; then
    echo "FAIL: derive_sparkle_public_key.swift stdin mode does not match argv mode" >&2
    exit 1
  fi
else
  echo "SKIP: swift unavailable; skipping derive_sparkle_public_key.swift stdin check"
fi

FAKE_BIN="$TMP_DIR/fake-bin"
mkdir -p "$FAKE_BIN"

cat > "$FAKE_BIN/git" <<'FAKEGIT'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "clone" ]]; then
  dest="${@: -1}"
  mkdir -p "$dest/Sparkle.xcodeproj"
  exit 0
fi

if [[ "${1:-}" == "-C" && "${3:-}" == "rev-parse" ]]; then
  printf '%s\n' "${SPARKLE_REVISION:-5581748cef2bae787496fe6d61139aebe0a451f6}"
  exit 0
fi

echo "unexpected fake git invocation: $*" >&2
exit 1
FAKEGIT
chmod +x "$FAKE_BIN/git"

cat > "$FAKE_BIN/xcodebuild" <<'FAKEXCODEBUILD'
#!/usr/bin/env bash
set -euo pipefail

derived_data=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -derivedDataPath)
      derived_data="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

if [[ -z "$derived_data" ]]; then
  echo "missing -derivedDataPath" >&2
  exit 1
fi

out_dir="$derived_data/Build/Products/Release"
mkdir -p "$out_dir"

cat > "$out_dir/generate_appcast" <<'FAKEGENERATE'
#!/usr/bin/env bash
set -euo pipefail
archives_dir="${@: -1}"
cat > "$archives_dir/appcast.xml" <<'XML'
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <item>
      <enclosure sparkle:edSignature="fake-signature" />
    </item>
  </channel>
</rss>
XML
FAKEGENERATE
chmod +x "$out_dir/generate_appcast"

cat > "$out_dir/sign_update" <<'FAKESIGNUPDATE'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' 'fallback-signature'
FAKESIGNUPDATE
chmod +x "$out_dir/sign_update"
FAKEXCODEBUILD
chmod +x "$FAKE_BIN/xcodebuild"

DMG_PATH="$TMP_DIR/zerocmux-macos.dmg"
APPCAST_PATH="$TMP_DIR/appcast.xml"
APPCAST_ENV_PATH="$TMP_DIR/appcast-env.xml"
SPARKLE_KEY_FILE="$TMP_DIR/sparkle-private-key"
printf 'fake dmg content\n' > "$DMG_PATH"
printf '%s\n' "$PRIVATE_KEY" > "$SPARKLE_KEY_FILE"

(
  unset SPARKLE_PRIVATE_KEY
  PATH="$FAKE_BIN:$PATH" \
    SPARKLE_PRIVATE_KEY_FILE="$SPARKLE_KEY_FILE" \
    "$ROOT_DIR/scripts/sparkle_generate_appcast.sh" "$DMG_PATH" v-test "$APPCAST_PATH" >/dev/null
)

if ! grep -q 'sparkle:edSignature' "$APPCAST_PATH"; then
  echo "FAIL: appcast was not generated with a file-backed Sparkle private key" >&2
  exit 1
fi

(
  unset SPARKLE_PRIVATE_KEY_FILE
  PATH="$FAKE_BIN:$PATH" \
    SPARKLE_PRIVATE_KEY="$PRIVATE_KEY" \
    "$ROOT_DIR/scripts/sparkle_generate_appcast.sh" "$DMG_PATH" v-test "$APPCAST_ENV_PATH" >/dev/null
)

if ! grep -q 'sparkle:edSignature' "$APPCAST_ENV_PATH"; then
  echo "FAIL: appcast env fallback no longer works" >&2
  exit 1
fi

echo "PASS: Sparkle secret handling supports stdin derivation and file-backed appcast signing"
