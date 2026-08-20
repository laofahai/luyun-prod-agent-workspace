#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
status=0

if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  echo "禁止用 root 运行 Agent 调查工作区"
  status=1
fi

check_link() {
  local name="$1"
  if [[ ! -L "$ROOT/$name" ]]; then
    echo "缺少软链接: $name"
    status=1
    return
  fi
  local target
  target="$(readlink "$ROOT/$name")"
  if [[ ! -e "$ROOT/$name" ]]; then
    echo "软链接目标不存在: $name -> $target"
    status=1
    return
  fi
  echo "OK: $name -> $target"
}

for name in app addons addons_third_party addons_oca ocb docs logs; do
  check_link "$name"
done

if command -v qwen >/dev/null 2>&1; then
  echo "OK: qwen $(qwen --version 2>/dev/null | head -n 1)"
else
  echo "缺少 qwen 命令"
  status=1
fi

if [[ -f "$ROOT/.qwen/settings.json" ]]; then
  echo "OK: .qwen/settings.json 已配置"
  if grep -q "describe_model\\|\\\"query\\\"\\|\\\"aggregate\\\"\\|run_preset" "$ROOT/.qwen/settings.json"; then
    echo "提示: .qwen/settings.json 中出现被排除的技术工具名，应只出现在 excludeTools 中"
  fi
else
  echo "缺少 .qwen/settings.json，请运行 scripts/install-qwen-project-config.sh"
  status=1
fi

if [[ -f "$ROOT/logs/odoo.log" ]]; then
  echo "OK: logs/odoo.log 可见"
else
  echo "提示: logs/odoo.log 不存在或不可见"
fi

for forbidden in \
  "$ROOT/app/.env" \
  "$ROOT/app/.env.local" \
  "$ROOT/app/.mcp.json" \
  "$ROOT/app/.agents" \
  "$ROOT/app/.claude" \
  "$ROOT/app/.codex" \
  "$ROOT/app/superpowers"; do
  if [[ -e "$forbidden" ]]; then
    echo "提示: 存在禁止 Agent 主动读取的路径: ${forbidden#$ROOT/}"
  fi
done

exit "$status"
