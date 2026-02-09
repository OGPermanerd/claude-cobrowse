# Architecture

**Analysis Date:** 2026-02-09

## Pattern Overview

**Overall:** Distribution Kit Pattern (Template + Bootstrap)

This is a distribution repository designed to scaffold Playwright E2E testing infrastructure into Next.js + NextAuth v5 applications. It follows a provider-consumer pattern where:
- The kit repository defines reusable components (config, setup, tests, instructions)
- Target projects consume these components via installation scripts
- Global Claude Code instructions enforce testing discipline across all projects

**Key Characteristics:**
- **Template-driven distribution** - Core assets live in `/template` for copy/reference
- **Global instruction injection** - Testing discipline instilled via `~/.claude/CLAUDE.md`
- **Separation of kit vs. integration concerns** - Kit repo stays clean while projects adapt in-place
- **Zero-dependency templates** - Only runtime dependencies added to consuming projects
- **Declarative setup** - Shell scripts automate both global and per-project configuration

## Layers

**Kit Infrastructure (`/`):**
- Purpose: Distribution and installation orchestration
- Location: `/home/dev/projects/claude-cobrowse/`
- Contains: Installation/scaffolding scripts, README, git metadata
- Depends on: Bash, shell utilities
- Used by: Developers installing the kit

**Global Configuration (`/claude`):**
- Purpose: System-wide Claude Code behavior and testing discipline
- Location: `/home/dev/projects/claude-cobrowse/claude/CLAUDE.md`
- Contains: Global testing instructions for all Claude sessions
- Depends on: Nothing (passive configuration file)
- Used by: Claude Code IDE when executing commands in projects that have installed this kit

**Template Assets (`/template`):**
- Purpose: Copy-in assets for target projects
- Location: `/home/dev/projects/claude-cobrowse/template/`
- Contains:
  - Playwright configuration (`playwright.config.ts`)
  - Authentication setup (`tests/e2e/auth.setup.ts`)
  - Example test (`tests/e2e/example.spec.ts`)
  - Git ignore patterns (`.gitignore.partial`)
- Depends on: Playwright, NextAuth JWT encoder, project's database/auth system
- Used by: Projects receiving scaffolded E2E infrastructure

## Data Flow

**Installation Flow (Global Setup):**

1. User runs `install.sh` from kit directory
2. Script checks if `~/.claude/CLAUDE.md` exists
3. If missing, creates it with full testing discipline
4. If exists, checks for "E2E Testing Discipline" header
5. If missing section, appends testing instructions
6. Creates symlink: `~/.claude/templates/playwright-nextauth` → kit's `/template`
7. All future Claude CLI sessions in that environment inherit testing discipline

**Scaffolding Flow (Per-Project Setup):**

1. User runs `scaffold.sh` from project root
2. Script validates `package.json` exists
3. Copies `playwright.config.ts` to project root (if not present)
4. Copies `tests/e2e/{auth.setup.ts, example.spec.ts}` to project's `tests/e2e/`
5. Appends Playwright entries to project's `.gitignore`
6. Creates `playwright/.auth/` directory for storage state
7. Installs dependencies: `@playwright/test` and `dotenv`
8. Runs `npx playwright install chromium`
9. User then adapts `auth.setup.ts` for their database/auth schema

**Test Execution Flow (During Development):**

1. Developer modifies a UI page/component
2. Claude Code session loads project's CLAUDE.md (inherits global testing discipline)
3. Claude detects UI modification, runs `npx playwright test tests/e2e/specific.spec.ts`
4. Playwright config loads `playwright/.auth/user.json` (created by setup project)
5. Setup project runs first:
   - Mints JWT token via NextAuth's `encode()`
   - Seeds test user in database
   - Stores authenticated cookie in browser context
   - Saves context to `playwright/.auth/user.json`
6. Chromium project runs, inheriting authenticated session from setup project
7. Test runs against authenticated app state
8. Dev server restarts after test completion

**Authentication State Persistence:**

```
auth.setup.ts                    example.spec.ts
     │                                │
     ├─ Create JWT token              │
     │  (NextAuth encode)             │
     │                                │
     ├─ Add to browser context        │
     │  as cookie                     │
     │                                │
     └─ Save to file                  └─ Load from file
        playwright/.auth/user.json       ↓ Reuse across tests
        (gitignored)
```

**State Management:**

- **Authentication state**: Stored in `playwright/.auth/user.json` (JSON, per-project, gitignored)
- **Configuration state**: Environment variables (`.env.local` with AUTH_SECRET, DATABASE_URL)
- **Test data state**: Database persistence (seeded by auth.setup.ts before tests run)
- **Server state**: Dev server reuse in local mode, fresh start in CI (controlled by `reuseExistingServer` flag)

## Key Abstractions

**Playwright Configuration:**
- Purpose: Parameterized test environment setup
- Examples: `playwright.config.ts`
- Pattern: Reads PORT from environment, auto-starts dev server, configures project dependencies (setup → chromium), enables storage state persistence

**Authentication Setup:**
- Purpose: Seed test database and create valid JWT sessions
- Examples: `tests/e2e/auth.setup.ts`
- Pattern: Uses NextAuth's `encode()` to mint JWT, stores cookie in browser context, persists context to storage state file for reuse

**Test Pattern:**
- Purpose: Structured Playwright test with authentication
- Examples: `tests/e2e/example.spec.ts`
- Pattern: `test.describe()` > `test()` blocks, assertions via `expect()`, base URL from Playwright config, authenticated via inherited storage state

**Installation Abstraction:**
- Purpose: Declarative setup with idempotency
- Examples: `install.sh`, `scaffold.sh`
- Pattern: Check for existence before creating, append to existing files rather than replace, use symlinks for template discovery

## Entry Points

**`install.sh`:**
- Location: `/home/dev/projects/claude-cobrowse/install.sh`
- Triggers: Manual run by developer setting up environment
- Responsibilities:
  - Install/update global `~/.claude/CLAUDE.md`
  - Create symlink to template directory
  - Enable testing discipline across all projects

**`scaffold.sh`:**
- Location: `/home/dev/projects/claude-cobrowse/scaffold.sh`
- Triggers: Manual run by developer in project root
- Responsibilities:
  - Copy Playwright config to project
  - Copy test templates to project
  - Update .gitignore with Playwright entries
  - Install npm dependencies
  - Print next steps for user adaptation

**`playwright.config.ts` (in consuming project):**
- Location: Copied to consuming project root
- Triggers: Run via `npx playwright test`
- Responsibilities:
  - Load PORT from environment
  - Start dev server if not running
  - Define setup project (auth.setup.ts) dependency
  - Define chromium project that loads storage state
  - Configure reporters and retry behavior

**`auth.setup.ts` (in consuming project):**
- Location: Copied to `tests/e2e/auth.setup.ts`
- Triggers: Runs first (before all tests) via setup project
- Responsibilities:
  - Validate AUTH_SECRET environment variable
  - Seed test user in database (adapter to project schema)
  - Mint JWT token with NextAuth
  - Store cookie in browser context
  - Persist storage state to file

**`tests/e2e/*.spec.ts` (in consuming project):**
- Location: Stored in `tests/e2e/`
- Triggers: Run via `npx playwright test`
- Responsibilities:
  - Execute authenticated E2E tests
  - Assert page behavior/content
  - Use inherited browser context with auth cookie

## Error Handling

**Strategy:** Fail-fast validation with environment variable checks

**Patterns:**

- **AUTH_SECRET validation** (in `auth.setup.ts`):
  ```typescript
  if (!authSecret) {
    throw new Error("AUTH_SECRET environment variable is required for E2E tests");
  }
  ```
  Thrown during setup project, prevents later tests from running with missing auth.

- **Database connection validation** (template in `auth.setup.ts`):
  ```typescript
  if (!db) {
    throw new Error("DATABASE_URL environment variable is required for E2E tests");
  }
  ```
  Commented but provided; project adapts to their specific client.

- **Package.json validation** (in `scaffold.sh`):
  ```bash
  if [ ! -f "package.json" ]; then
    echo "Error: Run this from your project root (no package.json found)"
    exit 1
  fi
  ```
  Prevents scaffolding outside project root.

- **Playwright configuration errors**: Delegated to Playwright runner; invalid PORT/baseURL cause connection failures caught during `webServer` startup.

## Cross-Cutting Concerns

**Logging:**
- Approach: Console logging in auth.setup.ts
- Pattern: `console.log(\`[auth.setup] ...\`)`
- Used for: Tracking JWT creation, user seeding, storage state persistence

**Validation:**
- Environment variables checked early in setup project
- Shell scripts validate file existence before operations
- Playwright config validates PORT is a number

**Authentication:**
- JWT-based (NextAuth v5 compatible)
- Cookie-based persistence via browser storage state
- Per-project database seeding to match auth schema

**Configuration:**
- Environment variables (PORT, AUTH_SECRET, DATABASE_URL)
- Playwright config file (typescript)
- Per-project `.env.local` for secrets
- Shell environment for runtime decisions (CI vs. local)

---

*Architecture analysis: 2026-02-09*
