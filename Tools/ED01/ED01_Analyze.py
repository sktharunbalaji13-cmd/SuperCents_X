"""ED01-A analyzer: admission-floor grid vs B8 control.

Population: telemetry rows with newDecision==1 (NEW-mode qualified decisions).
Closed: outcome in (1,2,3). Censored (outcome 0) excluded from R statistics.

Metric: mean R per rule family (ruleName -> family via the frozen GR01
RULE_FAMILY mapping), delta vs the same-file CONTROL run, bootstrap 95% CI on
the delta (10,000 resamples, day-stratified/paired). Verdicts per protocol
section 8 + amendment 13.1 (2/2 H1 stability; EURUSD H1 primary; +0.05
meaningful effect; trade-count inflation guard; UNKNOWN and M15 evidence-only).

Usage: python ED01_Analyze.py [--artifacts <dir>] [--iters 10000] [--min-n 50]
"""
import argparse
import csv
import glob
import json
import os
import random
import sys

PROJECT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DEFAULT_ARTS = os.path.join(PROJECT, "Tools", "ED01", "artifacts")

RULE_FAMILY = {
    "LIQUIDITY_BOS_BULLISH": "LIQUIDITY",
    "LIQUIDITY_BOS_BEARISH": "LIQUIDITY",
    "OB_FVG_BULLISH": "FVG",
    "OB_FVG_BEARISH": "FVG",
    "BOS_OB_BULLISH": "BOS",
    "BOS_OB_BEARISH": "BOS",
    "CHOCH_OB_REVERSAL": "CHOCH",
}

B8_FLOOR = {"LIQUIDITY": 0.60, "FVG": 0.35, "BOS": 0.35, "CHOCH": 0.35,
            "ORDER_BLOCK": 0.35, "UNKNOWN": 0.35}
DECISION_FILES = ["EURUSD_H1", "GBPJPY_H1"]
PRIMARY_FILE = "EURUSD_H1"
MIN_MEANINGFUL_DELTA = 0.05
MIN_N_DECISION = 50
INFLATION_CAP = 1.25

DELTAS = {"LIQUIDITY": ["0.50", "0.55", "0.65", "0.70"],
          "FVG": ["0.25", "0.30", "0.40", "0.45"],
          "BOS": ["0.25", "0.30", "0.40", "0.45"],
          "CHOCH": ["0.25", "0.30", "0.40", "0.45"],
          "ORDER_BLOCK": ["0.25", "0.30", "0.40", "0.45"]}


def family_of(row):
    return RULE_FAMILY.get((row.get("ruleName") or "").strip(), "UNKNOWN")


def num(row, key):
    try:
        return float((row.get(key) or "0").strip())
    except ValueError:
        return 0.0


def day_of(row):
    return (row.get("timestamp") or "").split()[0]


def load_run(art_dir, file_key, config):
    d = os.path.join(art_dir, file_key, config)
    if not os.path.isfile(os.path.join(d, ".done")):
        return None
    rows = []
    for path in sorted(glob.glob(os.path.join(d, "telemetry_v4_*.csv"))):
        with open(path, newline="", encoding="utf-16") as fh:
            rows.extend(csv.DictReader(fh))
    fps = sorted({r.get("configFingerprint", "") for r in rows})
    return rows, fps


def fam_rows(rows, fam):
    """Qualified, family-filtered, closed rows."""
    return [r for r in rows
            if r.get("newDecision") == "1" and family_of(r) == fam
            and r.get("outcome") in ("1", "2", "3")]


def run_stats(rows, fam):
    c = fam_rows(rows, fam)
    n = len(c)
    if n == 0:
        return {"nPop": sum(1 for r in rows if r.get("newDecision") == "1"
                            and family_of(r) == fam),
                "nClosed": 0, "wr": None, "meanR": None, "medianR": None,
                "maxDD": None, "meanBars": None}
    vals = [num(r, "rMultiple") for r in c]
    wins = sum(1 for r in c if r.get("outcome") == "1")
    ordered = sorted(c, key=lambda r: (day_of(r), int(num(r, "decisionId"))))
    cum = peak = dd = 0.0
    for r in ordered:
        cum += num(r, "rMultiple")
        peak = max(peak, cum)
        dd = max(dd, peak - cum)
    sv = sorted(vals)
    mid = n // 2
    median = sv[mid] if n % 2 else (sv[mid - 1] + sv[mid]) / 2.0
    return {"nPop": sum(1 for r in rows if r.get("newDecision") == "1"
                        and family_of(r) == fam),
            "nClosed": n, "wins": wins, "wr": round(wins / n, 4),
            "meanR": round(sum(vals) / n, 4), "medianR": round(median, 4),
            "maxDD": round(dd, 4),
            "meanBars": round(sum(num(r, "barsHeld") for r in c) / n, 2)}


def by_day(rows, fam):
    out = {}
    for r in fam_rows(rows, fam):
        out.setdefault(day_of(r), []).append(num(r, "rMultiple"))
    return out


def day_stratified_delta_ci(ctl_rows, exp_rows, fam, iters):
    """Paired day-stratified bootstrap on the pooled mean-R delta (exp - ctl).

    Protocol 7: bootstrap CI on per-family mean R, stratified by day. The same
    day set is resampled for both runs; each sampled day contributes its rows
    (ctl and exp), and the pooled mean-R difference is computed. Also returns
    the daily-mean-difference CI as an auxiliary view.
    """
    ctl = by_day(ctl_rows, fam)
    exp = by_day(exp_rows, fam)
    days = sorted(d for d in ctl if d in exp)
    if len(days) < 10:
        return None, None, len(days)
    n = len(days)
    diffs = []
    dmd = []
    for _ in range(iters):
        s = 0.0
        m = 0
        t = 0.0
        for _ in range(n):
            d = days[random.randrange(n)]
            a = ctl[d]
            b = exp[d]
            for v in a:
                s -= v
                m += 1
            for v in b:
                s += v
                m += 1
            t += (sum(b) / (len(b) or 1)) - (sum(a) / (len(a) or 1))
        diffs.append(s / max(m, 1))
        dmd.append(t / n)
    diffs.sort()
    dmd.sort()
    k = iters // 40
    return ({"lo": diffs[k], "hi": diffs[iters - k - 1]},
            {"lo": dmd[k], "hi": dmd[iters - k - 1]}, len(days))


def verdict(exp_stats, ctl_stats, ci, min_n):
    """Per protocol 8 + amendment 13.1. Returns (verdict, reason)."""
    n1 = exp_stats.get(PRIMARY_FILE, {}).get("nClosed", 0)
    if n1 < min_n:
        return "KEEP", "n<%d on %s (report only)" % (min_n, PRIMARY_FILE)
    if not ci:
        return "KEEP", "no paired days for CI on %s" % PRIMARY_FILE
    delta1 = exp_stats[PRIMARY_FILE]["meanR"] - ctl_stats[PRIMARY_FILE]["meanR"]
    if abs(delta1) < MIN_MEANINGFUL_DELTA:
        return "KEEP", "|delta|%.4f < 0.05 on %s" % (delta1, PRIMARY_FILE)
    if delta1 < 0:
        return "KEEP", "negative delta %.4f (floor change worsens)" % delta1
    if ci["lo"] <= 0.0:
        return "KEEP", "CI includes 0: [%.4f, %.4f]" % (ci["lo"], ci["hi"])
    signs = []
    stable = True
    for f in DECISION_FILES:
        if f not in exp_stats:
            continue
        d = exp_stats[f]["meanR"] - ctl_stats[f]["meanR"]
        signs.append("%s:%+.4f" % (f, d))
        stable = stable and d > 0
    if not stable:
        return "KEEP", "H1 direction not 2/2 (%s)" % ", ".join(signs)
    if any(exp_stats[f]["nClosed"] > INFLATION_CAP * ctl_stats[f]["nClosed"]
           for f in DECISION_FILES if f in exp_stats):
        return "DEFER", "trade-count inflation >%d%%: %s" % (INFLATION_CAP * 100, ", ".join(signs))
    return "REJECT", "delta=%.4f CI=[%.4f, %.4f] 2/2 (%s)" % (
        delta1, ci["lo"], ci["hi"], ", ".join(signs))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--artifacts", default=DEFAULT_ARTS)
    ap.add_argument("--iters", type=int, default=10000)
    ap.add_argument("--min-n", type=int, default=MIN_N_DECISION)
    ap.add_argument("--json", default=None)
    args = ap.parse_args()
    random.seed(20260809)

    files = [f for f in sorted(os.listdir(args.artifacts))
             if os.path.isdir(os.path.join(args.artifacts, f))]
    if not files:
        print("no run dirs under %s" % args.artifacts)
        return 1
    first_cfg_dir = os.path.join(args.artifacts, files[0])
    configs = [c for c in sorted(os.listdir(first_cfg_dir))
               if os.path.isdir(os.path.join(first_cfg_dir, c))]

    runs = {}
    for f in files:
        for c in configs:
            loaded = load_run(args.artifacts, f, c)
            if loaded:
                rows, fps = loaded
                runs[(f, c)] = rows
                if len(fps) > 1:
                    print("WARN  %s/%s multiple fingerprints: %s" % (f, c, fps))

    if not runs:
        print("no completed runs (no .done markers)")
        return 1

    stats_all = {(f, c): {fam: run_stats(rows, fam)
                          for fam in set(family_of(r) for r in rows)}
                 for (f, c), rows in runs.items()}
    families = sorted({fam for st in stats_all.values() for fam in st})

    ctl = "CONTROL"
    if (files[0], ctl) not in runs:
        print("CONTROL run missing for %s" % files[0])
        return 1

    print("== ED01-A screening (3-month window) - families: %s ==" % ", ".join(families))
    print()
    verdicts = {}
    for fam in families:
        floor = B8_FLOOR.get(fam, 0.35)
        deltas = DELTAS.get(fam, [])
        if not deltas:
            print("FAMILY %s (evidence-only, no grid)" % fam)
            for f in files:
                st = stats_all.get((f, ctl), {}).get(fam)
                if st:
                    print("  %-10s nClosed=%-5d meanR=%-8s wr=%s" %
                          (f, st["nClosed"], st["meanR"], st["wr"]))
            print()
            continue
        print("FAMILY %s (B8 floor %s)" % (fam, floor))
        print("  %-10s %-10s %-7s %-9s %-10s %-24s %-7s %s" %
              ("config", "file", "nClosed", "meanR", "medianR", "delta(CI)", "wr", "maxDD"))
        ci_store = {}
        for cfg in [ctl] + ["%s_%s" % (fam, d) for d in deltas]:
            for f in files:
                if (f, cfg) not in runs:
                    continue
                st = stats_all[(f, cfg)].get(fam)
                if not st:
                    continue
                base = stats_all.get((f, ctl), {}).get(fam)
                dstr = "-"
                ci = None
                if cfg != ctl and base and st["meanR"] is not None:
                    ci, dci, ndays = day_stratified_delta_ci(runs[(f, ctl)], runs[(f, cfg)], fam, args.iters)
                    ci_store[(f, cfg)] = (ci, ndays)
                    if ci:
                        d = st["meanR"] - base["meanR"]
                        dstr = "%+.4f [%.4f, %.4f] d=%d" % (d, ci["lo"], ci["hi"], ndays)
                        if dci and (dci["lo"] > 0 or dci["hi"] < 0):
                            dstr += " dCI=[%.4f, %.4f]" % (dci["lo"], dci["hi"])
                    else:
                        dstr = "n.d. (days<10)"
                print("  %-10s %-10s %-7d %-9s %-10s %-24s %-7s %s" %
                      (cfg, f, st["nClosed"], st["meanR"], st["medianR"], dstr, st["wr"], st["maxDD"]))
            if cfg != ctl:
                exp_stats = {f: stats_all[(f, cfg)].get(fam)
                             for f in files if (f, cfg) in runs and fam in stats_all[(f, cfg)]}
                ctl_stats = {f: stats_all[(f, ctl)].get(fam)
                             for f in files if (f, ctl) in runs and fam in stats_all[(f, ctl)]}
                if exp_stats and ctl_stats and PRIMARY_FILE in exp_stats and PRIMARY_FILE in ctl_stats:
                    ci, _ = ci_store.get((PRIMARY_FILE, cfg), (None, 0))
                    v, reason = verdict(exp_stats, ctl_stats, ci, args.min_n)
                    verdicts[(fam, cfg)] = v
                    print("    verdict %-10s : %s" % (cfg, reason))
        print()

    print("== verdicts (KEEP = keep B8 floor; REJECT = change floor; DEFER) ==")
    for (fam, cfg), v in sorted(verdicts.items()):
        print("  %-12s %-8s -> %s" % (fam, cfg, v))
    if args.json:
        with open(args.json, "w") as fh:
            json.dump({"stats": {("%s/%s" % k): st for k, st in stats_all.items()},
                       "verdicts": {("%s/%s" % k): v for k, v in verdicts.items()}},
                      fh, indent=1)
        print("wrote %s" % args.json)
    return 0


if __name__ == "__main__":
    sys.exit(main())
