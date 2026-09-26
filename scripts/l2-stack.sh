#!/usr/bin/env bash
# Start/stop Kev (:8009) + evaluator sidecar (:8288). Idempotent.
set -euo pipefail

KEV_DIR="${KEV_DIR:-}"
SIDECAR_DIR="${SIDECAR_DIR:-}"
if [[ -z "$KEV_DIR" ]]; then
  if [[ -d "$HOME/Projects/jev_demo/kev" ]]; then
    KEV_DIR="$HOME/Projects/jev_demo/kev"
  else
    KEV_DIR="$HOME/Documents/jev_demo/kev"
  fi
fi
if [[ -z "$SIDECAR_DIR" ]]; then
  if [[ -d "$HOME/Projects/jev_demo/agent-firewall-laya" ]]; then
    SIDECAR_DIR="$HOME/Projects/jev_demo/agent-firewall-laya"
  else
    SIDECAR_DIR="$HOME/Documents/jev_demo/agent-firewall-laya"
  fi
fi
CONFIG_ENV="${CONFIG_ENV:-$HOME/.config/agent-firewall-l2/env}"
KEV_MODEL="${KEV_MODEL:-jaredpalmer/kev-0.8b}"
PID_DIR="${PID_DIR:-$HOME/.local/state/agent-firewall-l2}"
LOG_DIR="${LOG_DIR:-$HOME/.local/log/agent-firewall-l2}"

port_pid() {
  lsof -n -iTCP:"$1" -sTCP:LISTEN -t 2>/dev/null | head -1 || true
}

cmd="${1:-}"
case "$cmd" in
  start)
    mkdir -p "$PID_DIR" "$LOG_DIR"
    if [[ ! -d "$KEV_DIR" ]]; then
      echo "missing KEV_DIR=$KEV_DIR (clone jaredpalmer/kev)" >&2
      exit 1
    fi
    if [[ ! -f "$SIDECAR_DIR/.env" && ! -f "$CONFIG_ENV" ]]; then
      echo "missing $SIDECAR_DIR/.env or $CONFIG_ENV (cp .env.example .env)" >&2
      exit 1
    fi
    if [[ -z "$(port_pid 8009)" ]]; then
      echo "starting Kev on :8009 ..."
      (cd "$KEV_DIR" && nohup uv run --extra serve python -m kev.serve --run "$KEV_MODEL" --port 8009 \
        >>"$LOG_DIR/kev.log" 2>&1 & echo $! >"$PID_DIR/kev.pid")
    else
      echo "Kev already listening on :8009"
    fi
    if [[ -z "$(port_pid 8288)" ]]; then
      echo "starting sidecar on :8288 ..."
      (cd "$SIDECAR_DIR" && set -a \
        && { [[ -f "$CONFIG_ENV" ]] && source "$CONFIG_ENV" || source .env; } && set +a \
        && if [[ ! -x .venv/bin/python ]]; then python3 -m venv .venv && .venv/bin/pip install -q -U pip && .venv/bin/pip install -q -r requirements.txt; fi \
        && nohup .venv/bin/python -m uvicorn service.main:create_app --factory --host 127.0.0.1 --port 8288 \
          >>"$LOG_DIR/sidecar.log" 2>&1 & echo $! >"$PID_DIR/sidecar.pid")
    else
      echo "sidecar already listening on :8288"
    fi
    for _ in $(seq 1 60); do
      curl -sf -m 1 http://127.0.0.1:8009/v1/models >/dev/null 2>&1 && break
      sleep 2
    done
    curl -sf -m 2 http://127.0.0.1:8288/healthz >/dev/null \
      && echo "ok: Kev :8009 + sidecar :8288" \
      || { echo "started but health check failed; see $LOG_DIR" >&2; exit 1; }
    ;;
  stop)
    for port in 8288 8009; do
      pid="$(port_pid "$port")"
      if [[ -n "$pid" ]]; then
        echo "stopping :$port (pid $pid)"
        kill "$pid" 2>/dev/null || true
      fi
    done
    rm -f "$PID_DIR"/kev.pid "$PID_DIR"/sidecar.pid
    echo "stopped"
    ;;
  status)
    echo -n "Kev :8009: "
    port_pid 8009 || echo -n "down"
    echo
    echo -n "sidecar :8288: "
    port_pid 8288 || echo -n "down"
    echo
    curl -sf -m 1 http://127.0.0.1:8288/healthz 2>/dev/null && echo "healthz: ok" || echo "healthz: fail"
    ;;
  *)
    echo "usage: $0 {start|stop|status}" >&2
    exit 2
    ;;
esac
