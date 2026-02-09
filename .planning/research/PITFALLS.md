# Pitfalls Research: AI-Agent Co-Browsing Infrastructure

**Domain:** AI-agent-driven co-browsing with Xvfb/noVNC/Playwright CDP
**Researched:** 2026-02-09
**Confidence:** HIGH

## Critical Pitfalls

### Pitfall 1: Chromium Remote Debugging Port Security Breakage (Chrome 136+)

**What goes wrong:**
Chrome 136+ no longer respects `--remote-debugging-port=9222` when using the default user data directory. The browser silently ignores the flag, CDP connection fails, and Playwright's `connectOverCDP()` times out with cryptic WebSocket errors.

**Why it happens:**
[Security hardening introduced in Chrome 136](https://developer.chrome.com/blog/remote-debugging-port) forces separation of debugging sessions from production profiles. The `--remote-debugging-port` and `--remote-debugging-pipe` switches must now be accompanied by `--user-data-dir` pointing to a non-default directory.

**How to avoid:**
- **ALWAYS** launch Chromium with both flags together:
  ```bash
  chromium --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-cdp-profile-$RANDOM
  ```
- **NEVER** use the default profile (`~/.config/chromium`) for CDP automation
- Create unique user-data-dir per container/session to avoid conflicts
- Add validation: check if port 9222 is actually listening before attempting CDP connection

**Warning signs:**
- `connectOverCDP()` hangs or times out despite browser running
- `lsof -i :9222` shows no listener even though `--remote-debugging-port=9222` was passed
- Browser launches successfully but DevTools protocol endpoint returns 404
- Error: "WebSocket connection failed" or "Could not find any debuggable targets"

**Phase to address:**
Phase 1 (Infrastructure Foundation) — systemd service must include correct flags from day one

---

### Pitfall 2: Xvfb Display Number Conflicts in Multi-Container Environments

**What goes wrong:**
When multiple containers or parallel processes use `Xvfb :99`, the second instance fails with "Fatal server error: Server is already active for display 99". Containers crash-loop because the display number is hardcoded. Tests intermittently fail as processes accidentally share the same display.

**Why it happens:**
[Common in CI/CD environments](https://github.com/cypress-io/cypress/issues/1426) where parallel jobs try to claim the same display. The `xvfb-run -a` auto-select flag has race conditions when invoked nearly simultaneously — multiple processes can grab the same display before locks are acquired.

**How to avoid:**
- **Use container-specific display offsets**: Calculate display number from container ID
  ```bash
  DISPLAY_NUM=$((99 + CONTAINER_ID))
  Xvfb :$DISPLAY_NUM -screen 0 1920x1080x24
  ```
- **Let Xvfb auto-select** (if version supports it): `Xvfb -displayfd 3 3>&1`
- **Use systemd templates** for per-container service isolation
- **Validate before launch**: Check if display is free with `xdpyinfo -display :99 2>/dev/null`
- **Reserve display ranges** in documentation: containers 1-5 use :99-:103

**Warning signs:**
- Systemd service restarts repeatedly (check `systemctl status` for "display already active")
- `DISPLAY` env var points to wrong X server (tests interact with another container's browser)
- VNC connection works but shows unexpected content from another container
- Race conditions: tests pass when run solo, fail in parallel

**Phase to address:**
Phase 1 (Infrastructure Foundation) — must be solved before multi-container deployment

---

### Pitfall 3: Chromium CDP Bind Address Lockdown (M113+)

**What goes wrong:**
[From Chromium M113 onward](https://www.ytyng.com/en/blog/docker-chromium-cdp-port/), passing `--remote-debugging-address=0.0.0.0` is **silently ignored**. Chromium forces bind to `127.0.0.1:9222`, making CDP inaccessible from reverse proxy or external containers. Playwright running in a separate container cannot connect despite correct port mapping.

**Why it happens:**
Chromium hardened the debugging interface to prevent external network exposure. Even when explicitly configured, the browser overwrites bind address to localhost-only for security.

**How to avoid:**
- **Use socat port forwarding** inside the container:
  ```bash
  socat TCP-LISTEN:9222,fork,bind=0.0.0.0 TCP:127.0.0.1:9223 &
  chromium --remote-debugging-port=9223 --user-data-dir=/tmp/chrome-cdp
  ```
- **Or use SSH tunneling** for cross-container access
- **Or run Playwright in the SAME container** as Chromium to avoid network issues
- Document the bind address limitation prominently in setup instructions

**Warning signs:**
- `netstat -tuln | grep 9222` shows `127.0.0.1:9222` instead of `0.0.0.0:9222`
- External CDP connections fail with "Connection refused" despite port mapping
- Works locally, fails when accessed from reverse proxy or another container
- Chrome process running but CDP endpoint not reachable from network

**Phase to address:**
Phase 1 (Infrastructure Foundation) — critical for reverse proxy architecture

---

### Pitfall 4: connectOverCDP Context Isolation Failures

**What goes wrong:**
[When using Playwright's `connectOverCDP()`](https://github.com/microsoft/playwright/issues/11442), calling `browser.newContext()` throws errors. Login cookies and localStorage from previous test runs persist across tests. Parallel test workers connecting to the same CDP port (9222) cause command interleaving and random failures.

**Why it happens:**
CDP exposes an existing browser instance with pre-existing state. Unlike `chromium.launch()`, `connectOverCDP()` cannot create fresh isolated contexts — you inherit the browser's current contexts. Multiple Playwright instances sharing one CDP endpoint cause protocol message routing conflicts.

**How to avoid:**
- **Retrieve existing context** instead of creating new:
  ```typescript
  const browser = await chromium.connectOverCDP('http://localhost:9222');
  const contexts = browser.contexts();
  const context = contexts[0] || await browser.newContext(); // fallback if no context exists
  ```
- **Clear state between tests**: Use `context.clearCookies()`, `context.clearPermissions()`, `page.evaluate(() => localStorage.clear())`
- **Use one CDP connection per container**: Never share port 9222 across test workers
- **Or use separate CDP ports per worker**: Launch multiple Chromium instances on 9222, 9223, 9224...

**Warning signs:**
- `browser.newPage()` throws "Cannot call newPage on connected browser"
- Tests pass individually but fail when run in parallel
- Authentication state bleeds between tests (logged in when expecting logged out)
- CDP command timeouts or "Session closed" errors during parallel execution

**Phase to address:**
Phase 2 (Headless ↔ Headed Switching) — before implementing concurrent access

---

### Pitfall 5: noVNC WebSocket Path Routing with Reverse Proxy

**What goes wrong:**
[When noVNC is served behind a reverse proxy with a path prefix](https://github.com/novnc/noVNC/issues/1737) (e.g., `/container1/vnc`), the HTML/JS loads correctly but WebSocket connections fail. The client tries to connect to `/websockify` instead of `/container1/websockify`, causing 404 errors and blank VNC screens.

**Why it happens:**
noVNC builds WebSocket URLs without considering the path prefix. The proxy serves static assets with correct paths, but the WebSocket URL is constructed relative to root. Additionally, [novnc-proxy hardcodes an empty path query parameter](https://bugs.launchpad.net/nova/+bug/1915868) when generating URLs.

**How to avoid:**
- **Configure noVNC's `path` parameter** in vnc.html:
  ```javascript
  const path = window.location.pathname.replace(/\/[^/]*$/, '/websockify');
  ```
- **Or use nginx path rewriting**:
  ```nginx
  location /container1/websockify {
      proxy_pass http://container1:6080/websockify;
      proxy_http_version 1.1;
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection "upgrade";
      proxy_read_timeout 600s;  # CRITICAL: prevent 60s disconnects
      proxy_buffering off;      # CRITICAL: avoid VNC stream caching
  }
  ```
- **Test WebSocket connectivity separately** before deploying UI
- **Set `proxy_read_timeout` > 60s** to avoid race-condition disconnects after inactivity

**Warning signs:**
- Browser console shows WebSocket error: "Failed to connect to /websockify"
- noVNC HTML loads but display stays black/gray
- Network tab shows 404 for WebSocket handshake
- Works without reverse proxy, fails when accessed through nginx/Apache

**Phase to address:**
Phase 3 (Reverse Proxy + Multi-Container Routing) — before path-based routing goes live

---

### Pitfall 6: Systemd Service Restart Loop from Missing ExecStart Script

**What goes wrong:**
Systemd service configured with `ExecStart=/path/to/nonexistent/script.sh` enters a tight restart loop. The service restarts 23,000+ times in hours, flooding logs and consuming CPU. `systemctl status` shows "activating (auto-restart)" continuously.

**Why it happens:**
[If `Restart=always` or `Restart=on-failure` is set without proper validation](https://blog.alphabravo.io/systemd-zero-to-hero-part-4-diagnosing-failures-and-debugging-like-a-pro/), systemd will retry indefinitely. The default `StartLimitBurst=5` is often overridden or not enforced, allowing unlimited restarts.

**How to avoid:**
- **Validate ExecStart path before enabling**:
  ```bash
  [[ -x /path/to/script.sh ]] || { echo "ExecStart script missing or not executable"; exit 1; }
  ```
- **Set explicit restart limits**:
  ```ini
  [Service]
  Restart=on-failure
  RestartSec=10s
  StartLimitIntervalSec=300
  StartLimitBurst=5
  ```
- **Add `ExecStartPre` validation**:
  ```ini
  ExecStartPre=/usr/bin/test -x /path/to/script.sh
  ```
- **Monitor restart count** with `systemctl show -p NRestarts <service>`
- **Temporarily disable restart during debugging**: `systemd-run --no-block <command>`

**Warning signs:**
- `journalctl -u <service>` shows rapid restart attempts
- `systemctl status` shows very high "Main PID" change rate
- CPU usage by systemd spikes
- Logs contain "Failed at step EXEC spawning /path: No such file or directory"

**Phase to address:**
Phase 1 (Infrastructure Foundation) — before any systemd service goes into production

---

### Pitfall 7: Headless/Headed Mode Switching Crashes Browser

**What goes wrong:**
[Switching from headless to headed mode mid-session](https://github.com/microsoft/playwright/issues/26497) causes browser crashes, hangs, or "XServer not found" errors even with Xvfb running. Tests that pass in headless fail in headed mode due to rendering differences (CSS animations, fonts, async timing).

**Why it happens:**
Chromium cannot dynamically attach to an X display after launching headless. The `DISPLAY` environment variable must be set **before** browser launch. Additionally, [headless mode uses a different rendering pipeline](https://github.com/microsoft/playwright/issues/30337) (chromium-headless-shell vs regular Chrome), causing behavioral differences.

**How to avoid:**
- **Restart browser entirely when switching modes** — never try to reuse the same browser instance
- **Set `DISPLAY` before launch**:
  ```typescript
  process.env.DISPLAY = ':99';
  const browser = await chromium.launch({ headless: false });
  ```
- **Use `PLAYWRIGHT_HEADED=1` env var** to force headed mode without code changes
- **Test in both modes** — headed tests can expose race conditions hidden by headless
- **Account for rendering differences**: Use `waitForLoadState('networkidle')` instead of `waitForTimeout()`

**Warning signs:**
- Error: "Looks like you launched a headed browser without having a XServer running"
- Browser process starts then immediately exits (check `journalctl`)
- Headed mode shows blank pages while headless works fine
- JavaScript `Promise` timing differs between modes (race conditions surface)

**Phase to address:**
Phase 2 (Headless ↔ Headed Switching) — validate before exposing mode toggle to agents

---

### Pitfall 8: noVNC Performance Degradation

**What goes wrong:**
[noVNC sessions are slow and laggy](https://github.com/novnc/noVNC/issues/1618) even at minimum quality settings. Frame rate drops below 1 FPS during animations or video. Mouse movements are delayed by 500ms+. Co-browsing becomes unusable for real-time interaction.

**Why it happens:**
VNC protocol performance is limited by server CPU, network bandwidth, and client CPU. [noVNC cannot achieve native performance](https://groups.google.com/g/novnc/c/61JQ_A7AOkY) until full binary data and asm.js conversion. Without fence and continuous updates support, [performance in high-latency networks is poor](https://github.com/novnc/noVNC/issues/1261).

**How to avoid:**
- **Lower resolution**: Use 1280x720 instead of 1920x1080 for Xvfb
- **Reduce color depth**: 16-bit color instead of 24-bit
- **Use x11vnc compression**: `-scale 3/4` flag
- **Enable continuous updates** if VNC server supports it
- **Limit frame rate** on server side: `-wait 50` (20 FPS max)
- **Accept performance limitations**: Document that noVNC is for **monitoring only**, not active use
- **Use Playwright CDP for agent actions** — VNC is for **human** oversight, not automation

**Warning signs:**
- High CPU usage on x11vnc process
- Network bandwidth saturated during VNC session
- Frame rate drops when page scrolls or animates
- Mouse cursor lags significantly behind movements

**Phase to address:**
Phase 4 (Notification System) — set expectations that VNC is for monitoring, not driving

---

### Pitfall 9: X11vnc Clipboard Sync Fails (Client → Server)

**What goes wrong:**
[Clipboard works server → client but not client → server](https://github.com/LibVNC/x11vnc/issues/260). Text copied in noVNC client doesn't paste into browser. Users resort to manual typing or external clipboard bridges. The HTTP clipboard bridge (clip/getclip) is clunky and requires manual copy/paste steps.

**Why it happens:**
VNC clipboard protocol has directional support issues. [X11 clipboard PRIMARY vs CLIPBOARD selection confusion](https://forums.linuxmint.com/viewtopic.php?t=369358) causes one-way sync. Recent Ubuntu updates broke `autocutsel` workarounds.

**How to avoid:**
- **Accept limitation**: Document that clipboard sync is unreliable in VNC
- **Provide HTTP clipboard bridge** as documented workaround (existing reference implementation)
- **Or use direct CDP injection** for agent-driven paste:
  ```typescript
  await page.evaluate((text) => navigator.clipboard.writeText(text), pasteContent);
  ```
- **For humans**: Provide web-based text input field that injects into page via CDP
- **Avoid reliance on VNC clipboard** for critical workflows

**Warning signs:**
- Clipboard paste from noVNC client shows stale/empty content
- Workarounds like `autocutsel` stop working after Ubuntu updates
- Users complain about typing long credentials manually

**Phase to address:**
Phase 4 (Notification System) — when human interaction patterns are defined

---

### Pitfall 10: xdotool Synthetic Events Fail on Complex UIs

**What goes wrong:**
[xdotool clicks and keystrokes fail on Google Apps Script, React forms, and other complex UIs](https://github.com/microsoft/playwright/issues/19445). Elements don't respond to synthetic X11 events. Forms don't validate. Dropdowns don't open. SPA frameworks ignore the interactions entirely.

**Why it happens:**
Modern frameworks (React, Vue, Angular) use synthetic event systems that track pointer deltas and state changes. [X11 XTest events are untargeted](https://groups.google.com/g/xdotool-users/c/bs4TfB-Ii9c) and lack the metadata that JavaScript event listeners expect. Complex UIs check `event.isTrusted` and reject synthetic events.

**How to avoid:**
- **Use Playwright CDP for complex UIs** — always
- **Reserve xdotool for simple tasks**: window management, basic desktop clicks
- **Test early**: If xdotool fails on your target app, switch to CDP immediately
- **Don't mix**: Using both xdotool and CDP on same page causes event confusion
- **Document scope**: xdotool = desktop/window control, Playwright = web automation

**Warning signs:**
- Clicks appear to work (element briefly highlights) but no action occurs
- Form inputs receive text but validation doesn't trigger
- Dropdowns don't expand when clicked via xdotool
- React DevTools shows no event handlers firing

**Phase to address:**
Phase 5 (Interaction Method Testing) — comparative testing will reveal this early

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Hardcode display `:99` | Simple config, no dynamic logic | Breaks in multi-container; impossible to scale | Never — always calculate from container ID |
| Share CDP port 9222 across workers | Simpler infrastructure (one browser) | Parallel test failures, command interleaving | Never — isolation is mandatory |
| Skip `--user-data-dir` flag | Shorter command line | Breaks on Chrome 136+; unpredictable state persistence | Never (as of Chrome 136) |
| Use default Xvfb resolution 1920x1080 | "Production-like" view | noVNC becomes unusably slow; wastes bandwidth | Only for screenshots; use 1280x720 for live viewing |
| Store auth cookies in browser profile | Persistent login across sessions | Tests fail when cookies expire; hard to debug stale state | Only for manual testing, never for automation |
| Use `Restart=always` without limits | Service auto-recovers from crashes | Restart loops hide root cause; flood logs | Only with `StartLimitBurst=5` and proper validation |
| Run VNC on port 5900 (default) | Standard port, well-known | Conflicts in multi-container; security risk (exposed VNC) | Never in production; always use random high port |
| Connect Playwright to headed browser | Easy debugging during development | State leaks between tests; crashes when switching back to headless | Only for local debugging, never in CI |

---

## Integration Gotchas

Common mistakes when connecting to external services.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| nginx → noVNC WebSocket | Forget `proxy_http_version 1.1` and `Upgrade` headers | Always set `proxy_http_version 1.1`, `proxy_set_header Upgrade $http_upgrade`, `Connection "upgrade"` |
| Playwright → Chromium CDP | Connect before browser is ready | Add health check: `curl http://localhost:9222/json/version` before `connectOverCDP()` |
| systemd → Xvfb | Assume `DISPLAY` is inherited | Set `Environment="DISPLAY=:99"` explicitly in `.service` file |
| x11vnc → Xvfb | Start vnc before Xvfb initializes | Add `ExecStartPre=/bin/sleep 2` or check for X server with `xdpyinfo` |
| Reverse proxy → multiple noVNC instances | Use same path for all containers | Use unique paths: `/container1/vnc`, `/container2/vnc` with path rewriting |
| Playwright storage state → NextAuth | Hardcode cookie name `authjs.session-token` | Read from `AUTH_COOKIE_NAME` env var (varies by NextAuth config) |

---

## Performance Traps

Patterns that work at small scale but fail as usage grows.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Unlimited Playwright workers | Fast test execution locally | OOM crashes, disk thrashing on low-memory containers | >4 parallel workers on 8GB RAM container |
| High-resolution Xvfb (1920x1080x24) | Sharp VNC display | noVNC lags, high bandwidth usage | Any resolution >1280x720 with noVNC |
| No `proxy_read_timeout` on noVNC proxy | Initial connection works fine | Random disconnects after 60s of inactivity | Default nginx timeout (60s) kicks in |
| Reusing browser context across tests | Faster test startup (no browser launch) | State leaks, flaky tests, auth issues | When tests modify cookies, localStorage, or DOM state |
| No restart limits on systemd services | Service appears "reliable" | Restart loops hide failures, flood logs | When underlying issue (missing file, wrong config) isn't fixed |
| Single CDP port for all containers | Simple port mapping | Command interleaving, test failures | >1 container trying to use port 9222 |
| Buffered proxy (`proxy_buffering on`) for VNC | Default nginx config | VNC frames lag behind actual screen state | Always — must set `proxy_buffering off` for VNC |

---

## Security Mistakes

Domain-specific security issues beyond general web security.

| Mistake | Risk | Prevention |
|---------|------|------------|
| Expose CDP port 9222 to public internet | Remote code execution; full browser control; data exfiltration | **Bind to 127.0.0.1 only**; use SSH tunnel or Tailscale for remote access |
| Run Chromium as root with `--no-sandbox` | Container escape; host compromise | Always run as non-root user; use `--disable-setuid-sandbox` if needed |
| Use default VNC password or no password | Unauthorized access to all running browsers and sessions | Always set strong VNC password or use auth proxy (nginx basic auth) |
| Reuse `--user-data-dir` across sessions | Session hijacking; cookie theft; credential leakage | Generate unique temp directory per CDP session |
| Store test credentials in browser profile | Credentials persist in unencrypted profile files | Use Playwright storage state (gitignored) or inject via CDP |
| Allow noVNC WebSocket without TLS | Credentials visible in plaintext over network | Use `wss://` (WebSocket over TLS) in production |
| Share Xvfb display across security contexts | Cross-session window capture via X11 protocol | Use separate display per user/session |

---

## UX Pitfalls

Common user experience mistakes in this domain.

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No notification when human input needed | User stares at logs, doesn't know to check VNC | Implement tab title flash + webhook alert when agent pauses |
| VNC tab auto-refreshes during interaction | User loses mouse position mid-click | Disable auto-reconnect; show manual "Reconnect" button |
| No visual indicator which container needs attention | User opens 5 VNC tabs, doesn't know which to focus | Use color-coded title prefixes: `[WAITING] Project-1`, `[RUNNING] Project-2` |
| Clipboard bridge requires too many steps | User gives up, types credentials manually | Provide direct text injection via web UI that calls CDP |
| No indication when agent resumes automation | User still interacting when agent takes over; confusing | Show overlay: "Agent resumed — do not interact" for 3 seconds |
| Error messages only in journalctl logs | User doesn't know what failed or where to look | Surface systemd errors in web UI dashboard |
| VNC session stays open after task complete | Wastes bandwidth; user forgets which sessions are active | Auto-close VNC after 10 minutes of inactivity |

---

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces.

- [ ] **CDP connection works**: Often missing health check before `connectOverCDP()` — verify with `curl http://localhost:9222/json/version`
- [ ] **Systemd service "active"**: Often missing validation that `ExecStart` script exists — verify with `test -x /path/to/script.sh`
- [ ] **noVNC displays browser**: Often missing WebSocket path config in reverse proxy — verify WebSocket handshake succeeds in browser console
- [ ] **Playwright test passes**: Often missing state cleanup — verify test passes 10 times in a row, not just once
- [ ] **Headless → headed switch works**: Often missing `DISPLAY` env var or Xvfb validation — verify browser actually appears in VNC before claiming success
- [ ] **Multiple containers run concurrently**: Often missing display number isolation — verify `Xvfb :99` doesn't conflict when container 2 starts
- [ ] **Clipboard bridge functional**: Often missing client → server direction — verify paste into browser, not just copy out
- [ ] **Auth state persists across tests**: Often missing `--user-data-dir` cleanup — verify fresh session on second test run
- [ ] **Reverse proxy routes to all containers**: Often missing `proxy_read_timeout` — verify VNC doesn't disconnect after 60s idle
- [ ] **Agent detects OAuth pages**: Often missing real OAuth redirect test — verify detection triggers on actual Google/GitHub login, not just URL pattern

---

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Chrome 136+ refuses CDP without `--user-data-dir` | LOW | Add flag, restart browser; no data loss |
| Display :99 conflict between containers | LOW | Increment to :100, restart Xvfb; session continues |
| CDP bind address locked to 127.0.0.1 | MEDIUM | Set up socat forwarding or SSH tunnel; requires config change + restart |
| `connectOverCDP()` context isolation failure | MEDIUM | Retrieve existing context instead of creating new; refactor test setup |
| noVNC WebSocket 404 behind reverse proxy | MEDIUM | Fix nginx path rewriting, reload config; no container restart needed |
| Systemd restart loop (23k+ restarts) | LOW | `systemctl disable <service>`, fix ExecStart, re-enable; logs may be huge but recoverable |
| Headless → headed crash | LOW | Set `DISPLAY` env var, restart Playwright script; no persistent damage |
| noVNC slow/laggy | MEDIUM | Lower Xvfb resolution, restart X/VNC stack; requires brief downtime |
| Clipboard sync broken (client → server) | HIGH | Implement HTTP bridge or CDP injection workaround; architectural change |
| xdotool fails on complex UI | HIGH | Migrate to Playwright CDP; requires code rewrite of interaction logic |

---

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Chrome 136+ CDP security breakage | Phase 1: Infrastructure Foundation | Verify CDP connection succeeds with explicit `--user-data-dir` |
| Xvfb display number conflicts | Phase 1: Infrastructure Foundation | Verify 5 containers can run simultaneously without display conflicts |
| CDP bind address lockdown (M113+) | Phase 1: Infrastructure Foundation | Verify external CDP connection via reverse proxy works |
| `connectOverCDP()` context isolation | Phase 2: Headless ↔ Headed Switching | Verify parallel tests don't share state when connecting to same browser |
| noVNC WebSocket path routing | Phase 3: Reverse Proxy Routing | Verify WebSocket connects successfully at `/container1/vnc` path |
| Systemd restart loop | Phase 1: Infrastructure Foundation | Verify service stays stopped when ExecStart fails, doesn't loop |
| Headless/headed switching crashes | Phase 2: Headless ↔ Headed Switching | Verify 10 consecutive switches without browser crash |
| noVNC performance degradation | Phase 4: Notification System | Verify frame rate >10 FPS at 1280x720 with quality=6 |
| Clipboard sync failure | Phase 4: Notification System | Verify HTTP bridge or CDP injection works for client → server paste |
| xdotool synthetic event failure | Phase 5: Interaction Method Testing | Verify Playwright CDP works on Google Apps Script (known hard case) |

---

## Sources

**noVNC Performance:**
- [noVNC Issue #1618: noVNC is slow on newer version](https://github.com/novnc/noVNC/issues/1618)
- [noVNC Google Group: Understanding noVNC performance](https://groups.google.com/g/novnc/c/61JQ_A7AOkY)
- [noVNC Issue #1261: Optimize for high latency connection](https://github.com/novnc/noVNC/issues/1261)

**Playwright CDP:**
- [Playwright Issue #31624: Support connectOverCDP in defineConfig](https://github.com/microsoft/playwright/issues/31624)
- [Playwright Issue #11442: Trying to connect to existing playwright session via Chromium CDP](https://github.com/microsoft/playwright/issues/11442)
- [Playwright Issue #17281: Allow downloads not working with connectOverCDP in headless mode](https://github.com/microsoft/playwright/issues/17281)
- [Medium: Automating Custom Browsers with Playwright (Jan 2026)](https://changjoon-baek.medium.com/automating-custom-browsers-with-playwright-a4e0158d0530)

**Chromium Remote Debugging:**
- [Chrome Blog: Changes to remote debugging switches to improve security](https://developer.chrome.com/blog/remote-debugging-port)
- [Docker Chromium Issue #30: can't use remote-debugging-port on chromium](https://github.com/linuxserver/docker-chromium/issues/30)
- [Chromium Issues: --remote-debugging-address not respected with --headless](https://issues.chromium.org/issues/40261787)
- [ytyng.com: How to Expose Chromium's Remote Debugging Port from Docker Container](https://www.ytyng.com/en/blog/docker-chromium-cdp-port/)

**WebSocket/noVNC Proxy:**
- [noVNC Issue #1737: /websockify endpoint fails with path prefix](https://github.com/novnc/noVNC/issues/1737)
- [Launchpad Bug #1915868: novnc-proxy fails through reverse-proxy](https://bugs.launchpad.net/nova/+bug/1915868)
- [noVNC Wiki: Proxying with nginx](https://github.com/novnc/noVNC/wiki/Proxying-with-nginx)
- [OneUpTime Blog: How to Configure WebSocket with Nginx Reverse Proxy (Jan 2026)](https://oneuptime.com/blog/post/2026-01-24-websocket-nginx-reverse-proxy/view)

**Clipboard Issues:**
- [noVNC Issue #1915: COPY PASTE NOT WORKING](https://github.com/novnc/noVNC/issues/1915)
- [x11vnc Issue #260: Clipboard isn't updated from VNC-client](https://github.com/LibVNC/x11vnc/issues/260)
- [Linux Mint Forums: x11vnc clipboard only works in one direction](https://forums.linuxmint.com/viewtopic.php?t=369358)

**Xvfb Multi-Instance:**
- [Cypress Issue #1426: XVFB issues when running two CI instances in parallel](https://github.com/cypress-io/cypress/issues/1426)
- [Jenkins Xvfb Plugin Documentation](https://plugins.jenkins.io/xvfb)
- [Docker-selenium Issue #184: xvfb-run being used incorrectly to set DISPLAY](https://github.com/SeleniumHQ/docker-selenium/issues/184)

**Headless/Headed Switching:**
- [Playwright Issue #26497: "Looks like you launched a headed browser without XServer" even when headless is true](https://github.com/microsoft/playwright/issues/26497)
- [Playwright Issue #30337: Headless mode doesn't have the same behavior](https://github.com/microsoft/playwright/issues/30337)
- [ProxiesAPI: Why Playwright Tests Pass in Headful But Fail Headless](https://proxiesapi.com/articles/why-playwright-tests-pass-in-headful-but-fail-headless-4-key-reasons-and-fixes)

**Synthetic Events:**
- [Playwright Issue #19445: Are events performed by Playwright "Synthetic" or "Native"?](https://github.com/microsoft/playwright/issues/19445)
- [xdotool Google Group: XTEST versus XSendEvent](https://groups.google.com/g/xdotool-users/c/bs4TfB-Ii9c)

**Systemd Debugging:**
- [AlphaBravo Blog: Systemd Zero to Hero Part 4 — Diagnosing Failures](https://blog.alphabravo.io/systemd-zero-to-hero-part-4-diagnosing-failures-and-debugging-like-a-pro/)
- [TheLinuxCode: How to Start, Stop, and Restart Services with systemctl (2026-Ready)](https://thelinuxcode.com/how-to-start-stop-and-restart-services-in-linux-with-systemctl-a-practical-2026-ready-guide/)
- [Container Solutions: Debug Systemd Service Units Runbook](https://containersolutions.github.io/runbooks/posts/linux/debug-systemd-service-units/)

**AI Agent Browser Automation:**
- [Browserless Blog: 2026 Outlook: AI-Driven Browser Automation](https://www.browserless.io/blog/state-of-ai-browser-automation-2026)
- [OAuth 2.1 Features You Can't Ignore in 2026 (Medium)](https://rgutierrez2004.medium.com/oauth-2-1-features-you-cant-ignore-in-2026-a15f852cb723)

**Playwright Visual Testing:**
- [BrowserStack: 15 Best Practices for Playwright testing in 2026](https://www.browserstack.com/guide/playwright-best-practices)
- [TestDino: Playwright Visual Testing Complete Guide](https://testdino.com/blog/playwright-visual-testing/)
- [OneUpTime: How to Implement Playwright Visual Testing (Jan 2026)](https://oneuptime.com/blog/post/2026-01-27-playwright-visual-testing/view)

---

*Pitfalls research for: AI-agent-driven co-browsing with Xvfb/noVNC/Playwright CDP*
*Researched: 2026-02-09*
*Confidence: HIGH — based on verified technical documentation, official bug reports, and recent 2026 sources*
