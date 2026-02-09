# Codebase Structure

**Analysis Date:** 2026-02-09

## Directory Layout

```
claude-cobrowse/
├── .git/                       # Git repository metadata
├── .gitignore                  # Root .gitignore
├── .planning/                  # GSD planning documents (generated)
│   └── codebase/              # Codebase analysis docs
├── claude/                     # Global Claude Code instructions
│   └── CLAUDE.md              # Testing discipline rules
├── template/                  # Copy-in assets for consuming projects
│   ├── .gitignore.partial     # Append to project .gitignore
│   ├── playwright.config.ts   # Parameterized Playwright config
│   └── tests/e2e/             # Test templates
│       ├── auth.setup.ts      # JWT + DB seeding setup
│       └── example.spec.ts    # Example authenticated test
├── README.md                  # Installation and usage docs
├── install.sh                 # Install global testing discipline
├── scaffold.sh                # Scaffold Playwright into a project
└── (no src/ or source code)   # This is a distribution kit, not an app
```

## Directory Purposes

**Root (`/`):**
- Purpose: Kit distribution and documentation
- Contains: Installation scripts, README, license/metadata
- Key files: `install.sh`, `scaffold.sh`, `README.md`

**`.git/`:**
- Purpose: Git repository metadata
- Contains: Commit history, refs, objects
- Key files: `HEAD`, `config`, `objects/`

**`.planning/`:**
- Purpose: Generated GSD planning documents
- Contains: Codebase analysis (ARCHITECTURE.md, STRUCTURE.md, etc.)
- Generated: Yes (by GSD orchestrator)
- Committed: No (excluded via .gitignore or .gsdignore)

**`claude/`:**
- Purpose: Global Claude Code instructions to install on developer machine
- Contains: `CLAUDE.md` with E2E testing discipline
- Key files: `claude/CLAUDE.md`
- Deployed to: `~/.claude/CLAUDE.md` on user's machine

**`template/`:**
- Purpose: Copy-in assets for target projects
- Contains:
  - Configuration files (`playwright.config.ts`)
  - Test setup code (`tests/e2e/auth.setup.ts`)
  - Example tests (`tests/e2e/example.spec.ts`)
  - Git ignore entries (`.gitignore.partial`)
- Key files: All files under `template/`
- Deployed to: Consuming project root and subdirectories

## Key File Locations

**Entry Points:**

- `install.sh`: `/home/dev/projects/claude-cobrowse/install.sh`
  - Purpose: Install global testing discipline to `~/.claude/CLAUDE.md`
  - Run from: Kit repo root
  - Triggers: `./install.sh`

- `scaffold.sh`: `/home/dev/projects/claude-cobrowse/scaffold.sh`
  - Purpose: Scaffold Playwright E2E infrastructure into a project
  - Run from: Target project root (where package.json exists)
  - Triggers: `~/projects/playwright-kit/scaffold.sh`

**Configuration:**

- `playwright.config.ts`: `/home/dev/projects/claude-cobrowse/template/playwright.config.ts`
  - Purpose: Playwright test configuration
  - Copied to: Project root after scaffolding
  - Key settings: PORT (env var), webServer command, projects (setup + chromium), storage state path

- `CLAUDE.md`: `/home/dev/projects/claude-cobrowse/claude/CLAUDE.md`
  - Purpose: Global Claude Code behavior enforcement
  - Installed to: `~/.claude/CLAUDE.md` (user's home)
  - Loaded by: Claude Code IDE on every session in projects with this discipline

**Core Logic:**

- `auth.setup.ts`: `/home/dev/projects/claude-cobrowse/template/tests/e2e/auth.setup.ts`
  - Purpose: Authentication setup that runs before all tests
  - Copied to: `tests/e2e/auth.setup.ts` in consuming project
  - Responsibilities:
    - Validate AUTH_SECRET environment variable
    - Seed test user in database (project-specific adaptation)
    - Mint JWT token using NextAuth's `encode()`
    - Store authenticated cookie in Playwright browser context
    - Persist context to `playwright/.auth/user.json`

- `example.spec.ts`: `/home/dev/projects/claude-cobrowse/template/tests/e2e/example.spec.ts`
  - Purpose: Skeleton authenticated test file
  - Copied to: `tests/e2e/example.spec.ts` in consuming project
  - Pattern: `test.describe()` wrapper with two example tests

**Testing:**

- `tests/e2e/`: `/home/dev/projects/claude-cobrowse/template/tests/e2e/`
  - Purpose: Contains test files and setup
  - When copied: Entire directory goes to `tests/e2e/` in consuming project
  - Files:
    - `auth.setup.ts` (setup project, runs first)
    - `example.spec.ts` (chromium project, runs with auth)

## Naming Conventions

**Files:**

- Playwright config: `playwright.config.ts` (TypeScript, matches Playwright convention)
- Setup file: `auth.setup.ts` (matches Playwright's `.setup.ts` pattern, triggers setup project)
- Test specs: `*.spec.ts` (Playwright default pattern, not `.test.ts`)
- Config: `CLAUDE.md` (uppercase, matches global instruction convention)
- Ignore partial: `.gitignore.partial` (prefix indicates partial file, appended not replaced)

**Directories:**

- `template/` (lowercase, contains copy-in assets)
- `tests/` (lowercase, matches common testing convention)
- `e2e/` (lowercase abbreviation, specific to end-to-end testing)
- `.planning/` (hidden dot prefix, generated planning docs)
- `playwright/.auth/` (Playwright convention for authentication state)
- `codebase/` (under `.planning/`, holds codebase analysis docs)

## Where to Add New Code

**New Test File:**
- Primary code: `template/tests/e2e/{feature}.spec.ts`
- Pattern:
  ```typescript
  import { test, expect } from "@playwright/test";

  test.describe("Feature Name", () => {
    test("should do something", async ({ page }) => {
      await page.goto("/path");
      await expect(page.locator("selector")).toBeVisible();
    });
  });
  ```
- When added to template, will be copied to consuming projects during scaffolding

**New Configuration Variable:**
- Primary location: `template/playwright.config.ts`
- Pattern:
  - Add to `defineConfig()` object
  - If environment-dependent, read from `process.env.VARIABLE_NAME`
  - Document in README.md configuration table

**Documentation/Instructions:**
- Global: `claude/CLAUDE.md` (affects all projects with this kit installed)
- Project-specific: Include in README.md (discoverable by users)

**Setup Adapter (per project):**
- Location: Not in template, requires per-project adaptation
- Pattern: User modifies `tests/e2e/auth.setup.ts` after scaffolding
- Search for: `ADAPT:` comments marking required customizations

## Special Directories

**`template/`:**
- Purpose: Copy-in assets for consuming projects
- Generated: No
- Committed: Yes (core distribution assets)
- Deployment: Copied to project or symlinked for reference

**`.planning/codebase/`:**
- Purpose: GSD-generated codebase analysis documents
- Generated: Yes (by GSD orchestrator)
- Committed: No (.gitignore excludes)
- Content: ARCHITECTURE.md, STRUCTURE.md, CONVENTIONS.md, TESTING.md, STACK.md, INTEGRATIONS.md, CONCERNS.md

**`playwright/.auth/` (in consuming projects):**
- Purpose: Store authenticated browser state between test runs
- Generated: Yes (created by auth.setup.ts)
- Committed: No (.gitignore.partial excludes as `playwright/.auth/`)
- Content: `user.json` (browser context storage state with authenticated cookies/session)

**`playwright-report/` (in consuming projects):**
- Purpose: HTML test reports
- Generated: Yes (by Playwright test runner)
- Committed: No (.gitignore.partial excludes)
- Content: HTML + assets from test runs

**`test-results/` (in consuming projects):**
- Purpose: JSON test results
- Generated: Yes (by Playwright test runner)
- Committed: No (.gitignore.partial excludes)
- Content: Test metadata, failures, traces

## File Relationships

**Installation Chain:**
```
install.sh
    ├─ reads: claude/CLAUDE.md
    └─ writes: ~/.claude/CLAUDE.md
           ↓ symlinks
    ~/.claude/templates/playwright-nextauth → template/
```

**Scaffolding Chain:**
```
scaffold.sh (from kit)
    ├─ reads: template/playwright.config.ts
    ├─ reads: template/tests/e2e/auth.setup.ts
    ├─ reads: template/tests/e2e/example.spec.ts
    ├─ reads: template/.gitignore.partial
    └─ writes to consuming project:
        ├─ playwright.config.ts
        ├─ tests/e2e/auth.setup.ts
        ├─ tests/e2e/example.spec.ts
        ├─ .gitignore (append)
        └─ playwright/.auth/ (directory)
```

**Test Execution Chain (in consuming project):**
```
npx playwright test
    ├─ reads: playwright.config.ts
    ├─ project "setup":
    │   ├─ runs: tests/e2e/auth.setup.ts
    │   ├─ reads: .env.local (AUTH_SECRET, DATABASE_URL)
    │   └─ writes: playwright/.auth/user.json
    └─ project "chromium":
        ├─ depends on: setup (waits for it first)
        ├─ reads: playwright/.auth/user.json
        ├─ starts: dev server (if not running)
        └─ runs: tests/e2e/*.spec.ts
```

## Documentation Structure

**README.md:**
- Location: `/home/dev/projects/claude-cobrowse/README.md`
- Contains: What's included, installation, configuration, design decisions
- Audience: Developers installing the kit

**CLAUDE.md (Global):**
- Location: `/home/dev/projects/claude-cobrowse/claude/CLAUDE.md`
- Contains: E2E testing discipline rules
- Audience: Claude Code IDE (applies to all sessions)

**CLAUDE.md (Project-level):**
- Location: Not provided by kit, optional in consuming project
- Contains: Project-specific overrides to global rules
- Audience: Claude Code IDE (overrides global rules)

---

*Structure analysis: 2026-02-09*
