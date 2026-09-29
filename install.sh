#!/usr/bin/env bash
# Installs skills from a release of RohanGupta15/awesome-claude-skills into Claude Code.
#
#   ./install.sh                       # latest release, every skill, into ~/.claude/skills
#   ./install.sh -v 1.2.0              # a specific release
#   ./install.sh -s logo-design        # only some skills (repeat -s)
#   ./install.sh -d ./.claude/skills   # one project instead of all projects
#
# Needs gh (signed in with access to the repo), unzip, and sha256sum or shasum. A skill that is
# already installed is moved to <destination>/.backup-<timestamp> before being replaced.
set -euo pipefail

repo="RohanGupta15/awesome-claude-skills"
version="latest"
dest="$HOME/.claude/skills"
skills=()
while getopts "v:s:d:r:" opt; do
  case "$opt" in
    v) version="$OPTARG" ;;
    s) skills+=("$OPTARG") ;;
    d) dest="$OPTARG" ;;
    r) repo="$OPTARG" ;;
    *) echo "usage: $0 [-v version] [-s skill]... [-d destination] [-r owner/repo]" >&2; exit 2 ;;
  esac
done

command -v gh >/dev/null || { echo "The GitHub CLI (gh) is required: https://cli.github.com, then gh auth login" >&2; exit 1; }
if [[ "$version" == "latest" ]]; then
  tag="$(gh release view -R "$repo" --json tagName --jq .tagName)"
else
  tag="v${version#v}"
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
gh release download "$tag" -R "$repo" -p 'all-skills-*.zip' -p 'SHA256SUMS' -D "$work"

cd "$work"
zips=(all-skills-*.zip)
zip_name="${zips[0]}"
if command -v sha256sum >/dev/null; then
  grep " $zip_name\$" SHA256SUMS | sha256sum -c --quiet -
else
  grep " $zip_name\$" SHA256SUMS | shasum -a 256 -c --quiet -
fi
unzip -q "$zip_name" -d skills

if [[ ${#skills[@]} -eq 0 ]]; then
  for d in skills/*/; do skills+=("$(basename "$d")"); done
fi

mkdir -p "$dest"
backup="$dest/.backup-$(date +%Y%m%d-%H%M%S)"
for name in "${skills[@]}"; do
  [[ -d "skills/$name" ]] || { echo "Not in $tag: $name" >&2; exit 1; }
  if [[ -e "$dest/$name" ]]; then
    mkdir -p "$backup"
    mv "$dest/$name" "$backup/$name"
  fi
  cp -R "skills/$name" "$dest/$name"
  echo "installed $name"
done
if [[ -d "$backup" ]]; then echo "previous versions moved to $backup"; fi
echo "Done: $tag into $dest. Start a new Claude Code session to load them."
