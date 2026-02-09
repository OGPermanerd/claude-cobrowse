# playwright-kit

Drop-in Playwright E2E testing setup for Next.js + Auth.js (NextAuth v5) projects, with Claude Code integration.

## What's Included

```
playwright-kit/
├── template/                    # Copy into your project
│   ├── playwright.config.ts     # Parameterized config
│   ├── tests/e2e/
│   │   ├── auth.setup.ts        # JWT minting + DB seed
│   │   └── example.spec.ts      # Skeleton authenticated test
│   └── .gitignore.partial       # Append to your .gitignore
├── claude/                      # Install into ~/.claude/
│   └── CLAUDE.md                # Global testing instructions
└── install.sh                   # One-command setup
```

## Install

### On a new machine (sets up global Claude instructions + template reference):

```bash
git clone <this-repo> ~/projects/playwright-kit
cd ~/projects/playwright-kit
./install.sh
```

This does two things:
1. Installs global `~/.claude/CLAUDE.md` with E2E testing discipline
2. Symlinks the template directory to `~/.claude/templates/playwright-nextauth`

### In a new project (scaffolds Playwright into your codebase):

```bash
cd ~/projects/my-new-app
~/projects/playwright-kit/scaffold.sh
```

Or manually:
```bash
npm install -D @playwright/test dotenv
npx playwright install chromium
cp ~/projects/playwright-kit/template/playwright.config.ts .
cp -r ~/projects/playwright-kit/template/tests .
cat ~/projects/playwright-kit/template/.gitignore.partial >> .gitignore
mkdir -p playwright/.auth
```

Then edit the `ADAPT:` markers in `tests/e2e/auth.setup.ts` for your project.

## Configuration

### playwright.config.ts

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `3000` | Dev server port (reads from `process.env.PORT`) |
| `webServer.command` | `npm run dev` / `npm start` | Auto-starts dev server |
| `workers` | unlimited (local) / 1 (CI) | Parallel execution |
| `retries` | 0 (local) / 2 (CI) | Retry failed tests in CI |

### auth.setup.ts

Search for `ADAPT:` comments — you'll need to:
1. Import your DB client and users table
2. Update `TEST_USER` fields to match your schema
3. Update the `db.insert()` upsert call
4. Add custom JWT claims (e.g., `tenantId`, `role`)
5. Verify cookie name matches your NextAuth config

### Required Environment Variables

Set in `.env.local`:
```
AUTH_SECRET=your-dev-secret
DATABASE_URL=postgresql://user:pass@localhost:5432/mydb
```

## Claude Code Integration

The global `~/.claude/CLAUDE.md` adds these behaviors to every Claude CLI session:

- **Always test before presenting** — Claude runs relevant Playwright tests after modifying UI
- **Restart dev server after tests** — prevents stale server state
- **Note missing coverage** — flags pages without E2E tests

### Project-Level Override

Add to your project's `CLAUDE.md` for stricter enforcement:
```markdown
## Testing
- Always invoke Playwright to test each page modified before asking the user to review it
- Never present a checkpoint without first running automated Playwright tests
- Run: `npx playwright test tests/e2e/specific.spec.ts`
```

## Design Decisions

- **JWT-based auth** — mint tokens directly, no OAuth flow needed in tests
- **DB seeding in setup** — test user exists before any test runs
- **Storage state file** — authenticated cookie persists across all tests
- **Dev server auto-start** — `reuseExistingServer` in local, fresh start in CI
- **Chromium only** — fast, sufficient for most web app testing

## Adapting to Other Auth

The pattern works with any JWT-based auth system:
1. Mint your JWT however your auth expects
2. Set the correct cookie name/attributes in `auth.setup.ts`
3. Seed whatever user record your app needs
