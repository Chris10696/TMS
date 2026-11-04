# ATLAS v2.0 — Evidence Digest (for the human; not part of the agent prompt)

Each item is marked **VERIFIED 2026-10-29** (re-checked at the source) or **CARRIED OVER** (from v1.1, not re-checked).

## Base rate
- **CARRIED OVER.** UK and EU rules make CFD brokers publish the share of retail accounts that lose money. Reported figures
  cluster in the 70s and 80s (IC Markets 73.42%, CMC Markets 73%, Trade Nation 86%, as shown on BrokerChooser in May 2026),
  and the FCA has cited roughly 80%. Treat "most accounts lose" as the prior. Sources: BrokerChooser risk-warning pages;
  FCA Handbook COBS 22.5.

## Over-sizing
- **VERIFIED (mathematics).** In the continuous approximation, growth is g(f) ∝ 2f/f\* − (f/f\*)². It peaks at the Kelly
  fraction f\*, falls to zero at 2f\*, and half-Kelly keeps 75% of the peak growth. Because the edge is estimated with error,
  ATLAS sizes from the lower confidence bound and caps at half-Kelly. Source: stat.berkeley.edu/~aldous/157/Papers/Good_Bad_Kelly.pdf.

## Overfitting
- **CARRIED OVER.** Bailey and López de Prado show that ignoring the number of trials inflates results. The Deflated Sharpe
  Ratio (papers.ssrn.com/abstract=2460551) and the Probability of Backtest Overfitting
  (escholarship.org/content/qt4w1110bb/qt4w1110bb.pdf) are the standard corrections. Hence the trial registry.

## FX edges
- **VERIFIED.** Menkhoff, Sarno, Schmeling and Schrimpf, *Currency Momentum Strategies*, BIS Working Paper 366 (Dec 2011): a
  cross-sectional spread "of up to 10% p.a." between past winner and loser currencies, "partially explained by transaction
  costs", with "very effective limits to arbitrage". The sample covered **up to 48 currencies, 1976–2010**. A seven-major
  retail universe cannot replicate it.
  [bis.org/publ/work366.htm](https://www.bis.org/publ/work366.htm)
- **CARRIED OVER.** A study of emerging-currency momentum (1985–2009) found 1–3% a year after costs, decaying, and mostly
  negative in its final five years (University of Otago archive).
- Treat trend, momentum and carry as hypotheses to test, never as promises.

## Institutional controls
- **CARRIED OVER.** Regulated algorithmic traders under MiFID II RTS 6 run pre-trade limits, real-time monitoring, a kill
  function and non-live testing. ATLAS mirrors that structure in sections 9 and 10.

## Platform
- **VERIFIED.** MetaTrader5 5.0.6231 (released 27 Sep 2026) ships Windows-only wheels for CPython 3.6 to 3.14, including
  cp312 and cp314 ([PyPI JSON](https://pypi.org/pypi/MetaTrader5/json)). Hence the isolated MT5 adapter, with the rest
  kept portable.
- **VERIFIED.** This laptop has Python 3.12.10, Git for Windows and Windows PowerShell 5.1. It is missing the `claude`
  CLI, `uv`, `yt-dlp`, PowerShell 7 and `gh`. MT5 is installed, logged into Deriv-Demo, with about 231 ms ping.

## Claude Code mechanics (all VERIFIED 2026-10-29 at code.claude.com)
| Claim | Finding | Source |
|---|---|---|
| Permission modes | `default` (alias `manual`), `acceptEdits`, `plan`, `auto`, `dontAsk`, `bypassPermissions`. Bypass is for isolated containers or VMs only. Deny rules apply in every mode | [permission-modes](https://code.claude.com/docs/en/permission-modes) |
| Auto mode in `claude -p` | Supported with `--permission-mode auto`. When repeated blocks reach a threshold, the action doesn't run and Claude keeps working | same |
| Effort | `--effort low/medium/high/xhigh/max/ultracode`. `CLAUDE_CODE_EFFORT_LEVEL` overrides the flag. max applies to the current session only unless set by the env var. Opus 5.5 defaults to medium. The docs say max "is prone to overthinking" | [model-config](https://code.claude.com/docs/en/model-config) |
| Stop hook | Block with `{"decision":"block","reason":...}` or exit 2. Input includes `stop_hook_active`. 8-consecutive-block cap, reset on every tool call, configurable with `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP` | [hooks](https://code.claude.com/docs/en/hooks) |
| PreToolUse | `hookSpecificOutput.permissionDecision: "deny"`. `onFailure: "block"` fails closed. Exec form (`command` + `args`) with `${CLAUDE_PROJECT_DIR}` | same |
| PreCompact | Can only block compaction (exit 2 or `decision: block`) | same |
| SessionStart | Matchers `startup`, `resume`, `clear`, `compact`, `fork`; stdout is added to context | same |
| Hooks on Windows | `"command":"powershell.exe"` with `"args":["-NoProfile","-ExecutionPolicy","Bypass","-File",...]` is the documented pattern | same |
| Deny-rule paths | Gitignore syntax. `//` is absolute, `~/` is home, `/` is relative to the settings file, a bare pattern is relative to cwd. On Windows, `C:\` becomes `/c/`. Rules don't cover subprocesses that open files themselves | [permissions](https://code.claude.com/docs/en/permissions) |
| Sandbox | Not supported on native Windows (supported on WSL 2) | [setup](https://code.claude.com/docs/en/setup) |
| CLI flags | `-p`, `-c/--continue` (includes `-p` sessions when used with `-p`), `--max-turns`, `--max-budget-usd` (print mode), `--model` aliases `opus`, `sonnet`, `haiku`, `fable` | [cli-reference](https://code.claude.com/docs/en/cli-reference) |
| MCP | `claude mcp add --transport http --scope user NAME URL`; `--header` for keys; `MAX_MCP_OUTPUT_TOKENS` (default 25,000); claude.ai connectors load for logged-in users (`ENABLE_CLAUDEAI_MCP_SERVERS`) | [mcp](https://code.claude.com/docs/en/mcp), [env-vars](https://code.claude.com/docs/en/env-vars) |
| Subagents | `.claude/agents/*.md` with frontmatter `name`, `description`, `tools`, `disallowedTools`, `model`, `effort`, `isolation: worktree`, and more. Nesting up to 3 levels | [sub-agents](https://code.claude.com/docs/en/sub-agents) |
| Install | `irm https://claude.ai/install.ps1 \| iex`, or `winget install Anthropic.ClaudeCode` (winget installs don't auto-update) | [setup](https://code.claude.com/docs/en/setup) |

## Research connectors (VERIFIED 2026-10-29)
- **Parallel Search:** `https://search.parallel.ai/mcp`, free and anonymous, rate-limited
  ([docs.parallel.ai](https://docs.parallel.ai/integrations/mcp/search-mcp)).
- **Exa:** `https://mcp.exa.ai/mcp`; OAuth via `?login` or an `x-api-key` header
  ([exa.ai docs](https://exa.ai/docs/reference/exa-mcp)).
- **Firecrawl:** keyless `https://mcp.firecrawl.dev/v2/mcp` (Search, Scrape and Parse only, rate-limited); OAuth
  `.../v2/mcp-oauth` for the full tool set ([docs.firecrawl.dev](https://docs.firecrawl.dev/mcp-server/keyless)).
- The operator's claude.ai connectors for all three are already connected and are the preferred path.

## Tooling (VERIFIED 2026-10-29)
- winget IDs: `Anthropic.ClaudeCode` (github.com/anthropics/claude-code README), `astral-sh.uv` (docs.astral.sh),
  `yt-dlp.yt-dlp` (microsoft/winget-pkgs manifests). The gitleaks ID is not verified: run `winget search gitleaks`.
- Current versions: uv 0.13.6 and yt-dlp 2026.10.26 on PyPI.

## How to use YouTube
Use transcripts for hypothesis mining and implementation ideas only. Much trading content earns money from courses,
signals, EAs and broker affiliate links. The four videos reviewed on 9 Oct 2026 are analysed in `docs/atlas/PROJECT_CONTEXT.md` §1.
A claim counts as evidence only after it survives your own out-of-sample test with costs.
