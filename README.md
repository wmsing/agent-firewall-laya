# agent-firewall-laya

Python · FastAPI · [Kev](https://github.com/jaredpalmer/kev) (HTTP backend) · License: MIT · Companion to [agent-firewall](https://github.com/wmsing/agent-firewall)

**Language**: **English** | [简体中文](README.zh-CN.md)

> **One line**: Local **Layer 2** HTTP semantic scorer for [agent-firewall](https://github.com/wmsing/agent-firewall) MCP / L7 — `POST /eval` → `score`, `reason`, optional sidecar `action` (firewall blocks at **score ≥ 0.8**).

**Repository**: [github.com/wmsing/agent-firewall-laya](https://github.com/wmsing/agent-firewall-laya)

```
  MCP execute_bash_command ──► agent-firewall (Go) ──► L1 hard rules
                                    │
                                    ▼ (EVALUATOR_API_* set)
                              POST /eval ──► this sidecar (:8288) ──► Kev :8009 /v1/systemone
                                    │ fail/timeout
                                    └──► TypeSafe Jev fallback (optional)
```

---

## Contents

| I want to… | Go to |
|------------|--------|
| Run Kev + sidecar | [Quick start](#quick-start) · [L2 stack / login](#run-on-login--quick-start) |
| Wire Cursor MCP | [MCP (with agent-firewall)](#mcp-with-agent-firewall) |
| Smoke-test `/eval` | [Smoke test](#smoke-test) |
| Health probe | `GET /healthz` → `{"status":"ok"}` (no auth) |
| CI / tests | [Check](#check) |
| API contract | [docs/spec/task_laya_evaluator.md](docs/spec/task_laya_evaluator.md) |
| Request flow (interactive) | [docs/diagrams/laya-eval-request.html](docs/diagrams/laya-eval-request.html) · [source JSON](docs/diagrams/laya-eval-request.sequence.json) |

---

## Quick start

**Requires**: Python **3.10+**

```bash
git clone https://github.com/wmsing/agent-firewall-laya.git
cd agent-firewall-laya
cp .env.example .env   # set EVALUATOR_API_KEY (long random secret)
set -a && source .env && set +a
make stack-start       # background Kev :8009 + sidecar :8288 (see scripts/l2-stack.sh)
# Or manually: Kev in ~/Projects/jev_demo/kev (uv sync --extra serve), then `make run` on :8288
```

First Kev start downloads weights; can take several minutes. After reboot, use `make stack-start` or [LaunchAgent](#run-on-login--quick-start).

Pair with [agent-firewall](https://github.com/wmsing/agent-firewall) — clone that repo separately and point MCP `EVALUATOR_API_URL` at this service.

---

## MCP (with agent-firewall)

In `~/.cursor/mcp.json` on the `agent-firewall` (or `mcp-firewall`) server:

```json
"env": {
  "EVALUATOR_API_URL": "http://127.0.0.1:8288/eval",
  "EVALUATOR_API_KEY": "<same as sidecar .env>",
  "TYPESAFE_API_KEY": "",
  "TYPESAFE_BASE_URL": "https://api.typesafe.ai"
}
```

**Priority ([agent-firewall](https://github.com/wmsing/agent-firewall)):** when `EVALUATOR_*` is set, **HTTP sidecar (Kev L2) runs first**; on timeout/error, **TypeSafe fallback** if `TYPESAFE_API_KEY` is non-empty. Kev-only: omit TypeSafe env. Reload MCP after edits.

Sidecar `.env` is for `make run` only; MCP reads `mcp.json` — keep the same `EVALUATOR_API_KEY` wherever you use it.

---

## Smoke test

```bash
set -a && source .env && set +a
curl -sS -X POST http://127.0.0.1:8288/eval \
  -H "Authorization: Bearer $EVALUATOR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"content":"ls -la"}'
```

Expect HTTP **200** JSON, e.g. `{"score":0.1,"reason":"destructive_shell","action":"ALLOW"}`. Sidecar sets `"action":"BLOCK"` when `score >= 0.5` (hint only); [agent-firewall](https://github.com/wmsing/agent-firewall) enforces **≥ 0.8** on `score` alone.

Obfuscated destructive example (needs Kev running):

```bash
curl -sS -X POST http://127.0.0.1:8288/eval \
  -H "Authorization: Bearer $EVALUATOR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"content":"echo cm0gLXJmIC8= | base64 -d | sh"}'
```

Expect `"score"` **≥ 0.8** and `"action":"BLOCK"` (firewall blocks on `score`, not sidecar `action` alone).

---

## Check

```bash
make check          # .venv + fast tests (Mock agent; no model download)
set -a && source .env && set +a
.venv/bin/python -m pytest -m slow -v   # optional: Kev at KEV_BASE_URL
```

`make check-firewall` in [agent-firewall](https://github.com/wmsing/agent-firewall) unsets evaluator keys and uses Mock — that does **not** prove the sidecar is wired.

---

## Environment

Copy `.env.example` → `.env` (**do not commit**).

| Variable | Role |
|----------|------|
| `EVALUATOR_API_KEY` | Bearer token for `/eval` (required) |
| `KEV_BASE_URL` | Default `http://127.0.0.1:8009` |
| `KEV_API_KEY` | Bearer for Kev (default `local`) |
| `KEV_MODEL` | Default `kev-latest` |

---

## Run on login / quick start

**One command** (background Kev + sidecar):

```bash
make stack-start    # or: bash scripts/l2-stack.sh start
make stack-status
make stack-stop
```

Logs: `~/.local/log/agent-firewall-l2/`. Skill: attach **`agent-firewall-l2`** in chat and ask to start L2.

**macOS login (optional):** install LaunchAgent (avoids Documents EPERM for launchd):

```bash
bash scripts/install-launchagent.sh
```

If `launchd.err.log` still shows `Operation not permitted` on `Documents`, move `~/Documents/jev_demo` to `~/Projects/jev_demo` and re-run install, or keep using `make stack-start` after login.

Disable: `launchctl bootout "gui/$(id -u)" ~/Library/LaunchAgents/com.wmsing.agent-firewall-l2.plist`

First login after reboot may wait on Kev weight download; MCP L2 fails until `:8288` healthz is ok.

---

## License

MIT © 2026 wmsing
