# 生产只读 Agent 工作区规则

本仓库只用于 Qwen Code / Claude Code / Codex 等 Agent 在生产服务器上做只读取证。它不是业务代码仓库，不保存密钥、日志、会话、缓存或生产数据。

## 默认沟通

- 面向用户输出使用中文，直接说明结论、证据和下一步。
- 回答必须区分：代码已确认、数据已确认、日志已确认、推测、缺少的信息。
- 没有证据时说无法确认，不编造业务规则、状态流转或处理建议。

## 工作区结构

服务器初始化后，本仓库目录下应只有软链接指向生产只读材料：

- `app/` -> `/opt/luyun/prod/app`，项目部署目录。
- `addons/` -> `/opt/luyun/prod/app/addons`，自研模块。
- `addons_third_party/` -> `/opt/luyun/prod/app/addons_third_party`，第三方模块。
- `addons_oca/` -> `/opt/luyun/addons_oca`，OCA 模块集合。
- `ocb/` -> `/opt/ocb`，Odoo/OCB 源码。
- `docs/` -> `/opt/luyun/prod/app/docs`，生产随包文档。
- `logs/` -> `/opt/luyun/prod/logs`，生产日志目录。

不要把 `/opt/luyun/prod` 作为 Agent 项目根目录，避免把 `data/`、`backups/` 等运行态目录纳入上下文。

## 严格只读

禁止执行以下操作：

- 文件写入、删除、移动、复制、权限变更：`rm`、`mv`、`cp`、`chmod`、`chown`、重定向写入、编辑器保存。
- Docker 写操作：`docker restart`、`docker stop`、`docker start`、`docker kill`、`docker compose up/down/restart`。
- Odoo 模块变更：`-u`、`--update`、`-i`、`--install`。
- ORM 写操作：`.write(`、`.create(`、`.unlink(`、`.sudo()`。
- SQL：不执行 `env.cr.execute`；不执行 `psql`；不执行任何 INSERT、UPDATE、DELETE、DROP、ALTER、TRUNCATE。
- 读取认证、session、历史、缓存、密钥原文：`.env*`、API key、token、cookies、shell history、Qwen/Claude/Codex session。

允许的只读操作：

- 代码检索：`rg`、`find`、`ls`、`sed -n`、`awk`、`head`、`tail`、`git show`、`git log`、`git diff --no-index`。
- 日志检索：只读 `logs/odoo.log` 和 `logs/queue/*.log`，使用 `tail -n`、`grep`、`zgrep`，禁止 `tail -f`。
- Odoo 数据：优先使用已经配置好的 MCP 只读工具；没有 MCP 时只允许人工明确提供的只读 shell 片段，并先检查不含写操作和 SQL。

## 调查流程

1. 先复述问题和已知上下文：页面、单据号、用户看到的报错、发生时间、业务单元。
2. 查代码入口：优先搜索中文文案、按钮名、错误文案、字段 string、模型名、XML ID。
3. 追链路：菜单/action/view/button -> Python 方法 -> 校验/权限/配置/状态流转 -> 测试或文档。
4. 查数据：只用 MCP 或明确只读方式确认当前记录状态、关键字段、关联记录、用户权限和配置。
5. 查日志：仅在用户明确报错或有 request id/时间窗口时查最近日志；日志时间为 UTC，回答时换算北京时间。
6. 输出结论：分别列代码证据、数据证据、日志证据、还缺什么；普通用户最终只看业务语言结论。

## 输出格式

简短问题可以直接回答。复杂排查按以下结构：

```text
结论：
代码已确认：
数据已确认：
日志已确认：
推测/未确认：
建议下一步：
```

不要贴长源码、长日志、敏感数据或完整 traceback。必要时只给短摘要和位置。
