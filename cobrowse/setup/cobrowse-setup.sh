#!/bin/bash
set -euo pipefail

# Cobrowse Display Stack Setup Script
# Version: 1.0.0
# Purpose: Install Xvfb, VNC, noVNC, and Chromium with CDP on Ubuntu 24.04
# Idempotent: Safe to run multiple times

echo "=================================================="
echo "Cobrowse Display Stack Setup v1.0.0"
echo "=================================================="
echo ""

# Verify Ubuntu 24.04
DISTRO=$(lsb_release -cs 2>/dev/null || echo "unknown")
if [ "$DISTRO" != "noble" ]; then
  echo "WARNING: This script is designed for Ubuntu 24.04 (noble), detected: $DISTRO"
  echo "Continuing anyway, but packages may differ..."
  echo ""
fi

# Determine script directory for relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEMD_DIR="$SCRIPT_DIR/../systemd"

echo "Step 1: Installing packages..."
echo ""

# Update package lists
sudo apt-get update -qq

# Install display stack packages
sudo apt-get install -y \
  xvfb \
  tigervnc-scraping-server \
  x11vnc \
  novnc \
  python3-websockify \
  python3-numpy \
  x11-utils \
  xdg-utils \
  lsof \
  net-tools \
  curl \
  wget

# Install Google Chrome (chromium-browser is snap-based which has confinement issues)
echo ""
echo "Installing Google Chrome..."
if [ ! -x /usr/bin/google-chrome-stable ]; then
  wget -q -O /tmp/google-chrome-stable_current_amd64.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  sudo dpkg -i /tmp/google-chrome-stable_current_amd64.deb || sudo apt-get install -f -y
  rm -f /tmp/google-chrome-stable_current_amd64.deb
  echo "  ✓ Google Chrome installed"
else
  echo "  ✓ Google Chrome already installed"
fi

echo ""
echo "Step 2: Creating directory structure..."
echo ""

# Create cobrowse directories
mkdir -p /home/dev/.cobrowse/chrome-profile
mkdir -p /home/dev/.cobrowse/logs
mkdir -p /home/dev/.config/systemd/user

echo "  ✓ Created /home/dev/.cobrowse/chrome-profile"
echo "  ✓ Created /home/dev/.cobrowse/logs"
echo "  ✓ Created /home/dev/.config/systemd/user"

echo ""
echo "Step 3: Deploying systemd service files..."
echo ""

# Copy service templates to systemd user directory
if [ -d "$SYSTEMD_DIR" ]; then
  cp "$SYSTEMD_DIR"/*.service /home/dev/.config/systemd/user/
  echo "  ✓ Copied service templates from $SYSTEMD_DIR"

  # List deployed services
  for service in "$SYSTEMD_DIR"/*.service; do
    echo "    - $(basename "$service")"
  done
else
  echo "  ✗ ERROR: Service directory not found: $SYSTEMD_DIR"
  exit 1
fi

echo ""
echo "Step 4: Reloading systemd daemon..."
echo ""

systemctl --user daemon-reload
echo "  ✓ Systemd user daemon reloaded"

echo ""
echo "Step 5: Enabling user service persistence..."
echo ""

# Enable lingering so services persist after logout
sudo loginctl enable-linger dev
echo "  ✓ Enabled lingering for user 'dev'"

echo ""
echo "Step 6: Configuring display environment..."
echo ""

# Run display configuration script
if [ -f "$SCRIPT_DIR/configure-display.sh" ]; then
  bash "$SCRIPT_DIR/configure-display.sh"
else
  echo "  ✗ WARNING: configure-display.sh not found"
  echo "  You'll need to create /home/dev/.cobrowse/display.env manually"
fi

echo ""
echo "=================================================="
echo "Setup Complete!"
echo "=================================================="
echo ""
echo "Installed components:"
echo "  • Xvfb (virtual framebuffer)"
echo "  • TigerVNC (x0vncserver for display export)"
echo "  • x11vnc (fallback VNC server)"
echo "  • noVNC (web-based VNC client)"
echo "  • websockify (WebSocket proxy)"
echo "  • Chromium (with CDP support)"
echo ""
echo "Systemd services deployed:"
echo "  • xvfb@.service"
echo "  • tigervnc@.service"
echo "  • novnc@.service"
echo "  • chromium-cdp@.service"
echo ""
echo "Next steps:"
echo "  1. Source display configuration: source ~/.cobrowse/display.env"
echo "  2. Start services: systemctl --user start xvfb@99"
echo "  3. Check status: systemctl --user status xvfb@99"
echo ""
echo "For display :99, the full stack starts with:"
echo "  systemctl --user start xvfb@99 tigervnc@99 novnc@99 chromium-cdp@99"
echo ""
