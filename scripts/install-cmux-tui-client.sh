#!/usr/bin/env bash
# Build the bundled TUI from the reviewed source in this checkout.
# A rolling upstream binary could contain code outside the fork's privacy audit.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
APP_PATH="${1:-}"
[[ -n "$APP_PATH" && -d "$APP_PATH/Contents" ]] || {
  echo "usage: scripts/install-cmux-tui-client.sh <app-path>" >&2
  exit 64
}
shift
[[ "$#" -eq 0 && -z "${CMUX_TUI_CLIENT_MANIFEST_URL:-}" && -z "${CMUX_TUI_CLIENT_LOCAL:-}" ]] || {
  echo "error: zerocmux bundles its reviewed TUI source; external binary overrides are unavailable" >&2
  exit 64
}

EXECUTABLE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP_PATH/Contents/Info.plist")"
ARCHS="$(lipo -archs "$APP_PATH/Contents/MacOS/$EXECUTABLE")"
MANIFEST="$REPO_ROOT/cmux-tui/Cargo.toml"
TARGET_DIR="${CARGO_TARGET_DIR:-$REPO_ROOT/cmux-tui/target}"
SLICES=()
for arch in $ARCHS; do
  case "$arch" in
    arm64) triple=aarch64-apple-darwin ;;
    x86_64) triple=x86_64-apple-darwin ;;
    *) echo "error: unsupported app architecture: $arch" >&2; exit 1 ;;
  esac
  if ! rustup target list --installed | grep -Fxq "$triple"; then
    rustup target add "$triple"
  fi
  # Keep host proc-macro debug info: Rust issue #157750 can produce dylibs
  # rejected by macOS 27 when stripping it. These build tools are not bundled.
  CARGO_PROFILE_RELEASE_BUILD_OVERRIDE_DEBUG=1 \
  CARGO_TARGET_DIR="$TARGET_DIR" MACOSX_DEPLOYMENT_TARGET=14.0 \
    cargo build --release --locked --manifest-path "$MANIFEST" --target "$triple" -p cmux-tui --bin cmux-tui
  SLICES+=("$TARGET_DIR/$triple/release/cmux-tui")
done
[[ "${#SLICES[@]}" -gt 0 ]] || { echo "error: app has no supported architectures" >&2; exit 1; }
DEST_DIR="$APP_PATH/Contents/Resources/bin"
mkdir -p "$DEST_DIR"
if [[ "${#SLICES[@]}" -eq 1 ]]; then
  install -m 755 "${SLICES[0]}" "$DEST_DIR/cmux-tui"
else
  lipo -create "${SLICES[@]}" -output "$DEST_DIR/cmux-tui"
  chmod 755 "$DEST_DIR/cmux-tui"
fi
for arch in $ARCHS; do lipo "$DEST_DIR/cmux-tui" -verify_arch "$arch"; done
printf 'source-tree=%s\n' "$(git -C "$REPO_ROOT" rev-parse HEAD:cmux-tui)" \
  > "$APP_PATH/Contents/Resources/cmux-tui-source.txt"
echo "Installed TUI built from this checkout at $DEST_DIR/cmux-tui"
