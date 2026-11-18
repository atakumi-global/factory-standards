"""The dependency rule is stated where the lead and workers read it."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def test_shared_lifecycle_has_the_rule():
    text = (ROOT / "agents" / "AGENTS.shared.md").read_text(encoding="utf-8")
    assert "A dependency on another" in text
    assert "Depends on: <ITEM-ID>" in text
    assert "is never Blocked" in text


def test_lead_records_a_dependency_instead_of_blocking():
    text = (ROOT / "agents" / "lead.md").read_text(encoding="utf-8")
    assert "Depends on: <ITEM-ID>" in text
    assert "set the factory item Blocked with that reason" not in text
    assert "waits until every dependency is Approved" in text


def test_worker_records_a_dependency():
    text = (ROOT / "agents" / "worker.md").read_text(encoding="utf-8")
    assert "Depends on: <ITEM-ID>" in text
