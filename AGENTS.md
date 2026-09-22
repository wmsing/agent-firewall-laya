# Agent 地图

## 现在就做（默认）

1. 改 `docs/spec/task_laya_evaluator.md`
2. 聊天 **`@` 该 spec**
3. `make check`（可选 slow：`pytest -m slow`）

| 我要改… | @ 这个 spec | 验收 |
|---------|-------------|------|
| Laya sidecar | `docs/spec/task_laya_evaluator.md` | `make check` |

代码：`service/main.py` · `service/scoring.py` · 规则 `.cursor/rules/project.md`

父仓防火墙（Mock，不验 Laya 接线）：<https://github.com/wmsing/agent-firewall> → `make check-firewall`
