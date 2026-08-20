#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
status=0

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

if [[ -f "$ROOT/logs/odoo.log" ]]; then
  echo "OK: logs/odoo.log 可见"
else
  echo "提示: logs/odoo.log 不存在或不可见"
fi

exit "$status"
