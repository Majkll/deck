import json
import os
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "Pi-Scripts"
sys.path.insert(0, str(SCRIPTS))

from policy import Policy, PolicyError  # noqa: E402
from safe_fetch import FetchPolicy, _redirect_target  # noqa: E402
from safe_fetch_service import _load_policy  # noqa: E402
from sanitizer import sanitize_html, sanitize_text  # noqa: E402
from verify_wizard import check_policy  # noqa: E402


class SanitizerTests(unittest.TestCase):
    def test_redacts_secrets_and_tracking_metadata(self) -> None:
        text, report = sanitize_text("Authorization: Bearer abcdefghijklmnop https://example.test/a?utm_source=x&ok=1 token=secret-value")
        self.assertNotIn("abcdefghijklmnop", text)
        self.assertNotIn("secret-value", text)
        self.assertNotIn("utm_source", text)
        self.assertIn("ok=1", text)
        self.assertIn("bearer", report.findings)

    def test_html_active_content_and_invisible_text_are_removed(self) -> None:
        text, report = sanitize_html("<script>steal()</script><p>Hello\u200b world</p><iframe>ignore</iframe>")
        self.assertEqual(text, "Hello world")
        self.assertIn("active_html", report.findings)
        self.assertIn("invisible_character", report.findings)

    def test_size_limit_is_bounded(self) -> None:
        text, report = sanitize_text("x" * 100, max_bytes=10)
        self.assertLessEqual(len(text.encode()), 10)
        self.assertIn("size_limit", report.findings)


class PolicyTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        policy_path = root / "security-policy.toml"
        policy_path.write_text((ROOT / "config/security-policy.toml").read_text())
        self.policy = Policy.load(policy_path, cwd=root)

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def test_shell_operators_and_network_tools_are_denied(self) -> None:
        self.assertFalse(self.policy.check_command("git status; curl https://example.test")[0])
        self.assertFalse(self.policy.check_command("curl https://example.test")[0])
        self.assertFalse(self.policy.check_command("python3 -c 'print(1)'")[0])
        self.assertFalse(self.policy.check_command("cat .env")[0])
        self.assertTrue(self.policy.check_command("git status")[0])

    def test_sensitive_and_escape_paths_are_denied(self) -> None:
        self.assertFalse(self.policy.check_path(".env")[0])
        self.assertFalse(self.policy.check_path("../outside.txt")[0])
        self.assertTrue(self.policy.check_path("notes.txt")[0])

    def test_shell_file_arguments_cannot_escape_workspace(self) -> None:
        self.assertFalse(self.policy.check_command("cat /etc/passwd")[0])

    def test_malformed_policy_fails_closed(self) -> None:
        path = Path(self.tmp.name) / "bad.toml"
        path.write_text("[commands]\nallow = []\n[paths]\nprotected = []\n")
        with self.assertRaises(PolicyError):
            Policy.load(path, cwd=Path(self.tmp.name))

    def test_redirect_target_is_revalidated(self) -> None:
        policy = FetchPolicy(frozenset({"allowed.example"}))
        address = [(None, None, None, None, ("93.184.216.34", 0))]
        with patch("safe_fetch.socket.getaddrinfo", return_value=address):
            self.assertEqual(_redirect_target("https://allowed.example/a", "/next", policy), "https://allowed.example/next")
            with self.assertRaises(ValueError):
                _redirect_target("https://allowed.example/a", "https://other.example/next", policy)


class QmdWrapperTests(unittest.TestCase):
    def test_check_mode_never_invokes_qmd_and_emits_manifest(self) -> None:
        process = subprocess.run(
            [sys.executable, str(SCRIPTS / "safe_qmd_ingest.py"), "memory", "--check"],
            input="token=super-secret",
            text=True,
            capture_output=True,
            check=False,
            env={"PATH": os.environ.get("PATH", "")},
        )
        self.assertEqual(process.returncode, 0)
        manifest = json.loads(process.stdout)
        self.assertNotIn("super-secret", process.stdout)
        self.assertTrue(manifest["sanitized"])
        self.assertIn("findings", manifest)


class FetchServiceTests(unittest.TestCase):
    def test_service_requires_target_policy(self) -> None:
        with patch.dict(os.environ, {}, clear=True):
            with self.assertRaises(ValueError):
                _load_policy()


class VerificationWizardTests(unittest.TestCase):
    def test_empty_allowlist_has_remediation_and_fails(self) -> None:
        policy = Path(tempfile.mkdtemp()) / "security-policy.toml"
        policy.write_text((ROOT / "config/security-policy.toml").read_text())
        result = check_policy(policy)
        self.assertFalse(result.ok)
        self.assertTrue(result.remediation)

    def test_valid_allowlist_passes(self) -> None:
        policy = Path(tempfile.mkdtemp()) / "security-policy.toml"
        policy.write_text((ROOT / "config/security-policy.toml").read_text().replace("allowed_domains = []", 'allowed_domains = ["docs.example.org"]'))
        result = check_policy(policy)
        self.assertTrue(result.ok)


if __name__ == "__main__":
    unittest.main()
