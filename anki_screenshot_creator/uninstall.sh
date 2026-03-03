#!/usr/bin/env bash
set -e

echo "=== anki-screenshot-creator uninstall ==="
echo ""

REPO_DIR="$HOME/anki-screenshot-creator"
PLIST="$HOME/Library/LaunchAgents/com.anki-screenshot-creator.plist"

# launchd agent
if [ -f "$PLIST" ]; then
  launchctl unload "$PLIST" 2>/dev/null || true
  rm -f "$PLIST"
  echo "✓ launchd agent removed"
fi

# Symlinks
rm -f "$HOME/anki_watcher.py"    # legacy symlink, may not exist
rm -f "$HOME/.hammerspoon/init.lua"
rm -rf "$HOME/.anki-screenshot-creator"
echo "✓ Symlinks removed"

# Shell function
if grep -q "anki-screenshot-creator/anki.zsh" "$HOME/.zshrc" 2>/dev/null; then
  sed -i '' '/# Anki watcher/d' "$HOME/.zshrc"
  sed -i '' '/anki-screenshot-creator\/anki.zsh/d' "$HOME/.zshrc"
  echo "✓ Shell function removed from ~/.zshrc"
fi

# Claude skill
rm -f "$HOME/.claude/commands/anki.md"
echo "✓ Claude /anki skill removed"

# Repo
if [ -d "$REPO_DIR" ]; then
  read -rp "Delete repo at $REPO_DIR? [y/N] " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    rm -rf "$REPO_DIR"
    echo "✓ Repo deleted"
  else
    echo "  Repo kept at $REPO_DIR"
  fi
fi

echo ""
echo "=== Done. Hammerspoon and Python packages were left in place. ==="
