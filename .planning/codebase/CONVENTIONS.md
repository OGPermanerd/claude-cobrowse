# Coding Conventions

**Analysis Date:** 2026-02-09

## Naming Patterns

**Files:**
- Test files: `*.spec.ts` (e.g., `example.spec.ts`, `auth.setup.ts`)
- Config files: `*.config.ts` (e.g., `playwright.config.ts`)
- Uppercase constants for configuration values (e.g., `PORT`, `BASE_URL`, `TEST_USER`)
- Camelcase for variables and constants that hold values (e.g., `authSecret`, `expiresAt`)

**Functions:**
- Async test functions use async/await pattern
- Setup functions follow naming convention `${testName}.setup.ts`
- Console logging uses bracket notation for context: `[setup]`, `[auth.setup]`

**Variables:**
- Environment variables: UPPERCASE (e.g., `PORT`, `AUTH_SECRET`, `DATABASE_URL`, `CI`)
- camelCase for local variables and parameters (e.g., `expiresAt`, `authSecret`, `now`)
- Constant values (static data) use UPPER_SNAKE_CASE (e.g., `TEST_USER`, `AUTH_FILE`)

**Types:**
- Not heavily typed in template (JavaScript with JSDoc comments)
- TypeScript interfaces/types follow PascalCase (inferred from usage)

## Code Style

**Formatting:**
- No explicit formatter configured in the template (would typically use Prettier)
- 2-space indentation evident in all files
- Line length appears to follow ~80-100 character guideline

**Linting:**
- No explicit linter configured in the template (would typically use ESLint)
- Code follows standard TypeScript conventions
- Import statements are organized at the top of files

## Import Organization

**Order:**
1. Third-party packages (`@playwright/test`, `dotenv`, `next-auth/jwt`)
2. Standard library imports (`path`)
3. Local imports (commented examples with `@your-package/db`)
4. No aliases in the template code

**Path Aliases:**
- Not used in template; intended to be adapted by individual projects

## Error Handling

**Patterns:**
- Explicit error checking before operations:
  ```typescript
  if (!authSecret) {
    throw new Error("AUTH_SECRET environment variable is required for E2E tests");
  }
  ```
- Clear error messages that describe what's missing and why it matters
- Errors thrown with descriptive context about the requirement
- No try-catch blocks in template (setup function fails on missing env vars)

## Logging

**Framework:** `console` (Node.js built-in)

**Patterns:**
- Use `console.log()` with context prefix in brackets: `console.log('[auth.setup] message')`
- Log key operations: user seeding, token creation, storage state saving
- Intended for debugging and setup verification, not production logging
- Context prefix format: `[context-name]` makes logs searchable and organized

Example:
```typescript
console.log(`[auth.setup] Seeded test user: ${TEST_USER.email}`);
console.log(`[auth.setup] Created JWT session token`);
console.log(`[auth.setup] Saved storageState to ${AUTH_FILE}`);
```

## Comments

**When to Comment:**
- ADAPT comments mark areas that require project-specific customization:
  ```typescript
  // ADAPT: import your db client and users table
  // import { db, users } from "@your-package/db";

  // ADAPT: Replace with your users table insert/upsert
  ```
- Multi-line comments explain complex operations (e.g., JWT encoding with `next-auth/jwt`)
- Inline comments explain non-obvious configuration choices
- Comments preserve intent for developers adapting the template

**JSDoc/TSDoc:**
- JSDoc block comments at file start explain purpose and adaptation points:
  ```typescript
  /**
   * Playwright Authentication Setup
   *
   * Seeds a test user and creates a valid JWT session for authenticated E2E tests.
   * Runs before other tests via the "setup" project in playwright.config.ts.
   *
   * ADAPT FOR YOUR PROJECT: ...
   */
  ```

## Configuration Patterns

**Environment-Based:**
- Load configuration from environment variables using `process.env`
- Support conditional behavior for CI vs. local:
  ```typescript
  const PORT = Number(process.env.PORT || 3000);
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  ```
- Use `.env.local` for local development (loaded by `dotenv.config()`)

**Fallback Values:**
- Provide sensible defaults:
  - `PORT` defaults to `3000`
  - Test dependencies, retries, worker count adjust for CI environment
  - `reuseExistingServer` disabled in CI to ensure fresh state

## Module Design

**Exports:**
- Test files export test cases via `test()` function from `@playwright/test`
- Setup files export setup routines via `setup()` function
- No explicit module exports in the template (tests are discovered by Playwright runner)

**Test Isolation:**
- Each test suite uses `test.describe()` block:
  ```typescript
  test.describe("Example Page", () => {
    test("should load the home page", async ({ page }) => {
      // test body
    });
  });
  ```
- Tests within a describe block are logically grouped

## Special Instructions for Project Adaptation

When using this template in a new project, follow all `ADAPT:` comments:
1. Update `TEST_USER` object to match your user schema
2. Uncomment and modify database import and insert logic
3. Add custom JWT claims beyond the default fields (id, email, name, sub, iat, exp)
4. Verify cookie name matches your NextAuth configuration
5. Update `BASE_URL` and `PORT` if different from 3000

---

*Convention analysis: 2026-02-09*
