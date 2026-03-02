# anki-screenshot-creator

Take a screenshot of anything — a textbook, slide, diagram — and get Anki flashcards automatically, powered by Claude.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/vishnya/code/main/anki_screenshot_creator/install.sh | bash
```

Then add your API key to `~/.zshrc`:

```zsh
export ANTHROPIC_API_KEY="sk-ant-..."
```

## Requirements

- macOS with [Hammerspoon](https://hammerspoon.org)
- [Anki](https://apps.ankiweb.net) with [AnkiConnect](https://ankiweb.net/shared/info/2055492159) (add-on code: `2055492159`)
- Python 3 with `pip3`
- Anthropic API key

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

If you use [Claude Code](https://claude.ai/code), there's a `/anki` slash command that loads full project context and asks what you want to work on. The install script copies it automatically.

To add it manually:

```bash
mkdir -p ~/.claude/commands
cp ~/code/anki_screenshot_creator/claude/anki.md ~/.claude/commands/anki.md
```

Then in any Claude Code session, type `/anki` to load context for this project.

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

Claude is prompted to follow Anki best practices: one concept per card, plain English backs, cloze for lists, image cards for diagrams. It generates 1–8 cards depending on content density.

The watcher process is started automatically when you pick a deck. It runs in a Terminal window and can be left open across sessions — just press `⌥⇧A` to screenshot whenever.

## Files

```
anki_screenshot_creator/
  anki_watcher.py       # watchdog + Claude + AnkiConnect logic
  anki.zsh              # anki() shell function (sourced by ~/.zshrc)
  hammerspoon/
    init.lua            # hotkey logic and deck chooser UI
  claude/
    anki.md             # /anki Claude Code skill
  install.sh            # one-step installer
```

`~/anki_watcher.py` and `~/.hammerspoon/init.lua` are symlinks into this repo so edits are version-controlled automatically.
