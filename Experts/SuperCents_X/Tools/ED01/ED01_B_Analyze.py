"""ED01-B analyzer: LIQUIDITY vs pooled NON-LIQUIDITY conditional expectancy.

Protocol: docs/Sprint20_ED01B_Protocol.md (frozen 2026-08-09, amendment 13.1).

Population: frozen ED01-A CONTROL runs only (B8, fingerprint
3005138848403243456); rows with newDecision==1; settled rMultiple on closed
rows (outcome in 1,2,3); censored (outcome 0) excluded from R statistics and
reported as nOpen. Family assignment via the frozen GR01 RULE_FAMILY map.

Groups: LIQUIDITY vs NON-LIQUIDITY pooled (BOS + FVG + CHOCH + ORDER_BLOCK +
UNKNOWN). Pool membership is fixed by the protocol.

Primary metric: Delta Mean R = MeanR(LIQUIDITY) - MeanR(NON-LIQUIDITY), per
file. Bootstrap 95% CI: paired day-stratified, 10,000 resamples, seed
20260809. Pooled estimator is primary; daily-mean estimator is auxiliary
(computed on days where both groups have rows). Unpaired days are included in
the pooled resampling (they contribute their single group's rows). Fewer than
10 paired days -> CI unavailable -> DEFER.

Decision rules (protocol section 8): EURUSD_H1 primary; n >= 50 closed per
group in BOTH decision files; |Delta| >= 0.10; 95% CI excludes 0; 2/2 H1
direction agreement; estimator-conflict -> DEFER; UNKNOWN-exclusion gate
(conclusion must survive with UNKNOWN removed, sign and magnitude);
sub-family concentration gate (removing any single non-liquidity family must
not flip the verdict). Verdicts: EVIDENCE FOR LIQUIDITY / EVIDENCE AGAINST
LIQUIDITY / REJECT (no distinct edge) / DEFER. EURUSD_M15 is evidence-only
and never gates. TT01 baseline replay is an informational cross-check only.

Usage: python ED01_B_Analyze.py [--artifacts <dir>] [--iters 10000]
       [--min-n 50] [--min-effect 0.10] [--json results_ED01B.json]
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
TT01_BASELINE = os.path.join(PROJECT, "Tools", "TT01", "baseline",
                             "telemetry_v4_20260130.csv")

RULE_FAMILY = {
    "LIQUIDITY_BOS_BULLISH": "LIQUIDITY",
    "LIQUIDITY_BOS_BEARISH": "LIQUIDITY",
    "OB_FVG_BULLISH": "FVG",
    "OB_FVG_BEARISH": "FVG",
    "BOS_OB_BULLISH": "BOS",
    "BOS_OB_BEARISH": "BOS",
    "CHOCH_OB_REVERSAL": "CHOCH",
}

B8_FINGERPRINT = "3005138848403243456"
# Per-file default-config (B8-equivalent) fingerprints, protocol amendment
# 13.2: the fingerprint canonical string includes symbol|timeframe, so each
# file has its own constant. Cross-verified against the 6-month archive
# CONTROL runs (config determinism across batches).
FINGERPRINTS = {
    "EURUSD_H1": B8_FINGERPRINT,
    "GBPJPY_H1": "14617585492269479818",
    "EURUSD_M15": "13548296177162108249",
}
ARCHIVE = os.path.join(os.path.dirname(DEFAULT_ARTS), "artifacts_6mo_2026-01-05_07-05")
PRIMARY_FILE = "EURUSD_H1"
DECISION_FILES = ["EURUSD_H1", "GBPJPY_H1"]
EVIDENCE_FILE = "EURUSD_M15"
FILES = DECISION_FILES + [EVIDENCE_FILE]
NON_LIQ_FAMILIES = ["BOS", "FVG", "CHOCH", "ORDER_BLOCK", "UNKNOWN"]
SEED = 20260809
MIN_PAIRED_DAYS = 10
DEFAULT_ITERS = 10000

# Audit constants (protocol amendment 13.1, from the frozen ED01-A analysis
# Tools/ED01/results_3mo.json). Audit is a hard gate: qualified counts and
# per-family closed counts must reproduce exactly.
AUDIT_QUALIFIED = {"EURUSD_H1": 1468, "GBPJPY_H1": 236, "EURUSD_M15": 5981}
AUDIT_CLOSED = {
    "EURUSD_H1": {"LIQUIDITY": 607, "FVG": 318, "BOS": 378,
                  "CHOCH": 0, "UNKNOWN": 117},
    "GBPJPY_H1": {"LIQUIDITY": 96, "FVG": 39, "BOS": 59,
                  "CHOCH": 0, "UNKNOWN": 23},
    "EURUSD_M15": {"LIQUIDITY": 1694, "FVG": 2092, "BOS": 2095,
                   "CHOCH": 1, "UNKNOWN": 49},
}
# ED01-A mean R per family (warn-level reproduction check, 4-dp rounding).
AUDIT_MEANR = {
    "EURUSD_H1": {"LIQUIDITY": -0.0906, "FVG": 0.1604, "BOS": 0.0079,
                  "CHOCH": None, "UNKNOWN": -0.2821},
    "GBPJPY_H1": {"LIQUIDITY": -0.0938, "FVG": -0.3846, "BOS": 0.1186,
                  "CHOCH": None, "UNKNOWN": 0.1739},
    "EURUSD_M15": {"LIQUIDITY": -0.1464, "FVG": 0.0675, "BOS": 0.0150,
                   "CHOCH": 2.0, "UNKNOWN": -0.0320},
}

# Outcome semantics: 1 = WIN, 2 = LOSS, 3 = BREAKEVEN, 0 = censored/open.
OUTCOME_LABEL = {"1": "WIN", "2": "LOSS", "3": "BREAKEVEN"}


def family_of(row):
    return RULE_FAMILY.get((row.get("ruleName") or "").strip(), "UNKNOWN")


def num(row, key):
    try:
        return float((row.get(key) or "0").strip())
    except ValueError:
        return 0.0


def day_of(row):
    return (row.get("timestamp") or "").split()[0]


def load_run(art_dir, file_key):
    """Load the CONTROL run for a file. Returns (rows, fingerprints) or None."""
    d = os.path.join(art_dir, file_key, "CONTROL")
    if not os.path.isfile(os.path.join(d, ".done")):
        return None
    rows = []
    for path in sorted(glob.glob(os.path.join(d, "telemetry_v4_*.csv"))):
        with open(path, newline="", encoding="utf-16") as fh:
            rows.extend(csv.DictReader(fh))
    fps = sorted({r.get("configFingerprint", "") for r in rows})
    return rows, fps


def qualified_rows(rows):
    return [r for r in rows if r.get("newDecision") == "1"]


def closed_family_rows(rows, fams):
    """Qualified, family-filtered, closed rows (outcome in 1,2,3)."""
    return [r for r in rows
            if r.get("newDecision") == "1" and family_of(r) in fams
            and r.get("outcome") in ("1", "2", "3")]


def group_stats(rows, fams):
    """Statistics for a fixed group (protocol section 6)."""
    q = qualified_rows(rows)
    n_pop = sum(1 for r in q if family_of(r) in fams)
    c = [r for r in q if family_of(r) in fams and r.get("outcome") in ("1", "2", "3")]
    n_open = sum(1 for r in q if family_of(r) in fams and r.get("outcome") == "0")
    st = {"nPop": n_pop, "nClosed": len(c), "nOpen": n_open,
          "wins": 0, "losses": 0, "be": 0, "wr": None,
          "meanR": None, "medianR": None, "q25": None, "q75": None,
          "maxDD": None, "rDist": {}, "outDist": {}, "confDist": {}}
    if not c:
        return st
    vals = [num(r, "rMultiple") for r in c]
    for r in c:
        o = r.get("outcome")
        st["outDist"][o] = st["outDist"].get(o, 0) + 1
        st["rDist"][str(num(r, "rMultiple"))] = st["rDist"].get(
            str(num(r, "rMultiple")), 0) + 1
        st["confDist"][r.get("newConfidence", "")] = st["confDist"].get(
            r.get("newConfidence", ""), 0) + 1
        if o == "1":
            st["wins"] += 1
        elif o == "2":
            st["losses"] += 1
        else:
            st["be"] += 1
    denom = st["wins"] + st["losses"]
    st["wr"] = round(st["wins"] / denom, 4) if denom else None
    st["meanR"] = round(sum(vals) / len(c), 4)
    sv = sorted(vals)
    n = len(sv)
    def qp(p):
        i = int(p * (n - 1))
        return sv[i]
    st["q25"], st["medianR"], st["q75"] = (round(qp(0.25), 4),
                                           round(qp(0.5), 4), round(qp(0.75), 4))
    ordered = sorted(c, key=lambda r: (day_of(r), int(num(r, "decisionId"))))
    cum = peak = dd = 0.0
    for r in ordered:
        cum += num(r, "rMultiple")
        peak = max(peak, cum)
        dd = max(dd, peak - cum)
    st["maxDD"] = round(dd, 4)
    return st


def by_day(rows, fams):
    """day -> [rMultiple] for closed rows in the group."""
    out = {}
    for r in closed_family_rows(rows, fams):
        out.setdefault(day_of(r), []).append(num(r, "rMultiple"))
    return out


def day_stratified_delta_ci(liq, non, iters):
    """Paired day-stratified bootstrap on Delta = MeanR(LIQ) - MeanR(NON).

    Resamples days (with replacement) from the union of days holding rows in
    either group; unpaired days contribute their single group's rows to the
    pooled draw (protocol 5). The auxiliary daily-mean estimator averages the
    per-day mean-R difference over sampled days where BOTH groups have rows.
    Returns (pooled_ci, daily_ci, n_paired_days, observed_daily_delta).
    """
    days = sorted(set(liq) | set(non))
    paired = [d for d in days if d in liq and d in non]
    if len(paired) < MIN_PAIRED_DAYS:
        return None, None, len(paired), None
    n = len(days)
    diffs, dmd = [], []
    for _ in range(iters):
        s = m = 0.0
        t = c = 0.0
        for _ in range(n):
            d = days[random.randrange(n)]
            a = liq.get(d, [])
            b = non.get(d, [])
            s += sum(a) - sum(b)
            m += len(a) + len(b)
            if a and b:
                t += (sum(a) / len(a)) - (sum(b) / len(b))
                c += 1
        diffs.append(s / max(m, 1.0))
        dmd.append(t / max(c, 1.0))
    diffs.sort()
    dmd.sort()
    k = iters // 40
    observed_daily = (sum(sum(liq[d]) / len(liq[d]) - sum(non[d]) / len(non[d])
                          for d in paired) / len(paired))
    return ({"lo": diffs[k], "hi": diffs[iters - k - 1]},
            {"lo": dmd[k], "hi": dmd[iters - k - 1]}, len(paired),
            observed_daily)


def ci_excludes_zero(ci):
    return ci is not None and (ci["lo"] > 0.0 or ci["hi"] < 0.0)


def estimator_conflict(delta, pooled_ci, daily_delta, daily_ci):
    """Protocol 5: sign disagreement with a CI excluding 0 -> DEFER."""
    if pooled_ci is None or daily_ci is None:
        return False
    if (delta > 0) == (daily_delta > 0):
        return False
    return ci_excludes_zero(pooled_ci) or ci_excludes_zero(daily_ci)


def group_delta(rows, liq_fams, non_fams, iters):
    """Full per-file comparison: stats + Delta + CIs."""
    liq = by_day(rows, liq_fams)
    non = by_day(rows, non_fams)
    pooled_ci, daily_ci, ndays, observed_daily = day_stratified_delta_ci(
        liq, non, iters)
    s_liq = group_stats(rows, liq_fams)
    s_non = group_stats(rows, non_fams)
    delta = (s_liq["meanR"] - s_non["meanR"]) if s_liq["meanR"] is not None else None
    return {"liq": s_liq, "non": s_non, "delta": delta, "ci": pooled_ci,
            "dailyDelta": observed_daily, "dailyCi": daily_ci,
            "pairedDays": ndays}


def audit(rows_by_file):
    """Protocol 10 + amendments 13.1/13.2.

    Hard gates: single fingerprint per run equal to the frozen per-file
    fingerprint; qualified counts and per-family closed counts reproduce the
    frozen ED01-A analysis; the 6-month archive CONTROL runs (same default
    config) carry the same fingerprints. Mean R reproduction is warn-level.
    """
    msgs = []
    ok = True
    for f in FILES:
        rows = rows_by_file[f]
        if not rows:
            msgs.append("FAIL %s: no rows" % f)
            ok = False
            continue
        fps = sorted({r.get("configFingerprint", "") for r in rows})
        if fps != [FINGERPRINTS[f]]:
            msgs.append("FAIL %s: fingerprints %s != frozen %s" %
                        (f, fps, FINGERPRINTS[f]))
            ok = False
        arch_path = os.path.join(ARCHIVE, f, "CONTROL")
        arch_fps = set()
        if os.path.isdir(arch_path):
            for path in sorted(glob.glob(os.path.join(arch_path, "telemetry_v4_*.csv"))):
                with open(path, newline="", encoding="utf-16") as fh:
                    for r in csv.DictReader(fh):
                        arch_fps.add(r.get("configFingerprint", ""))
        else:
            msgs.append("WARN %s: 6-month archive CONTROL absent (%s)" %
                        (f, arch_path))
        if arch_fps and arch_fps != {FINGERPRINTS[f]}:
            msgs.append("FAIL %s: archive fingerprints %s != frozen %s" %
                        (f, sorted(arch_fps), FINGERPRINTS[f]))
            ok = False
        nq = len(qualified_rows(rows))
        if nq != AUDIT_QUALIFIED[f]:
            msgs.append("FAIL %s: qualified %d != frozen %d" % (f, nq, AUDIT_QUALIFIED[f]))
            ok = False
        for fam, exp in sorted(AUDIT_CLOSED[f].items()):
            got = len(closed_family_rows(rows, {fam}))
            if got != exp:
                msgs.append("FAIL %s %s: closed %d != frozen %d" % (f, fam, got, exp))
                ok = False
            st = group_stats(rows, {fam})
            exp_mr = AUDIT_MEANR[f].get(fam)
            if exp_mr is not None and st["meanR"] is not None:
                if abs(st["meanR"] - exp_mr) > 0.00005:
                    msgs.append("WARN %s %s: meanR %s != ED01-A %s" %
                                (f, fam, st["meanR"], exp_mr))
    return ok, msgs


def decide(cmp_by_file, iters, min_n, min_effect, rows_by_file):
    """Pre-registered decision ladder (protocol section 8)."""
    reason_parts = []
    for f in DECISION_FILES:
        c = cmp_by_file[f]
        if c["liq"]["nClosed"] < min_n or c["non"]["nClosed"] < min_n:
            return "DEFER", ("n < %d per side on %s (liq=%d, non=%d)"
                             % (min_n, f, c["liq"]["nClosed"], c["non"]["nClosed"]))
    prim = cmp_by_file[PRIMARY_FILE]
    if prim["ci"] is None:
        return "DEFER", "paired days < 10 on %s (primary)" % PRIMARY_FILE
    d1 = prim["delta"]
    ci1 = prim["ci"]
    if estimator_conflict(d1, ci1, prim["dailyDelta"], prim["dailyCi"]):
        return "DEFER", ("estimator conflict on %s: pooled %.4f vs daily %.4f "
                         "(daily CI [%.4f, %.4f])"
                         % (PRIMARY_FILE, d1, prim["dailyDelta"],
                            prim["dailyCi"]["lo"], prim["dailyCi"]["hi"]))
    if abs(d1) < min_effect:
        return "REJECT", ("|delta| %.4f < 0.10 on %s" % (abs(d1), PRIMARY_FILE))
    if not ci_excludes_zero(ci1):
        return "REJECT", "95%% CI includes 0: [%.4f, %.4f]" % (ci1["lo"], ci1["hi"])
    signs = []
    for f in DECISION_FILES:
        d = cmp_by_file[f]["delta"]
        signs.append("%s:%+.4f" % (f, d))
    if (cmp_by_file[DECISION_FILES[1]]["delta"] > 0) != (d1 > 0):
        return "REJECT", "H1 direction not 2/2 (%s)" % ", ".join(signs)
    cand = ("EVIDENCE FOR LIQUIDITY" if d1 > 0
            else "EVIDENCE AGAINST LIQUIDITY")
    rows = rows_by_file[PRIMARY_FILE]
    for fam in NON_LIQ_FAMILIES:
        rest = [x for x in NON_LIQ_FAMILIES if x != fam]
        c2 = group_delta(rows, ["LIQUIDITY"], rest, iters)
        if c2["delta"] is None:
            continue
        if (c2["delta"] > 0) != (d1 > 0) or abs(c2["delta"]) < min_effect:
            return "DEFER", ("gate: removing %s flips verdict "
                             "(delta %.4f on %s)" % (fam, c2["delta"], PRIMARY_FILE))
        reason_parts.append("no-%s:%.4f" % (fam, c2["delta"]))
    reason = ("delta=%.4f CI=[%.4f, %.4f] %s gates=[%s]"
              % (d1, ci1["lo"], ci1["hi"], ", ".join(signs),
                 ", ".join(reason_parts)))
    return cand, reason


def baseline_cross_check(path):
    """Informational TT01 baseline replay (protocol 6); never gates."""
    if not os.path.isfile(path):
        return {"note": "baseline not found: %s" % path}
    rows = []
    with open(path, newline="", encoding="utf-16") as fh:
        rows.extend(csv.DictReader(fh))
    s_liq = group_stats(rows, ["LIQUIDITY"])
    s_non = group_stats(rows, NON_LIQ_FAMILIES)
    out = {"liq": s_liq, "non": s_non}
    if s_liq["nClosed"] >= 50 and s_non["nClosed"] >= 50:
        out["delta"] = s_liq["meanR"] - s_non["meanR"]
    else:
        out["delta"] = None
        out["note"] = "per-group n < 50 (informational only)"
    return out


def fmt_stat(st):
    return ("nPop=%d nClosed=%d nOpen=%d wr=%s meanR=%s median=%s "
            "q25=%s q75=%s maxDD=%s" % (
                st["nPop"], st["nClosed"], st["nOpen"], st["wr"],
                st["meanR"], st["medianR"], st["q25"], st["q75"], st["maxDD"]))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--artifacts", default=DEFAULT_ARTS)
    ap.add_argument("--iters", type=int, default=DEFAULT_ITERS)
    ap.add_argument("--min-n", type=int, default=50)
    ap.add_argument("--min-effect", type=float, default=0.10)
    ap.add_argument("--json", default=os.path.join(
        os.path.dirname(DEFAULT_ARTS), "results_ED01B.json"))
    args = ap.parse_args()
    random.seed(SEED)

    rows_by_file = {}
    for f in FILES:
        loaded = load_run(args.artifacts, f)
        if not loaded:
            print("no CONTROL run for %s (missing .done)" % f)
            return 1
        rows, fps = loaded
        rows_by_file[f] = rows
        if len(fps) > 1:
            print("WARN %s: multiple fingerprints: %s" % (f, fps))

    ok, msgs = audit(rows_by_file)
    print("== audit (protocol 10 + amendment 13.1) ==")
    for m in msgs:
        print("  %s" % m)
    if not ok:
        print("AUDIT FAILED - frozen counts/fingerprint not reproduced; "
              "analysis aborted.")
        return 1
    print("  audit PASS (fingerprint + qualified + per-family closed counts "
          "reproduce the frozen ED01-A analysis)")

    cmp_by_file = {}
    print()
    print("== per-file comparison (LIQUIDITY vs NON-LIQUIDITY pooled) ==")
    for f in FILES:
        c = group_delta(rows_by_file[f], ["LIQUIDITY"], NON_LIQ_FAMILIES, args.iters)
        cmp_by_file[f] = c
        tag = "decision" if f in DECISION_FILES else "evidence"
        print("  %-10s (%s)" % (f, tag))
        print("    LIQ         %s" % fmt_stat(c["liq"]))
        print("    NON-LIQUID  %s" % fmt_stat(c["non"]))
        if c["delta"] is not None:
            dci = ""
            if c["dailyCi"]:
                dci = " dailyCI=[%.4f, %.4f] (d=%+.4f)" % (
                    c["dailyCi"]["lo"], c["dailyCi"]["hi"], c["dailyDelta"])
            print("    delta       %+.4f CI=[%s, %s] pairedDays=%d%s" % (
                c["delta"], c["ci"]["lo"], c["ci"]["hi"], c["pairedDays"], dci))
        else:
            print("    delta       n/a (paired days < %d)" % MIN_PAIRED_DAYS)

    print()
    print("== per-family breakdown (EURUSD_H1) ==")
    fams = ["LIQUIDITY"] + NON_LIQ_FAMILIES
    for fam in fams:
        st = group_stats(rows_by_file[PRIMARY_FILE], {fam})
        print("  %-12s %s" % (fam, fmt_stat(st)))

    print()
    print("== TT01 baseline cross-check (informational) ==")
    bc = baseline_cross_check(TT01_BASELINE)
    if "delta" in bc and bc["delta"] is not None:
        print("  delta %+.4f (liq n=%d, non n=%d)" %
              (bc["delta"], bc["liq"]["nClosed"], bc["non"]["nClosed"]))
    else:
        print("  %s" % bc.get("note", "skipped"))

    verdict, reason = decide(cmp_by_file, args.iters, args.min_n,
                             args.min_effect, rows_by_file)
    print()
    print("== verdict: %s ==" % verdict)
    print("  %s" % reason)

    if args.json:
        out = {"audit": {"pass": True, "messages": msgs},
               "per_file": cmp_by_file,
               "baseline": bc,
               "verdict": {"verdict": verdict, "reason": reason,
                           "thresholds": {"min_effect": args.min_effect,
                                          "min_n": args.min_n,
                                          "iters": args.iters,
                                          "seed": SEED}}}
        with open(args.json, "w") as fh:
            json.dump(out, fh, indent=1)
        print("wrote %s" % args.json)
    return 0


if __name__ == "__main__":
    sys.exit(main())
