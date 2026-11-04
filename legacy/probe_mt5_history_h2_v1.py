#!/usr/bin/env python3
"""Probe 12 fixed one-minute history windows using an existing MT5 demo terminal.

Standalone Windows helper: no TMS imports, trading calls, credentials, prices or
account identifiers. The injectable run_probe entry point supports Linux tests.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from datetime import datetime, timedelta, timezone
from decimal import Decimal, InvalidOperation
from numbers import Integral
from pathlib import Path
from typing import Any

UTC = timezone.utc
EPOCH = datetime(1970, 1, 1, tzinfo=UTC)
TOOL_VERSION = "1.0.0"
REPORT_NAME = "history-availability.json"
WINDOW_SECONDS = 60
MAX_RETURNED_ROWS = 50_000
COHORTS = (
    ("development-candidate", "2026-01-01", "2026-04-01", ("2026-01-06", "2026-03-30")),
    ("validation-candidate", "2026-04-01", "2026-07-01", ("2026-04-07", "2026-06-29")),
    ("holdout-candidate", "2026-07-01", "2026-09-01", ("2026-07-07", "2026-08-28")),
)
SAMPLE_TIMES = ("08:00", "09:30")


class ProbeError(Exception):
    """A failure message that does not expose vendor details or account identity."""


def _field(record: Any, name: str) -> Any:
    try:
        return getattr(record, name)
    except AttributeError:
        try:
            return record[name]
        except (KeyError, IndexError, TypeError, ValueError):
            raise ProbeError("MT5 returned an incomplete response.") from None


def _integer(value: Any, *, minimum: int = 0) -> int:
    if isinstance(value, bool) or not isinstance(value, Integral) or value < minimum:
        raise ProbeError("MT5 returned an invalid integer field.")
    return int(value)


def _decimal(value: Any) -> str:
    try:
        result = Decimal(str(value))
    except (InvalidOperation, ValueError, TypeError):
        raise ProbeError("MT5 returned an invalid specification field.") from None
    if not result.is_finite() or result <= 0:
        raise ProbeError("MT5 returned an invalid specification field.")
    return str(result)


def _currency(value: Any) -> str:
    if not isinstance(value, str) or not re.fullmatch(r"[A-Z]{3,8}", value):
        raise ProbeError("MT5 returned an invalid account currency.")
    return value


def _iso(value: datetime) -> str:
    return value.astimezone(UTC).isoformat(timespec="milliseconds").replace("+00:00", "Z")


def _error_code(mt5: Any) -> int | None:
    """Keep only the numeric code; vendor messages may contain private details."""
    try:
        value = mt5.last_error()[0]
        return int(value) if isinstance(value, Integral) and not isinstance(value, bool) else None
    except Exception:
        return None


def sample_windows() -> tuple[dict[str, Any], ...]:
    """The fixed proposal is deliberately not an arbitrary history-export API."""
    windows = []
    for cohort, _, _, dates in COHORTS:
        for date in dates:
            for time in SAMPLE_TIMES:
                start = datetime.fromisoformat(f"{date}T{time}:00+00:00")
                windows.append({"cohort": cohort, "start": start,
                                "end": start + timedelta(seconds=WINDOW_SECONDS)})
    return tuple(windows)


def _guard(mt5: Any, original_identity: tuple[Any, Any, str] | None = None) -> tuple[Any, Any, str]:
    """Identity stays in memory solely to reject a terminal/account switch."""
    account = mt5.account_info()
    if account is None:
        raise ProbeError("No logged-in account is available; open your existing demo terminal.")
    if _integer(_field(account, "trade_mode")) != mt5.ACCOUNT_TRADE_MODE_DEMO:
        raise ProbeError("Probe refused: the connected MT5 account is not DEMO.")
    terminal = mt5.terminal_info()
    if terminal is None or _field(terminal, "connected") is not True:
        raise ProbeError("Probe refused: the MT5 terminal is not connected.")
    identity = (_field(account, "login"), _field(account, "server"),
                _currency(_field(account, "currency")))
    if original_identity is not None and identity != original_identity:
        raise ProbeError("The connected MT5 account changed; no report was saved.")
    return identity


def _specification(info: Any, symbol: str) -> dict[str, Any]:
    if info is None or _field(info, "name") != symbol:
        raise ProbeError("The exact symbol is unavailable; check its Market Watch spelling.")
    result = {"digits": _integer(_field(info, "digits")),
              "point": _decimal(_field(info, "point")),
              "tick_size": _decimal(_field(info, "trade_tick_size")),
              "tick_value_loss": _decimal(_field(info, "trade_tick_value_loss")),
              "volume_min": _decimal(_field(info, "volume_min")),
              "volume_step": _decimal(_field(info, "volume_step")),
              "volume_max": _decimal(_field(info, "volume_max"))}
    if result["digits"] > 16 or Decimal(result["volume_max"]) < Decimal(result["volume_min"]):
        raise ProbeError("MT5 returned an invalid current symbol specification.")
    return result


def _sample(mt5: Any, symbol: str, window: dict[str, Any],
            identity: tuple[Any, Any, str]) -> dict[str, Any]:
    start, end = window["start"], window["end"]
    result = {"cohort": window["cohort"], "requested_start_utc": _iso(start),
              "requested_end_exclusive_utc": _iso(end), "status": "not_requested",
              "returned_count": None, "in_window_count": None,
              "outside_window_count": None, "first_observed_utc": None,
              "last_observed_utc": None, "error_code": None}
    _guard(mt5, identity)
    # MT5 uses inclusive endpoints. Exclude the next minute by one millisecond.
    try:
        rows = mt5.copy_ticks_range(symbol, start, end - timedelta(milliseconds=1), mt5.COPY_TICKS_INFO)
    except Exception:
        result.update(status="api_exception", error_code=_error_code(mt5))
        _guard(mt5, identity)
        return result
    error_code = _error_code(mt5) if rows is None else None
    _guard(mt5, identity)
    if rows is None:
        result.update(status="api_returned_none", error_code=error_code)
        return result
    try:
        count = len(rows)
        result["returned_count"] = count
        if count >= MAX_RETURNED_ROWS:
            result["status"] = "row_limit_reached"
            return result
        first, last, valid_count, previous = None, None, 0, None
        start_ms = int((start - EPOCH).total_seconds()) * 1000
        end_ms = int((end - EPOCH).total_seconds()) * 1000
        for row in rows:
            stamp = _integer(_field(row, "time_msc"))
            if previous is not None and stamp < previous:
                raise ProbeError("MT5 returned unordered sample timestamps.")
            previous = stamp
            if start_ms <= stamp < end_ms:
                observed = EPOCH + timedelta(milliseconds=stamp)
                first = observed if first is None else first
                last = observed
                valid_count += 1
        result.update(status="observed" if valid_count else ("empty" if count == 0 else "outside_window_only"),
                      in_window_count=valid_count, outside_window_count=count - valid_count,
                      first_observed_utc=_iso(first) if first else None,
                      last_observed_utc=_iso(last) if last else None)
    except Exception:
        # No repr(), traceback, raw row, price or vendor exception is retained.
        result.update(status="invalid_response", in_window_count=None,
                      outside_window_count=None, first_observed_utc=None, last_observed_utc=None)
    return result


def run_probe(mt5: Any, output: Path | str, *, symbol: str = "EURUSD") -> dict[str, Any]:
    """Read 12 sparse windows, then exclusively create one privacy-limited report.

    No successful output is retained after a demo/account/connection guard fails.
    This is not a completeness test or approval to ingest historical prices.
    """
    if not isinstance(symbol, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,47}", symbol):
        raise ProbeError("Use the exact short Market Watch symbol, including its suffix.")
    output = Path(output)
    if output.exists() or output.is_symlink():
        raise ProbeError("Output directory already exists; choose a new directory.")
    if not output.parent.is_dir():
        raise ProbeError("The output parent directory must already exist.")
    attempted_initialize = False
    created_directory = False
    created_report = False
    try:
        attempted_initialize = True
        if not mt5.initialize():
            code = _error_code(mt5)
            raise ProbeError(f"Cannot connect to the existing MT5 terminal (error code {code}).")
        identity = _guard(mt5)
        captured_at = _iso(datetime.now(UTC))
        specification = _specification(mt5.symbol_info(symbol), symbol)
        _guard(mt5, identity)
        results = [_sample(mt5, symbol, window, identity) for window in sample_windows()]
        _guard(mt5, identity)
        report = {
            "schema_version": 1,
            "source": "mt5-demo-sparse-history-probe",
            "tool": {"version": TOOL_VERSION,
                     "source_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest()},
            "created_at_utc": _iso(datetime.now(UTC)),
            "symbol": symbol,
            "account": {"trade_mode": "DEMO", "currency": identity[2]},
            "terminal": {"connected": True},
            "current_specification_captured_at_utc": captured_at,
            "current_symbol_specification": specification,
            "probe_parameters": {
                "window_seconds": WINDOW_SECONDS, "window_count": len(results),
                "inclusive_api_end_adjustment_milliseconds": -1,
                "request_flags": "COPY_TICKS_INFO", "row_guard_per_request": MAX_RETURNED_ROWS,
                "sample_times_utc": list(SAMPLE_TIMES),
                "cohort_candidates": [{"name": name, "start_inclusive_utc": f"{start}T00:00:00Z",
                                       "end_exclusive_utc": f"{end}T00:00:00Z", "sample_dates_utc": list(dates)}
                                      for name, start, end, dates in COHORTS],
            },
            "samples": results,
            "summary": {"observed_windows": sum(r["status"] == "observed" for r in results),
                        "empty_windows": sum(r["status"] == "empty" for r in results),
                        "other_windows": sum(r["status"] not in {"observed", "empty"} for r in results)},
            "limitations": [
                "Sparse availability only: a nonempty sample does not establish complete cohort history.",
                "Empty or failed samples do not prove that an entire date block is unavailable.",
                "Dates are proposed fresh blocks for this project, not proof the owner has never inspected them.",
                "Current symbol specifications are not historical specifications or a dated session calendar.",
                "Holiday exceptions, full range/signal coverage, counts and research splits remain unverified.",
                "No historical prices, trading signals, returns, orders or profit assessment are saved.",
                "Host collection timestamps are not independently synchronized broker timestamps.",
            ],
        }
        # Delay creation until all reads and final guards pass. Exclusive creation
        # protects existing data, including a directory raced into place mid-run.
        output.mkdir()
        created_directory = True
        with (output / REPORT_NAME).open("x", encoding="utf-8", newline="\n") as handle:
            created_report = True
            json.dump(report, handle, indent=2, sort_keys=True, allow_nan=False)
            handle.write("\n")
        return report
    except ProbeError:
        raise
    except Exception:
        raise ProbeError("Read-only probe failed; vendor and filesystem details suppressed.") from None
    finally:
        if sys.exc_info()[0] is not None and created_directory:
            if created_report:
                try:
                    (output / REPORT_NAME).unlink(missing_ok=True)
                except OSError:
                    pass
            try:
                output.rmdir()
            except OSError:
                pass
        if attempted_initialize:
            try:
                mt5.shutdown()
            except Exception:
                pass


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--symbol", default="EURUSD", help="Exact current demo-account symbol (default: EURUSD).")
    parser.add_argument("--output", type=Path, required=True, help="New report directory; its parent must exist.")
    args = parser.parse_args(argv)
    try:
        if sys.platform != "win32":
            raise ProbeError("Run this helper on the Windows computer hosting your existing MT5 demo terminal.")
        try:
            import MetaTrader5 as mt5
        except ImportError:
            raise ProbeError("Use the existing .venv-mt5 Python with the installed MetaTrader5 package.") from None
        except Exception:
            raise ProbeError("The MetaTrader5 package could not load; vendor details suppressed.") from None
        run_probe(mt5, args.output, symbol=args.symbol)
    except ProbeError as exc:
        print(f"Probe failed: {exc}", file=sys.stderr)
        return 1
    print("Read-only probe complete. Review history-availability.json before sharing that file only.")
    print("Sparse samples do not establish complete history or strategy profitability. Keep Algo Trading off.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
