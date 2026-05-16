#!/usr/bin/env bash
set -euo pipefail

URL="${1:-https://example.com/form}"
SURFACE="${2:-surface:1}"

zerocmux browser "$SURFACE" goto "$URL"
zerocmux browser "$SURFACE" get url
zerocmux browser "$SURFACE" wait --load-state complete --timeout-ms 15000
zerocmux browser "$SURFACE" snapshot --interactive

echo "Now run fill/click commands using refs from the snapshot above."
