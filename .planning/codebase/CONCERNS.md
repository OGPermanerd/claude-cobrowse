# Codebase Concerns

**Analysis Date:** 2026-02-09

## Security Considerations

**Hardcoded test credentials:**
- Risk: Test user email `e2e-test@company.com` is hardcoded with predictable ID `e2e-test-user`
- Files: `template/tests/e2e/auth.setup.ts` (lines 19-23)
- Current mitigation: This is test-only code, not shipped to production
- Recommendations:
  - Document clearly that test user IDs must be randomized or unique per test run to avoid conflicts in shared environments
  - Consider generating test user IDs programmatically (e.g., using UUID or timestamp)
  - Update README to warn against reusing these hardcoded values in multi-developer or CI environments

**JWT cookie configured insecurely in setup:**
- Risk: `secure: false` flag hardcoded in auth cookie (line 89 of auth.setup.ts)
- Files: `template/tests/e2e/auth.setup.ts` (line 89)
- Current mitigation: Only applies to localhost; comment acknowledges this
- Recommendations:
  - This is appropriate for local testing but could be misapplied. Add guard to ensure secure flag is set dynamically based on BASE_URL
  - Document why this must never be set to `secure: false` in production
  - Consider auto-detecting localhost vs. production environment

**Missing AUTH_SECRET validation in setup:**
- Risk: If AUTH_SECRET is empty string or whitespace, JWT encoding will fail silently or produce invalid tokens
- Files: `template/tests/e2e/auth.setup.ts` (lines 31-33)
- Current mitigation: Throws error if AUTH_SECRET is undefined, but not if it's empty or whitespace
- Recommendations:
  - Add stronger validation: `if (!authSecret || authSecret.trim().length === 0)`
  - Add minimum length check (NextAuth recommends at least 32 characters)

## Configuration & Adaptation Risks

**Heavy reliance on ADAPT markers:**
- Risk: The template requires 4+ "ADAPT:" code changes (db connection, users table, JWT payload, cookie name). Missing these breaks authentication
- Files: `template/tests/e2e/auth.setup.ts` (multiple ADAPT comments)
- Impact: E2E tests will fail silently or authenticate incorrectly if adaptations are incomplete
- Recommendations:
  - Create a validation/check script that verifies all ADAPT points have been customized
  - Add a pre-test hook that validates the adapted configuration (e.g., check cookie name matches NextAuth config)
  - Provide a checklist or interactive setup tool to guide users through adaptations

**Database integration is completely commented out:**
- Risk: The database seeding code is 100% commented out (lines 35-56). Users may forget to uncomment and adapt it, causing tests to run without proper test data
- Files: `template/tests/e2e/auth.setup.ts` (lines 35-56)
- Impact: Tests run with token/session but no actual test user in database; queries may fail downstream
- Recommendations:
  - Add an explicit error if DB seeding is not configured: check for env var like `DATABASE_ENABLED=true` or validate that seeding code runs
  - Provide a working example or default implementation that's simpler to adapt
  - Add documentation linking specific schema requirements

**Port configuration via environment variable:**
- Risk: If `PORT` env var is not set, defaults to 3000; if user's dev server runs on different port, tests silently target wrong URL
- Files: `template/playwright.config.ts` (line 9)
- Impact: Tests pass but test wrong server instance
- Recommendations:
  - Add validation: warn or fail if base URL is unreachable before tests run
  - Consider requiring explicit PORT in .env.local rather than defaulting
  - Log the BASE_URL being used at the start of test runs

## Environment & Dependency Risks

**Missing .env.local setup documentation:**
- Risk: Tests require AUTH_SECRET and DATABASE_URL in .env.local but scaffold.sh doesn't create or validate this file
- Files: All template test files depend on `.env.local`
- Impact: Users run tests without required env vars; tests fail with cryptic "AUTH_SECRET is required" error
- Recommendations:
  - Update scaffold.sh to create a template .env.local with required variables
  - Add validation step in auth.setup.ts that logs missing env vars clearly
  - Document in README which env vars are mandatory vs. optional

**Playwright version compatibility:**
- Risk: No pinned Playwright version; scaffold.sh installs latest which may have breaking changes between major versions
- Files: `scaffold.sh` (lines 59-63)
- Impact: Different developers may get different Playwright versions with incompatible APIs
- Recommendations:
  - Add Playwright version to a peerDependencies or document required version in README
  - Consider adding @playwright/test version to package.json in template scaffolding

**dotenv dependency not in template package.json:**
- Risk: playwright.config.ts imports `dotenv` but scaffold.sh installs it only as dev dependency
- Files: `template/playwright.config.ts` (line 2) and `scaffold.sh` (line 59-63)
- Impact: May not be available if node_modules is not properly cleaned/installed
- Recommendations:
  - Create a minimal template package.json that includes both @playwright/test and dotenv with pinned versions
  - Add it to scaffold.sh installation step

## Fragile Areas

**Storage state file path hardcoded in multiple places:**
- Risk: `playwright/.auth/user.json` is hardcoded in auth.setup.ts (line 26) and playwright.config.ts (line 35); must match exactly
- Files: `template/tests/e2e/auth.setup.ts` (line 26) and `template/playwright.config.ts` (line 35)
- Impact: If path changes in one place but not the other, authentication setup works but tests use wrong state file
- Recommendations:
  - Extract path to a shared constant or environment variable
  - Consider using a more predictable name or location (e.g., `.playwright/auth.json` to be more explicit)

**Example test uses overly generic selectors:**
- Risk: `example.spec.ts` uses `page.locator("body")` and checks `toBeVisible()` — passes trivially
- Files: `template/tests/e2e/example.spec.ts` (line 11)
- Impact: Example test doesn't validate actual app content; users copying this pattern write ineffective tests
- Recommendations:
  - Replace generic body check with a more specific assertion (e.g., check for app header, navigation, or user-specific content)
  - Add comments explaining why each assertion matters
  - Document test design principles in README

**No error handling for database seeding failures:**
- Risk: Commented-out DB code has no try-catch; if uncommented and DB fails, error is not caught
- Files: `template/tests/e2e/auth.setup.ts` (lines 42-56)
- Impact: DB seeding errors silently fail; tests run without data
- Recommendations:
  - Add error handling wrapper around DB operations
  - Log which test user was/wasn't seeded
  - Fail fast with clear error message if seeding fails

## Test Coverage Gaps

**No tests for the test setup itself:**
- What's not tested: Whether auth.setup.ts actually creates valid JWT tokens and cookies
- Files: `template/tests/e2e/auth.setup.ts`
- Risk: Setup code could be broken but tests would silently skip it or fail with confusing errors
- Priority: Medium
- Recommendations:
  - Add a simple validation test that verifies token can be decoded and cookie was created
  - Log token details (header, payload) for debugging

**No validation that adapted code is correct:**
- What's not tested: After user adapts ADAPT: markers, is the adapted code syntactically correct and functional?
- Files: `template/tests/e2e/auth.setup.ts`
- Risk: Common adaptation mistakes (wrong table name, wrong field names) only manifest as runtime failures in actual tests
- Priority: High
- Recommendations:
  - Add a pre-test validation that checks the adapted database code compiles and runs
  - Provide example adaptations for popular ORMs (Prisma, Drizzle, etc.)

**No cookie validation test:**
- What's not tested: Whether the cookie set in auth.setup.ts matches the cookie expected by the app's NextAuth config
- Files: `template/tests/e2e/auth.setup.ts`
- Risk: Users may use wrong cookie name; tests authenticate but app redirects to login
- Priority: High
- Recommendations:
  - Add a validation step that checks if the configured cookie name appears in the app's NextAuth config
  - Test that a page marked as protected (requires auth) is actually accessible after setup

## Missing Critical Features

**No logout test:**
- Problem: Example test doesn't include logout flow; users may not test that authenticated session is properly cleared
- Blocks: Can't verify auth state is cleaned between test runs
- Recommendations:
  - Add optional logout/cleanup test to example.spec.ts
  - Document session lifecycle and how to test logout flows

**No multi-user testing pattern:**
- Problem: Template only handles single test user; no guidance for testing with multiple users or permission levels
- Blocks: Can't test role-based access control or multi-user scenarios
- Recommendations:
  - Add optional pattern for creating and switching between multiple test users
  - Document how to seed different user roles in the database

**No error page tests:**
- Problem: Example tests authenticated happy path only; no guidance for testing 403/401 redirects or error states
- Blocks: Can't verify auth guard behavior when permissions are missing
- Recommendations:
  - Add example of testing protected routes with insufficient permissions
  - Document how to test logout → redirect to login flows

## Performance Bottlenecks

**Full browser parallel execution with no worker limit:**
- Problem: `workers: undefined` in local mode allows unlimited parallel workers (line 18)
- Files: `template/playwright.config.ts` (line 18)
- Impact: On machines with < 4GB RAM or slower disks, unlimited workers cause OOM or thrashing
- Improvement path:
  - Default to a reasonable worker count (e.g., 2-4) based on CPU cores
  - Allow override via environment variable `PW_WORKERS`

**reuseExistingServer enabled locally without health check:**
- Problem: Dev server may be stale or in a bad state; Playwright reuses it without verification
- Files: `template/playwright.config.ts` (line 43)
- Impact: Tests may fail against old server state; misleading failures
- Improvement path:
  - Add explicit health check endpoint or page that validates server is ready
  - Consider adding `waitForNavigation` or explicit "server ready" signal before running tests

## Dependencies at Risk

**next-auth dependency version drift:**
- Risk: auth.setup.ts uses `next-auth/jwt` encode function; no version constraint documented
- Files: `template/tests/e2e/auth.setup.ts` (line 14)
- Impact: NextAuth v4 vs. v5 have different APIs; cookie name changed; users upgrading NextAuth may break tests
- Migration plan:
  - Document required NextAuth version (v5 based on code comments)
  - Add validation that detects NextAuth version mismatch
  - Provide migration guide for v4 → v5 users

**@playwright/test breaking changes between major versions:**
- Risk: scaffold.sh installs latest Playwright without version pinning
- Impact: API changes between Playwright 1.x and 2.x could break tests
- Migration plan:
  - Pin Playwright to ^1.x for now
  - Document when/how to upgrade to v2.x (if it exists)
  - Test against multiple Playwright versions in CI

---

*Concerns audit: 2026-02-09*
