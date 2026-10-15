import { realpathSync } from "node:fs";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";

export type SecurityPolicy = {
  allowedCommands: Set<string>;
  workspace: string;
  protectedPatterns: string[];
};

export function loadPolicy(): SecurityPolicy {
  const policyPath = process.env.PI_SECURITY_POLICY;
  if (!policyPath) throw new Error("PI_SECURITY_POLICY must point to a reviewed policy file");
  let raw: unknown;
  try { raw = JSON.parse(readFileSync(policyPath, "utf8")); } catch { throw new Error(`cannot load security policy: ${policyPath}`); }
  if (typeof raw !== "object" || raw === null) throw new Error("security policy must be an object");
  const record = raw as Record<string, unknown>;
  if (!Array.isArray(record.allowedCommands) || record.allowedCommands.length === 0 || !Array.isArray(record.protectedPatterns) || typeof record.workspace !== "string") {
    throw new Error("security policy is missing required fields");
  }
  const workspace = process.env.PI_SECURITY_WORKSPACE ?? resolve(dirname(policyPath), record.workspace);
  return { allowedCommands: new Set(record.allowedCommands.map(String)), workspace, protectedPatterns: record.protectedPatterns.map(String) };
}

export function checkCommand(command: string, policy: SecurityPolicy): { allowed: boolean; reason: string } {
  if (!command || command.length > 4096) return { allowed: false, reason: "empty or oversized command" };
  if (/[;&|<>`]|\$\(|\\\n/.test(command)) return { allowed: false, reason: "shell operators are disabled" };
  const executable = command.trim().split(/\s+/, 1)[0].split("/").pop() ?? "";
  if (!policy.allowedCommands.has(executable)) return { allowed: false, reason: `command not allowlisted: ${executable}` };
  if (/\b(?:sudo|su|doas|chmod|chown|mkfs|dd|mount|umount|useradd|systemctl|curl|wget|ssh|scp|nc|ncat|npm|pip|uv|rm|python|python3)\b/i.test(command)) return { allowed: false, reason: "forbidden command or argument" };
  for (const word of command.trim().split(/\s+/).slice(1)) {
    if (word.startsWith("-") || (!word.includes("/") && !word.startsWith(".") && !word.startsWith("~"))) continue;
    const pathDecision = checkPath(word, policy);
    if (!pathDecision.allowed) return pathDecision;
  }
  return { allowed: true, reason: "allowed" };
}

export function checkPath(rawPath: string, policy: SecurityPolicy): { allowed: boolean; reason: string } {
  const path = rawPath.replaceAll("\\", "/");
  if (path.includes("../") || path === "..") return { allowed: false, reason: "path traversal is disabled" };
  const candidate = resolve(policy.workspace, path);
  let canonical = candidate;
  try { canonical = realpathSync.native(candidate); } catch {}
  const workspace = resolve(policy.workspace);
  if (canonical !== workspace && !canonical.startsWith(`${workspace}/`)) return { allowed: false, reason: "path is outside workspace" };
  const relative = canonical.slice(workspace.length).replace(/^\//, "");
  if (policy.protectedPatterns.some((pattern) => relative === pattern || relative.includes(pattern))) return { allowed: false, reason: "protected path" };
  return { allowed: true, reason: "allowed" };
}
