# Global Claude Code Instructions

## E2E Testing Discipline
- When modifying UI pages or components, run the relevant Playwright E2E tests before presenting work
- Never present a checkpoint without first verifying modified pages load without errors
- If no Playwright tests exist for a modified page, note this gap to the user
- After running tests that stop or interfere with the dev server, restart it

## Playwright Conventions
- Test files: `tests/e2e/*.spec.ts`
- Auth setup: `tests/e2e/auth.setup.ts` (runs before all tests via "setup" project)
- Config: `playwright.config.ts` at the app root
- Run: `npx playwright test` (or `npx playwright test tests/e2e/specific.spec.ts`)
- Storage state: `playwright/.auth/user.json` (gitignored)

## General
- Prefer editing existing files over creating new ones
- Check for circuit breakers in project-level CLAUDE.md before long-running operations
