import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from sync_agents_md import END, sync  # noqa: E402

SHARED = "## Factory standard (shared)\n\nRule one.\n"


def test_inserts_after_title_and_intro_keeping_project_content():
    src = "# AGENTS.md — X\n\n> Intro line\n> more\n\n## What this is\n\nProject text.\n"
    out = sync(src, SHARED, "0.1.0")
    assert out.index("> more") < out.index("factory-standards:begin v0.1.0")
    assert out.index(END) < out.index("## What this is")
    assert "Project text." in out


def test_replaces_existing_block_only():
    src = sync("# T\n\n## Project\n\nmine\n", SHARED, "0.1.0")
    out = sync(src, "## Factory standard (shared)\n\nRule two.\n", "0.2.0")
    assert "Rule two." in out and "Rule one." not in out
    assert "begin v0.2.0" in out and out.count(END) == 1
    assert out.endswith("mine\n")


def test_idempotent():
    once = sync("# T\n\nbody\n", SHARED, "0.1.0")
    assert sync(once, SHARED, "0.1.0") == once


def test_template_placeholder_markers_are_replaced():
    src = ("# T\n\n<!-- factory-standards:begin -->\n<!-- placeholder -->\n"
           f"{END}\n\n## Project\n")
    out = sync(src, SHARED, "0.1.0")
    assert "placeholder" not in out and "Rule one." in out


def test_unterminated_block_is_an_error():
    with pytest.raises(ValueError):
        sync("# T\n<!-- factory-standards:begin v0.1.0 -->\nno end\n", SHARED, "0.1.0")


def test_no_title_inserts_at_top():
    out = sync("Some text\n", SHARED, "0.1.0")
    assert out.startswith("<!-- factory-standards:begin")
