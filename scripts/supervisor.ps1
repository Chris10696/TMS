#requires -Version 5.1
<#
.SYNOPSIS
    ATLAS supervisor: keeps the autonomous build loop alive across usage-limit resets and crashes.

.DESCRIPTION
    Each iteration starts one headless Claude Code run (claude -p) that resumes from docs/STATE.md.
    By default every iteration is a FRESH session, so docs/STATE.md is the single source of truth
    and the handoff is exercised on every loop. Use -ContinueSession to reuse the last session.

    The loop stops when:
      - docs/NEEDS_HUMAN.md exists (the agent, or this script, needs the operator);
      - docs/STATE.md says STATUS: DONE;
      - no new commit appears for -NoProgressLimit successful iterations (writes NEEDS_HUMAN, S4);
      - -MaxConsecutiveFailures runs fail in a row (writes NEEDS_HUMAN, S4).
    A usage-limit message is not a failure: the script sleeps until the reset time it can parse
    from the message, otherwise for -DefaultLimitSleepMinutes. Parsing is best effort.

    Safety: never sets ATLAS_LIVE, and removes it from the child environment if present.
    Sets ATLAS_AUTONOMOUS=1 for the child only, which arms the Stop gate.
    Works in Windows PowerShell 5.1 and PowerShell 7.

    Exit codes: 0 stopped normally, 1 failure limit, 2 already running, 3 configuration error.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts\supervisor.ps1

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts\supervisor.ps1 -Model opus -MaxBudgetUsd 20
#>
[CmdletBinding()]
param(
    [string]$Root = '',
    [string]$ClaudeExe = 'claude',
    [string]$Model = '',
    [ValidateSet('low', 'medium', 'high', 'xhigh', 'max')][string]$Effort = 'max',
    # bypassPermissions is deliberately not offered: it belongs in disposable containers only.
    [ValidateSet('auto', 'acceptEdits', 'default', 'manual', 'dontAsk', 'plan')][string]$PermissionMode = 'auto',
    [int]$MaxTurns = 200,
    [double]$MaxBudgetUsd = 0,
    [switch]$ContinueSession,
    [int]$NoProgressLimit = 3,
    [int]$MaxConsecutiveFailures = 5,
    [int]$DefaultLimitSleepMinutes = 30,
    [int]$MaxIterations = 0,
    [int]$SleepSecondsOverride = 0
)

$ErrorActionPreference = 'Stop'
if (-not $Root) { $Root = Split-Path -Parent $PSScriptRoot }
$Root = (Resolve-Path -LiteralPath $Root).Path

$Prompt = 'Resume per docs/STATE.md and MASTER_PROMPT.md sections 3 and 16. First read CLAUDE.md, docs/STATE.md, docs/PLAN.md and docs/LESSONS.md. Work on the next task until the stop gate lets you stop.'

$logDir = Join-Path $Root 'logs'
$runDir = Join-Path $logDir 'runs'
New-Item -ItemType Directory -Force -Path $runDir | Out-Null
$dailyLog = Join-Path $logDir ('supervisor-{0}.log' -f (Get-Date -Format 'yyyyMMdd'))

function Write-Log([string]$msg) {
    $line = '{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg
    Write-Host $line
    Add-Content -LiteralPath $dailyLog -Value $line -Encoding UTF8
}

function Get-Head {
    Push-Location -LiteralPath $Root
    $eap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $h = [string](& git rev-parse --verify -q HEAD 2>$null)
        if ($LASTEXITCODE -ne 0) { return 'none' }
        return $h.Trim()
    } finally { $ErrorActionPreference = $eap; Pop-Location }
}

function Test-NeedsHuman { return (Test-Path -LiteralPath (Join-Path $Root 'docs/NEEDS_HUMAN.md')) }

function Test-Done {
    $s = Join-Path $Root 'docs/STATE.md'
    if (-not (Test-Path -LiteralPath $s)) { return $false }
    return ((Get-Content -LiteralPath $s -Raw -Encoding UTF8) -match '(?m)^STATUS:\s*DONE\b')
}

function Write-NeedsHuman([string]$code, [string]$evidence, [string]$next) {
    $f = Join-Path $Root 'docs/NEEDS_HUMAN.md'
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $f) | Out-Null
    $body = @(
        '# Needs human (written by scripts/supervisor.ps1)',
        '',
        "S-CODE: $code",
        "EVIDENCE: $evidence",
        "NEXT: $next",
        ('WRITTEN: {0}' -f (Get-Date -Format o))
    )
    [IO.File]::WriteAllLines($f, $body, (New-Object Text.UTF8Encoding($false)))
}

function Format-Arg([string]$a) {
    if ($a -notmatch '[\s"]') { return $a }
    return '"' + ($a -replace '"', '\"') + '"'
}

function Sleep-For([double]$seconds, [string]$why) {
    $s = if ($SleepSecondsOverride -gt 0) { $SleepSecondsOverride } else { [int][Math]::Ceiling($seconds) }
    Write-Log ("sleeping {0}s ({1})" -f $s, $why)
    Start-Sleep -Seconds $s
}

function Get-LimitWaitSeconds([string]$text) {
    if ($text -notmatch '(?i)(usage limit|limit reached|rate limit|5-hour limit|weekly limit|out of (extra )?usage|limit will reset|hit your limit)') { return $null }
    $default = $DefaultLimitSleepMinutes * 60
    $h = $null; $mi = 0; $ampm = $null
    if ($text -match '(?i)reset[s]?\s*(?:at\s*)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b') {
        $h = [int]$Matches[1]; if ($Matches[2]) { $mi = [int]$Matches[2] }; $ampm = $Matches[3]
    } elseif ($text -match '(?i)reset[s]?\s*(?:at\s*)?(\d{1,2}):(\d{2})\b') {
        $h = [int]$Matches[1]; $mi = [int]$Matches[2]
    }
    if ($null -eq $h) { return $default }
    if ($ampm) {
        if ($ampm -ieq 'pm' -and $h -lt 12) { $h += 12 }
        elseif ($ampm -ieq 'am' -and $h -eq 12) { $h = 0 }
    }
    if ($h -gt 23 -or $mi -gt 59) { return $default }
    $now = Get-Date
    $target = $now.Date.AddHours($h).AddMinutes($mi)
    if ($target -le $now) { $target = $target.AddDays(1) }
    return [Math]::Min([int]($target - $now).TotalSeconds + 120, 6 * 3600)
}

function Invoke-Claude([string]$exe) {
    $cliArgs = @('-p', $Prompt, '--permission-mode', $PermissionMode, '--effort', $Effort,
                 '--max-turns', [string]$MaxTurns, '--output-format', 'text')
    if ($ContinueSession) { $cliArgs += '--continue' }
    if ($Model) { $cliArgs += @('--model', $Model) }
    if ($MaxBudgetUsd -gt 0) { $cliArgs += @('--max-budget-usd', ([string]$MaxBudgetUsd)) }
    $argString = ($cliArgs | ForEach-Object { Format-Arg $_ }) -join ' '

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    if ($exe -match '\.ps1$') {
        $psi.FileName = 'powershell.exe'
        $psi.Arguments = '-NoProfile -ExecutionPolicy Bypass -File ' + (Format-Arg $exe) + ' ' + $argString
    } else {
        $psi.FileName = $exe
        $psi.Arguments = $argString
    }
    $psi.WorkingDirectory = $Root
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [Text.Encoding]::UTF8
    if ($psi.EnvironmentVariables.ContainsKey('ATLAS_LIVE')) { $psi.EnvironmentVariables.Remove('ATLAS_LIVE') }
    $psi.EnvironmentVariables['ATLAS_AUTONOMOUS'] = '1'
    $psi.EnvironmentVariables['CLAUDE_CODE_EFFORT_LEVEL'] = $Effort

    $proc = [System.Diagnostics.Process]::Start($psi)
    $outTask = $proc.StandardOutput.ReadToEndAsync()
    $errTask = $proc.StandardError.ReadToEndAsync()
    $proc.WaitForExit()
    return [pscustomobject]@{ Code = $proc.ExitCode; Out = $outTask.Result; Err = $errTask.Result }
}

# --- single-instance lock -------------------------------------------------------------------
$lockDir = Join-Path $Root '.atlas'
New-Item -ItemType Directory -Force -Path $lockDir | Out-Null
$lock = Join-Path $lockDir 'supervisor.lock'
if (Test-Path -LiteralPath $lock) {
    $oldPid = 0
    [void][int]::TryParse(((Get-Content -LiteralPath $lock -Raw) -replace '\s', ''), [ref]$oldPid)
    if ($oldPid -gt 0 -and (Get-Process -Id $oldPid -ErrorAction SilentlyContinue)) {
        Write-Log "another supervisor (PID $oldPid) is running; exiting"
        exit 2
    }
    Write-Log "removing stale lock (PID $oldPid)"
}
Set-Content -LiteralPath $lock -Value $PID -Encoding ASCII

$exitCode = 0
try {
    $exe = $null
    if (Test-Path -LiteralPath $ClaudeExe) {
        $exe = (Resolve-Path -LiteralPath $ClaudeExe).Path
    } else {
        $cmd = Get-Command $ClaudeExe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($cmd) { $exe = $cmd.Source }
    }
    if (-not $exe) {
        Write-Log "cannot find '$ClaudeExe'; install Claude Code first (docs/atlas/OPERATOR_RUNBOOK.md step 1)"
        $exitCode = 3
    } else {
        Write-Log ("supervisor start: root={0} exe={1} effort={2} mode={3} fresh={4}" -f $Root, $exe, $Effort, $PermissionMode, (-not $ContinueSession))
    }

    $iter = 0; $fails = 0; $noProgress = 0
    while ($exe) {
        if (Test-NeedsHuman) { Write-Log 'docs/NEEDS_HUMAN.md exists: stopping for the operator'; break }
        if (Test-Done) { Write-Log 'docs/STATE.md says STATUS: DONE: stopping'; break }
        if ($MaxIterations -gt 0 -and $iter -ge $MaxIterations) { Write-Log "reached -MaxIterations $MaxIterations"; break }

        $iter++
        $before = Get-Head
        Write-Log "iteration $iter starting (HEAD $before)"
        $r = Invoke-Claude $exe
        $runLog = Join-Path $runDir ('{0}-iter{1}.log' -f (Get-Date -Format 'yyyyMMdd-HHmmss'), $iter)
        [IO.File]::WriteAllText($runLog, ("EXIT: {0}`n--- STDOUT ---`n{1}`n--- STDERR ---`n{2}" -f $r.Code, $r.Out, $r.Err), (New-Object Text.UTF8Encoding($false)))
        Write-Log ("iteration {0} exit {1}; transcript {2}" -f $iter, $r.Code, $runLog)

        $wait = Get-LimitWaitSeconds ($r.Out + "`n" + $r.Err)
        if ($null -ne $wait) { Sleep-For $wait 'usage limit reported'; continue }

        if ($r.Code -ne 0) {
            $fails++
            if ($fails -ge $MaxConsecutiveFailures) {
                Write-NeedsHuman 'S4' "$fails consecutive failed runs; last transcript $runLog" 'Operator: read the transcript, fix the cause, delete this file, restart the supervisor.'
                Write-Log "failure limit reached ($fails); wrote docs/NEEDS_HUMAN.md"
                $exitCode = 1
                break
            }
            Sleep-For ([Math]::Min([Math]::Pow(2, $fails), 30) * 60) "backoff after failure $fails"
            continue
        }
        $fails = 0

        $after = Get-Head
        if ($after -eq $before) { $noProgress++ } else { $noProgress = 0 }
        if ($noProgress -ge $NoProgressLimit -and -not (Test-NeedsHuman) -and -not (Test-Done)) {
            Write-NeedsHuman 'S4' "no new commit in $noProgress consecutive successful runs (HEAD $after); last transcript $runLog" 'Operator: read the last transcripts in logs/runs, decide whether the agent is stuck, delete this file, restart.'
            Write-Log "no progress for $noProgress iterations; wrote docs/NEEDS_HUMAN.md"
            break
        }
    }
} finally {
    Remove-Item -LiteralPath $lock -Force -ErrorAction SilentlyContinue
    Write-Log "supervisor exit $exitCode"
}
exit $exitCode
