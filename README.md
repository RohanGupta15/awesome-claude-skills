# Awesome Claude Skills

A personal collection of [Claude skills](https://docs.claude.com/en/docs/claude-code/skills) I collect, use and create, packaged into versioned releases so any machine can install the same set in one step.

## Skills

| Skill | What it does | Source | Licence |
| --- | --- | --- | --- |
| [logo-design](skills/logo-design/SKILL.md) | Logo and brand-mark design from brief to production files: discovery, concepts, clean SVG construction, 16 px and one-colour testing, presentation boards, favicon and app-icon export, guidelines. Includes a 1,400+ logo reference library and Python tools. | [kaankiziltug/logo-design-skill](https://github.com/kaankiziltug/logo-design-skill) @ `5a02a1a` (v1.4.4) | [MIT](skills/logo-design/LICENSE), library logos are [trademarks of their owners](skills/logo-design/TRADEMARKS.md) |

## Install

Each [release](https://github.com/RohanGupta15/awesome-claude-skills/releases) contains:

- `all-skills-v<version>.zip`: every skill as a top-level folder.
- `<skill>.zip`: one skill on its own.
- `SHA256SUMS`: checksums for both.

### Claude Code (recommended)

Claude Code loads skills from `~/.claude/skills` (all projects) or `.claude/skills` inside a project. The install scripts download a release, check its checksum and copy the skills there. An existing skill with the same name is moved to a `.backup-<timestamp>` folder first, and nothing else is touched.

You need the [GitHub CLI](https://cli.github.com) signed in (`gh auth login`), because the repo is private.

```powershell
# Windows
./install.ps1                               # latest release, every skill
./install.ps1 -Version 1.0.0                # a specific release
./install.ps1 -Skills logo-design           # only some skills
./install.ps1 -Destination .\.claude\skills # this project only
```

```bash
# macOS / Linux
./install.sh
./install.sh -v 1.0.0 -s logo-design -d ./.claude/skills
```

Or by hand: download `all-skills-v<version>.zip` and extract it into `~/.claude/skills`, so you end up with `~/.claude/skills/logo-design/SKILL.md`.

Start a new Claude Code session afterwards; skills are picked up at startup.

### Claude.ai and Claude Desktop

Upload a single `<skill>.zip` under **Settings > Capabilities > Skills**.

### Other agents

Most agents that support the skills format read a `skills/` folder too, for example `~/.codex/skills` or `~/.gemini/skills`. Extract the bundle there.

## Adding or updating a skill

1. Put the skill in `skills/<name>/`. It needs a `SKILL.md` whose front matter `name` matches the folder (lowercase, digits and hyphens) and has a `description`.
2. For a collected skill, keep its `LICENSE` inside the folder and add a row to the table above with the upstream repo and commit.
3. Check it:

   ```bash
   python scripts/validate_skills.py
   python scripts/package_skills.py --version 0.0.0 --out dist   # optional trial build
   ```

4. Add a line under **Unreleased** in [CHANGELOG.md](CHANGELOG.md).

## Releasing

A release is published automatically when `VERSION` changes on `main`:

1. Move the **Unreleased** notes in `CHANGELOG.md` under a new `## [x.y.z] - YYYY-MM-DD` heading.
2. Set `VERSION` to the same `x.y.z`. Use a major bump for breaking changes such as removing or renaming a skill, a minor bump for new skills, and a patch for fixes.
3. Commit and push to `main`.

The [release workflow](.github/workflows/release.yml) validates every skill, builds the zips and checksums, and publishes `v<x.y.z>` with that CHANGELOG section as its notes. You can also run it by hand from the Actions tab; a version that already has a release is skipped. [Validate](.github/workflows/validate.yml) runs on every push and pull request.

## Licences

This repository collects skills from different authors. Each skill keeps its own licence in its folder, and the table above lists them. Scripts and docs outside `skills/` are mine and free to reuse.
