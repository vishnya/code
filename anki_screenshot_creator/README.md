# anki-screenshot-creator

Take a screenshot of anything — a textbook, slide, diagram — and get Anki flashcards automatically. Works with Claude, GPT-4o, Groq, or any local model.

## Requirements

- macOS
- [Anki](https://apps.ankiweb.net) installed
- An API key for your chosen provider (or a local model via Ollama/LM Studio)

Everything else (Hammerspoon, AnkiConnect, Python dependencies, background server) is handled by the install script.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/vishnya/anki-screenshot-creator/main/install.sh | bash
```

The script:
- Installs Hammerspoon (via Homebrew)
- Installs Python dependencies (`flask`, `anthropic`, `openai`, `watchdog`, `Pillow`, `requests`)
- Opens Anki and walks you through adding the AnkiConnect add-on (code: `2055492159`)
- Sets up a launchd agent so the server starts automatically on login

## Usage

| Hotkey | Action |
|--------|--------|
| `⌥⇧A` | Session active: takes screenshot. No session: opens config page. |
| `⌥⇧⌘A` | Stop session and reopen config page (switch decks/subjects). |

**Workflow:**
1. Press `⌥⇧A` — browser opens to `http://localhost:5789`
2. Choose a deck, pick your model, add your API key, click **Start Session**
3. Press `⌥⇧A` — drag to select any region of your screen
4. Cards appear in Anki within ~10 seconds
5. Watch them populate in the **Recent Cards** panel on the page

## Model support

Configure everything in the web UI — no decisions needed at install time:

| Provider | Examples | Notes |
|----------|---------|-------|
| Anthropic | `claude-sonnet-4-6`, `claude-opus-4-6` | Default |
| OpenAI | `gpt-4o`, `gpt-4-turbo` | Needs OpenAI key |
| Groq | `llama-3.3-70b-versatile` | Free tier available |
| Gemini | `gemini-2.0-flash`, `gemini-1.5-pro` | Key from [aistudio.google.com](https://aistudio.google.com) |
| Custom endpoint | Any Ollama/LM Studio model | Enter base URL, e.g. `http://localhost:11434/v1` |

The **Model name** field (next to the Provider dropdown) controls which specific model is used — change it to `claude-opus-4-6`, `gpt-4-turbo`, etc. at any time. Settings autosave on blur.

## Config

Settings (deck, model, API key, custom prompt) are saved to `~/.anki-screenshot-creator/config.json` with `chmod 600` and autosaved on blur — no explicit save step needed. The last-used deck is remembered and pre-selected on next visit. If `$ANTHROPIC_API_KEY` is set in your environment, it pre-fills on first run.

## Server logs

```bash
tail -f /tmp/anki-screenshot-creator.log
```

## Claude `/anki` skill

If you use [Claude Code](https://claude.ai/code), there's a `/anki` slash command that loads full project context. The install script adds it automatically.

## How it works

```
⌥⇧A keypress (Hammerspoon)
  → GET /api/session → session active?
  → yes: screencapture -i → saves PNG to ~/AnkiScreenshots/incoming/
  → no:  opens http://localhost:5789 in browser

flask_server.py (launchd background process, port 5789)
  → serves web UI at /
  → watchdog thread detects new PNG in incoming/
  → calls models.py → Claude/GPT/Groq/Gemini/Ollama generates cards
  → AnkiConnect HTTP API (localhost:8765) adds cards to Anki
  → SSE stream pushes progress to browser
```

## Uninstall

```bash
bash ~/anki-screenshot-creator/uninstall.sh
```

Stops and removes the launchd agent, removes symlinks and the shell function. Prompts before deleting the repo.

## Files

```
flask_server.py       # Flask app: API endpoints + watchdog thread
config.py             # Read/write ~/.anki-screenshot-creator/config.json
models.py             # Provider abstraction: Anthropic / OpenAI / Groq / Gemini / custom
anki.zsh              # anki() shell function (sourced by ~/.zshrc)
hammerspoon/
  init.lua            # Hotkey: checks session via GET /api/session
web/
  templates/
    index.html        # Config + session UI
  static/
    style.css         # Dark theme
    app.js            # Deck fetch, config save, session control, SSE cards
launchd/
  com.anki-screenshot-creator.plist   # launchd template (install.sh fills in paths)
claude/
  anki.md             # /anki Claude Code skill
CONTEXT.md            # Living architecture doc, updated each Claude session
install.sh            # One-step installer
uninstall.sh          # Removes everything install.sh added
```
