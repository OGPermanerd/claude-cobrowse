# Roadmap: Claude Co-Browse

## Overview

This roadmap takes Claude Co-Browse from existing Playwright E2E scaffolding to a complete co-browsing infrastructure across six phases. Phase 1 establishes the display stack foundation (Xvfb + TigerVNC + noVNC + Chromium) on a single container. Phase 2 proves the dual-control model where Playwright CDP and human noVNC access coexist. Phase 3 scales to 3-5 containers with nginx reverse proxy routing. Phases 4-5 add intelligent escalation (notifications and auto-resume detection). Phase 6 creates a testing lab to validate interaction methods and document best practices.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Display Stack Foundation** - Xvfb + TigerVNC + noVNC + Chromium running on single container
- [ ] **Phase 2: Playwright CDP Integration** - Dual-control automation via CDP while human monitors noVNC
- [ ] **Phase 3: Multi-Container Routing** - nginx reverse proxy serving 3-5 container noVNC sessions
- [ ] **Phase 4: Intelligent Escalation** - Notifications via tab flash and webhook when human input needed
- [ ] **Phase 5: Interaction Completion Detection** - Auto-resume after human interaction via URL/element detection
- [ ] **Phase 6: Interaction Method Testing** - Empirical validation and documentation of Playwright methods

## Phase Details

### Phase 1: Display Stack Foundation
**Goal**: Browser visible via noVNC in laptop browser, persistent session across restarts
**Depends on**: Nothing (first phase)
**Requirements**: DISP-01, DISP-02, DISP-03, DISP-04, DISP-05, STAT-01, SETUP-01, SETUP-02, SETUP-03, SETUP-04
**Success Criteria** (what must be TRUE):
  1. User opens noVNC URL in laptop browser and sees Chromium running on virtual display
  2. User can click and type in Chromium via noVNC interface
  3. Chromium CDP debugger accessible at localhost:9222 from container shell
  4. Browser session survives service restart (cookies and localStorage persist via --user-data-dir)
  5. Setup script installs entire stack on fresh Ubuntu 24.04 container in under 5 minutes
**Plans**: TBD

Plans:
- [ ] 01-01: TBD during planning

### Phase 2: Playwright CDP Integration
**Goal**: Claude Code drives browser via Playwright CDP while human watches simultaneously in noVNC
**Depends on**: Phase 1
**Requirements**: AUTO-01, AUTO-02, AUTO-03, AUTO-04, AUTO-05, AUTO-06, STAT-02, STAT-03, STAT-04
**Success Criteria** (what must be TRUE):
  1. Playwright script connects to persistent Chromium via connectOverCDP without errors
  2. Playwright navigates to URL, fills form, clicks button while user watches action happen in noVNC
  3. User can take over interaction via noVNC mouse/keyboard while Playwright connection remains active
  4. Playwright injects cookies directly via CDP to skip login flow on test application
  5. Screenshots captured via import command show current browser state for Claude analysis
**Plans**: TBD

Plans:
- [ ] 02-01: TBD during planning

### Phase 3: Multi-Container Routing
**Goal**: Single reverse proxy URL routes to 3-5 container noVNC sessions via path-based routing
**Depends on**: Phase 2
**Requirements**: DISP-06, DISP-07
**Success Criteria** (what must be TRUE):
  1. User opens http://proxy-host/project-a/ and sees container A's noVNC session
  2. User opens http://proxy-host/project-b/ in new tab and sees container B's noVNC session
  3. Both noVNC sessions remain connected simultaneously without WebSocket disconnects
  4. Display number conflicts avoided when 3 containers run Xvfb concurrently
**Plans**: TBD

Plans:
- [ ] 03-01: TBD during planning

### Phase 4: Intelligent Escalation
**Goal**: User knows which project needs input via tab title flash and external notifications
**Depends on**: Phase 3
**Requirements**: HAND-01, HAND-02, HAND-06
**Success Criteria** (what must be TRUE):
  1. Playwright detects OAuth URL pattern and triggers escalation notification
  2. noVNC browser tab title changes to "⚠ project-name needs input" with visual flash
  3. Webhook fires to ntfy.sh endpoint with project name and reason for escalation
  4. Notification stops/updates when user begins interacting via noVNC
**Plans**: TBD

Plans:
- [ ] 04-01: TBD during planning

### Phase 5: Interaction Completion Detection
**Goal**: Claude Code automatically resumes after human completes interaction without manual signal
**Depends on**: Phase 4
**Requirements**: HAND-03, HAND-04, HAND-05
**Success Criteria** (what must be TRUE):
  1. Playwright detects URL change from /oauth/callback to /dashboard and resumes automation
  2. Playwright detects appearance of expected DOM element and resumes automation
  3. User can send manual "done" signal via command/endpoint when auto-detection fails
  4. Full escalation loop works: detect OAuth → notify → wait → detect completion → resume
**Plans**: TBD

Plans:
- [ ] 05-01: TBD during planning

### Phase 6: Interaction Method Testing
**Goal**: Documented best practices for Playwright interaction methods with empirical data
**Depends on**: Phase 2 (can parallelize with Phases 4-5)
**Requirements**: TEST-01, TEST-02, TEST-03, TEST-04, TEST-05, TEST-06
**Success Criteria** (what must be TRUE):
  1. Test suite compares page.fill() vs page.type() vs page.keyboard.press() on 5+ input types
  2. Test suite compares page.evaluate() JavaScript injection vs Playwright API for state manipulation
  3. Documentation shows when to use each method with success rates and timing data
  4. Tests validate methods against real-world targets (OAuth providers, Google UIs, complex SPAs)
  5. Recommendations clearly state when CDP is required vs when standard Playwright suffices
**Plans**: TBD

Plans:
- [ ] 06-01: TBD during planning

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Display Stack Foundation | 0/TBD | Not started | - |
| 2. Playwright CDP Integration | 0/TBD | Not started | - |
| 3. Multi-Container Routing | 0/TBD | Not started | - |
| 4. Intelligent Escalation | 0/TBD | Not started | - |
| 5. Interaction Completion Detection | 0/TBD | Not started | - |
| 6. Interaction Method Testing | 0/TBD | Not started | - |
