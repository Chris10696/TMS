#requires -Version 5.1
# ATLAS PreCompact hook: saves a snapshot of the handoff state before context compaction.
# It never blocks compaction (blocking a full context is unsafe). Re-orientation after compaction
# is done by session_start.ps1 (matcher "compact"). Output goes to artifacts/compaction/, which
# is git-ignored so it never dirties the working tree.
$ErrorActionPreference = 'Stop'
try {
    [Console]::InputEncoding = [Text.Encoding]::UTF8
    $raw = [Console]::In.ReadToEnd()
    $evt = $null
    try { $evt = $raw | ConvertFrom-Json } catch { $evt = $null }
    $root = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR }
            elseif ($evt -and $evt.cwd) { [string]$evt.cwd }
            else { (Get-Location).Path }

    $dir = Join-Path $root 'artifacts/compaction'
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $ts = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
    $trigger = if ($evt -and $evt.trigger) { [string]$evt.trigger } else { 'unknown' }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("# Pre-compaction snapshot $ts")
    $lines.Add("trigger: $trigger")
    Push-Location -LiteralPath $root
    $eap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'   # PS 5.1: native stderr must not become a terminating error
    try {
        $lines.Add('## git')
        foreach ($l in @(& git log -1 --oneline 2>$null)) { $lines.Add([string]$l) }
        foreach ($l in @(& git status --short 2>$null)) { $lines.Add([string]$l) }
    } finally { $ErrorActionPreference = $eap; Pop-Location }
    $state = Join-Path $root 'docs/STATE.md'
    if (Test-Path -LiteralPath $state) {
        $lines.Add('## docs/STATE.md')
        foreach ($l in (Get-Content -LiteralPath $state -Encoding UTF8)) { $lines.Add([string]$l) }
    }
    [IO.File]::WriteAllLines((Join-Path $dir "$ts.md"), $lines, (New-Object Text.UTF8Encoding($false)))
} catch {
    # Snapshot is best effort; never interfere with compaction.
}
exit 0
