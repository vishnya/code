# anki-screenshot-creator — Project Context

This file is read by the Claude `/anki` skill at the start of every session and updated
at the end. It is the living source of truth for architecture, status, and recent changes.

## What It Does
Press `⌥⇧A` → crosshair screenshot selector → Claude analyzes PNG → cards added to Anki automatically.

## Key Files
| File | Purpose |
|------|---------|
| `anki_watcher.py` | Watchdog watcher: monitors `~/AnkiScreenshots/incoming/`, calls Claude API, posts cards to AnkiConnect |
| `hammerspoon/init.lua` | Hotkey logic, 3-state machine, deck chooser UI |
| `anki.zsh` | `anki()` shell function sourced by `~/.zshrc` |

After install, `~/anki_watcher.py` and `~/.hammerspoon/init.lua` are symlinks into this repo.

## Architecture
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

## 3-State Hotkey (`⌥⇧A`)
- **State 1** — Anki closed → opens Anki, polls AnkiConnect every 1s (up to 15s)
- **State 2** — Anki open, no deck selected → shows `hs.chooser` with deck list + "Create new deck..."
- **State 3** — Deck selected → takes screenshot immediately

`⌥⇧⌘A` resets deck selection and shows the chooser again (to switch subjects).

## AnkiConnect
- URL: `http://localhost:8765`
- Version: 6
- Test: `curl -s -X POST http://localhost:8765 -d '{"action":"version","version":6}'`
- List decks: `curl -s -X POST http://localhost:8765 -d '{"action":"deckNames","version":6}'`

## Known Gotchas
- Anki process name is `python3.x` — detect with `lsof -i :8765`, not `pgrep -x Anki`
- `anki` in terminal is a zsh function, not a binary — only works in interactive shells
- Multiple watcher processes can accumulate: `ps aux | grep anki_watcher | grep -v grep`
- Deck name = `mode.capitalize()` (e.g. `--mode anatomy` → deck `Anatomy`)

## Recent Changes
- 2026-03-01: Fixed freeze on deck select — `openTerminalWithAnki` switched from `hs.execute` (blocking) to `hs.task.new(...):start()` (async)
- 2026-03-02: Moved into monorepo at `~/code/anki_screenshot_creator/`, symlinks replace original paths. Published to github.com/vishnya/anki-screenshot-creator.
