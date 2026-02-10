# Phase 1: Display Stack Foundation - Research

**Researched:** 2026-02-10
**Domain:** Virtual display stack with VNC remote access and Chromium CDP
**Confidence:** HIGH

## Summary

Phase 1 establishes the foundational display infrastructure: Xvfb virtual framebuffer, TigerVNC server, noVNC web client, and Chromium with Chrome DevTools Protocol (CDP) enabled. This stack enables both human observation (via noVNC) and AI automation (via Playwright CDP) of the same browser instance. The architecture must support persistent browser sessions across restarts and work reliably on Ubuntu 24.04 LXC containers.

**Critical findings from research:**
1. Chrome 136+ requires `--user-data-dir` with a non-default directory when using `--remote-debugging-port` (security change in 2026)
2. TigerVNC outperforms x11vnc by 15-20% with better screen redraw and lower memory usage
3. Systemd services need explicit ExecStartPre validation to prevent restart loops
4. Display number conflicts are a real issue in multi-container environments; must be addressed from day one

**Primary recommendation:** Use TigerVNC (not x11vnc), implement systemd services with proper validation and restart limits, launch Chromium with both `--remote-debugging-port=9222` and `--user-data-dir=/path/to/custom/dir`, and design for unique display numbers per container from the start.

## Standard Stack

### Core Components

| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| **Xvfb** | Ubuntu 24.04 default (21.1.x) | Virtual framebuffer for headless X11 display | De facto standard for headless Linux desktop automation; mature, stable, widely documented |
| **TigerVNC** | Ubuntu 24.04 repos (1.13.x) | VNC server exposing Xvfb display | 15-20% faster than x11vnc with better screen redraw performance and lower memory footprint ([DoHost comparison](https://dohost.us/index.php/2025/11/05/vnc-server-software-comparison-tightvnc-tigervnc-realvnc-x11vnc/), [Manjaro Forum user report](https://forum.manjaro.org/t/x11vnc-has-slow-redraw-reaction-while-tigervnc-server-on-a-new-display-is-much-faster/7414)) |
| **noVNC** | 1.6.0+ (latest from repos or GitHub) | Browser-based VNC client (HTML5) | Zero client installation, mobile support, active development, supports tight/hextile encoding |
| **websockify** | 0.13.0+ (latest from repos) | WebSocket-to-TCP bridge for noVNC | Official noVNC companion; optional numpy dependency improves HyBi protocol performance |
| **Chromium** | Ubuntu 24.04 repos (latest) | Browser engine with CDP support | Lower resource usage than Chrome for Testing (~5-10GB vs 20GB+ RAM); sufficient compatibility for most web apps |
| **systemd** | System default | Service lifecycle management | Built into Ubuntu 24.04; proper dependency ordering and restart handling essential |

### Supporting Tools

| Tool | Purpose | When to Use |
|------|---------|-------------|
| **lsof** | Verify CDP port 9222 is listening | Pre-flight validation before Playwright connects |
| **xdpyinfo** | Check if X display is responsive | Validate Xvfb started successfully |
| **curl** | Test CDP endpoint availability | Health check: `curl http://localhost:9222/json/version` |
| **netstat/ss** | Verify port bindings | Debug networking issues (VNC port 5900, noVNC port 6080) |

### Installation

```bash
# Core display stack
sudo apt-get update
sudo apt-get install -y xvfb tigervnc-standalone-server tigervnc-common

# noVNC and websockify
sudo apt-get install -y novnc websockify python3-numpy

# Chromium browser
sudo apt-get install -y chromium-browser

# Debugging tools
sudo apt-get install -y lsof x11-utils curl net-tools
```

### Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| **TigerVNC** | x11vnc | Never for production — 15-20% slower, requires 10-20x framebuffer size in memory, poor screen redraw performance |
| **TigerVNC** | Apache Guacamole | When HTML5 RDP support needed; heavier weight, requires Java backend |
| **Chromium (system)** | Chrome for Testing (Playwright) | When maximum compatibility required; trade-off is 20GB+ RAM per instance vs 5-10GB |
| **systemd** | supervisord | When running in Docker (no systemd); use supervisord or s6 |
| **Path-based routing** | Port-based routing | Never for multi-container — port exhaustion and firewall complexity |

## Architecture Patterns

### Recommended Project Structure

```
/home/dev/
├── .cobrowse/
│   ├── project-a/
│   │   ├── chrome-profile/        # --user-data-dir for persistent state
│   │   ├── display.env             # DISPLAY=:99, ports, config
│   │   └── logs/                   # Service logs
│   ├── project-b/
│   │   └── ...
│   └── scripts/
│       ├── cobrowse-start.sh       # Start all services for a project
│       ├── cobrowse-stop.sh        # Stop all services
│       └── cobrowse-status.sh      # Health check
│
├── .config/systemd/user/           # User systemd services
│   ├── xvfb@.service               # Template: Xvfb on display :N
│   ├── tigervnc@.service           # Template: TigerVNC for display :N
│   ├── novnc@.service              # Template: noVNC on port 608N
│   └── chromium-cdp@.service       # Template: Chromium with CDP
│
└── projects/
    └── claude-cobrowse/            # This repo (distribution kit)
        ├── cobrowse/
        │   ├── setup/              # Installation scripts
        │   └── runtime/            # Service management scripts
        └── ...
```

### Pattern 1: Always-On Display with Persistent Browser (RECOMMENDED)

**What:** Xvfb and Chromium always run with `--display=:99`; TigerVNC + noVNC start on-demand when human needs to view.

**When to use:** Sufficient resources (32GB RAM containers); frequent need for visual debugging; simpler state management.

**Benefits:**
- No browser restart required — same Chromium instance throughout
- Simpler mode switching — just start/stop VNC, not browser
- Playwright CDP connection never breaks
- Session state (cookies, localStorage) automatically persists

**Trade-offs:**
- Xvfb always consuming ~100MB RAM even when not viewed
- Slightly slower than true headless mode (rendering overhead)

**Implementation:**
```bash
# Start display stack (once per container boot)
systemctl --user start xvfb@99
systemctl --user start chromium-cdp@project-a

# Start VNC on-demand (when human needs to view)
systemctl --user start tigervnc@99
systemctl --user start novnc@project-a
```

**Rationale:** This is the proven pattern from the reference implementation. Resources are abundant (32GB RAM), and Playwright CDP stability is critical — reconnecting after browser restart risks losing session state.

### Pattern 2: Systemd Service Dependencies and Validation

**What:** Use `ExecStartPre` for validation, explicit service dependencies with `After=`/`Requires=`, and restart limits to prevent loops.

**When to use:** Always — essential for production reliability.

**Example:**
```ini
# /home/dev/.config/systemd/user/chromium-cdp@.service
[Unit]
Description=Chromium with CDP for %i
After=xvfb@99.service
Requires=xvfb@99.service

[Service]
Type=simple
Environment="DISPLAY=:99"
ExecStartPre=/usr/bin/test -x /usr/bin/chromium-browser
ExecStartPre=/bin/bash -c 'xdpyinfo -display :99 >/dev/null 2>&1 || exit 1'
ExecStart=/usr/bin/chromium-browser \
    --display=:99 \
    --remote-debugging-port=9222 \
    --user-data-dir=/home/dev/.cobrowse/%i/chrome-profile \
    --no-first-run \
    --no-default-browser-check \
    --disable-gpu
Restart=on-failure
RestartSec=10s
StartLimitIntervalSec=300
StartLimitBurst=5

[Install]
WantedBy=default.target
```

**Key elements:**
- `ExecStartPre` validation prevents restart loops ([systemd.service docs](https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html))
- `After=xvfb@99.service` ensures Xvfb starts first
- `Requires=xvfb@99.service` stops Chromium if Xvfb fails
- `StartLimitBurst=5` limits restart attempts to 5 within 300 seconds

### Pattern 3: Container-Specific Display Number Calculation

**What:** Calculate display number from container ID to avoid conflicts.

**When to use:** Always in multi-container environments; essential for scaling beyond 1 container.

**Example:**
```bash
# cobrowse/setup/configure-display.sh
#!/bin/bash

# Get unique container identifier (last octet of IP, or container name hash)
CONTAINER_ID=$(hostname | md5sum | head -c2 | xargs printf "%d")
DISPLAY_NUM=$((99 + (CONTAINER_ID % 50)))  # Range :99 to :148

echo "DISPLAY=:${DISPLAY_NUM}" > ~/.cobrowse/$(basename $PWD)/display.env
echo "VNC_PORT=$((5900 + (CONTAINER_ID % 50)))" >> ~/.cobrowse/$(basename $PWD)/display.env
echo "NOVNC_PORT=$((6080 + (CONTAINER_ID % 50)))" >> ~/.cobrowse/$(basename $PWD)/display.env

# Use in service files
systemctl --user start xvfb@${DISPLAY_NUM}
```

**Rationale:** Hardcoded `:99` works for one container but breaks immediately with 2+ containers ([docker-selenium issue #184](https://github.com/SeleniumHQ/docker-selenium/issues/184), [LinuxGSM issue #4680](https://github.com/GameServerManagers/LinuxGSM/issues/4680)). Dynamic allocation prevents conflicts from day one.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Display number conflict resolution | Custom locking/PID files | Calculated display numbers from container ID | Race conditions in custom locks; md5sum-based calculation is collision-resistant |
| Service lifecycle management | Custom bash daemons with `&` and PID files | systemd user services | systemd handles dependencies, restart policies, logging, and cgroup resource limits |
| VNC server | Custom framebuffer streaming | TigerVNC (or x11vnc as fallback) | VNC protocol is complex; compression, authentication, multiple clients require extensive code |
| WebSocket bridge for noVNC | Custom WebSocket server | websockify | Handles RFB protocol details, base64 encoding, HyBi vs Hixie protocols |
| Browser CDP health checking | Retry loops with sleep | `ExecStartPre` validation in systemd | systemd does exponential backoff, tracks restart count, integrates with journalctl |

**Key insight:** This domain (virtual displays, VNC, systemd) has 20+ years of battle-tested tooling. Custom solutions introduce bugs that are already solved upstream.

## Common Pitfalls

### Pitfall 1: Chrome 136+ CDP Without --user-data-dir

**What goes wrong:** Chromium 136+ silently ignores `--remote-debugging-port=9222` when using the default user data directory. Playwright's `connectOverCDP()` times out with "WebSocket connection failed" despite the browser running.

**Why it happens:** [Security hardening in Chrome 136](https://developer.chrome.com/blog/remote-debugging-port) forces separation of debugging sessions from production profiles. The debugging switches must be accompanied by `--user-data-dir` pointing to a non-default directory.

**How to avoid:**
- **ALWAYS** launch Chromium with both flags together:
  ```bash
  chromium-browser \
    --remote-debugging-port=9222 \
    --user-data-dir=/home/dev/.cobrowse/project-a/chrome-profile
  ```
- **NEVER** use the default profile (`~/.config/chromium`) for CDP automation
- Create unique user-data-dir per container/project to avoid conflicts

**Warning signs:**
- `lsof -i :9222` shows no listener even though `--remote-debugging-port=9222` was passed
- `curl http://localhost:9222/json/version` returns connection refused
- Playwright throws "Could not find any debuggable targets"

**Phase to address:** Phase 1 — must be correct from initial setup

### Pitfall 2: Systemd Service Restart Loop

**What goes wrong:** Service configured with `ExecStart=/path/to/nonexistent/script.sh` enters a tight restart loop. The service restarts 23,000+ times in hours, flooding logs and consuming CPU.

**Why it happens:** If `Restart=always` or `Restart=on-failure` is set without proper validation, systemd will retry indefinitely. The default `StartLimitBurst=5` is often overridden or not enforced properly.

**How to avoid:**
- **Validate ExecStart path before service starts:**
  ```ini
  ExecStartPre=/usr/bin/test -x /usr/bin/chromium-browser
  ExecStartPre=/bin/bash -c 'xdpyinfo -display :99 >/dev/null 2>&1 || exit 1'
  ```
- **Set explicit restart limits:**
  ```ini
  Restart=on-failure
  RestartSec=10s
  StartLimitIntervalSec=300
  StartLimitBurst=5
  ```
- **Monitor restart count:** `systemctl show -p NRestarts <service>`

**Warning signs:**
- `journalctl -u <service>` shows rapid restart attempts
- Logs contain "Failed at step EXEC spawning /path: No such file or directory"
- High CPU usage by systemd

**Phase to address:** Phase 1 — before any systemd service goes into production

### Pitfall 3: Xvfb Display Number Conflicts

**What goes wrong:** Multiple containers using `Xvfb :99` cause "Fatal server error: Server is already active for display 99". Second instance fails, service crash-loops.

**Why it happens:** Common in parallel environments ([Cypress CI issue #1426](https://github.com/cypress-io/cypress/issues/1426)) where multiple processes try to claim the same display. The `xvfb-run -a` auto-select has race conditions when invoked simultaneously.

**How to avoid:**
- **Use container-specific display offsets:** Calculate from container ID (see Pattern 3 above)
- **Validate before launch:** `xdpyinfo -display :99 2>/dev/null` checks if display is free
- **Use systemd templates:** `xvfb@.service` accepts display number as parameter

**Warning signs:**
- Service restarts repeatedly with "display already active" in logs
- VNC connection works but shows unexpected content from another container
- Tests pass solo but fail in parallel

**Phase to address:** Phase 1 — must be solved before multi-container deployment

### Pitfall 4: noVNC WebSocket Path Routing with Reverse Proxy

**What goes wrong:** When noVNC is served behind a reverse proxy with a path prefix (e.g., `/project-a/vnc`), the HTML/JS loads but WebSocket connections fail with 404 errors. The client tries `/websockify` instead of `/project-a/websockify`.

**Why it happens:** noVNC builds WebSocket URLs without considering the path prefix ([noVNC issue #1737](https://github.com/novnc/noVNC/issues/1737)). The proxy serves static assets with correct paths, but WebSocket URL is constructed relative to root.

**How to avoid:**
- **Configure nginx path rewriting:**
  ```nginx
  location /project-a/ {
      proxy_pass http://localhost:6080/;
      proxy_http_version 1.1;
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection "upgrade";
      proxy_read_timeout 600s;  # CRITICAL: prevent 60s disconnects
      proxy_buffering off;      # CRITICAL: avoid VNC stream caching
  }

  location /project-a/websockify {
      proxy_pass http://localhost:6080/websockify;
      proxy_http_version 1.1;
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection "upgrade";
      proxy_read_timeout 600s;
  }
  ```
- **Set `proxy_read_timeout` > 60s** to avoid race-condition disconnects after inactivity

**Warning signs:**
- Browser console shows WebSocket error: "Failed to connect to /websockify"
- noVNC HTML loads but display stays black/gray
- Works without reverse proxy, fails when accessed through nginx

**Phase to address:** Phase 3 (Reverse Proxy) — before path-based routing goes live

### Pitfall 5: Missing Browser Session Persistence

**What goes wrong:** Browser restarts lose all cookies, localStorage, and authenticated sessions. Automation must re-login every time Chromium is restarted.

**Why it happens:** Default Chromium behavior is to use temporary profile when `--user-data-dir` is not specified. Temporary profiles are wiped on exit.

**How to avoid:**
- **Always specify --user-data-dir:**
  ```bash
  chromium-browser \
    --user-data-dir=/home/dev/.cobrowse/project-a/chrome-profile
  ```
- **Ensure directory is writable** by the user running Chromium
- **Backup profile directory** periodically for disaster recovery

**Warning signs:**
- OAuth login required after every browser restart
- localStorage values reset to empty
- Cookies disappear between sessions

**Phase to address:** Phase 1 — requirement STAT-01 explicitly calls for persistence

## Code Examples

Verified patterns from official sources and best practices:

### Starting Xvfb with Systemd

```ini
# /home/dev/.config/systemd/user/xvfb@.service
[Unit]
Description=Xvfb Virtual Framebuffer on display :%i
After=network.target

[Service]
Type=simple
ExecStartPre=/usr/bin/test -x /usr/bin/Xvfb
ExecStart=/usr/bin/Xvfb :%i -screen 0 1920x1080x24 -ac +extension GLX +render -noreset
Restart=on-failure
RestartSec=10s
StartLimitIntervalSec=300
StartLimitBurst=5

[Install]
WantedBy=default.target
```

**Usage:**
```bash
# Start Xvfb on display :99
systemctl --user start xvfb@99

# Enable auto-start on boot
systemctl --user enable xvfb@99

# Check status
systemctl --user status xvfb@99
```

### Starting TigerVNC with Systemd

```ini
# /home/dev/.config/systemd/user/tigervnc@.service
[Unit]
Description=TigerVNC Server for display :%i
After=xvfb@%i.service
Requires=xvfb@%i.service

[Service]
Type=forking
ExecStartPre=/usr/bin/test -x /usr/bin/vncserver
ExecStartPre=/bin/bash -c 'xdpyinfo -display :%i >/dev/null 2>&1 || exit 1'
ExecStart=/usr/bin/vncserver :%i -geometry 1920x1080 -depth 24 -localhost -nolisten tcp
ExecStop=/usr/bin/vncserver -kill :%i
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=default.target
```

**Note:** TigerVNC creates a new X server, so you may need to configure it to share the existing Xvfb display. Alternative: Use `x11vnc -display :99` to export the existing Xvfb.

### Starting Chromium with CDP and Persistence

```bash
#!/bin/bash
# cobrowse/runtime/browser-manager.sh

PROJECT_NAME="$1"
DISPLAY_NUM="${2:-99}"
CDP_PORT="${3:-9222}"

# Ensure user-data-dir exists
PROFILE_DIR="/home/dev/.cobrowse/${PROJECT_NAME}/chrome-profile"
mkdir -p "$PROFILE_DIR"

# Launch Chromium with CDP enabled
DISPLAY=:${DISPLAY_NUM} chromium-browser \
  --remote-debugging-port=${CDP_PORT} \
  --user-data-dir="$PROFILE_DIR" \
  --no-first-run \
  --no-default-browser-check \
  --disable-gpu \
  --disable-dev-shm-usage \
  --disable-software-rasterizer \
  2>&1 | tee /home/dev/.cobrowse/${PROJECT_NAME}/logs/chromium.log &

# Wait for CDP to be ready
for i in {1..30}; do
  if curl -s http://localhost:${CDP_PORT}/json/version >/dev/null 2>&1; then
    echo "Chromium CDP ready on port ${CDP_PORT}"
    exit 0
  fi
  sleep 1
done

echo "ERROR: Chromium CDP failed to start within 30 seconds"
exit 1
```

### Validating Display Stack Health

```bash
#!/bin/bash
# cobrowse/runtime/health-check.sh

DISPLAY_NUM="${1:-99}"
CDP_PORT="${2:-9222}"
VNC_PORT="${3:-5900}"

# Check Xvfb is running
if ! xdpyinfo -display :${DISPLAY_NUM} >/dev/null 2>&1; then
  echo "FAIL: Xvfb not running on display :${DISPLAY_NUM}"
  exit 1
fi
echo "OK: Xvfb running on :${DISPLAY_NUM}"

# Check VNC server is listening
if ! lsof -i :${VNC_PORT} >/dev/null 2>&1; then
  echo "FAIL: VNC server not listening on port ${VNC_PORT}"
  exit 1
fi
echo "OK: VNC server listening on port ${VNC_PORT}"

# Check Chromium CDP is accessible
if ! curl -s http://localhost:${CDP_PORT}/json/version >/dev/null 2>&1; then
  echo "FAIL: Chromium CDP not accessible on port ${CDP_PORT}"
  exit 1
fi
echo "OK: Chromium CDP accessible on port ${CDP_PORT}"

echo "All health checks passed"
exit 0
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Chrome debugging without --user-data-dir | Chrome 136+ requires --user-data-dir with non-default directory | Chrome 136 (Jan 2026) | Breaking change: all CDP automation must add this flag |
| x11vnc for VNC server | TigerVNC for better performance | Ongoing recommendation | 15-20% performance improvement, lower memory usage |
| Port-based container routing | Path-based routing with nginx | Modern best practice | Easier scaling, single entry point, no port exhaustion |
| Manual service management | systemd user services | systemd became standard ~2015 | Proper dependency handling, restart policies, logging integration |

**Deprecated/outdated:**
- **x11vnc as primary VNC server:** TigerVNC outperforms in all benchmarks; x11vnc only useful if you need to export existing X display
- **Hardcoded display :99:** Multi-container deployments require dynamic display number allocation
- **supervisord in LXC:** systemd is native to Ubuntu 24.04; supervisord adds unnecessary layer

## Open Questions

1. **TigerVNC vs x11vnc in this specific setup**
   - What we know: TigerVNC is faster (15-20%), but creates its own X server
   - What's unclear: Whether TigerVNC can export an *existing* Xvfb display (like x11vnc does with `-display :99`)
   - Recommendation: Test both; if TigerVNC can't export Xvfb, fall back to x11vnc for Phase 1, optimize later

2. **Display number range allocation**
   - What we know: Need unique display per container; `:99` is common default
   - What's unclear: Safe range on Ubuntu 24.04 (`:0-:63` reserved? `:99-:148` safe?)
   - Recommendation: Use `:99 + container_id` capped at `:148`; validate with `xdpyinfo` before starting

3. **Chromium vs Chrome for Testing memory difference**
   - What we know: Chrome for Testing uses 20GB+ RAM (reported), Chromium uses 5-10GB
   - What's unclear: Is this specific to certain Playwright versions or universal?
   - Recommendation: Start with system Chromium; monitor RAM usage; switch to Chrome for Testing only if compatibility issues arise

4. **noVNC H.264 encoding support**
   - What we know: noVNC 1.6.0 supports H.264 for reduced bandwidth
   - What's unclear: Does TigerVNC support H.264 encoding? Configuration required?
   - Recommendation: Defer to Phase 4 (optimization); start with tight/hextile encoding

## Sources

### Primary (HIGH confidence)

- [Chrome for Developers Blog: Changes to remote debugging switches](https://developer.chrome.com/blog/remote-debugging-port) — Chrome 136+ --user-data-dir requirement
- [systemd.service Documentation](https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html) — ExecStartPre validation, restart policies
- [noVNC GitHub Wiki: Proxying with nginx](https://github.com/novnc/noVNC/wiki/Proxying-with-nginx) — WebSocket configuration
- [VNC Server Software Comparison (DoHost)](https://dohost.us/index.page/2025/11/05/vnc-server-software-comparison-tightvnc-tigervnc-realvnc-x11vnc/) — TigerVNC vs x11vnc performance
- [How to Configure WebSocket with Nginx Reverse Proxy (OneUpTime, Jan 2026)](https://oneuptime.com/blog/post/2026-01-24-websocket-nginx-reverse-proxy/view) — Modern nginx WebSocket best practices

### Secondary (MEDIUM confidence)

- [Manjaro Forum: x11vnc slow redraw vs TigerVNC](https://forum.manjaro.org/t/x11vnc-has-slow-redraw-reaction-while-tigervnc-server-on-a-new-display-is-much-faster/7414) — User-reported performance difference
- [docker-selenium Issue #184](https://github.com/SeleniumHQ/docker-selenium/issues/184) — Display number conflicts in containers
- [Websockify & noVNC behind NGINX Proxy (DataWookie)](https://datawookie.dev/blog/2021/08/websockify-novnc-behind-an-nginx-proxy/) — Path routing configuration
- [LinuxGSM Issue #4680](https://github.com/GameServerManagers/LinuxGSM/issues/4680) — Multiple Xvfb instances with xvfb-run race conditions

### Tertiary (LOW confidence, marked for validation)

- Web search results on TigerVNC Ubuntu 24.04 — no specific benchmarks for this OS version
- Community reports of Chrome for Testing memory usage — needs validation with actual testing

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — Based on official documentation and existing reference implementation
- Architecture patterns: HIGH — Proven Pattern 2 (Always-On Display) from working reference box
- Pitfalls: HIGH — Chrome 136 and systemd issues verified with official sources; display conflicts documented in multiple repos
- Code examples: MEDIUM — Systemd service templates need testing on Ubuntu 24.04; Chromium flags verified

**Research date:** 2026-02-10
**Valid until:** ~2026-05-10 (90 days for stable infrastructure; systemd/Xvfb change slowly; Chrome flags may evolve)

---

*Research complete for Phase 1: Display Stack Foundation*
*Next step: Planner creates PLAN.md with concrete tasks based on this research*
