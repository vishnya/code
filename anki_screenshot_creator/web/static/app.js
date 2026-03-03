// ── Constants ──────────────────────────────────────────────────────────────────
const MODEL_DEFAULTS = {
  anthropic:         { name: "claude-sonnet-4-6",        apiKeyLabel: "Anthropic API Key",  hasKey: true,  hasUrl: false },
  openai:            { name: "gpt-4o",                   apiKeyLabel: "OpenAI API Key",     hasKey: true,  hasUrl: false },
  groq:              { name: "llama-3.3-70b-versatile",  apiKeyLabel: "Groq API Key",       hasKey: true,  hasUrl: false },
  gemini:            { name: "gemini-2.0-flash",         apiKeyLabel: "Gemini API Key",     hasKey: true,  hasUrl: false },
  custom:            { name: "",                         apiKeyLabel: "",                   hasKey: false, hasUrl: true  },
};

// ── DOM refs ───────────────────────────────────────────────────────────────────
const deckSelect      = document.getElementById("deck");
const deckRow         = document.getElementById("deck-row");
const btnNewDeck      = document.getElementById("btn-new-deck");
const deckNewRow      = document.getElementById("deck-new-row");
const deckNewInput    = document.getElementById("deck-new-input");
const btnCancelDeck   = document.getElementById("btn-cancel-deck");
const providerSelect  = document.getElementById("provider");
const modelNameInput  = document.getElementById("model-name");
const apiKeyField     = document.getElementById("field-api-key");
const apiKeyInput     = document.getElementById("api-key");
const apiKeyLabel     = document.getElementById("api-key-label");
const baseUrlField    = document.getElementById("field-base-url");
const baseUrlInput    = document.getElementById("base-url");
const promptInput     = document.getElementById("custom-prompt");
const startBtn        = document.getElementById("btn-start");
const stopBtn         = document.getElementById("btn-stop");
const statusBanner    = document.getElementById("status-banner");
const statusText      = document.getElementById("status-text");
const cardsList       = document.getElementById("cards-list");
const toast           = document.getElementById("toast");

// ── State ──────────────────────────────────────────────────────────────────────
let config        = null;
let sessionActive = false;

// ── Init ───────────────────────────────────────────────────────────────────────
async function init() {
  await Promise.all([loadConfig(), loadDecks()]);
  connectSSE();
}

async function loadConfig() {
  const res  = await fetch("/api/config");
  config     = await res.json();
  sessionActive = config.session_active;

  providerSelect.value = config.model?.provider || "anthropic";
  modelNameInput.value = config.model?.model_name || "";
  baseUrlInput.value   = config.model?.base_url   || "";
  promptInput.value    = config.custom_prompt || "";

  const provider = config.model?.provider || "anthropic";
  apiKeyInput.value = config.api_keys?.[provider] || "";

  updateProviderUI(provider, false);
  updateSessionUI();
}

async function loadDecks() {
  try {
    const res   = await fetch("/api/decks");
    const decks = await res.json();
    if (Array.isArray(decks)) {
      deckSelect.innerHTML = '<option value="">— choose deck —</option>';
      decks.forEach(d => {
        const opt = document.createElement("option");
        opt.value = d;
        opt.textContent = d;
        deckSelect.appendChild(opt);
      });
      // If saved deck isn't in Anki yet (e.g. typed manually), add it
      if (config?.deck) {
        if (![...deckSelect.options].some(o => o.value === config.deck)) {
          const opt = document.createElement("option");
          opt.value = config.deck;
          opt.textContent = config.deck;
          deckSelect.appendChild(opt);
        }
        deckSelect.value = config.deck;
      }
    } else {
      deckSelect.innerHTML = '<option value="">Anki not reachable</option>';
    }
  } catch {
    deckSelect.innerHTML = '<option value="">Anki not reachable</option>';
  }
}

// ── Autosave ───────────────────────────────────────────────────────────────────
async function saveConfig() {
  if (sessionActive) return;
  const provider = providerSelect.value;
  const body = {
    deck:          deckSelect.value,
    model: {
      provider,
      model_name: modelNameInput.value.trim(),
      base_url:   provider === "custom" ? baseUrlInput.value.trim() : null,
    },
    api_keys:      { ...(config?.api_keys || {}), [provider]: apiKeyInput.value.trim() },
    custom_prompt: promptInput.value.trim(),
  };
  await fetch("/api/config", { method: "POST", body: JSON.stringify(body), headers: { "Content-Type": "application/json" } });
  config = { ...config, ...body };
}

[apiKeyInput, baseUrlInput, modelNameInput, promptInput].forEach(el => {
  el.addEventListener("blur", saveConfig);
});
deckSelect.addEventListener("change", saveConfig);

// ── Provider UI ────────────────────────────────────────────────────────────────
function updateProviderUI(provider, resetName) {
  const meta = MODEL_DEFAULTS[provider] || MODEL_DEFAULTS.anthropic;

  if (resetName) {
    modelNameInput.value = meta.name;
    apiKeyInput.value = config?.api_keys?.[provider] || "";
  }

  if (meta.hasKey) {
    apiKeyField.classList.remove("hidden");
    apiKeyLabel.textContent = meta.apiKeyLabel;
  } else {
    apiKeyField.classList.add("hidden");
  }

  if (meta.hasUrl) {
    baseUrlField.classList.remove("hidden");
  } else {
    baseUrlField.classList.add("hidden");
  }
}

providerSelect.addEventListener("change", () => {
  updateProviderUI(providerSelect.value, true);
  saveConfig();
});

// ── New deck ───────────────────────────────────────────────────────────────────
btnNewDeck.addEventListener("click", () => {
  deckRow.classList.add("hidden");
  deckNewRow.classList.remove("hidden");
  deckNewInput.focus();
});

function confirmNewDeck() {
  const name = deckNewInput.value.trim();
  if (name) {
    if (![...deckSelect.options].some(o => o.value === name)) {
      const opt = document.createElement("option");
      opt.value = name;
      opt.textContent = name;
      deckSelect.appendChild(opt);
    }
    deckSelect.value = name;
    saveConfig();
  }
  deckNewInput.value = "";
  deckRow.classList.remove("hidden");
  deckNewRow.classList.add("hidden");
}

deckNewInput.addEventListener("keydown", (e) => {
  if (e.key === "Enter")  { e.preventDefault(); confirmNewDeck(); }
  if (e.key === "Escape") {
    deckNewInput.value = "";
    deckRow.classList.remove("hidden");
    deckNewRow.classList.add("hidden");
  }
});

// blur fires before the cancel button click — small delay lets the click win
deckNewInput.addEventListener("blur", () => setTimeout(confirmNewDeck, 150));

btnCancelDeck.addEventListener("click", () => {
  deckNewInput.value = "";
  deckRow.classList.remove("hidden");
  deckNewRow.classList.add("hidden");
});

// ── Session UI ─────────────────────────────────────────────────────────────────
function updateSessionUI() {
  if (sessionActive) {
    startBtn.classList.add("hidden");
    stopBtn.classList.remove("hidden");
    statusBanner.className = "status-banner active";
    statusBanner.classList.remove("hidden");
    statusBanner.querySelector(".status-dot").classList.add("pulse");
    statusText.textContent = `Session active — press ⌥⇧A to screenshot (deck: ${config?.deck || "?"})`;
    setFormDisabled(true);
  } else {
    startBtn.classList.remove("hidden");
    stopBtn.classList.add("hidden");
    statusBanner.classList.add("hidden");
    setFormDisabled(false);
  }
}

function setFormDisabled(disabled) {
  [deckSelect, providerSelect, modelNameInput, apiKeyInput, baseUrlInput, promptInput, btnNewDeck]
    .forEach(el => { el.disabled = disabled; });
}

// ── Save & Start ───────────────────────────────────────────────────────────────
startBtn.addEventListener("click", async () => {
  const provider = providerSelect.value;
  const deck     = deckSelect.value;

  if (!deck) { showToast("Choose a deck first"); return; }

  const body = {
    deck,
    model: {
      provider,
      model_name: modelNameInput.value.trim(),
      base_url:   provider === "custom" ? baseUrlInput.value.trim() : null,
    },
    api_keys:      { ...(config?.api_keys || {}), [provider]: apiKeyInput.value.trim() },
    custom_prompt: promptInput.value.trim(),
  };

  await fetch("/api/config", { method: "POST", body: JSON.stringify(body), headers: { "Content-Type": "application/json" } });
  const res  = await fetch("/api/session/start", { method: "POST" });
  const data = await res.json();

  if (data.ok) {
    config = { ...config, ...body, session_active: true };
    sessionActive = true;
    updateSessionUI();
  }
});

stopBtn.addEventListener("click", async () => {
  await fetch("/api/session/stop", { method: "POST" });
  sessionActive = false;
  config = { ...config, session_active: false };
  updateSessionUI();
});

// ── SSE ────────────────────────────────────────────────────────────────────────
function connectSSE() {
  const es = new EventSource("/api/events");

  es.onmessage = (e) => {
    const event = JSON.parse(e.data);

    if (event.type === "ping")    return;
    if (event.type === "recent")  { renderCards(event.cards); return; }
    if (event.type === "done")    { showToast(event.message); if (event.cards?.length) prependCards(event.cards); return; }
    if (event.type === "error")   { showToast("Error: " + event.message, true); return; }
    if (event.type === "progress") showToast(event.message);
  };
}

// ── Recent cards ───────────────────────────────────────────────────────────────
function renderCards(cards) {
  cardsList.innerHTML = "";
  if (!cards.length) {
    cardsList.innerHTML = '<li class="empty-state">No cards yet this session</li>';
    return;
  }
  cards.forEach(c => cardsList.appendChild(buildCardLi(c)));
}

function prependCards(cards) {
  if (cardsList.querySelector(".empty-state")) cardsList.innerHTML = "";
  const deck = config?.deck || "";
  cards.forEach(c => {
    cardsList.prepend(buildCardLi({ front: c.front, back: c.back, deck, ts: Date.now() / 1000 }));
  });
  while (cardsList.children.length > 10) cardsList.removeChild(cardsList.lastChild);
}

function buildCardLi(c) {
  const li = document.createElement("li");

  // Dim cards older than an hour
  if (Date.now() / 1000 - c.ts > 3600) li.classList.add("card-old");

  // Row 1: question + timestamp
  const top = document.createElement("div");
  top.className = "card-top";

  const front = document.createElement("span");
  front.className   = "card-front";
  front.textContent = c.front;

  const ts = document.createElement("span");
  ts.className   = "card-ts";
  ts.textContent = reltime(c.ts);

  top.appendChild(front);
  top.appendChild(ts);
  li.appendChild(top);

  // Row 2: back preview + deck badge
  if (c.back || c.deck) {
    const meta = document.createElement("div");
    meta.className = "card-meta";

    if (c.back) {
      const back = document.createElement("span");
      back.className   = "card-back";
      back.textContent = c.back.split("\n")[0];
      meta.appendChild(back);
    }

    if (c.deck) {
      const deckEl = document.createElement("span");
      deckEl.className   = "card-deck";
      deckEl.textContent = c.deck;
      meta.appendChild(deckEl);
    }

    li.appendChild(meta);
  }

  return li;
}

function reltime(ts) {
  const secs = Math.floor(Date.now() / 1000 - ts);
  if (secs < 60)   return "just now";
  if (secs < 3600) return `${Math.floor(secs / 60)} min ago`;
  return `${Math.floor(secs / 3600)} hr ago`;
}

// ── Toast ──────────────────────────────────────────────────────────────────────
let toastTimer = null;
function showToast(msg, isError = false) {
  toast.textContent = msg;
  toast.style.borderColor = isError ? "var(--red)" : "var(--border)";
  toast.classList.add("show");
  if (toastTimer) clearTimeout(toastTimer);
  toastTimer = setTimeout(() => toast.classList.remove("show"), 3000);
}

// ── Boot ───────────────────────────────────────────────────────────────────────
init();
