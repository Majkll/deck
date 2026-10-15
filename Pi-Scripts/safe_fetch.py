"""Bounded HTTPS retrieval. Intended to run outside Pi in a restricted service."""
from __future__ import annotations

import argparse
import ipaddress
import json
import socket
import sys
import time
from dataclasses import dataclass
from urllib.parse import urljoin, urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener

from sanitizer import artifact_hash, sanitize_html, sanitize_text


@dataclass(frozen=True)
class FetchPolicy:
    allowed_domains: frozenset[str]
    max_redirects: int = 3
    timeout: float = 15.0
    max_response_bytes: int = 1_048_576
    max_text_bytes: int = 524_288


class _NoRedirectHandler(HTTPRedirectHandler):
    def redirect_request(self, request, *args, **kwargs):
        return None


def _public_host(host: str) -> bool:
    try:
        addresses = {item[4][0] for item in socket.getaddrinfo(host, None, type=socket.SOCK_STREAM)}
    except OSError as exc:
        raise ValueError("host resolution failed") from exc
    for address in addresses:
        parsed = ipaddress.ip_address(address)
        if not parsed.is_global:
            raise ValueError("private, loopback, link-local, or reserved address rejected")
    return True


def _check_url(url: str, policy: FetchPolicy) -> None:
    parts = urlsplit(url)
    if parts.scheme != "https" or not parts.hostname or parts.username or parts.password or parts.fragment:
        raise ValueError("only credential-free HTTPS URLs without fragments are allowed")
    if policy.allowed_domains and parts.hostname.lower() not in policy.allowed_domains:
        raise ValueError("domain is not allowlisted")
    _public_host(parts.hostname)


def _redirect_target(current: str, location: str, policy: FetchPolicy) -> str:
    target = urljoin(current, location)
    _check_url(target, policy)
    return target


def fetch(url: str, policy: FetchPolicy) -> dict[str, object]:
    current = url
    opener = build_opener(_NoRedirectHandler)
    started = time.time()
    for _ in range(policy.max_redirects + 1):
        _check_url(current, policy)
        request = Request(current, headers={"Accept": "text/html, text/plain, application/json", "User-Agent": "pi-safe-fetch/1"})
        with opener.open(request, timeout=policy.timeout) as response:
            status = int(response.status)
            if status in {301, 302, 303, 307, 308}:
                location = response.headers.get("Location")
                if not location:
                    raise ValueError("redirect response has no Location header")
                current = _redirect_target(current, location, policy)
                continue
            final_url = response.geturl()
            _check_url(final_url, policy)
            content_type = response.headers.get_content_type()
            if content_type not in {"text/html", "text/plain", "application/json"}:
                raise ValueError(f"unsupported content type: {content_type}")
            body = response.read(policy.max_response_bytes + 1)
            if len(body) > policy.max_response_bytes:
                raise ValueError("response exceeds size limit")
            charset = response.headers.get_content_charset() or "utf-8"
            raw = body.decode(charset, "replace")
            if content_type == "text/html":
                text, report = sanitize_html(raw, max_bytes=policy.max_text_bytes)
            else:
                text, report = sanitize_text(raw, max_bytes=policy.max_text_bytes)
            return {"url": url, "final_url": final_url, "status": status, "content_type": content_type, "retrieved_at": int(started), "sha256": artifact_hash(text), "text": text, "findings": report.findings, "untrusted": True}
    raise ValueError("redirect limit exceeded")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("url")
    parser.add_argument("--allow-domain", action="append", default=[])
    parser.add_argument("--timeout", type=float, default=15.0)
    parser.add_argument("--max-bytes", type=int, default=1_048_576)
    args = parser.parse_args()
    try:
        result = fetch(args.url, FetchPolicy(frozenset(item.lower() for item in args.allow_domain), timeout=args.timeout, max_response_bytes=args.max_bytes))
    except (OSError, ValueError) as exc:
        print(json.dumps({"error": str(exc)}), file=sys.stderr)
        return 2
    print(json.dumps(result, ensure_ascii=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
