#!/bin/bash
set -euo pipefail

# Cobrowse Display Configuration Script
# Purpose: Calculate container-specific display number and generate env file
# Output: /home/dev/.cobrowse/display.env with port assignments

echo "Configuring display environment..."
echo ""

# Default display number for Phase 1 (single container)
DEFAULT_DISPLAY=99

# Calculate a container-specific display offset from hostname hash
# (For future multi-container support)
HOSTNAME=$(hostname)
HASH=$(echo -n "$HOSTNAME" | md5sum | cut -c1-8)
HASH_DEC=$((0x$HASH))
OFFSET=$((HASH_DEC % 100))
CALCULATED_DISPLAY=$((90 + OFFSET))

echo "  Hostname: $HOSTNAME"
echo "  Calculated display: :$CALCULATED_DISPLAY"

# Check if calculated display is available
DISPLAY_NUM=$CALCULATED_DISPLAY
if command -v xdpyinfo >/dev/null 2>&1; then
  if DISPLAY=:$CALCULATED_DISPLAY xdpyinfo >/dev/null 2>&1; then
    echo "  Display :$CALCULATED_DISPLAY is in use, falling back to :$DEFAULT_DISPLAY"
    DISPLAY_NUM=$DEFAULT_DISPLAY
  fi
else
  # xdpyinfo not available, use default
  DISPLAY_NUM=$DEFAULT_DISPLAY
fi

# For Phase 1, always use :99 unless we detect a conflict
if [ $DISPLAY_NUM -ne $DEFAULT_DISPLAY ]; then
  echo "  Using display :$DISPLAY_NUM"
else
  DISPLAY_NUM=$DEFAULT_DISPLAY
  echo "  Using default display :$DISPLAY_NUM"
fi

# Calculate port numbers
VNC_PORT=$((5900 + DISPLAY_NUM))
NOVNC_PORT=6080
CDP_PORT=9222

echo ""
echo "  Display: :$DISPLAY_NUM"
echo "  VNC port: $VNC_PORT"
echo "  noVNC port: $NOVNC_PORT"
echo "  CDP port: $CDP_PORT"

# Write environment file
ENV_FILE="/home/dev/.cobrowse/display.env"
cat > "$ENV_FILE" <<EOF
# Cobrowse Display Environment
# Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
# Hostname: $HOSTNAME

DISPLAY=:$DISPLAY_NUM
VNC_PORT=$VNC_PORT
NOVNC_PORT=$NOVNC_PORT
CDP_PORT=$CDP_PORT
EOF

echo ""
echo "✓ Configuration written to: $ENV_FILE"
echo ""
echo "To use this configuration, source the env file:"
echo "  source $ENV_FILE"
echo ""
