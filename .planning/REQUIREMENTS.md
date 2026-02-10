# Requirements: Claude Co-Browse

**Defined:** 2026-02-09
**Core Value:** Claude Code can seamlessly escalate from headless browser automation to a human-visible co-browsing session when it needs input, and the human always knows which project needs them.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Display Stack

- [ ] **DISP-01**: Xvfb virtual framebuffer runs on display :99 with systemd auto-start
- [ ] **DISP-02**: TigerVNC serves display :99 over VNC protocol (port 5900)
- [ ] **DISP-03**: noVNC + websockify provides browser-accessible view of VNC session (port 6080)
- [ ] **DISP-04**: Chromium launches on display :99 with `--remote-debugging-port=9222` and `--user-data-dir`
- [ ] **DISP-05**: All display components managed by systemd services with proper restart limits and validation
- [ ] **DISP-06**: nginx reverse proxy routes path-based URLs to container noVNC sessions (`/project-a/`, `/project-b/`)
- [ ] **DISP-07**: Reverse proxy handles WebSocket upgrade for VNC protocol

### Automation

- [ ] **AUTO-01**: Playwright connects to persistent Chromium via `connectOverCDP('http://localhost:9222')`
- [ ] **AUTO-02**: Playwright can navigate, click, fill forms, and interact with pages through CDP connection
- [ ] **AUTO-03**: Direct text injection via CDP `Input.insertText` bypasses clipboard entirely
- [ ] **AUTO-04**: `page.fill()`, `page.type()`, and `page.keyboard.press()` work through CDP connection
- [ ] **AUTO-05**: Screenshots captured via `DISPLAY=:99 import -window root` for Claude to see current state
- [ ] **AUTO-06**: Human can interact via noVNC simultaneously while Playwright has CDP connection

### Handoff

- [ ] **HAND-01**: noVNC tab title changes/flashes when a project needs human input (e.g., "⚠ ProjectName needs input")
- [ ] **HAND-02**: Webhook fires to configurable endpoint (ntfy.sh, Slack) when human input needed
- [ ] **HAND-03**: Auto-detection of completed user interaction via URL change (navigation event listener)
- [ ] **HAND-04**: Auto-detection of completed user interaction via element appearance (DOM mutation observer)
- [ ] **HAND-05**: Manual "done" signal path for Claude Code to resume after user interaction
- [ ] **HAND-06**: Escalation triggers on OAuth/auth URL patterns (`/oauth/`, `/login/`, `/auth/`, `/consent`)

### State

- [ ] **STAT-01**: Browser session persists across restarts via `--user-data-dir` (cookies, localStorage)
- [ ] **STAT-02**: Playwright can inject cookies directly via CDP to skip login flows
- [ ] **STAT-03**: Playwright can set localStorage values via `page.evaluate()` to restore state
- [ ] **STAT-04**: API call shortcuts documented for common auth flows (token injection, session creation)

### Setup

- [ ] **SETUP-01**: Single `cobrowse-setup.sh` script installs entire stack (Xvfb, TigerVNC, noVNC, Chromium) on Ubuntu 24.04
- [ ] **SETUP-02**: Setup script is idempotent (safe to run multiple times)
- [ ] **SETUP-03**: Start/stop scripts manage all services (`cobrowse-start.sh`, `cobrowse-stop.sh`)
- [ ] **SETUP-04**: Setup works for non-root user (dev) with sudo for package installation

### Testing Lab

- [ ] **TEST-01**: Test suite comparing `page.fill()` vs `page.type()` vs `page.keyboard.type()` across input types
- [ ] **TEST-02**: Test suite comparing `page.evaluate()` JS injection vs Playwright API DOM interaction
- [ ] **TEST-03**: Test suite measuring screenshot feedback timing and reliability
- [ ] **TEST-04**: Test suite comparing state manipulation methods (cookie injection, localStorage, API bypass)
- [ ] **TEST-05**: Results documented with recommendations for when to use each method
- [ ] **TEST-06**: Tests run against real-world targets (OAuth flows, complex SPAs, Google UIs)

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Intelligent Automation

- **INTEL-01**: ML-based confidence scoring for when to escalate to human
- **INTEL-02**: Self-healing automation that adapts when selectors fail
- **INTEL-03**: Pointer/annotation overlay showing AI's intent during handoff

### Optimization

- **OPT-01**: On-demand VNC start/stop to save resources when human not watching
- **OPT-02**: noVNC H.264 encoding for reduced bandwidth
- **OPT-03**: Resource usage monitoring per container (CPU/memory via CDP Performance domain)
- **OPT-04**: Priority queue for human intervention requests across containers

## Out of Scope

| Feature | Reason |
|---------|--------|
| Video recording of sessions | Massive storage; screenshots + logs provide same debugging value |
| Multi-user co-browsing | Race conditions, permission conflicts; single operator model |
| Mobile browser testing | Desktop Chromium only; mobile testing is separate concern (Appium) |
| Non-Playwright automation | Chromium-only via Playwright; Firefox/Safari have incomplete CDP |
| Always-on visible browser | Wastes resources; always-on display pattern is acceptable compromise |
| Automatic AI auth handling | Security risk; OAuth designed for human interaction |
| xdotool for complex UIs | Confirmed broken on modern UIs (Google, React); Playwright CDP required |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| DISP-01 | Phase 1 | Pending |
| DISP-02 | Phase 1 | Pending |
| DISP-03 | Phase 1 | Pending |
| DISP-04 | Phase 1 | Pending |
| DISP-05 | Phase 1 | Pending |
| DISP-06 | Phase 3 | Pending |
| DISP-07 | Phase 3 | Pending |
| AUTO-01 | Phase 2 | Pending |
| AUTO-02 | Phase 2 | Pending |
| AUTO-03 | Phase 2 | Pending |
| AUTO-04 | Phase 2 | Pending |
| AUTO-05 | Phase 2 | Pending |
| AUTO-06 | Phase 2 | Pending |
| HAND-01 | Phase 4 | Pending |
| HAND-02 | Phase 4 | Pending |
| HAND-03 | Phase 5 | Pending |
| HAND-04 | Phase 5 | Pending |
| HAND-05 | Phase 5 | Pending |
| HAND-06 | Phase 4 | Pending |
| STAT-01 | Phase 1 | Pending |
| STAT-02 | Phase 2 | Pending |
| STAT-03 | Phase 2 | Pending |
| STAT-04 | Phase 2 | Pending |
| SETUP-01 | Phase 1 | Pending |
| SETUP-02 | Phase 1 | Pending |
| SETUP-03 | Phase 1 | Pending |
| SETUP-04 | Phase 1 | Pending |
| TEST-01 | Phase 6 | Pending |
| TEST-02 | Phase 6 | Pending |
| TEST-03 | Phase 6 | Pending |
| TEST-04 | Phase 6 | Pending |
| TEST-05 | Phase 6 | Pending |
| TEST-06 | Phase 6 | Pending |

**Coverage:**
- v1 requirements: 33 total
- Mapped to phases: 33
- Unmapped: 0 ✓

---
*Requirements defined: 2026-02-09*
*Last updated: 2026-02-09 after initial definition*
