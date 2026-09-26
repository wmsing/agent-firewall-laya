#!/usr/bin/env bash
# Long-running sidecar (for launchd KeepAlive).
set -euo pipefail
SIDECAR_DIR="${SIDECAR_DIR:-$HOME/Projects/jev_demo/agent-firewall-laya}"
CONFIG_ENV="${CONFIG_ENV:-$HOME/.config/agent-firewall-l2/env}"
cd "$SIDECAR_DIR"
if [[ ! -x .venv/bin/python ]]; then
  python3 -m venv .venv
  .venv/bin/pip install -q -U pip
  .venv/bin/pip install -q -r requirements.txt
fi
set -a
if [[ -f "$CONFIG_ENV" ]]; then source "$CONFIG_ENV"; elif [[ -f .env ]]; then source .env; else
  echo "missing $CONFIG_ENV or .env" >&2
  exit 1
fi
set +a
exec .venv/bin/python -m uvicorn service.main:create_app --factory --host 127.0.0.1 --port 8288
