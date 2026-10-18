import os
import subprocess
import tarfile
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class BackupScriptTests(unittest.TestCase):
    def test_restore_uses_the_provided_archive_path(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp) / "home"
            cfg = home / ".config" / "pi-harness"
            cfg.mkdir(parents=True)
            (cfg / "state.txt").write_text("ready", encoding="utf-8")

            archive = Path(tmp) / "snapshot.tar.gz"
            with tarfile.open(archive, "w:gz") as handle:
                handle.add(cfg, arcname=".config/pi-harness")

            env = os.environ.copy()
            env["HOME"] = str(home)

            result = subprocess.run(
                ["bash", str(ROOT / "bootstrap" / "backup.sh"), "restore", str(archive)],
                cwd=str(ROOT),
                env=env,
                text=True,
                capture_output=True,
                check=False,
            )

            self.assertEqual(result.returncode, 0, msg=result.stderr)
            self.assertTrue((home / ".config" / "pi-harness" / "state.txt").exists())


class BootstrapPipelineTests(unittest.TestCase):
    def test_source_installer_dry_run_does_not_create_destination(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            destination = Path(tmp) / "nested" / "WorkspacePi"
            result = subprocess.run(
                [
                    str(ROOT / "bootstrap" / "install-from-source.sh"),
                    "--repository-url",
                    "https://example.invalid/WorkspacePi.git",
                    "--destination",
                    str(destination),
                    "--dry-run",
                ],
                cwd=str(ROOT),
                text=True,
                capture_output=True,
                check=False,
            )

            self.assertEqual(result.returncode, 0, msg=result.stderr)
            self.assertIn("would clone", result.stdout)
            self.assertFalse(destination.exists())
            self.assertFalse(destination.parent.exists())

    def test_source_installer_rejects_non_https_repository(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "bootstrap" / "install-from-source.sh"),
                "--repository-url",
                "git@example.invalid:WorkspacePi.git",
                "--dry-run",
            ],
            cwd=str(ROOT),
            text=True,
            capture_output=True,
            check=False,
        )

        self.assertEqual(result.returncode, 1)
        self.assertIn("must use HTTPS", result.stderr)

    def test_source_installer_delegates_to_fetched_checkout(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            bin_dir = root / "bin"
            bin_dir.mkdir()
            arguments_file = root / "arguments.txt"
            fake_git = bin_dir / "git"
            fake_git.write_text(
                "#!/usr/bin/env bash\n"
                "destination=\"$4\"\n"
                "mkdir -p \"$destination\"\n"
                "cat > \"$destination/install-target.sh\" <<'SCRIPT'\n"
                "#!/usr/bin/env bash\n"
                "printf '%s\\n' \"$@\" > \"$INSTALL_ARGUMENTS_FILE\"\n"
                "SCRIPT\n"
                "chmod +x \"$destination/install-target.sh\"\n",
                encoding="utf-8",
            )
            fake_git.chmod(0o755)
            destination = root / "checkout"
            env = os.environ.copy()
            env["PATH"] = f"{bin_dir}:{env['PATH']}"
            env["INSTALL_ARGUMENTS_FILE"] = str(arguments_file)

            result = subprocess.run(
                [
                    str(ROOT / "bootstrap" / "install-from-source.sh"),
                    "--repository-url",
                    "https://example.invalid/WorkspacePi.git",
                    "--destination",
                    str(destination),
                    "--mode",
                    "bash",
                    "--flavor",
                    "scientific",
                    "--approve",
                ],
                cwd=str(ROOT),
                env=env,
                text=True,
                capture_output=True,
                check=False,
            )

            self.assertEqual(result.returncode, 0, msg=result.stderr)
            self.assertEqual(arguments_file.read_text(encoding="utf-8").splitlines(), [
                "--mode",
                "bash",
                "--flavor",
                "scientific",
                "--approve",
            ])

    def test_stage_registry_matches_manifest(self) -> None:
        registry = (ROOT / "bootstrap" / "stages.list").read_text(encoding="utf-8").splitlines()
        manifest = (ROOT / "bootstrap" / "stage-manifest.yaml").read_text(encoding="utf-8")
        manifest_stages = []
        in_stages = False
        for line in manifest.splitlines():
            if line == "stages:":
                in_stages = True
                continue
            if in_stages and line.startswith("  - "):
                manifest_stages.append(f"{line[4:]}.sh")
                continue
            if in_stages and line and not line.startswith(" "):
                break

        self.assertEqual(registry, manifest_stages)

    def test_live_stage_selection_is_rejected_before_authentication(self) -> None:
        result = subprocess.run(
            [
                "bash",
                str(ROOT / "bootstrap" / "bootstrap.sh"),
                "--mode",
                "bash",
                "--flavor",
                "sysadmin",
                "--stage",
                "05-persona.sh",
                "--approve",
            ],
            cwd=str(ROOT),
            text=True,
            capture_output=True,
            check=False,
        )

        self.assertEqual(result.returncode, 2)
        self.assertIn("Live --stage execution is disabled", result.stderr)

    def test_inspection_modes_do_not_authenticate_with_sudo(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            bin_dir = Path(tmp) / "bin"
            bin_dir.mkdir()
            sudo_log = Path(tmp) / "sudo.log"
            (bin_dir / "sudo").write_text(
                "#!/usr/bin/env bash\n"
                f"printf '%s\\n' \"$*\" >> {sudo_log}\n",
                encoding="utf-8",
            )
            (bin_dir / "sudo").chmod(0o755)

            env = os.environ.copy()
            env["PATH"] = f"{bin_dir}:{env['PATH']}"
            env["HOME"] = tmp
            env["PI_HARNESS_LOG"] = str(Path(tmp) / "bootstrap.log")

            for args in (("--dry-run",), ("--list-stages",)):
                result = subprocess.run(
                    ["bash", str(ROOT / "bootstrap" / "bootstrap.sh"), *args],
                    cwd=str(ROOT),
                    env=env,
                    text=True,
                    capture_output=True,
                    check=False,
                )
                self.assertEqual(result.returncode, 0, msg=result.stderr)

            self.assertFalse(sudo_log.exists())
            self.assertFalse((Path(tmp) / "bootstrap.log").exists())

    def test_package_stage_keeps_installers_in_the_expected_privilege_context(self) -> None:
        package_stage = (ROOT / "bootstrap" / "01-packages.sh").read_text(encoding="utf-8")

        self.assertIn("curl -fsSL https://pi.dev/install.sh | sh", package_stage)
        self.assertIn("curl -fsSL https://astral.sh/uv/install.sh | sh", package_stage)
        self.assertIn("run_as_root dpkg --install", package_stage)
        self.assertIn("nym-vpnd_${NYM_VERSION}_${architecture}.deb", package_stage)
        self.assertIn("nym-vpnc_${NYM_VERSION}_${architecture}.deb", package_stage)
        self.assertIn("run_as_root dpkg --install \"$daemon_deb\" \"$cli_deb\"", package_stage)
        self.assertNotIn("nym-vpn-app", package_stage)
        self.assertNotIn("sudo dpkg", package_stage)

    def test_compatibility_entrypoint_exposes_approval_flag(self) -> None:
        install_target = (ROOT / "install-target.sh").read_text(encoding="utf-8")

        self.assertIn("[--dry-run] [--approve]", install_target)
        self.assertIn('BOOTSTRAP_ARGS+=(--approve)', install_target)

    def test_target_mutation_stages_are_explicit_and_hardened(self) -> None:
        users_stage = (ROOT / "bootstrap" / "02-users.sh").read_text(encoding="utf-8")
        security_stage = (ROOT / "bootstrap" / "03-security.sh").read_text(encoding="utf-8")
        verify_stage = (ROOT / "bootstrap" / "07-verify.sh").read_text(encoding="utf-8")

        self.assertIn("useradd --system", users_stage)
        self.assertIn("/usr/sbin/nologin", users_stage)
        self.assertIn("passwd --lock", users_stage)
        self.assertIn("Enter exact HTTPS hostnames", security_stage)
        self.assertIn("systemctl daemon-reload", security_stage)
        self.assertNotIn("run_as_root systemctl enable", security_stage)
        self.assertIn("/opt/pi-security/Pi-Scripts/safe_fetch_service.py", verify_stage)

    def test_nymvpn_status_checks_do_not_expand_status_as_a_shell_variable(self) -> None:
        verify_stage = (ROOT / "bootstrap" / "07-verify.sh").read_text(encoding="utf-8")
        package_checks = [
            line for line in verify_stage.splitlines()
            if line.startswith("check 'NymVPN ")
        ]
        self.assertEqual(len(package_checks), 2)

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            bin_dir = root / "bin"
            bin_dir.mkdir()
            (bin_dir / "dpkg-query").write_text(
                "#!/usr/bin/env bash\n"
                "printf '%s\\n' 'install ok installed'\n",
                encoding="utf-8",
            )
            (bin_dir / "nym-vpnc").write_text("#!/usr/bin/env bash\nexit 0\n", encoding="utf-8")
            for name in ("dpkg-query", "nym-vpnc"):
                (bin_dir / name).chmod(0o755)

            harness = (
                "set -eu\n"
                "check() {\n"
                "  local label=\"$1\" condition=\"$2\"\n"
                "  if eval \"$condition\"; then printf 'PASS: %s\\n' \"$label\"; "
                "else printf 'FAIL: %s\\n' \"$label\"; fi\n"
                "}\n"
                + "\n".join(package_checks)
                + "\n"
            )
            result = subprocess.run(
                ["bash", "-c", harness],
                env={**os.environ, "PATH": f"{bin_dir}:{os.environ['PATH']}"},
                text=True,
                capture_output=True,
                check=False,
            )

            self.assertEqual(result.returncode, 0, msg=result.stderr)
            self.assertNotIn("unbound variable", result.stderr)
            self.assertIn("PASS: NymVPN daemon package installed", result.stdout)
            self.assertIn("PASS: NymVPN CLI package and command available", result.stdout)

    def test_users_stage_checks_numeric_group_and_reports_conflicts(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            bin_dir = root / "bin"
            bin_dir.mkdir()
            (bin_dir / "getent").write_text(
                "#!/usr/bin/env bash\n"
                "case \"$1\" in\n"
                "  group) printf 'pi-safe-fetch:x:4242:\\n' ;;\n"
                "  passwd) printf 'pi-safe-fetch:x:987:4242::/var/lib/pi-safe-fetch:/usr/sbin/nologin\\n' ;;\n"
                "esac\n",
                encoding="utf-8",
            )
            (bin_dir / "id").write_text(
                "#!/usr/bin/env bash\n"
                "if [ \"$1\" = -u ]; then echo 0; else printf '%s\\n' \"$TEST_GROUP_IDS\"; fi\n",
                encoding="utf-8",
            )
            for name in ("getent", "id"):
                (bin_dir / name).chmod(0o755)

            env = os.environ.copy()
            env["PATH"] = f"{bin_dir}:{env['PATH']}"
            env["HOME"] = str(root)
            env["TEST_GROUP_IDS"] = "4242 27"

            result = subprocess.run(
                ["bash", str(ROOT / "bootstrap" / "02-users.sh")],
                cwd=str(ROOT),
                env=env,
                text=True,
                capture_output=True,
                check=False,
            )

            self.assertNotEqual(result.returncode, 0)
            self.assertIn("primary_gid=4242 groups=4242 27", result.stderr)
            self.assertIn("no supplementary groups", result.stderr)

    def test_users_stage_accepts_newly_provisioned_account(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            bin_dir = root / "bin"
            bin_dir.mkdir()
            (bin_dir / "getent").write_text(
                "#!/usr/bin/env bash\n"
                "case \"$1\" in\n"
                "  group) printf 'pi-safe-fetch:x:4242:\\n' ;;\n"
                "  passwd) printf 'pi-safe-fetch:x:987:4242::/var/lib/pi-safe-fetch:/usr/sbin/nologin\\n' ;;\n"
                "esac\n",
                encoding="utf-8",
            )
            (bin_dir / "id").write_text(
                "#!/usr/bin/env bash\n"
                "if [ \"$1\" = -u ]; then echo 0; else echo 4242; fi\n",
                encoding="utf-8",
            )
            for name in ("passwd", "install"):
                (bin_dir / name).write_text("#!/usr/bin/env bash\nexit 0\n", encoding="utf-8")
            for name in ("getent", "id", "passwd", "install"):
                (bin_dir / name).chmod(0o755)

            env = os.environ.copy()
            env["PATH"] = f"{bin_dir}:{env['PATH']}"
            env["HOME"] = str(root)

            result = subprocess.run(
                ["bash", str(ROOT / "bootstrap" / "02-users.sh")],
                cwd=str(ROOT),
                env=env,
                text=True,
                capture_output=True,
                check=False,
            )

            self.assertEqual(result.returncode, 0, msg=result.stderr)
            self.assertIn("PASS: hardened service account pi-safe-fetch is ready", result.stdout)

    def test_bootstrap_supports_dry_run_mode(self) -> None:
        result = subprocess.run(
            ["bash", str(ROOT / "bootstrap" / "bootstrap.sh"), "--mode", "bash", "--flavor", "sysadmin", "--dry-run"],
            cwd=str(ROOT),
            text=True,
            capture_output=True,
            check=False,
        )

        self.assertEqual(result.returncode, 0, msg=result.stderr)
        self.assertIn("DRY_RUN", result.stdout)
        self.assertIn("00-base.sh", result.stdout)

    def test_bootstrap_supports_stage_selection_and_listing(self) -> None:
        list_result = subprocess.run(
            ["bash", str(ROOT / "bootstrap" / "bootstrap.sh"), "--list-stages"],
            cwd=str(ROOT),
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(list_result.returncode, 0, msg=list_result.stderr)
        self.assertIn("00-base.sh", list_result.stdout)

        stage_result = subprocess.run(
            ["bash", str(ROOT / "bootstrap" / "bootstrap.sh"), "--mode", "bash", "--flavor", "sysadmin", "--stage", "00-base.sh", "--dry-run"],
            cwd=str(ROOT),
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(stage_result.returncode, 0, msg=stage_result.stderr)
        self.assertIn("00-base.sh", stage_result.stdout)
        self.assertNotIn("01-packages.sh", stage_result.stdout)

    def test_bootstrap_requires_explicit_production_gate(self) -> None:
        result = subprocess.run(
            ["bash", str(ROOT / "bootstrap" / "08-production-gate.sh"), "bash", "sysadmin"],
            cwd=str(ROOT),
            text=True,
            capture_output=True,
            check=False,
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Production gate", result.stderr + result.stdout)


if __name__ == "__main__":
    unittest.main()
