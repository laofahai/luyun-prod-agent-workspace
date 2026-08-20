# 陆运管家生产只读 Agent 工作区

这个仓库用于在生产服务器上搭建 Qwen Code 等 Agent 的只读调查工作区。仓库本身只维护规则、脚本和软链接配置，不保存生产密钥、日志、会话或业务源码副本。

## 服务器初始化

建议部署到：

```bash
/opt/luyun/prod-agent-workspace
```

初始化软链接和 Qwen 项目配置：

```bash
cd /opt/luyun/prod-agent-workspace
./scripts/bootstrap-links.sh
LUYUN_MCP_BEARER_TOKEN='***' ./scripts/install-qwen-project-config.sh
./scripts/check-workspace.sh
```

不要用 `root` 运行 Qwen Code。建议在服务器上创建专用低权限用户运行本仓库：

```bash
# 示例，仅供服务器管理员执行
useradd --system --create-home --shell /bin/bash luyun-agent
```

专用用户不得加入 `docker` 组，不配置 `sudo`，只授予读取源码和指定日志的权限。

默认链接目标：

```text
app                 -> /opt/luyun/prod/app
addons              -> /opt/luyun/prod/app/addons
addons_third_party  -> /opt/luyun/prod/app/addons_third_party
addons_oca          -> /opt/luyun/addons_oca
docs                -> /opt/luyun/prod/app/docs
logs                -> /opt/luyun/prod/logs
```

OCB/Odoo 核心源码通常在容器镜像内，宿主机没有路径时不挂 `ocb`。如果服务器路径不同，复制 `config/paths.env.example` 为 `config/paths.env` 后调整。`config/paths.env` 不提交。

## Qwen Code 用法

只读调查建议使用 wrapper：

```bash
./scripts/qwen-prod-investigate.sh "用户在配载计划页面点击确认时报错：请帮忙只读查原因"
```

wrapper 会在当前工作区运行 `qwen --bare -p`，并把生产只读规则、代码路径、OCA 路径和日志限制注入 prompt。
默认会拒绝 root 运行，使用 `--approval-mode plan`、JSON 输出和运行预算。Qwen 只做只读代码分析；生产数据和日志只通过 MCP 白名单工具。

项目 MCP 配置写入本地 `.qwen/settings.json`，不提交。它只暴露 support 系列和基础身份工具，不暴露通用 `query/aggregate/describe_model`。

## 安全边界

- 不把 `/opt/luyun/prod` 作为 Agent 工作目录。
- 不读取 `.env*`、key、token、session、history、cache。
- 不读取生产 app 内的 `.agents/`、`.claude/`、`.codex/`、`.mcp.json`、`AGENTS.md`、`CLAUDE.md`、`superpowers/`。
- 不执行 SQL。
- 不执行 ORM 写入；没有 MCP 只读工具时，不让 Agent 自己拼 Odoo shell。
- 不通过 shell 直接查数据库或整段日志。
- 不重启容器、不更新模块、不修改文件。
- 日志诊断走 MCP `support_diagnose_error`；不让 Agent 直接读日志文件。
- Agent 可用生产调查账号查后台事实，但普通用户回复必须按用户可见性收敛。

## 推荐问题模板

```text
用户问题：
页面：
单据号：
报错文案：
发生时间（北京时间）：
业务单元/项目：
请只读查代码、当前数据和必要日志，输出已确认结论和还缺什么。
```
