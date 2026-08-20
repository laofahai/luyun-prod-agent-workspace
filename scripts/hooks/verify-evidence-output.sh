#!/usr/bin/env bash
set -euo pipefail

INPUT="$(cat)"
QWEN_STOP_HOOK_INPUT="$INPUT" python3 - <<'PY'
import json
import os
import re

raw = os.environ.get("QWEN_STOP_HOOK_INPUT", "")


def block(reason):
    print(json.dumps({
        "decision": "block",
        "reason": reason,
        "stopReason": reason,
        "continue": True,
    }, ensure_ascii=False))


try:
    payload = json.loads(raw or "{}")
except json.JSONDecodeError:
    block("Stop hook 输入不是 JSON，无法审查最终输出。")
    raise SystemExit(0)

message = str(payload.get("last_assistant_message") or "")
start = message.find("{")
end = message.rfind("}")
if start < 0 or end <= start:
    block("最终输出必须是 luyun_support_investigation_v1 JSON 对象，不能是普通 Markdown。")
    raise SystemExit(0)

try:
    data = json.loads(message[start:end + 1])
except json.JSONDecodeError as exc:
    block(f"最终输出不是合法 JSON：{exc.msg}")
    raise SystemExit(0)

errors = []
if data.get("schema") != "luyun_support_investigation_v1":
    errors.append("schema 必须是 luyun_support_investigation_v1")

evidence = data.get("evidence")
if not isinstance(evidence, list) or not evidence:
    errors.append("evidence 不能为空")
    evidence_ids = set()
else:
    evidence_ids = {str(item.get("id")) for item in evidence if isinstance(item, dict)}
    for item in evidence:
        if not isinstance(item, dict):
            errors.append("evidence 每项必须是对象")
            continue
        if not item.get("id") or not item.get("type") or not item.get("source") or not item.get("detail"):
            errors.append(f"evidence {item.get('id') or '<missing>'} 缺少 id/type/source/detail")

allowed_status = {"confirmed", "partial", "blocked"}
if data.get("status") not in allowed_status:
    errors.append("status 必须是 confirmed/partial/blocked")


def refs_exist(refs, path):
    if not isinstance(refs, list) or not refs:
        errors.append(f"{path} 必须引用至少一个 evidence id")
        return
    missing = [str(ref) for ref in refs if str(ref) not in evidence_ids]
    if missing:
        errors.append(f"{path} 引用了不存在的 evidence id: {', '.join(missing)}")


summary = data.get("summary")
if not isinstance(summary, dict) or not summary.get("text"):
    errors.append("summary.text 必填")
else:
    refs_exist(summary.get("evidence"), "summary.evidence")

user_reply = data.get("user_reply")
if not isinstance(user_reply, dict) or not user_reply.get("text"):
    errors.append("user_reply.text 必填")
else:
    refs_exist(user_reply.get("evidence"), "user_reply.evidence")

facts = data.get("facts")
if not isinstance(facts, list):
    errors.append("facts 必须是数组")
else:
    for index, fact in enumerate(facts, 1):
        if not isinstance(fact, dict) or not fact.get("claim"):
            errors.append(f"facts[{index}] 缺少 claim")
            continue
        refs_exist(fact.get("source"), f"facts[{index}].source")

actions = data.get("next_actions")
if not isinstance(actions, list):
    errors.append("next_actions 必须是数组")
else:
    for index, action in enumerate(actions, 1):
        if not isinstance(action, dict) or not action.get("action"):
            errors.append(f"next_actions[{index}] 缺少 action")
            continue
        refs_exist(action.get("source"), f"next_actions[{index}].source")

handoff = data.get("internal_handoff")
if isinstance(handoff, dict) and handoff.get("text"):
    refs_exist(handoff.get("evidence"), "internal_handoff.evidence")

forbidden = re.compile(
    r"(Bearer\s+[A-Za-z0-9._-]+|sk-[A-Za-z0-9._-]+|0bb9bd3342bc2de3cbe8697c8d41a642adaaa4b2)",
    re.IGNORECASE,
)
if forbidden.search(message):
    errors.append("最终输出疑似包含密钥或 token")

if errors:
    block("最终输出未通过证据契约审查：" + "；".join(errors[:8]))
else:
    print(json.dumps({
        "decision": "allow",
        "reason": "evidence output contract passed",
        "continue": False,
    }, ensure_ascii=False))
PY
