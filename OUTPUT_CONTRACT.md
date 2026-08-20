# 生产支持调查输出契约

服务端 Agent 的职责是完成取证、判断和权限收敛，并返回可审计结果。用户端 WorkBuddy 或 ops-support skill 只能展示、折叠、转交和补充交互入口，不得新增事实、原因或处理建议。

## 工作流目标

```text
用户问题 -> 服务端只读取证 -> 证据编号 -> 结论生成 -> 权限收敛 -> 用户端展示
```

服务端必须直接返回最终答复和证据包，不只返回原始材料。用户端可以改变展示形态，但不能重新解释证据。

## 输出 JSON

最终回答必须是一个 JSON 对象，schema 固定为 `luyun_support_investigation_v1`：

```json
{
  "schema": "luyun_support_investigation_v1",
  "status": "confirmed | partial | blocked",
  "summary": {
    "text": "一句话结论。不能没有证据。",
    "evidence": ["E1"]
  },
  "user_reply": {
    "text": "给普通用户看的话，必须脱敏、收敛。",
    "evidence": ["E1"],
    "redaction": "说明哪些内容因权限或敏感性未展示"
  },
  "facts": [
    {
      "id": "F1",
      "claim": "已确认事实",
      "source": ["E1"]
    }
  ],
  "next_actions": [
    {
      "action": "下一步处理动作",
      "owner": "user | ops | implementation | developer | admin",
      "source": ["E1"]
    }
  ],
  "evidence": [
    {
      "id": "E1",
      "type": "user_input | code | mcp_data | log_file | document | policy",
      "source": "工具名、文件路径、函数名、日志文件范围或用户输入字段",
      "detail": "短摘要，不贴长源码、长日志或敏感值",
      "sensitive": false
    }
  ],
  "unknowns": [
    {
      "question": "还不能确认什么",
      "why": "缺少哪类证据或工具"
    }
  ],
  "internal_handoff": {
    "visibility": "none | internal_only",
    "text": "给内部人员的交接摘要；没有则为空",
    "evidence": ["E1"]
  }
}
```

## 证据规则

- `summary.text`、每条 `facts[].claim`、每条 `next_actions[].action` 必须引用 `evidence[].id`。
- 没有证据的内容只能放进 `unknowns`，不能放进 `summary`、`facts`、`next_actions`。
- `evidence[].detail` 只写短摘要，不复制长源码、长日志、完整 traceback、密钥、手机号、金额、价格、成本、合同内容。
- 来自用户输入的内容必须标为 `type=user_input`，不能当作系统事实。
- 推理链不能当证据。证据只能来自用户输入、代码/文档位置、MCP 数据、日志文件或本仓库策略。
- `user_reply.text` 必须按普通用户可见性收敛；内部数据只放 `internal_handoff`，且 `visibility=internal_only`。

## 用户端规则

用户端 WorkBuddy/ops-support skill 可以：

- 展示 `user_reply.text`。
- 折叠展示 `facts` 和 `evidence`。
- 将 `internal_handoff` 转给有权限的内部人员。
- 发现 `status=blocked` 或 `unknowns` 非空时，引导用户补充页面、单据号、报错、时间、业务单元。

用户端不得：

- 新增 facts、next_actions 或 summary。
- 把 `unknowns` 改写成确定结论。
- 把 `internal_handoff` 展示给无权限用户。
- 重新调用通用数据查询工具扩展答案。
