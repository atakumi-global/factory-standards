"""The standard is delivered by the runtime, not copied into a repository."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def test_shared_header_says_it_is_installed_and_loaded():
    text = (ROOT / "agents" / "AGENTS.shared.md").read_text(encoding="utf-8")
    assert "installed with the agent runtime" in text
    assert "not copied into repositories" in text
    assert "ignore it" in text


def test_template_has_no_copied_section():
    text = (ROOT / "templates" / "AGENTS.md").read_text(encoding="utf-8")
    assert "factory-standards:begin" not in text
    assert "installed with the agent runtime" in text


def test_readme_states_one_install_per_server():
    text = (ROOT / "README.md").read_text(encoding="utf-8")
    flat = " ".join(text.split())
    assert "one install on the agent server and no commit in any repository" in flat
