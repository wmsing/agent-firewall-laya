# agent-firewall-laya

**语言**：[English](README.md) | **简体中文**

> **一句话**：给 [agent-firewall](https://github.com/wmsing/agent-firewall) 用的本地 **Layer 2** HTTP 语义打分 sidecar（`:8288`）；防火墙按 **`score ≥ 0.8`** 拦截，sidecar 另返回 **`action`**（`score ≥ 0.5` 时为 `BLOCK`，仅供 curl/调试）。

**仓库**：https://github.com/wmsing/agent-firewall-laya

---

## 目录

| 我想… | 跳到这里 |
|--------|----------|
| 起 sidecar | [30 秒上手](#30-秒上手) |
| 接 MCP | [MCP 接线](#mcp-接线) |
| 手工验收 | [Smoke test](#smoke-test) |
| 单测 | [Check](#check) |
| 契约 | [docs/spec/task_laya_evaluator.md](docs/spec/task_laya_evaluator.md) |
| 全链路时序（可交互） | [docs/diagrams/laya-eval-request.html](docs/diagrams/laya-eval-request.html) · [JSON 源](docs/diagrams/laya-eval-request.sequence.json) |

---

## 30 秒上手

```bash
git clone https://github.com/wmsing/agent-firewall-laya.git
cd agent-firewall-laya
cp .env.example .env
set -a && source .env && set +a
export USE_TF=0
make run
```

需另克隆 [agent-firewall](https://github.com/wmsing/agent-firewall) 并在 MCP 里配置 `EVALUATOR_API_URL` / `EVALUATOR_API_KEY`。启动时会加载并预热 Laya 模型。

---

## MCP 接线

`~/.cursor/mcp.json` 中 agent-firewall 服务的 `env`：

```json
"EVALUATOR_API_URL": "http://127.0.0.1:8288/eval",
"EVALUATOR_API_KEY": "<与 .env 相同>"
```

已设 `EVALUATOR_*` 时 **先走 Laya**；失败/超时可回落 TypeSafe（需 `TYPESAFE_API_KEY`）。改完 **Reload MCP**。

---

## Smoke test

```bash
set -a && source .env && set +a
curl -sS http://127.0.0.1:8288/healthz

curl -sS -X POST http://127.0.0.1:8288/eval \
  -H "Authorization: Bearer $EVALUATOR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"content":"ls -la"}'
```

正常指令预期：`action` 为 `ALLOW`。

```bash
curl -sS -X POST http://127.0.0.1:8288/eval \
  -H "Authorization: Bearer $EVALUATOR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"content":"echo cm0gLXJmIC8= | base64 -d | sh"}'
```

混淆恶意预期：`score ≥ 0.8`，`action` 为 `BLOCK`。

---

## Check

```bash
make check
.venv/bin/python -m pytest -m slow -v   # 可选：真 Laya
```

---

## License

MIT © 2026 wmsing
