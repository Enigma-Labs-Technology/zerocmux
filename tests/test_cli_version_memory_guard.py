#!/usr/bin/env python3
"""
Regression test: `zerocmux --version` must not scan huge sibling app lists just to
resolve optional version metadata.
"""

from __future__ import annotations

import glob
import os
import plistlib
import re
import shutil
import subprocess
import tempfile
import time


JUNK_APP_COUNT = 40000
RSS_LIMIT_KB = 64 * 1024
TIMEOUT_SECONDS = 10.0
EXPECTED_STDOUT = "zerocmux 9.9.9 (999)"


def resolve_zerocmux_cli() -> str:
    explicit = (
        os.environ.get("ZEROCMUX_CLI_BIN")
        or os.environ.get("ZEROCMUX_CLI")
        or os.environ.get("CMUX_CLI_BIN")
        or os.environ.get("CMUX_CLI")
    )
    if explicit and os.path.exists(explicit) and os.access(explicit, os.X_OK):
        return explicit

    candidates: list[str] = []
    candidates.extend(glob.glob(os.path.expanduser("~/Library/Developer/Xcode/DerivedData/*/Build/Products/Debug/zerocmux")))
    candidates.extend(glob.glob("/tmp/zerocmux-*/Build/Products/Debug/zerocmux"))
    candidates = [p for p in candidates if os.path.exists(p) and os.access(p, os.X_OK)]
    if candidates:
        candidates.sort(key=os.path.getmtime, reverse=True)
        return candidates[0]

    in_path = shutil.which("zerocmux")
    if in_path:
        return in_path

    raise RuntimeError("Unable to find zerocmux CLI binary. Set ZEROCMUX_CLI_BIN.")


def build_fixture(root: str, cli_path: str) -> str:
    app_path = os.path.join(root, "zerocmux.app")
    contents_path = os.path.join(app_path, "Contents")
    resources_path = os.path.join(contents_path, "Resources")
    bin_path = os.path.join(resources_path, "bin")
    os.makedirs(bin_path, exist_ok=True)

    fixture_cli = os.path.join(bin_path, "zerocmux")
    shutil.copy2(cli_path, fixture_cli)

    info = {
        "CFBundleExecutable": "zerocmux",
        "CFBundleIdentifier": "test.zerocmux.version-memory-guard",
        "CFBundlePackageType": "APPL",
        "CFBundleShortVersionString": "9.9.9",
        "CFBundleVersion": "999",
    }
    with open(os.path.join(contents_path, "Info.plist"), "wb") as handle:
        plistlib.dump(info, handle)

    # Regular files are enough here because the fallback scan keys off the
    # ".app" suffix before it ever tries to inspect bundle contents.
    for index in range(JUNK_APP_COUNT):
        open(os.path.join(resources_path, f"junk-{index:05d}.app"), "wb").close()

    return fixture_cli


def run_with_limits(cli_path: str, *args: str) -> dict[str, object]:
    env = dict(os.environ)
    env.pop("ZEROCMUX_COMMIT", None)
    env.pop("CMUX_COMMIT", None)

    proc = subprocess.Popen(
        ["/usr/bin/time", "-l", cli_path, *args],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        env=env,
    )

    started = time.time()
    try:
        stdout, stderr = proc.communicate(timeout=TIMEOUT_SECONDS)
    except subprocess.TimeoutExpired:
        proc.kill()
        stdout, stderr = proc.communicate()
        elapsed = time.time() - started
        return {
            "exit_code": proc.returncode,
            "stdout": stdout.strip(),
            "stderr": stderr.strip(),
            "elapsed": elapsed,
            "peak_rss_kb": 0,
            "failure_reason": f"timeout exceeded ({elapsed:.2f}s > {TIMEOUT_SECONDS:.2f}s)",
        }

    elapsed = time.time() - started
    peak_rss_kb = 0
    rss_match = re.search(r"(\d+)\s+maximum resident set size", stderr)
    if rss_match:
        peak_rss_raw = int(rss_match.group(1))
        peak_rss_kb = peak_rss_raw if peak_rss_raw <= RSS_LIMIT_KB * 16 else peak_rss_raw // 1024

    failure_reason: str | None = None
    if peak_rss_kb > RSS_LIMIT_KB:
        failure_reason = f"rss limit exceeded ({peak_rss_kb} KB > {RSS_LIMIT_KB} KB)"
    elif elapsed > TIMEOUT_SECONDS:
        failure_reason = f"timeout exceeded ({elapsed:.2f}s > {TIMEOUT_SECONDS:.2f}s)"

    return {
        "exit_code": proc.returncode,
        "stdout": stdout.strip(),
        "stderr": stderr.strip(),
        "elapsed": elapsed,
        "peak_rss_kb": peak_rss_kb,
        "failure_reason": failure_reason,
    }


def main() -> int:
    try:
        cli_path = resolve_zerocmux_cli()
    except Exception as exc:
        print(f"FAIL: {exc}")
        return 1

    with tempfile.TemporaryDirectory(prefix="zerocmux-version-memory-guard-") as root:
        fixture_cli = build_fixture(root, cli_path)
        result = run_with_limits(fixture_cli, "--version")

    if result["failure_reason"]:
        print("FAIL: `zerocmux --version` exceeded runtime guard")
        print(f"reason={result['failure_reason']}")
        print(f"elapsed={result['elapsed']:.2f}s")
        print(f"peak_rss_kb={result['peak_rss_kb']}")
        print(f"stdout={result['stdout']}")
        print(f"stderr={result['stderr']}")
        return 1

    if result["exit_code"] != 0:
        print("FAIL: `zerocmux --version` exited non-zero")
        print(f"exit={result['exit_code']}")
        print(f"stdout={result['stdout']}")
        print(f"stderr={result['stderr']}")
        return 1

    if result["stdout"] != EXPECTED_STDOUT:
        print("FAIL: unexpected version output")
        print(f"stdout={result['stdout']!r}")
        print(f"expected={EXPECTED_STDOUT!r}")
        return 1

    print(
        "PASS: `zerocmux --version` exits within memory/time limits "
        f"(peak_rss_kb={result['peak_rss_kb']}, elapsed={result['elapsed']:.2f}s)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
