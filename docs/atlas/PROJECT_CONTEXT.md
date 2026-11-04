# TMS / ATLAS — Project Context (input dossier for the agent)

Compiled 2026-10-29, updated 2026-11-05, from this project's record of work on 9 and 11 Oct 2026. On 29 Oct, `docs/MASTER_PLAN.md` was no
longer present in C:\TMS (the whole `docs/` folder had been removed), so the facts ATLAS needs are restated here. These
are facts and decisions, not instructions. Where they conflict with MASTER_PROMPT.md, MASTER_PROMPT.md wins, except the
owner decisions in §3, which rank above the prompt body (MASTER_PROMPT.md §1.1).

## 1. Forensics of the social-media "bot" videos (reviewed frame by frame, 9 Oct 2026)

**"EA AUTOMATED TRADING BOT" (MT5 mobile, `XAUUSDm`, shown going from $10 to $97,842 in about 55 minutes):**
- The bot opened **bursts of 9 to 29 market orders in one direction** and closed the basket on a small combined profit.
  Positions had **no stop-loss and no take-profit**: a ticket shown at 5:09 had S/L and T/P empty.
- Lot sizes scaled with the balance: 0.01 → 0.02 → 0.12 → 0.34 → 1.34 → 6.34 per order, then more 6.34-lot orders.
- Exposure rebuilt from the on-screen margin divides into exact multiples of 6.34 lots at 1:1000 and 1:2000 leverage. For
  example, a margin of 88,486.29 equals 29 × 6.34 = 183.9 lots, about 18,400 oz of gold.
- The gold move needed to wipe out the **entire** account was about $0.55 (at $5 equity), $0.34 (at about $2.6k equity)
  and about $5 (at $48k to $90k equity). The margin level reached 61% with free margin at −$7,082. It survived only
  because the broker's stop-out level was 0%.
- About 22 all-in cycles were shown. Under a driftless random walk the survival odds are **well under 1%**. Verdict: this
  is gambling with automation attached; it cannot be replicated and must never be built. The ambition to keep is
  automation and compounding; the methods are rejected.

**"Krypt Trader" (an LLM multi-agent desk on Kalshi prediction markets):** a research → strategy → backtest → council vote
→ execution pipeline, with a "who called it?" accuracy board. The narrator says the visuals are "bullshit". Keep the
pipeline and the per-source accuracy tracking. A 64% win rate on binary contracts proves nothing without the entry prices.

**"6 Grok bots turned $89 into $68,024":** an engagement funnel ("comment GROK"). The useful idea is separation of
duties (scan, size, enter, book, kill chases). The claim that it works "the same on $89 as on $68k" is false because of
liquidity and slippage.

**"4 videos that make you good at trading in 24 hours":** ICT/smart-money family methods (TTrades fractal model, MMXM, GxT
sequence) plus Rande Howell's trading psychology. These are discretionary. Codifiable parts to test objectively: session
ranges, prior-day and session highs and lows, liquidity sweeps, time windows, displacement and fair-value gaps.
Psychology point: automation removes emotion from execution, but not the operator's urge to override the bot.

## 2. Legacy EA audit

`legacy/` in this repository holds the operator's EA and the demo-only probe. Every other file below is third-party or
compiled, so it stays on the operator's machine in `legacy/local-only/` (git-ignored). This audit is what you need from them.

| File | Verdict | Defects → regression-test ideas |
|---|---|---|
| `MomentumPatternEA_Final_Confirmed_VisualsPiercing.mq5` | Retire | (a) `IsBearNarami()` can never be true (it requires o2 > c2 > c1 > o1 > o2). (b) The "EMA cross" actually compares the RSI(14) and RSI(7) arrays; the EMA handles are never read. (c) It reads the forming bar (CopyBuffer from shift 0, non-series arrays). (d) The MaxTrades check runs once, then up to 9 patterns can each open a trade on the same candle, including Dark Cloud + Bear Piercing double sells and a simultaneous buy and sell. (e) TrailingStart and TrailingStep are declared but never implemented. (f) Lots are rounded to *price digits* rather than the volume step, with no max-volume check. (g) A fixed 2000-point SL/TP: $2 on 3-digit gold but 200 pips on EURUSD. (h) No magic number. (i) Trade results are ignored, with no filling mode, spread, session or news filter. (j) Engulfing and piercing rules require price gaps that rarely occur intraday |
| `Indicator_Arrows.mq5` | Misleading | **Repaints**: with a higher timeframe selected, history is stamped with the higher-timeframe bar's *final* value (look-ahead), and live arrows appear and disappear |
| `QQE.mq5` | Visual only | Creates a new RSI handle on every tick without releasing it; alerts from the forming bar |
| `AMA.mq5` | Correct | Stock Kaufman adaptive MA; usable as a trend-filter component |
| `candle_timer.mq5` | Cosmetic | Harmless |
| `Breakout.ex5`, `Trend_Angle.ex5` | Black box | No source; default wizard copyright, so the real author is unknown. Never run with money |
| `JFHighLow.ex5`, `JFDailyOpenLine.ex5`, `Shved supply and demand.ex5` | Visual only | Reference levels and fractal zones; historical zones were not all visible in real time |

## 3. Owner decisions

| ID | Decision | Answer | Date |
|---|---|---|---|
| D1 | Jurisdiction | Kenya: real money only at a **CMA-licensed** broker | 2026-10-11 |
| D2 | Risk capital | **USD 15**: a cent or micro account is mandatory; live micro is an execution test, not income | 2026-10-11 |
| D3 | Prop firms | **No** | 2026-10-11 |
| D4 | Swap-free | **Pending** (explained in §6) | — |
| D5 | Hosting | Laptop until hosting costs less than 10% of expected monthly profit | 2026-10-11 |
| D6 | Git | The operator runs the initial git commands personally; under ATLAS the agent commits locally and never pushes | 2026-10-11, 2026-10-29 |
| D7 | Disk | The operator frees about 30 GB or uses an external drive | 2026-10-11 |
| D8 | Instruments | **Deriv synthetic indices are banned**: Deriv states they come from a random number generator | 2026-10-09 |
| D9 | Earlier build | **ATLAS supersedes it.** Wiped from GitHub; a local backup remains (§7) | 2026-11-05 |
| D10 | Contributors | The operator is the **only contributor**: operator identity on every commit, no AI attribution (rule 26) | 2026-11-05 |

## 4. Kenya broker landscape (as reported by secondary sources on 2026-10-11; verify each on the CMA register)

Brands named as CMA-licensed: FXPesa (EGM Securities, licence 107), Scope Markets (SCFM, 123), Pepperstone Markets Kenya
(128), FXTM (Exinity Capital East Africa, 135), HFM Investments, Windsor Markets (Kenya), XM (reported licensed Feb 2026),
and Exness (sources conflict on the entity; reported licence 162). **No evidence of a CMA licence for Deriv**, which serves
Kenyans through offshore entities. The secondary sources report CMA leverage of up to 1:400, which is irrelevant to ATLAS.
Selection checklist: licence verified on the register; MT5; a **cent or micro account on MT5 for the Kenyan entity**; M-Pesa
deposits and withdrawals, including the KES/USD conversion rate; spread plus commission measured on demo; swaps;
execution quality; ping.

## 5. What USD 15 can and cannot do (ASSUMED until recomputed from real symbol specifications)

| Instrument | Account | Max stop at 0.25% risk | Max stop at 0.5% risk | Verdict |
|---|---|---|---|---|
| EURUSD | Standard ($15) | 0.4 pip | 0.75 pip | Impossible |
| Gold | Standard ($15) | $0.04 | $0.075 | Impossible |
| EURUSD | Cent (1,500 USC) | 37.5 pips | 75 pips | Feasible for H1–H4 FX |
| Gold | Cent | $3.75 | $7.50 | Too tight; needs about $60 or more on cent |

At 2% a month, $15 earns about $0.30 a month; 3 years of compounding gives about $30. The value of this phase is evidence,
not income.

## 6. Hosting and swaps

- **Hosting:** laptop now ($0; fine for H1+ strategies at 231 ms ping; broker-side stops protect open positions if the
  laptop sleeps). MetaQuotes virtual hosting costs $15 a month (no DLLs, no Python, no remote desktop). A Windows VPS costs
  about $15–40 a month. Rule: pay for hosting only when it costs less than 10% of expected monthly profit, which at 2% a
  month means about $7,500 of capital.
- **Swaps:** an overnight financing charge or credit at the daily rollover (often 3× on Wednesday for FX). A swap-free
  ("Islamic") account removes interest, usually in exchange for fees or wider spreads. This matters only for strategies
  that hold positions overnight.

## 7. Earlier TMS build (Codex, October 2026; superseded by ATLAS)

- **Where it is:** wiped from GitHub on the operator's instruction on 2026-11-05 (one commit, `ea2b6be`, 277 files, branch
  `codex/windows-handoff-2026-10-23`). A verified full backup stays on the operator's machine at
  `%USERPROFILE%\TMS-backups\remote-before-wipe-2026-11-05\TMS-full-history.bundle`. Work after 23 Oct (the "TMS Paper"
  desktop app, the v3 paper continuation, the first broker test) is described in `legacy/local-only/START_TMS.md`, but its
  files were not found on this machine.
- **What it was:** an offline research foundation, a read-only MT5 demo exporter, a bounded quote observer and an
  experimental paper engine. It had no broker-order gateway and no fundamental analysis.
- **Its reported findings (ASSUMED: not re-verified here):** a candle-pattern reference lost hypothetical equity in every
  tested case on 4,569,925 EURUSD quotes (7 Sep to 12 Oct 2026), including a zero-additional-commission diagnostic. A short
  SMA/momentum rule with ATR protection had "no demonstrated profitable edge". A USD 10,000 paper account stood near
  USD 9,996 after two closed trades totalling USD -2.76. Unmonitored gaps caused paper losses beyond the planned stop risk,
  which supports broker-side stops and the laptop-sleep traps.
- **What this means for ATLAS:** those EURUSD windows are already seen. Its January to March development cohort and April to
  June validation cohort were evaluated; its July to August holdout was reported unopened. Do not treat seen windows as
  untouched for rules of the same family, and record those tests as prior trials in the registry.
- `legacy/probe_mt5_history_h2_v1.py` is a careful read-only, demo-only history probe: it refuses non-DEMO accounts, guards
  against the account changing mid-run, and saves no prices or identifiers. It is a good reference for rule 20.
- Import nothing from the backup unless the operator says so (S1). If that system is ever restored, its paper account's
  losses, fees and risk counters must not be reset.

## 8. Environment (measured)

Windows 11, i5-10310U, 15 GB RAM, local clock GMT+3, Windows PowerShell 5.1, Git for Windows, Python 3.12.10 (plus 3.14.6).
MT5 is installed (Deriv build 6182), logged into Deriv-Demo, with about 231 ms ping to the Ireland access server.
MetaTrader5 5.0.6231 has wheels for cp310 to cp314. Missing on 2026-10-29: the `claude` CLI on PATH, `uv`, `yt-dlp`,
PowerShell 7 and `gh`. The disk was 87% full on 2026-10-09.

Git identity for this repository: `123624160+Chris10696@users.noreply.github.com`, the operator's GitHub no-reply address. It
links every commit to the Chris10696 account and keeps private email out of a public repository. It is set in the local
repository config, so a fresh clone must set it again (`docs/atlas/OPERATOR_RUNBOOK.md` step 3).
