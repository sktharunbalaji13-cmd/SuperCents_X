#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ED01-E supplement: pre-registered secondary outputs not emitted by the
committed analyzer (protocol docs/Sprint20_ED01E_Protocol.md).

  -- Bonferroni sensitivity CIs (98.75%, section 7): cut from the SAME
     10,000 resample draws as the 95% CI per comparison (k = iters//160).
  -- Per-family decomposition (section 6): FVG/BOS/LIQUIDITY/UNKNOWN +
     CHOCH evidence-only, paired delta + 95% CI per family per file.
  -- Composition gates (section 9): UNKNOWN-exclusion and single-family
     concentration (FVG/BOS/LIQUIDITY removal) on the pooled H1 delta.
  -- Treatment rates (gate 3c): treated closed rows / closed rows per tier.
  -- Distributional secondaries: median R, R 25/75 quantiles, outcome
     distribution (WIN/LOSS/BREAKEVEN), TP-hit rates, transition matrix,
     nOpen - per arm per file.
  -- Decision-ladder evaluation (section 8): gates + selection rule on H1
     (primary) with M15 (stability) direction agreement; GBPJPY
     evidence-only.

Determinism: the 95% bootstrap path mirrors ED01_E_Analyze.py exactly
(same seed 20260813, same day_pairs/loop order) and MUST reproduce the
analyzer's pooled/daily CIs byte-for-byte - that is the cross-check.
All additional draws happen after the mirrored sequence.
"""
import importlib.util
import json
import os
import random

HERE = os.path.dirname(os.path.abspath(__file__))
ANALYZER = os.path.join(HERE, "ED01_E_Analyze.py")
ANALYSIS_JSON = os.path.join(HERE, "results_ED01E.json")
OUT_JSON = os.path.join(HERE, "results_ED01E_supplement.json")

spec = importlib.util.spec_from_file_location("ed01e", ANALYZER)
A = importlib.util.module_from_spec(spec)
spec.loader.exec_module(A)

random.seed(A.SEED)
ITERS = A.DEFAULT_ITERS
K95 = ITERS // 40       # 2.5% / 97.5%  (95% CI)
KBF = ITERS // 160      # 0.625% / 99.375% (Bonferroni 98.75% CI)
FAMILIES = ["FVG", "BOS", "LIQUIDITY", "UNKNOWN", "CHOCH"]


def closed(rows):
    return [r for r in rows if r.get("newDecision") == "1" and
            r.get("outcome") in ("1", "2", "3")]


def qualified(rows):
    return [r for r in rows if r.get("newDecision") == "1"]


def quantile(vals, q):
    if not vals:
        return None
    s = sorted(vals)
    k = int(round(q * (len(s) - 1)))
    return s[k]


def bootstrap_draws(pairs_by_day, days_union, iters):
    """Same day-stratified draw loop as the analyzer; keeps ALL draws so one
    resample set yields both the 95% and the Bonferroni 98.75% percentiles."""
    days = sorted(set(days_union))
    paired_days = [d for d in days if pairs_by_day.get(d)]
    n = len(days)
    pooled, daily = [], []
    for _ in range(iters):
        s = 0.0
        m = 0
        t = 0.0
        c = 0
        for _ in range(n):
            d = days[random.randrange(n)]
            vals = pairs_by_day.get(d, [])
            s += sum(vals)
            m += len(vals)
            if vals:
                t += sum(vals) / len(vals)
                c += 1
        pooled.append(s / max(m, 1))
        daily.append(t / max(c, 1))
    pooled.sort()
    daily.sort()
    return pooled, daily, len(paired_days)


def cut(pooled, daily, k):
    return ({"lo": pooled[k], "hi": pooled[len(pooled) - k - 1]},
            {"lo": daily[k], "hi": daily[len(daily) - k - 1]})


def arm_stats(rows):
    rv = [A.num(r, "rMultiple") for r in rows]
    n = len(rows)
    return {
        "n": n,
        "meanR": round(sum(rv) / n, 4) if n else None,
        "medianR": round(quantile(rv, 0.5), 4) if n else None,
        "q25R": round(quantile(rv, 0.25), 4) if n else None,
        "q75R": round(quantile(rv, 0.75), 4) if n else None,
        "winRate": round(sum(1 for r in rows if r.get("outcome") == "1") / n, 4)
        if n else None,
        "outcomeDist": {k: sum(1 for r in rows if r.get("outcome") == k)
                        for k in ("1", "2", "3")},
        "tpHitRate": A.tp_hit_rate(rows),
    }


def transition(cl_c, cl_a, key_fn):
    a = {key_fn(r): r for r in cl_c}
    b = {key_fn(r): r for r in cl_a}
    trans = {}
    for k in set(a) & set(b):
        t = (a[k].get("outcome", "?"), b[k].get("outcome", "?"))
        trans[t] = trans.get(t, 0) + 1
    return {"%s->%s" % t: v for t, v in sorted(trans.items())}


def main():
    if not os.path.isfile(ANALYSIS_JSON):
        print("missing %s - run the analyzer first" % ANALYSIS_JSON)
        return 2
    prev = json.load(open(ANALYSIS_JSON, encoding="utf-8"))

    loads = {}
    for f in A.FILES:
        ctrl = A.load_run(A.DEFAULT_ARTS, f, "CONTROL")
        arms = {k: A.load_run(A.DEFAULT_ARTS, f, k) for k in A.TIER_RUNS}
        loads[f] = (ctrl, arms)

    key_fn = (lambda r: r.get("decisionId", ""))

    # ---- mirrored main comparisons (RNG order identical to the analyzer)
    per_file = {}
    mismatches = []
    for f in A.FILES:
        ctrl, arms = loads[f]
        cl_c = closed(ctrl["rows"])
        pf = {}
        for kind in A.TIER_RUNS:
            arm = arms.get(kind)
            if arm is None:
                pf[kind] = {"error": "missing arm"}
                continue
            cl_a = closed(arm["rows"])
            pairs, (ua, ub, ncommon) = A.day_pairs(cl_c, cl_a, key_fn)
            days_union = set(A.day_of(r) for r in cl_c) | \
                set(A.day_of(r) for r in cl_a)
            pooled, daily, ndays = bootstrap_draws(pairs, days_union, ITERS)
            ci95, daily95 = cut(pooled, daily, K95)
            ci_bf, daily_bf = cut(pooled, daily, KBF)
            vals_c = [A.num(r, "rMultiple") for r in cl_c]
            vals_a = [A.num(r, "rMultiple") for r in cl_a]
            mean_c = sum(vals_c) / len(vals_c)
            mean_a = sum(vals_a) / len(vals_a)
            p = prev["perFile"][f][kind]
            for tag, got, want in (("ci95", ci95, p.get("ci")),
                                   ("daily95", daily95, p.get("dailyCi"))):
                if got != want:
                    mismatches.append("%s/%s %s %s != %s" % (f, kind, tag,
                                                             got, want))
            pf[kind] = {
                "tier": A.TIER_VALUES[kind],
                "nClosed": {"twoR": len(cl_c), "tier": len(cl_a)},
                "nPaired": ncommon,
                "unmatched": {"twoR": ua, "tier": ub},
                "meanR": {"twoR": round(mean_c, 4), "tier": round(mean_a, 4)},
                "delta": round(mean_a - mean_c, 4),
                "ci95": ci95, "dailyCi95": daily95,
                "ciBonf9875": ci_bf, "dailyCiBonf9875": daily_bf,
                "pairedDays": ndays,
                "twoR": arm_stats(cl_c), "tier": arm_stats(cl_a),
                "transition2RtoTier": transition(cl_c, cl_a, key_fn),
                "nOpen": {"twoR": sum(1 for r in qualified(ctrl["rows"])
                                      if r.get("outcome") == "0"),
                          "tier": sum(1 for r in qualified(arm["rows"])
                                      if r.get("outcome") == "0")},
                "treatedClosed": treated_count(cl_c, cl_a, key_fn),
            }
        per_file[f] = pf

    # ---- per-family decomposition (section 6; RNG continues after mirror)
    per_family = {}
    for f in A.FILES:
        ctrl, arms = loads[f]
        cl_c = closed(ctrl["rows"])
        fam = {}
        for fam_name in FAMILIES:
            for kind in A.TIER_RUNS:
                arm = arms.get(kind)
                if arm is None:
                    continue
                cl_a = [r for r in closed(arm["rows"])
                        if A.family_of(r) == fam_name]
                c_sub = [r for r in cl_c if A.family_of(r) == fam_name]
                pairs, (ua, ub, ncommon) = A.day_pairs(c_sub, cl_a, key_fn)
                if ncommon < 1:
                    fam.setdefault(fam_name, {})[kind] = {
                        "nPaired": 0, "note": "no paired rows"}
                    continue
                days_union = set(A.day_of(r) for r in c_sub) | \
                    set(A.day_of(r) for r in cl_a)
                pooled, daily, ndays = bootstrap_draws(pairs, days_union,
                                                       ITERS)
                ci95, daily95 = cut(pooled, daily, K95)
                vals_c = [A.num(r, "rMultiple") for r in c_sub]
                vals_a = [A.num(r, "rMultiple") for r in cl_a]
                fam.setdefault(fam_name, {})[kind] = {
                    "tier": A.TIER_VALUES[kind],
                    "nClosed": {"twoR": len(c_sub), "tier": len(cl_a)},
                    "nPaired": ncommon,
                    "delta": round(sum(vals_a) / len(vals_a) -
                                   sum(vals_c) / len(vals_c), 4),
                    "meanR": {"twoR": round(sum(vals_c) / len(vals_c), 4),
                              "tier": round(sum(vals_a) / len(vals_a), 4)},
                    "winRate": {
                        "twoR": round(sum(1 for r in c_sub
                                          if r.get("outcome") == "1") /
                                      len(c_sub), 4),
                        "tier": round(sum(1 for r in cl_a
                                          if r.get("outcome") == "1") /
                                      len(cl_a), 4)},
                    "ci95": ci95, "dailyCi95": daily95,
                    "pairedDays": ndays,
                }
        per_family[f] = fam

    # ---- composition gates on the primary file (section 9)
    comp = {}
    ctrl, arms = loads[A.PRIMARY_FILE]
    cl_c = closed(ctrl["rows"])
    for kind in A.TIER_RUNS:
        cl_a = closed(arms[kind]["rows"])
        full_delta = per_file[A.PRIMARY_FILE][kind]["delta"]
        out = {"fullPooledDelta": full_delta, "checks": {}}
        # UNKNOWN-exclusion
        c_sub = [r for r in cl_c if A.family_of(r) != "UNKNOWN"]
        a_sub = [r for r in cl_a if A.family_of(r) != "UNKNOWN"]
        pairs, (_, _, ncommon) = A.day_pairs(c_sub, a_sub, key_fn)
        if ncommon:
            days_union = set(A.day_of(r) for r in c_sub) | \
                set(A.day_of(r) for r in a_sub)
            pooled, daily, ndays = bootstrap_draws(pairs, days_union, ITERS)
            ci95, _ = cut(pooled, daily, K95)
            vals_c = [A.num(r, "rMultiple") for r in c_sub]
            vals_a = [A.num(r, "rMultiple") for r in a_sub]
            out["checks"]["excludeUNKNOWN"] = {
                "delta": round(sum(vals_a) / len(vals_a) -
                               sum(vals_c) / len(vals_c), 4),
                "ci95": ci95, "nPaired": ncommon, "pairedDays": ndays}
        # single-family concentration
        for fam in ("FVG", "BOS", "LIQUIDITY"):
            c_sub = [r for r in cl_c if A.family_of(r) != fam]
            a_sub = [r for r in cl_a if A.family_of(r) != fam]
            pairs, (_, _, ncommon) = A.day_pairs(c_sub, a_sub, key_fn)
            if not ncommon:
                continue
            days_union = set(A.day_of(r) for r in c_sub) | \
                set(A.day_of(r) for r in a_sub)
            pooled, daily, ndays = bootstrap_draws(pairs, days_union, ITERS)
            ci95, _ = cut(pooled, daily, K95)
            vals_c = [A.num(r, "rMultiple") for r in c_sub]
            vals_a = [A.num(r, "rMultiple") for r in a_sub]
            out["checks"]["minus%s" % fam] = {
                "delta": round(sum(vals_a) / len(vals_a) -
                               sum(vals_c) / len(vals_c), 4),
                "ci95": ci95, "nPaired": ncommon, "pairedDays": ndays}
        comp[kind] = out

    # ---- decision ladder (section 8) - H1 primary, M15 stability
    ladder = {"tiers": {}, "selected": None, "verdict": None}
    clears = []
    for kind in A.TIER_RUNS:
        h1 = per_file[A.PRIMARY_FILE][kind]
        m15 = per_file[A.STABILITY_FILE][kind]
        d_h1 = h1["delta"]
        ci_excl = h1["ci95"]["lo"] > 0 or h1["ci95"]["hi"] < 0
        daily_excl = h1["dailyCi95"]["lo"] > 0 or \
            h1["dailyCi95"]["hi"] < 0
        est_agree = (ci_excl == daily_excl)
        n_ok = h1["nClosed"]["tier"] >= A.MIN_N
        days_ok = h1["pairedDays"] >= A.MIN_PAIRED_DAYS
        material = abs(d_h1) >= A.MIN_EFFECT
        m15_agree = (d_h1 >= 0) == (m15["delta"] >= 0)
        bf_excl = h1["ciBonf9875"]["lo"] > 0 or \
            h1["ciBonf9875"]["hi"] < 0
        gate = {
            "delta": d_h1,
            "material": material,
            "ci95Excludes0": ci_excl,
            "dailyCi95Excludes0": daily_excl,
            "estimatorAgreement": est_agree,
            "nClosedTier": h1["nClosed"]["tier"],
            "nGe50": n_ok,
            "pairedDays": h1["pairedDays"],
            "daysGe10": days_ok,
            "m15DirectionAgree": m15_agree,
            "m15Delta": m15["delta"],
            "bonf9875Excludes0": bf_excl,
            "clears": material and ci_excl and est_agree and n_ok and
                      days_ok and m15_agree,
        }
        ladder["tiers"][kind] = gate
        if gate["clears"]:
            clears.append((abs(d_h1), d_h1, kind))
    clears.sort(key=lambda x: -x[0])
    if clears:
        ladder["selected"] = clears[0][2]
        ladder["verdict"] = "EVIDENCE - TIER SELECTED (%s)" % clears[0][2]
    else:
        any_excl = any(ladder["tiers"][k]["ci95Excludes0"]
                       for k in A.TIER_RUNS)
        if any_excl:
            ladder["verdict"] = "DEFER - CI excludes 0 but full gate not met"
        else:
            ladder["verdict"] = "REJECT - 2.0R REMAINS BEST (no tier clears)"
    ladder["clearedSorted"] = [c[2] for c in clears]

    out = {
        "seed": A.SEED, "iters": ITERS,
        "crosscheckVsAnalyzer": {
            "ok": len(mismatches) == 0, "mismatches": mismatches},
        "perFile": per_file,
        "perFamily": per_family,
        "compositionPrimaryH1": comp,
        "decisionLadder": ladder,
        "manifestCaveat": "manifest journal rows field read 2/0 (stale "
                          "agent-log parse); authoritative CSV row counts "
                          "exact (1558/1560/6239); faults=0 on all runs",
    }
    with open(OUT_JSON, "w", encoding="utf-8") as fh:
        json.dump(out, fh, indent=1)

    # ---- console report
    print("== ED01-E supplement (seed %d, %d iters) ==" % (A.SEED, ITERS))
    print("cross-check vs analyzer: %s" %
          ("MATCH (byte-identical 95% CIs)" if out["crosscheckVsAnalyzer"]["ok"]
           else "MISMATCH: %s" % out["crosscheckVsAnalyzer"]["mismatches"]))
    for f in A.FILES:
        print("--- %s ---" % f)
        for kind in A.TIER_RUNS:
            pf = per_file[f][kind]
            if "error" in pf:
                print("  %-6s %s" % (kind, pf["error"]))
                continue
            ci = pf["ci95"]
            bf = pf["ciBonf9875"]
            print("  %-6s delta=%+.4f 95CI=[%.4f,%.4f] 98.75CI=[%.4f,%.4f] "
                  "daily=[%.4f,%.4f] n2R=%d ntier=%d paired=%d days=%d "
                  "treated=%d WR(2R/tier)=%.4f/%.4f tpHit=%.4f/%.4f" %
                  (kind, pf["delta"], ci["lo"], ci["hi"], bf["lo"], bf["hi"],
                   pf["dailyCi95"]["lo"], pf["dailyCi95"]["hi"],
                   pf["nClosed"]["twoR"], pf["nClosed"]["tier"],
                   pf["nPaired"], pf["pairedDays"], pf["treatedClosed"],
                   pf["twoR"]["winRate"], pf["tier"]["winRate"],
                   pf["twoR"]["tpHitRate"], pf["tier"]["tpHitRate"]))
    print("--- per-family delta (paired, H1 primary) ---")
    for fam in FAMILIES:
        for kind in A.TIER_RUNS:
            e = per_family.get(A.PRIMARY_FILE, {}).get(fam, {}).get(kind)
            if not e or "delta" not in e:
                continue
            print("  %-9s %-6s n=(%d/%d) delta=%+.4f 95CI=[%.4f,%.4f]" %
                  (fam, kind, e["nClosed"]["twoR"], e["nClosed"]["tier"],
                   e["delta"], e["ci95"]["lo"], e["ci95"]["hi"]))
    print("--- composition (H1) ---")
    for kind in A.TIER_RUNS:
        c = comp[kind]
        print("  %-6s full=%+.4f" % (kind, c["fullPooledDelta"]))
        for name, e in c["checks"].items():
            print("      %-18s delta=%+.4f 95CI=[%.4f,%.4f] n=%d" %
                  (name, e["delta"], e["ci95"]["lo"], e["ci95"]["hi"],
                   e["nPaired"]))
    print("--- decision ladder ---")
    for kind, g in ladder["tiers"].items():
        print("  %-6s delta=%+.4f material=%s ci95=%s daily=%s agree=%s "
              "n=%d days=%d m15agree=%s bonf=%s clears=%s" %
              (kind, g["delta"], g["material"], g["ci95Excludes0"],
               g["dailyCi95Excludes0"], g["estimatorAgreement"],
               g["nClosedTier"], g["pairedDays"], g["m15DirectionAgree"],
               g["bonf9875Excludes0"], g["clears"]))
    print("verdict: %s" % ladder["verdict"])
    print("wrote %s" % OUT_JSON)
    return 0


def treated_count(cl_c, cl_a, key_fn):
    a = {key_fn(r): r for r in cl_c}
    b = {key_fn(r): r for r in cl_a}
    n = 0
    for k in set(a) & set(b):
        if A.num(a[k], "rMultiple") != A.num(b[k], "rMultiple"):
            n += 1
    return n


if __name__ == "__main__":
    import sys
    sys.exit(main())
