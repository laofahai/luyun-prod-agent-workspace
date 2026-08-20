# 陆运管家生产只读 Agent 工作区

这个仓库用于在生产服务器上搭建 Qwen Code 等 Agent 的只读调查工作区。仓库本身只维护规则、脚本和软链接配置，不保存生产密钥、日志、会话或业务源码副本。

## 服务器初始化

建议部署到：

```bash
/opt/luyun/prod-agent-workspace
```

初始化软链接：

```bash
cd /opt/luyun/prod-agent-workspace
./scripts/bootstrap-links.sh
./scripts/check-workspace.sh
```

默认链接目标：

```text
app                 -> /opt/luyun/prod/app
addons              -> /opt/luyun/prod/app/addons
addons_third_party  -> /opt/luyun/prod/app/addons_third_party
addons_oca          -> /opt/luyun/addons_oca
ocb                 -> /opt/ocb
docs                -> /opt/luyun/prod/app/docs
logs                -> /opt/luyun/prod/logs
```

如果服务器路径不同，复制 `config/paths.env.example` 为 `config/paths.env` 后调整。`config/paths.env` 不提交。

## Qwen Code 用法

只读调查建议使用 wrapper：

```bash
./scripts/qwen-prod-investigate.sh "用户在配载计划页面点击确认时报错：请帮忙只读查原因"
```

wrapper 会在当前工作区运行 `qwen --bare -p`，并把生产只读规则、代码路径、OCA 路径、OCB 路径和日志限制注入 prompt。

## 安全边界

- 不把 `/opt/luyun/prod` 作为 Agent 工作目录。
- 不读取 `.env*`、key、token、session、history、cache。
- 不执行 SQL。
- 不执行 ORM 写入。
- 不重启容器、不更新模块、不修改文件。
- 日志只读 `logs/odoo.log` 和 `logs/queue/*.log`。

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
