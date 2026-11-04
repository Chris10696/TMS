# ATLAS v1.1 → v2.0 Hardening Audit

**Date:** 29 Oct 2026 · **Scope:** the v1.1 master prompt (Parts 0, A and B) as supplied by the operator.
**Method:** every Claude Code mechanic was checked against the official documentation, fetched that day with the
operator's Firecrawl, Exa and Parallel connectors. Every tool and package claim was checked against PyPI, winget
manifests or vendor docs. The machine was inspected directly. The safety scripts were written and tested here:
`scripts/kit_selftest.ps1` passes **64 of 64** cases on Windows PowerShell 5.1.

**Verdict on v1.1:** a strong research and validation design. Its rigor on statistics, costs, risk and gates is the
right foundation, and v2.0 keeps all of it. Its weaknesses were in the **mechanics of autonomy and safety**: several
controls relied on the agent's honesty or on Claude Code behaviour that works differently from what it assumed. Two
were Sev-1, because they left real money protected only by an agent following instructions.

## Findings

Severity: Sev-1 could lose money or expose a secret; Sev-2 is a broken guarantee; Sev-3 is a correctness or
robustness gap; Sev-4 is a nit.

| ID | Sev | v1.1 said or did | What is actually true (evidence) | v2.0 fix |
|---|---|---|---|---|
| H01 | 1 | "Permissions: wide for research, hard-walled for secrets" through deny rules | On native Windows Claude Code has **no OS sandbox**. Read/Edit deny rules cover Claude's file tools and recognised shell commands, **not a subprocess that opens files itself** ([permissions docs](https://code.claude.com/docs/en/permissions); [setup docs](https://code.claude.com/docs/en/setup): sandboxing "Not supported" on native Windows) | §18.3 states the limit plainly. Live credentials are never on the build user. G-LIVE uses a **separate Windows user**, which is real OS isolation (runbook step 9) |
| H02 | 1 | Real money was gated only by an env var and an approval file "you never create", an honour system for an agent with a shell | Nothing in code stopped an order on a real account if the terminal was logged into one | **Rule 20 demo lock**: the adapter refuses every send unless the account trade mode is DEMO. **Live triple**: env var, plus an approval bound to `SHA-256(login\|server)`, plus an allow-list. The guard blocks any assignment of `ATLAS_LIVE` or its value (tests P02–P06). Trap 31 covers a shared terminal |
| H03 | 2 | `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP=200` "lets stop-hook loops run longer" | The cap counts consecutive blocks **without a tool call**, and the count resets every time Claude calls a tool ([hooks docs](https://code.claude.com/docs/en/hooks)). Eight in a row means the agent is stuck, so raising the cap only lets it spin and burn usage | Keep the default of 8. The supervisor's **progress watchdog** escalates to S4 after N iterations with no new commit (tests U02, U07) |
| H04 | 2 | The stop gate allowed stopping "if docs/NEEDS_HUMAN.md exists" | Trivially gameable: one line in a file buys an exit | The gate requires `S-CODE`, `EVIDENCE` and `NEXT` lines (§21), and rule 22 forbids escape writes (tests G05, G06) |
| H05 | 2 | The stop gate applied to every session in the folder | It would trap every ordinary chat, including the desktop app, in C:\TMS | Active only when `ATLAS_AUTONOMOUS=1` (tests G01, S02) |
| H06 | 2 | "PreCompact forces a STATE.md handoff" | A PreCompact hook can only **block** compaction, which is unsafe when context is full ([hooks docs](https://code.claude.com/docs/en/hooks), exit-code table) | PreCompact writes a non-blocking snapshot; SessionStart (matcher `compact`) re-orients (tests C01, S01) |
| H07 | 2 | The agent wrote its own stop gate and guard in Phase 0, and could edit them later | Self-written, self-editable guard rails police nothing | The kit is **pre-built and tested** (64 cases). Its files are protected by the guard, project deny rules and user deny rules. The **operator arms it** (runbook step 4) |
| H08 | 2 | ACCEPTANCE.md and risk caps "change only by ADR" | No technical control; the agent could edit them and write an ADR | Operator lock (`.atlas/locks.json` plus user deny rules). The verify protected-file audit (§20.6). Gate reports list every protected-file commit (§14) (tests P35, P36) |
| H09 | 2 | No rule against weakening checks | The most common reward hack for autonomous agents: skip a test, lower a threshold, get green | Rule 18. Verify fails on skips or xfails in the protected suites (§20.2) |
| H10 | 2 | The holdout was "touched once", by honour | No mechanism | A sealed loader that writes a `holdout_unseal` registry entry, plus a static check in verify (§7, §20.8) |
| H11 | 2 | The experiment registry could be rewritten | Deflated significance is only as honest as the trial count | Verify checks the registry is append-only (§20.7) |
| H12 | 3 | The supervisor ran `--continue` every loop | One ever-growing session; the handoff files are never tested | Fresh session per loop by default; STATE.md is the single source of truth; `-ContinueSession` is optional (test U06) |
| H13 | 3 | The supervisor passed its whole environment to the agent | An `ATLAS_LIVE` set in the parent would reach the agent | The child environment drops `ATLAS_LIVE` and sets `ATLAS_AUTONOMOUS=1` (test U01) |
| H14 | 3 | No stuck detection, only "5 consecutive failures" | A stuck agent exits 0 every time and never trips a failure counter | No-commit watchdog (U02, U07); crash limit (U04); single-instance lock (U05) |
| H15 | 3 | Step 2 added Firecrawl, Exa and Parallel with `claude mcp add` | The operator already has them as **claude.ai connectors**, which Claude Code loads automatically for a signed-in account (`ENABLE_CLAUDEAI_MCP_SERVERS`, [env-vars docs](https://code.claude.com/docs/en/env-vars)). Duplicates confuse tool routing (Firecrawl's docs say to keep one), and Firecrawl's keyless endpoint has only Search, Scrape and Parse ([Firecrawl docs](https://docs.firecrawl.dev/mcp-server/keyless)) | Use the connectors; keyless endpoints are a fallback only (runbook step 2, §17) |
| H16 | 3 | Project allow rules `mcp__parallel-search`, etc. | They don't match connector tool names, and allow-listing MCP tools wholesale is the opposite of least privilege | Removed. Auto mode's classifier reviews MCP calls |
| H17 | 3 | User-scope deny rules like `Read(**/.env)` | A bare pattern anchors to the **current directory** ([permissions docs](https://code.claude.com/docs/en/permissions): "How path patterns match") | Absolute `//c/TMS/**` patterns (runbook step 5) |
| H18 | 3 | Project at `C:/dev/atlas`; Python 3.12 assumed necessary | The project already lives in `C:\TMS`, with recorded decisions (now in `docs/atlas/PROJECT_CONTEXT.md`). MetaTrader5 5.0.6231 (27 Sep 2026) has wheels for **cp310 to cp314** (PyPI) | Root `C:\TMS`. 3.12 is kept for ecosystem maturity, not as a hard constraint. the old plan's §13 layout superseded |
| H19 | 3 | A generic operator; Phase 0 asked six questions | The operator had already decided Kenya/CMA, USD 15, cent account, no prop firms, laptop hosting and no Deriv synthetics | §1.2 operator-facts table; discovery asks only what is still open (§4.0.6) |
| H20 | 3 | Pre-flight assumed `claude`, `uv` and `yt-dlp` exist | **Measured:** `claude` not on PATH; `uv`, `yt-dlp`, `pwsh` and `gh` missing; Python 3.12.10 present; Windows PowerShell 5.1 | Runbook step 1, with winget IDs verified (`Anthropic.ClaudeCode`, `astral-sh.uv`, `yt-dlp.yt-dlp`) |
| H21 | 3 | Recommended `irm … \| iex` while banning "pipe a download into a shell" | Self-contradictory; winget manifests pin and hash the binaries and don't auto-update mid-run | winget recommended, the official installer offered as an alternative; the guard blocks pipe-to-shell by the agent (P17) |
| H22 | 3 | Hard per-trade cap of 3% by default | At Micro tier, with an edge estimated from a few hundred trades, 3% leaves little room for estimation error | Default 2%; up to 3% only through G-ACCEPT (§9) |
| H23 | 3 | No broker-choice gate; no lock gate | Kenyan clients need a CMA-licensed broker the operator verifies; protected-file changes need an owner | G-BROKER and G-LOCK (§13); rule 24 |
| H24 | 3 | "max effort" presented as strictly better | The docs say max "may show diminishing returns and is prone to overthinking" ([model-config docs](https://code.claude.com/docs/en/model-config)); `CLAUDE_CODE_EFFORT_LEVEL` overrides `--effort` | §16 directs depth to decisions and audits; subagents set effort per role in frontmatter; ultracode noted as an option |
| H25 | 3 | The verify script was unspecified, yet the stop gate depended on "verify red/green" | The gate had no machine-readable signal to check | §20 verify contract; `artifacts/verify/last.json` bound to HEAD and git-ignored (committing it would change HEAD) (tests G07–G09) |
| H26 | 3 | Only PASS or FAIL | An under-powered result gets pushed toward PASS | An INCONCLUSIVE verdict that leads only to more demo forward testing (§8) |
| H27 | 3 | A "done" signal from STATE.md alone | An agent could declare DONE with open items | DONE also requires no open PLAN items, a clean tree and green verify for HEAD (tests G07a, G07b) |
| H28 | 3 | Tags weren't protected | Force-moving the baseline or gate tags would shrink the audit window | The guard blocks `git tag -f/-d` and allows creating tags (P16b, P16c); the operator sets `atlas-baseline` |
| H29 | 3 | PowerShell 5.1 specifics were absent | Under `$ErrorActionPreference='Stop'`, native stderr can become a terminating error; `>` writes UTF-16; `Set-Content` defaults to ANSI | All kit scripts relax the preference around native calls and set encodings; trap 33. The defect was found and fixed during kit construction |
| H30 | 4 | Cross-references (for example "section 2" for autonomy) | They broke after the new sections were added | Renumbered consistently: §2 rules, §3 autonomy, §20 verify, §21 schemas |
| H31 | 2 | Nothing protected who appears as a contributor | The earlier commit's email wasn't linked to any GitHub account (the API listed no contributors), and agent tooling can add `Co-Authored-By` lines, which GitHub counts as contributors | Commits use the operator's GitHub no-reply address. Rule 26, a guard check (P16d, P16e), a verify check (§20.9) and an empty `attribution` setting keep it that way |

## What v1.1 got right (kept unchanged in substance)

The evidence ladder and D-grade discipline; pre-registered kill criteria; the trial registry with DSR, PBO and SPA;
the monkey test and baselines; power analysis; era transfer and alpha decay; cost stress; the feasibility floor; the
evidence-based Risk Governor with fractional Kelly; the earn-your-risk ladder; the drawdown throttle; circuit breakers;
the MiFID II RTS 6-style controls; the hexagonal architecture with a broker capability profile; the order state
machine with idempotency and reconciliation; chaos tests; the subagent auditors; the retraction protocol; the
scorecard; and the human gates. These are the reasons ATLAS is worth running.

## Honest limits of this hardening

1. **The guard is defense in depth, not a wall.** A determined agent could write a script that opens files itself, and
   native Windows can't stop that. The layered answer is: no live credentials on the build user, the demo lock in code,
   human gates, git audit and independent replication.
2. **The hooks were tested by direct invocation, not inside a live Claude Code session.** The CLI isn't installed yet.
   Phase 0 step 0.1 makes the agent probe the live hooks and stop with S5 if they aren't active.
3. **Whether the claude.ai connectors load in headless `-p` runs** is expected from the docs but untested here. Phase 0
   step 0.2 checks it, and §17 gives the fallback.
4. **The supervisor's parsing of usage-limit messages is best effort,** because the message format isn't documented.
   When parsing fails, it waits 30 minutes and retries.
5. **Some figures in the evidence digest are carried over from v1.1** without re-verification, and they are labelled as such.
6. **No prompt can create an edge.** With USD 15, even an excellent system earns cents a month. ATLAS's value is finding
   out, cheaply and honestly, whether an edge exists before you add capital.
