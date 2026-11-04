#requires -Version 5.1
# ATLAS Stop gate.
#
# Active ONLY when ATLAS_AUTONOMOUS=1 (set by scripts/supervisor.ps1 or the operator's launch
# command), so ordinary interactive chats in this folder are never trapped.
#
# Allows stopping when:
#   - docs/NEEDS_HUMAN.md exists and is valid (S-CODE, EVIDENCE and NEXT lines), or
#   - docs/STATE.md says STATUS: DONE, the tree is clean, and the last verify run is green for HEAD.
# Otherwise it blocks with the next task from docs/PLAN.md.
#
# Loop safety: Claude Code ends the turn after 8 consecutive blocks without a tool call
# (CLAUDE_CODE_STOP_HOOK_BLOCK_CAP). A stuck agent therefore stops anyway, and the supervisor's
# progress watchdog escalates it. This script fails OPEN: on an internal error it allows the stop.
$ErrorActionPreference = 'Stop'
$root = $null

function Write-Block([string]$reason) {
    [Console]::Out.Write((@{ decision = 'block'; reason = $reason } | ConvertTo-Json -Compress))
    exit 0
}

try {
    if ($env:ATLAS_AUTONOMOUS -ne '1') { exit 0 }

    [Console]::InputEncoding = [Text.Encoding]::UTF8
    [Console]::OutputEncoding = [Text.Encoding]::UTF8
    $raw = [Console]::In.ReadToEnd()
    $evt = $null
    try { $evt = $raw | ConvertFrom-Json } catch { $evt = $null }

    $root = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR }
            elseif ($evt -and $evt.cwd) { [string]$evt.cwd }
            else { (Get-Location).Path }
    $again = ($evt -and ($evt.stop_hook_active -eq $true))
    $prefix = if ($again) { 'You stopped again after being told to continue. If you truly cannot make progress, follow S4 and write docs/NEEDS_HUMAN.md. ' } else { '' }

    # 1. An honest, well-formed request for the operator always allows the stop.
    $nh = Join-Path $root 'docs/NEEDS_HUMAN.md'
    if (Test-Path -LiteralPath $nh) {
        $t = Get-Content -LiteralPath $nh -Raw -Encoding UTF8
        $valid = ($t -match '(?m)^S-CODE:\s*S[1-5]\b') -and ($t -match '(?m)^EVIDENCE:\s*\S') -and ($t -match '(?m)^NEXT:\s*\S')
        if ($valid) { exit 0 }
        Write-Block ($prefix + 'docs/NEEDS_HUMAN.md exists but is malformed. It needs the lines "S-CODE: S1".."S5", "EVIDENCE: ..." and "NEXT: ..." (MASTER_PROMPT.md section 21). Fix it, or delete it and keep working.')
    }

    # 2. Repository state.
    # Windows PowerShell 5.1 turns native stderr into terminating errors under 'Stop'; relax it here.
    Push-Location -LiteralPath $root
    $eap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $head = [string](& git rev-parse --verify -q HEAD 2>$null)
        $gitOk = ($LASTEXITCODE -eq 0) -and ($head.Trim().Length -ge 7)
        $dirty = if ($gitOk) { (@(& git status --porcelain 2>$null) -join "`n") } else { '' }
    } finally { $ErrorActionPreference = $eap; Pop-Location }
    if (-not $gitOk) {
        Write-Block ($prefix + 'The project is not a git repository with at least one commit. The operator makes the initial commit (docs/atlas/OPERATOR_RUNBOOK.md). If it is missing, write docs/NEEDS_HUMAN.md with S-CODE: S2.')
    }
    $head = $head.Trim()
    $clean = [string]::IsNullOrWhiteSpace($dirty)

    # 3. Verify contract (MASTER_PROMPT.md section 20): artifacts/verify/last.json must be green for HEAD.
    $verifyOk = $false
    $verifyNote = 'scripts/verify.ps1 has not produced artifacts/verify/last.json'
    $vf = Join-Path $root 'artifacts/verify/last.json'
    if (Test-Path -LiteralPath $vf) {
        try {
            $v = Get-Content -LiteralPath $vf -Raw -Encoding UTF8 | ConvertFrom-Json
            if ([string]$v.result -notin @('green', 'green-offline')) { $verifyNote = 'the last verify run was RED' }
            elseif ([string]$v.head -ne $head) { $verifyNote = 'the last green verify run is for an older commit' }
            else { $verifyOk = $true }
        } catch { $verifyNote = 'artifacts/verify/last.json is unreadable' }
    }

    # 4. Next open item in docs/PLAN.md (a checkbox line "- [ ] ...").
    $next = 'scaffold Phase 0 per MASTER_PROMPT.md section 4'
    $openItem = $true
    $plan = Join-Path $root 'docs/PLAN.md'
    if (Test-Path -LiteralPath $plan) {
        $m = Select-String -LiteralPath $plan -Pattern '^\s*-\s\[\s\]\s+(.+)$' -Encoding UTF8 | Select-Object -First 1
        if ($m) { $next = $m.Matches[0].Groups[1].Value.Trim() }
        else { $openItem = $false; $next = 'every docs/PLAN.md item is checked: run the gate for the current phase (section 14), then plan the next phase' }
    }

    # 5. Finished? DONE counts only with no open plan items, a clean tree and green verify for HEAD.
    $state = Join-Path $root 'docs/STATE.md'
    $done = $false
    if (Test-Path -LiteralPath $state) {
        $done = ((Get-Content -LiteralPath $state -Raw -Encoding UTF8) -match '(?m)^STATUS:\s*DONE\b')
    }
    if ($done -and $verifyOk -and $clean -and -not $openItem) { exit 0 }

    # 6. Not finished: name the next task.
    $issues = @()
    if ($done -and $openItem) { $issues += 'docs/STATE.md says STATUS: DONE but docs/PLAN.md still has open items (finish them or record why they are dropped in an ADR)' }
    if (-not $clean) { $issues += 'the working tree has uncommitted changes (commit or revert them)' }
    if (-not $verifyOk) { $issues += ($verifyNote + ' (run scripts/verify.ps1 until it is green)') }
    $tail = if ($issues.Count -gt 0) { ' Also: ' + ($issues -join '; ') + '.' } else { '' }
    Write-Block ($prefix + "Work is not finished. Next task from docs/PLAN.md: $next.$tail You may stop only through docs/NEEDS_HUMAN.md for S1-S5 (MASTER_PROMPT.md section 3).")
} catch {
    try {
        if ($root) {
            $logDir = Join-Path $root '.atlas'
            New-Item -ItemType Directory -Force -Path $logDir | Out-Null
            Add-Content -LiteralPath (Join-Path $logDir 'hook-errors.log') -Value ("{0} stop_gate: {1}" -f (Get-Date -Format o), $_.Exception.Message) -Encoding UTF8
        }
    } catch { }
    exit 0
}
