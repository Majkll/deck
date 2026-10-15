"""Deterministic, conservative sanitization for untrusted agent inputs."""
from __future__ import annotations

import hashlib
import re
import unicodedata
from dataclasses import dataclass, field
from html.parser import HTMLParser
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit


SECRET_PATTERNS: tuple[tuple[str, re.Pattern[str]], ...] = (
    ("private_key", re.compile(r"-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----.*?-----END [A-Z0-9 ]*PRIVATE KEY-----", re.I | re.S)),
    ("bearer", re.compile(r"\bBearer\s+[A-Za-z0-9._~+/=-]{16,}", re.I)),
    ("basic_auth", re.compile(r"\bBasic\s+[A-Za-z0-9+/=]{16,}", re.I)),
    ("jwt", re.compile(r"\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b")),
    ("api_key", re.compile(r"\b(?:sk|pk|ghp|github_pat|xox[baprs]-)[A-Za-z0-9_-]{12,}\b", re.I)),
    ("secret_assignment", re.compile(r"\b(?:api[_-]?key|token|secret|password|passwd|cookie|session[_-]?id|oauth[_-]?code)\s*[:=]\s*[^\s,;]+", re.I)),
    ("credential_url", re.compile(r"\b[a-z][a-z0-9+.-]*://[^\s/@]+:[^\s/@]+@[^\s]+", re.I)),
)

TRACKING_KEYS = {"fbclid", "gclid", "mc_cid", "mc_eid", "ref", "ref_src", "utm_campaign", "utm_content", "utm_medium", "utm_source", "utm_term"}


@dataclass
class SanitizationReport:
    findings: dict[str, int] = field(default_factory=dict)

    def add(self, name: str, count: int = 1) -> None:
        self.findings[name] = self.findings.get(name, 0) + count


class _VisibleText(HTMLParser):
    def __init__(self, report: SanitizationReport) -> None:
        super().__init__(convert_charrefs=True)
        self.report = report
        self.parts: list[str] = []
        self.hidden = 0
        self.skip_depth = 0

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag.lower() in {"script", "style", "noscript", "template", "iframe", "object", "embed", "svg"}:
            self.skip_depth += 1
            self.report.add("active_html")

    def handle_endtag(self, tag: str) -> None:
        if tag.lower() in {"script", "style", "noscript", "template", "iframe", "object", "embed", "svg"} and self.skip_depth:
            self.skip_depth -= 1

    def handle_data(self, data: str) -> None:
        if not self.skip_depth:
            self.parts.append(data)


def _redact(value: str, report: SanitizationReport) -> str:
    for name, pattern in SECRET_PATTERNS:
        def replace(match: re.Match[str], category: str = name) -> str:
            report.add(category)
            return f"[REDACTED:{category}]"
        value = pattern.sub(replace, value)
    return value


def _clean_url(value: str, report: SanitizationReport) -> str:
    try:
        parts = urlsplit(value)
    except ValueError:
        return value
    if not parts.scheme or not parts.netloc:
        return value
    safe_query = [(key, val) for key, val in parse_qsl(parts.query, keep_blank_values=True) if key.lower() not in TRACKING_KEYS]
    if len(safe_query) != len(parse_qsl(parts.query, keep_blank_values=True)):
        report.add("tracking_metadata")
    netloc = parts.hostname or ""
    if parts.port:
        netloc += f":{parts.port}"
    return urlunsplit((parts.scheme, netloc, parts.path, urlencode(safe_query), ""))


def sanitize_text(text: str, *, max_bytes: int = 524288, max_lines: int = 10000) -> tuple[str, SanitizationReport]:
    report = SanitizationReport()
    if len(text.encode("utf-8", "replace")) > max_bytes:
        report.add("size_limit")
        text = text.encode("utf-8", "replace")[:max_bytes].decode("utf-8", "ignore")
    normalized = unicodedata.normalize("NFKC", text)
    cleaned_chars: list[str] = []
    for char in normalized:
        category = unicodedata.category(char)
        if category == "Cf":
            report.add("invisible_character")
            continue
        if category.startswith("C") and char not in "\n\t\r":
            report.add("control_character")
            continue
        cleaned_chars.append(char)
    value = "".join(cleaned_chars)
    value = _redact(value, report)
    value = re.sub(r"https?://[^\s<>]+", lambda m: _clean_url(m.group(0), report), value)
    lines = value.splitlines()
    if len(lines) > max_lines:
        report.add("line_limit")
        lines = lines[:max_lines]
    return "\n".join(lines).strip(), report


def sanitize_html(html: str, *, max_bytes: int = 524288, max_lines: int = 10000) -> tuple[str, SanitizationReport]:
    report = SanitizationReport()
    parser = _VisibleText(report)
    parser.feed(html[:max_bytes])
    if len(html.encode("utf-8", "replace")) > max_bytes:
        report.add("size_limit")
    text, text_report = sanitize_text("\n".join(parser.parts), max_bytes=max_bytes, max_lines=max_lines)
    for key, count in text_report.findings.items():
        report.add(key, count)
    return text, report


def artifact_hash(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()
