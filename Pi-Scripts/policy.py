"""Fail-closed command and path policy with no third-party dependencies."""
from __future__ import annotations

import fnmatch
import os
import shlex
import tomllib
from dataclasses import dataclass
from pathlib import Path


class PolicyError(ValueError):
    """Raised when a security policy is missing or malformed."""


@dataclass(frozen=True)
class Policy:
    allowed_commands: frozenset[str]
    protected_paths: tuple[str, ...]
    workspace: Path
    max_command_bytes: int
    allow_shell_operators: bool

    @classmethod
    def load(cls, path: Path, cwd: Path | None = None) -> "Policy":
        try:
            with path.open("rb") as handle:
                raw = tomllib.load(handle)
        except (OSError, tomllib.TOMLDecodeError) as exc:
            raise PolicyError(f"cannot load security policy: {path}") from exc
        if not isinstance(raw, dict) or not isinstance(raw.get("commands"), dict) or not isinstance(raw.get("paths"), dict):
            raise PolicyError("security policy requires commands and paths tables")
        commands = raw.get("commands", {})
        paths = raw.get("paths", {})
        if not isinstance(commands.get("allow"), list) or not commands["allow"]:
            raise PolicyError("security policy command allowlist must be non-empty")
        if not isinstance(paths.get("protected"), list):
            raise PolicyError("security policy protected paths must be a list")
        configured_workspace = Path(raw.get("workspace", "."))
        base = cwd or path.parent.parent
        workspace = (base / configured_workspace).resolve()
        return cls(
            allowed_commands=frozenset(str(item) for item in commands.get("allow", [])),
            protected_paths=tuple(str(item) for item in paths.get("protected", [])),
            workspace=workspace,
            max_command_bytes=int(commands.get("max_command_bytes", 4096)),
            allow_shell_operators=bool(commands.get("allow_shell_operators", False)),
        )

    def check_command(self, command: str) -> tuple[bool, str]:
        if not command or len(command.encode("utf-8")) > self.max_command_bytes:
            return False, "empty or oversized command"
        if not self.allow_shell_operators and any(token in command for token in (";", "&&", "||", "|", ">", "<", "`", "$(", "\\\n")):
            return False, "shell operators are disabled"
        try:
            words = shlex.split(command, posix=True)
        except ValueError:
            return False, "invalid shell quoting"
        if not words:
            return False, "empty command"
        executable = Path(words[0]).name
        if executable not in self.allowed_commands:
            return False, f"command not allowlisted: {executable}"
        forbidden = {"sudo", "su", "doas", "chmod", "chown", "mkfs", "dd", "mount", "umount", "useradd", "systemctl", "curl", "wget", "ssh", "scp", "nc", "ncat", "npm", "pip", "uv", "rm", "python", "python3"}
        if executable in forbidden or any(Path(word).name in forbidden for word in words[1:]):
            return False, "forbidden command or argument"
        for word in words[1:]:
            if word.startswith("-"):
                continue
            if "/" in word or word.startswith((".", "~")):
                allowed, reason = self.check_path(word)
                if not allowed:
                    return False, reason
        return True, "allowed"

    def check_path(self, raw_path: str, *, must_exist: bool = False) -> tuple[bool, str]:
        candidate = Path(raw_path).expanduser()
        if not candidate.is_absolute():
            candidate = self.workspace / candidate
        try:
            resolved = candidate.resolve(strict=must_exist)
        except OSError:
            return False, "path cannot be resolved"
        try:
            resolved.relative_to(self.workspace)
        except ValueError:
            return False, "path is outside workspace"
        relative = resolved.relative_to(self.workspace).as_posix()
        name = resolved.name
        for pattern in self.protected_paths:
            if fnmatch.fnmatch(relative, pattern) or fnmatch.fnmatch(name, pattern) or fnmatch.fnmatch(f"**/{relative}", pattern):
                return False, "protected path"
        return True, "allowed"
