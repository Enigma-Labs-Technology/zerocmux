#!/usr/bin/env python3
"""Reject bundled computer-use engines containing removed reporting/update transport."""

from pathlib import Path
import sys


FORBIDDEN_MARKERS = (
    b"posthog.com",
    b"cmux_cua_install",
    b"cmux_cua_mcp",
    b"cmux_cua_api_",
    b".telemetry_id",
    b"version_check.json",
)


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: verify-cmux-cua-privacy.py <built-engine> [...]")
        return 2
    for argument in sys.argv[1:]:
        path = Path(argument)
        contents = path.read_bytes()
        if b"managed_by_zerocmux" not in contents:
            print(f"error: {path} is missing the compiled zerocmux update policy", file=sys.stderr)
            return 1
        for marker in FORBIDDEN_MARKERS:
            if marker in contents:
                print(f"error: {path} contains forbidden reporting/update marker {marker!r}", file=sys.stderr)
                return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
