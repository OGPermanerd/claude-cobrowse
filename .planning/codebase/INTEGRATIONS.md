# External Integrations

**Analysis Date:** 2026-02-09

## APIs & External Services

**Testing Infrastructure:**
- Playwright Remote (optional) - Cloud browser execution
  - Not configured by default; projects can opt into cloud execution
  - SDK/Client: `@playwright/test` supports cloud deployment

## Data Storage

**Databases:**
- Configurable per target project
  - Connection: `DATABASE_URL` environment variable
  - Client: User-supplied (no default included)
  - Pattern: Test user seeded in `template/tests/e2e/auth.setup.ts` via user-supplied DB client
  - Note: Projects must adapt the `db.insert()` call in `auth.setup.ts` to their database schema

**File Storage:**
- Local filesystem only
  - Storage state: `playwright/.auth/user.json` (Playwright's built-in session storage)
  - Reports: `playwright-report/` and `test-results/` (Playwright outputs)
  - No external file storage integration

**Caching:**
- None - Each test run reseeds the test user if database integration is enabled

## Authentication & Identity

**Auth Provider:**
- Next.js Auth (NextAuth.js) v5 custom
  - Implementation: JWT-based tokens with session cookies
  - Token encoding: `next-auth/jwt` library
  - Session format: Custom JWT payload with user claims

**Session Management:**
- Cookie-based with JWT payload
  - Cookie name: `authjs.session-token` (NextAuth v5 default, configurable in `auth.setup.ts` line 84)
  - Storage: Playwright's `storageState` API in `playwright/.auth/user.json`
  - Persistence: Automatic across all tests in chromium project via `dependencies: ["setup"]`
  - Expiration: 24 hours by default (configurable in `auth.setup.ts`)

**Test User Identity:**
- Hard-coded test user constants in `template/tests/e2e/auth.setup.ts`
  - `id`: `e2e-test-user`
  - `email`: `e2e-test@company.com`
  - `name`: `E2E Test User`
  - Schema: Must be adapted to match target project's user table schema

**No External OAuth:**
- Projects must implement OAuth manually if needed (not part of this kit)

## Monitoring & Observability

**Error Tracking:**
- None configured - errors are reported directly to test runner output

**Logs:**
- Console logging via `console.log()` in `auth.setup.ts`
  - Traces auth flow for debugging
  - Playwright HTML reports (in `playwright-report/`) contain trace data
  - Trace recording: `on-first-retry` (enabled in `playwright.config.ts` line 22)

**Test Reporting:**
- HTML Reporter - Built-in to Playwright
  - Output: `playwright-report/` directory
  - Trace data: Captured on first retry for debugging failures
  - Manual run: `npx playwright show-report`

## CI/CD & Deployment

**Hosting:**
- Target projects (not this kit) deploy via standard Next.js hosting:
  - Vercel, AWS Amplify, self-hosted, etc.
  - This kit provides E2E test scaffolding only

**CI Pipeline:**
- Configurable environment detection via `process.env.CI` flag
  - Behavior changes when `CI` is set:
    - Disables `test.only()` via `forbidOnly: true`
    - Enables retries: `retries: 2`
    - Serial execution: `workers: 1`
    - Fresh server on each run: `reuseExistingServer: false`

**Test Execution in CI:**
- Trigger: `npx playwright test` (or specific test file)
- Browser: Chromium only (headless mode by default)
- Dependencies: Runs `setup` project first via playwright config

## Environment Configuration

**Required env vars (in target project's `.env.local`):**
- `AUTH_SECRET` - Required for JWT token creation
  - Usage: Passed to `next-auth/jwt` encode function in `auth.setup.ts`
  - Error if missing: `"AUTH_SECRET environment variable is required for E2E tests"`

- `DATABASE_URL` - Optional but recommended
  - Usage: Projects using DB seeding must import and connect to this URL
  - Pattern: Imported via user-supplied DB client in adapted `auth.setup.ts`

- `PORT` - Optional
  - Default: `3000`
  - Usage: Playwright base URL and dev server connection

**CI-specific:**
- `CI=true` - Must be set in CI environment
  - Triggers different test behavior (retries, serial workers, fresh server)

**Secrets location:**
- `.env.local` - Git-ignored, contains AUTH_SECRET and DATABASE_URL
- Should never be committed; create locally or via CI secrets manager

## Webhooks & Callbacks

**Incoming:**
- None - This is a testing kit, not a backend service

**Outgoing:**
- None - Tests do not trigger external webhooks
- Note: Target projects may implement webhooks independently

## Default Test Configuration

**Base URL:**
- `http://localhost:{PORT}` (defaults to `http://localhost:3000`)
- Configurable via `PORT` environment variable
- Read in `playwright.config.ts` line 9

**Browser Capabilities:**
- Device: Desktop Chrome (via `devices["Desktop Chrome"]`)
- Viewport: 1280x720 (Playwright default)
- No mobile testing by default (can be added by projects)

**Test Directory:**
- `tests/e2e/` - Exclusively for E2E tests
- Match pattern: `*.spec.ts` for tests, `*.setup.ts` for setup

**Storage State:**
- File: `playwright/.auth/user.json`
- Format: Playwright's storageState JSON (cookies, localStorage, sessionStorage)
- Reusable across: All tests in chromium project
- Gitignored: Yes (in `.gitignore.partial`)

---

*Integration audit: 2026-02-09*
