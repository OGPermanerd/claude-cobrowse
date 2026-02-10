#!/usr/bin/env bash
set -euo pipefail

# cobrowse-start.sh: Start all display stack services in dependency order

ENV_FILE="/home/dev/.cobrowse/display.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: $ENV_FILE not found"
  echo "Please run cobrowse-setup.sh first to configure the display environment."
  exit 1
fi

source "$ENV_FILE"

# Extract display number from DISPLAY variable (e.g., ":99" -> "99")
DISPLAY_NUM="${DISPLAY#:}"

echo "Starting cobrowse display stack on DISPLAY $DISPLAY..."
echo "VNC port: $VNC_PORT, noVNC port: $NOVNC_PORT, CDP port: $CDP_PORT"
echo ""

# Wait-for-ready helper function
wait_for() {
  local desc="$1" cmd="$2" timeout="$3"
  for i in $(seq 1 "$timeout"); do
    if eval "$cmd" >/dev/null 2>&1; then
      echo "  OK: $desc"
      return 0
    fi
    sleep 1
  done
  echo "  FAIL: $desc (timeout after ${timeout}s)"
  return 1
}

# Start services in dependency order
echo "1. Starting Xvfb..."
systemctl --user start "xvfb@${DISPLAY_NUM}"
if ! wait_for "Xvfb responding on display :${DISPLAY_NUM}" "xdpyinfo -display :${DISPLAY_NUM}" 10; then
  echo "ERROR: Xvfb failed to start"
  journalctl --user -u "xvfb@${DISPLAY_NUM}" --no-pager -n 20
  exit 1
fi

echo ""
echo "2. Starting TigerVNC..."
systemctl --user start "tigervnc@${DISPLAY_NUM}"
if ! wait_for "VNC server listening on port ${VNC_PORT}" "ss -tlnp | grep -q :${VNC_PORT}" 10; then
  echo "ERROR: TigerVNC failed to start"
  journalctl --user -u "tigervnc@${DISPLAY_NUM}" --no-pager -n 20
  exit 1
fi

echo ""
echo "3. Starting noVNC..."
systemctl --user start "novnc@${DISPLAY_NUM}"
if ! wait_for "noVNC listening on port ${NOVNC_PORT}" "ss -tlnp | grep -q :${NOVNC_PORT}" 10; then
  echo "ERROR: noVNC failed to start"
  journalctl --user -u "novnc@${DISPLAY_NUM}" --no-pager -n 20
  exit 1
fi

echo ""
echo "4. Starting Chromium with CDP..."
systemctl --user start "chromium-cdp@${DISPLAY_NUM}"
if ! wait_for "Chromium CDP responding on port ${CDP_PORT}" "curl -s http://localhost:${CDP_PORT}/json/version" 30; then
  echo "ERROR: Chromium failed to start"
  journalctl --user -u "chromium-cdp@${DISPLAY_NUM}" --no-pager -n 20
  exit 1
fi

echo ""
echo "=========================================="
echo "✓ All services started successfully"
echo "=========================================="
echo ""

# Run status check
bash "$(dirname "$0")/cobrowse-status.sh"

echo ""
echo "Access URLs:"
echo "  noVNC: http://$(hostname -I | awk '{print $1}'):${NOVNC_PORT}/vnc.html?autoconnect=true"
echo "  CDP:   http://localhost:${CDP_PORT}/json/version"
echo ""
