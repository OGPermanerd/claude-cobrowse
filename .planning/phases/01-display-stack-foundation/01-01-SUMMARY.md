---
phase: 01-display-stack-foundation
plan: 01
subsystem: infra
tags: [xvfb, tigervnc, novnc, chromium, systemd, cdp, websockify]

# Dependency graph
requires:
  - phase: none
    provides: Initial codebase with Playwright tests
provides:
  - Systemd service templates for Xvfb, TigerVNC, noVNC, and Chromium with CDP
  - Installation script for Ubuntu 24.04 with complete display stack
  - Display configuration script for container-specific port assignments
affects: [01-02-verification, 02-api, 03-proxy, 04-container]

# Tech tracking
tech-stack:
  added: [xvfb, tigervnc-scraping-server, x11vnc, novnc, websockify, chromium-browser]
  patterns: [systemd-user-services, parameterized-service-templates, idempotent-setup-scripts]

key-files:
  created:
    - cobrowse/systemd/xvfb@.service
    - cobrowse/systemd/tigervnc@.service
    - cobrowse/systemd/novnc@.service
    - cobrowse/systemd/chromium-cdp@.service
    - cobrowse/setup/cobrowse-setup.sh
    - cobrowse/setup/configure-display.sh
  modified: []

key-decisions:
  - "Used x0vncserver from tigervnc-scraping-server for existing display export (not vncserver which creates its own X server)"
  - "Systemd service templates use %i parameter for display number (xvfb@99, tigervnc@99, etc.)"
  - "Chromium includes --user-data-dir flag to satisfy Chrome 136+ CDP security requirement"
  - "Display :99 as default with hostname-based offset calculation for future multi-container support"

patterns-established:
  - "ExecStartPre validation: All services check dependencies before starting"
  - "Restart limits: StartLimitBurst=5 with StartLimitIntervalSec=300 prevents infinite restart loops"
  - "Service dependency chain: chromium→xvfb, tigervnc→xvfb, novnc→tigervnc"
  - "Idempotent setup: All scripts safe to re-run without errors or duplicates"

# Metrics
duration: 2min
completed: 2026-02-10
---

# Phase 1 Plan 01: Display Stack Foundation Summary

**Systemd-managed display stack with Xvfb virtual framebuffer, TigerVNC x0vncserver for VNC export, noVNC web client via websockify, and Chromium with CDP on configurable display numbers**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-10T02:04:19Z
- **Completed:** 2026-02-10T02:06:16Z
- **Tasks:** 2
- **Files modified:** 6 created

## Accomplishments
- Four systemd user service templates with parameterized display numbers (@.service pattern)
- Complete idempotent installation script for Ubuntu 24.04 with all display stack packages
- Display configuration script that calculates container-specific display numbers and generates sourceable env file
- All services include ExecStartPre validation and restart limits to prevent infinite restart loops
- Chromium configured with --user-data-dir to satisfy Chrome 136+ CDP security requirement

## Task Commits

Each task was committed atomically:

1. **Task 1: Create systemd service templates for all display stack components** - `b68bbaf` (feat)
2. **Task 2: Create setup script and display configuration** - `5f97036` (feat)

## Files Created/Modified

### Systemd Service Templates
- `cobrowse/systemd/xvfb@.service` - Virtual framebuffer with 1920x1080x24 display, GLX extension, validates Xvfb binary
- `cobrowse/systemd/tigervnc@.service` - VNC server using x0vncserver for existing display export, depends on xvfb@%i
- `cobrowse/systemd/novnc@.service` - noVNC web client via websockify, depends on tigervnc@%i, validates VNC port listening
- `cobrowse/systemd/chromium-cdp@.service` - Chromium with CDP port 9222 and required user-data-dir, depends on xvfb@%i

### Setup Scripts
- `cobrowse/setup/cobrowse-setup.sh` - Installs packages, creates directories, deploys services, enables lingering, runs display config
- `cobrowse/setup/configure-display.sh` - Calculates display number from hostname hash, defaults to :99, generates display.env

## Decisions Made

**1. Used x0vncserver instead of vncserver**
- Rationale: TigerVNC's vncserver creates its own X server and cannot export an existing Xvfb display. x0vncserver (from tigervnc-scraping-server) is designed to connect to an existing display.
- Impact: Requires tigervnc-scraping-server package instead of standard tigervnc-standalone-server

**2. Systemd template services with %i parameter**
- Rationale: Enables multiple isolated display stacks on same host (xvfb@99, xvfb@100, etc.)
- Impact: Services must be instantiated with display number: `systemctl --user start xvfb@99`

**3. Chromium --user-data-dir requirement**
- Rationale: Chrome 136+ security change requires --user-data-dir when using --remote-debugging-port
- Impact: Must create /home/dev/.cobrowse/chrome-profile directory before starting chromium service

**4. Display number calculation with fallback**
- Rationale: Hostname-based hash provides container-specific display numbers for future multi-container deployments
- Impact: Phase 1 uses :99 default; Phase 4 will leverage calculated offsets for container orchestration

**5. Idempotent setup script design**
- Rationale: Must be safe to re-run for updates, troubleshooting, or container image rebuilds
- Impact: All operations use idempotent commands (apt-get install -y, mkdir -p, cp overwrites)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - all tasks completed successfully on first attempt.

## Next Phase Readiness

**Ready for next phase (01-02: Verification)**
- All systemd service templates deployed
- Setup script ready to run on test container
- Display configuration script ready to generate env file

**Prerequisites for 01-02:**
- Ubuntu 24.04 container or VM for testing
- Non-root user with sudo access (user 'dev')
- Network access for apt-get package installation

**Success indicators:**
- cobrowse-setup.sh runs without errors
- All four services start successfully with `systemctl --user start xvfb@99 tigervnc@99 novnc@99 chromium-cdp@99`
- noVNC accessible at http://localhost:6080
- CDP accessible at http://localhost:9222/json

---
*Phase: 01-display-stack-foundation*
*Completed: 2026-02-10*
