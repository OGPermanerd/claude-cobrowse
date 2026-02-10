#!/usr/bin/env bash
set -euo pipefail

# cobrowse-status.sh: Health check all display stack components

ENV_FILE="/home/dev/.cobrowse/display.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: $ENV_FILE not found"
  echo "Please run cobrowse-setup.sh first to configure the display environment."
  exit 1
fi

source "$ENV_FILE"

# Extract display number from DISPLAY variable
DISPLAY_NUM="${DISPLAY#:}"

echo "Display Stack Health Check (DISPLAY $DISPLAY)"
echo "=============================================="
echo ""

HEALTHY=0
TOTAL=4

# Check 1: Xvfb
echo -n "1. Xvfb (display :${DISPLAY_NUM}): "
if xdpyinfo -display ":${DISPLAY_NUM}" >/dev/null 2>&1; then
  echo "OK"
  ((HEALTHY++))
else
  echo "FAIL"
fi

# Check 2: VNC Server
echo -n "2. VNC Server (port ${VNC_PORT}): "
if ss -tlnp 2>/dev/null | grep -q ":${VNC_PORT}"; then
  echo "OK"
  ((HEALTHY++))
else
  echo "FAIL"
fi

# Check 3: noVNC
echo -n "3. noVNC (port ${NOVNC_PORT}): "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${NOVNC_PORT}" 2>/dev/null || echo "000")
if [[ "$HTTP_CODE" == "200" ]]; then
  echo "OK"
  ((HEALTHY++))
else
  echo "FAIL (HTTP $HTTP_CODE)"
fi

# Check 4: Chromium CDP
echo -n "4. Chromium CDP (port ${CDP_PORT}): "
if CDP_VERSION=$(curl -s "http://localhost:${CDP_PORT}/json/version" 2>/dev/null); then
  BROWSER=$(echo "$CDP_VERSION" | grep -o '"Browser":"[^"]*"' | cut -d'"' -f4)
  echo "OK ($BROWSER)"
  ((HEALTHY++))
else
  echo "FAIL"
fi

echo ""
echo "Systemd Service States:"
echo "=============================================="
echo -n "  xvfb@${DISPLAY_NUM}: "
systemctl --user is-active "xvfb@${DISPLAY_NUM}" 2>/dev/null || echo "inactive"
echo -n "  tigervnc@${DISPLAY_NUM}: "
systemctl --user is-active "tigervnc@${DISPLAY_NUM}" 2>/dev/null || echo "inactive"
echo -n "  novnc@${DISPLAY_NUM}: "
systemctl --user is-active "novnc@${DISPLAY_NUM}" 2>/dev/null || echo "inactive"
echo -n "  chromium-cdp@${DISPLAY_NUM}: "
systemctl --user is-active "chromium-cdp@${DISPLAY_NUM}" 2>/dev/null || echo "inactive"

echo ""
echo "=============================================="
echo "Summary: ${HEALTHY}/${TOTAL} services healthy"
echo "=============================================="
echo ""

if [[ "$HEALTHY" -eq "$TOTAL" ]]; then
  exit 0
else
  exit 1
fi
