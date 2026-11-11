# relink.ps1: keep ~/.claude/CLAUDE.md and ~/.claude/settings.json hard-linked to this repo.
#
# Why: Windows file symlinks need admin rights, so the live files are hard links to the copies in
# this repo (same drive, no privilege). Claude Code rewrites settings.json as a NEW file whenever it
# changes it (plugin install/uninstall, some settings changes), which silently breaks the link and
# lets the two copies drift. Run this script after such a change to restore the link.
#
# Behaviour per file: if already the same file, do nothing. Otherwise back both copies up to
# ~/.claude/backups/relink-<timestamp>/, keep whichever copy was modified more recently (copying it
# over the older one), and re-create the hard link. Review `git diff` in this repo afterwards.
#
# Usage:  pwsh -File $HOME\claude-config\relink.ps1   (adjust if the repo lives elsewhere)

$ErrorActionPreference = 'Stop'
$cfg  = Split-Path -Parent $MyInvocation.MyCommand.Path
$live = Join-Path $env:USERPROFILE '.claude'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backup = Join-Path $live "backups\relink-$stamp"

foreach ($f in @('settings.json', 'CLAUDE.md')) {
    $a = Join-Path $live $f
    $b = Join-Path $cfg $f
    if (-not (Test-Path $b)) { Write-Host "skip ${f}: not in repo"; continue }
    $linked = $false
    if (Test-Path $a) {
        $links = (fsutil hardlink list $a) -replace '/', '\'
        $linked = [bool]($links | Where-Object { $_ -ieq ($b.Substring(2)) })
    }
    if ($linked) { Write-Host "ok     ${f}: already linked"; continue }

    New-Item -ItemType Directory -Force $backup | Out-Null
    if (Test-Path $a) { Copy-Item $a (Join-Path $backup "live-$f") }
    Copy-Item $b (Join-Path $backup "repo-$f")

    if ((Test-Path $a) -and ((Get-Item $a).LastWriteTime -gt (Get-Item $b).LastWriteTime)) {
        Copy-Item $a $b -Force
        Write-Host "synced ${f}: live copy was newer, copied into the repo"
    } else {
        Write-Host "synced ${f}: repo copy kept"
    }
    if (Test-Path $a) { Remove-Item $a -Force }
    New-Item -ItemType HardLink -Path $a -Target $b | Out-Null
    Write-Host "linked ${f} (backups in $backup)"
}
