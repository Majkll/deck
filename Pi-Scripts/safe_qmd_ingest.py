"""Sanitize and persist an artifact for the local qmd memory collection."""
from __future__ import annotations

import argparse
import json
import os
import stat
import sys
from pathlib import Path

from sanitizer import artifact_hash, sanitize_text


def persist_artifact(text: str, digest: str) -> Path:
    directory = Path.home().resolve() / ".local/share/pi-memory/qmd/collections"
    if directory.resolve(strict=True) != directory:
        raise OSError(f"qmd memory collection path contains a symlink: {directory}")
    directory_stat = directory.lstat()
    if not stat.S_ISDIR(directory_stat.st_mode):
        raise OSError(f"qmd memory collection is not initialized: {directory}")
    if directory_stat.st_uid != os.getuid() or stat.S_IMODE(directory_stat.st_mode) != 0o700:
        raise OSError(f"qmd memory collection must be owned by the invoking user with mode 700: {directory}")

    path = directory / f"{digest}.md"
    try:
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0), 0o600)
    except FileExistsError:
        existing = path.lstat()
        if not stat.S_ISREG(existing.st_mode) or existing.st_uid != os.getuid() or stat.S_IMODE(existing.st_mode) != 0o600:
            raise OSError(f"existing qmd artifact has unsafe file state: {path}")
        if path.read_text(encoding="utf-8") != text:
            raise OSError(f"existing qmd artifact content does not match its digest: {path}")
        return path

    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(text)
            handle.flush()
            os.fsync(handle.fileno())
    except OSError:
        path.unlink(missing_ok=True)
        raise
    return path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("collection", choices=("memory",))
    parser.add_argument("--source", default="stdin")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    raw = sys.stdin.read()
    text, report = sanitize_text(raw)
    manifest = {"source": args.source, "sha256": artifact_hash(text), "findings": report.findings, "sanitized": True}
    if args.check:
        print(json.dumps(manifest, sort_keys=True))
        return 0

    try:
        artifact = persist_artifact(text, manifest["sha256"])
    except OSError as exc:
        print(json.dumps({"error": str(exc), "manifest": manifest}), file=sys.stderr)
        return 2
    print(json.dumps({"ok": True, "artifact": str(artifact), "manifest": manifest}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
