# Project Research Summary

**Project:** claude-cobrowse
**Domain:** AI-Agent-Driven Browser Co-Browsing Infrastructure
**Researched:** 2026-02-09
**Confidence:** HIGH

## Executive Summary

This project builds a remote browser co-browsing system where Claude Code (AI agent) drives browsers with optional human observation and intervention. The optimal 2026 approach combines **Xvfb (virtual display) + TigerVNC (faster than x11vnc) + noVNC (browser-based viewer) + Playwright CDP (browser automation)** in an always-on display pattern. The reference implementation's core stack is sound, but requires optimization for multi-container deployment and proper CDP integration.

The critical insight: **noVNC is inherently slow for interaction** due to VNC protocol limitations. The solution is architectural: noVNC serves exclusively as a monitoring interface for humans, while ALL programmatic actions flow through Playwright CDP. This dual-control model enables AI automation at full speed while maintaining real-time visual oversight. The key differentiator is intelligent escalation — detecting when human input is needed (OAuth, CAPTCHA) and alerting via dual notification (tab title flash + webhook).

Major risks center on Chrome 136+ security changes (requiring `--user-data-dir` for CDP), multi-container display number conflicts (requires calculated display offsets), and reverse proxy WebSocket routing (requires proper path handling). All are preventable with proper setup from Phase 1. The recommended approach uses the **Always-On Display pattern** (Pattern 2) where Xvfb runs continuously with on-demand VNC viewing, avoiding browser restart complexity while maintaining Playwright CDP stability.

## Key Findings

### Recommended Stack

The 2026 stack balances performance, compatibility, and resource efficiency. **TigerVNC outperforms x11vnc by 15-20%** with better screen redraw and lower memory usage. **Chromium is preferred over Chrome for Testing** due to Chrome's 20GB+ RAM per instance (vs Chromium's 5-10GB), though Chrome for Testing should be used if compatibility issues arise. **Playwright 1.58.0+** provides best-in-class CDP integration, but `connectOverCDP()` offers "significantly lower fidelity" than native Playwright — acceptable trade-off for persistent browser sessions.

**Core technologies:**
- **TigerVNC**: VNC server (15-20% faster than x11vnc, lower memory) — replaces x11vnc
- **Xvfb**: Virtual framebuffer (de facto standard, mature) — headless display for browser
- **Chromium (system)**: Browser engine (5-10GB RAM vs 20GB+ for Chrome for Testing) — default choice
- **Playwright 1.58.0+**: Primary automation API (industry-leading CDP integration) — all AI actions
- **noVNC 1.6.0+**: Browser-based VNC client (zero installation, mobile support) — human monitoring only
- **nginx**: Reverse proxy (path-based routing to 3-5 containers) — single entry point

**Critical version requirements:**
- Chrome 136+ requires `--user-data-dir` with `--remote-debugging-port` (security change)
- Playwright 1.58.0 supports latest Chrome for Testing 134+
- noVNC 1.6.0 adds H.264 support for reduced bandwidth (requires H.264 VNC server)

### Expected Features

Research reveals a clear MVP boundary: 8 launch features solving immediate pain points, with 6 post-validation enhancements and advanced features deferred to v2+.

**Must have (table stakes):**
- **Real-time browser viewing** — core co-browsing capability (noVNC stack proven on reference box)
- **Headless → headed mode switching** — resource efficiency (Playwright `headless: false` + CDP)
- **Session persistence** — auth flows require cookie/localStorage survival across restarts
- **Secure credential handling** — OAuth flows need element redaction, separate profiles
- **Text input injection** — CDP `Input.insertText` bypasses slow clipboard bridges
- **Multi-tab navigation** — modern web apps require multiple tabs/windows support
- **Network state visibility** — AI needs loading states, error detection via CDP Network domain

**Should have (competitive advantage):**
- **Intelligent escalation detection** — auto-detect OAuth/CAPTCHA via URL/content pattern matching
- **Dual notification system** — tab title flash (Page Visibility API) + webhook (ntfy.sh/Slack)
- **Auto-resume after human input** — detect completion via URL change or element appearance
- **Interaction method testing suite** — empirical data on Playwright API vs CDP vs JS injection
- **Pointer/annotation overlay** — visual guidance showing AI's intent during handoff
- **State snapshot/rollback** — save browser state before risky operations

**Defer (v2+):**
- **Self-healing automation** — requires ML training data from many failure sessions
- **Concurrent session orchestration (priority queue)** — MVP assumes human monitors tabs manually
- **Browser-agnostic support** — Chromium-only focus beats Firefox/Safari fragmentation

**Anti-features to avoid:**
- Video recording of full sessions (massive storage; screenshots + logs provide same debugging value)
- Multi-user co-browsing (race conditions; use sequential control instead)
- Always-on visible browser (wastes resources; use headless-first or on-demand display)

### Architecture Approach

The architecture uses a **dual-control model** where Playwright CDP and noVNC simultaneously access the same Chromium instance via `--remote-debugging-port=9222`. The recommended **Always-On Display pattern (Pattern 2)** keeps Xvfb + Chromium running continuously with on-demand VNC viewing, avoiding browser restart complexity while maintaining CDP stability. This is optimal for 32GB RAM containers running 3-5 concurrent projects.

**Major components:**
1. **Reverse Proxy (nginx)** — path-based routing to multiple containers (`/project-a/`, `/project-b/`), WebSocket upgrade handling, single entry point
2. **Display Stack (Xvfb + TigerVNC + noVNC)** — virtual framebuffer, VNC server, browser-based client; human monitoring interface
3. **Browser (Chromium)** — persistent instance with `--display=:99 --remote-debugging-port=9222 --user-data-dir=/path/to/profile`
4. **Automation Layer (Playwright CDP)** — `connectOverCDP('http://localhost:9222')` for AI-driven interactions
5. **Notification System** — tab title flash via `page.evaluate()` + webhook to ntfy.sh/Slack
6. **State Management** — systemd services (Xvfb, TigerVNC, Chromium) + `--user-data-dir` for persistence

**Critical data flows:**
- AI automation: Claude Code → Playwright CDP → Chromium → Xvfb framebuffer
- Human viewing: Xvfb → TigerVNC → websockify → noVNC → browser on laptop
- Human interaction: noVNC → WebSocket → websockify → TigerVNC → X11 events → Chromium
- Notifications: Playwright detects condition → notify.ts → tab flash (CDP) + webhook (HTTP POST)

**Key architectural decisions:**
- **Pattern 2 (Always-On Display)** over Pattern 1 (Headless-First) — simpler, avoids browser restarts, CDP stability
- **TigerVNC** over x11vnc — 15-20% faster, lower memory usage
- **Playwright CDP** over native Playwright — required for persistent browser, accepts lower fidelity trade-off
- **Path-based routing** over subdomain-based — simpler (no wildcard DNS/SSL), sufficient for 3-5 containers
- **Chromium** over Chrome for Testing — 4x lower memory usage (5-10GB vs 20GB+), acceptable compatibility

### Critical Pitfalls

Research identified 10 critical pitfalls with verified prevention strategies:

1. **Chrome 136+ CDP security breakage** — `--remote-debugging-port=9222` silently ignored without `--user-data-dir=/path/to/custom/dir`; ALWAYS use both flags together
2. **Xvfb display number conflicts** — multiple containers using `:99` causes "display already active" crashes; calculate display from container ID: `DISPLAY_NUM=$((99 + CONTAINER_ID))`
3. **CDP bind address lockdown (M113+)** — `--remote-debugging-address=0.0.0.0` ignored, forces 127.0.0.1; use socat port forwarding or run Playwright in same container
4. **connectOverCDP context isolation failures** — `browser.newContext()` throws errors; retrieve existing context: `browser.contexts()[0]` instead of creating new
5. **noVNC WebSocket path routing** — proxy path prefix causes 404 on WebSocket; configure nginx path rewriting + set `proxy_read_timeout > 60s` to prevent disconnects
6. **Systemd restart loops** — missing ExecStart script causes infinite restarts; validate with `ExecStartPre=/usr/bin/test -x /path/to/script.sh` and set `StartLimitBurst=5`
7. **Headless/headed mode switching crashes** — cannot change DISPLAY on running browser; must restart browser entirely when switching modes
8. **noVNC performance degradation** — VNC protocol inherently slow (1-10 FPS); accept limitation, use Playwright CDP for ALL automation, noVNC for monitoring only
9. **Clipboard sync failures (client → server)** — VNC clipboard one-way only; use CDP injection instead: `page.evaluate(() => navigator.clipboard.writeText(text))`
10. **xdotool synthetic event failures** — modern UIs (Google Apps Script, React) reject X11 synthetic events; NEVER use xdotool for complex web UIs, always use Playwright CDP

## Implications for Roadmap

Based on research, the recommended phase structure follows a **foundation-first, scale-outward** approach. Each phase addresses specific pitfalls and builds on proven patterns.

### Phase 1: Single-Container Display Stack (Foundation)
**Rationale:** Establish baseline infrastructure before adding Playwright; validate display chain independently. This is where 6 of 10 critical pitfalls must be prevented.

**Delivers:** Working Xvfb → TigerVNC → noVNC chain with Chromium CDP accessible; systemd services for auto-start

**Addresses:**
- Real-time browser viewing (table stakes from FEATURES.md)
- Session persistence via `--user-data-dir`
- Infrastructure for all subsequent phases

**Avoids:**
- Pitfall #1: Chrome 136+ CDP breakage (validate `--user-data-dir` flag from day one)
- Pitfall #2: Display number conflicts (use calculated offset before multi-container)
- Pitfall #3: CDP bind address lockdown (validate socat setup or same-container Playwright)
- Pitfall #6: Systemd restart loops (proper ExecStart validation before production)

**Research flags:** Standard VNC setup, well-documented patterns (skip `/gsd:research-phase`)

### Phase 2: Playwright CDP Integration
**Rationale:** Prove AI + human can co-exist in same browser before scaling to multiple containers. Critical for validating dual-control model.

**Delivers:** Playwright `connectOverCDP()` working; simple automation visible in noVNC simultaneously; state persistence validated

**Uses:**
- Playwright 1.58.0+ (from STACK.md)
- CDP WebSocket connection to localhost:9222
- Always-On Display pattern (ARCHITECTURE.md Pattern 2)

**Implements:** Automation Layer component from architecture

**Avoids:**
- Pitfall #4: CDP context isolation failures (use `browser.contexts()[0]` pattern)
- Pitfall #7: Mode switching crashes (validate DISPLAY env var before browser launch)

**Research flags:** Standard Playwright patterns (skip research); refer to existing E2E test setup

### Phase 3: Reverse Proxy + Multi-Container Routing
**Rationale:** Scaling to 3-5 containers requires routing layer; test with 2 containers before full deployment.

**Delivers:** nginx path-based routing to multiple noVNC instances; WebSocket upgrade handling; port assignment strategy documented

**Addresses:**
- Multi-container deployment (core use case from PROJECT.md)
- Concurrent session orchestration foundations

**Implements:** Reverse Proxy component from architecture

**Avoids:**
- Pitfall #5: noVNC WebSocket path routing (nginx path rewriting + `proxy_read_timeout` config)
- Pitfall #2: Display conflicts validated with 2+ containers running simultaneously

**Research flags:** Standard nginx WebSocket proxying (skip research); templates available in architecture doc

### Phase 4: Notification System
**Rationale:** Notifications only matter once multi-container setup operational; need working noVNC tabs to flash.

**Delivers:** Tab title flash via CDP; webhook integration (ntfy.sh/Slack); trigger script for escalation detection; stop notification on completion

**Addresses:**
- Dual notification system (differentiator from FEATURES.md)
- Intelligent escalation detection (competitive advantage)
- User experience for multi-container monitoring

**Avoids:**
- Pitfall #8: noVNC performance (document that VNC is monitoring only, not interaction)
- Pitfall #9: Clipboard failures (implement CDP injection alternative)

**Research flags:** May need ntfy.sh API research for advanced features (notification updating/deletion)

### Phase 5: Interaction Completion Detection
**Rationale:** Requires working notification system to test full "notification → interaction → detection → resume" loop.

**Delivers:** Auto-detection via Playwright event listeners (URL change, element appears); manual signal endpoint as fallback; integration with notifications

**Addresses:**
- Auto-resume after human input (should-have from FEATURES.md)
- Seamless handoff workflow

**Implements:** State transition logic in automation layer

**Avoids:** False positives in detection (manual signal provides escape hatch)

**Research flags:** Standard Playwright event listeners (skip research)

### Phase 6: Interaction Method Testing Suite
**Rationale:** Can develop in parallel with Phase 4-5; not a blocker for core functionality. Builds reusable knowledge base.

**Delivers:** Test suite comparing Playwright methods (`fill()` vs `type()` vs `keyboard.press()`); JS injection vs DOM interaction benchmarks; documentation of best practices

**Addresses:**
- Interaction method testing suite (differentiator from FEATURES.md)
- Knowledge foundation for self-healing automation (v2+)

**Avoids:**
- Pitfall #10: xdotool failures (empirical proof that Playwright CDP is required)

**Research flags:** Low complexity, self-contained experimentation (skip research)

### Phase 7: Headless ↔ Headed Switching (Optional)
**Rationale:** Optimization, not core functionality; Pattern 2 (Always-On Display) may be sufficient given 32GB RAM availability.

**Delivers:** On-demand VNC start/stop scripts; resource savings validated; OR decision to skip entirely

**Avoids:**
- Pitfall #7: Mode switching crashes (if implemented, requires proper DISPLAY handling)

**Research flags:** Standard systemd service management (skip research); DEFER unless resource pressure demands it

### Phase Ordering Rationale

- **Foundation-first (Phase 1-2):** Establish single-container infrastructure before scaling; 6 of 10 pitfalls prevented in foundation
- **Scale-outward (Phase 3):** Multi-container routing requires proven single-container setup
- **UX layer (Phase 4-5):** Notifications and detection require operational multi-container base
- **Knowledge-gathering (Phase 6):** Can parallelize with UX development; informs future features
- **Optimization last (Phase 7):** Defer until proven necessary; always-on pattern acceptable for 32GB containers

**Dependency chain:**
```
Phase 1 (Foundation)
    ↓
Phase 2 (Playwright CDP)
    ↓
Phase 3 (Multi-container routing)
    ↓
┌───────────────┬───────────────┐
↓               ↓               ↓
Phase 4         Phase 5         Phase 6
(Notifications) (Auto-resume)   (Testing suite)
                                (parallel)
    ↓
Phase 7 (Optional optimization)
```

### Research Flags

**Phases needing deeper research during planning:**
- **Phase 4:** ntfy.sh API research for advanced notification features (updating/deletion for dead man's switch pattern)

**Phases with standard patterns (skip research-phase):**
- **Phase 1:** Standard VNC/systemd setup, well-documented across sources
- **Phase 2:** Playwright CDP is well-documented, existing E2E test setup provides reference
- **Phase 3:** nginx WebSocket proxying is standard pattern, templates in ARCHITECTURE.md
- **Phase 5:** Standard Playwright event listeners, no specialized knowledge required
- **Phase 6:** Self-contained experimentation, no external research needed
- **Phase 7:** Standard systemd service management if implemented

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Official Playwright docs, Chrome DevTools Protocol spec, noVNC GitHub releases verified; TigerVNC vs x11vnc benchmarks from user reports; Chrome 136+ security changes from official Chrome blog |
| Features | HIGH | Competitor analysis (Browserbase, Cobrowse.io, OpenClaw) provides clear market context; reference implementation validates feasibility; MVP boundary clear from research |
| Architecture | HIGH | Pattern 2 (Always-On Display) proven on reference box; nginx WebSocket proxying well-documented; CDP dual-control model validated in multiple sources |
| Pitfalls | HIGH | All 10 pitfalls sourced from official bug reports, Playwright issues, Chrome developer blog; recovery strategies verified from community solutions |

**Overall confidence:** HIGH

Research drew from official documentation (Playwright API, Chrome DevTools Protocol, noVNC wiki), verified bug reports (GitHub issues, Chromium issue tracker), and 2026-current sources. The reference implementation provides empirical validation of core stack. The only medium-confidence area is TigerVNC vs x11vnc performance claims (15-20% faster), which come from user benchmarks rather than official sources, but multiple independent reports align.

### Gaps to Address

- **noVNC H.264 encoding:** Research indicates noVNC 1.6.0 supports H.264 for reduced bandwidth, but TigerVNC may not support H.264 by default. **Action:** Verify H.264 support during Phase 1 testing; fall back to tight/hextile encoding if unavailable.

- **ntfy.sh notification updating/deletion:** 2026 ntfy.sh features (notification updating for dead man's switch) are documented but not yet tested in context. **Action:** Include ntfy.sh API exploration in Phase 4 if advanced patterns needed; basic webhook POST is sufficient for MVP.

- **Chrome for Testing vs Chromium compatibility:** Stack research recommends Chromium (lower memory) but flags Chrome for Testing as fallback if compatibility issues arise. **Action:** Test target applications (OAuth providers, complex SPAs) during Phase 2; switch to Chrome for Testing only if Chromium breaks critical flows.

- **Multi-container resource contention:** Architecture assumes 32GB RAM / 8 vCPU per container is sufficient for always-on display pattern. **Action:** Monitor resource usage in Phase 3 with 3-5 concurrent containers; implement Phase 7 (headless switching) only if memory pressure observed.

- **Playwright CDP fidelity limitations:** Official docs state `connectOverCDP()` has "significantly lower fidelity" than native Playwright but don't enumerate specific missing features. **Action:** Document any functionality gaps discovered during Phase 2; maintain list of CDP limitations for future reference.

## Sources

### Primary (HIGH confidence)
- [Playwright BrowserType API](https://playwright.dev/docs/api/class-browsertype) — connectOverCDP fidelity, version compatibility
- [Playwright CDPSession API](https://playwright.dev/docs/api/class-cdpsession) — CDP capabilities
- [Chrome DevTools Protocol Spec](https://chromedevtools.github.io/devtools-protocol/) — stable domains, protocol reference
- [Chrome Developer Blog: Remote Debugging Changes](https://developer.chrome.com/blog/remote-debugging-port) — Chrome 136+ security changes
- [noVNC GitHub Repository](https://github.com/novnc/noVNC) — version 1.6.0 features, WebSocket configuration
- [noVNC Wiki: Proxying with nginx](https://github.com/novnc/noVNC/wiki/Proxying-with-nginx) — reverse proxy setup

### Secondary (MEDIUM confidence)
- [Playwright Issue #38489](https://github.com/microsoft/playwright/issues/38489) — Chrome for Testing 20GB+ RAM usage
- [Playwright Issue #11442](https://github.com/microsoft/playwright/issues/11442) — connectOverCDP context isolation
- [VNC Server Comparison | DoHost](https://dohost.us/index.php/2025/11/05/vnc-server-software-comparison-tightvnc-tigervnc-realvnc-x11vnc/) — TigerVNC vs x11vnc performance
- [BrowserStack: Connecting Playwright to Existing Browser](https://www.browserstack.com/guide/playwright-connect-to-existing-browser) — CDP usage patterns
- [Browserless: 2026 AI Browser Automation Outlook](https://www.browserless.io/blog/state-of-ai-browser-automation-2026) — industry trends
- [Launch YC: Asteroid Browser Agents](https://www.ycombinator.com/launches/MtY-asteroid-browser-agents-with-human-oversight) — human-in-the-loop patterns

### Tertiary (context-specific)
- Reference implementation (claude-cobrowse existing box) — Xvfb :99 + Chromium --remote-debugging-port=9222 + noVNC proven working
- Project context — 3-5 concurrent LXC containers (32GB/8vCPU each), Ubuntu 24.04, Tailscale networking

---
*Research completed: 2026-02-09*
*Ready for roadmap: yes*
