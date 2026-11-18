"""The answer rule is stated where the lead and workers read it."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def test_shared_lifecycle_resumes_an_answered_item():
    text = (ROOT / "agents" / "AGENTS.shared.md").read_text(encoding="utf-8")
    assert "next run resumes the item by itself" in text


def test_lead_resumes_an_answered_blocked_item():
    text = (ROOT / "agents" / "lead.md").read_text(encoding="utf-8")
    assert "marked `answered`" in text
    assert "move it" in text and "to In Progress and brief a worker" in text


def test_worker_does_not_ask_to_be_moved_back():
    text = (ROOT / "agents" / "worker.md").read_text(encoding="utf-8")
    assert "next run resumes it" in text
