#requires -Version 5.1
# ATLAS SessionStart hook (startup, resume, clear, compact).
# Whatever this script prints is added to Claude's context. It never blocks and always exits 0.
$ErrorActionPreference = 'Stop'
try {
    [Console]::InputEncoding = [Text.Encoding]::UTF8
    [Console]::OutputEncoding = [Text.Encoding]::UTF8
    $raw = [Console]::In.ReadToEnd()
    $evt = $null
    try { $evt = $raw | ConvertFrom-Json } catch { $evt = $null }

    $root = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR }
            elseif ($evt -and $evt.cwd) { [string]$evt.cwd }
            else { (Get-Location).Path }
    $source = if ($evt -and $evt.source) { [string]$evt.source } else { 'unknown' }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("ATLAS orientation (session source: $source).")
    $lines.Add('Before any action: read CLAUDE.md, docs/STATE.md, docs/PLAN.md and docs/LESSONS.md. MASTER_PROMPT.md governs (section 1 sets precedence).')
    if ($env:ATLAS_AUTONOMOUS -eq '1') {
        $lines.Add('Mode: AUTONOMOUS. The stop gate is active: stop only via docs/NEEDS_HUMAN.md (MASTER_PROMPT.md section 3).')
    } else {
        $lines.Add('Mode: INTERACTIVE. The stop gate is inactive; the PreToolUse guard is still active.')
    }

    $nh = Join-Path $root 'docs/NEEDS_HUMAN.md'
    if (Test-Path -LiteralPath $nh) {
        $lines.Add('docs/NEEDS_HUMAN.md EXISTS: an operator question is open. If the operator answered it in this conversation, record the answers in docs/DECISIONS.md (OWNER), delete the file and resume. Otherwise do unblocked work or wait.')
    }

    $state = Join-Path $root 'docs/STATE.md'
    if (Test-Path -LiteralPath $state) {
        $lines.Add('--- head of docs/STATE.md ---')
        foreach ($l in (Get-Content -LiteralPath $state -TotalCount 40 -Encoding UTF8)) { $lines.Add([string]$l) }
        $lines.Add('--- end of excerpt ---')
    } else {
        $lines.Add('docs/STATE.md not found: Phase 0 has not run yet. Start with MASTER_PROMPT.md section 4.')
    }

    $lessons = Join-Path $root 'docs/LESSONS.md'
    if (Test-Path -LiteralPath $lessons) {
        $count = @(Select-String -LiteralPath $lessons -Pattern '^\s*-\s' -Encoding UTF8).Count
        $lines.Add("docs/LESSONS.md has $count entries; read them before repeating a past mistake.")
    }

    [Console]::Out.Write(($lines -join "`n"))
} catch {
    [Console]::Out.Write("ATLAS orientation hook error: $($_.Exception.Message). Read CLAUDE.md and docs/STATE.md manually.")
}
exit 0
