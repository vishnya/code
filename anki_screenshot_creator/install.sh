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
pip3 install -q anthropic openai watchdog requests Pillow flask
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

# ── launchd agent ─────────────────────────────────────────────────────────────
PYTHON_PATH="$(which python3)"
PLIST_DEST="$HOME/Library/LaunchAgents/com.anki-screenshot-creator.plist"

mkdir -p "$HOME/Library/LaunchAgents"
sed \
  -e "s|__PYTHON__|${PYTHON_PATH}|g" \
  -e "s|__PROJECT__|${PROJECT}|g" \
  "$PROJECT/launchd/com.anki-screenshot-creator.plist" > "$PLIST_DEST"

# Unload if already loaded (e.g. re-running install), then reload
launchctl unload "$PLIST_DEST" 2>/dev/null || true
launchctl load   "$PLIST_DEST"
echo "✓ launchd agent (auto-starts on login)"

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

echo "=== Done! ==="
echo ""
echo "  1. Press ⌥⇧A  → opens http://localhost:5789 in your browser"
echo "  2. Choose deck, add your API key, click Start Session"
echo "  3. Press ⌥⇧A  → crosshair to screenshot → cards appear in Anki"
echo ""
echo "Server logs: tail -f /tmp/anki-screenshot-creator.log"
echo "Uninstall:   bash $REPO_DIR/uninstall.sh"
