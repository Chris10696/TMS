# TMS: Project ATLAS

An automated, risk-governed FX trading system for MetaTrader 5.

**Status:** planning and safety kit complete; Phase 0 has not started. No strategy has been validated and nothing trades.
Profitability is unproven until a strategy passes every test in `MASTER_PROMPT.md`.

## Start here (Fable 5.1)

Run this on the Windows laptop that has MT5, because the MT5 Python package only works on Windows. Finish
[the operator runbook](docs/atlas/OPERATOR_RUNBOOK.md) first, then paste:

```text
Read MASTER_PROMPT.md completely and execute it, starting with Phase 0 (section 4). Follow section 3 (autonomy) and section 2 (non-negotiables). Ask me nothing until the Phase 0 discovery message.
```

## What's here

| Path | Purpose |
|---|---|
| [`MASTER_PROMPT.md`](MASTER_PROMPT.md) | The agent's governing instructions (ATLAS v2.0) |
| [`docs/atlas/OPERATOR_RUNBOOK.md`](docs/atlas/OPERATOR_RUNBOOK.md) | Everything the owner does, step by step |
| [`docs/atlas/PROJECT_CONTEXT.md`](docs/atlas/PROJECT_CONTEXT.md) | Owner decisions, video forensics, legacy audit, broker and capital facts, the earlier build |
| [`docs/atlas/HARDENING_AUDIT.md`](docs/atlas/HARDENING_AUDIT.md) | What changed from v1.1 and why |
| [`docs/atlas/EVIDENCE_DIGEST.md`](docs/atlas/EVIDENCE_DIGEST.md) | The evidence behind the design |
| `.claude/hooks/`, `.claude/settings.atlas.json` | Safety hooks and their config, **inactive until armed** (runbook step 4) |
| `.claude/agents/` | Nine independent reviewers |
| `scripts/` | Unattended-run supervisor and the kit self-test |
| `legacy/` | The owner's old EA and a demo-only MT5 probe, for reference only |

## Flags: needed before Phase 0

| Needed | Who | Status |
|---|---|---|
| Set the default branch to `main`, delete the old branch, make the repository private | Owner | **Open** (runbook step 3) |
| Install Claude Code CLI, `uv`, `yt-dlp`, gitleaks | Owner | **Open** (step 1) |
| Sign in and confirm the Firecrawl, Exa and Parallel connectors load | Owner | **Open** (step 2) |
| Arm the guard rails and run the self-test | Owner | **Open** (step 4) |
| Add personal deny rules | Owner | **Open** (step 5) |
| Free about 30 GB of disk, or connect an external drive | Owner | **Open** |
| Keep MT5 logged in to a demo account only | Owner | In place at last check |

## Flags: needed during the build

| Needed | When | Status |
|---|---|---|
| Maximum drawdown you can tolerate, and whether you need a swap-free account | Phase 0 questions | **Open** |
| Lock `ACCEPTANCE.md` and `config/risk_limits.yaml` | After Phase 0 (step 7) | Not yet possible |
| A demo account at a CMA-licensed broker with an MT5 cent or micro account | Phases 1 to 3, for real cost data | **Open** |
| Telegram bot for alerts | Phase 6 | Not yet needed |
| Choice of live broker, and a separate Windows user for live trading | Phase 7 | Not yet needed |

## Kept out of this repository

| Item | Why | Where it is |
|---|---|---|
| Third-party indicators, compiled `.ex5` files, `START_TMS.md` | Licences unclear, or not needed | `legacy/local-only/` on the owner's machine |
| The earlier TMS build | Wiped at the owner's request | Local backup (see `PROJECT_CONTEXT.md` §7) |
| The four reference videos | Third-party content; their analysis is in `PROJECT_CONTEXT.md` §1 | Owner's Downloads folder |
| Market data, logs, secrets | Large or private | Never committed (`.gitignore`) |
