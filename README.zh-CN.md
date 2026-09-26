# agent-firewall-laya

**语言**：[English](README.md) | **简体中文**

> **一句话**：给 [agent-firewall](https://github.com/wmsing/agent-firewall) 用的本地 **Layer 2** HTTP 语义打分 sidecar（`:8288`）；防火墙按 **`score ≥ 0.8`** 拦截，sidecar 另返回 **`action`**（`score ≥ 0.5` 时为 `BLOCK`，仅供 curl/调试）。

**仓库**：https://github.com/wmsing/agent-firewall-laya

---

## 目录

| 我想… | 跳到这里 |
|--------|----------|
| 起 Kev + sidecar | [30 秒上手](#30-秒上手) · [开机 / 一键栈](#开机与-l2-栈) |
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
make stack-start   # 后台 Kev :8009 + sidecar :8288
# 或手动：在 kev 仓 uv run … --port 8009，本仓 `make run` 起 :8288
```

首次启动 Kev 会下载权重，可能需数分钟。重启后可用 `make stack-start` 或 [LaunchAgent](#开机与-l2-栈)。

需另克隆 [agent-firewall](https://github.com/wmsing/agent-firewall) 并在 MCP 里配置 `EVALUATOR_API_URL` / `EVALUATOR_API_KEY`。Sidecar 通过 HTTP 调本机 Kev，不再内嵌 Laya。

---

## MCP 接线

`~/.cursor/mcp.json` 中 agent-firewall 服务的 `env`：

```json
"EVALUATOR_API_URL": "http://127.0.0.1:8288/eval",
"EVALUATOR_API_KEY": "<与 .env 相同>"
```

已设 `EVALUATOR_*` 时 **先走 sidecar（Kev L2）**；失败/超时可回落 TypeSafe（需 `TYPESAFE_API_KEY`）。改完 **Reload MCP**。

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
.venv/bin/python -m pytest -m slow -v   # 可选：需 Kev 在 KEV_BASE_URL 运行
```

---

## 环境变量

复制 `.env.example` → `.env`（**勿提交**）。

| 变量 | 作用 |
|------|------|
| `EVALUATOR_API_KEY` | `/eval` Bearer（必填） |
| `KEV_BASE_URL` | 默认 `http://127.0.0.1:8009` |
| `KEV_API_KEY` | 调 Kev 的 Bearer（默认 `local`） |
| `KEV_MODEL` | 默认 `kev-latest` |

---

## 开机与 L2 栈

```bash
make stack-start    # 或 bash scripts/l2-stack.sh start
make stack-status
make stack-stop
```

日志：`~/.local/log/agent-firewall-l2/`。聊天可挂 skill **`agent-firewall-l2`** 让 Agent 起栈。

**macOS 登录自启（可选）：**

```bash
bash scripts/install-launchagent.sh
```

若 `launchd.err.log` 仍报 `Documents` 的 `Operation not permitted`，把 `~/Documents/jev_demo` 迁到 `~/Projects/jev_demo` 后重装，或登录后手动 `make stack-start`。

关闭：`launchctl bootout "gui/$(id -u)" ~/Library/LaunchAgents/com.wmsing.agent-firewall-l2.plist`

重启后首轮可能等 Kev 下权重；`:8288` healthz 未就绪时 MCP L2 会失败。

---

## License

MIT © 2026 wmsing
