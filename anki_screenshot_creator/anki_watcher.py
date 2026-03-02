import anthropic
import argparse
import base64
import json
import re
import requests
import time
from pathlib import Path
from watchdog.events import FileSystemEventHandler
from watchdog.observers import Observer

# ── Config ────────────────────────────────────────────────────────────────────
SCREENSHOTS_ROOT = Path.home() / "AnkiScreenshots"
ANKICONNECT_URL  = "http://localhost:8765"
# ─────────────────────────────────────────────────────────────────────────────

client = anthropic.Anthropic()

PROMPT_TEMPLATE = """You are an expert at creating Anki flashcards following best practices.

Analyze this textbook screenshot and create Anki flashcards from it.

RULES:
- Each card tests ONE concept. If the back needs more than 2 sentences, split it into multiple cards instead.
- Front: write how a curious student would actually ask it — conversational, not academic. "Why does X cause Y?" not "Describe the mechanism by which X results in Y."
- Front: never use passive voice or academic phrasing. Not "What is the mechanism by which..." or "How is X characterized by..." — just ask it directly.
- Back: 1–2 sentences max, plain english. Use jargon only when the jargon itself is what's being learned. Never use phrases like "as illustrated", "in the context of", or "with respect to".
- If you are tempted to write a back longer than 2 sentences, stop — split it into multiple cards instead.
- For definitions: "What is [term]?" → one plain-english sentence
- For processes/steps: one card per step, written as a natural question
- For cause/effect: "What happens when X?" → short direct answer; add a reverse card if both directions are worth knowing
- For formulas: "What's the formula for [concept]?" → formula + what each variable means
- For lists: cloze-style ("The 3 types of X are: [A], [B], [C]") not one card per item
- Skip trivial or obvious facts
- Generate 1–8 cards depending on content density

EXAMPLES — study these before writing any cards:

BAD: front: "What does this show?" / back: "It shows the process of how neural networks learn through multiple complex mechanisms involving weights and gradients."
GOOD: front: "How does a neural network update its weights?" / back: "It uses backpropagation — nudging each weight based on how much it contributed to the error."

BAD: front: "Describe the role of the hippocampus in memory consolidation." / back: "The hippocampus plays a critical role in the consolidation of information from short-term to long-term memory, as illustrated by studies of patients with hippocampal lesions."
GOOD: front: "Why do hippocampal lesions cause amnesia for new memories?" / back: "The hippocampus converts short-term memories into long-term ones — damage stops that transfer cold."

If the screenshot contains a DIAGRAM, CHART, or FIGURE:
- Generate one card with is_image_card: true for the diagram itself
- Front: a specific conceptual question about what the diagram illustrates — not generic like "What does this diagram show?" but precise enough that someone could answer it cold, e.g. "What is the input/output flow of a multimodal model?" or "How does CLIP training work?"
- Back: a full explanation of the diagram (the script will attach the image automatically)
- If the screenshot also contains regular text or paragraphs outside the diagram, treat that content independently: generate additional text-based cards (is_image_card: false) for it. Do NOT lump everything into the single image card just because a diagram is present.

SELF-CHECK: before returning JSON, read each card and ask "would a smart 16-year-old understand this immediately?" If not, rewrite it until they would.

Return ONLY valid JSON in this exact format, no other text:
{
  "cards": [
    {
      "front": "question text",
      "back": "answer text",
      "tags": ["tag1", "tag2"],
      "is_image_card": false
    }
  ]
}

Tags should reflect the topic (e.g. "anatomy", "biochemistry", "chapter-3").
For image cards set is_image_card to true."""


def encode_image(image_path: str) -> str:
    with open(image_path, "rb") as f:
        return base64.standard_b64encode(f.read()).decode("utf-8")


def generate_cards(image_path: str) -> list[dict]:
    b64 = encode_image(image_path)
    message = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=2000,
        messages=[
            {
                "role": "user",
                "content": [
                    {
                        "type": "image",
                        "source": {"type": "base64", "media_type": "image/png", "data": b64},
                    },
                    {"type": "text", "text": PROMPT_TEMPLATE},
                ],
            }
        ],
    )
    raw = message.content[0].text.strip()
    raw = re.sub(r"^```(?:json)?\s*|\s*```$", "", raw, flags=re.MULTILINE).strip()
    data = json.loads(raw)
    return data.get("cards", [])


def ankiconnect(action: str, **params):
    payload = json.dumps({"action": action, "version": 6, "params": params})
    response = requests.post(ANKICONNECT_URL, data=payload)
    result = response.json()
    if result.get("error"):
        raise Exception(f"AnkiConnect error: {result['error']}")
    return result["result"]


def ensure_anki_deck(deck_name: str):
    existing = ankiconnect("deckNames")
    if deck_name not in existing:
        ankiconnect("createDeck", deck=deck_name)
        print(f"  🗂️  Created Anki deck: '{deck_name}'")


def store_image_in_anki(image_path: str) -> str:
    filename = Path(image_path).name
    b64 = encode_image(image_path)
    ankiconnect("storeMediaFile", filename=filename, data=b64)
    return filename


def add_cards_to_anki(cards: list[dict], image_path: str, deck: str, mode_tag: str):
    added = 0
    for card in cards:
        back = card["back"]
        if card.get("is_image_card"):
            img_filename = store_image_in_anki(image_path)
            back += f'<br><img src="{img_filename}">'

        tags = list(set(card.get("tags", []) + [mode_tag]))

        note = {
            "deckName": deck,
            "modelName": "Basic",
            "fields": {"Front": card["front"], "Back": back},
            "tags": tags,
            "options": {"allowDuplicate": False},
        }

        try:
            ankiconnect("addNote", note=note)
            added += 1
        except Exception as e:
            if "duplicate" in str(e).lower():
                print(f"  ↷ Skipped duplicate: {card['front'][:60]}")
            else:
                raise

    print(f"  ✓ Added {added}/{len(cards)} cards to deck '{deck}'")


class ScreenshotHandler(FileSystemEventHandler):
    def __init__(self, deck: str, mode_tag: str):
        self.deck     = deck
        self.mode_tag = mode_tag

    def on_created(self, event):
        if event.is_directory or not event.src_path.endswith(".png"):
            return
        path = event.src_path
        time.sleep(0.5)
        print(f"\n📸 New screenshot: {Path(path).name}")
        try:
            print("  🤖 Generating cards with Claude...")
            cards = generate_cards(path)
            print(f"  📝 {len(cards)} card(s) generated")
            add_cards_to_anki(cards, path, self.deck, self.mode_tag)
        except Exception as e:
            print(f"  ✗ Error: {e}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Anki screenshot watcher")
    parser.add_argument(
        "--mode",
        default="default",
        help="Subject name (e.g. anatomy, biochem). Creates the folder and Anki deck automatically."
    )
    args = parser.parse_args()

    mode      = args.mode.lower().strip()
    folder    = SCREENSHOTS_ROOT / "incoming"
    deck_name = mode.capitalize()

    folder.mkdir(parents=True, exist_ok=True)
    ensure_anki_deck(deck_name)

    print(f"👁  Mode     : {mode}")
    print(f"📁  Folder   : {folder}  (shared inbox)")
    print(f"📚  Deck     : {deck_name}")
    print(f"🏷️  Tag      : {mode}")
    print(f"\n   Make sure Anki is open with AnkiConnect running.\n")

    observer = Observer()
    observer.schedule(ScreenshotHandler(deck_name, mode), str(folder), recursive=False)
    observer.start()
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
    observer.join()
