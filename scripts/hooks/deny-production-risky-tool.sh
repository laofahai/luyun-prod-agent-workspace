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

def iter_values(value):
    if isinstance(value, dict):
        for item in value.values():
            yield from iter_values(item)
    elif isinstance(value, list):
        for item in value:
            yield from iter_values(item)
    elif isinstance(value, str):
        yield value

def shell_command_from_input(value):
    if isinstance(value, dict):
        for key in ("command", "cmd", "shell_command"):
            if isinstance(value.get(key), str):
                return value[key]
    strings = list(iter_values(value))
    return strings[0] if strings else ""

def shell_command_is_safe(command):
    try:
        import shlex

        parts = shlex.split(command)
    except ValueError:
        return False, "shell 命令无法安全解析"
    if not parts:
        return False, "shell 命令为空"
    if re.search(r"[;&|><`$]", command):
        return False, "shell 命令包含管道、重定向、替换或多命令控制符"
    allowed = {
        "find", "grep", "head", "ls", "rg", "stat", "tail", "wc", "zgrep",
    }
    executable = os.path.basename(parts[0])
    if executable not in allowed:
        return False, f"shell 只允许只读检索命令，当前为: {executable}"
    allowed_roots = ("addons", "addons_third_party", "addons_oca", "docs", "logs")
    has_allowed_path = False
    for index, part in enumerate(parts[1:], start=1):
        if part.startswith("-"):
            continue
        if parts[index - 1] in {"-n", "--max-count", "-m"}:
            continue
        if part.startswith("/"):
            return False, "shell 禁止访问绝对路径"
        if "/" in part or part in allowed_roots:
            if not (part in allowed_roots or part.startswith(tuple(f"{root}/" for root in allowed_roots))):
                return False, f"shell 禁止访问非白名单路径: {part}"
            has_allowed_path = True
    if not has_allowed_path:
        return False, "shell 只允许检索白名单目录"
    if executable in {"head", "tail"}:
        for index, part in enumerate(parts):
            if part == "-n" and index + 1 < len(parts):
                try:
                    if int(parts[index + 1].lstrip("+")) > 2000:
                        return False, "head/tail 最多读取 2000 行"
                except ValueError:
                    return False, "head/tail 行数参数无效"
            elif part.startswith("-n") and len(part) > 2:
                try:
                    if int(part[2:].lstrip("+")) > 2000:
                        return False, "head/tail 最多读取 2000 行"
                except ValueError:
                    return False, "head/tail 行数参数无效"
    return True, ""

blocked_tool = re.compile(
    r"(write|edit|shell|bash|command|computer_use|web_fetch|agent|task|cron|worktree|record_artifact)",
    re.IGNORECASE,
)
blocked_input = re.compile(
    r"(\.qwen|settings\.json|\.env|token|secret|authorization|cookie|session|history|docker|odoo-bin|psql|env\.cr\.execute|\.sudo\(|\.write\(|\.create\(|\.unlink\(|\brm\b|\bmv\b|\bcp\b|chmod|chown)",
    re.IGNORECASE,
)

reason = ""
if re.search(r"(shell|bash|command)", tool_name, re.IGNORECASE):
    ok, shell_reason = shell_command_is_safe(shell_command_from_input(tool_input))
    if not ok:
        reason = shell_reason
elif blocked_tool.search(tool_name):
    reason = f"生产只读工作区禁止工具: {tool_name}"
if not reason and blocked_input.search(text):
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
