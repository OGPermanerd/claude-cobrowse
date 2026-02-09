# Technology Stack

**Analysis Date:** 2026-02-09

## Languages

**Primary:**
- TypeScript - E2E testing setup and configuration
- Bash - Installation and scaffolding scripts

**Secondary:**
- JavaScript - Runtime environment for Node.js

## Runtime

**Environment:**
- Node.js (no specific version pinned, recommended via .nvmrc or similar in target projects)

**Package Manager:**
- npm - Primary package manager (also supports pnpm and yarn)
- Lockfile: Not applicable (this is a scaffolding kit, not a consumable package)

## Frameworks

**Testing:**
- Playwright (`@playwright/test`) - E2E testing framework
  - Browsers: Chromium only (configured in `template/playwright.config.ts`)
  - Configuration: Parameterized via `playwright.config.ts` and environment variables
  - Version: No specific version pinned in scaffold.sh (installs latest)

**Authentication:**
- Next.js Auth v5 (NextAuth.js) - JWT-based session management
  - JWT encoding: `next-auth/jwt` package
  - Token-based auth in `template/tests/e2e/auth.setup.ts`

## Key Dependencies

**Critical:**
- `@playwright/test` - E2E testing framework and assertion library
  - Why it matters: Core testing engine, must be installed for any project scaffolded
  - Installation: `npm install -D @playwright/test` via scaffold.sh

- `dotenv` - Environment variable management
  - Why it matters: Loads `.env.local` in playwright config for auth secrets and DB credentials
  - Installation: `npm install -D dotenv`

**Auth-related:**
- `next-auth/jwt` - JWT encoding/decoding for session tokens
  - Why it matters: Used in `auth.setup.ts` to mint test session tokens
  - Required import: `import { encode } from "next-auth/jwt"`

**Peer Dependencies (in target projects):**
- `next` - Next.js framework (required by projects this kit scaffolds into)
- `next-auth@5.x` - NextAuth v5 (specific to projects, not declared in this kit)

## Configuration

**Environment:**
- `.env.local` file (created in target project root)
- Required variables:
  - `AUTH_SECRET` - Signing secret for JWT tokens (used in `auth.setup.ts`)
  - `DATABASE_URL` - Database connection string (optional if not using DB seeding)
  - `PORT` - Dev server port (defaults to 3000 if not set)

**Build:**
- `playwright.config.ts` - Main Playwright configuration
  - Location: Copied to target project root via `scaffold.sh`
  - Configurable via environment: `PORT`, `CI` flag
  - Auto-starts dev server with `npm run dev` or `npm start`

- `tsconfig.json` - Not present in this kit (relies on target project's TypeScript config)

## Platform Requirements

**Development:**
- Node.js (any recent version, typically 18+)
- npm/pnpm/yarn package manager
- Bash shell (for `install.sh` and `scaffold.sh`)
- Available PORT 3000 (default) or configurable via `PORT` env var

**Production (in target projects):**
- Node.js runtime
- Chromium browser (auto-installed by `npx playwright install chromium`)
- Environment variables set in CI environment or deployment platform

## Installation Targets

**Global Installation:**
- Installs `~/.claude/CLAUDE.md` - Global Claude Code testing instructions
- Symlinks `~/.claude/templates/playwright-nextauth` - Template reference for Claude CLI

**Per-Project Installation:**
- Target: Any Next.js project with NextAuth v5
- Copies: `playwright.config.ts`, `tests/e2e/` directory
- Creates: `playwright/.auth/` directory for session state
- Modifies: `.gitignore` to exclude test artifacts

## Dev Server Integration

**Local Development:**
- Uses `npm run dev` (Next.js default dev command)
- Configurable via `webServer.command` in config
- `reuseExistingServer: true` - Reuses running server in local testing
- `reuseExistingServer: false` - Fresh server start in CI

**CI/CD:**
- Uses `npm start` - Production-like server
- Forces fresh server startup
- Single worker (`workers: 1`)
- Retry logic enabled (`retries: 2`)

---

*Stack analysis: 2026-02-09*
