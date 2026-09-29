# Installs skills from a release of RohanGupta15/awesome-claude-skills into Claude Code.
#
#   ./install.ps1                                  # latest release, every skill, into ~/.claude/skills
#   ./install.ps1 -Version 1.2.0                   # a specific release
#   ./install.ps1 -Skills logo-design              # only some skills
#   ./install.ps1 -Destination .\.claude\skills    # one project instead of all projects
#
# Needs the GitHub CLI (gh), signed in with access to the repo. A skill that is already installed
# is moved to <destination>\.backup-<timestamp> before being replaced; nothing else is touched.
param(
    [string]$Version = 'latest',
    [string[]]$Skills,
    [string]$Destination = (Join-Path $HOME '.claude\skills'),
    [string]$Repo = 'RohanGupta15/awesome-claude-skills'
)
$ErrorActionPreference = 'Stop'

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { throw 'The GitHub CLI (gh) is required: winget install GitHub.cli, then gh auth login' }

$tag = if ($Version -eq 'latest') { gh release view -R $Repo --json tagName --jq .tagName } else { "v$($Version.TrimStart('v'))" }
if ($LASTEXITCODE -ne 0 -or -not $tag) { throw "Could not find release '$Version' in $Repo" }

$work = Join-Path ([IO.Path]::GetTempPath()) "claude-skills-$([guid]::NewGuid().ToString('n'))"
New-Item -ItemType Directory -Force $work | Out-Null
try {
    gh release download $tag -R $Repo -p 'all-skills-*.zip' -p 'SHA256SUMS' -D $work
    if ($LASTEXITCODE -ne 0) { throw "Download of $tag failed" }

    $zip = Get-ChildItem $work -Filter 'all-skills-*.zip' | Select-Object -First 1
    $expected = (Get-Content (Join-Path $work 'SHA256SUMS') | Where-Object { $_ -match "\s$([regex]::Escape($zip.Name))$" }) -split '\s+' | Select-Object -First 1
    $actual = (Get-FileHash $zip.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $expected) { throw "Checksum mismatch for $($zip.Name)" }

    $extracted = Join-Path $work 'skills'
    Expand-Archive $zip.FullName -DestinationPath $extracted
    $available = Get-ChildItem $extracted -Directory
    $selected = if ($Skills) { $available | Where-Object Name -in $Skills } else { $available }
    $missing = $Skills | Where-Object { $_ -notin $available.Name }
    if ($missing) { throw "Not in $tag`: $($missing -join ', '). Available: $($available.Name -join ', ')" }

    New-Item -ItemType Directory -Force $Destination | Out-Null
    $backup = Join-Path $Destination ".backup-$(Get-Date -Format yyyyMMdd-HHmmss)"
    foreach ($skill in $selected) {
        $target = Join-Path $Destination $skill.Name
        if (Test-Path $target) {
            New-Item -ItemType Directory -Force $backup | Out-Null
            Move-Item $target (Join-Path $backup $skill.Name)
        }
        Copy-Item -Recurse $skill.FullName $target
        Write-Host "installed $($skill.Name)"
    }
    if (Test-Path $backup) { Write-Host "previous versions moved to $backup" }
    Write-Host "Done: $tag into $Destination. Start a new Claude Code session to load them."
}
finally { Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue }
