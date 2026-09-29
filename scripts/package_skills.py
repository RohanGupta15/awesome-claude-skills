#!/usr/bin/env python3
"""Packages skills/ into release zips.

Writes to the output folder:
  all-skills-v<version>.zip   every skill as a top-level folder; extract straight into ~/.claude/skills
  <skill>.zip                 one skill (the format Claude.ai and Claude Desktop accept for upload)
  SHA256SUMS                  checksums for all of the above

Zips are reproducible: sorted entries, fixed timestamps, no caches.

Usage: python scripts/package_skills.py --version 1.0.0 [--out dist]
"""
from __future__ import annotations

import argparse
import hashlib
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SKIP = {"__pycache__", ".DS_Store", "Thumbs.db"}
FIXED_TIME = (1980, 1, 1, 0, 0, 0)


def skill_files(skill_dir: Path) -> list[Path]:
    return sorted(
        p for p in skill_dir.rglob("*")
        if p.is_file() and not SKIP.intersection(p.relative_to(skill_dir).parts)
    )


def add(zf: zipfile.ZipFile, path: Path, arcname: str) -> None:
    info = zipfile.ZipInfo(arcname, FIXED_TIME)
    info.compress_type = zipfile.ZIP_DEFLATED
    info.external_attr = 0o644 << 16
    zf.writestr(info, path.read_bytes())


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--version", required=True)
    parser.add_argument("--out", default=str(ROOT / "dist"))
    args = parser.parse_args()

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    skills = sorted(p for p in (ROOT / "skills").iterdir() if (p / "SKILL.md").is_file())

    written: list[Path] = []
    bundle = out / f"all-skills-v{args.version}.zip"
    with zipfile.ZipFile(bundle, "w") as all_zip:
        for skill in skills:
            single = out / f"{skill.name}.zip"
            with zipfile.ZipFile(single, "w") as one_zip:
                for path in skill_files(skill):
                    arcname = f"{skill.name}/{path.relative_to(skill).as_posix()}"
                    add(one_zip, path, arcname)
                    add(all_zip, path, arcname)
            written.append(single)
    written.insert(0, bundle)

    sums = out / "SHA256SUMS"
    sums.write_text("".join(f"{sha256(p)}  {p.name}\n" for p in written), encoding="utf-8")

    for path in written + [sums]:
        print(f"{path.name:40} {path.stat().st_size / 1_048_576:7.2f} MB")


if __name__ == "__main__":
    main()
