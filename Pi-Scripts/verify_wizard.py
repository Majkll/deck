"""Interactive target verification with explicit, non-destructive remediation guidance."""
from __future__ import annotations

import argparse
import json
import os
import shutil
import stat
import subprocess
import sys
from dataclasses import asdict, dataclass
from pathlib import Path


@dataclass(frozen=True)
class Check:
    name: str
    ok: bool
    detail: str
    remediation: tuple[str, ...] = ()
    severity: str = "error"


def _command(name: str) -> bool:
    return shutil.which(name) is not None


def _run(command: list[str]) -> tuple[bool, str]:
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=5, check=False)
    except (OSError, subprocess.SubprocessError) as exc:
        return False, str(exc)
    return result.returncode == 0, (result.stdout or result.stderr).strip()


def check_python() -> Check:
    ok = sys.version_info >= (3, 11)
    return Check("Python >= 3.11", ok, f"Python {sys.version.split()[0]}", ("Install Python 3.11 or newer using the target distribution packages.",))


def check_pi() -> Check:
    ok = _command("pi")
    return Check("Pi CLI available", ok, shutil.which("pi") or "pi was not found", ("Install the reviewed Pi release on the target, then run `pi --version`.",))


def check_qmd() -> Check:
    ok = _command("qmd")
    return Check("qmd available", ok, shutil.which("qmd") or "qmd was not found", ("Install qmd on the target and verify it is on PATH. Do not ingest data until the safe wrapper is used.",))


def check_policy(path: Path) -> Check:
    if not path.is_file():
        return Check("Security policy exists", False, str(path), (f"Copy a reviewed policy to `{path}`.",))
    try:
        import tomllib
        with path.open("rb") as handle:
            raw = tomllib.load(handle)
        domains = raw["network"]["allowed_domains"]
        if not isinstance(domains, list) or not domains:
            return Check("Fetch allowlist configured", False, "network.allowed_domains is empty", (f"Edit `{path}` and add only reviewed HTTPS domains to `network.allowed_domains`.",))
    except (OSError, KeyError, TypeError, ValueError, tomllib.TOMLDecodeError) as exc:
        return Check("Security policy valid", False, str(exc), (f"Repair or replace `{path}` from the reviewed template, then validate it before enabling services.",))
    return Check("Security policy valid", True, str(path), ())


def check_environment(policy_json: Path) -> Check:
    configured = os.environ.get("PI_SECURITY_POLICY")
    if configured != str(policy_json):
        return Check("Pi policy environment", False, configured or "PI_SECURITY_POLICY is unset", (f"Run `export PI_SECURITY_POLICY={policy_json}` before starting Pi.",))
    return Check("Pi policy environment", True, configured, ())


def check_permissions(path: Path) -> Check:
    if not path.exists():
        return Check("Policy permissions", False, "policy does not exist", (f"Create `{path}` with owner-only permissions.",))
    mode = stat.S_IMODE(path.stat().st_mode)
    ok = mode & 0o077 == 0
    return Check("Policy permissions", ok, oct(mode), (f"Run `chmod 600 {path}` and verify the owner is the intended Pi user.",))


def check_systemd() -> Check:
    if not _command("systemctl"):
        return Check("systemd available", False, "systemctl was not found", ("Run the fetch worker under a supported service manager or install systemd on the target.",))
    ok, detail = _run(["systemctl", "is-system-running"])
    if not ok and detail not in {"degraded", "running"}:
        return Check("systemd operational", False, detail or "systemd did not report running", ("Inspect `systemctl --failed` and fix the target service manager before enabling the fetch worker.",))
    return Check("systemd operational", True, detail or "running", ())


def collect(policy_toml: Path, policy_json: Path) -> list[Check]:
    return [
        check_python(),
        check_pi(),
        check_qmd(),
        check_policy(policy_toml),
        check_environment(policy_json),
        check_permissions(policy_toml),
        check_systemd(),
    ]


def render(checks: list[Check], *, interactive: bool = False) -> None:
    print("Pi security verification")
    print("No changes are made automatically. Remediations are suggestions for review.")
    print()
    for check in checks:
        marker = "PASS" if check.ok else "FAIL"
        print(f"[{marker}] {check.name}: {check.detail}")
        if not check.ok:
            if interactive:
                answer = input("  Show remediation steps? [Y/n] ").strip().lower()
                if answer in {"n", "no"}:
                    continue
            print("  Remediation:")
            for step in check.remediation:
                print(f"  - {step}")
    passed = sum(check.ok for check in checks)
    print(f"\n{passed}/{len(checks)} checks passed.")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--policy", type=Path, default=Path("/etc/pi-security/security-policy.toml"))
    parser.add_argument("--policy-json", type=Path, default=Path.home() / ".local/share/pi-security/config/security-policy.json")
    parser.add_argument("--json", action="store_true", help="emit machine-readable results")
    parser.add_argument("--interactive", action="store_true", help="pause before showing each failed check's remediation")
    args = parser.parse_args()
    checks = collect(args.policy, args.policy_json)
    if args.json:
        print(json.dumps([asdict(check) for check in checks], sort_keys=True))
    else:
        render(checks, interactive=args.interactive)
    return 0 if all(check.ok for check in checks) else 1


if __name__ == "__main__":
    raise SystemExit(main())
