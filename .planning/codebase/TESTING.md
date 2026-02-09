# Testing Patterns

**Analysis Date:** 2026-02-09

## Test Framework

**Runner:**
- Playwright Test v1.x (installed as `@playwright/test`)
- Config: `playwright.config.ts` at project root

**Assertion Library:**
- Playwright's built-in expectations and matchers (e.g., `expect(page).toHaveURL()`, `expect(page.locator()).toBeVisible()`)

**Run Commands:**
```bash
npx playwright test                           # Run all tests
npx playwright test tests/e2e/specific.spec.ts  # Run specific test file
npx playwright test --watch                  # Watch mode (local development)
npx playwright show-report                   # View HTML test report
npx playwright install chromium              # Install browser dependencies
```

## Test File Organization

**Location:**
- Co-located in `tests/e2e/` directory at project root
- Setup file: `tests/e2e/auth.setup.ts` (runs before all test suites via "setup" project)
- Test files: `tests/e2e/*.spec.ts`

**Naming:**
- Setup files: `[purpose].setup.ts` (e.g., `auth.setup.ts`)
- Test files: `[page-or-feature].spec.ts` (e.g., `example.spec.ts`)
- Pattern: `*.spec.ts` or `*.setup.ts` matches Playwright's discovery conventions

**Structure:**
```
tests/
└── e2e/
    ├── auth.setup.ts      # Runs first via "setup" project
    ├── example.spec.ts    # Test suite
    └── [feature].spec.ts  # Additional test suites
```

## Test Structure

**Suite Organization:**
```typescript
import { test, expect } from "@playwright/test";

test.describe("Example Page", () => {
  test("should load the home page", async ({ page }) => {
    await page.goto("/");
    await expect(page).not.toHaveURL(/\/login/);
    await expect(page.locator("body")).toBeVisible();
  });

  test("should display user-specific content", async ({ page }) => {
    await page.goto("/");
    // ADAPT: check for authenticated user content
    // await expect(page.locator("text=E2E Test User")).toBeVisible();
  });
});
```

**Patterns:**
- **Setup:** Tests receive pre-authenticated `page` fixture from Playwright context
- **Assertions:** Use fluent `expect()` API with async matchers
- **Navigation:** Tests start by navigating to routes relative to `baseURL` set in config
- **Teardown:** Automatic via Playwright (no explicit cleanup needed for basic tests)

## Authentication Pattern

**Global Setup File** (`tests/e2e/auth.setup.ts`):
- Runs once before all tests via the "setup" project in `playwright.config.ts`
- Executes in sequence (not parallelized) to seed data and create session
- Creates authenticated session without OAuth flow

**Pattern:**
```typescript
import { test as setup } from "@playwright/test";
import { encode } from "next-auth/jwt";

const TEST_USER = {
  id: "e2e-test-user",
  email: "e2e-test@company.com",
  name: "E2E Test User",
};

const AUTH_FILE = "playwright/.auth/user.json";

setup("authenticate", async ({ page }) => {
  const authSecret = process.env.AUTH_SECRET;

  if (!authSecret) {
    throw new Error("AUTH_SECRET environment variable is required for E2E tests");
  }

  // 1. Seed test user in database
  // ADAPT: Replace with your users table insert/upsert
  // await db.insert(users).values({ ... });

  // 2. Create a valid JWT session token
  const now = Math.floor(Date.now() / 1000);
  const expiresAt = now + 24 * 60 * 60;

  const token = await encode({
    token: {
      id: TEST_USER.id,
      email: TEST_USER.email,
      name: TEST_USER.name,
      sub: TEST_USER.id,
      iat: now,
      exp: expiresAt,
    },
    secret: authSecret,
    salt: "authjs.session-token",
  });

  // 3. Store session cookie in Playwright storageState
  await page.context().addCookies([
    {
      name: "authjs.session-token",
      value: token,
      domain: "localhost",
      path: "/",
      httpOnly: true,
      secure: false,
      sameSite: "Lax",
    },
  ]);

  // 4. Save the storage state to file for reuse by other tests
  await page.context().storageState({ path: AUTH_FILE });
});
```

**Key Points:**
- JWT encoding uses `next-auth/jwt` package (NextAuth v5 compatible)
- Token includes standard claims: `id`, `email`, `name`, `sub`, `iat`, `exp`
- Session persisted to `playwright/.auth/user.json` via `storageState()`
- All subsequent tests inherit this authenticated context

## Playwright Configuration

**Config File** (`playwright.config.ts`):
```typescript
import { defineConfig, devices } from "@playwright/test";
import dotenv from "dotenv";
import path from "path";

dotenv.config({ path: path.resolve(__dirname, ".env.local") });

const PORT = Number(process.env.PORT || 3000);
const BASE_URL = `http://localhost:${PORT}`;

export default defineConfig({
  testDir: "./tests/e2e",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: "html",
  use: {
    baseURL: BASE_URL,
    trace: "on-first-retry",
  },
  projects: [
    {
      name: "setup",
      testMatch: /.*\.setup\.ts/,
    },
    {
      name: "chromium",
      use: {
        ...devices["Desktop Chrome"],
        storageState: "playwright/.auth/user.json",
      },
      dependencies: ["setup"],
    },
  ],
  webServer: {
    command: process.env.CI ? "npm start" : "npm run dev",
    url: BASE_URL,
    reuseExistingServer: !process.env.CI,
    timeout: 120000,
  },
});
```

**Configuration Points:**
- **testDir:** Tests discovered from `./tests/e2e`
- **fullyParallel:** Tests run in parallel (within local dev constraints)
- **forbidOnly:** CI enforces `.only()` isn't used to skip tests
- **retries:** 0 locally, 2 in CI for flakiness tolerance
- **workers:** Unlimited locally, 1 in CI for deterministic execution
- **reporter:** HTML report saved to `playwright-report/`
- **trace:** Captures trace artifacts on first retry for debugging
- **baseURL:** All `page.goto()` calls are relative to this URL
- **storageState:** Loads authenticated cookies from setup phase
- **webServer.reuseExistingServer:** Reuses running dev server locally, forces restart in CI

## Adapting Tests for Your Project

**1. Update Test User** (`auth.setup.ts`):
- Change `TEST_USER` to match your database schema
- Add additional fields required by your system

**2. Seed Database** (`auth.setup.ts`):
- Uncomment and adapt the database insert/upsert call:
  ```typescript
  import { db, users } from "@your-package/db";

  await db
    .insert(users)
    .values({
      id: TEST_USER.id,
      email: TEST_USER.email,
      name: TEST_USER.name,
    })
    .onConflictDoUpdate({
      target: users.id,
      set: {
        email: TEST_USER.email,
        name: TEST_USER.name,
        updatedAt: new Date(),
      },
    });
  ```

**3. Add JWT Claims** (`auth.setup.ts`):
- If your JWT requires additional claims (e.g., `tenantId`, `role`), add them to the token object:
  ```typescript
  const token = await encode({
    token: {
      id: TEST_USER.id,
      email: TEST_USER.email,
      name: TEST_USER.name,
      sub: TEST_USER.id,
      tenantId: TEST_USER.tenantId,  // Custom claim
      role: TEST_USER.role,          // Custom claim
      iat: now,
      exp: expiresAt,
    },
    secret: authSecret,
    salt: "authjs.session-token",
  });
  ```

**4. Verify Cookie Name** (`auth.setup.ts`):
- Ensure the cookie name matches your NextAuth configuration
- NextAuth v5 default: `authjs.session-token`
- Older versions: `next-auth.session-token`
- Set in `addCookies()` call and in `encode()` salt parameter

**5. Write Test Cases** (`*.spec.ts`):
- Follow the example structure in `example.spec.ts`
- Replace comments marked with `ADAPT:` with real assertions
- Use Playwright locators to find elements: `page.locator()`, `page.getByRole()`, `page.getByText()`

## Test Utilities and Helpers

**Fixtures:**
- Playwright provides built-in fixtures: `page`, `context`, `browser`, `request`
- Access via test function parameters:
  ```typescript
  test("example", async ({ page, context, request }) => {
    // Use page, context, request
  });
  ```

**Test Data:**
- Test user defined in `auth.setup.ts` as constants: `TEST_USER`
- Seed data created in setup phase (database insert)
- Authentication persisted via `storageState` file

**Storage State File:**
- Location: `playwright/.auth/user.json` (gitignored)
- Created by setup phase, reused by all tests
- Contains cookies, localStorage, sessionStorage from authenticated context
- Manually inspect for debugging: `cat playwright/.auth/user.json`

## Coverage

**Requirements:** Not enforced in template

**View Report:**
```bash
npx playwright show-report
```

This opens an HTML report in browser showing:
- Test results (passed/failed)
- Execution time
- Traces and videos (if configured)
- Failures with screenshots

## Test Types

**E2E Tests:**
- Scope: Full page load, navigation, user interactions
- Approach: Uses real browser (Chromium) against dev server
- Example: `tests/e2e/example.spec.ts` — verifies page loads and shows authenticated content
- Setup: Runs with authenticated session via JWT cookie

**Setup Tests:**
- Scope: Database seeding, session creation
- Approach: Runs once before all E2E tests
- Example: `tests/e2e/auth.setup.ts` — creates test user and JWT token
- Isolation: Runs in "setup" project before "chromium" project

**Unit/Integration Tests:**
- Not included in template (would use Jest, Vitest, or similar)
- Recommended for isolated function testing, API route testing

## Environment Configuration

**Required Environment Variables** (`.env.local`):
```
AUTH_SECRET=your-dev-secret
DATABASE_URL=postgresql://user:pass@localhost:5432/mydb
```

**Optional:**
```
PORT=3000              # Defaults to 3000
CI=                    # Set by CI systems; affects retries, workers, webServer.command
```

**Loading:**
- `playwright.config.ts` loads via `dotenv.config()`
- Tests access via `process.env.*`

## CI/CD Integration

**Typical CI Configuration:**
```bash
npm install -D @playwright/test dotenv
npx playwright install chromium
npx playwright test
```

**Behavior in CI:**
- `process.env.CI` set by CI runner (GitHub Actions, GitLab CI, etc.)
- Uses `npm start` instead of `npm run dev`
- Runs with `workers: 1` for deterministic execution
- Retries tests up to 2 times on failure
- Generates HTML report: `playwright-report/`

## Common Assertion Patterns

**Navigation:**
```typescript
await page.goto("/");
await expect(page).not.toHaveURL(/\/login/);
```

**Element Visibility:**
```typescript
await expect(page.locator("body")).toBeVisible();
```

**Text Content:**
```typescript
await expect(page.locator("text=E2E Test User")).toBeVisible();
```

**Form Interaction:**
```typescript
await page.fill('input[name="email"]', 'test@example.com');
await page.click('button[type="submit"]');
```

## Debugging Tests

**View Trace (After Failure):**
```bash
npx playwright show-trace trace.zip  # Generated on first retry
```

**Run in Headed Mode (See Browser):**
```bash
npx playwright test --headed
```

**Debug Single Test:**
```bash
npx playwright test tests/e2e/example.spec.ts --debug
```

**Verbose Output:**
```bash
npx playwright test --verbose
```

---

*Testing analysis: 2026-02-09*
