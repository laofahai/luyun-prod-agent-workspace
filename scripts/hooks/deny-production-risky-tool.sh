#!/usr/bin/env bash
set -euo pipefail

INPUT="$(cat)"
QWEN_HOOK_INPUT="$INPUT" python3 - <<'PY'
import json
import os
import re
import sys

raw = os.environ.get("QWEN_HOOK_INPUT", "")
try:
    payload = json.loads(raw or "{}")
except json.JSONDecodeError:
    payload = {}

tool_name = str(payload.get("tool_name") or payload.get("name") or "")
tool_input = payload.get("tool_input", payload.get("input", {}))
text = json.dumps(tool_input, ensure_ascii=False)

blocked_tool = re.compile(
    r"(write|edit|shell|bash|command|computer_use|web_fetch|agent|task|cron|worktree|record_artifact)",
    re.IGNORECASE,
)
blocked_input = re.compile(
    r"(\.env|token|secret|authorization|cookie|session|history|/logs/|logs/odoo\.log|docker|odoo-bin|psql|env\.cr\.execute|\.sudo\(|\.write\(|\.create\(|\.unlink\(|\brm\b|\bmv\b|\bcp\b|chmod|chown)",
    re.IGNORECASE,
)

reason = ""
if blocked_tool.search(tool_name):
    reason = f"生产只读工作区禁止工具: {tool_name}"
elif blocked_input.search(text):
    reason = "生产只读工作区禁止读取敏感/运行态内容或执行写操作"

if reason:
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }, ensure_ascii=False))
    sys.exit(2)

print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "allow",
        "permissionDecisionReason": "production readonly guard passed",
    }
}, ensure_ascii=False))
PY
