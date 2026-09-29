#!/usr/bin/env python3
"""Checks every skill in skills/ before it is packaged.

A skill is a folder under skills/ with a SKILL.md whose YAML front matter has a `name` and a
`description`. Claude loads a skill by that name, so it must match the folder and follow Claude's
rules: lowercase letters, digits and hyphens, at most 64 characters; description at most 1024.

Usage: python scripts/validate_skills.py [skills-dir]
Exits non-zero when any skill fails.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

NAME_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
JUNK = {"__pycache__", ".DS_Store", "Thumbs.db"}


def front_matter(text: str) -> dict[str, str] | None:
    """Reads simple `key: value` pairs from the leading --- block (enough for name/description)."""
    if not text.startswith("---"):
        return None
    end = text.find("\n---", 3)
    if end == -1:
        return None
    fields: dict[str, str] = {}
    key = None
    for line in text[3:end].splitlines():
        if not line.strip():
            continue
        match = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", line)
        if match:
            key = match.group(1)
            fields[key] = match.group(2).strip().strip("\"'")
        elif key and line.startswith((" ", "\t")):
            # Folded continuation line of the previous value.
            fields[key] = (fields[key] + " " + line.strip()).strip()
    return fields


def check(skill_dir: Path) -> list[str]:
    problems: list[str] = []
    skill_md = skill_dir / "SKILL.md"
    if not skill_md.is_file():
        return ["missing SKILL.md"]

    fields = front_matter(skill_md.read_text(encoding="utf-8"))
    if fields is None:
        return ["SKILL.md has no --- front matter block"]

    name = fields.get("name", "")
    description = fields.get("description", "")
    if not name:
        problems.append("front matter has no name")
    elif name != skill_dir.name:
        problems.append(f"name '{name}' does not match folder '{skill_dir.name}'")
    elif not NAME_RE.match(name) or len(name) > 64:
        problems.append(f"name '{name}' must be lowercase letters, digits and hyphens, at most 64 characters")

    if not description:
        problems.append("front matter has no description")
    elif len(description) > 1024:
        problems.append(f"description is {len(description)} characters (max 1024)")

    for path in skill_dir.rglob("*"):
        if path.name in JUNK:
            problems.append(f"remove {path.relative_to(skill_dir)}")
    return problems


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / "skills")
    skills = sorted(p for p in root.iterdir() if p.is_dir())
    if not skills:
        print(f"no skills found in {root}")
        return 1

    failed = 0
    for skill in skills:
        problems = check(skill)
        if problems:
            failed += 1
            print(f"FAIL {skill.name}")
            for problem in problems:
                print(f"     - {problem}")
        else:
            print(f"ok   {skill.name}")
    print(f"\n{len(skills) - failed} of {len(skills)} skills valid")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
