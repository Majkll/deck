"""Sanitize an artifact, then invoke qmd without shell interpolation."""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

from sanitizer import artifact_hash, sanitize_text


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("collection")
    parser.add_argument("--source", default="stdin")
    parser.add_argument("--qmd", default="qmd")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    raw = sys.stdin.read()
    text, report = sanitize_text(raw)
    manifest = {"source": args.source, "sha256": artifact_hash(text), "findings": report.findings, "sanitized": True}
    if args.check:
        print(json.dumps(manifest, sort_keys=True))
        return 0
    env = {"PATH": os.environ.get("PATH", "/usr/bin:/bin"), "HOME": os.environ.get("HOME", "/tmp")}
    command = [args.qmd, "add", args.collection, "--stdin"]
    try:
        completed = subprocess.run(command, input=text, text=True, capture_output=True, check=False, env=env, timeout=30)
    except (OSError, subprocess.SubprocessError) as exc:
        print(json.dumps({"error": str(exc), "manifest": manifest}), file=sys.stderr)
        return 2
    if completed.returncode:
        print(json.dumps({"error": "qmd failed", "returncode": completed.returncode, "manifest": manifest}), file=sys.stderr)
        return completed.returncode
    print(json.dumps({"ok": True, "manifest": manifest}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
