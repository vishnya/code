import pytest
from unittest.mock import MagicMock, patch

import flask_server
from flask_server import ScreenshotHandler


def make_event(path, is_directory=False):
    event = MagicMock()
    event.src_path = path
    event.is_directory = is_directory
    return event


def test_ignores_directory_event():
    handler = ScreenshotHandler()
    event = make_event("/some/dir", is_directory=True)
    with patch("flask_server.cfg") as mock_cfg:
        handler.on_created(event)
        mock_cfg.load.assert_not_called()


def test_ignores_non_png():
    handler = ScreenshotHandler()
    event = make_event("/some/file.jpg")
    with patch("flask_server.cfg") as mock_cfg:
        handler.on_created(event)
        mock_cfg.load.assert_not_called()


def test_ignores_when_session_inactive(tmp_config):
    handler = ScreenshotHandler()
    event = make_event("/some/file.png")
    conf = dict(tmp_config)
    conf["session_active"] = False

    with patch("flask_server.cfg.load", return_value=conf), \
         patch("flask_server.models.generate_cards") as mock_gen, \
         patch("time.sleep"):
        handler.on_created(event)
        mock_gen.assert_not_called()


def test_error_when_no_deck(tmp_config):
    handler = ScreenshotHandler()
    event = make_event("/some/file.png")
    conf = dict(tmp_config)
    conf["session_active"] = True
    conf["deck"] = ""

    pushed_events = []
    with patch("flask_server.cfg.load", return_value=conf), \
         patch("flask_server._push_event", side_effect=pushed_events.append), \
         patch("time.sleep"):
        handler.on_created(event)

    assert any(
        e.get("type") == "error" and "No deck" in e.get("message", "")
        for e in pushed_events
    )


def test_processes_png_full_flow(tmp_config, tiny_png):
    handler = ScreenshotHandler()
    event = make_event(tiny_png)
    conf = dict(tmp_config)
    conf["session_active"] = True
    conf["deck"] = "TestDeck"

    fake_cards = [
        {"front": "Q1", "back": "A1", "tags": [], "is_image_card": False},
        {"front": "Q2", "back": "A2", "tags": [], "is_image_card": False},
    ]

    def ankiconnect_side_effect(action, **params):
        if action == "deckNames":
            return ["TestDeck"]
        if action == "addNote":
            return 12345
        return None

    pushed_events = []
    with patch("flask_server.cfg.load", return_value=conf), \
         patch("flask_server.models.generate_cards", return_value=fake_cards), \
         patch("flask_server._ankiconnect", side_effect=ankiconnect_side_effect), \
         patch("flask_server._push_event", side_effect=pushed_events.append), \
         patch("time.sleep"):
        handler.on_created(event)

    done_events = [e for e in pushed_events if e.get("type") == "done"]
    assert len(done_events) == 1
    assert "2" in done_events[0]["message"]
    assert len(flask_server._recent_cards) == 2
