#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  echo "拒绝用 root 运行 Qwen Code Serve。请使用专用低权限用户。" >&2
  exit 1
fi
if [[ -z "${QWEN_SERVER_TOKEN:-}" ]]; then
  echo "缺少 QWEN_SERVER_TOKEN。Odoo 调用 qwen serve 必须启用 Bearer 认证。" >&2
  exit 2
fi
if ! command -v qwen >/dev/null 2>&1; then
  echo "未找到 qwen 命令" >&2
  exit 1
fi

cd "$ROOT"
exec qwen serve \
  --workspace "$ROOT" \
  --hostname 127.0.0.1 \
  --port "${QWEN_SERVE_PORT:-4170}" \
  --require-auth \
  --no-web
