import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { isToolCallEventType } from "@earendil-works/pi-coding-agent";
import { checkCommand, checkPath, loadPolicy } from "./policy.ts";
import { sanitizeText } from "./sanitize.ts";

export default function (pi: ExtensionAPI) {
  const policy = loadPolicy();

  pi.on("tool_call", async (event) => {
    if (isToolCallEventType("bash", event)) {
      const decision = checkCommand(event.input.command, policy);
      if (!decision.allowed) return { block: true, reason: decision.reason, terminate: true };
      return undefined;
    }
    if (event.toolName === "read" || event.toolName === "write" || event.toolName === "edit" || event.toolName === "grep" || event.toolName === "find" || event.toolName === "ls") {
      const path = typeof event.input.path === "string" ? event.input.path : typeof event.input.cwd === "string" ? event.input.cwd : "";
      const decision = checkPath(path, policy);
      if (!decision.allowed) return { block: true, reason: decision.reason, terminate: true };
    }
    return undefined;
  });

  pi.on("user_bash", (event) => {
    const decision = checkCommand(event.command, policy);
    if (!decision.allowed) return { result: { output: `Blocked: ${decision.reason}`, exitCode: 126, cancelled: false, truncated: false } };
    return undefined;
  });

  pi.on("tool_result", (event) => ({ content: event.content.map((item) => item.type === "text" ? { ...item, text: sanitizeText(item.text).text } : item), details: { sanitized: true } }));
  pi.on("message_end", (event) => {
    if (event.message.role !== "user" && event.message.role !== "assistant" && event.message.role !== "toolResult") return undefined;
    return { message: sanitizeMessage(event.message) };
  });
  pi.on("context", (event) => ({ messages: event.messages.map(sanitizeMessage) }));
  pi.on("project_trust", () => ({ trusted: "no" }));
}

function sanitizeMessage<T extends { role: string; content?: unknown }>(message: T): T {
  if (!Array.isArray(message.content)) return message;
  return { ...message, content: message.content.map((item) => typeof item === "object" && item !== null && "type" in item && item.type === "text" && "text" in item ? { ...item, text: sanitizeText(String(item.text)).text } : item) };
}
