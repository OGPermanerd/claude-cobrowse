# Stack Research: Remote Browser Co-Browsing Infrastructure

**Domain:** Browser automation and remote co-browsing for AI-driven containers
**Researched:** 2026-02-09
**Confidence:** HIGH

## Executive Summary

For 2025/2026, the optimal stack for remote browser co-browsing where Claude Code drives a browser with optional human observation balances **performance, compatibility, and resource efficiency**. The reference implementation's core approach (Xvfb + CDP + noVNC) remains fundamentally sound, but specific component choices and interaction methods can be optimized based on recent developments and known limitations.

**Key Finding:** The slowness in noVNC browsing is inherent to the VNC protocol's design and cannot be fully eliminated, but can be mitigated through encoding optimization, compression, and most critically: **bypassing noVNC entirely for programmatic interaction** by using Playwright CDP for all automated actions.

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **Xvfb** | System default (Ubuntu 24.04) | Virtual framebuffer for headless display | De facto standard, mature, stable; modern browser native headless modes have limitations with complex UIs that require visual rendering (confirmed by reference implementation) |
| **Chromium** or **Chrome for Testing** | Latest from Ubuntu repos OR Playwright-bundled | Browser engine | Chromium offers lower resource usage (~20% less RAM); Chrome for Testing provides higher fidelity but uses 20GB+ per instance. **Recommendation: Start with Chromium, switch to Chrome for Testing only if compatibility issues arise** |
| **Playwright** | 1.58.0+ (latest: 1.58.0 as of Jan 2026) | Primary automation API | Industry-leading browser automation, actively maintained, best-in-class CDP integration, official migration to Chrome for Testing in v1.57+ |
| **TigerVNC** | Latest from Ubuntu repos | VNC server (faster alternative to x11vnc) | **15-20% faster** than x11vnc with better screen redraw performance and lower memory usage; x11vnc requires 10-20x framebuffer size in memory (100MB+ for 1280x1024) |
| **noVNC** | 1.6.0+ (latest: 1.6.0 as of Mar 2025) | Browser-based VNC client | Zero client installation, mobile support, active development, tight/hextile encoding support, H.264 support for reduced bandwidth |
| **websockify** | 0.13.0+ (latest: May 2025) | WebSocket-to-TCP bridge for noVNC | Official noVNC companion, optional numpy dependency for HyBi protocol performance boost |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **nginx** | 1.24+ (Ubuntu 24.04 default) | Reverse proxy for multi-container routing | Path-based routing to multiple noVNC instances; requires WebSocket upgrade headers for `/websockify` path |
| **ntfy.sh** | 2.16.0+ (latest server) | Push notifications for human intervention alerts | Webhook-based notifications to user's devices; 2026 updates added notification updating/deletion for dead man's switch patterns |
| **Python numpy** | Latest | Performance optimization for websockify | Optional but recommended: improves HyBi WebSocket protocol performance in websockify |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| **xdotool** | Simple X11 event injection (DEPRECATED for complex UIs) | **Do NOT use for modern web apps** (Google, complex SPAs) — synthetic X11 events rejected by most browsers for security; falls back to XSendEvent which browsers ignore |
| **Chrome DevTools Protocol (CDP)** | Direct browser control for complex interactions | Access via `playwright.chromium.connectOverCDP('http://localhost:9222')` — lower fidelity than native Playwright but enables persistent session attachment |
| **Playwright native API** | Preferred interaction method | Higher fidelity than CDP; use for all actions when possible |

## Installation

### Core Components

```bash
# Virtual framebuffer
sudo apt-get update
sudo apt-get install -y xvfb

# TigerVNC (recommended over x11vnc)
sudo apt-get install -y tigervnc-standalone-server tigervnc-common

# Chromium (lightweight option)
sudo apt-get install -y chromium-browser

# OR Chrome for Testing (higher fidelity, more memory)
# Playwright will auto-download when running: npx playwright install chromium

# noVNC and websockify
sudo apt-get install -y novnc websockify python3-numpy

# Reverse proxy
sudo apt-get install -y nginx
```

### Playwright Setup

```bash
# Install Playwright
npm install -D @playwright/test@latest

# Install browser binaries (includes Chrome for Testing as of v1.57+)
npx playwright install chromium

# For lower memory usage, use system Chromium instead:
# Set PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 before npm install
# and configure to use /usr/bin/chromium-browser
```

### Optional: ntfy.sh for Notifications

```bash
# Self-hosted option
docker pull binwiederhier/ntfy
docker run -p 80:80 -it binwiederhier/ntfy serve

# Or use hosted service at https://ntfy.sh
curl -d "Claude needs your input on project-name" https://ntfy.sh/your-topic
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| **TigerVNC** | x11vnc | Never for production — x11vnc is 15-20% slower with poor screen redraw performance and high memory usage |
| **TigerVNC** | Apache Guacamole | When HTML5 RDP support is needed; provides clientless RDP/VNC/SSH access but heavier weight and requires Java backend |
| **noVNC** | SPICE protocol | When running KVM/QEMU VMs with multimedia requirements; SPICE requires client installation and is designed for VM hypervisor access, not browser automation |
| **noVNC** | Kasm Workspaces | For enterprise browser isolation or multi-user environments; overkill for single-operator AI agent use case |
| **Xvfb** | Native browser headless mode | When you don't need visual display at all; but reference implementation proves complex UIs (Google Apps Script, forms) require visual rendering |
| **Chromium** | Chrome for Testing | When maximum compatibility is required; trade-off: **20GB+ RAM per instance** vs Chromium's ~5-10GB |
| **Playwright CDP (connectOverCDP)** | Playwright native (browserType.connect) | Always prefer `.connect()` when launching browsers yourself — higher fidelity; use `.connectOverCDP()` only when attaching to existing Chrome with `--remote-debugging-port` |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| **xdotool for complex web UIs** | Modern browsers reject synthetic X11 events for security; XSendEvent flagged and ignored; **confirmed broken with Google Apps Script, complex SPAs** | Playwright CDP or native Playwright API via `page.evaluate()` |
| **Clipboard bridges for text injection** | Unnecessary complexity; clipboard state conflicts; security restrictions in modern browsers | `page.fill()`, `page.type()`, or `page.evaluate(() => element.value = 'text')` |
| **x11vnc** | Slow screen redraw (user-reported 15-20% slower), high memory usage (requires 10-20x framebuffer RAM), poor performance under load | TigerVNC |
| **noVNC for programmatic interactions** | **THIS IS THE MAIN PERFORMANCE BOTTLENECK** — VNC is inherently slow for interactive use; designed for screen transmission, not automation | **Use Playwright CDP/API for ALL automated actions**; noVNC is ONLY for human observation |
| **XSendEvent** | Explicitly flagged by X11, applications ignore it for security | XTEST extension (but even this fails in modern browsers — use Playwright instead) |
| **Chrome remote debugging without --user-data-dir** | **Security change in Chrome 136+**: `--remote-debugging-port` rejected on default data dir | Always use `--user-data-dir=/path/to/custom/dir` with `--remote-debugging-port=9222` |

## Stack Patterns by Use Case

### Pattern 1: Headless-First with On-Demand Display (RECOMMENDED)

**When:** Claude Code drives browser 95% of the time, human observes occasionally

**Stack:**
```
Playwright (native API)
  ↓
Chrome/Chromium (headless by default)
  ↓
Xvfb :99 (started but unused unless headed mode enabled)
  ↓
TigerVNC (vncserver :1) → websockify → nginx → noVNC (human browser)
```

**Benefits:**
- Minimal resource usage during headless operation
- Switch to headed mode on-demand: `browser.launch({ headless: false })`
- noVNC always available but not consuming bandwidth until human connects

**Drawbacks:**
- Requires browser restart to switch headless ↔ headed (cannot switch at runtime for existing instance)

### Pattern 2: Persistent Headed Browser with CDP Attachment

**When:** Browser must stay visible for entire session (OAuth flows, visual debugging)

**Stack:**
```
Playwright CDP (connectOverCDP)
  ↓
Chrome with --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-profile
  ↓
Xvfb :99 (DISPLAY=:99)
  ↓
TigerVNC → websockify → nginx → noVNC
```

**Launch command:**
```bash
DISPLAY=:99 chromium-browser \
  --remote-debugging-port=9222 \
  --user-data-dir=/tmp/chrome-profile \
  --no-first-run \
  --disable-gpu \
  2>&1 | tee /tmp/chrome.log &
```

**Playwright connection:**
```javascript
const browser = await playwright.chromium.connectOverCDP('http://localhost:9222');
const context = browser.contexts()[0];
const page = context.pages()[0] || await context.newPage();
```

**Benefits:**
- Browser persists across Playwright script restarts
- Human can observe in real-time via noVNC
- Session state (cookies, localStorage) preserved

**Drawbacks:**
- Lower fidelity than native Playwright (per official docs: "significantly lower fidelity")
- Chrome 136+ requires `--user-data-dir` (security change 2026)

### Pattern 3: Hybrid — Headless with Screenshot Escalation

**When:** Maximize performance, only show browser on error/auth detection

**Stack:**
```
Playwright (native, headless=true)
  ↓
Chrome/Chromium
  ↓
On error/OAuth detection:
  1. Take screenshot → analyze → decide if human needed
  2. Launch new headed browser with saved cookies
  3. Notify human via ntfy.sh
  4. Human intervenes via noVNC
  5. Resume headless automation
```

**Benefits:**
- Best performance (headless majority of time)
- noVNC/TigerVNC only running when needed
- Clear escalation path

**Drawbacks:**
- More complex orchestration logic
- Browser state transfer overhead (export/import cookies)

## Performance Optimization Recommendations

### Critical: Bypass noVNC for Automation

**The Problem:** noVNC browsing is slow because VNC transmits pixels, not actions. Every interaction (click, type, scroll) requires:
1. Client → websockify → VNC server (input event)
2. VNC server → browser (synthetic event, if accepted)
3. Browser → framebuffer (render update)
4. Framebuffer → VNC server (detect changes)
5. VNC server → websockify → noVNC (pixel diff encoding)
6. noVNC → browser (canvas update)

**The Solution:**
- **noVNC is ONLY for human observation, never for automation**
- **ALL programmatic interactions via Playwright API/CDP**
- Text injection: `page.fill('#input', 'text')` or `page.evaluate(() => document.querySelector('#input').value = 'text')`
- Clicks: `page.click('button')`
- Complex interactions: `page.evaluate()` to run JavaScript directly in page context

**Performance gain:** 10-100x faster than noVNC mouse/keyboard for complex workflows

### noVNC Encoding Optimization

When humans DO use noVNC, optimize encoding:

```javascript
// noVNC client settings
compression: 9,          // Max compression
qualityLevel: 9,         // Max quality (paradoxically can improve speed on slow connections)
preferredEncoding: 'tight'  // Or 'hextile' — both more efficient than 'raw'
```

**Note:** noVNC 1.6.0 supports H.264 encoding for video-like scenarios but requires H.264 VNC server support (not in TigerVNC by default)

### Xvfb Configuration

```bash
# Optimal for 1080p display with 24-bit color
Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset

# For lower bandwidth, use smaller resolution
Xvfb :99 -screen 0 1280x720x24 -ac +extension GLX +render -noreset
```

**Memory consideration:** Framebuffer uses ~6MB for 1920x1080x24 (W × H × depth / 8)

### TigerVNC Configuration

```bash
# Start TigerVNC with optimal settings
vncserver :1 -geometry 1920x1080 -depth 24 -localhost -nolisten tcp

# Or for lower bandwidth
vncserver :1 -geometry 1280x720 -depth 24 -localhost -nolisten tcp
```

**Security note:** `-localhost` ensures VNC only binds to 127.0.0.1; nginx reverse proxy provides external access

### nginx Reverse Proxy

```nginx
# /etc/nginx/sites-available/cobrowse
upstream project1_novnc {
    server 127.0.0.1:6080;
}

upstream project2_novnc {
    server 127.0.0.1:6081;
}

server {
    listen 80;
    server_name cobrowse.local;

    # Disable caching for VNC streams
    proxy_buffering off;

    location /project1/ {
        proxy_pass http://project1_novnc/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;  # 24 hours for persistent connections
    }

    location /project1/websockify {
        proxy_pass http://project1_novnc/websockify;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;
    }

    # Repeat for project2, project3, etc.
}
```

**Key settings:**
- `proxy_buffering off` — prevents caching of VNC stream
- `proxy_read_timeout 86400` — prevents timeout on idle connections
- `proxy_http_version 1.1` + `Upgrade`/`Connection` headers — required for WebSocket

### Text Injection Without Clipboard

**Best practices ranked by performance:**

1. **Playwright API (fastest, most reliable):**
   ```javascript
   await page.fill('#username', 'user@example.com');  // For form inputs
   await page.type('#search', 'query text', { delay: 0 });  // With optional typing delay
   ```

2. **Direct DOM manipulation via page.evaluate (instant):**
   ```javascript
   await page.evaluate(({ selector, text }) => {
       const el = document.querySelector(selector);
       el.value = text;
       el.dispatchEvent(new Event('input', { bubbles: true }));
       el.dispatchEvent(new Event('change', { bubbles: true }));
   }, { selector: '#input', text: 'value' });
   ```

3. **CDP Input.insertText (low-level, for special cases):**
   ```javascript
   const client = await page.context().newCDPSession(page);
   await client.send('Input.insertText', { text: 'value' });
   ```

**NEVER use:**
- Clipboard bridges (HTTP servers for clip/paste)
- X11 clipboard utilities (xclip, xsel)
- noVNC clipboard sync

**Why:** Modern browsers restrict clipboard access; adds complexity; Playwright methods work reliably and bypass all clipboard limitations

### Notification System

**Browser tab title flash (for when user is watching):**
```javascript
// In noVNC HTML, inject this script
let originalTitle = document.title;
let flashInterval = setInterval(() => {
    document.title = document.title === originalTitle
        ? '🔔 INPUT NEEDED'
        : originalTitle;
}, 1000);

// Stop flashing when user focuses tab
document.addEventListener('visibilitychange', () => {
    if (!document.hidden) {
        clearInterval(flashInterval);
        document.title = originalTitle;
    }
});
```

**External webhook (for when user is away):**
```bash
# Send ntfy notification
curl -H "Title: Project my-app needs input" \
     -H "Priority: high" \
     -H "Tags: warning,computer" \
     -d "OAuth login required at /auth/google" \
     https://ntfy.sh/claude-cobrowse-alerts
```

**ntfy.sh features (2026):**
- Notification updating/deletion (dead man's switch pattern)
- Action buttons in notifications
- Webhook templates with Go template syntax
- mTLS client certificates for self-hosted

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| Playwright 1.58.0 | Chrome for Testing 134+ | Auto-bundled; major/minor version must match (1.58.x ↔ 1.58.y) |
| Playwright 1.58.0 | Chromium (system) | Set `channel: 'chromium'` in launch options OR `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1` |
| noVNC 1.6.0 | websockify 0.13.0+ | Requires WebSocket support; Python 3.8+ |
| websockify 0.13.0 | numpy (optional) | Performance boost for HyBi protocol; not required |
| TigerVNC | Xvfb (any modern version) | No specific version coupling |
| Chrome with --remote-debugging-port | Chrome 136+ | **MUST use --user-data-dir** with non-default directory (security change 2026) |

## Architecture Decision Records

### ADR 1: TigerVNC over x11vnc

**Decision:** Use TigerVNC as VNC server instead of x11vnc

**Rationale:**
- 15-20% faster screen redraw (user-reported benchmarks)
- Lower memory footprint (x11vnc requires 10-20x framebuffer size)
- Better performance under continuous screen updates
- Actively maintained

**Trade-offs:**
- x11vnc can export existing X display (Xvfb :99); TigerVNC creates new display
- Requires mapping TigerVNC :1 to Xvfb :99 OR running browser directly on TigerVNC's X server

**Implementation note:** For this use case (dedicated co-browsing), running browser on TigerVNC's built-in X server is acceptable (no need for Xvfb)

### ADR 2: Playwright Native API over CDP for Primary Automation

**Decision:** Use Playwright native API (`browser.launch()`) for primary automation, CDP (`connectOverCDP`) only for persistent sessions

**Rationale:**
- Official documentation: "significantly lower fidelity" for CDP connection
- Native Playwright protocol is higher performance and more reliable
- CDP useful for attaching to already-running browser but not ideal for automation

**Trade-offs:**
- Native API requires browser restart to switch headless ↔ headed
- CDP allows persistent browser across script restarts but with degraded functionality

**When to use CDP:**
- Browser must persist across Playwright script lifecycle
- Session state (cookies, history) must be preserved
- Human interaction via noVNC happens first, then automation resumes

### ADR 3: Chromium over Chrome for Testing (Default)

**Decision:** Default to system Chromium; use Chrome for Testing only when compatibility issues arise

**Rationale:**
- Chrome for Testing (Playwright 1.57+) uses **20GB+ RAM per instance** (reported issue #38489)
- System Chromium uses ~5-10GB per instance
- For 3-5 concurrent containers, memory difference is 50-100GB vs 15-50GB
- Compatibility differences minimal for most web apps

**Trade-offs:**
- Chrome for Testing is "more authentic" (Google's words) and matches production Chrome exactly
- Chromium may lag behind Chrome by ~2-4 weeks
- For bleeding-edge testing, Chrome for Testing is superior

**Override when:**
- Testing against specific Chrome version required
- Compatibility issues detected with Chromium
- Memory is abundant (64GB+ per container)

### ADR 4: No xdotool for Modern Web Applications

**Decision:** Do NOT use xdotool for interaction with modern web apps (SPAs, Google services, complex forms)

**Rationale:**
- Reference implementation confirms Google Apps Script and complex UIs ignore X11 synthetic events
- Browsers reject XSendEvent for security (flagged in X11 protocol)
- Even XTEST extension fails with Firefox, Chrome security policies
- Wayland incompatibility (though not applicable to Xvfb)

**Trade-offs:**
- xdotool is simple and lightweight for basic X11 apps
- Loss of "native-looking" mouse movements (but irrelevant since events are rejected anyway)

**Acceptable uses:**
- Window management (`xdotool search --name 'Chrome' windowactivate`)
- Non-browser X11 applications (terminals, file managers)
- Testing X11 event handling itself

## Sources

### High Confidence (Official Documentation)

- [Playwright BrowserType API](https://playwright.dev/docs/api/class-browsertype) — connectOverCDP fidelity warning, version compatibility
- [Playwright CDPSession API](https://playwright.dev/docs/api/class-cdpsession) — CDP capabilities and usage
- [Chrome DevTools Protocol](https://chromedevtools.github.io/devtools-protocol/) — Stable domains and protocol reference
- [Playwright Release Notes](https://playwright.dev/docs/release-notes) — Version 1.58.0 current as of Jan 2026
- [noVNC GitHub Repository](https://github.com/novnc/noVNC) — Version 1.6.0 released Mar 2025
- [websockify GitHub Releases](https://github.com/novnc/websockify/releases) — Version 0.13.0 released May 2025
- [ntfy.sh Documentation](https://docs.ntfy.sh/) — Version 2.16.0 features (Jan 2026)
- [Chrome for Developers Blog: Remote Debugging Changes](https://developer.chrome.com/blog/remote-debugging-port) — Chrome 136+ --user-data-dir requirement

### Medium Confidence (Verified Community Sources)

- [noVNC Wiki: Proxying with nginx](https://github.com/novnc/noVNC/wiki/Proxying-with-nginx) — nginx WebSocket proxy configuration
- [Connecting Playwright to Existing Browser | BrowserStack](https://www.browserstack.com/guide/playwright-connect-to-existing-browser) — connectOverCDP usage patterns
- [VNC Server Software Comparison | DoHost](https://dohost.us/index.php/2025/11/05/vnc-server-software-comparison-tightvnc-tigervnc-realvnc-x11vnc/) — TigerVNC vs x11vnc performance
- [Websockify & noVNC behind an NGINX Proxy | DataWookie](https://datawookie.dev/blog/2021/08/websockify-novnc-behind-an-nginx-proxy/) — Path routing configuration
- [Playwright Issue #38489: Chrome for Testing Memory Usage](https://github.com/microsoft/playwright/issues/38489) — 20GB+ RAM per instance report
- [xdotool Issue #151: Synthetic Events](https://github.com/jordansissel/xdotool/issues/151) — Modern browsers reject synthetic events

### Context-Specific (Reference Implementation)

- Project context: Working reference box with Xvfb :99 + Chromium --remote-debugging-port=9222 + noVNC
- Validated finding: Google's complex UIs don't respond to synthetic X11 events; Playwright CDP required
- Known pain point: Slow browsing via noVNC (VNC protocol limitation)
- Known workflow: noVNC for OAuth flows, Playwright CDP for complex automation

---

*Stack research for: Remote Browser Co-Browsing Infrastructure*
*Researched: 2026-02-09*
*Next: Architect system integration patterns and phase roadmap*
