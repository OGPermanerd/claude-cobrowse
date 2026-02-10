#!/usr/bin/env bash
set -euo pipefail

# cobrowse-stop.sh: Stop all display stack services in reverse dependency order

ENV_FILE="/home/dev/.cobrowse/display.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: $ENV_FILE not found"
  echo "Please run cobrowse-setup.sh first to configure the display environment."
  exit 1
fi

source "$ENV_FILE"

# Extract display number from DISPLAY variable
DISPLAY_NUM="${DISPLAY#:}"

echo "Stopping cobrowse display stack on DISPLAY $DISPLAY..."
echo ""

# Stop in reverse dependency order (use || true to ignore errors if service not running)
echo "1. Stopping Chromium..."
systemctl --user stop "chromium-cdp@${DISPLAY_NUM}" || true

echo "2. Stopping noVNC..."
systemctl --user stop "novnc@${DISPLAY_NUM}" || true

echo "3. Stopping TigerVNC..."
systemctl --user stop "tigervnc@${DISPLAY_NUM}" || true

echo "4. Stopping Xvfb..."
systemctl --user stop "xvfb@${DISPLAY_NUM}" || true

echo ""
echo "✓ All services stopped"
echo ""
