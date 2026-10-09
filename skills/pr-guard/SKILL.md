---
name: pr-guard
description: Pre-PR quality gate. Use whenever the user asks to create, open, raise or submit a pull request, or says "pr-guard init". Reuses the project's own lint/build/check commands, has a cheap model review for over-engineering, bloat and needless comments (via the ponytail-review skill), checks CodeQL, reports in plain words, offers a one-shot fix, then opens the PR.
---

# PR Guard

Goal: catch bloat and obvious problems before a PR opens, at the lowest cost. Never invent commands; use what the project already has. Stay quiet when everything is fine.

All per-repo state lives in one file: `.claude/pr-guard.json`.

```json
{
  "base": "dev",
  "checks": {
    "lint":  { "cmd": "npm run lint --", "files": true, "source": "package.json#scripts.lint" },
    "types": { "cmd": "npm run typecheck", "files": false, "source": "package.json#scripts.typecheck" },
    "build": null
  },
  "already_enforced": ["lint"],
  "codeql": "workflow",
  "ignore": [
    { "pattern": "src/legacy/**", "reason": "frozen code" },
    { "rule": "single-use wrapper around fetchClient", "reason": "intentional: mock seam" }
  ]
}
```

- `when` (optional) is a comma-separated list of file patterns; the check only runs if the diff touches one of them.
- `files: true` means changed file paths can be appended to the command.
- `already_enforced` lists checks that a pre-commit hook or CI already runs on every commit or PR.
- `codeql` is one of `workflow`, `local`, or `none`.

## Init (`pr-guard init`, or automatically when the config is missing)

Use a `haiku` agent. Discover commands only; never write new scripts. Never switch branches, stash or change the working tree; dry-run commands on the current branch only.

1. Read what exists: `package.json` scripts (and the package manager from its lockfile), `Makefile`/`justfile`/`Taskfile`, `pyproject.toml`/`tox.ini`/`noxfile`, `Cargo.toml`, `go.mod`, `composer.json`, `build.gradle`, `.pre-commit-config.yaml`, `.husky/`/`lefthook.yml`, `.github/workflows/*`, plus CLAUDE.md/CONTRIBUTING.md/README for "how to lint/test".
2. Prefer, in this order: the commands CI runs, then the project's scripts or task runner, then the tool's own command if that tool is configured (e.g. a `ruff` section exists). Only pick checks that take under about a minute (lint, format check, typecheck, fast build). Skip the full test suites.
3. Mark checks that pre-commit hooks or CI already enforce as `already_enforced`.
4. Detect `codeql`: if a workflow mentions `github/codeql-action` (or GitHub default setup is on), use `workflow`; otherwise `none`.
5. Detect `base` from CLAUDE.md or memory conventions, then from `gh repo view --json defaultBranchRef`.
6. Check that the `ponytail:ponytail-review` skill is in the skills list. If it is missing, say the review will use the fallback checklist and ask whether to install the ponytail plugin (github.com/DietrichGebert/ponytail). Ask once per machine.
7. Show the proposed config in a few lines, including where each command came from. Write it once the user confirms. Ask whether it should be committed or added to `.git/info/exclude`.

Re-run init when a config file it relied on changes, or when a configured command fails with "not found".

## 1. Scope the change (main thread, no agent)

- Load the config, running init first if it's missing.
- Run `git fetch -q origin <base>`, then `git diff --shortstat` and `git diff --name-only` for `origin/<base>...HEAD`.
- Drop files matching an `ignore[].pattern`, along with lockfiles, generated code and vendored code.

Pick the reviewer:

| Change | Reviewer |
|---|---|
| Docs/config/renames only, or < 30 code lines | `haiku` |
| < 300 lines, one area | `sonnet`, effort `low` |
| Bigger, or touches auth/security/data/migrations | `sonnet`, effort `medium` |
| > 1500 lines | `sonnet` medium on the riskiest files only, and suggest splitting the PR |

Docs-only changes skip steps 2–3.

## 2. Run these at the same time

**A. Checks (main thread).** Run each configured check, except those in `already_enforced`. For an `already_enforced` check, read its result instead: if the latest commit passed its hooks or the branch's CI is green, count it as passed. Append the changed files when `files` is true. Only failures matter.

**B. Review agent (background).** Use the model from step 1 and this prompt:

> Run the `ponytail:ponytail-review` skill on branch `HEAD` against `origin/<base>`. Also flag comments that only repeat the code and leftover debug prints, any file this diff pushes from under 1000 lines to over 1000, and new one-off conditionals or flags bolted into unrelated code paths (suggest where the logic belongs instead). If that skill is unavailable, check the diff yourself for bugs, single-use abstractions, dead or duplicated code, avoidable dependencies and useless comments. Skip these accepted items: <ignore[].rule list>, and any `shortcut:` comment that names its limit. Return at most 6 findings, each `MUST|NICE file:line — problem — simple fix` (bugs and security issues are MUST; lean items are NICE unless large), or exactly `CLEAN`.

**C. CodeQL.**
- `workflow`: it runs on the PR. Do nothing now.
- `local`: run it only if the diff touches security-sensitive code, for that language only.
- `none`: suggest GitHub CodeQL default setup once, then record that it was suggested.

## 3. Report (only when something triggered)

```
Before opening this PR:
✗ Must fix (2)
  1. api/user.ts:40: this wrapper is only used once. Call the function directly.
  2. Lint: 3 unused imports in utils.py
• Could tidy (1)
  3. service.go:12: the comment repeats the code. Delete it.

[fix all] [fix 1,3] [ignore 2: reason] [open anyway] [stop]
```

- Everything clean: print one line, `✓ checks, review clean`, and continue to step 4.
- Only NICE items: show them and continue unless the user objects.
- **Fix:** a `haiku` agent (or `sonnet` low for items that touch logic) applies only the chosen items. Re-run just the failed checks, then make one commit: `chore: pr-guard fixes`. Never rewrite earlier commits.
- **Ignore:** add `{rule or pattern, reason}` to `ignore` in the config so the finding never comes back. Ignore a whole file pattern only when the user names one.

## 4. Open the PR

- Push the branch, then run `gh pr create --base <base>`. Write a short title and a body covering what changed, why, and how it was tested. If the project has a PR template, use it.
- Follow the user's attribution rules from memory/CLAUDE.md.
- Never push to the base branch directly. With `codeql: workflow`, mention that results will show on the PR; do not poll.
