#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
QUESTION="${1:-}"
if [[ -z "$QUESTION" ]]; then
  echo "用法: $0 '用户问题/页面/单据/报错/时间'" >&2
  exit 2
fi
if ! command -v qwen >/dev/null 2>&1; then
  echo "未找到 qwen 命令" >&2
  exit 1
fi

cd "$ROOT"
qwen --bare -p "$(cat <<PROMPT
你在陆运管家生产只读 Agent 工作区工作。必须遵守 AGENTS.md。

用户问题：
$QUESTION

可查范围：
- 自研模块: ./addons
- 第三方模块: ./addons_third_party
- OCA 模块: ./addons_oca
- Odoo/OCB 源码: ./ocb
- 文档: ./docs
- 日志: 仅 ./logs/odoo.log 与 ./logs/queue/*.log

硬性限制：
- 禁止修改文件。
- 禁止 SQL。
- 禁止 ORM write/create/unlink/sudo。
- 禁止重启容器或更新/安装 Odoo 模块。
- 禁止读取 .env、key、token、session、history、cache。
- 日志只允许 tail/grep/zgrep，禁止 tail -f。

请按顺序只读调查：先代码，再数据线索，再必要日志。输出必须区分：代码已确认、数据已确认、日志已确认、推测/未确认、建议下一步。
PROMPT
)"
