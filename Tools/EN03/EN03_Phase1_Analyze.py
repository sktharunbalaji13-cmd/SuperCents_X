#!/usr/bin/env python3
"""
EN03_Phase1_Analyze.py - EN-03 Phase 1 population-invariance analysis.

Authorized research (docs/Sprint24_EN03_Assessment.md, Phase 1). Reads the
three arm artifacts produced by EN03_Phase1_Run.ps1 and answers ONE
question: does replacing the legacy trend-flip gate (or removing it)
change the strategy's populations over the frozen TT01 replay window?

Pipeline (hard gates, in order):
  GATE 1  VALIDITY: the LEGACY arm telemetry CSV must be byte-identical
           to the frozen golden Tools/TT01/artifacts/TT01_20260813_185122/
           telemetry_v5_default.csv. Any mismatch => the instrument is
           invalid (profile/wiring divergence); no population verdict.
  GATE 2  POPULATION: per-bar counters from en03_pop_<arm>.csv
           (cumulative columns are diffed per bar):
             trend transitions, gate flips, choch/bos/pp/ob/fvg/liq
             counts, signal bars
  GATE 3  ROW-LEVEL: telemetry CSV alignment (decisionId order) between
           arms: row counts + per-column divergence counts.

Verdict: POPULATION-INVARIANT (all deltas zero) vs SHIFTED (quantified).
STOP here; report + recommendation go to the user (no A/B selection).

Usage: python EN03_Phase1_Analyze.py  (run from Tools/EN03)
       python EN03_Phase1_Analyze.py --artifacts <dir> --golden <csv>
"""

import argparse
import csv
import os
import sys

ARMS = ["LEGACY", "OFF", "COORDINATED"]


def decode_text(data):
    """MQL5 FileWrite defaults to UTF-16LE; fall back to UTF-8 for
    externally-written files."""
    if data[:2] == b"\xff\xfe":
        return data.decode("utf-16")
    return data.decode("utf-8-sig", errors="replace")


def find_csv(art_dir, arm, prefix):
    """Return the single <prefix>_*.csv for an arm, or None."""
    d = os.path.join(art_dir, arm)
    if not os.path.isdir(d):
        return None
    for name in sorted(os.listdir(d)):
        if name.startswith(prefix) and name.endswith(".csv"):
            return os.path.join(d, name)
    return None


def read_csv(path):
    with open(path, "rb") as fh:
        text = decode_text(fh.read())
    return list(csv.reader(text.splitlines()))


def gate_validity(art_dir, golden):
    print("=" * 78)
    print("GATE 1  VALIDITY: LEGACY arm vs frozen TT01 golden")
    print("=" * 78)
    legacy = find_csv(art_dir, "LEGACY", "telemetry_v5")
    if legacy is None:
        print("FAIL  no LEGACY telemetry capture found in", art_dir)
        return False
    with open(legacy, "rb") as fh:
        run_bytes = fh.read()
    with open(golden, "rb") as fh:
        gold_bytes = fh.read()
    if run_bytes == gold_bytes:
        print("PASS  byte-identical (%d bytes, %s)" % (len(run_bytes), legacy))
        return True

    run_lines = decode_text(run_bytes).splitlines()
    gold_lines = decode_text(gold_bytes).splitlines()
    print("FAIL  NOT byte-identical: run=%d bytes %d lines | golden=%d bytes %d lines"
          % (len(run_bytes), len(run_lines), len(gold_bytes), len(gold_lines)))
    print("  run   :", legacy)
    print("  golden:", golden)

    #--- header / column divergence
    hdr_run = run_lines[0].split(",") if run_lines else []
    hdr_gold = gold_lines[0].split(",") if gold_lines else []
    if hdr_run != hdr_gold:
        print("  column divergence: run=%d cols golden=%d cols"
              % (len(hdr_run), len(hdr_gold)))
        for i, (a, b) in enumerate(zip(hdr_run, hdr_gold)):
            if a != b:
                print("    col %d: run='%s' golden='%s'" % (i, a, b))
        if len(hdr_run) != len(hdr_gold):
            for i in range(min(len(hdr_run), len(hdr_gold)), max(len(hdr_run), len(hdr_gold))):
                src = hdr_run if len(hdr_run) > len(hdr_gold) else hdr_gold
                print("    extra col %d in %s: '%s'"
                      % (i, "run" if len(hdr_run) > len(hdr_gold) else "golden", src[i]))

    #--- first differing data row
    n = min(len(run_lines), len(gold_lines))
    for i in range(1, n):
        if run_lines[i] != gold_lines[i]:
            r = run_lines[i].split(",")
            g = gold_lines[i].split(",")
            print("  first differing row: line %d (1-based)" % (i + 1))
            for j, (a, b) in enumerate(zip(r, g)):
                if a != b:
                    col = hdr_gold[j] if j < len(hdr_gold) else "?"
                    print("    col %d '%s': run='%s' golden='%s'" % (j, col, a, b))
            break
    if n - 1 >= 1 and all(run_lines[i] == gold_lines[i] for i in range(1, n)):
        print("  all shared data rows identical; difference is only in")
        print("  row count (run=%d golden=%d)" % (len(run_lines), len(gold_lines)))
    return False


def load_pop(path):
    """Return list of dict rows + header."""
    with open(path, "rb") as fh:
        text = decode_text(fh.read())
    rd = csv.DictReader(text.splitlines())
    return list(rd)


def intv(v):
    try:
        return int(v)
    except (TypeError, ValueError):
        return -1


def aggregate_pop(rows):
    """Cumulative columns are diffed per bar; totals across the run."""
    agg = {"bars": len(rows)}
    if not rows:
        return agg
    keys = ["bosCount", "chochCount", "ppCount", "obCount", "fvgCount",
            "liqCount", "flipGate", "flipCoord", "coordSkip"]
    for k in keys:
        vals = [intv(r[k]) for r in rows]
        deltas = [max(vals[i] - vals[i - 1], 0) for i in range(1, len(vals))]
        agg[k + "_deltaSum"] = sum(deltas)
        agg[k + "_final"] = vals[-1]
    trend = [intv(r["trend"]) for r in rows]
    agg["trendTransitions"] = sum(
        1 for i in range(1, len(trend)) if trend[i] != trend[i - 1] and trend[i - 1] >= 0)
    agg["signalBars"] = sum(1 for r in rows if intv(r["signalCount"]) >= 1)
    agg["firstTime"] = rows[0].get("time", "?")
    agg["lastTime"] = rows[-1].get("time", "?")
    return agg


def gate_population(art_dir):
    print()
    print("=" * 78)
    print("GATE 2  POPULATION: per-bar counters")
    print("=" * 78)
    pops = {}
    for arm in ARMS:
        p = find_csv(art_dir, arm, "en03_pop")
        if p is None:
            print("MISSING population capture for", arm)
            return None
        pops[arm] = aggregate_pop(load_pop(p))

    print("%-12s %8s %8s %8s %8s %8s %8s %8s %8s %8s %8s" %
          ("arm", "bars", "flipGt", "flipCd", "cSkip", "trTrn", "choch",
           "bos", "pp", "ob", "fvg"))
    for arm in ARMS:
        a = pops[arm]
        print("%-12s %8d %8d %8d %8d %8d %8d %8d %8d %8d %8d" %
              (arm, a["bars"], a["flipGate_deltaSum"], a["flipCoord_deltaSum"],
               a["coordSkip_deltaSum"], a["trendTransitions"],
               a["chochCount_final"], a["bosCount_final"], a["ppCount_final"],
               a["obCount_final"], a["fvgCount_final"]))
    base = pops["LEGACY"]
    shifted = []
    for arm in ("OFF", "COORDINATED"):
        a = pops[arm]
        diffs = []
        for k in ["flipGate_deltaSum", "flipCoord_deltaSum", "coordSkip_deltaSum",
                  "trendTransitions", "chochCount_final", "bosCount_final",
                  "ppCount_final", "obCount_final", "fvgCount_final",
                  "liqCount_final", "signalBars"]:
            if a.get(k, -1) != base.get(k, -2):
                diffs.append("%s %s->%s" % (k, base.get(k), a.get(k)))
        if diffs:
            shifted.append((arm, diffs))
        print("  %-12s vs LEGACY: %s" %
              (arm, "; ".join(diffs) if diffs else "NO DELTA"))
    return shifted


def gate_rowlevel(art_dir):
    print()
    print("=" * 78)
    print("GATE 3  ROW-LEVEL: telemetry alignment (decisionId order)")
    print("=" * 78)
    rows = {}
    for arm in ARMS:
        p = find_csv(art_dir, arm, "telemetry_v5")
        if p is None:
            print("MISSING telemetry capture for", arm)
            return None
        rows[arm] = read_csv(p)

    base = rows["LEGACY"]
    hdr = base[0]
    print("rows: LEGACY=%d OFF=%d COORDINATED=%d" %
          (len(base) - 1, len(rows["OFF"]) - 1, len(rows["COORDINATED"]) - 1))
    result = []
    for arm in ("OFF", "COORDINATED"):
        other = rows[arm]
        if other[0] != hdr:
            print("  %s: HEADER DIVERGES - not comparable" % arm)
            result.append((arm, "header-diverged"))
            continue
        if len(other) != len(base):
            result.append((arm, "row-count %d vs %d" % (len(other) - 1, len(base) - 1)))
        diverged_cols = {}
        n = min(len(base), len(other))
        row_diffs = 0
        for i in range(1, n):
            if base[i] != other[i]:
                row_diffs += 1
                for j, (a, b) in enumerate(zip(base[i], other[i])):
                    if a != b:
                        diverged_cols[hdr[j]] = diverged_cols.get(hdr[j], 0) + 1
        extra = max(len(base), len(other)) - n
        print("  %-12s rows-diff=%d (extra rows %d) cols-diff: %s" %
              (arm, row_diffs, extra,
               ", ".join("%s=%d" % (k, v) for k, v in sorted(diverged_cols.items()))
               if diverged_cols else "none"))
        if row_diffs or extra:
            result.append((arm, "rows-diff=%d" % row_diffs))
    return result


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("--artifacts", default="artifacts",
                    help="EN03 artifact root (default artifacts)")
    ap.add_argument("--golden",
                    default=r"..\TT01\artifacts\TT01_20260813_185122\telemetry_v5_default.csv")
    args = ap.parse_args()

    art_dir = args.artifacts
    golden = args.golden
    if not os.path.isdir(art_dir):
        print("FATAL artifact dir not found:", art_dir)
        sys.exit(2)
    if not os.path.isfile(golden):
        print("FATAL golden not found:", golden)
        sys.exit(2)

    valid = gate_validity(art_dir, golden)
    if not valid:
        print()
        print("VERDICT INVALID INSTRUMENT - population deltas untrustworthy;")
        print("fix profile/wiring divergence, rerun batch, re-analyze. STOP.")
        sys.exit(1)

    shifted = gate_population(art_dir)
    rows = gate_rowlevel(art_dir)

    print()
    print("=" * 78)
    if shifted is None or rows is None:
        print("INCOMPLETE - missing captures; re-run the batch.")
        sys.exit(1)
    if not shifted and not rows:
        print("VERDICT POPULATION-INVARIANT (all deltas zero).")
        sys.exit(0)
    print("VERDICT SHIFTED (quantified above). Report to user; STOP;")
    print("no A/B selection without authorization.")
    sys.exit(0)


if __name__ == "__main__":
    main()
