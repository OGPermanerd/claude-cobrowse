#!/bin/bash
# Scaffold Playwright E2E tests into the current project
# Run from your project root: ~/projects/playwright-kit/scaffold.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/template"

if [ ! -f "package.json" ]; then
  echo "Error: Run this from your project root (no package.json found)"
  exit 1
fi

echo "Scaffolding Playwright E2E tests..."

# 1. Copy config
if [ -f "playwright.config.ts" ]; then
  echo "  playwright.config.ts already exists — skipping"
else
  cp "$TEMPLATE_DIR/playwright.config.ts" .
  echo "  Created playwright.config.ts"
fi

# 2. Copy test files
if [ -d "tests/e2e" ]; then
  echo "  tests/e2e/ already exists — skipping"
else
  mkdir -p tests/e2e
  cp "$TEMPLATE_DIR/tests/e2e/auth.setup.ts" tests/e2e/
  cp "$TEMPLATE_DIR/tests/e2e/example.spec.ts" tests/e2e/
  echo "  Created tests/e2e/auth.setup.ts and example.spec.ts"
fi

# 3. Update .gitignore
if [ -f ".gitignore" ]; then
  if grep -q "playwright/.auth/" .gitignore; then
    echo "  .gitignore already has Playwright entries — skipping"
  else
    echo "" >> .gitignore
    echo "# Playwright" >> .gitignore
    cat "$TEMPLATE_DIR/.gitignore.partial" >> .gitignore
    echo "  Appended Playwright entries to .gitignore"
  fi
else
  echo "# Playwright" > .gitignore
  cat "$TEMPLATE_DIR/.gitignore.partial" >> .gitignore
  echo "  Created .gitignore with Playwright entries"
fi

# 4. Create auth storage directory
mkdir -p playwright/.auth
echo "  Created playwright/.auth/"

# 5. Install dependencies
echo ""
echo "Installing dependencies..."
if command -v pnpm &>/dev/null; then
  pnpm add -D @playwright/test dotenv
  pnpm exec playwright install chromium
elif command -v npm &>/dev/null; then
  npm install -D @playwright/test dotenv
  npx playwright install chromium
fi

echo ""
echo "Done. Next steps:"
echo "  1. Edit tests/e2e/auth.setup.ts — search for ADAPT: comments"
echo "  2. Set AUTH_SECRET and DATABASE_URL in .env.local"
echo "  3. Run: npx playwright test"
