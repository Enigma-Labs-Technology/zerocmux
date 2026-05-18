#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${CMUX_TAG:-}" ]]; then
  cat >&2 <<'EOF'
CMUX_TAG is required.

Usage:
  CMUX_TAG=<tag> scripts/zerocmux-debug-cli.sh <zerocmux-command> [args...]

Example:
  CMUX_TAG=codext scripts/zerocmux-debug-cli.sh list-workspaces
EOF
  exit 2
fi

if [[ ! "$CMUX_TAG" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "Invalid CMUX_TAG: $CMUX_TAG" >&2
  exit 2
fi

if [[ $# -eq 0 ]]; then
  echo "Usage: CMUX_TAG=$CMUX_TAG scripts/zerocmux-debug-cli.sh <zerocmux-command> [args...]" >&2
  exit 2
fi

sanitize_bundle() {
  local raw="$1"
  local cleaned
  cleaned="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/./g; s/^\.+//; s/\.+$//; s/\.+/./g')"
  if [[ -z "$cleaned" ]]; then
    cleaned="agent"
  fi
  printf '%s\n' "$cleaned"
}

sanitize_path() {
  local raw="$1"
  local cleaned
  cleaned="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')"
  if [[ -z "$cleaned" ]]; then
    cleaned="agent"
  fi
  printf '%s\n' "$cleaned"
}

tag_slug="$(sanitize_path "$CMUX_TAG")"
tag_bundle_id="$(sanitize_bundle "$CMUX_TAG")"

socket_path="/tmp/zerocmux-debug-${tag_slug}.sock"
if [[ ! -S "$socket_path" ]]; then
  cat >&2 <<EOF
Tagged zerocmux socket not found:
  $socket_path

Launch the tagged app first:
  ./scripts/reload.sh --tag $CMUX_TAG --launch
EOF
  exit 1
fi

cli_path="${HOME}/Library/Developer/Xcode/DerivedData/zerocmux-${tag_slug}/Build/Products/Debug/zerocmux DEV ${tag_slug}.app/Contents/Resources/bin/zerocmux"
if [[ ! -x "$cli_path" ]]; then
  cat >&2 <<EOF
Tagged zerocmux CLI not found:
  $cli_path

Build the tagged app first:
  ./scripts/reload.sh --tag $CMUX_TAG
EOF
  exit 1
fi

unset CMUX_SOCKET
unset CMUX_SOCKET_PASSWORD
unset CMUX_WORKSPACE_ID
unset CMUX_SURFACE_ID
unset CMUX_TAB_ID
unset CMUX_PANEL_ID
unset CMUXD_UNIX_PATH
unset CMUX_DEBUG_LOG
export CMUX_SOCKET_PATH="$socket_path"
export CMUX_TAG="$tag_slug"
export CMUX_BUNDLE_ID="com.kernelalex.zerocmux.debug.${tag_bundle_id}"
export CMUX_BUNDLED_CLI_PATH="$cli_path"
exec "$cli_path" "$@"
