#!/usr/bin/env python3
"""Insert or refresh the shared factory section in a repository's AGENTS.md.

The shared section lives between two markers:

    <!-- factory-standards:begin vX.Y.Z -->
    ...
    <!-- factory-standards:end -->

Everything outside the markers is the project's own content and is never touched.
If AGENTS.md has no markers yet, the section is inserted after the first heading
block (title plus any intro quote), so existing project content stays below it.

Usage:
    sync_agents_md.py --shared AGENTS.shared.md --version 0.1.0 [--target AGENTS.md] [--check]

--check exits 1 if the file would change (for CI drift detection) and writes nothing.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

BEGIN_RE = re.compile(r"<!-- factory-standards:begin(?: v[^ ]+)? -->")
END = "<!-- factory-standards:end -->"


def block(shared: str, version: str) -> str:
    return f"<!-- factory-standards:begin v{version} -->\n{shared.strip()}\n{END}"


def insertion_point(text: str) -> int:
    """After the H1 title and an immediately following blockquote, if any."""
    lines = text.splitlines(keepends=True)
    i = 0
    while i < len(lines) and not lines[i].startswith("# "):
        i += 1
    if i == len(lines):
        return 0
    i += 1
    while i < len(lines) and lines[i].strip() == "":
        i += 1
    while i < len(lines) and lines[i].startswith(">"):
        i += 1
    return sum(len(l) for l in lines[:i])


def sync(text: str, shared: str, version: str) -> str:
    new_block = block(shared, version)
    m = BEGIN_RE.search(text)
    if m:
        end = text.find(END, m.end())
        if end == -1:
            raise ValueError("found factory-standards:begin without a matching end marker")
        return text[: m.start()] + new_block + text[end + len(END):]
    pos = insertion_point(text)
    before, after = text[:pos].rstrip("\n"), text[pos:].lstrip("\n")
    parts = [p for p in (before, new_block, after) if p]
    return "\n\n".join(parts).rstrip("\n") + "\n"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--shared", required=True)
    ap.add_argument("--version", required=True)
    ap.add_argument("--target", default="AGENTS.md")
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()

    shared = Path(a.shared).read_text()
    target = Path(a.target)
    current = target.read_text() if target.exists() else f"# AGENTS.md\n"
    updated = sync(current, shared, a.version)
    if updated == current:
        print(f"{target}: up to date (v{a.version})")
        return 0
    if a.check:
        print(f"{target}: shared section is missing or not v{a.version}")
        return 1
    target.write_text(updated)
    print(f"{target}: shared section synced to v{a.version}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
