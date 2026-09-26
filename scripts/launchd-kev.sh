#!/usr/bin/env bash
# Long-running Kev server (for launchd KeepAlive).
set -euo pipefail
KEV_DIR="${KEV_DIR:-$HOME/Projects/jev_demo/kev}"
KEV_MODEL="${KEV_MODEL:-jaredpalmer/kev-0.8b}"
cd "$KEV_DIR"
exec uv run --extra serve python -m kev.serve --run "$KEV_MODEL" --port 8009
