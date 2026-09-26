#!/usr/bin/env bash
# Two KeepAlive LaunchAgents (Kev + sidecar). Run after fix-launchagent-documents or from ~/Projects.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
BIN_DIR="${HOME}/.local/bin"
LOG_DIR="${HOME}/.local/log/agent-firewall-l2"
CONFIG_DIR="${HOME}/.config/agent-firewall-l2"
LA="${HOME}/Library/LaunchAgents"
GUI_UID="$(id -u)"

if [[ -d "${HOME}/Projects/jev_demo/kev" ]]; then
  KEV_DIR="${HOME}/Projects/jev_demo/kev"
  SIDECAR_DIR="${HOME}/Projects/jev_demo/agent-firewall-laya"
else
  KEV_DIR="${HOME}/Documents/jev_demo/kev"
  SIDECAR_DIR="${REPO}"
  echo "warning: not under ~/Projects — launchd may fail on Documents" >&2
fi

mkdir -p "$BIN_DIR" "$LOG_DIR" "$CONFIG_DIR"
install -m 755 "$REPO/scripts/l2-stack.sh" "$BIN_DIR/agent-firewall-l2-stack.sh"
install -m 755 "$REPO/scripts/launchd-kev.sh" "$BIN_DIR/agent-firewall-l2-kev.sh"
install -m 755 "$REPO/scripts/launchd-sidecar.sh" "$BIN_DIR/agent-firewall-l2-sidecar.sh"

if [[ -f "$SIDECAR_DIR/.env" && ! -f "$CONFIG_DIR/env" ]]; then
  cp "$SIDECAR_DIR/.env" "$CONFIG_DIR/env"
  chmod 600 "$CONFIG_DIR/env"
fi

if [[ -d "$SIDECAR_DIR" ]]; then
  (cd "$SIDECAR_DIR" && [[ -x .venv/bin/python ]] || (python3 -m venv .venv && .venv/bin/pip install -q -U pip && .venv/bin/pip install -q -r requirements.txt))
fi

bootout_plist() {
  local plist=$1
  launchctl bootout "gui/${GUI_UID}" "$plist" 2>/dev/null || true
}
bootout_plist "$LA/com.wmsing.agent-firewall-l2.plist"
bootout_plist "$LA/com.wmsing.agent-firewall-l2.kev.plist"
bootout_plist "$LA/com.wmsing.agent-firewall-l2.sidecar.plist"

load_plist() {
  local plist=$1 label=$2
  if launchctl bootstrap "gui/${GUI_UID}" "$plist" 2>/dev/null; then
    return 0
  fi
  launchctl enable "gui/${GUI_UID}/${label}" 2>/dev/null || true
  launchctl kickstart -k "gui/${GUI_UID}/${label}" 2>/dev/null || launchctl bootstrap "gui/${GUI_UID}" "$plist"
}

write_plist() {
  local label=$1 out=$2 name=$3
  cat >"$out" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${label}</string>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>${LOG_DIR}/${name}.log</string>
  <key>StandardErrorPath</key>
  <string>${LOG_DIR}/${name}.err.log</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>${BIN_DIR}:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
    <key>KEV_DIR</key>
    <string>${KEV_DIR}</string>
    <key>SIDECAR_DIR</key>
    <string>${SIDECAR_DIR}</string>
    <key>CONFIG_ENV</key>
    <string>${CONFIG_DIR}/env</string>
  </dict>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>${BIN_DIR}/agent-firewall-l2-${name}.sh</string>
  </array>
</dict>
</plist>
EOF
}

write_plist com.wmsing.agent-firewall-l2.kev "$LA/com.wmsing.agent-firewall-l2.kev.plist" kev
write_plist com.wmsing.agent-firewall-l2.sidecar "$LA/com.wmsing.agent-firewall-l2.sidecar.plist" sidecar
rm -f "$LA/com.wmsing.agent-firewall-l2.plist"

load_plist "$LA/com.wmsing.agent-firewall-l2.kev.plist" com.wmsing.agent-firewall-l2.kev
load_plist "$LA/com.wmsing.agent-firewall-l2.sidecar.plist" com.wmsing.agent-firewall-l2.sidecar

echo "installed KeepAlive agents: kev + sidecar"
echo "wait ~2min then: bash $BIN_DIR/agent-firewall-l2-stack.sh status"
