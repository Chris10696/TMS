#requires -Version 5.1
# ATLAS PreToolUse guard for Bash, PowerShell, Write, Edit and NotebookEdit.
#
# Defense in depth, NOT a wall. On native Windows there is no OS sandbox, and a script that
# opens files itself is invisible to this guard. The real controls are: no live credentials on
# the build machine, the demo lock in code, the human gates, and git audit at every gate
# (MASTER_PROMPT.md section 18). This guard stops the common accidental and injected paths.
#
# Output: a "deny" decision as JSON, or nothing (the normal permission flow applies).
# Fails closed: if the input cannot be parsed, or the guard errors, the call is denied.
$ErrorActionPreference = 'Stop'

function Write-Deny([string]$reason) {
    $out = @{ hookSpecificOutput = @{
        hookEventName            = 'PreToolUse'
        permissionDecision       = 'deny'
        permissionDecisionReason = "ATLAS guard: $reason"
    } }
    [Console]::Out.Write(($out | ConvertTo-Json -Compress -Depth 5))
    exit 0
}

function ConvertTo-NormPath([string]$p) {
    if (-not $p) { return '' }
    $n = $p.Trim().Trim('"').Trim("'") -replace '\\', '/'
    if ($n -match '^/([a-zA-Z])/(.*)$') { $n = $Matches[1] + ':/' + $Matches[2] }   # Git Bash /c/... form
    while ($n.Contains('//')) { $n = $n.Replace('//', '/') }
    return $n.TrimEnd('/').ToLowerInvariant()
}

# Replace the contents of quoted strings, so words inside commit messages do not trigger rules.
function Remove-Quoted([string]$s) {
    return [regex]::Replace($s, '"[^"]*"|''[^'']*''', '""')
}

try {
    [Console]::InputEncoding = [Text.Encoding]::UTF8
    [Console]::OutputEncoding = [Text.Encoding]::UTF8
    $raw = [Console]::In.ReadToEnd()
    $evt = $raw | ConvertFrom-Json
    if ($null -eq $evt) { throw 'empty input' }
} catch {
    Write-Deny 'could not parse the hook input, so the call is denied (fail closed).'
}

try {
    $root = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR }
            elseif ($evt.cwd) { [string]$evt.cwd }
            else { (Get-Location).Path }
    $rootN = ConvertTo-NormPath $root

    # Files the agent must never change by any route (MASTER_PROMPT.md section 2, rule 21).
    # Entries ending in '/' protect a whole directory.
    $protected = New-Object System.Collections.Generic.List[string]
    foreach ($p in @('master_prompt.md', 'docs/go_live_approval.md', '.claude/settings.json',
                     '.claude/settings.local.json', '.claude/settings.atlas.json', '.claude/hooks/',
                     '.atlas/locks.json', '.atlas/guard_probe.txt')) { $protected.Add($p) }

    # Operator-locked files (created by the operator after Phase 0; see OPERATOR_RUNBOOK.md).
    $locksFile = Join-Path $root '.atlas/locks.json'
    if (Test-Path -LiteralPath $locksFile) {
        try {
            $locks = Get-Content -LiteralPath $locksFile -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($l in @($locks.locked)) { if ($l) { $protected.Add((ConvertTo-NormPath ([string]$l))) } }
        } catch {
            Write-Deny '.atlas/locks.json is unreadable, so all guarded calls are denied until the operator repairs it.'
        }
    }

    $tool = [string]$evt.tool_name
    $ti = $evt.tool_input

    if ($tool -eq 'Bash' -or $tool -eq 'PowerShell') {
        $cmd = [string]$ti.command
        $bare = Remove-Quoted $cmd
        $cmdN = ($cmd -replace '\\', '/').ToLowerInvariant()

        # 1. Live-trading switch: only the operator sets it, on the production host (rule 2).
        $livePatterns = @(
            'I_ACCEPT_REAL_MONEY_RISK',
            '\$env:ATLAS_LIVE\s*=',
            '\b(set|setx|export)\s+ATLAS_LIVE\b',
            '(^|[^\w.])ATLAS_LIVE\s*=(?!=)',
            'ATLAS_LIVE[''"]\s*\]\s*=(?!=)',
            'SetEnvironmentVariable\(\s*[''"]ATLAS_LIVE'
        )
        foreach ($pat in $livePatterns) {
            if ($cmd -match $pat) { Write-Deny 'only the operator may set ATLAS_LIVE or use its value (MASTER_PROMPT.md section 2, rule 2).' }
        }

        # 2. Secrets: never read, print or copy them (rule 8).
        $secretPatterns = @(
            '(^|[\s''"=/\\(:])\.env(\.[\w.-]+)?($|[\s''"/\\);|&>])',
            '(^|[\s''"=/\\(:])[\w.-]*\.(pem|key|pfx|p12)($|[\s''"/\\);|&>])',
            '(^|[\s''"=/\\(:])(id_rsa|id_ecdsa|id_ed25519)[\w.]*($|[\s''"/\\);|&>])',
            '[\\/]secrets([\\/]|$|[\s''"])',
            'accounts\.dat',
            'MetaQuotes[\\/]+Terminal[\\/]+[^\\/\s]+[\\/]+config'
        )
        foreach ($pat in $secretPatterns) {
            if ($cmd -match $pat) { Write-Deny 'the command touches a secret-like path (.env, keys, secrets/, MT5 terminal config). Secrets never enter the build (rule 8).' }
        }

        # 3. Protected files: any shell write, move or delete is forbidden; reading is fine (use the Read tool).
        $mutation = '(>|\bSet-Content\b|\bAdd-Content\b|\bOut-File\b|\bNew-Item\b|\bRemove-Item\b|\bMove-Item\b|\bCopy-Item\b|\bRename-Item\b|\bClear-Content\b|\bri\b|\brm\b|\bdel\b|\berase\b|\bmv\b|\bcp\b|\bsed\b[^|;&]*\s-i|\btee\b|\btruncate\b|\bgit\s+(rm|mv|checkout|restore|update-index)\b|WriteAll(Text|Lines|Bytes)|\.write_text\(|open\([^)]*,\s*[''"][wax+])'
        foreach ($pp in $protected) {
            if ($cmdN.Contains($pp) -and $cmd -match $mutation) {
                Write-Deny "the command may modify the protected path '$pp' (rule 21). Read it with the Read tool; propose changes in docs/DECISIONS.md and ask under S1."
            }
        }

        # 4. Git history and remotes: honest history, no pushes, no skipped hooks (rules 15, 16).
        $gitPatterns = @(
            '\bgit\b[^;&|]*\bpush\b',
            '\bgit\b[^;&|]*\breset\b[^;&|]*--hard',
            '\bgit\b[^;&|]*\bclean\b[^;&|]*\s-[a-z]*f',
            '\bgit\b[^;&|]*\b(filter-branch|filter-repo)\b',
            '\bgit\b[^;&|]*\btag\b[^;&|]*(\s-d\b|--delete|\s-f\b|--force)',
            '\bgit\b[^;&|]*\bupdate-ref\b[^;&|]*\s-d\b',
            '\bgit\b[^;&|]*\breflog\b[^;&|]*\bexpire\b',
            '\bgit\b[^;&|]*--no-verify',
            '\bgit\b[^;&|]*\bconfig\b[^;&|]*\bcore\.hooksPath\b'
        )
        foreach ($pat in $gitPatterns) {
            if ($bare -match $pat) { Write-Deny 'this git operation rewrites history, pushes, or skips hooks. The operator does these by hand (rules 15 and 16).' }
        }

        # 4b. Sole contributor (rule 26). Checked on the raw command, because the trailer sits inside the quoted message.
        if ($cmd -match '\bgit\b[^;&|]*\bcommit\b' -and $cmd -match 'co-authored-by\s*:') {
            Write-Deny 'commits must not carry Co-Authored-By lines or AI attribution: the operator is the only contributor (rule 26).'
        }

        # 5. Supply chain: never pipe a download into a shell (section 18).
        if ($bare -match '\b(irm|iwr|Invoke-RestMethod|Invoke-WebRequest|curl|wget)\b[^\n]*\|\s*(iex|Invoke-Expression|sh|bash|pwsh|powershell)\b' -or
            $bare -match '\b(iex|Invoke-Expression)\b\s*\(?\s*(\(?\s*(New-Object\s+Net\.WebClient|irm|iwr|Invoke-RestMethod|Invoke-WebRequest))') {
            Write-Deny 'piping a download into a shell is forbidden (section 18). Download, inspect, pin and hash instead.'
        }

        # 6. Own access and Claude Code configuration: never widen it (rule 17).
        if ($bare -match '\bclaude\b[^;&|]*\b(mcp\s+(add|add-json|remove)|config|plugin\s+(install|add))\b' -or
            $cmd -match '--dangerously-skip-permissions|bypassPermissions|disableBypassPermissionsMode|--allow-dangerously-skip-permissions') {
            Write-Deny 'changing Claude Code servers, plugins, permissions or modes is operator-only (rule 17). Ask under S1.'
        }

        # 7. System and security settings are operator-only (section 18).
        if ($bare -match '\b(Set-ExecutionPolicy|powercfg|netsh|bcdedit|Set-MpPreference|Add-MpPreference|Enable-WindowsOptionalFeature|Disable-WindowsOptionalFeature|New-NetFirewallRule|Set-NetFirewall\w*|Register-ScheduledTask|Unregister-ScheduledTask|New-Service|Set-Service|setx)\b' -or
            $bare -match '\breg(\.exe)?\s+(add|delete|import)\b' -or
            $bare -match '\bschtasks(\.exe)?\s+/(create|change|delete)\b' -or
            $bare -match '\bsc(\.exe)?\s+(create|config|delete)\b' -or
            $bare -match '\bnssm(\.exe)?\s+(install|set|remove)\b') {
            Write-Deny 'system, service, scheduler and security settings are operator-only (section 18). Write the script and ask the operator to run it.'
        }
    }
    elseif ($tool -eq 'Write' -or $tool -eq 'Edit' -or $tool -eq 'NotebookEdit' -or $tool -eq 'MultiEdit') {
        $p = if ($ti.file_path) { [string]$ti.file_path } elseif ($ti.notebook_path) { [string]$ti.notebook_path } else { '' }
        $pn = ConvertTo-NormPath $p
        $rel = if ($rootN -and $pn.StartsWith($rootN + '/')) { $pn.Substring($rootN.Length + 1) } else { $pn }
        foreach ($pp in $protected) {
            if ($rel -eq $pp -or ($pp.EndsWith('/') -and $rel.StartsWith($pp))) {
                Write-Deny "'$rel' is protected (MASTER_PROMPT.md section 2, rule 21). Propose the change in docs/DECISIONS.md and ask under S1."
            }
        }
        if ($rel -match '(^|/)(\.env(\.[^/]*)?|[^/]*\.(pem|key|pfx|p12)|id_rsa[^/]*|id_ecdsa[^/]*|id_ed25519[^/]*)$' -or $rel -match '(^|/)secrets(/|$)') {
            Write-Deny "writing the secret-like path '$rel' is forbidden (rule 8)."
        }
    }
    exit 0
} catch {
    Write-Deny ("guard internal error (" + $_.Exception.Message + "), so the call is denied (fail closed).")
}
