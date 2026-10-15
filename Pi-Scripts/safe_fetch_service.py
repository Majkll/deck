"""Socket-activated JSON-lines adapter for the bounded safe fetcher."""
from __future__ import annotations

import json
import os
import sys
import tomllib
from pathlib import Path

from safe_fetch import FetchPolicy, fetch


def _load_policy() -> FetchPolicy:
    path = os.environ.get("PI_SAFE_FETCH_POLICY")
    if not path:
        raise ValueError("PI_SAFE_FETCH_POLICY is required")
    try:
        with Path(path).open("rb") as handle:
            raw = tomllib.load(handle)
        network = raw["network"]
        domains = frozenset(str(item).lower() for item in network["allowed_domains"])
        if not domains:
            raise ValueError("safe fetch policy must contain at least one allowed domain")
        return FetchPolicy(
            domains,
            max_redirects=int(network.get("max_redirects", 3)),
            timeout=float(network.get("read_timeout_seconds", 15)),
            max_response_bytes=int(network.get("max_response_bytes", 1_048_576)),
            max_text_bytes=int(network.get("max_text_bytes", 524_288)),
        )
    except (OSError, KeyError, TypeError, ValueError, tomllib.TOMLDecodeError) as exc:
        raise ValueError("cannot load safe fetch policy") from exc


def main() -> int:
    line = sys.stdin.buffer.readline(16_385)
    if not line or len(line) > 16_384:
        print(json.dumps({"error": "request is missing or oversized"}), flush=True)
        return 2
    try:
        request = json.loads(line)
        if not isinstance(request, dict) or not isinstance(request.get("url"), str):
            raise ValueError("request requires a URL")
        policy = _load_policy()
        result = fetch(request["url"], policy)
    except (ValueError, OSError, json.JSONDecodeError) as exc:
        print(json.dumps({"error": str(exc)}), flush=True)
        return 2
    print(json.dumps(result, ensure_ascii=True), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())