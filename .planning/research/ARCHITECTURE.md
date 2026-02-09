# Architecture Research

**Domain:** Multi-container AI-driven co-browsing infrastructure
**Researched:** 2026-02-09
**Confidence:** HIGH

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        USER WORKSTATION (Laptop)                             │
│  ┌─────────────────────────────────────────────────────────────────┐        │
│  │  Browser (3-5 tabs, one per container)                          │        │
│  │  http://proxy.domain/project-a/   (noVNC client)                │        │
│  │  http://proxy.domain/project-b/   (noVNC client)                │        │
│  │  http://proxy.domain/project-c/   (noVNC client)                │        │
│  └─────────────────────────────────────────────────────────────────┘        │
│           ↑                                                                  │
│           │ WebSocket (RFB protocol over HTTP)                               │
│           │ Tab title flash notifications                                    │
└───────────┼──────────────────────────────────────────────────────────────────┘
            │
            ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│                    REVERSE PROXY (Nginx on host)                             │
│  ┌───────────────────────────────────────────────────────────────┐          │
│  │  Path-based routing:                                          │          │
│  │  /project-a/ → localhost:6080 (container-1 noVNC)             │          │
│  │  /project-b/ → localhost:6081 (container-2 noVNC)             │          │
│  │  /project-c/ → localhost:6082 (container-3 noVNC)             │          │
│  │                                                                │          │
│  │  WebSocket upgrade handling (Upgrade, Connection headers)     │          │
│  │  proxy_read_timeout: 3600s                                    │          │
│  └───────────────────────────────────────────────────────────────┘          │
└───────────┬─────────────────┬─────────────────┬───────────────────────────────┘
            │                 │                 │
            ↓                 ↓                 ↓
┌───────────────────┐ ┌───────────────────┐ ┌───────────────────┐
│  CONTAINER 1      │ │  CONTAINER 2      │ │  CONTAINER 3      │
│  (Project A)      │ │  (Project B)      │ │  (Project C)      │
│                   │ │                   │ │                   │
│ ┌───────────────┐ │ │ ┌───────────────┐ │ │ ┌───────────────┐ │
│ │ noVNC Server  │ │ │ │ noVNC Server  │ │ │ │ noVNC Server  │ │
│ │ (Port 6080)   │ │ │ │ (Port 6081)   │ │ │ │ (Port 6082)   │ │
│ │ + websockify  │ │ │ │ + websockify  │ │ │ │ + websockify  │ │
│ └───────┬───────┘ │ │ └───────┬───────┘ │ │ └───────┬───────┘ │
│         │         │ │         │         │ │         │         │
│         ↓         │ │         ↓         │ │         ↓         │
│ ┌───────────────┐ │ │ ┌───────────────┐ │ │ ┌───────────────┐ │
│ │ x11vnc        │ │ │ │ x11vnc        │ │ │ │ x11vnc        │ │
│ │ (VNC Server)  │ │ │ │ (VNC Server)  │ │ │ │ (VNC Server)  │ │
│ │ Port 5900     │ │ │ │ Port 5900     │ │ │ │ Port 5900     │ │
│ └───────┬───────┘ │ │ └───────┬───────┘ │ │ └───────┬───────┘ │
│         │         │ │         │         │ │         │         │
│         ↓         │ │         ↓         │ │         ↓         │
│ ┌───────────────┐ │ │ ┌───────────────┐ │ │ ┌───────────────┐ │
│ │ Xvfb :99      │ │ │ │ Xvfb :99      │ │ │ │ Xvfb :99      │ │
│ │ (Virtual      │ │ │ │ (Virtual      │ │ │ │ (Virtual      │ │
│ │  Display)     │ │ │ │  Display)     │ │ │ │  Display)     │ │
│ │ 1920x1080x24  │ │ │ │ 1920x1080x24  │ │ │ │ 1920x1080x24  │ │
│ └───────┬───────┘ │ │ └───────┬───────┘ │ │ └───────┬───────┘ │
│         │         │ │         │         │ │         │         │
│         ↓         │ │         ↓         │ │         ↓         │
│ ┌───────────────┐ │ │ ┌───────────────┐ │ │ ┌───────────────┐ │
│ │ Chromium      │ │ │ │ Chromium      │ │ │ │ Chromium      │ │
│ │ --display=:99 │ │ │ │ --display=:99 │ │ │ │ --display=:99 │ │
│ │ --remote-     │ │ │ │ --remote-     │ │ │ │ --remote-     │ │
│ │  debugging-   │ │ │ │  debugging-   │ │ │ │  debugging-   │ │
│ │  port=9222    │ │ │ │  port=9222    │ │ │ │  port=9222    │ │
│ └───────┬───────┘ │ │ └───────┬───────┘ │ │ └───────┬───────┘ │
│         │         │ │         │         │ │         │         │
│         │         │ │         │         │ │         │         │
│  ┌──────┴──────┐  │ │  ┌──────┴──────┐  │ │  ┌──────┴──────┐  │
│  │             │  │ │  │             │  │ │  │             │  │
│  ↓             ↓  │ │  ↓             ↓  │ │  ↓             ↓  │
│ ┌──────┐  ┌──────┐│ │ ┌──────┐  ┌──────┐│ │ ┌──────┐  ┌──────┐│
│ │Claude│  │Play- ││ │ │Claude│  │Play- ││ │ │Claude│  │Play- ││
│ │ Code │  │wright││ │ │ Code │  │wright││ │ │ Code │  │wright││
│ │(Agent)  │ CDP  ││ │ │(Agent)  │ CDP  ││ │ │(Agent)  │ CDP  ││
│ └──────┘  └──────┘│ │ └──────┘  └──────┘│ │ └──────┘  └──────┘│
│   localhost:9222  │ │   localhost:9222  │ │   localhost:9222  │
│                   │ │                   │ │                   │
│ ┌───────────────┐ │ │ ┌───────────────┐ │ │ ┌───────────────┐ │
│ │Notification   │ │ │ │Notification   │ │ │ │Notification   │ │
│ │System         │ │ │ │System         │ │ │ │System         │ │
│ │- Tab title    │ │ │ │- Tab title    │ │ │ │- Tab title    │ │
│ │  flash script │ │ │ │  flash script │ │ │ │  flash script │ │
│ │- Webhook      │ │ │ │- Webhook      │ │ │ │- Webhook      │ │
│ │  (ntfy.sh)    │ │ │ │  (ntfy.sh)    │ │ │ │  (ntfy.sh)    │ │
│ └───────────────┘ │ │ └───────────────┘ │ │ └───────────────┘ │
└───────────────────┘ └───────────────────┘ └───────────────────┘
   Ubuntu 24.04 LXC    Ubuntu 24.04 LXC    Ubuntu 24.04 LXC
   32GB/8vCPU          32GB/8vCPU          32GB/8vCPU
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| **Reverse Proxy (Nginx)** | Single entry point for all containers; path-based routing to noVNC instances; WebSocket upgrade handling | Nginx config with location blocks, proxy_pass to localhost:608X, WebSocket headers |
| **noVNC + websockify** | HTML5 VNC client; WebSocket-to-TCP bridge for RFB protocol | noVNC web UI served on port 6080+, websockify bridges to x11vnc on 5900 |
| **x11vnc** | VNC server capturing Xvfb framebuffer; enables human viewing/interaction | `x11vnc -display :99 -rfbport 5900 -shared -forever` |
| **Xvfb** | Virtual X11 display server; no physical display required | `Xvfb :99 -screen 0 1920x1080x24` running as daemon |
| **Chromium** | Browser with CDP enabled; dual-control via noVNC (human) and Playwright (AI) | Launched with `--display=:99 --remote-debugging-port=9222` |
| **Claude Code Agent** | AI orchestrator; drives browser via Playwright; detects when human needed; triggers notifications | Node.js process with Playwright SDK, connects via CDP |
| **Playwright CDP** | High-fidelity browser automation; complex interactions; state manipulation | `chromium.connectOverCDP('http://localhost:9222')` |
| **Notification System** | Alerts human when container needs input; tab title flash + webhook | Script injecting DOM manipulation + HTTP POST to ntfy.sh |

## Recommended Project Structure

```
claude-cobrowse/                    # Distribution kit repository
├── template/                       # Per-project scaffolding assets
│   ├── playwright.config.ts        # Existing: E2E test config
│   ├── tests/e2e/                  # Existing: Test templates
│   │   ├── auth.setup.ts           # Existing: JWT minting
│   │   └── example.spec.ts         # Existing: Sample test
│   └── .gitignore.partial          # Existing: Git ignore entries
│
├── cobrowse/                       # NEW: Co-browsing infrastructure
│   ├── setup/                      # NEW: Installation scripts
│   │   ├── install-deps.sh         # Install Xvfb, x11vnc, noVNC, Chromium
│   │   ├── configure-display.sh    # Set up Xvfb + x11vnc services
│   │   ├── configure-proxy.sh      # Generate nginx config for container
│   │   └── test-stack.sh           # Verify display → VNC → noVNC chain
│   │
│   ├── runtime/                    # NEW: Runtime control scripts
│   │   ├── browser-manager.sh      # Start/stop Chromium with CDP
│   │   ├── display-manager.sh      # Start/stop Xvfb + x11vnc
│   │   ├── mode-switch.ts          # Playwright headless ↔ headed logic
│   │   └── notify.ts               # Trigger tab title flash + webhook
│   │
│   ├── playwright-cdp/             # NEW: CDP integration helpers
│   │   ├── connect.ts              # chromium.connectOverCDP wrapper
│   │   ├── headless-switch.ts      # Runtime mode switching logic
│   │   ├── interaction-test.ts     # Test fill vs type vs keyboard
│   │   └── screenshot-feedback.ts  # Capture → analyze → act loop
│   │
│   ├── notification/               # NEW: Human alert system
│   │   ├── tab-flash.js            # Inject into noVNC page via CDP
│   │   ├── webhook-send.ts         # POST to ntfy.sh or Slack
│   │   ├── detect-complete.ts      # Auto-detect interaction done
│   │   └── manual-signal.sh        # User-triggered "done" signal
│   │
│   └── proxy/                      # NEW: Reverse proxy templates
│       ├── nginx-template.conf     # Per-container location block
│       └── merge-configs.sh        # Combine all container configs
│
├── claude/                         # Existing: Global Claude instructions
│   └── CLAUDE.md                   # Existing: E2E testing discipline
│
├── install.sh                      # Existing: Global setup (E2E kit)
├── scaffold.sh                     # Existing: Per-project setup (E2E kit)
│
├── cobrowse-install.sh             # NEW: Global co-browsing setup
└── cobrowse-scaffold.sh            # NEW: Per-container co-browsing setup
```

### Structure Rationale

- **Separation of concerns**: E2E testing (existing) vs co-browsing infrastructure (new) are distinct domains; keep them in separate top-level directories
- **Template-driven distribution**: Follows existing pattern — `/template` for E2E, `/cobrowse` for co-browsing
- **Script-based installation**: Mirrors existing `install.sh`/`scaffold.sh` pattern; new scripts for co-browsing setup
- **Runtime vs setup distinction**: `/cobrowse/setup` = one-time installation, `/cobrowse/runtime` = operational scripts
- **Testing integration**: `/cobrowse/playwright-cdp` extends existing Playwright stack with CDP capabilities

## Architectural Patterns

### Pattern 1: Headless-First with On-Demand Display

**What:** Browser runs headless (no Xvfb) by default; switches to headed mode (Xvfb + noVNC) only when human interaction needed.

**When to use:** Resource-constrained containers running 3-5 concurrent projects; most automation is fire-and-forget.

**Trade-offs:**
- **Pro:** Saves CPU/memory when display not needed (Xvfb consumes ~100MB RAM, x11vnc ~50MB)
- **Pro:** Faster browser startup in headless mode
- **Con:** Mode switching requires browser restart (cannot change `--display` of running Chromium)
- **Con:** Adds complexity to orchestration logic

**Example:**
```typescript
// cobrowse/playwright-cdp/headless-switch.ts
import { chromium } from '@playwright/test';

let browser = null;
let displayMode = 'headless'; // 'headless' | 'headed'

export async function ensureHeadedMode() {
  if (displayMode === 'headed') {
    return browser; // Already in headed mode
  }

  // Close headless browser if running
  if (browser) {
    await browser.close();
  }

  // Start Xvfb + x11vnc if not running
  await startDisplayStack();

  // Launch Chromium in headed mode (connected to Xvfb)
  browser = await chromium.connectOverCDP('http://localhost:9222', {
    // CDP connection to already-running Chromium started with:
    // chromium --display=:99 --remote-debugging-port=9222
  });

  displayMode = 'headed';
  return browser;
}

export async function ensureHeadlessMode() {
  if (displayMode === 'headless') {
    return browser;
  }

  if (browser) {
    await browser.close();
  }

  // Stop Xvfb + x11vnc to save resources
  await stopDisplayStack();

  // Launch Chromium headless (no --display flag)
  browser = await chromium.launch({
    headless: true,
    args: ['--remote-debugging-port=9222']
  });

  displayMode = 'headless';
  return browser;
}
```

### Pattern 2: Always-On Display with Lazy VNC Connection

**What:** Xvfb + Chromium always run with `--display=:99`; x11vnc + noVNC start only when human needs to view.

**When to use:** Sufficient resources (32GB RAM containers); frequent need for visual debugging; simpler state management.

**Trade-offs:**
- **Pro:** No browser restart required — same Chromium instance throughout
- **Pro:** Simpler mode switching — just start/stop x11vnc, not browser
- **Pro:** Playwright CDP connection never breaks
- **Con:** Xvfb always consuming resources even when not viewed
- **Con:** Slightly slower than headless mode (rendering overhead even if not transmitted)

**Example:**
```bash
# cobrowse/runtime/display-manager.sh
#!/bin/bash

start_vnc() {
  if pgrep x11vnc > /dev/null; then
    echo "x11vnc already running"
    return
  fi

  # Xvfb already running permanently
  x11vnc -display :99 -rfbport 5900 -shared -forever -bg -nopw

  # Start websockify + noVNC
  cd /opt/noVNC
  ./utils/novnc_proxy --vnc localhost:5900 --listen 6080 &
}

stop_vnc() {
  pkill x11vnc
  pkill websockify
  echo "VNC stopped; Xvfb and Chromium still running"
}
```

**Recommendation:** Pattern 2 (Always-On Display) is better for this use case because:
1. Resources are abundant (32GB RAM, 8 vCPU per container)
2. Playwright CDP stability is critical — reconnecting after browser restart risks losing session state
3. Simpler implementation — mode switch = start/stop VNC, not browser orchestration
4. Proven on reference box (already working this way)

### Pattern 3: CDP as Single Source of Truth

**What:** All browser control flows through Chrome DevTools Protocol; Playwright uses `connectOverCDP()` to attach to persistent browser instance.

**When to use:** Multi-client control (AI + human simultaneously); long-running browser sessions; state preservation across automation runs.

**Trade-offs:**
- **Pro:** Multiple clients (Playwright + noVNC + screenshot tools) can access same browser
- **Pro:** Browser outlives individual Playwright script executions
- **Pro:** Matches proven reference implementation (already working this way)
- **Con:** Lower fidelity than native Playwright protocol (some advanced features unavailable)
- **Con:** Requires manual browser lifecycle management (systemd service or supervisor)

**Example:**
```typescript
// cobrowse/playwright-cdp/connect.ts
import { chromium } from '@playwright/test';

export async function connectToManagedBrowser() {
  // Assumes Chromium started externally via:
  // chromium --display=:99 --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-profile

  const browser = await chromium.connectOverCDP('http://localhost:9222');

  // Get existing contexts (pages user might have already opened via noVNC)
  const contexts = browser.contexts();
  const context = contexts[0] || await browser.newContext();

  return { browser, context };
}
```

## Data Flow

### Request Flow: AI Agent → Browser

```
Claude Code Command (e.g., "Navigate to login page")
    ↓
Playwright Script (TypeScript)
    ↓
CDP WebSocket (localhost:9222)
    ↓
Chromium Browser Process
    ↓
DOM Manipulation / Network Request
    ↓
Rendering to Xvfb Framebuffer (:99)
    ↓
[Optional] x11vnc captures framebuffer → noVNC → Human viewer
```

### Request Flow: Human → Browser

```
Human clicks in noVNC tab (browser)
    ↓
noVNC Client (JavaScript in browser)
    ↓
WebSocket to websockify (RFB protocol)
    ↓
websockify bridges to x11vnc (port 5900)
    ↓
x11vnc injects X11 events into Xvfb display
    ↓
Chromium receives X11 input events
    ↓
Browser updates DOM / triggers event handlers
    ↓
[Optional] Playwright detects DOM change via CDP event listeners
```

### Notification Flow: Container → Human

```
Claude Code detects interaction needed (e.g., OAuth login page)
    ↓
Trigger notification script (cobrowse/notification/notify.ts)
    ↓
┌──────────────────────────┬──────────────────────────┐
│                          │                          │
│  Tab Title Flash         │  Webhook Notification    │
│                          │                          │
│  CDP → Page.evaluate()   │  HTTP POST               │
│  Inject JS into noVNC    │  to ntfy.sh              │
│  HTML page:              │  or Slack webhook        │
│                          │                          │
│  setInterval(() => {     │  fetch('https://ntfy.sh/ │
│    document.title =      │    my-topic', {          │
│      document.title      │    method: 'POST',       │
│        .startsWith('🔔') │    body: JSON.stringify( │
│      ? 'Project A needs  │      {                   │
│         input'           │        title: 'Project A'│
│      : '🔔 Project A     │        message: 'OAuth   │
│         needs input';    │          login needed'   │
│  }, 1000);               │      })                  │
│                          │  })                      │
│                          │                          │
└──────────────────────────┴──────────────────────────┘
                          ↓
              Human notices flashing tab
              or receives push notification
                          ↓
              Human switches to noVNC tab
                          ↓
              Human completes OAuth flow via noVNC
```

### Interaction Completion Detection

```
Human completes OAuth in noVNC
    ↓
Chromium updates (URL changes OR expected element appears)
    ↓
┌─────────────────────────┬─────────────────────────┐
│                         │                         │
│  Auto-detection         │  Manual signal          │
│  (preferred)            │  (fallback)             │
│                         │                         │
│  Playwright CDP         │  HTTP endpoint          │
│  event listeners:       │  /signal-done           │
│                         │                         │
│  page.on('framenavigated│  User clicks "Done"     │
│    () => {              │  button in UI or runs:  │
│    if (url.includes(    │                         │
│      'oauth/callback')) │  curl http://localhost: │
│      resumeAutomation();│    3001/signal-done     │
│  });                    │                         │
│                         │  Triggers:              │
│  await page.waitFor     │  resumeAutomation();    │
│    Selector(            │                         │
│    '.dashboard-welcome',│                         │
│    { timeout: 300000 }) │                         │
│                         │                         │
└─────────────────────────┴─────────────────────────┘
                          ↓
              Stop tab title flash
                          ↓
              Resume automated workflow
```

### State Management

**Browser State Persistence:**
```
Chromium launched with --user-data-dir=/home/dev/.cobrowse/project-a/chrome-profile
    ↓
Cookies, localStorage, sessionStorage persisted to disk
    ↓
Browser restart preserves authenticated sessions
    ↓
Playwright can access existing state via CDP
```

**Playwright Storage State (for E2E tests):**
```
auth.setup.ts mints JWT → saves to playwright/.auth/user.json
    ↓
example.spec.ts loads storage state
    ↓
All tests inherit authenticated session
```

**Display Stack State (systemd services):**
```
systemd manages lifecycle:
  - xvfb@99.service (Xvfb always running)
  - chromium-cdp@project-a.service (Chromium with CDP port 9222)
  - x11vnc@project-a.service (on-demand or always-on, depending on pattern)
  - novnc@project-a.service (on-demand or always-on)
```

### Key Data Flows

1. **AI-driven automation flow:** Claude Code → Playwright (TypeScript) → CDP WebSocket → Chromium → DOM → Xvfb framebuffer
2. **Human viewing flow:** Xvfb framebuffer → x11vnc (capture) → websockify (bridge) → noVNC client (browser on laptop)
3. **Human interaction flow:** noVNC client → WebSocket → websockify → x11vnc → X11 events → Chromium
4. **Notification flow:** Playwright detects condition → notify.ts → Tab title flash (CDP) + Webhook (HTTP POST)
5. **State persistence flow:** Chromium --user-data-dir → Disk → Survives restart

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 1-3 containers | Single Nginx config with manual location blocks; no auto-discovery needed |
| 3-5 containers | Template-based Nginx config generation; `merge-configs.sh` script combines per-container blocks |
| 5-10 containers | Dynamic proxy registration (etcd/consul + confd for nginx auto-reload); consider resource limits per container |
| 10+ containers | Multi-host deployment; load balancer in front of multiple Nginx proxies; centralized notification hub |

### Scaling Priorities

1. **First bottleneck: Port exhaustion on single host**
   - Problem: Each container needs unique noVNC port (6080, 6081, 6082...)
   - Fix: Path-based routing instead of port-based (already planned)
   - Alternative: Subdomain-based routing (project-a.proxy.domain, project-b.proxy.domain)

2. **Second bottleneck: Nginx config management**
   - Problem: Manual editing of nginx.conf for each new container
   - Fix: Template-based generation with `cobrowse/proxy/merge-configs.sh`
   - Example: `for container in project-*; do generate_location_block $container; done > nginx.conf`

3. **Third bottleneck: Resource contention (RAM, CPU)**
   - Problem: 5 containers × (Xvfb 100MB + Chromium 500MB + x11vnc 50MB + noVNC 50MB) = ~3.5GB baseline
   - Fix: Implement headless-first pattern (Pattern 1) to reduce idle overhead
   - Alternative: Increase container specs or reduce concurrent containers

4. **Fourth bottleneck: Notification noise**
   - Problem: 5 containers all sending webhooks creates alert fatigue
   - Fix: Centralized notification service with deduplication; single webhook aggregates all containers
   - Alternative: Priority-based notifications (only critical OAuth flows trigger webhook, minor issues only flash tab)

## Anti-Patterns

### Anti-Pattern 1: Launching New Browser Instance Per Test

**What people do:** Each Playwright test script launches a new browser with `chromium.launch()`

**Why it's wrong:**
- Browser restart loses authenticated state (cookies, localStorage)
- Startup overhead (3-5 seconds per launch)
- Cannot co-exist with human interaction in noVNC (different browser instances)
- Breaks the co-browsing model (AI and human must share same browser instance)

**Do this instead:**
Use `chromium.connectOverCDP('http://localhost:9222')` to attach to persistent browser instance managed by systemd service. All automation shares the same browser, preserving state across runs.

```typescript
// WRONG
const browser = await chromium.launch({ headless: false });

// RIGHT
const browser = await chromium.connectOverCDP('http://localhost:9222');
```

### Anti-Pattern 2: Clipboard-Based Text Transfer

**What people do:** Use clipboard bridges (HTTP server for `clip`/`getclip` commands) to transfer text between AI and browser

**Why it's wrong:**
- Brittle: Requires X11 clipboard synchronization (xclip, xsel)
- Race conditions: Clipboard content can be overwritten by other processes
- Unnecessary complexity: Playwright can inject text directly via CDP

**Do this instead:**
Use Playwright's native text injection via `page.fill()` or `page.evaluate()` to set input values directly. No clipboard needed.

```typescript
// WRONG (clipboard approach from reference box)
await execSync('echo "password123" | clip');
await page.click('#password-input');
await page.keyboard.press('Control+v');

// RIGHT (direct injection)
await page.fill('#password-input', 'password123');

// ALSO RIGHT (for complex scenarios)
await page.evaluate((text) => {
  document.querySelector('#password-input').value = text;
}, 'password123');
```

### Anti-Pattern 3: xdotool for Complex UI Interactions

**What people do:** Use `xdotool` to simulate mouse clicks and keyboard input via X11 events

**Why it's wrong:**
- Low reliability on modern web UIs (Google Apps Script, React apps ignore synthetic events)
- No access to shadow DOM or complex event listeners
- Cannot manipulate application state (cookies, localStorage, fetch requests)
- Reference box finding confirms: "Google's complex UIs don't respond well to synthetic X11 events"

**Do this instead:**
Use Playwright CDP for all complex interactions; reserve xdotool only for trivial cases where Playwright is overkill (e.g., taking screenshots with `import -window root`).

```bash
# WRONG (xdotool for filling form)
xdotool search --name "Chrome" windowactivate
xdotool type "username@example.com"
xdotool key Tab
xdotool type "password123"

# RIGHT (Playwright for filling form)
await page.fill('#username', 'username@example.com');
await page.fill('#password', 'password123');
await page.click('button[type="submit"]');
```

### Anti-Pattern 4: Fixed Port Numbers in Scripts

**What people do:** Hardcode port 6080 for noVNC, 9222 for CDP, etc.

**Why it's wrong:**
- Prevents running multiple containers on same host
- Port conflicts cause service startup failures
- Difficult to scale beyond 1-2 containers

**Do this instead:**
Use per-container port assignment with environment variables; reverse proxy routes based on path, not port.

```bash
# WRONG (hardcoded in all containers)
export NOVNC_PORT=6080
export CDP_PORT=9222

# RIGHT (unique per container, managed by orchestrator)
export NOVNC_PORT=$(( 6080 + CONTAINER_ID ))
export PROJECT_NAME="project-a"
# Nginx routes /project-a/ → localhost:6080
# Nginx routes /project-b/ → localhost:6081
```

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| **ntfy.sh** | HTTP POST webhook | `curl -d "Project A needs input" https://ntfy.sh/my-topic` |
| **Slack** | Incoming webhook | `curl -X POST -H 'Content-type: application/json' --data '{"text":"OAuth login needed"}' https://hooks.slack.com/services/XXX` |
| **Playwright** | CDP WebSocket | `chromium.connectOverCDP('http://localhost:9222')` |
| **Tailscale** | Container networking | Containers accessible via Tailscale IPs; reverse proxy on public interface |
| **Systemd** | Service management | Xvfb, x11vnc, Chromium, noVNC managed as systemd user services |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| **Claude Code ↔ Chromium** | CDP WebSocket (localhost:9222) | AI agent drives browser via Playwright CDP |
| **Chromium ↔ Xvfb** | X11 protocol (DISPLAY=:99) | Browser renders to virtual framebuffer |
| **Xvfb ↔ x11vnc** | X11 framebuffer read | VNC server captures display pixels |
| **x11vnc ↔ websockify** | RFB protocol (TCP port 5900) | VNC server → WebSocket bridge |
| **websockify ↔ noVNC** | WebSocket (port 6080) | WebSocket bridge → HTML5 client |
| **noVNC ↔ Human** | HTTP/WebSocket | Browser on laptop connects to container's noVNC |
| **Nginx ↔ noVNC** | HTTP reverse proxy | Path-based routing to correct container |

## Suggested Build Order

### Phase 1: Single-Container Display Stack (Foundation)
**Dependencies:** None
**Deliverables:**
1. Install Xvfb, x11vnc, noVNC, Chromium on one container
2. Verify Xvfb → x11vnc → noVNC chain works
3. Launch Chromium with `--display=:99 --remote-debugging-port=9222`
4. Access noVNC from laptop, confirm browser visible
5. Systemd services for auto-start (xvfb, x11vnc, novnc)

**Why first:** Establish baseline infrastructure before adding Playwright; validate display stack independently

### Phase 2: Playwright CDP Integration
**Dependencies:** Phase 1
**Deliverables:**
1. Install Playwright in container
2. Create `cobrowse/playwright-cdp/connect.ts` wrapper for `connectOverCDP()`
3. Run simple Playwright script (navigate to URL, take screenshot)
4. Verify Playwright actions visible in noVNC simultaneously
5. Confirm state persistence (restart Playwright script, same browser session continues)

**Why second:** Prove AI + human can co-exist in same browser before scaling to multiple containers

### Phase 3: Reverse Proxy for Multi-Container
**Dependencies:** Phase 2 (working single container)
**Deliverables:**
1. Create nginx config template in `cobrowse/proxy/nginx-template.conf`
2. Generate location blocks for each container (path-based routing)
3. Test with 2 containers: /project-a/ → container-1, /project-b/ → container-2
4. Validate WebSocket upgrade handling for noVNC
5. Document port assignment strategy (6080, 6081, 6082...)

**Why third:** Scaling to multiple containers requires routing layer; test with 2 before adding 3-5

### Phase 4: Notification System
**Dependencies:** Phase 3 (multi-container access working)
**Deliverables:**
1. Tab title flash via CDP (`Page.evaluate()` to inject JS into noVNC page)
2. Webhook integration (ntfy.sh or Slack)
3. Trigger script: `cobrowse/notification/notify.ts`
4. Test notification flow: Playwright detects OAuth → triggers notification → human receives alert
5. Stop notification when interaction complete

**Why fourth:** Notifications only matter once multi-container setup is operational; need working noVNC tabs to flash

### Phase 5: Interaction Completion Detection
**Dependencies:** Phase 4 (notifications working)
**Deliverables:**
1. Auto-detection via Playwright event listeners (URL change, element appears)
2. Manual signal endpoint (`curl http://localhost:3001/signal-done`)
3. Integration with notification system (stop flashing when done)
4. Test both paths: auto-detect (OAuth callback) and manual signal (complex flow)
5. Document which scenarios need manual signal vs auto-detect

**Why fifth:** Requires working notification system to test "notification → interaction → detection → resume" loop

### Phase 6: Interaction Method Testing Suite
**Dependencies:** Phase 2 (Playwright CDP working)
**Deliverables:**
1. Test suite comparing Playwright methods: `fill()` vs `type()` vs `keyboard.press()`
2. Test suite for JS injection vs DOM interaction
3. Screenshot feedback loop timing tests
4. State manipulation shortcuts (cookies, localStorage, API bypass)
5. Documentation of best practices for each scenario

**Why sixth:** Can be developed in parallel with Phase 4-5; not a blocker for core functionality

### Phase 7: Headless ↔ Headed Switching (Optional)
**Dependencies:** Phase 2 (Playwright CDP working)
**Deliverables:**
1. Implement Pattern 2 (Always-On Display) — simplest approach
2. On-demand VNC start/stop scripts
3. Test resource savings when VNC disabled
4. **OR** defer this entirely (32GB RAM is abundant, always-on is simpler)

**Why last:** Optimization, not core functionality; Pattern 2 may be sufficient given resource availability

## Headless ↔ Headed Switching Mechanism

### Recommended Approach: Always-On Display (Pattern 2)

Given the project constraints (32GB RAM, 8 vCPU per container, 3-5 concurrent containers), the **Always-On Display** pattern is recommended:

1. **Xvfb always running:** `systemd` service ensures Xvfb :99 is always available
2. **Chromium always headed:** Launched with `--display=:99 --remote-debugging-port=9222`
3. **VNC on-demand:** x11vnc + noVNC start only when notification triggered

**Rationale:**
- **Simplicity:** No browser restart required; Playwright CDP connection never breaks
- **Reliability:** Proven on reference box (already working this way)
- **Resource cost acceptable:** ~150MB overhead (Xvfb + x11vnc) is negligible on 32GB containers
- **State preservation:** Browser keeps cookies, localStorage, session across automation runs

### Switching Mechanism Implementation

```typescript
// cobrowse/runtime/mode-switch.ts
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

export async function enableHumanViewing() {
  // Start VNC stack if not running
  await execAsync('/home/dev/.cobrowse/runtime/display-manager.sh start_vnc');

  // Trigger notification to human
  await import('./notification/notify').then(m => m.notifyHuman());

  console.log('VNC enabled; human can view at http://proxy.domain/project-a/');
}

export async function disableHumanViewing() {
  // Stop VNC stack to save resources
  await execAsync('/home/dev/.cobrowse/runtime/display-manager.sh stop_vnc');

  console.log('VNC disabled; browser still running for automation');
}
```

### Alternative: True Headless Switching (Pattern 1)

If resource constraints become critical (e.g., running 10+ containers), implement Pattern 1:

1. **Default state:** Chromium headless (no `--display` flag, no Xvfb)
2. **On escalation:**
   - Stop headless browser
   - Start Xvfb + x11vnc + noVNC
   - Launch Chromium with `--display=:99 --remote-debugging-port=9222`
   - Restore session state from `--user-data-dir`
3. **After interaction:**
   - Stop headed browser
   - Stop Xvfb + x11vnc + noVNC
   - Launch headless browser
   - Continue automation

**Trade-offs:**
- **Pro:** Saves ~150MB RAM per container when headless
- **Con:** Browser restart loses ephemeral state (in-memory caches, pending network requests)
- **Con:** CDP reconnection required (Playwright must `connectOverCDP()` again)
- **Con:** Added complexity in orchestration logic

**Conclusion:** Defer Pattern 1 unless resource pressure demands it. Start with Pattern 2 (Always-On Display).

## Reverse Proxy Architecture

### Nginx Configuration Pattern

```nginx
# /etc/nginx/sites-available/cobrowse-proxy

upstream project_a_novnc {
    server localhost:6080;
}

upstream project_b_novnc {
    server localhost:6081;
}

upstream project_c_novnc {
    server localhost:6082;
}

server {
    listen 80;
    server_name proxy.domain;

    # Project A
    location /project-a/ {
        proxy_pass http://project_a_novnc/;

        # WebSocket upgrade (required for noVNC)
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Prevent timeout during long VNC sessions
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;

        # Preserve original request info
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Project B
    location /project-b/ {
        proxy_pass http://project_b_novnc/;
        # ... same headers as above
    }

    # Project C
    location /project-c/ {
        proxy_pass http://project_c_novnc/;
        # ... same headers as above
    }
}
```

### Template-Based Generation

```bash
# cobrowse/proxy/merge-configs.sh
#!/bin/bash

PROJECTS=("project-a" "project-b" "project-c")
BASE_PORT=6080

cat > /tmp/nginx-cobrowse.conf <<'HEADER'
# Auto-generated cobrowse proxy config
# Generated: $(date)

HEADER

for i in "${!PROJECTS[@]}"; do
  PROJECT="${PROJECTS[$i]}"
  PORT=$((BASE_PORT + i))

  cat >> /tmp/nginx-cobrowse.conf <<BLOCK

upstream ${PROJECT}_novnc {
    server localhost:${PORT};
}

server {
    listen 80;
    server_name ${PROJECT}.proxy.domain;

    location / {
        proxy_pass http://${PROJECT}_novnc/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 3600s;
    }
}
BLOCK
done

sudo cp /tmp/nginx-cobrowse.conf /etc/nginx/sites-available/cobrowse-proxy
sudo ln -sf /etc/nginx/sites-available/cobrowse-proxy /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

### Path-Based vs Subdomain-Based Routing

| Aspect | Path-Based (/project-a/) | Subdomain-Based (project-a.domain) |
|--------|--------------------------|-----------------------------------|
| **URL Format** | `http://proxy.domain/project-a/` | `http://project-a.proxy.domain` |
| **DNS Required** | No (single domain) | Yes (wildcard DNS *.proxy.domain) |
| **SSL Complexity** | Single cert for proxy.domain | Wildcard cert for *.proxy.domain |
| **Bookmark UX** | Slightly uglier URLs | Cleaner URLs |
| **noVNC Compatibility** | Requires path awareness | Works out-of-box |

**Recommendation:** Path-based routing for simplicity (no DNS/SSL complexity); subdomain-based if scaling to 10+ containers.

## Sources

- [Understanding Headless vs. Headed Modes in Playwright | DEV Community](https://dev.to/johnnyv5g/understanding-headless-vs-headed-modes-in-playwright-a-guide-for-qa-automation-engineers-sdets-4h7e)
- [Chrome DevTools Protocol Documentation](https://chromedevtools.github.io/devtools-protocol/)
- [Xvfb Wikipedia](https://en.wikipedia.org/wiki/Xvfb)
- [x11vnc Wikipedia](https://en.wikipedia.org/wiki/X11vnc)
- [Websockify & noVNC behind an NGINX Proxy](https://datawookie.dev/blog/2021/08/websockify-novnc-behind-an-nginx-proxy/)
- [Proxying with nginx | noVNC Wiki](https://github.com/novnc/noVNC/wiki/Proxying-with-nginx)
- [Path-Based Routing with Nginx Reverse Proxy | Cloud Native Daily](https://medium.com/cloud-native-daily/path-based-routing-with-nginx-reverse-proxy-for-multiple-applications-in-a-vm-53838169540c)
- [Connecting Playwright to an Existing Browser | BrowserStack](https://www.browserstack.com/guide/playwright-connect-to-existing-browser)
- [BrowserType | Playwright API](https://playwright.dev/docs/api/class-browsertype)
- [2026 Outlook: AI-Driven Browser Automation | Browserless](https://www.browserless.io/blog/state-of-ai-browser-automation-2026)

---

*Architecture research for: Multi-container AI-driven co-browsing infrastructure*
*Researched: 2026-02-09*
