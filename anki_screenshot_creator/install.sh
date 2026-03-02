#!/usr/bin/env bash
set -e

REPO_DIR="$HOME/code"
PROJECT="$REPO_DIR/anki_screenshot_creator"

# Clone repo if not already present
if [ ! -d "$REPO_DIR/.git" ]; then
  git clone https://github.com/vishnya/anki-screenshot-creator "$REPO_DIR"
fi

# Python dependencies
pip3 install anthropic watchdog requests

# Symlinks
ln -sf "$PROJECT/anki_watcher.py" "$HOME/anki_watcher.py"
mkdir -p "$HOME/.hammerspoon"
ln -sf "$PROJECT/hammerspoon/init.lua" "$HOME/.hammerspoon/init.lua"

# Claude /anki skill
mkdir -p "$HOME/.claude/commands"
cp "$PROJECT/claude/anki.md" "$HOME/.claude/commands/anki.md"

# .zshrc
if ! grep -q "anki_screenshot_creator/anki.zsh" "$HOME/.zshrc"; then
  printf '\n# Anki watcher\nsource %s/anki.zsh\n' "$PROJECT" >> "$HOME/.zshrc"
fi

echo ""
echo "Installed. Two manual steps remain:"
echo ""
echo "  1. Add your API key to ~/.zshrc:"
echo "       export ANTHROPIC_API_KEY=\"sk-ant-...\""
echo ""
echo "  2. Install AnkiConnect inside Anki:"
echo "       Tools > Add-ons > Get Add-ons > code: 2055492159"
echo ""
echo "  3. Reload Hammerspoon (Cmd+Option+R) or run: hs -c 'hs.reload()'"
echo ""
echo "Then press ⌥⇧A to start."
