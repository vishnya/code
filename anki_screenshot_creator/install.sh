#!/usr/bin/env bash
set -e

echo "=== anki-screenshot-creator setup ==="
echo ""

# ── Homebrew ──────────────────────────────────────────────────────────────────
if ! command -v brew &>/dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  echo "✓ Homebrew"
fi

# ── Hammerspoon ───────────────────────────────────────────────────────────────
if [ ! -d "/Applications/Hammerspoon.app" ]; then
  echo "Installing Hammerspoon..."
  brew install --cask hammerspoon
else
  echo "✓ Hammerspoon"
fi

# ── Python dependencies ───────────────────────────────────────────────────────
echo "Installing Python dependencies..."
pip3 install -q anthropic watchdog requests Pillow
echo "✓ Python dependencies"

# ── Clone repo ────────────────────────────────────────────────────────────────
REPO_DIR="$HOME/anki-screenshot-creator"
PROJECT="$REPO_DIR"

if [ ! -d "$REPO_DIR/.git" ]; then
  echo "Cloning repo to $REPO_DIR..."
  git clone https://github.com/vishnya/anki-screenshot-creator "$REPO_DIR"
else
  echo "✓ Repo already present at $REPO_DIR"
fi

# ── Symlinks ──────────────────────────────────────────────────────────────────
ln -sf "$PROJECT/anki_watcher.py" "$HOME/anki_watcher.py"
mkdir -p "$HOME/.hammerspoon"
ln -sf "$PROJECT/hammerspoon/init.lua" "$HOME/.hammerspoon/init.lua"
mkdir -p "$HOME/.anki-screenshot-creator"
ln -sf "$PROJECT/CONTEXT.md" "$HOME/.anki-screenshot-creator/CONTEXT.md"
echo "✓ Symlinks"

# ── Claude /anki skill ────────────────────────────────────────────────────────
if [ -d "$HOME/.claude/commands" ]; then
  cp "$PROJECT/claude/anki.md" "$HOME/.claude/commands/anki.md"
  echo "✓ Claude /anki skill"
fi

# ── .zshrc ────────────────────────────────────────────────────────────────────
if ! grep -q "anki-screenshot-creator/anki.zsh" "$HOME/.zshrc" 2>/dev/null; then
  printf '\n# Anki watcher\nsource %s/anki.zsh\n' "$PROJECT" >> "$HOME/.zshrc"
fi
echo "✓ Shell function"

# ── Anthropic API key ─────────────────────────────────────────────────────────
if [[ -z "$ANTHROPIC_API_KEY" ]] && ! grep -q "ANTHROPIC_API_KEY" "$HOME/.zshrc" 2>/dev/null; then
  echo ""
  read -rp "Paste your Anthropic API key (from console.anthropic.com): " api_key
  printf '\nexport ANTHROPIC_API_KEY="%s"\n' "$api_key" >> "$HOME/.zshrc"
  echo "✓ API key saved to ~/.zshrc"
else
  echo "✓ Anthropic API key"
fi

# ── AnkiConnect ───────────────────────────────────────────────────────────────
echo ""
echo "Opening Anki to install the AnkiConnect add-on..."
open -a Anki 2>/dev/null || echo "(Anki not found — install it from https://apps.ankiweb.net first)"
echo ""
echo "  In Anki:  Tools > Add-ons > Get Add-ons"
echo "  Code:     2055492159"
echo "  Click OK, then restart Anki."
echo ""
read -rp "Press Enter once AnkiConnect is installed and Anki has restarted... "

# ── Hammerspoon first launch ──────────────────────────────────────────────────
echo ""
echo "Opening Hammerspoon..."
open -a Hammerspoon
echo "  If prompted, grant Accessibility permissions in System Settings."
echo ""

echo "=== Done! Press ⌥⇧A to start. ==="
echo ""
echo "To uninstall: bash $REPO_DIR/uninstall.sh"
