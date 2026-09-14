from __future__ import annotations

import shutil
import stat
import subprocess
import sys
import tempfile
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "cmux-tui/dist/scripts/package_npm_artifact.py"
EXECUTABLES = (
    "cmux-tui-darwin-arm64/bin/cmux-tui",
    "cmux-tui-darwin-arm64/bin/cmux-tui-hook",
    "cmux-tui-darwin-x64/bin/cmux-tui",
    "cmux-tui-darwin-x64/bin/cmux-tui-hook",
    "cmux-tui-linux-x64/bin/cmux-tui",
    "cmux-tui-linux-x64/bin/cmux-tui-hook",
    "cmux-tui-linux-arm64/bin/cmux-tui",
    "cmux-tui-linux-arm64/bin/cmux-tui-hook",
    "cmux/bin/cmux.js",
    "cmux-relay-darwin-arm64/bin/chatmux-relay",
    "cmux-relay-darwin-x64/bin/chatmux-relay",
    "cmux-relay-linux-x64/bin/chatmux-relay",
    "cmux-relay-linux-arm64/bin/chatmux-relay",
    "cmux-relay/bin/cmux-relay.js",
)

VERSION = "1.2.3"
TARGETS = {
    "cmux-tui-darwin-arm64": ("darwin", "arm64"),
    "cmux-tui-darwin-x64": ("darwin", "x64"),
    "cmux-tui-linux-x64": ("linux", "x64"),
    "cmux-tui-linux-arm64": ("linux", "arm64"),
}
RELAY_TARGETS = {
    name.replace("cmux-tui", "cmux-relay"): value
    for name, value in TARGETS.items()
}


def run_helper(*args: object) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), *(str(arg) for arg in args)],
        cwd=ROOT,
        check=False,
        capture_output=True,
        text=True,
    )


def write_relay_launcher_fixture(path: Path) -> None:
    """Write a launcher fixture with the npx autostart safety rule."""

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        r'''#!/usr/bin/env node
"use strict";

function isEphemeralNpxPath(value) {
  return value
    .split(/[\\/]+/)
    .some((component) => component.toLowerCase() === "_npx");
}

const executable = process.env.CMUX_RELAY_FIXTURE_EXECUTABLE || __filename;
if (process.platform === "win32") {
  console.error("cmux-relay: unsupported_platform (the Rust machine relay requires a Unix PTY backend).");
  process.exit(1);
}
if (process.argv.slice(2).includes("--autostart") && isEphemeralNpxPath(executable)) {
  console.error(
    "Install cmux-relay globally (npm install --global cmux-relay) before --autostart.",
  );
  process.exit(2);
}
process.stdout.write("cmux relay launcher 1.2.3\n");
''',
        encoding="utf-8",
    )
    path.chmod(0o755)


def make_package_fixture(packages: Path) -> None:
    for name, (os_name, cpu) in TARGETS.items():
        package = packages / name
        package.mkdir(parents=True, exist_ok=True)
        (package / "package.json").write_text(
            json.dumps(
                {
                    "name": name,
                    "version": VERSION,
                    "os": [os_name],
                    "cpu": [cpu],
                    "files": ["bin/cmux-tui", "bin/cmux-tui-hook"],
                }
            )
            + "\n"
        )
        for binary in ("cmux-tui", "cmux-tui-hook"):
            executable = package / "bin" / binary
            executable.parent.mkdir(parents=True, exist_ok=True)
            executable.write_text("#!/bin/sh\nexit 0\n")
            executable.chmod(0o755)

    launcher = packages / "cmux"
    launcher.mkdir(parents=True, exist_ok=True)
    (launcher / "package.json").write_text(
        json.dumps(
            {
                "name": "cmux",
                "version": VERSION,
                "bin": {"cmux": "bin/cmux.js"},
                "files": ["bin/cmux.js"],
                "optionalDependencies": {
                    name: VERSION for name in TARGETS
                },
            }
        )
        + "\n"
    )
    launcher_bin = launcher / "bin" / "cmux.js"
    launcher_bin.parent.mkdir(parents=True, exist_ok=True)
    launcher_bin.write_text("#!/bin/sh\nexit 0\n")
    launcher_bin.chmod(0o755)

    for name, (os_name, cpu) in RELAY_TARGETS.items():
        package = packages / name
        package.mkdir(parents=True, exist_ok=True)
        (package / "package.json").write_text(
            json.dumps(
                {
                    "name": name,
                    "version": VERSION,
                    "os": [os_name],
                    "cpu": [cpu],
                    "files": ["bin/chatmux-relay", "bin/cmux-tui"],
                }
            )
            + "\n"
        )
        executable = package / "bin" / "chatmux-relay"
        executable.parent.mkdir(parents=True, exist_ok=True)
        executable.write_text("#!/bin/sh\nexit 0\n")
        executable.chmod(0o755)
        runtime = package / "bin" / "cmux-tui"
        runtime.write_text("#!/bin/sh\nexit 0\n")
        runtime.chmod(0o755)

    relay_launcher = packages / "cmux-relay"
    relay_launcher.mkdir(parents=True, exist_ok=True)
    (relay_launcher / "package.json").write_text(
        json.dumps(
            {
                "name": "cmux-relay",
                "version": VERSION,
                "bin": {"cmux-relay": "bin/cmux-relay.js"},
                "files": ["bin/cmux-relay.js"],
                "optionalDependencies": {
                    name: VERSION for name in RELAY_TARGETS
                },
            }
        )
        + "\n"
    )
    relay_launcher_bin = relay_launcher / "bin" / "cmux-relay.js"
    relay_launcher_bin.parent.mkdir(parents=True, exist_ok=True)
    write_relay_launcher_fixture(relay_launcher_bin)


def test_archive_round_trip_preserves_package_executables(tmp_path: Path) -> None:
    packages = tmp_path / "npm-packages"
    make_package_fixture(packages)

    archive = tmp_path / "npm-packages.tar.gz"
    created = run_helper(
        "create", "--packages-dir", packages, "--archive", archive
    )
    assert created.returncode == 0, created.stderr

    # GitHub artifact transfer may normalize the outer file mode. The archive
    # must still restore executable package entries after download.
    archive.chmod(0o644)
    shutil.rmtree(packages)

    extracted = run_helper("extract", "--archive", archive, "--out", tmp_path)
    assert extracted.returncode == 0, extracted.stderr
    for relative_path in EXECUTABLES:
        mode = (packages / relative_path).stat().st_mode
        assert mode & stat.S_IXUSR, relative_path


def test_archive_bytes_are_independent_of_modes_and_output_name(tmp_path: Path) -> None:
    first_packages = tmp_path / "first" / "npm-packages"
    second_packages = tmp_path / "second" / "npm-packages"
    make_package_fixture(first_packages)
    make_package_fixture(second_packages)

    # Equivalent package trees may arrive with different umasks after a
    # self-hosted artifact hop.  The archive name is also caller-controlled.
    (second_packages / "cmux").chmod(0o700)
    (second_packages / "cmux" / "package.json").chmod(0o600)
    (second_packages / "cmux" / "bin" / "cmux.js").chmod(0o711)

    first_archive = tmp_path / "first-name.tar.gz"
    second_archive = tmp_path / "second-name.tar.gz"
    first = run_helper(
        "create",
        "--packages-dir",
        first_packages,
        "--archive",
        first_archive,
    )
    second = run_helper(
        "create",
        "--packages-dir",
        second_packages,
        "--archive",
        second_archive,
    )
    assert first.returncode == 0, first.stderr
    assert second.returncode == 0, second.stderr
    assert first_archive.read_bytes() == second_archive.read_bytes()


def test_extract_rejects_paths_outside_package_root(tmp_path: Path) -> None:
    archive = tmp_path / "npm-packages.tar.gz"
    # Build the hostile archive without relying on the helper under test.
    import io
    import tarfile

    with tarfile.open(archive, "w:gz") as tar:
        info = tarfile.TarInfo("../outside")
        contents = b"unexpected"
        info.size = len(contents)
        tar.addfile(info, io.BytesIO(contents))

    extracted = run_helper("extract", "--archive", archive, "--out", tmp_path)
    assert extracted.returncode != 0
    assert not (tmp_path.parent / "outside").exists()


# Hosted publisher workflow-shape assertions are excluded from zerocmux.
# Keep the executable archive contract independent of those publishers.
def main() -> None:
    with tempfile.TemporaryDirectory() as directory:
        test_archive_round_trip_preserves_package_executables(Path(directory))
    with tempfile.TemporaryDirectory() as directory:
        test_archive_bytes_are_independent_of_modes_and_output_name(Path(directory))
    with tempfile.TemporaryDirectory() as directory:
        test_extract_rejects_paths_outside_package_root(Path(directory))


if __name__ == "__main__":
    main()
