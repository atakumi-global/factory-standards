#!/usr/bin/env python3
"""Delete an old copied factory-standard section from a repository's AGENTS.md.

The standard is installed with the agent runtime and loaded into every session, so a
repository does not carry a copy any more. Older repositories have one between markers:

    <!-- factory-standards:begin vX.Y.Z -->
    ...
    <!-- factory-standards:end -->

This tool removes that section and leaves everything outside it untouched.

Usage:
    sync_agents_md.py [--target AGENTS.md] [--check]

--check writes nothing. It exits 1 only when the markers are malformed (a begin with no
end); an intact old section is reported and left alone, because it is harmless.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

BEGIN_RE = re.compile(r"<!-- factory-standards:begin(?: v[^ ]+)? -->")
END = "<!-- factory-standards:end -->"


def has_block(text: str) -> bool:
    return BEGIN_RE.search(text) is not None


def remove(text: str) -> str:
    """Delete the marked section, if any, and tidy the blank lines around it."""
    m = BEGIN_RE.search(text)
    if m is None:
        return text
    end = text.find(END, m.end())
    if end == -1:
        raise ValueError("found factory-standards:begin without a matching end marker")
    before = text[: m.start()].rstrip("\n")
    after = text[end + len(END):].lstrip("\n")
    if before and after:
        out = before + "\n\n" + after
    else:
        out = before + after
    return re.sub(r"\n{3,}", "\n\n", out).rstrip("\n") + "\n"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--target", default="AGENTS.md")
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()

    target = Path(a.target)
    if not target.exists():
        print(f"{target}: not found")
        return 0
    current = target.read_text()
    try:
        updated = remove(current)
    except ValueError as e:
        print(f"{target}: {e}", file=sys.stderr)
        return 1
    if updated == current:
        print(f"{target}: no copied factory-standard section")
        return 0
    if a.check:
        print(f"{target}: old copied factory-standard section present "
              "(harmless; delete it when you next edit the file)")
        return 0
    target.write_text(updated)
    print(f"{target}: removed the old copied factory-standard section")
    return 0


if __name__ == "__main__":
    sys.exit(main())
