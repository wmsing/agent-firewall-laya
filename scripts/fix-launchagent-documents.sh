#!/usr/bin/env bash
# Move jev_demo out of Documents (launchd cannot read Documents on macOS), reinstall agent.
set -euo pipefail

SRC="${HOME}/Documents/jev_demo"
DST="${HOME}/Projects/jev_demo"
REPO_SCRIPT="$(cd "$(dirname "$0")" && pwd)"

if [[ -d "$DST" ]]; then
  echo "already at $DST"
elif [[ ! -d "$SRC" ]]; then
  echo "missing $SRC — nothing to move" >&2
  exit 1
else
  mkdir -p "${HOME}/Projects"
  mv "$SRC" "$DST"
  echo "moved: $SRC -> $DST"
fi

mkdir -p "${HOME}/.config/agent-firewall-l2"
if [[ -f "$DST/agent-firewall-laya/.env" && ! -f "${HOME}/.config/agent-firewall-l2/env" ]]; then
  cp "$DST/agent-firewall-laya/.env" "${HOME}/.config/agent-firewall-l2/env"
  chmod 600 "${HOME}/.config/agent-firewall-l2/env"
  echo "copied sidecar secrets to ~/.config/agent-firewall-l2/env (for launchd)"
fi

bash "$DST/agent-firewall-laya/scripts/install-launchagent.sh"
echo "done. Reboot or: launchctl kickstart -k gui/$(id -u)/com.wmsing.agent-firewall-l2"
