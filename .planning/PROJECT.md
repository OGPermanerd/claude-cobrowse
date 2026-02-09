# Claude Co-Browse

## What This Is

A reusable co-browsing infrastructure kit for Claude Code containers. It lets Claude Code drive browsers headlessly via Playwright most of the time, but escalate to a visible browser session (via Xvfb + x11vnc + noVNC) when human input is needed — OAuth flows, visual review, manual interaction. The user monitors 3-5 concurrent project containers from their laptop via noVNC tabs behind a reverse proxy, with notifications alerting them when a specific project needs attention.

Separately, it's a testing lab for discovering and documenting the best methods for Claude Code to interact with browsers — comparing Playwright API approaches (fill vs type vs keyboard), JavaScript injection vs DOM interaction, screenshot-based feedback loops, and state manipulation shortcuts (cookies, localStorage, direct API calls).

## Core Value

Claude Code can seamlessly escalate from headless browser automation to a human-visible co-browsing session when it needs input, and the human always knows which project needs them.

## Requirements

### Validated

- ✓ Playwright E2E test scaffolding for Next.js + NextAuth v5 — existing
- ✓ Auth setup via JWT token minting and browser storage state — existing
- ✓ Install/scaffold scripts for per-project setup — existing
- ✓ Global Claude Code testing discipline via ~/.claude/CLAUDE.md — existing

### Active

- [ ] Working Xvfb + x11vnc + noVNC stack in Ubuntu 24.04 containers
- [ ] Playwright headless → headed mode switching on demand
- [ ] Reverse proxy for single-port access to multiple container noVNC sessions (path-based routing)
- [ ] Notification system: noVNC tab title flash when project needs input
- [ ] Notification system: webhook/external alert (ntfy.sh, Slack, etc.) when project needs input
- [ ] Auto-detection of completed user interaction (URL change, element appears) to resume automation
- [ ] Manual signal path ("done") for Claude Code to resume after user interaction
- [ ] Interaction method test suite: Playwright API comparisons (fill vs type vs keyboard.press)
- [ ] Interaction method test suite: JS injection (page.evaluate) vs DOM interaction
- [ ] Interaction method test suite: screenshot feedback timing and reliability
- [ ] Interaction method test suite: state manipulation shortcuts (cookies, localStorage, API bypass)
- [ ] Reusable setup script that works across any container instance
- [ ] Documentation of best practices and method recommendations

### Out of Scope

- Mobile browser testing — desktop Chromium only for now
- Multi-user co-browsing (shared sessions) — single operator model
- Video recording of sessions — screenshots sufficient for feedback
- Non-Playwright browser automation (Puppeteer, Selenium) — Playwright is the standard

## Context

- Containers are Hetzner LXC (32GB/8vCPU), Ubuntu 24.04, Node.js 22, Xvfb pre-installed
- Missing from this container: x11vnc, noVNC, websockify, Chromium
- One container had a broken cobrowse setup (systemd service looping 23K+ restarts due to missing start script) — building fresh
- Another box has a **working reference implementation** with this proven stack:
  - Xvfb :99 → Chromium with `--remote-debugging-port=9222` → noVNC web view
  - 4 interaction methods: noVNC (human), xdotool (simple Claude actions), Playwright CDP via `connectOverCDP('http://localhost:9222')` (complex Claude actions), screenshots via `import -window root`
  - Clipboard bridge: HTTP server on Tailscale for text exchange (`clip`/`getclip`)
  - Practical workflow: noVNC for auth flows, xdotool for simple clicks, Playwright CDP for complex UIs (Google Apps Script, forms)
  - Key finding: Google's complex UIs don't respond well to synthetic X11 events — Playwright CDP is more reliable
- Existing codebase is a distribution kit: template files + install/scaffold scripts
- User runs 3-5 Claude Code project containers concurrently on Tailscale network
- User accesses containers from a laptop via browser
- Playwright already used for E2E testing in target projects; this extends it with co-browsing capability
- Escalation is currently ad-hoc: sometimes Claude detects OAuth pages, sometimes user notices something's stuck

## Constraints

- **Platform**: Ubuntu 24.04 containers with apt-get (no Docker-in-Docker)
- **Display**: Xvfb virtual framebuffer (no physical display)
- **Browser**: Chromium only (Playwright's default)
- **Network**: Containers expose ports to host; reverse proxy routes to noVNC sessions
- **Resources**: Must be lightweight enough to run alongside the actual project dev server
- **Permissions**: Scripts run as non-root user (dev), may need sudo for package installation

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Xvfb + Chromium CDP + noVNC | Proven on reference box; CDP port 9222 enables both noVNC viewing and Playwright control | — Pending |
| Reverse proxy over fixed ports | Single entry point, cleaner URL scheme for 3-5 containers | — Pending |
| Headless → headed on demand | Saves resources; only use display when human needs to see | — Pending |
| Dual notification (tab + webhook) | Tab flash for when you're watching; webhook for when you're not | — Pending |
| Auto-detect + manual signal | Best of both: auto-resume when possible, manual fallback | — Pending |

---
*Last updated: 2026-02-09 after initialization*
