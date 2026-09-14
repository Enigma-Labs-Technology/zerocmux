#!/usr/bin/env python3
"""Exercise the bundled engine's reporting/update policy without allowing network egress."""

import json
import os
from pathlib import Path
import subprocess
import sys
import unittest


class BundledComputerUsePrivacyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binary = Path(os.environ["CUA_PRIVACY_BINARY"]).resolve(strict=True)
        repository = Path(__file__).resolve().parents[1]
        subprocess.run(
            [sys.executable, str(repository / "scripts/verify-cmux-cua-privacy.py"), str(cls.binary)],
            check=True,
        )

    def run_helper(self, *arguments):
        environment = dict(os.environ)
        environment["CMUX_CUA_TELEMETRY_ENABLED"] = "1"
        return subprocess.run(
            [
                "sandbox-exec", "-p", "(version 1)(allow default)(deny network-outbound)",
                str(self.binary), *arguments,
            ],
            env=environment,
            text=True,
            capture_output=True,
            timeout=15,
        )

    def test_install_event_is_not_an_available_command(self):
        result = self.run_helper("telemetry", "install-event")
        self.assertEqual(result.returncode, 64, result.stdout + result.stderr)

    def test_independent_update_paths_return_managed_policy(self):
        for arguments in [("check-update", "--json"), ("update", "--apply", "--json")]:
            with self.subTest(arguments=arguments):
                result = self.run_helper(*arguments)
                self.assertEqual(result.returncode, 64, result.stderr)
                self.assertEqual(json.loads(result.stdout)["error"], "managed_by_zerocmux")


if __name__ == "__main__":
    unittest.main()
