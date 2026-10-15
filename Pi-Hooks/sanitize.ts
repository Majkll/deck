const patterns: Array<[string, RegExp]> = [
  ["private_key", /-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z0-9 ]*PRIVATE KEY-----/gi],
  ["bearer", /\bBearer\s+[A-Za-z0-9._~+/=-]{16,}/gi],
  ["jwt", /\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b/g],
  ["assignment", /\b(api[_-]?key|token|secret|password|cookie|session[_-]?id)\s*[:=]\s*[^\s,;]+/gi],
];

export function sanitizeText(input: string): { text: string; findings: string[] } {
  const findings: string[] = [];
  let text = input.normalize("NFKC").replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F\u200B-\u200D\uFEFF]/g, () => { findings.push("control_or_invisible"); return ""; });
  for (const [name, pattern] of patterns) text = text.replace(pattern, () => { findings.push(name); return `[REDACTED:${name}]`; });
  return { text: text.slice(0, 524288), findings };
}
