"""The end-of-run report is two layers and terse (INTFACTORY-28).

Locks the required shape in agents/AGENTS.shared.md so a later edit cannot quietly bring
back the scanner-by-scanner narrative or the diff restatement.
"""
from pathlib import Path

SHARED = (Path(__file__).resolve().parents[1] / "agents" / "AGENTS.shared.md").read_text(
    encoding="utf-8"
)


def report_section() -> str:
    start = SHARED.index("### End-of-run report (required)")
    rest = SHARED[start:]
    end = rest.find("\n### ", 1)
    return rest if end == -1 else rest[:end]


def test_report_has_two_layers():
    text = report_section()
    assert "**Activity log.**" in text
    assert "**Manager summary.**" in text


def test_activity_log_is_short_bullets_without_diff_narration():
    text = report_section()
    assert "Short bullets" in text
    assert "restates the diff" in text


def test_passing_checks_are_one_line():
    text = report_section()
    assert "### factory-check — pass" in text
    assert "only when one fails" in text


def test_human_action_names_the_action_only_and_says_where_a_sample_runs():
    text = report_section()
    assert "* **Coolify redeploy after merge.**" in text
    assert "copy-paste" in text


def test_repo_state_is_terse_and_has_no_artifacts():
    text = report_section()
    assert "Repo state: none changed." in text
    assert "temp" in text and "tool artifacts" in text
