# GR02B - canonical funnel analytics (Sprint 20, GR02B)
# ======================================================
# The project's funnel dashboard layer. Reads a v4 telemetry CSV and
# produces, per family:
#   - stage table: fired -> qualified -> closed (simulated / live)
#   - reject reason buckets (Spread / Confidence / Session / Risk / Other)
#   - conversion rates (qualified/fired, closed/qualified, ...)
#   - confidence histograms (accepted vs rejected, floor-relevant bins)
#   - simulated vs live availability (live columns are "Not yet available"
#     until GR02A-populated rows exist; never invented values)
#
# Data-model boundaries (schema v4, 75 cols - no schema bump):
#   - fired    : every telemetry row (a decision tick)
#   - qualified: validatorResults contains no "=2" (full chain admission)
#   - entered  : NOT in v4 schema (no order lifecycle per decision) -> n/a
#   - filled   : NOT in v4 schema -> n/a
#   - closed   : sim  = outcomeSource==1 && outcome in {1,2,3}
#                live = actualOutcomeSource==2 && actualOutcome in {1,2,3}
#   - wr       : WIN/(WIN+LOSS); BREAKEVEN excluded from the denominator
#   - mean/median R: over closed rows (live R not in schema -> n/a)
#
# Golden reference (mirrors TT01 baseline discipline):
#   - --write-golden <dir> freezes funnel_B8.csv (stable, diffable) and
#     funnel_B8.json (structured) - e.g. Tools/TT01/baseline/
#   - --compare <new.csv> --golden <dir> [--expected <json>] diffs a new
#     run against the golden funnel; deltas are classified EXPECTED
#     (declared via the expected-deltas file) vs UNEXPECTED (exit 1).
#
# Usage:
#   python gr02_funnel.py <csv> [--report <dir>] [--write-golden <dir>]
#   python gr02_funnel.py <csv> --compare --golden <dir> [--expected <exp.json>]
#
# Mirrors Tools/GR01/gr01_funnel.py conventions (utf-16 CSVs, ruleName ->
# family mapping, wr = WIN/(WIN+LOSS), report.md + data.json).

import argparse
import csv
import json
import math
import os
import sys

FAMILIES = ["LIQUIDITY", "FVG", "BOS", "CHOCH", "UNKNOWN", "ORDER_BLOCK"]

RULE_FAMILY = {
    "LIQUIDITY_BOS_BULLISH": "LIQUIDITY",
    "LIQUIDITY_BOS_BEARISH": "LIQUIDITY",
    "OB_FVG_BULLISH": "FVG",
    "OB_FVG_BEARISH": "FVG",
    "BOS_OB_BULLISH": "BOS",
    "BOS_OB_BEARISH": "BOS",
    "CHOCH_OB_REVERSAL": "CHOCH",
}

VALIDATOR_BUCKET = {
    "SpreadValidator": "Spread",
    "ConfluenceValidator": "Confidence",
    "SessionValidator": "Session",
    "RiskValidator": "Risk",
}

STAGES = ["fired", "qualified", "entered", "filled", "closed_sim", "closed_live"]
METRICS = ["count", "pct", "wr", "mean_r", "median_r"]
SIDES = ["sim", "live"]

HIST_BINS = [0.30 + 0.05 * i for i in range(11)]  # left edges 0.30..0.80


def family_of(row):
    name = (row.get("ruleName") or "").strip()
    return RULE_FAMILY.get(name, "UNKNOWN")


def num(row, key):
    try:
        v = row.get(key)
        if v is None:
            return 0.0
        v = v.strip()
        return float(v) if v != "" else 0.0
    except ValueError:
        return 0.0


def qualified_and_reason(row):
    vrs = (row.get("validatorResults") or "").strip()
    if vrs == "":
        return True, None
    for pair in vrs.split("|"):
        name, _, val = pair.partition("=")
        if val.strip() == "2":
            return False, name.strip()
    return True, None


def median(values):
    n = len(values)
    if n == 0:
        return None
    s = sorted(values)
    if n % 2 == 1:
        return s[n // 2]
    return (s[n // 2 - 1] + s[n // 2]) / 2.0


def stage_stats(rows, outcome_key):
    wins = sum(1 for r in rows if r.get(outcome_key, "") == "1")
    losses = sum(1 for r in rows if r.get(outcome_key, "") == "2")
    decided = wins + losses
    rm = [num(r, "rMultiple") for r in rows if r.get("outcome", "") != ""]
    stats = {
        "count": len(rows),
        "wr": round(wins / decided, 4) if decided > 0 else None,
        "mean_r": round(sum(rm) / len(rm), 4) if rm else None,
        "median_r": round(median(rm), 4) if rm else None,
    }
    return stats


def stage_stats_actual(rows):
    wins = sum(1 for r in rows if r.get("actualOutcome", "") == "1")
    losses = sum(1 for r in rows if r.get("actualOutcome", "") == "2")
    decided = wins + losses
    return {
        "count": len(rows),
        "wr": round(wins / decided, 4) if decided > 0 else None,
        "mean_r": None,
        "median_r": None,
    }


def histogram(row, lo):
    c = num(row, "confidence")
    if c < lo:
        return -1
    return next((i for i in range(len(HIST_BINS) - 1) if c < HIST_BINS[i + 1]),
                len(HIST_BINS) - 1)


def build_funnel(rows):
    fam_rows = {fam: [] for fam in FAMILIES}
    fam_rows["ALL"] = rows
    for r in rows:
        fam_rows[family_of(r)].append(r)

    report = {"overall": {}, "families": {}}

    for fam in FAMILIES + ["ALL"]:
        fr = fam_rows[fam]
        fired = len(fr)
        qualified_rows = []
        reject_buckets = {"Spread": 0, "Confidence": 0, "Session": 0, "Risk": 0,
                          "Other": 0}
        rejected_total = 0
        accepted_hist = [0] * len(HIST_BINS)
        rejected_hist = [0] * len(HIST_BINS)
        for r in fr:
            ok, reason = qualified_and_reason(r)
            b = histogram(r, HIST_BINS[0])
            if b >= 0:
                if ok:
                    accepted_hist[b] += 1
                else:
                    rejected_hist[b] += 1
            if ok:
                qualified_rows.append(r)
            else:
                rejected_total += 1
                bucket = VALIDATOR_BUCKET.get(reason, "Other")
                reject_buckets[bucket] = reject_buckets.get(bucket, 0) + 1

        closed_sim = [r for r in fr
                      if r.get("outcomeSource", "") == "1"
                      and r.get("outcome", "") in ("1", "2", "3")]
        closed_live = [r for r in fr
                       if r.get("actualOutcomeSource", "") == "2"
                       and r.get("actualOutcome", "") in ("1", "2", "3")]

        stages = {
            "fired": {"count": fired},
            "qualified": {"count": len(qualified_rows)},
            "entered": {"count": None},
            "filled": {"count": None},
            "closed_sim": stage_stats(closed_sim, "outcome"),
            "closed_live": stage_stats_actual(closed_live),
        }

        conv = {}
        if fired > 0:
            conv["qualified_over_fired"] = round(len(qualified_rows) / fired, 4)
        else:
            conv["qualified_over_fired"] = None
        conv["entered_over_qualified"] = None
        conv["filled_over_entered"] = None
        if len(qualified_rows) > 0:
            conv["closed_sim_over_qualified"] = round(len(closed_sim) / len(qualified_rows), 4)
            conv["closed_live_over_qualified"] = round(len(closed_live) / len(qualified_rows), 4)
        else:
            conv["closed_sim_over_qualified"] = None
            conv["closed_live_over_qualified"] = None

        report["families"][fam] = {
            "stages": stages,
            "rejects": {
                "total": rejected_total,
                "buckets": reject_buckets,
            },
            "histograms": [
                {
                    "lo": HIST_BINS[i],
                    "hi": HIST_BINS[i + 1] if i < len(HIST_BINS) - 1 else None,
                    "accepted": accepted_hist[i],
                    "rejected": rejected_hist[i],
                }
                for i in range(len(HIST_BINS))
            ],
            "conversions": conv,
        }

    report["overall"] = report["families"]["ALL"]
    return report


def report_family_key(family):
    return "ALL" if family == "ALL" else family


def rows_for_csv(report):
    out = []
    for fam in ["ALL"] + FAMILIES:
        famrep = report_family_key(fam)
        stages = report["families"][famrep]["stages"]
        for stage in STAGES:
            s = stages[stage]
            for m in METRICS:
                for side in SIDES:
                    val = None
                    if m == "count":
                        if side == "sim" and stage in ("fired", "qualified", "closed_sim"):
                            val = s.get("count")
                        elif side == "live" and stage == "closed_live":
                            val = s.get("count")
                    elif side == "sim" and m in ("wr", "mean_r", "median_r"):
                        val = s.get(m)
                    elif side == "live" and m == "wr" and stage == "closed_live":
                        val = s.get(m)
                    out.append({
                        "family": fam,
                        "stage": stage,
                        "metric": m,
                        "side": side,
                        "value": "" if val is None else ("%.4f" % val),
                    })
    return out


def fmt(v):
    return "-" if v is None else ("%.4f" % v)


def fmt_int(v):
    return "-" if v is None else str(v)


def write_report(report, rows, total, src, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    lines = []
    lines.append("# GR02B - Canonical Funnel Report")
    lines.append("")
    lines.append("- Source: `%s` (%d rows)" % (src, total))
    lines.append("- Generated by: `Tools/GR02/gr02_funnel.py`")
    lines.append("- wr = WIN/(WIN+LOSS); BREAKEVEN excluded from the denominator")
    lines.append("- entered/filled: not present in the v4 schema (no per-decision order lifecycle) -> n/a")
    lines.append("- live: `actualOutcomeSource == 2` (GR02A); absent until live rows exist -> Not yet available")
    lines.append("")
    lines.append("## 1. Per-family stage funnel (Simulation / Live)")
    lines.append("")
    lines.append("| Family | Stage | Count (sim) | % | WR (sim) | Mean R (sim) | Median R (sim) | Live count | Live WR |")
    lines.append("|---|---|---|---|---|---|---|---|---|")
    for fam in ["ALL"] + FAMILIES:
        stages = report["families"][report_family_key(fam)]["stages"]
        for stage in STAGES:
            s = stages[stage]
            fired = report["families"][report_family_key(fam)]["stages"]["fired"]["count"]
            pct = ""
            if s.get("count") is not None and fired > 0:
                pct = "%.1f%%" % (100.0 * s["count"] / fired)
            live_count = s.get("count") if stage == "closed_live" else None
            live_wr = s.get("wr") if stage == "closed_live" else None
            lines.append("| %s | %s | %s | %s | %s | %s | %s | %s | %s |" % (
                fam, stage, fmt_int(s.get("count")), pct,
                fmt(s.get("wr")), fmt(s.get("mean_r")), fmt(s.get("median_r")),
                fmt_int(live_count), fmt(live_wr)))
    lines.append("")
    lines.append("## 2. Reject breakdown (first failing validator)")
    lines.append("")
    lines.append("| Family | Rejected | Spread | Confidence | Session | Risk | Other |")
    lines.append("|---|---|---|---|---|---|---|")
    for fam in ["ALL"] + FAMILIES:
        rj = report["families"][report_family_key(fam)]["rejects"]
        b = rj["buckets"]
        lines.append("| %s | %d | %d | %d | %d | %d | %d |" % (
            fam, rj["total"], b["Spread"], b["Confidence"], b["Session"],
            b["Risk"], b["Other"]))
    lines.append("")
    lines.append("## 3. Conversion rates")
    lines.append("")
    lines.append("| Family | Qualified/Fired | Entered/Qualified | Filled/Entered | Closed-sim/Qualified | Closed-live/Qualified |")
    lines.append("|---|---|---|---|---|---|")
    for fam in ["ALL"] + FAMILIES:
        c = report["families"][report_family_key(fam)]["conversions"]
        lines.append("| %s | %s | %s | %s | %s | %s |" % (
            fam, fmt(c["qualified_over_fired"]), fmt(c["entered_over_qualified"]),
            fmt(c["filled_over_entered"]), fmt(c["closed_sim_over_qualified"]),
            fmt(c["closed_live_over_qualified"])))
    lines.append("")
    lines.append("## 4. Confidence histograms (accepted vs rejected, 0.05 bins)")
    lines.append("")
    for fam in ["ALL"] + FAMILIES:
        hists = report["families"][report_family_key(fam)]["histograms"]
        lines.append("### %s" % fam)
        lines.append("")
        lines.append("| Bin lo | Bin hi | Accepted | Rejected |")
        lines.append("|---|---|---|---|")
        for h in hists:
            hi = ("%.2f" % h["hi"]) if h["hi"] is not None else "0.85+"
            lines.append("| %.2f | %s | %d | %d |" % (h["lo"], hi, h["accepted"], h["rejected"]))
        lines.append("")
    lines.append("## 5. Simulation vs Live availability")
    lines.append("")
    lines.append("| Metric | Simulation | Live |")
    lines.append("|---|---|---|")
    for metric in ["Fired", "Qualified", "Entered", "Filled", "Closed", "Win Rate", "Mean R", "Median R"]:
        sim = "available" if metric in ("Fired", "Qualified", "Closed", "Win Rate", "Mean R", "Median R") else "n/a (no order lifecycle in v4 schema)"
        live = "Not yet available" if metric != "Fired" and metric != "Qualified" else "available (funnel base)"
        if metric == "Closed":
            live = "Not yet available" if report["overall"]["stages"]["closed_live"]["count"] is None or report["overall"]["stages"]["closed_live"]["count"] == 0 else "available"
        if metric == "Win Rate":
            live = "Not yet available" if report["overall"]["stages"]["closed_live"]["wr"] is None else "available"
        if metric in ("Mean R", "Median R"):
            live = "n/a (schema stores actualOutcome only - no actual R column)"
        lines.append("| %s | %s | %s |" % (metric, sim, live))
    lines.append("")

    with open(os.path.join(out_dir, "gr02_funnel_report.md"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")

    report_out = {
        "schemaVersion": "gr02-funnel-v1",
        "dataset": {"source": src, "rows": total},
        "overall": report["overall"],
        "families": report["families"],
    }
    with open(os.path.join(out_dir, "gr02_funnel_data.json"), "w", encoding="utf-8") as fh:
        json.dump(report_out, fh, indent=2, sort_keys=True)


def load_rows(path):
    with open(path, newline="", encoding="utf-16") as fh:
        return [r for r in csv.DictReader(fh)]


def funnel_compare(report, golden_path, expected_path):
    with open(golden_path, "r", encoding="utf-8") as fh:
        golden = json.load(fh)

    expected = {}
    if expected_path:
        with open(expected_path, "r", encoding="utf-8-sig") as fh:
            expected = json.load(fh)

    def get(report_or_golden, fam, stage, metric, side):
        r = report_or_golden["families"][fam]["stages"][stage]
        if metric == "count":
            if side == "sim" and stage in ("fired", "qualified", "closed_sim"):
                return r.get("count")
            if side == "live" and stage == "closed_live":
                return r.get("count")
            return None
        if metric == "wr":
            if side == "sim" and stage in ("fired", "qualified", "closed_sim"):
                return r.get("wr")
            if side == "live" and stage == "closed_live":
                return r.get("wr")
            return None
        if metric in ("mean_r", "median_r") and side == "sim":
            return r.get(metric)
        return None

    def classify(key, old, new):
        exp = expected.get(key)
        if exp is None:
            return "UNEXPECTED"
        if isinstance(exp, dict):
            if exp.get("any") is True:
                return "EXPECTED"
            if "band" in exp:
                lo, hi = exp["band"]
                if new is not None and lo <= new <= hi:
                    return "EXPECTED"
            return "UNEXPECTED"
        if exp is None:
            return "EXPECTED" if new is None else "UNEXPECTED"
        if new is None:
            return "UNEXPECTED"
        return "EXPECTED" if abs(new - exp) < 1e-9 else "UNEXPECTED"

    deltas = []
    unexpected = 0
    for fam in ["ALL"] + FAMILIES:
        for stage in STAGES:
            for metric in METRICS:
                for side in SIDES:
                    old = get(golden, fam, stage, metric, side)
                    new = get(report, fam, stage, metric, side)
                    if old == new:
                        continue
                    key = "%s.%s.%s.%s" % (fam, stage, metric, side)
                    status = classify(key, old, new)
                    if status == "UNEXPECTED":
                        unexpected += 1
                    deltas.append((status, key, old, new))

    print("")
    print("=== Funnel comparison vs golden (%s) ===" % os.path.basename(golden_path))
    if not deltas:
        print("no deltas - funnel identical to golden")
    for status, key, old, new in deltas:
        print("  [%s] %s: %s -> %s" % (status, key,
                                       "-" if old is None else ("%.4f" % old),
                                       "-" if new is None else ("%.4f" % new)))
    print("unexpected deltas: %d" % unexpected)
    return unexpected


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("csv")
    ap.add_argument("--report", default=None, help="output dir for report.md + data.json")
    ap.add_argument("--write-golden", default=None, help="dir to freeze funnel_B8.csv/.json")
    ap.add_argument("--compare", action="store_true", help="compare against golden funnel")
    ap.add_argument("--golden", default=None, help="golden funnel_B8.json path")
    ap.add_argument("--expected", default=None, help="expected-deltas JSON (classification spec)")
    args = ap.parse_args()

    rows = load_rows(args.csv)
    print("loaded %d rows from %s" % (len(rows), args.csv))
    report = build_funnel(rows)

    out_dir = args.report or os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
                                          "Tools", "GR02", "reports")
    write_report(report, rows_for_csv(report), len(rows), args.csv, out_dir)
    print("saved: %s" % os.path.join(out_dir, "gr02_funnel_report.md"))
    print("saved: %s" % os.path.join(out_dir, "gr02_funnel_data.json"))

    if args.write_golden:
        os.makedirs(args.write_golden, exist_ok=True)
        with open(os.path.join(args.write_golden, "funnel_B8.csv"), "w", encoding="utf-8", newline="") as fh:
            w = csv.DictWriter(fh, fieldnames=["family", "stage", "metric", "side", "value"])
            w.writeheader()
            for r in rows_for_csv(report):
                w.writerow(r)
        report_out = {
            "schemaVersion": "gr02-funnel-v1",
            "dataset": {"source": os.path.basename(args.csv), "rows": len(rows)},
            "overall": report["overall"],
            "families": report["families"],
        }
        with open(os.path.join(args.write_golden, "funnel_B8.json"), "w", encoding="utf-8") as fh:
            json.dump(report_out, fh, indent=2, sort_keys=True)
        print("golden frozen: %s" % os.path.join(args.write_golden, "funnel_B8.csv"))

    if args.compare:
        if not args.golden:
            print("error: --compare requires --golden <funnel_B8.json>", file=sys.stderr)
            return 2
        unexpected = funnel_compare(report, args.golden, args.expected)
        if unexpected > 0:
            print("FUNNEL GATE: FAIL (%d unexpected delta(s))" % unexpected)
            return 1
        print("FUNNEL GATE: PASS")
        return 0

    return 0


if __name__ == "__main__":
    sys.exit(main())
