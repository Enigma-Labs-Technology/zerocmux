#!/usr/bin/env python3
import os
import sys
from pathlib import Path


SECRET_NAMES = [
    "APPLE_CERTIFICATE_BASE64",
    "APPLE_CERTIFICATE_PASSWORD",
    "APPLE_ID",
    "APPLE_APP_SPECIFIC_PASSWORD",
    "SPARKLE_PRIVATE_KEY",
]

SECRET_FILE_ENV_NAMES = {
    "SPARKLE_PRIVATE_KEY": "SPARKLE_PRIVATE_KEY_FILE",
}


def iter_files(paths: list[Path]):
    for path in paths:
        if not path.exists():
            continue
        if path.is_file():
            yield path
            continue
        for child in path.rglob("*"):
            if child.is_file() and not child.is_symlink():
                yield child


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: verify_release_artifacts_no_secrets.py <artifact-path>...", file=sys.stderr)
        return 2

    needles = []
    for name in SECRET_NAMES:
        value = os.environ.get(name, "")
        if not value:
            file_env_name = SECRET_FILE_ENV_NAMES.get(name)
            file_path = os.environ.get(file_env_name or "", "")
            if file_path:
                try:
                    value = Path(file_path).read_text(encoding="utf-8")
                except OSError as error:
                    print(f"Could not read secret file from {file_env_name}: {error}", file=sys.stderr)
                    return 1
        value = value.strip()
        if len(value) >= 8:
            needles.append((name, value.encode("utf-8")))

    if not needles:
        print("No secret values available for artifact leak scan", file=sys.stderr)
        return 1

    leaked = []
    for path in iter_files([Path(arg) for arg in sys.argv[1:]]):
        try:
            data = path.read_bytes()
        except OSError as error:
            print(f"Could not read artifact file {path}: {error}", file=sys.stderr)
            return 1
        for name, needle in needles:
            if needle in data:
                leaked.append((name, path))

    if leaked:
        for name, path in leaked:
            print(f"Secret value {name} was found in release artifact {path}", file=sys.stderr)
        return 1

    print("PASS: release artifacts do not contain checked secret values")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
