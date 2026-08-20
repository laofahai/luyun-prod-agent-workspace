#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
if [[ -f "$ROOT/config/paths.env" ]]; then
  # shellcheck disable=SC1091
  source "$ROOT/config/paths.env"
fi

: "${LUYUN_APP_DIR:=/opt/luyun/prod/app}"
: "${LUYUN_ADDONS_DIR:=/opt/luyun/prod/app/addons}"
: "${LUYUN_THIRD_PARTY_DIR:=/opt/luyun/prod/app/addons_third_party}"
: "${LUYUN_OCA_DIR:=/opt/luyun/addons_oca}"
: "${LUYUN_OCB_DIR:=}"
: "${LUYUN_DOCS_DIR:=/opt/luyun/prod/app/docs}"
: "${LUYUN_LOGS_DIR:=/opt/luyun/prod/logs}"

link_one() {
  local name="$1"
  local target="$2"
  if [[ ! -e "$target" ]]; then
    echo "缺少目标: $target" >&2
    return 1
  fi
  if [[ -L "$ROOT/$name" ]]; then
    local current
    current="$(readlink "$ROOT/$name")"
    if [[ "$current" == "$target" ]]; then
      echo "已存在: $name -> $target"
      return 0
    fi
    echo "软链接已存在但目标不同: $name -> $current" >&2
    return 1
  fi
  if [[ -e "$ROOT/$name" ]]; then
    echo "路径已存在且不是软链接: $ROOT/$name" >&2
    return 1
  fi
  ln -s "$target" "$ROOT/$name"
  echo "创建: $name -> $target"
}

link_one app "$LUYUN_APP_DIR"
link_one addons "$LUYUN_ADDONS_DIR"
link_one addons_third_party "$LUYUN_THIRD_PARTY_DIR"
link_one addons_oca "$LUYUN_OCA_DIR"
if [[ -n "$LUYUN_OCB_DIR" ]]; then
  link_one ocb "$LUYUN_OCB_DIR"
else
  echo "跳过: ocb 未配置宿主机路径"
fi
link_one docs "$LUYUN_DOCS_DIR"
link_one logs "$LUYUN_LOGS_DIR"
