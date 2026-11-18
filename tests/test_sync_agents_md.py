import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from sync_agents_md import END, has_block, remove  # noqa: E402


def test_removes_the_block_and_keeps_project_content():
    src = ("# AGENTS.md — X\n\n> Intro\n\n<!-- factory-standards:begin v2.0.0 -->\n"
           "## Factory standard\n\nRule one.\n" f"{END}\n\n## What this is\n\nProject text.\n")
    out = remove(src)
    assert "Rule one." not in out and "factory-standards:begin" not in out
    assert "> Intro" in out and "Project text." in out
    assert out.index("> Intro") < out.index("## What this is")


def test_removes_a_placeholder_block_from_the_old_template():
    src = ("# T\n\n<!-- factory-standards:begin -->\n<!-- placeholder -->\n"
           f"{END}\n\n## Project\n")
    out = remove(src)
    assert "placeholder" not in out and "## Project" in out


def test_idempotent():
    src = "# T\n\n<!-- factory-standards:begin v0.1.0 -->\nx\n" f"{END}\n\nbody\n"
    once = remove(src)
    assert remove(once) == once
    assert not has_block(once)


def test_unterminated_block_is_an_error():
    with pytest.raises(ValueError):
        remove("# T\n<!-- factory-standards:begin v0.1.0 -->\nno end\n")


def test_file_without_a_block_is_unchanged():
    src = "# T\n\n## Project\n\nmine\n"
    assert remove(src) == src
