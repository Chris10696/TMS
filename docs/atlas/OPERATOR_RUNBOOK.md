# ATLAS v2.0 — Operator Runbook (for you, the human)

This is everything **you** do. The agent never does any of it. Set aside about 45 minutes for steps 0 to 6.
Every command was checked against the official documentation on 29 Oct 2026, and the kit's safety scripts passed
64 of 64 self-test cases on this laptop.

> This is engineering guidance, not financial advice. Fund the system only with money you can afford to lose entirely
> (your stated USD 15).

## What is already in C:\TMS (prepared for you)

| Path | What it is |
|---|---|
| `MASTER_PROMPT.md` | The agent's governing instructions (ATLAS v2.0). Write-protected once armed |
| `docs/atlas/PROJECT_CONTEXT.md` | Your project's facts: video forensics, legacy EA audit, your decisions, Kenya, $15, hosting, and the earlier TMS build |
| `legacy/` | Your EA and the demo-only MT5 probe. `legacy/local-only/` (never pushed) holds third-party indicators, `.ex5` files and `START_TMS.md` |
| `docs/atlas/HARDENING_AUDIT.md` | What was wrong with v1.1 and how v2.0 fixes it, with sources |
| `docs/atlas/EVIDENCE_DIGEST.md` | The research facts behind the design |
| `.claude/hooks/*.ps1` | Four safety hooks: session orientation, tool guard, compaction snapshot, stop gate |
| `.claude/settings.atlas.json` | Hook and permission config. **Inactive until you copy it** to `settings.json` (step 4) |
| `.claude/agents/*.md` | Nine independent reviewer subagents (auditors cannot edit files) |
| `scripts/supervisor.ps1` | Keeps long unattended runs going across usage limits and crashes |
| `scripts/kit_selftest.ps1` | Proves the hooks and the supervisor work (64 cases) |
| `.gitignore` | Keeps data, logs, secrets and machine-local files out of git |

---

## Step 0. Safety checks (5 minutes)

1. **The MT5 terminal on this laptop must contain demo accounts only.** Open MetaTrader 5 → View → Navigator → Accounts.
   If a real-money account is listed, right-click it and choose **Delete** (this removes it from the terminal only, not from
   the broker). The agent's code refuses to trade anything except DEMO, but don't tempt fate.
2. **Disk space:** free at least 30 GB, or connect your external drive.
3. **Keep the laptop awake when plugged in:** Settings → System → Power & battery → Screen and sleep →
   "When plugged in, put my device to sleep after" → **Never**.

## Step 1. Install the tools (10 minutes)

Open **PowerShell** (Start → type "PowerShell"). Run each line separately:

```powershell
winget install Anthropic.ClaudeCode
```
```powershell
winget install --id=astral-sh.uv -e
```
```powershell
winget install --id yt-dlp.yt-dlp
```
For the secret scanner, search first and install the exact ID it shows (usually `Gitleaks.Gitleaks`):
```powershell
winget search gitleaks
```

Close PowerShell, open a **new** window, and check that each tool answers:
```powershell
claude --version
```
```powershell
uv --version
```
```powershell
yt-dlp --version
```

Why winget: winget packages are pinned and hash-checked, and they don't update silently in the middle of a run (upgrade
them yourself with `winget upgrade Anthropic.ClaudeCode` when you choose). The official alternative,
`irm https://claude.ai/install.ps1 | iex`, also works and auto-updates in the background.

## Step 2. Sign in and confirm your research connectors (5 minutes)

```powershell
cd C:\TMS
```
```powershell
claude
```
Inside Claude Code, type each of these and press Enter:
- `/status`: confirms you are signed in to your **paid** account (the free plan has no Claude Code).
- `/mcp`: you should see **Firecrawl, Exa and Parallel**, the connectors you added on claude.ai. Claude Code loads them
  automatically for a signed-in account.
- `/exit`

**Only if they are missing**, add the free keyless versions (rate-limited; Firecrawl's keyless mode has Search, Scrape and
Parse only). Don't add them if the connectors already appear, because duplicates cause confusion.
```powershell
claude mcp add --transport http --scope user parallel-search https://search.parallel.ai/mcp
```
```powershell
claude mcp add --transport http --scope user exa https://mcp.exa.ai/mcp
```
```powershell
claude mcp add --transport http --scope user firecrawl https://mcp.firecrawl.dev/v2/mcp
```

## Step 3. Finish the repository (2 minutes, one web page)

The local folder is already connected to `github.com/Chris10696/TMS`, and the clean work is on branch `main`.

1. Open the repository on GitHub → **Settings** → **General** → **Default branch**, and switch it to `main`.
2. On the same page, under **Danger Zone**, change the visibility to **Private**. The repository is public, so anyone can read
   your risk capital, your plans and, later, any results you push. Do this before pushing any strategy results.
3. Delete the old branch from Git Bash. GitHub refuses this until step 1 is done:

```bash
git -C /c/TMS push origin --delete codex/windows-handoff-2026-10-23
```

The agent commits locally on its own and can never push, rewrite history or skip hooks; the guard blocks all three. You push
when you choose.

**On another PC**, set the identity again after cloning, or your commits won't link to your account:
```bash
git clone https://github.com/Chris10696/TMS
```
```bash
git -C TMS config user.email "123624160+Chris10696@users.noreply.github.com"
```

## Step 4. Arm the guard rails (2 minutes, PowerShell)

```powershell
Copy-Item C:\TMS\.claude\settings.atlas.json C:\TMS\.claude\settings.json
```
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\TMS\scripts\kit_selftest.ps1
```
The last line must read **`ATLAS kit self-test: 64 passed, 0 failed, 64 total`**. If anything fails, stop and bring
the output to a Claude chat.

Commit the armed settings (Git Bash):
```bash
git add .claude/settings.json
```
```bash
git commit -m "G-LOCK arm ATLAS guard rails"
```
Mark this commit as the audit baseline. The agent's verify checks every change to protected files after this point, and the
guard stops the agent from moving or deleting the tag:
```bash
git tag atlas-baseline
```
Publish both:
```bash
git push origin main
```
```bash
git push origin atlas-baseline
```

The first time Claude Code opens C:\TMS after this, it asks you to **trust the project's hooks**. Say yes. From now on,
every Claude session in C:\TMS, including the desktop app, has the tool guard. The stop gate only activates when
`ATLAS_AUTONOMOUS=1` is set (step 6), so normal chats are never trapped.

## Step 5. Add your personal deny rules (3 minutes)

These live in your user settings, where the agent's project files cannot undo them. Your file currently holds only your
`attribution` setting, which is kept below.

```powershell
notepad $env:USERPROFILE\.claude\settings.json
```
Replace everything with this, save, and close:
```json
{
  "attribution": {
    "commit": "",
    "pr": "",
    "sessionUrl": false
  },
  "permissions": {
    "deny": [
      "Read(//c/TMS/**/.env)",
      "Read(//c/TMS/**/.env.*)",
      "Read(//c/TMS/**/secrets/**)",
      "Read(//c/TMS/**/*.pem)",
      "Read(//c/TMS/**/*.key)",
      "Read(~/.ssh/**)",
      "Read(//c/Users/*/AppData/Roaming/MetaQuotes/Terminal/*/config/**)",
      "Edit(//c/TMS/MASTER_PROMPT.md)",
      "Edit(//c/TMS/docs/GO_LIVE_APPROVAL.md)",
      "Edit(//c/TMS/.claude/settings.json)",
      "Edit(//c/TMS/.claude/settings.atlas.json)",
      "Edit(//c/TMS/.claude/hooks/**)",
      "Edit(//c/TMS/.atlas/locks.json)"
    ]
  }
}
```
These rules apply to every Claude session, including when you later ask a Claude chat to revise the master prompt. To allow
that, remove the `MASTER_PROMPT.md` line, make the change, then put the line back.

**Honest limit:** on native Windows, Claude Code has no operating-system sandbox. These rules and the guard stop Claude's
own tools and the shell commands it recognises, but a script that opens files by itself isn't covered. That's why the most
important rule is: **never keep real-money broker passwords on this laptop's main Windows user** (see step 9).

## Step 6. Launch Phase 0 (interactive, about 1 to 3 hours of agent work)

In PowerShell:
```powershell
cd C:\TMS
```
```powershell
$env:ATLAS_AUTONOMOUS = '1'; $env:CLAUDE_CODE_EFFORT_LEVEL = 'max'
```
```powershell
claude --permission-mode auto --model fable
```
(Use `--model opus` for Opus 5.5.) The desktop app's model picker also works, but the stop gate stays off there because
`ATLAS_AUTONOMOUS` isn't set, so use this command or the supervisor for unattended work. Then paste this launch line:

```text
Read MASTER_PROMPT.md completely and execute it, starting with Phase 0 (section 4). Follow section 3 (autonomy) and section 2 (non-negotiables). Ask me nothing until the Phase 0 discovery message.
```

What these settings do:
- **auto mode:** a safety classifier reviews actions instead of asking you each time.
- **max effort:** the deepest reasoning. The docs warn it can overthink, so the prompt directs depth to decisions and audits.
  `--effort ultracode` (xhigh plus planned workflows) is an alternative you can test later.
- **ATLAS_AUTONOMOUS=1:** arms the stop gate for this window only.

You can press **Esc** to interrupt at any time. `/exit` ends the session. To chat with Claude about the project without the
stop gate, open a new window without setting `ATLAS_AUTONOMOUS`.

Don't use `--dangerously-skip-permissions` (bypass mode) on this laptop. It belongs in a disposable VM with no personal
files, and the guard blocks the agent from using it.

## Step 7. Answer the discovery questions, then lock the rules

Phase 0 ends with `docs/NEEDS_HUMAN.md`, about seven short questions, each with a default. Answer them in the chat (typing
"go" accepts every default). The agent records your answers and continues to Phase 1.

Then **lock the acceptance thresholds and risk limits** so the agent can never relax them. In PowerShell:
```powershell
Set-Content -Path C:\TMS\.atlas\locks.json -Value '{"locked":["ACCEPTANCE.md","config/risk_limits.yaml"]}' -Encoding ASCII
```
Add these two lines inside the `deny` list of your user settings from step 5:
```text
"Edit(//c/TMS/ACCEPTANCE.md)",
"Edit(//c/TMS/config/risk_limits.yaml)",
```
Commit the lock (Git Bash):
```bash
git add .atlas/locks.json
```
```bash
git commit -m "G-LOCK lock acceptance thresholds and risk limits"
```

## Step 8. Long unattended runs (the supervisor)

When you want the agent to work for hours or overnight, close any interactive session and run:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\TMS\scripts\supervisor.ps1
```

- Each loop starts a fresh session that resumes from `docs/STATE.md`. Add `-Model fable` to run Fable 5.1.
- It **stops by itself** when the agent writes `docs/NEEDS_HUMAN.md`, when the work is done, after 3 loops with no new commit
  (stuck), or after 5 crashes in a row. It waits out usage limits (best effort).
- Logs are in `C:\TMS\logs\`, with full transcripts in `logs\runs\`.
- To stop it: press **Ctrl+C** in its window.
- Keep the laptop plugged in and awake. Your Claude plan has a rolling 5-hour limit and a weekly limit, which you can check
  with `/usage`. Max effort uses the allowance faster.
- `-MaxBudgetUsd 20` adds a spend cap, which only matters if you pay per token through the API.

## Step 9. Gates: what you'll be asked, and how to answer

| Gate | You'll be asked | What to do |
|---|---|---|
| Phase reports | Read `reports/gates/PHASE_N.md` | Read the 10-line summary. For an independent check, paste the report into a separate Claude chat and ask it to audit the report |
| G-SPEND | To approve a purchase | Say no unless it's clearly worth it; nothing is needed before Phase 7 |
| G-BROKER | To choose the CMA-licensed broker | Check the licence yourself on the CMA register (cma.or.ke) and confirm the entity name in the client agreement |
| G-ACCEPT | To relax a threshold or raise risk | The agent must show the ruin odds in USD. Default answer: **no** |
| G-LIVE | First real-money order | See below |
| G-SCALE / G-RESUME | More risk / restart after a halt | Read why before saying yes |

**G-LIVE preparation (Phase 7, not before):**
1. Create a separate, non-admin Windows user for live trading (Settings → Accounts → Other users), for example `atlas-live`.
   Separate Windows users give **real operating-system isolation**, which Claude Code's deny rules can't on native Windows.
2. Log in as that user, install MT5 there, and log into your real **cent** account there only. Never run Claude Code as that user.
3. Write `docs/GO_LIVE_APPROVAL.md` yourself:
   ```text
   # GO-LIVE APPROVAL
   Operator: <your name>
   Date: <date>
   Broker: <name>, CMA licence <number>, verified on cma.or.ke on <date>
   Account binding: <SHA-256 of "LOGIN|SERVER", computed with the command below>
   Approved ladder step: 1 (25% of the governor's risk)
   Maximum loss I accept this month: USD <amount>
   I have read reports/gates/GO_LIVE_CHECKLIST.md: yes
   Signature: <typed name>
   ```
   Compute the account binding in PowerShell. Replace LOGIN and SERVER, and don't paste the result into any chat:
   ```powershell
   $s = 'LOGIN|SERVER'; ([BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($s)))).Replace('-','').ToLower()
   ```
4. In the `atlas-live` user's PowerShell window only, before starting the live engine:
   ```powershell
   $env:ATLAS_LIVE = 'I_ACCEPT_REAL_MONEY_RISK'
   ```
   Never use `setx` for this, and never set it in the build user's environment.

## Emergency stop

1. Press **Ctrl+C** in the supervisor window and type `/exit` in any Claude session.
2. In MT5, click the **Algo Trading** button so it turns red. This stops all automated trading in that terminal.
3. Once Phase 5 exists, the kill switch also works: `scripts\kill_drill.ps1` and the documented kill file.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `claude` not recognised | Open a new PowerShell window; if it's still missing, re-run step 1 |
| Connectors missing in `/mcp` | Make sure you're signed in to the same account as claude.ai, or use the keyless commands in step 2 |
| Self-test fails | Don't launch. Bring the output to a Claude chat |
| Claude keeps refusing to stop when you just want to talk | You started it with `ATLAS_AUTONOMOUS=1`. Open a new window without it |
| "ATLAS guard: ..." blocks something you want | It's working. If the agent truly needs it, it must ask you (S1); you decide |
| Supervisor says another instance is running | Close the other window. A leftover lock from a crash is detected and removed automatically |
| A hook error appears in the transcript | Check `C:\TMS\.atlas\hook-errors.log` |
