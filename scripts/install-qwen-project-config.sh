#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

if [[ -z "${LUYUN_MCP_BEARER_TOKEN:-}" ]]; then
  echo "缺少 LUYUN_MCP_BEARER_TOKEN。请用生产调查只读账号的 mcp_agent token 执行。" >&2
  exit 2
fi

if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  echo "拒绝用 root 安装 Qwen 项目配置。请使用专用低权限用户。" >&2
  exit 1
fi

mkdir -p "$ROOT/.qwen"
umask 077
python3 - "$ROOT/config/qwen-settings.example.json" "$ROOT/.qwen/settings.json" <<'PY'
import json
import os
import sys

source, target = sys.argv[1], sys.argv[2]
token = os.environ["LUYUN_MCP_BEARER_TOKEN"]
with open(source, encoding="utf-8") as handle:
    data = json.load(handle)
data["mcpServers"]["luyun-prod-support"]["headers"]["Authorization"] = (
    "Bearer " + token
)
with open(target, "w", encoding="utf-8") as handle:
    json.dump(data, handle, ensure_ascii=False, indent=2)
    handle.write("\n")
PY
chmod 600 "$ROOT/.qwen/settings.json"

echo "已写入 $ROOT/.qwen/settings.json"
echo "请确认该文件权限仅当前用户可读，并且不要提交 .qwen/。"
