"""Every described action carries the machine, the path or URL, and the command."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def test_shared_communication_requires_the_three_parts():
    text = (ROOT / "agents" / "AGENTS.shared.md").read_text(encoding="utf-8")
    assert "machine or system" in text
    assert "full path or full URL" in text
    assert "exact command or clicks" in text
    assert "A step without all three is incomplete" in text
