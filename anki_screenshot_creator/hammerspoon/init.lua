-- Enable CLI access (hs -c "...")
require("hs.ipc")

-- Ensure incoming folder exists
os.execute("mkdir -p " .. os.getenv("HOME") .. "/AnkiScreenshots/incoming")

-- Current active deck mode. nil = not set yet; once set, ⌥⇧A goes straight to screenshot.
-- Reload Hammerspoon config to reset (e.g. to switch decks).
local currentMode = nil

local function ankiConnectReachable()
  -- hs.http.post returns (statusCode, body, headers)
  local code = hs.http.post("http://localhost:8765",
    '{"action":"version","version":6}',
    {["Content-Type"] = "application/json"})
  return code == 200
end

local function getAnkiDecks()
  local code, response = hs.http.post("http://localhost:8765",
    '{"action":"deckNames","version":6}',
    {["Content-Type"] = "application/json"})
  if code == 200 then
    local ok, result = pcall(hs.json.decode, response)
    if ok and result and result.result then
      return result.result
    end
  end
  return {}
end

local function takeScreenshot()
  local home = os.getenv("HOME")
  local timestamp = os.date("%Y%m%d_%H%M%S")
  local path = home .. "/AnkiScreenshots/incoming/screenshot_" .. timestamp .. ".png"
  hs.task.new("/usr/sbin/screencapture", nil, {"-i", path}):start()
end

local function openTerminalWithAnki(mode)
  hs.task.new("/usr/bin/osascript", nil, {"-e", 'tell application "Terminal" to do script "anki ' .. mode .. '"'}):start()
end

-- Module-level so the chooser isn't garbage-collected before the callback fires
local ankiChooser = nil

local function showDeckChooser()
  local decks = getAnkiDecks()
  local choices = {}
  for _, deck in ipairs(decks) do
    table.insert(choices, {text = deck})
  end
  table.insert(choices, {text = "Create new deck..."})

  ankiChooser = hs.chooser.new(function(choice)
    if not choice then return end

    local mode
    if choice.text == "Create new deck..." then
      local button, name = hs.dialog.textPrompt("New deck", "Enter a name for the new deck:", "", "Start", "Cancel")
      if button ~= "Start" or name == "" then return end
      mode = name:lower()
    else
      -- "Anatomy" → "anatomy", "Textbook::Anatomy" → "anatomy"
      mode = (choice.text:match("::(.+)$") or choice.text):lower()
    end

    currentMode = mode
    openTerminalWithAnki(mode)
    hs.alert.show("Deck: " .. mode .. " — ⌥⇧A will now screenshot")
    hs.timer.doAfter(1, takeScreenshot)
  end)

  ankiChooser:choices(choices)
  ankiChooser:show()
end

local function waitForAnkiThenChoose(triesLeft)
  if ankiConnectReachable() then
    showDeckChooser()
  elseif triesLeft > 0 then
    hs.timer.doAfter(1, function() waitForAnkiThenChoose(triesLeft - 1) end)
  else
    hs.alert.show("AnkiConnect unreachable after 15s — is the add-on installed?")
  end
end

-- ⌥⇧A behaviour:
--   deck already selected  → screenshot immediately
--   no deck, Anki open     → show deck chooser
--   no deck, Anki closed   → open Anki, wait for AnkiConnect, show deck chooser
hs.hotkey.bind({"alt", "shift"}, "a", function()
  if currentMode ~= nil then
    if ankiConnectReachable() then
      takeScreenshot()
    else
      -- Anki was closed since deck was chosen; reopen it and restart watcher
      hs.execute("open -a Anki")
      local function waitThenScreenshot(triesLeft)
        if ankiConnectReachable() then
          openTerminalWithAnki(currentMode)
          hs.timer.doAfter(1, takeScreenshot)
        elseif triesLeft > 0 then
          hs.timer.doAfter(1, function() waitThenScreenshot(triesLeft - 1) end)
        else
          hs.alert.show("AnkiConnect unreachable after 15s — is the add-on installed?")
        end
      end
      hs.timer.doAfter(1, function() waitThenScreenshot(14) end)
    end
    return
  end

  if ankiConnectReachable() then
    showDeckChooser()
  else
    hs.execute("open -a Anki")
    hs.timer.doAfter(1, function() waitForAnkiThenChoose(14) end)
  end
end)

-- ⌥⇧⌘A: reset deck selection and show chooser immediately
hs.hotkey.bind({"alt", "shift", "cmd"}, "a", function()
  currentMode = nil
  if ankiConnectReachable() then
    showDeckChooser()
  else
    hs.execute("open -a Anki")
    hs.timer.doAfter(1, function() waitForAnkiThenChoose(14) end)
  end
end)

hs.alert.show("Hammerspoon loaded — ⌥⇧A ready")
