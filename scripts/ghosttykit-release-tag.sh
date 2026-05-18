#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ] || [ -z "${1:-}" ]; then
  echo "usage: $0 <ghostty-sha>" >&2
  exit 64
fi

GHOSTTY_SHA="$1"
GHOSTTYKIT_CRASH_REPORT_SUBDIR="${GHOSTTYKIT_CRASH_REPORT_SUBDIR:-zerocmux/crash}"
GHOSTTYKIT_BUILD_FLAVOR="${GHOSTTYKIT_BUILD_FLAVOR:-sentry-off-crashsubdir-$(printf '%s' "$GHOSTTYKIT_CRASH_REPORT_SUBDIR" | tr '/=' '--')-v1}"

printf 'xcframework-%s-%s\n' "$GHOSTTY_SHA" "$GHOSTTYKIT_BUILD_FLAVOR"
