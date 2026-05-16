#!/usr/bin/env python3
import json
import os
import secrets
import sys
from pathlib import Path


REQUIRED_SECRET_NAMES = [
    "APPLE_CERTIFICATE_BASE64",
    "APPLE_CERTIFICATE_PASSWORD",
    "APPLE_SIGNING_IDENTITY",
    "APPLE_ID",
    "APPLE_APP_SPECIFIC_PASSWORD",
    "APPLE_TEAM_ID",
    "APPLE_RELEASE_PROVISIONING_PROFILE_BASE64",
    "SPARKLE_PRIVATE_KEY",
]

FILE_BACKED_SECRET_NAMES = {
    "SPARKLE_PRIVATE_KEY",
}


def _canonical_name(name: str) -> str:
    return "".join(ch for ch in name.lower() if ch.isalnum())


def normalize_secret_value(name: str, value: str) -> str:
    stripped = value.strip()
    if not stripped or stripped[0] not in '{"':
        return value

    try:
        parsed = json.loads(stripped)
    except json.JSONDecodeError:
        return value

    if isinstance(parsed, str):
        return parsed

    if not isinstance(parsed, dict):
        raise ValueError("secret JSON must be a string or object")

    if isinstance(parsed.get(name), str):
        return parsed[name]

    wanted = _canonical_name(name)
    matching_values = [
        field_value
        for field_name, field_value in parsed.items()
        if isinstance(field_value, str) and _canonical_name(field_name) == wanted
    ]
    if len(matching_values) == 1:
        return matching_values[0]

    string_values = [
        field_value
        for field_value in parsed.values()
        if isinstance(field_value, str)
    ]
    if len(string_values) == 1:
        return string_values[0]

    raise ValueError("secret JSON must contain one string field, or a field matching the expected environment variable name")


def _escape_workflow_command(value: str) -> str:
    return value.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def _write_github_env(env_file: str, name: str, value: str) -> None:
    delimiter = f"ZEROCMUX_SECRET_{secrets.token_hex(16)}"
    while delimiter in value:
        delimiter = f"ZEROCMUX_SECRET_{secrets.token_hex(16)}"

    with open(env_file, "a", encoding="utf-8") as handle:
        handle.write(f"{name}<<{delimiter}\n")
        handle.write(value)
        handle.write(f"\n{delimiter}\n")


def _clear_github_env(env_file: str, name: str) -> None:
    with open(env_file, "a", encoding="utf-8") as handle:
        handle.write(f"{name}=\n")


def _write_secret_file(directory: str, name: str, value: str) -> str:
    safe_name = name.lower().replace("_", "-")
    path = Path(directory) / f"zerocmux-{safe_name}-{secrets.token_hex(8)}"
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        handle.write(value)
    os.chmod(path, 0o600)
    return str(path)


def main() -> int:
    env_file = os.environ.get("GITHUB_ENV")
    if not env_file:
        print("GITHUB_ENV is not set", file=sys.stderr)
        return 1
    secret_file_dir = os.environ.get("RUNNER_TEMP")

    missing = []
    normalized_values = []
    for name in REQUIRED_SECRET_NAMES:
        value = os.environ.get(name, "")
        if not value:
            missing.append(name)
            continue

        try:
            normalized = normalize_secret_value(name, value)
        except ValueError as error:
            print(f"Invalid AWS secret format for {name}: {error}", file=sys.stderr)
            return 1

        if not normalized:
            missing.append(name)
            continue

        normalized_values.append((name, normalized))

    if missing:
        print(f"Missing release signing secrets from AWS Secrets Manager: {' '.join(missing)}", file=sys.stderr)
        return 1

    for name, value in normalized_values:
        print(f"::add-mask::{_escape_workflow_command(value)}")
        if name in FILE_BACKED_SECRET_NAMES:
            if not secret_file_dir:
                print(f"RUNNER_TEMP is required for file-backed secret {name}", file=sys.stderr)
                return 1
            secret_file_path = _write_secret_file(secret_file_dir, name, value)
            _clear_github_env(env_file, name)
            _write_github_env(env_file, f"{name}_FILE", secret_file_path)
        else:
            _write_github_env(env_file, name, value)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
