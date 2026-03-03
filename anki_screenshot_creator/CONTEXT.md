# anki-screenshot-creator — Project Context

This file is read by the Claude `/anki` skill at the start of every session and updated
at the end. It is the living source of truth for architecture, status, and recent changes.

## What It Does
Press `⌥⇧A` → crosshair screenshot selector → model generates cards → cards added to Anki automatically.

## Key Files
| File | Purpose |
|------|---------|
| `flask_server.py` | Flask app (port 5789): serves web UI, API endpoints, watchdog thread |
| `config.py` | Read/write `~/.anki-screenshot-creator/config.json` |
| `models.py` | Provider abstraction: generate_cards(image_path, config) |
| `hammerspoon/init.lua` | Hotkey: GET /api/session → screenshot or open browser |
| `anki.zsh` | `anki()` shell function: ensure server running + open browser |
| `web/templates/index.html` | Single-page config + session UI |
| `web/static/style.css` | Dark theme |
| `web/static/app.js` | Deck fetch, save, session control, SSE live updates |
| `launchd/com.anki-screenshot-creator.plist` | Template; install.sh generates the live plist |

After install, `~/.hammerspoon/init.lua` is a symlink into this repo.
Server auto-starts on login via `~/Library/LaunchAgents/com.anki-screenshot-creator.plist`.

## Architecture
```
⌥⇧A keypress (Hammerspoon)
  → GET http://localhost:5789/api/session
  → {active: true}  → screencapture -i → PNG to ~/AnkiScreenshots/incoming/
  → {active: false} → hs.urlevent.openURL("http://localhost:5789")

flask_server.py (launchd, always running)
  → serves web UI at /
  → watchdog thread watches ~/AnkiScreenshots/incoming/
  → on new PNG: reads config, calls models.generate_cards(), adds to AnkiConnect
  → SSE stream at /api/events sends progress + done events to browser

Web UI (localhost:5789)
  → user sets deck, provider, model name, API key, custom prompt
  → POST /api/config saves to ~/.anki-screenshot-creator/config.json (chmod 600)
  → POST /api/session/start sets session_active: true
  → Recent Cards section updates live via SSE
```

## Hotkey Flow
- **⌥⇧A, session inactive** → browser opens to `localhost:5789`
- **⌥⇧A, session active** → screenshot taken immediately (no browser)
- **⌥⇧⌘A** → stops session, reopens browser to reconfigure

## Config Schema (`~/.anki-screenshot-creator/config.json`)
```json
{
  "session_active": false,
  "deck": "Anatomy",
  "model": {
    "provider": "anthropic",
    "model_name": "claude-sonnet-4-6",
    "base_url": null
  },
  "api_keys": {
    "anthropic": "sk-ant-...",
    "openai": "sk-...",
    "groq": "gsk_...",
    "gemini": "AIza..."
  },
  "custom_prompt": ""
}
```
File is `chmod 600`. On first creation, `$ANTHROPIC_API_KEY` env var pre-fills the anthropic key.

## Provider Support
| Provider | api_keys key | Base URL | Notes |
|----------|-------------|----------|-------|
| `anthropic` | anthropic | — | anthropic SDK |
| `openai` | openai | — | openai SDK |
| `groq` | groq | `https://api.groq.com/openai/v1` | openai SDK |
| `gemini` | gemini | `https://generativelanguage.googleapis.com/v1beta/openai/` | openai SDK, key from aistudio.google.com |
| `custom` | — | user-supplied | openai SDK, no key required |

Model name is a free-text field in the UI; defaults per provider: `claude-sonnet-4-6`, `gpt-4o`, `llama-3.3-70b-versatile`, `gemini-2.0-flash`, `""`.

## Web UI Behaviour
- All fields autosave on blur/change to config.json — no explicit save needed
- Last-used deck pre-selected on page load
- "New deck" toggle in the deck field: `+ New` button → text input → Enter to confirm; deck created in Anki when first card is added
- Recent Cards: max 10, shows deck badge + first line of back; cards > 1 hr old dimmed to 45% opacity

## Flask API Endpoints
| Method | Path | Description |
|--------|------|-------------|
| GET | `/` | Serves index.html |
| GET | `/api/decks` | AnkiConnect deckNames proxy |
| GET | `/api/config` | Returns config.json |
| POST | `/api/config` | Saves config.json |
| GET | `/api/session` | Returns `{active, deck}` |
| POST | `/api/session/start` | Sets session_active: true |
| POST | `/api/session/stop` | Sets session_active: false |
| GET | `/api/events` | SSE: progress, done, error, ping events |

## AnkiConnect
- URL: `http://localhost:8765`
- Version: 6
- Test: `curl -s -X POST http://localhost:8765 -d '{"action":"version","version":6}'`

## Known Gotchas
- Anki process name is `python3.x` — detect with `lsof -i :8765`, not `pgrep -x Anki`
- Flask runs with `threaded=True, use_reloader=False` — safe for watchdog thread
- SSE uses per-connection queues broadcast from watchdog thread
- `anki_watcher.py` is now a deprecated stub — don't run it
- Server logs: `tail -f /tmp/anki-screenshot-creator.log`
- Check server: `launchctl list | grep anki`
- Restart server: `launchctl kickstart -k gui/$UID/com.anki-screenshot-creator`

## Recent Changes
- 2026-03-01: Fixed freeze on deck select — switched from `hs.execute` to `hs.task.new`
- 2026-03-02: Moved into monorepo at `~/code/anki_screenshot_creator/`
- 2026-03-02: **Web UI redesign** — replaced hs.chooser with Flask web UI; added launchd agent; multi-provider model support; Hammerspoon simplified to ~30 lines
- 2026-03-02: Added Gemini provider (OpenAI-compat endpoint, no extra SDK)
- 2026-03-02: Renamed `openai_compatible` provider to `custom`
- 2026-03-02: Autosave on blur/change for all config fields; last deck remembered across sessions
- 2026-03-02: "New deck" creation in web UI (no longer needs Hammerspoon chooser)
- 2026-03-02: Recent Cards shows deck badge + back preview; max 10; cards > 1 hr dimmed
