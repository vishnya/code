# anki-screenshot-creator

Take a screenshot of anything — a textbook, slide, diagram — and get Anki flashcards automatically, powered by Claude.

## Requirements

- macOS
- [Anki](https://apps.ankiweb.net) installed
- [Anthropic API key](https://console.anthropic.com)

Everything else (Hammerspoon, AnkiConnect, Python dependencies) is handled by the install script.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/vishnya/anki-screenshot-creator/main/install.sh | bash
```

The script will:
- Install Hammerspoon (via Homebrew)
- Install Python dependencies
- Open Anki and walk you through adding the AnkiConnect add-on (code: `2055492159`)
- Prompt for your Anthropic API key if not already set

## Usage

| Hotkey | Action |
|--------|--------|
| `⌥⇧A` | If Anki is closed: opens it. If open, no deck selected: shows deck chooser. If deck selected: takes screenshot immediately. |
| `⌥⇧⌘A` | Reset deck selection and show chooser again (switch subjects). |

**Workflow:**
1. Press `⌥⇧A` — Anki opens if it isn't already
2. Pick a deck (or create one) from the chooser
3. Press `⌥⇧A` again — drag to select any region of your screen
4. Cards appear in Anki within ~10 seconds

## Claude `/anki` skill

If you use [Claude Code](https://claude.ai/code), there's a `/anki` slash command that loads full project context and asks what you want to work on. The install script adds it automatically.

To add it manually:

```bash
mkdir -p ~/.claude/commands
cp ~/anki-screenshot-creator/claude/anki.md ~/.claude/commands/anki.md
```

Then type `/anki` in any Claude Code session to load context for this project.

## How it works

```
⌥⇧A keypress (Hammerspoon)
  → screencapture -i  (interactive crosshair selector)
  → saves PNG to ~/AnkiScreenshots/incoming/

anki_watcher.py (watchdog)
  → detects new PNG
  → sends image to Claude (claude-opus-4-6) with card-writing prompt
  → parses JSON response into card objects
  → posts each card to Anki via AnkiConnect HTTP API (localhost:8765)
```

Claude follows Anki best practices: one concept per card, plain English backs, cloze for lists, image cards for diagrams. Generates 1–8 cards depending on content density.

The watcher process starts automatically when you pick a deck and runs in a Terminal window. Leave it open across sessions — just press `⌥⇧A` to screenshot whenever.

## Uninstall

```bash
bash ~/anki-screenshot-creator/uninstall.sh
```

Removes symlinks, the shell function, and the Claude skill. Prompts before deleting the repo. Leaves Hammerspoon and Python packages in place.

## Files

```
anki_watcher.py       # watchdog + Claude + AnkiConnect logic
anki.zsh              # anki() shell function (sourced by ~/.zshrc)
hammerspoon/
  init.lua            # hotkey logic and deck chooser UI
claude/
  anki.md             # /anki Claude Code skill
CONTEXT.md            # living architecture doc, updated each Claude session
install.sh            # one-step installer
uninstall.sh          # removes everything install.sh added
```
