---
phase: 01-display-stack-foundation
verified: 2026-02-10T03:10:00Z
status: gaps_found
score: 4/5 must-haves verified
gaps:
  - truth: "Setup script installs entire stack on fresh Ubuntu 24.04 container in under 5 minutes"
    status: failed
    reason: "cobrowse-setup.sh has a bash syntax error at line 56-57 that prevents it from running on a fresh system"
    artifacts:
      - path: "cobrowse/setup/cobrowse-setup.sh"
        issue: "Line 56 'fi \\' with line 57 '  net-tools' creates 'fi net-tools' after line continuation, which is a bash syntax error. The net-tools package was originally in the apt-get install list but was stranded when the Chrome install block was inserted in commit 2c93688."
    missing:
      - "Remove the backslash from line 56 (change 'fi \\' to 'fi') and move 'net-tools' back into the apt-get install list (lines 33-44) or add it as a separate apt-get install command"
  - truth: "novnc@.service missing StartLimitIntervalSec and StartLimitBurst"
    status: partial
    reason: "DISP-05 requires proper restart limits on all services. novnc@.service has Restart=on-failure but lacks StartLimitIntervalSec and StartLimitBurst that the other 3 services have."
    artifacts:
      - path: "cobrowse/systemd/novnc@.service"
        issue: "Missing StartLimitIntervalSec=300 and StartLimitBurst=5 that xvfb@, tigervnc@, and chromium-cdp@ all have"
    missing:
      - "Add StartLimitIntervalSec=300 and StartLimitBurst=5 to novnc@.service [Service] section"
---

# Phase 1: Display Stack Foundation Verification Report

**Phase Goal:** Browser visible via noVNC in laptop browser, persistent session across restarts
**Verified:** 2026-02-10T03:10:00Z
**Status:** gaps_found
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User opens noVNC URL in laptop browser and sees Chromium running on virtual display | VERIFIED | noVNC returns HTTP 200 on port 6080. Xvfb responds on display :161. Chrome running via google-chrome-stable on display :161. All 4 systemd services active. User confirmed in 01-02-SUMMARY.md. |
| 2 | User can click and type in Chromium via noVNC interface | VERIFIED | noVNC websockify connects to VNC port 6061 (confirmed via ss -tlnp). x0vncserver running with -SecurityTypes None (no auth barrier). User confirmed mouse/keyboard interaction in 01-02-SUMMARY.md. |
| 3 | Chromium CDP debugger accessible at localhost:9222 from container shell | VERIFIED | `curl -s http://localhost:9222/json/version` returns valid JSON with Browser: "Chrome/144.0.7559.132" and webSocketDebuggerUrl. chromium-cdp@.service includes --remote-debugging-port=9222. |
| 4 | Browser session survives service restart (cookies and localStorage persist via --user-data-dir) | VERIFIED | chromium-cdp@.service includes both --user-data-dir=/home/dev/.cobrowse/chrome-profile and --restore-last-session. Chrome profile directory exists with 156M of data. User confirmed session persistence after stop/start cycle in 01-02-SUMMARY.md. |
| 5 | Setup script installs entire stack on fresh Ubuntu 24.04 container in under 5 minutes | FAILED | cobrowse-setup.sh has a bash syntax error at lines 56-57. The `fi \` continuation + `  net-tools` on next line produces `fi net-tools` which is invalid bash. Script will abort with syntax error on any fresh run. See Gaps Summary. |

**Score:** 4/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `cobrowse/systemd/xvfb@.service` | Xvfb virtual framebuffer service template | VERIFIED | 15 lines. Runs Xvfb with 1920x1080x24, GLX extension, -noreset. ExecStartPre validates binary. Has restart limits. Uses %i template parameter for display number. Deployed to ~/.config/systemd/user/ (identical to source). |
| `cobrowse/systemd/tigervnc@.service` | TigerVNC x0vncserver service template | VERIFIED | 18 lines. Uses x0vncserver (not vncserver). Depends on xvfb@%i. Sources display.env for VNC_PORT. ExecStartPre waits for X display. Has restart limits. Deployed identical to source. |
| `cobrowse/systemd/novnc@.service` | noVNC websockify service template | PARTIAL | 16 lines. Runs websockify connecting to VNC port. Depends on tigervnc@%i. Sources display.env. ExecStartPre validates VNC port listening. Deployed identical to source. Missing StartLimitIntervalSec and StartLimitBurst (other 3 services have these). |
| `cobrowse/systemd/chromium-cdp@.service` | Chromium with CDP debugging | VERIFIED | 19 lines. Uses google-chrome-stable with --remote-debugging-port=9222, --user-data-dir, --restore-last-session, --no-first-run, --disable-gpu, --window-size=1920,1080. Depends on xvfb@%i. Two ExecStartPre checks (binary + X display). Has restart limits. Deployed identical to source. |
| `cobrowse/setup/cobrowse-setup.sh` | Idempotent installation script | FAILED | 143 lines. Substantive implementation with 6-step process: apt-get, directories, service deploy, daemon-reload, lingering, display config. BUT has bash syntax error at line 56-57: `fi \` + `  net-tools` creates invalid continuation. Would abort on fresh system. See gap analysis. |
| `cobrowse/setup/configure-display.sh` | Display number calculator | VERIFIED | 74 lines. Calculates display from hostname hash (md5sum), falls back to :99. Generates /home/dev/.cobrowse/display.env with DISPLAY, VNC_PORT, NOVNC_PORT, CDP_PORT. Env file exists and is being consumed by all services and runtime scripts. |
| `cobrowse/runtime/cobrowse-start.sh` | Start all services script | VERIFIED | 86 lines. Sources display.env. Starts services in dependency order (Xvfb -> TigerVNC -> noVNC -> Chrome). wait_for() function with configurable timeouts. Runs status check after startup. Shows access URLs. Executable. |
| `cobrowse/runtime/cobrowse-stop.sh` | Stop all services script | VERIFIED | 37 lines. Sources display.env. Stops in reverse dependency order. Uses `|| true` for graceful handling of already-stopped services. Executable. |
| `cobrowse/runtime/cobrowse-status.sh` | Health check script | VERIFIED | 90 lines. Sources display.env. Checks 4 components: Xvfb (xdpyinfo), VNC (ss port check), noVNC (curl HTTP), Chrome CDP (curl /json/version with browser version extraction). Reports systemd service states. Returns exit code 0/1 based on health. Executable. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| xvfb@.service | Xvfb binary | ExecStart=/usr/bin/Xvfb :%i | WIRED | Binary exists, ExecStartPre validates it, service is active |
| tigervnc@.service | xvfb@%i.service | Requires= + After= | WIRED | Explicit systemd dependency chain. ExecStartPre waits for X display to respond. |
| tigervnc@.service | display.env | EnvironmentFile + source in ExecStart | WIRED | Sources VNC_PORT from display.env, uses -rfbport $VNC_PORT. Confirmed VNC listening on port 6061 (5900+161). |
| novnc@.service | tigervnc@%i.service | Requires= + After= | WIRED | Explicit systemd dependency. ExecStartPre waits for VNC port. |
| novnc@.service | display.env | EnvironmentFile + source in ExecStart | WIRED | Sources VNC_PORT and NOVNC_PORT. websockify connects to localhost:$VNC_PORT and serves on $NOVNC_PORT. |
| chromium-cdp@.service | xvfb@%i.service | Requires= + After= + DISPLAY=:%i | WIRED | Depends on Xvfb. Sets DISPLAY env. ExecStartPre validates X display responds. |
| cobrowse-start.sh | display.env | source "$ENV_FILE" | WIRED | Sources env file, extracts DISPLAY_NUM, uses all port variables. |
| cobrowse-start.sh | cobrowse-status.sh | bash "$(dirname "$0")/cobrowse-status.sh" | WIRED | Calls status script after startup for health report. |
| cobrowse-stop.sh | display.env | source "$ENV_FILE" | WIRED | Sources env file, uses DISPLAY_NUM to identify service instances. |
| cobrowse-status.sh | display.env | source "$ENV_FILE" | WIRED | Sources env file, uses all port variables for health checks. |
| cobrowse-setup.sh | configure-display.sh | bash "$SCRIPT_DIR/configure-display.sh" | WIRED | Called in Step 6 of setup. Generates display.env. |
| cobrowse-setup.sh | systemd templates | cp "$SYSTEMD_DIR"/*.service | WIRED | Copies service files to ~/.config/systemd/user/. Deployed copies verified identical to source. |
| Chrome profile | --user-data-dir flag | chromium-cdp@.service ExecStart | WIRED | Profile directory at /home/dev/.cobrowse/chrome-profile/ has 156M of data. --restore-last-session flag present. |

### Requirements Coverage

| Requirement | Status | Blocking Issue |
|-------------|--------|----------------|
| DISP-01: Xvfb runs on virtual display with systemd auto-start | SATISFIED | Note: Display :161 (hostname-based) instead of :99, but this is by design. |
| DISP-02: TigerVNC serves display over VNC protocol | SATISFIED | x0vncserver exports display :161 on port 6061. |
| DISP-03: noVNC + websockify provides browser-accessible view (port 6080) | SATISFIED | websockify on port 6080 serving noVNC web client, connecting to VNC port 6061. |
| DISP-04: Chromium launches with --remote-debugging-port=9222 and --user-data-dir | SATISFIED | google-chrome-stable (Chrome 144) running with both flags. CDP responds with valid JSON. |
| DISP-05: All display components managed by systemd with proper restart limits and validation | PARTIAL | 3/4 services have StartLimitBurst/StartLimitIntervalSec. novnc@.service is missing these. All 4 have Restart=on-failure and ExecStartPre validation. |
| STAT-01: Browser session persists across restarts via --user-data-dir | SATISFIED | --user-data-dir and --restore-last-session flags present. Profile has 156M data. User confirmed persistence. |
| SETUP-01: Single cobrowse-setup.sh installs entire stack on Ubuntu 24.04 | BLOCKED | Syntax error at line 56-57 prevents script from running to completion on fresh system. |
| SETUP-02: Setup script is idempotent | BLOCKED | Script cannot run at all due to syntax error, therefore idempotency cannot be verified on fresh run. Individual operations (apt-get install -y, mkdir -p, cp overwrite) are idempotent by design. |
| SETUP-03: Start/stop scripts manage all services | SATISFIED | cobrowse-start.sh (with wait-for-ready), cobrowse-stop.sh (reverse order with || true), cobrowse-status.sh (health checks). All executable and functional. |
| SETUP-04: Setup works for non-root user (dev) with sudo for package installation | PARTIAL | Script uses sudo for apt-get and loginctl. User-level systemd commands don't need sudo. But script cannot run due to syntax error. Design is correct; execution is blocked. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| cobrowse/setup/cobrowse-setup.sh | 56-57 | `fi \` continuation + `net-tools` creates syntax error | BLOCKER | Script fails on any fresh run. net-tools package not installed by script. |
| cobrowse/systemd/novnc@.service | - | Missing StartLimitBurst and StartLimitIntervalSec | WARNING | noVNC could restart infinitely on persistent failures, unlike the other 3 services which are rate-limited. |

### Human Verification Required

### 1. noVNC Visual Interaction
**Test:** Open http://[container-ip]:6080/vnc.html?autoconnect=true in laptop browser. Click on elements in Chrome. Type text into an input field.
**Expected:** Mouse clicks register. Typed text appears. Chrome UI responds in real-time through VNC.
**Why human:** Visual and interactive behavior cannot be verified programmatically.
**Note:** User already confirmed this works per 01-02-SUMMARY.md. Re-verification optional.

### 2. Session Persistence After Restart
**Test:** Open a few tabs in Chrome via noVNC. Run `cobrowse-stop.sh` then `cobrowse-start.sh`. Check if tabs are restored.
**Expected:** All tabs from before the restart are restored by Chrome.
**Why human:** Need to visually confirm tab restoration in the browser.
**Note:** User already confirmed this works after --restore-last-session fix. Re-verification optional.

### 3. Setup Script on Fresh System
**Test:** Run `bash cobrowse/setup/cobrowse-setup.sh` on a fresh Ubuntu 24.04 container (or after removing installed packages).
**Expected:** Script should install all packages and configure the display stack without errors.
**Why human:** The syntax error at line 56-57 must be fixed first. After the fix, re-run to verify end-to-end setup.

## Gaps Summary

There is one blocking gap and one minor gap:

**Gap 1 (BLOCKER): Setup script syntax error prevents fresh installation**

The `cobrowse-setup.sh` script has a bash syntax error introduced in commit `2c93688` when the Chrome installation block was inserted. The original `apt-get install` list included `net-tools` at the end. When `chromium-browser` was replaced with a separate Google Chrome `if/fi` install block, the `net-tools` line was left dangling after `fi \` (backslash continuation), creating the invalid construct `fi net-tools` which is a bash syntax error.

This means the setup script cannot run on ANY system -- fresh or existing. The current working deployment was set up from the pre-bug commit (`5f97036`) and the Chrome changes were applied manually/live.

Fix: Remove the backslash from line 56 (change `fi \` to `fi`) and either move `net-tools` back into the `apt-get install` list or add a separate `sudo apt-get install -y net-tools` after the `fi`.

**Gap 2 (WARNING): novnc@.service missing restart limits**

The `novnc@.service` file has `Restart=on-failure` and `RestartSec=10s` but lacks `StartLimitIntervalSec=300` and `StartLimitBurst=5` that the other three services (`xvfb@`, `tigervnc@`, `chromium-cdp@`) all include. This means noVNC could restart infinitely on persistent failures, which is inconsistent with the DISP-05 requirement for "proper restart limits."

Fix: Add `StartLimitIntervalSec=300` and `StartLimitBurst=5` to the `[Service]` section of `novnc@.service`.

---

*Verified: 2026-02-10T03:10:00Z*
*Verifier: Claude (gsd-verifier)*
