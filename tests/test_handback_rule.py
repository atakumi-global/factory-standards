"""The handback rule: evidence in the knowledge base, the broker enforces it (INTFACTORY-46)."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def shared() -> str:
    return (ROOT / "agents" / "AGENTS.shared.md").read_text(encoding="utf-8")


def test_the_report_is_the_knowledge_base_evidence_file():
    text = shared()
    assert "**The report is the evidence file" in text
    assert "log/YYYY-MM-DD-<ITEM-ID>.md" in text
    assert "The tester's guide is not duplicated there" in text


def test_the_plane_handback_is_short_and_links_the_evidence():
    text = shared()
    assert "### Handback in Plane (required)" in text
    assert "One absolute GitHub link to the evidence file" in text
    assert "over 1500 characters" in text
    assert "the newest comment" in text


def test_the_worker_posts_the_guide_then_the_handback():
    text = (ROOT / "agents" / "worker.md").read_text(encoding="utf-8")
    assert "Tester's guide in Plane first" in text
    assert "Handback in Plane, last" in text
    assert "push the evidence" in text and "file before the handback" in text


def test_the_lead_checks_the_resolving_link():
    text = (ROOT / "agents" / "lead.md").read_text(encoding="utf-8")
    assert "handback as its newest comment with a link that resolves" in text
