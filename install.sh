#!/bin/bash
# Install playwright-kit global Claude Code configuration
# Run from the playwright-kit repo directory

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
TEMPLATES_DIR="$CLAUDE_DIR/templates"

echo "Installing playwright-kit..."

# 1. Install global CLAUDE.md
if [ -f "$CLAUDE_DIR/CLAUDE.md" ]; then
  echo "  ~/.claude/CLAUDE.md already exists"
  if grep -q "E2E Testing Discipline" "$CLAUDE_DIR/CLAUDE.md"; then
    echo "  Testing instructions already present — skipping"
  else
    echo "  Appending testing instructions..."
    echo "" >> "$CLAUDE_DIR/CLAUDE.md"
    cat "$SCRIPT_DIR/claude/CLAUDE.md" >> "$CLAUDE_DIR/CLAUDE.md"
    echo "  Appended to ~/.claude/CLAUDE.md"
  fi
else
  mkdir -p "$CLAUDE_DIR"
  cp "$SCRIPT_DIR/claude/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
  echo "  Created ~/.claude/CLAUDE.md"
fi

# 2. Symlink template directory
mkdir -p "$TEMPLATES_DIR"
if [ -L "$TEMPLATES_DIR/playwright-nextauth" ]; then
  rm "$TEMPLATES_DIR/playwright-nextauth"
fi
ln -s "$SCRIPT_DIR/template" "$TEMPLATES_DIR/playwright-nextauth"
echo "  Linked ~/.claude/templates/playwright-nextauth -> $SCRIPT_DIR/template"

echo ""
echo "Done. All Claude CLI sessions will now follow Playwright testing discipline."
echo "To scaffold into a project: $SCRIPT_DIR/scaffold.sh"
