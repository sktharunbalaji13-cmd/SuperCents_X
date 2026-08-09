"""ED01-C analyzer: within-family discrete confidence-level expectancy.

Protocol: docs/Sprint20_ED01C_Protocol.md (frozen 2026-08-09, amendment 16.1).

Population: frozen ED01-A CONTROL runs only (B8 default config, per-file
fingerprints per ED01-B amendment 13.2); rows with newDecision==1; settled
rMultiple on closed rows (outcome in 1,2,3); censored (outcome 0) excluded
from R statistics and reported as nOpen. Family assignment via the frozen
GR01 RULE_FAMILY map.

Level groups (pre-registered): FVG-HIGH = FVG rows at newConfidence 0.40,
FVG-LOW = FVG rows at 0.35; BOS-HIGH = 0.45, BOS-LOW = 0.40 (BOS is
evidence-only: HIGH n ~= 14 on H1, ~= 39 on M15). LIQUIDITY (constant 0.60),
UNKNOWN (no deciding rule), CHOCH and ORDER_BLOCK (never fire) are
structurally excluded - no level split exists.

Primary metric: Delta Mean R = MeanR(FVG-HIGH) - MeanR(FVG-LOW), per file.
Bootstrap 95% CI: paired day-stratified, 10,000 resamples, seed 20260810.
Pooled estimator primary; daily-mean estimator auxiliary (paired days only).
Fewer than 10 paired days -> CI unavailable -> DEFER.

Hierarchy (amendment 16.1): EURUSD_H1 primary decision file; EURUSD_M15
stability partner (GBPJPY_H1 n-constrained: 39 FVG closed rows -> evidence
only). 2/2 direction agreement across the two resolvable populations is
required for an affirmative verdict; M15 cannot independently establish an
edge.

Decision ladder (protocol section 8 + amendment 16.1):
- EVIDENCE FOR CONFIDENCE LEVELS: H1 |Delta| >= 0.10, CI excludes 0,
  n >= 50 per level on H1, estimators agree, direction agrees on M15 (2/2),
  M15 resolvable (n >= 50/level, >= 10 paired days, no estimator conflict).
- REJECT / NO DISTINCT LEVEL EXPECTANCY: H1 |Delta| < 0.10 or CI includes 0
  (M15 direction moot when H1 is null).
- DEFER: n < 50/level on H1, < 10 paired days, estimator conflict, or a
  meaningful H1 result with opposite sign / unresolvable M15 (instability).

Composition discipline: primary pools no families. The pooled-level
exploratory view (FVG+BOS HIGH vs LOW) is reported with the ED01-B
composition gates applied (single-subfamily concentration), never gating.
Level-split integrity: FVG HIGH counts must equal the frozen ED01-A FVG_0.40
grid admitted counts (EURUSD_H1 143, EURUSD_M15 1159); HIGH+LOW == total.

Usage: python ED01_C_Analyze.py [--artifacts <dir>] [--iters 10000]
       [--min-n 50] [--min-effect 0.10] [--json results_ED01C.json]
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
FINGERPRINTS = {
    "EURUSD_H1": B8_FINGERPRINT,
    "GBPJPY_H1": "14617585492269479818",
    "EURUSD_M15": "13548296177162108249",
}
ARCHIVE = os.path.join(os.path.dirname(DEFAULT_ARTS), "artifacts_6mo_2026-01-05_07-05")

PRIMARY_FILE = "EURUSD_H1"
STABILITY_FILE = "EURUSD_M15"
EVIDENCE_FILE = "GBPJPY_H1"
FILES = [PRIMARY_FILE, STABILITY_FILE, EVIDENCE_FILE]

# Level definitions per family (pre-registered, protocol section 3).
LEVELS = {"FVG": ("0.40", "0.35"), "BOS": ("0.45", "0.40")}
SEED = 20260810
MIN_PAIRED_DAYS = 10
DEFAULT_ITERS = 10000

# Frozen audit constants (ED01-B amendment 13.1 + ED01-C section 3/11).
AUDIT_QUALIFIED = {"EURUSD_H1": 1468, "GBPJPY_H1": 236, "EURUSD_M15": 5981}
AUDIT_CLOSED = {
    "EURUSD_H1": {"LIQUIDITY": 607, "FVG": 318, "BOS": 378,
                  "CHOCH": 0, "UNKNOWN": 117},
    "GBPJPY_H1": {"LIQUIDITY": 96, "FVG": 39, "BOS": 59,
                  "CHOCH": 0, "UNKNOWN": 23},
    "EURUSD_M15": {"LIQUIDITY": 1694, "FVG": 2092, "BOS": 2095,
                   "CHOCH": 1, "UNKNOWN": 49},
}
# Expected HIGH-level (0.40) FVG closed counts from the frozen ED01-A
# FVG_0.40 grid runs (the raised floor admits exactly the >= 0.40 subset).
FVG_HIGH_EXPECTED = {"EURUSD_H1": 143, "EURUSD_M15": 1159}
# Expected distinct deciding-family confidence values (ED01-A, discrete).
CONF_EXPECTED = {"LIQUIDITY": {0.60}, "FVG": {0.35, 0.40}, "BOS": {0.40, 0.45}}

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


def level_of(row, fam):
    """HIGH/LOW by deciding-family confidence; None if not a level family."""
    if fam not in LEVELS:
        return None
    conf = num(row, "newConfidence")
    hi, lo = LEVELS[fam]
    if abs(conf - float(hi)) < 1e-9:
        return "HIGH"
    if abs(conf - float(lo)) < 1e-9:
        return "LOW"
    return None


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


def level_rows(rows, fam, level):
    """Qualified, family+level-filtered, closed rows (outcome in 1,2,3)."""
    return [r for r in rows
            if r.get("newDecision") == "1" and family_of(r) == fam
            and level_of(r, fam) == level
            and r.get("outcome") in ("1", "2", "3")]


def group_stats(rows, fam, level):
    """Statistics for a level group (protocol section 6)."""
    q = qualified_rows(rows)
    fams = [r for r in q if family_of(r) == fam]
    n_pop = sum(1 for r in fams if level_of(r, fam) == level)
    c = [r for r in fams if level_of(r, fam) == level
         and r.get("outcome") in ("1", "2", "3")]
    n_open = sum(1 for r in fams if level_of(r, fam) == level
                 and r.get("outcome") == "0")
    st = {"fam": fam, "level": level, "nPop": n_pop, "nClosed": len(c),
          "nOpen": n_open, "wins": 0, "losses": 0, "be": 0, "wr": None,
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
        st["confDist"][str(num(r, "newConfidence"))] = st["confDist"].get(
            str(num(r, "newConfidence")), 0) + 1
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
    st["q25"] = round(sv[int(0.25 * (n - 1))], 4)
    st["medianR"] = round(sv[int(0.5 * (n - 1))], 4)
    st["q75"] = round(sv[int(0.75 * (n - 1))], 4)
    ordered = sorted(c, key=lambda r: (day_of(r), int(num(r, "decisionId"))))
    cum = peak = dd = 0.0
    for r in ordered:
        cum += num(r, "rMultiple")
        peak = max(peak, cum)
        dd = max(dd, peak - cum)
    st["maxDD"] = round(dd, 4)
    return st


def by_day_level(rows, fam, level):
    out = {}
    for r in level_rows(rows, fam, level):
        out.setdefault(day_of(r), []).append(num(r, "rMultiple"))
    return out


def day_stratified_delta_ci(hi, lo, iters):
    """Paired day-stratified bootstrap on Delta = MeanR(HIGH) - MeanR(LOW).

    Resamples days (with replacement) from the union of days holding either
    level's rows; unpaired days contribute their single level's rows to the
    pooled draw. Auxiliary daily-mean estimator averages per-day differences
    over sampled days where BOTH levels have rows.
    Returns (pooled_ci, daily_ci, n_paired_days, observed_daily_delta).
    """
    days = sorted(set(hi) | set(lo))
    paired = [d for d in days if d in hi and d in lo]
    if len(paired) < MIN_PAIRED_DAYS:
        return None, None, len(paired), None
    n = len(days)
    diffs, dmd = [], []
    for _ in range(iters):
        s = m = 0.0
        t = c = 0.0
        for _ in range(n):
            d = days[random.randrange(n)]
            a = hi.get(d, [])
            b = lo.get(d, [])
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
    observed_daily = (sum(sum(hi[d]) / len(hi[d]) - sum(lo[d]) / len(lo[d])
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


def level_compare(rows, fam, iters):
    """Full per-file level comparison: stats + Delta + CIs."""
    hi = by_day_level(rows, fam, "HIGH")
    lo = by_day_level(rows, fam, "LOW")
    pooled_ci, daily_ci, ndays, observed_daily = day_stratified_delta_ci(
        hi, lo, iters)
    s_hi = group_stats(rows, fam, "HIGH")
    s_lo = group_stats(rows, fam, "LOW")
    delta = (s_hi["meanR"] - s_lo["meanR"]) if s_hi["meanR"] is not None else None
    return {"hi": s_hi, "lo": s_lo, "delta": delta, "ci": pooled_ci,
            "dailyDelta": observed_daily, "dailyCi": daily_ci,
            "pairedDays": ndays}


def pooled_level_compare(rows, fams, iters):
    """Exploratory pooled-level view (protocol 6/9) - never gating.

    Pooled-HIGH (all fams HIGH) vs pooled-LOW. Composition gate: removing any
    single family must not flip sign or drop |Delta| below the threshold,
    else the view is reported as composition-confined.
    """
    hi, lo = {}, {}
    for fam in fams:
        for d, v in by_day_level(rows, fam, "HIGH").items():
            hi.setdefault(d, []).extend(v)
        for d, v in by_day_level(rows, fam, "LOW").items():
            lo.setdefault(d, []).extend(v)
    pooled_ci, daily_ci, ndays, observed_daily = day_stratified_delta_ci(
        hi, lo, iters)
    s_hi = group_stats(rows, fams[0], "HIGH") if False else None
    hi_n = sum(len(v) for v in hi.values())
    lo_n = sum(len(v) for v in lo.values())
    # mean R from the day maps (closed rows only).
    hi_vals = [v for vals in hi.values() for v in vals]
    lo_vals = [v for vals in lo.values() for v in vals]
    m_hi = sum(hi_vals) / len(hi_vals) if hi_vals else None
    m_lo = sum(lo_vals) / len(lo_vals) if lo_vals else None
    delta = (m_hi - m_lo) if (m_hi is not None and m_lo is not None) else None
    out = {"nHigh": hi_n, "nLow": lo_n, "delta": delta, "ci": pooled_ci,
           "dailyCi": daily_ci, "pairedDays": ndays, "confined": []}
    for fam in fams:
        hi2, lo2 = {}, {}
        for f2 in fams:
            if f2 == fam:
                continue
            for d, v in by_day_level(rows, f2, "HIGH").items():
                hi2.setdefault(d, []).extend(v)
            for d, v in by_day_level(rows, f2, "LOW").items():
                lo2.setdefault(d, []).extend(v)
        a = [v for vals in hi2.values() for v in vals]
        b = [v for vals in lo2.values() for v in vals]
        if not a or not b:
            continue
        d2 = (sum(a) / len(a)) - (sum(b) / len(b))
        if (d2 > 0) != (delta > 0) or abs(d2) < 0.10:
            out["confined"].append(fam)
    return out


def audit(rows_by_file):
    """Protocol 11: fingerprints, frozen counts, level-split integrity.

    Hard gates: per-file fingerprints, qualified + per-family closed counts,
    FVG HIGH-level counts equal the frozen FVG_0.40 grid expectations.
    Warn-level: discrete confidence sets per family.
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
        if arch_fps and arch_fps != {FINGERPRINTS[f]}:
            msgs.append("FAIL %s: archive fingerprints %s != frozen %s" %
                        (f, sorted(arch_fps), FINGERPRINTS[f]))
            ok = False
        nq = len(qualified_rows(rows))
        if nq != AUDIT_QUALIFIED[f]:
            msgs.append("FAIL %s: qualified %d != frozen %d" % (f, nq, AUDIT_QUALIFIED[f]))
            ok = False
        for fam, exp in sorted(AUDIT_CLOSED[f].items()):
            got = len(level_rows(rows, fam, "HIGH")) + len(level_rows(rows, fam, "LOW"))
            if fam not in LEVELS:
                got = len([r for r in rows
                           if r.get("newDecision") == "1" and family_of(r) == fam
                           and r.get("outcome") in ("1", "2", "3")])
            if got != exp:
                msgs.append("FAIL %s %s: closed %d != frozen %d" % (f, fam, got, exp))
                ok = False
            if fam in CONF_EXPECTED:
                confs = {num(r, "newConfidence") for r in rows
                         if r.get("newDecision") == "1" and family_of(r) == fam
                         and r.get("outcome") in ("1", "2", "3")}
                if confs and confs != CONF_EXPECTED[fam]:
                    msgs.append("WARN %s %s: confidence set %s != expected %s" %
                                (f, fam, sorted(confs), sorted(CONF_EXPECTED[fam])))
        if f in FVG_HIGH_EXPECTED:
            n_hi = len(level_rows(rows, "FVG", "HIGH"))
            n_lo = len(level_rows(rows, "FVG", "LOW"))
            exp_hi = FVG_HIGH_EXPECTED[f]
            exp_lo = AUDIT_CLOSED[f]["FVG"] - exp_hi
            if n_hi != exp_hi or n_lo != exp_lo:
                msgs.append("FAIL %s FVG level split: HIGH=%d LOW=%d != frozen "
                            "HIGH=%d LOW=%d" % (f, n_hi, n_lo, exp_hi, exp_lo))
                ok = False
    return ok, msgs


def decide(cmp_by_file, min_n, min_effect):
    """Pre-registered decision ladder (protocol 8 + amendment 16.1)."""
    prim = cmp_by_file[PRIMARY_FILE]
    if prim["hi"]["nClosed"] < min_n or prim["lo"]["nClosed"] < min_n:
        return "DEFER", ("n < %d per level on %s (HIGH=%d, LOW=%d)"
                         % (min_n, PRIMARY_FILE,
                            prim["hi"]["nClosed"], prim["lo"]["nClosed"]))
    if prim["ci"] is None:
        return "DEFER", "paired days < 10 on %s (primary)" % PRIMARY_FILE
    d1 = prim["delta"]
    ci1 = prim["ci"]
    if estimator_conflict(d1, ci1, prim["dailyDelta"], prim["dailyCi"]):
        return "DEFER", ("estimator conflict on %s: pooled %.4f vs daily %.4f"
                         % (PRIMARY_FILE, d1, prim["dailyDelta"]))
    if abs(d1) < min_effect:
        return "REJECT", ("|delta| %.4f < 0.10 on %s (M15 direction moot)"
                          % (abs(d1), PRIMARY_FILE))
    if not ci_excludes_zero(ci1):
        return "REJECT", "95%% CI includes 0 on %s: [%.4f, %.4f]" % (
            PRIMARY_FILE, ci1["lo"], ci1["hi"])
    st = cmp_by_file[STABILITY_FILE]
    if st["hi"]["nClosed"] < min_n or st["lo"]["nClosed"] < min_n:
        return "DEFER", ("M15 stability partner unresolvable: n < %d per level "
                         "(HIGH=%d, LOW=%d)" % (min_n, st["hi"]["nClosed"],
                                                st["lo"]["nClosed"]))
    if st["ci"] is None:
        return "DEFER", "paired days < 10 on %s (stability)" % STABILITY_FILE
    if estimator_conflict(st["delta"], st["ci"], st["dailyDelta"], st["dailyCi"]):
        return "DEFER", "estimator conflict on %s (stability)" % STABILITY_FILE
    if (st["delta"] > 0) != (d1 > 0):
        return "DEFER", ("direction instability: %s %.4f vs %s %.4f "
                         "(meaningful H1 result, opposite sign on M15)"
                         % (PRIMARY_FILE, d1, STABILITY_FILE, st["delta"]))
    direction = "HIGH-better" if d1 > 0 else "LOW-better"
    return ("EVIDENCE FOR CONFIDENCE LEVELS",
            "delta=%.4f CI=[%.4f, %.4f] %s; %s delta=%.4f CI=[%.4f, %.4f] "
            "2/2 agreement" % (d1, ci1["lo"], ci1["hi"], direction,
                               STABILITY_FILE, st["delta"], st["ci"]["lo"],
                               st["ci"]["hi"]))


def baseline_cross_check(path):
    """Informational TT01 baseline replay (protocol 6); never gates."""
    if not os.path.isfile(path):
        return {"note": "baseline not found: %s" % path}
    rows = []
    with open(path, newline="", encoding="utf-16") as fh:
        rows.extend(csv.DictReader(fh))
    n_hi = len(level_rows(rows, "FVG", "HIGH"))
    n_lo = len(level_rows(rows, "FVG", "LOW"))
    out = {"nHigh": n_hi, "nLow": n_lo}
    if n_hi >= 50 and n_lo >= 50:
        c = level_compare(rows, "FVG", DEFAULT_ITERS)
        out["delta"] = c["delta"]
        out["ci"] = c["ci"]
        out["pairedDays"] = c["pairedDays"]
    else:
        out["note"] = "per-level n < 50 (informational only)"
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
        os.path.dirname(DEFAULT_ARTS), "results_ED01C.json"))
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
    print("== audit (protocol 11 + amendments 13.1/13.2/16.1) ==")
    for m in msgs:
        print("  %s" % m)
    if not ok:
        print("AUDIT FAILED - frozen counts/fingerprints/level split not "
              "reproduced; analysis aborted.")
        return 1
    print("  audit PASS (fingerprints + qualified + per-family closed counts "
          "+ FVG level split reproduce the frozen ED01-A analysis)")

    cmp_by_file = {}
    print()
    print("== per-file FVG level comparison (HIGH 0.40 vs LOW 0.35) ==")
    for f in FILES:
        c = level_compare(rows_by_file[f], "FVG", args.iters)
        cmp_by_file[f] = c
        tag = "decision (primary)" if f == PRIMARY_FILE else (
            "stability partner" if f == STABILITY_FILE else "evidence")
        print("  %-10s (%s)" % (f, tag))
        print("    HIGH        %s" % fmt_stat(c["hi"]))
        print("    LOW         %s" % fmt_stat(c["lo"]))
        if c["delta"] is not None:
            dci = ""
            if c["dailyCi"]:
                dci = " dailyCI=[%.4f, %.4f] (d=%+.4f)" % (
                    c["dailyCi"]["lo"], c["dailyCi"]["hi"], c["dailyDelta"])
            if c["ci"]:
                print("    delta       %+.4f CI=[%.4f, %.4f] pairedDays=%d%s" % (
                    c["delta"], c["ci"]["lo"], c["ci"]["hi"],
                    c["pairedDays"], dci))
            else:
                print("    delta       %+.4f CI=n/a (paired days %d < %d)%s" % (
                    c["delta"], c["pairedDays"], MIN_PAIRED_DAYS, dci))
        else:
            print("    delta       n/a (paired days < %d)" % MIN_PAIRED_DAYS)

    print()
    print("== BOS level split (evidence-only, n-constrained) ==")
    for f in FILES:
        c = level_compare(rows_by_file[f], "BOS", args.iters)
        print("  %-10s HIGH n=%d LOW n=%d" % (f, c["hi"]["nClosed"],
                                              c["lo"]["nClosed"]))

    print()
    print("== pooled-level exploratory view (FVG+BOS, composition-gated) ==")
    pv = pooled_level_compare(rows_by_file[PRIMARY_FILE], ["FVG", "BOS"], args.iters)
    print("  nHigh=%d nLow=%d delta=%s CI=[%s, %s] confined=%s" % (
        pv["nHigh"], pv["nLow"],
        ("%.4f" % pv["delta"]) if pv["delta"] is not None else "n/a",
        ("%.4f" % pv["ci"]["lo"]) if pv["ci"] else "n/a",
        ("%.4f" % pv["ci"]["hi"]) if pv["ci"] else "n/a",
        pv["confined"] or "none"))

    print()
    print("== TT01 baseline cross-check (informational) ==")
    bc = baseline_cross_check(TT01_BASELINE)
    print("  %s" % json.dumps({k: v for k, v in bc.items() if k != "note"}) +
          ((" " + bc["note"]) if "note" in bc else ""))

    verdict, reason = decide(cmp_by_file, args.min_n, args.min_effect)
    print()
    print("== verdict: %s ==" % verdict)
    print("  %s" % reason)

    if args.json:
        out = {"audit": {"pass": True, "messages": msgs},
               "per_file": cmp_by_file,
               "pooled_level_view": pv,
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
