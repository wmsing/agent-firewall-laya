# agent-firewall-laya

## 核心命令

- 安装/验收：`make check`
- 启动 sidecar：`make run`（需 `.env` 中 `EVALUATOR_API_KEY`）
- 范例：`service/main.py`
- 关联防火墙：<https://github.com/wmsing/agent-firewall>（`make check-firewall`）

## 绝对禁区

- 勿提交 `.env*`、密钥、`.pem`、`credentials*`
- 勿把密钥读进 Agent 上下文
- 勿擅改生产配置与数据库迁移

## 规范范例

- `service/main.py`

## 流程

- 新功能：`docs/spec/task_*.md` → 对话 `@` 该 spec → 实现 → `make check`
- Laya sidecar 规格：[`docs/spec/task_laya_evaluator.md`](../../docs/spec/task_laya_evaluator.md)（HTTP 契约对齐 `../agent-firewall` `HTTPRiskEvaluator`）
