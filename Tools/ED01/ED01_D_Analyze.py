#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ED01-D analyzer: opposing-liquidity TP vs fixed-RR TP expectancy.

Frozen protocol: docs/Sprint20_ED01D_Protocol.md (FROZEN 2026-08-09).
Predecessor pattern: Tools/ED01/ED01_C_Analyze.py (loader/audit/bootstrap).

Modes:
  --selfcheck : audit the frozen CONTROL artifacts + pairing-key audit +
                estimator machinery probe + expected six-run manifest.
                No statistic is computed and no verdict is emitted (the
                opposing arm does not exist yet). FAILS LOUDLY on any
                frozen-constant, fingerprint, eligibility, or key-uniqueness
                violation. Writes results_ED01D_selfcheck.json.
  --gate      : pre-analysis gate (protocol section 11, gates 1/2/3a/3b/3c/5)
                against the six-run artifacts + two-arm manifest. FAILS
                LOUDLY when any run artifact, .done marker, or manifest
                entry is missing or violates a hard gate. Chooses and
                records the pairing key (decisionId vs canonical stable key).
  --analyze   : paired analysis (protocol section 5) after the gate passes.
                Requires both arms; refuses otherwise. Writes
                results_ED01D.json.

Determinism: random.seed(20260811) fixed once per run (protocol section 11
gate 4); reruns reproduce identical CIs and JSON byte-for-byte.
"""
import argparse
import csv
import glob
import hashlib
import json
import os
import random
import sys

PROJECT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DEFAULT_ARTS = os.path.join(PROJECT, "Tools", "ED01", "artifacts")
SELFCHECK_JSON = os.path.join(os.path.dirname(DEFAULT_ARTS), "results_ED01D_selfcheck.json")
ANALYSIS_JSON = os.path.join(os.path.dirname(DEFAULT_ARTS), "results_ED01D.json")
MANIFEST_JSON = os.path.join(os.path.dirname(DEFAULT_ARTS), "ED01_D_manifest.json")

# Frozen GR01 RULE_FAMILY map (same as ED01-C).
RULE_FAMILY = {
    "LIQUIDITY_BOS_BULLISH": "LIQUIDITY",
    "LIQUIDITY_BOS_BEARISH": "LIQUIDITY",
    "OB_FVG_BULLISH": "FVG",
    "OB_FVG_BEARISH": "FVG",
    "BOS_OB_BULLISH": "BOS",
    "BOS_OB_BEARISH": "BOS",
    "CHOCH_OB_REVERSAL": "CHOCH",
}

# Frozen per-file default-config fingerprints (protocol section 3).
FINGERPRINTS = {
    "EURUSD_H1": "3005138848403243456",
    "GBPJPY_H1": "14617585492269479818",
    "EURUSD_M15": "13548296177162108249",
}

PRIMARY_FILE = "EURUSD_H1"
STABILITY_FILE = "EURUSD_M15"
EVIDENCE_FILE = "GBPJPY_H1"
FILES = [PRIMARY_FILE, STABILITY_FILE, EVIDENCE_FILE]

RUN_DIRS = {
    "CONTROL": "CONTROL",
    "INTEGRITY": "CONTROL_ED01D_INTEGRITY",
    "OPPOSING": "CONTROL_ED01D_OPPOSING",
}

# Frozen audit constants (protocol 16.2 amendment, measured 2026-08-09).
AUDIT_TOTAL = {"EURUSD_H1": 1558, "GBPJPY_H1": 1560, "EURUSD_M15": 6239}
AUDIT_QUALIFIED = {"EURUSD_H1": 1468, "GBPJPY_H1": 236, "EURUSD_M15": 5981}
AUDIT_CLOSED = {
    "EURUSD_H1": {"LIQUIDITY": 607, "FVG": 318, "BOS": 378,
                  "CHOCH": 0, "UNKNOWN": 117},
    "GBPJPY_H1": {"LIQUIDITY": 96, "FVG": 39, "BOS": 59,
                  "CHOCH": 0, "UNKNOWN": 23},
    "EURUSD_M15": {"LIQUIDITY": 1694, "FVG": 2092, "BOS": 2095,
                   "CHOCH": 1, "UNKNOWN": 49},
}
AUDIT_ELIGIBLE = {"EURUSD_H1": 607, "GBPJPY_H1": 96, "EURUSD_M15": 1694}
AUDIT_ELIGIBLE_FAM = {
    "EURUSD_H1": {"LIQUIDITY": 607},
    "GBPJPY_H1": {"LIQUIDITY": 96},
    "EURUSD_M15": {"LIQUIDITY": 1694},
}
AUDIT_DAYS = {"EURUSD_H1": 55, "GBPJPY_H1": 23, "EURUSD_M15": 65}

WINDOW_START = "2026.04.05"
WINDOW_END = "2026.07.05"

SEED = 20260811
MIN_PAIRED_DAYS = 10
MIN_N = 50
MIN_EFFECT = 0.10
DEFAULT_ITERS = 10000

TREATMENT_FAMILY = "LIQUIDITY"

# Expected six-run set (protocol section 14): (file, run kind, EA mode).
SIX_RUNS = [
    ("EURUSD_H1", "INTEGRITY", "FIXED_RR"),
    ("GBPJPY_H1", "INTEGRITY", "FIXED_RR"),
    ("EURUSD_M15", "INTEGRITY", "FIXED_RR"),
    ("EURUSD_H1", "OPPOSING", "OPPOSING_LIQUIDITY"),
    ("GBPJPY_H1", "OPPOSING", "OPPOSING_LIQUIDITY"),
    ("EURUSD_M15", "OPPOSING", "OPPOSING_LIQUIDITY"),
]


def family_of(row):
    return RULE_FAMILY.get((row.get("ruleName") or "").strip(), "UNKNOWN")


def num(row, key):
    try:
        return float((row.get(key) or "0").strip())
    except ValueError:
        return 0.0


def day_of(row):
    return (row.get("timestamp") or "").split()[0]


def canonical_key(row):
    """Canonical stable decision identity (protocol 14):
    {signalTime, configFingerprint, symbol, timeframe}."""
    return (row.get("signalTime", ""), row.get("configFingerprint", ""),
            row.get("symbol", ""), row.get("timeframe", ""))


def load_run(art_dir, file_key, run_kind):
    """Load one run dir. Returns (rows, fingerprints, segments) or None."""
    d = os.path.join(art_dir, file_key, RUN_DIRS[run_kind])
    if not os.path.isdir(d):
        return None
    done = os.path.isfile(os.path.join(d, ".done"))
    rows = []
    segments = {}
    for path in sorted(glob.glob(os.path.join(d, "telemetry_v4_*.csv"))):
        with open(path, newline="", encoding="utf-16") as fh:
            seg = list(csv.DictReader(fh))
        rows.extend(seg)
        segments[os.path.basename(path)] = seg
    if not rows:
        return None
    fps = sorted({r.get("configFingerprint", "") for r in rows})
    return {"rows": rows, "fps": fps, "segments": segments,
            "done": done, "dir": d}


def qualified_rows(rows):
    return [r for r in rows if r.get("newDecision") == "1"]


def closed_rows(rows):
    return [r for r in rows if r.get("newDecision") == "1"
            and r.get("outcome") in ("1", "2", "3")]


def eligible_rows(rows):
    """Sweep-bearing eligible closed rows (protocol 16.2 amendment):
    closed AND hasLiquiditySweep == EV_TRUE ("2") - the engine records the
    sweep flag as "2" (TelemetryEvidenceState(true)=EV_TRUE); these are
    exactly the LIQUIDITY-family rows the opposing arm can treat."""
    return [r for r in rows if r.get("newDecision") == "1"
            and r.get("outcome") in ("1", "2", "3")
            and r.get("hasLiquiditySweep") == "2"]


def window_audit(rows, msgs, f, hard=True):
    """Timestamps must lie within the frozen window (protocol 3)."""
    bad = [r for r in rows if not (WINDOW_START <= day_of(r) <= WINDOW_END)]
    if bad:
        msgs.append(("FAIL " if hard else "WARN ") + "%s: %d rows outside "
                    "frozen window [%s, %s] (e.g. %s)" %
                    (f, len(bad), WINDOW_START, WINDOW_END, day_of(bad[0])))
        return hard
    return True


def audit_control(loads):
    """Protocol 11 gate 5 + section 16.2 frozen constants on CONTROL runs."""
    msgs = []
    ok = True
    for f in FILES:
        ld = loads.get(f)
        if not ld:
            msgs.append("FAIL %s: no CONTROL run (missing artifacts or .done)" % f)
            ok = False
            continue
        rows = ld["rows"]
        if not ld["done"]:
            msgs.append("FAIL %s: CONTROL missing .done marker" % f)
            ok = False
        if ld["fps"] != [FINGERPRINTS[f]]:
            msgs.append("FAIL %s: fingerprints %s != frozen %s" %
                        (f, ld["fps"], FINGERPRINTS[f]))
            ok = False
        if len(rows) != AUDIT_TOTAL[f]:
            msgs.append("FAIL %s: total rows %d != frozen %d" %
                        (f, len(rows), AUDIT_TOTAL[f]))
            ok = False
        nq = len(qualified_rows(rows))
        if nq != AUDIT_QUALIFIED[f]:
            msgs.append("FAIL %s: qualified %d != frozen %d" % (f, nq, AUDIT_QUALIFIED[f]))
            ok = False
        closed = closed_rows(rows)
        if len(closed) != sum(AUDIT_CLOSED[f].values()):
            msgs.append("FAIL %s: closed %d != frozen %d" %
                        (f, len(closed), sum(AUDIT_CLOSED[f].values())))
            ok = False
        closed_fam = {}
        for r in closed:
            fam = family_of(r)
            closed_fam[fam] = closed_fam.get(fam, 0) + 1
        for fam, exp in sorted(AUDIT_CLOSED[f].items()):
            if closed_fam.get(fam, 0) != exp:
                msgs.append("FAIL %s %s: closed %d != frozen %d" %
                            (f, fam, closed_fam.get(fam, 0), exp))
                ok = False
        elig = eligible_rows(rows)
        if len(elig) != AUDIT_ELIGIBLE[f]:
            msgs.append("FAIL %s: eligible %d != frozen %d" %
                        (f, len(elig), AUDIT_ELIGIBLE[f]))
            ok = False
        elig_fam = {}
        for r in elig:
            fam = family_of(r)
            elig_fam[fam] = elig_fam.get(fam, 0) + 1
        for fam, exp in sorted(AUDIT_ELIGIBLE_FAM[f].items()):
            if elig_fam.get(fam, 0) != exp:
                msgs.append("FAIL %s %s: eligible %d != frozen %d" %
                            (f, fam, elig_fam.get(fam, 0), exp))
                ok = False
        liq_closed = closed_fam.get("LIQUIDITY", 0)
        if len(elig) != liq_closed:
            msgs.append("FAIL %s: eligibility broken: eligible %d "
                        "!= LIQUIDITY closed %d (amendment 16.2)" %
                        (f, len(elig), liq_closed))
            ok = False
        liq_unflagged = [r for r in closed if family_of(r) == "LIQUIDITY"
                         and r.get("hasLiquiditySweep") != "2"]
        if liq_unflagged:
            msgs.append("FAIL %s: %d LIQUIDITY rows lack the sweep flag "
                        "EV_TRUE (\"2\") (structural fact violated)" %
                        (f, len(liq_unflagged)))
            ok = False
        nonliq_flagged = [r for r in closed if family_of(r) != "LIQUIDITY"
                          and r.get("hasLiquiditySweep") != "1"]
        if nonliq_flagged:
            msgs.append("FAIL %s: %d non-LIQUIDITY closed rows do not carry "
                        "EV_FALSE (\"1\") (fallback set corrupted)" %
                        (f, len(nonliq_flagged)))
            ok = False
        days = sorted({day_of(r) for r in elig})
        if len(days) != AUDIT_DAYS[f]:
            msgs.append("FAIL %s: eligible days %d != frozen %d" %
                        (f, len(days), AUDIT_DAYS[f]))
            ok = False
        ok = window_audit(rows, msgs, f, hard=True) and ok
    return ok, msgs


def pairing_audit(loads):
    """Cross-run pairing identity audit on CONTROL (protocol 14).

    Records: decisionId uniqueness per CSV segment, canonical-key uniqueness
    per segment and across the merged run. FAILS LOUDLY if the canonical key
    is not unique within a run (pairing would be silently invalid) or if
    decisionId repeats within a segment.
    """
    msgs = []
    ok = True
    for f in FILES:
        ld = loads.get(f)
        if not ld:
            continue
        rows = ld["rows"]
        all_keys = [canonical_key(r) for r in qualified_rows(rows)]
        if len(all_keys) != len(set(all_keys)):
            msgs.append("FAIL %s: duplicate canonical keys across merged run "
                        "(dups=%d)" % (f, len(all_keys) - len(set(all_keys))))
            ok = False
        for name, seg in sorted(ld["segments"].items()):
            ids = [r.get("decisionId", "") for r in seg]
            if len(ids) != len(set(ids)):
                msgs.append("FAIL %s: duplicate decisionId in segment %s "
                            "(dups=%d)" % (f, name, len(ids) - len(set(ids))))
                ok = False
            keys = [canonical_key(r) for r in seg]
            if len(keys) != len(set(keys)):
                msgs.append("FAIL %s: duplicate canonical keys in segment %s "
                            "(dups=%d)" % (f, name, len(keys) - len(set(keys))))
                ok = False
    return ok, msgs


def day_pairs(eligible_a, eligible_b, key_fn):
    """Pair eligible rows by key_fn; return (pairs_by_day, unmatched) where
    pairs_by_day[d] = list of d_r = rMultiple(b) - rMultiple(a)."""
    a = {key_fn(r): r for r in eligible_a}
    b = {key_fn(r): r for r in eligible_b}
    common = sorted(set(a) & set(b))
    pairs_by_day = {}
    for k in common:
        d_r = num(b[k], "rMultiple") - num(a[k], "rMultiple")
        pairs_by_day.setdefault(day_of(a[k]), []).append(d_r)
    unmatched_a = len(eligible_a) - len(common)
    unmatched_b = len(eligible_b) - len(common)
    return pairs_by_day, (unmatched_a, unmatched_b, len(common))


def paired_bootstrap_delta_ci(pairs_by_day, days_union, iters):
    """Protocol section 5 paired day-stratified bootstrap.

    Resample days with replacement from the union of days holding any
    eligible row; each sampled day contributes its paired OPPOSING-FIXED
    differences; the pooled mean of d_r over the sampled pairs is one draw.
    Auxiliary estimator: per-day mean of d_r over sampled days with pairs.
    Returns (pooled_ci, daily_ci, n_paired_days, observed_daily).
    """
    days = sorted(set(days_union))
    paired_days = [d for d in days if pairs_by_day.get(d)]
    if len(paired_days) < MIN_PAIRED_DAYS:
        return None, None, len(paired_days), None
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
    k = iters // 40
    obs_d = sum(sum(pairs_by_day[d]) / len(pairs_by_day[d])
                for d in paired_days) / len(paired_days)
    return ({"lo": pooled[k], "hi": pooled[iters - k - 1]},
            {"lo": daily[k], "hi": daily[iters - k - 1]},
            len(paired_days), obs_d)


def machinery_probe(loads, iters):
    """FIXED vs FIXED estimator probe (no opposing arm yet).

    Self-pairing the CONTROL run against itself by canonical key must yield
    delta == 0 exactly and a CI including 0 for every file. Exercises the
    bootstrap path deterministically; output feeds the determinism check.
    """
    out = {}
    for f in FILES:
        ld = loads.get(f)
        if not ld:
            out[f] = {"error": "no CONTROL run"}
            continue
        elig = eligible_rows(ld["rows"])
        pairs, (ua, ub, ncommon) = day_pairs(elig, elig, canonical_key)
        ci, daily_ci, ndays, obs_d = paired_bootstrap_delta_ci(
            pairs, [day_of(r) for r in elig], iters)
        if ci is None:
            out[f] = {"nPaired": ncommon, "pairedDays": ndays,
                      "error": "paired days < %d" % MIN_PAIRED_DAYS}
            continue
        out[f] = {"nEligible": len(elig), "nPaired": ncommon,
                  "pairedDays": ndays, "ci": ci, "dailyCi": daily_ci,
                  "observedDailyDelta": round(obs_d, 6),
                  "ciIncludesZero": ci["lo"] <= 0.0 <= ci["hi"]}
    return out


def expected_manifest():
    """Expected two-arm manifest spec (protocol 14) for the six runs."""
    runs = []
    for f, kind, mode in SIX_RUNS:
        runs.append({
            "file": f, "kind": kind, "mode": mode,
            "artifactDir": os.path.join("Tools/ED01/artifacts", f,
                                        RUN_DIRS[kind]),
            "profile": os.path.join("Tools/ED01/ini", "%s_CONTROL.ini" % f),
            "fingerprint": FINGERPRINTS[f],
            "expected": {"total": AUDIT_TOTAL[f],
                         "qualified": AUDIT_QUALIFIED[f],
                         "closed": sum(AUDIT_CLOSED[f].values())},
            "done": ".done marker required", "status": "PENDING",
        })
    return {"runs": runs,
            "manifestFile": "Tools/ED01/ED01_D_manifest.json",
            "profile": "Control profile + OutcomeTpMode=1 for OPPOSING "
                       "(EA input ENUM_OUTCOME_TP_MODE, commit 8954332)",
            "window": [WINDOW_START, WINDOW_END],
            "pairingKey": "decisionId if integrity gate 3a proves it "
                          "invariant, else canonical {signalTime, "
                          "configFingerprint, symbol, timeframe} "
                          "(uniqueness verified by audit)"}


def gate_six_runs(art_dir):
    """Pre-analysis gate (protocol 11 gates 1/2/3a/3b/3c/5 + manifest).

    FAILS LOUDLY on any missing artifact, .done, or manifest entry, and on
    any gate violation. Returns (ok, msgs, pairing_key, pairing_proof).
    """
    msgs = []
    ok = True
    manifest = None
    if os.path.isfile(MANIFEST_JSON):
        try:
            with open(MANIFEST_JSON, encoding="utf-8-sig") as fh:
                manifest = json.load(fh)
        except (ValueError, OSError) as e:
            msgs.append("FAIL manifest: unreadable %s (%s)" % (MANIFEST_JSON, e))
            ok = False
    else:
        msgs.append("FAIL: two-arm manifest missing: %s" % MANIFEST_JSON)
        ok = False

    loads = {}
    for f, kind, mode in SIX_RUNS:
        ld = load_run(art_dir, f, kind)
        if ld is None:
            msgs.append("FAIL %s/%s: artifacts missing (need %s)" %
                        (f, RUN_DIRS[kind],
                         os.path.join(art_dir, f, RUN_DIRS[kind])))
            ok = False
            continue
        if not ld["done"]:
            msgs.append("FAIL %s/%s: missing .done marker" % (f, RUN_DIRS[kind]))
            ok = False
        loads.setdefault(f, {})[kind] = ld

    # CONTROL (frozen arm) is required for gates 3a/3b/3c; missing CONTROL
    # must fail loudly, never silently skip the core integrity gates.
    for f in FILES:
        ctrl = load_run(art_dir, f, "CONTROL")
        if ctrl is None:
            msgs.append("FAIL %s/CONTROL: frozen arm artifacts missing (need "
                        "%s)" % (f, os.path.join(art_dir, f, "CONTROL")))
            ok = False
        else:
            if not ctrl["done"]:
                msgs.append("FAIL %s/CONTROL: missing .done marker" % f)
                ok = False
            loads.setdefault(f, {})["CONTROL"] = ctrl

    if manifest is not None:
        for f, kind, mode in SIX_RUNS:
            present = False
            for entry in (manifest.get("runs") or []):
                if (entry.get("file") == f and entry.get("kind") == kind
                        and entry.get("mode") == mode):
                    present = True
                    if entry.get("status") != "DONE":
                        msgs.append("FAIL manifest %s/%s: status %s != DONE" %
                                    (f, kind, entry.get("status")))
                        ok = False
            if not present:
                msgs.append("FAIL manifest: missing entry %s/%s/%s" %
                            (f, kind, mode))
                ok = False

    # Gates 1 + 2 on every available run (both arms).
    for f in FILES:
        for kind in ("CONTROL", "INTEGRITY", "OPPOSING"):
            ld = loads.get(f, {}).get(kind)
            if ld is None:
                continue
            rows = ld["rows"]
            if ld["fps"] != [FINGERPRINTS[f]]:
                msgs.append("FAIL gate1 %s/%s: fingerprints %s != frozen %s" %
                            (f, kind, ld["fps"], FINGERPRINTS[f]))
                ok = False
            nq = len(qualified_rows(rows))
            ncl = len(closed_rows(rows))
            if len(rows) != AUDIT_TOTAL[f] or nq != AUDIT_QUALIFIED[f] \
                    or ncl != sum(AUDIT_CLOSED[f].values()):
                msgs.append("FAIL gate2 %s/%s: rows %d/%d/%d != frozen "
                            "%d/%d/%d" % (f, kind, len(rows), nq, ncl,
                                          AUDIT_TOTAL[f], AUDIT_QUALIFIED[f],
                                          sum(AUDIT_CLOSED[f].values())))
                ok = False

    # Gate 3a: integrity reruns row-for-row byte-identical to CONTROL.
    pairing_key = "canonical"
    pairing_proof = []
    for f in FILES:
        ctrl = loads.get(f, {}).get("CONTROL")
        integ = loads.get(f, {}).get("INTEGRITY")
        if ctrl is None or integ is None:
            continue
        c_seg, i_seg = ctrl["segments"], integ["segments"]
        if sorted(c_seg) != sorted(i_seg):
            msgs.append("FAIL gate3a %s: segment file sets differ: %s vs %s" %
                        (f, sorted(c_seg), sorted(i_seg)))
            ok = False
            continue
        seg_ok = True
        for name in sorted(c_seg):
            crows = sorted(c_seg[name], key=lambda r: r.get("decisionId", ""))
            irows = sorted(i_seg[name], key=lambda r: r.get("decisionId", ""))
            if len(crows) != len(irows):
                msgs.append("FAIL gate3a %s %s: row count %d != CONTROL %d" %
                            (f, name, len(irows), len(crows)))
                ok = False
                seg_ok = False
                continue
            if not crows:
                continue
            cols = sorted(crows[0].keys())
            for a, b in zip(crows, irows):
                if sorted(a.keys()) != sorted(b.keys()) or \
                        any(a[c] != b[c] for c in cols):
                    msgs.append("FAIL gate3a %s %s: row-for-row divergence "
                                "(decisionId=%s)" %
                                (f, name, a.get("decisionId", "")))
                    ok = False
                    seg_ok = False
                    break
        if seg_ok:
            pairing_proof.append("%s: decisionId invariant (integrity "
                                 "reproduces CONTROL row-for-row)" % f)
        else:
            pairing_proof.append("%s: decisionId NOT proven invariant -> "
                                 "canonical stable key" % f)
    if pairing_proof:
        pairing_key = "decisionId" if all(
            "invariant" in p for p in pairing_proof) else "canonical"

    # Gate 3b: ineligible (non-LIQUIDITY, flag EV_FALSE "1") fallback
    # byte-identical in opposing arm (amendment 16.2 - the fallback proof
    # set is the non-LIQUIDITY closed rows).
    for f in FILES:
        ctrl = loads.get(f, {}).get("CONTROL")
        opp = loads.get(f, {}).get("OPPOSING")
        if ctrl is None or opp is None:
            continue
        fb_c = {canonical_key(r): r for r in closed_rows(ctrl["rows"])
                if family_of(r) != "LIQUIDITY"}
        fb_o = {canonical_key(r): r for r in closed_rows(opp["rows"])
                if family_of(r) != "LIQUIDITY"}
        if set(fb_c) != set(fb_o):
            msgs.append("FAIL gate3b %s: fallback row identity sets differ "
                        "(%d vs %d)" % (f, len(fb_c), len(fb_o)))
            ok = False
            continue
        cols = None
        diverged = 0
        for k in fb_c:
            a, b = fb_c[k], fb_o[k]
            cols = cols or sorted(a.keys())
            if any(a[c] != b[c] for c in cols):
                diverged += 1
        if diverged:
            msgs.append("FAIL gate3b %s: %d/%d fallback rows diverged in "
                        "opposing arm (fallback NOT byte-identical)" %
                        (f, diverged, len(fb_c)))
            ok = False

    # Gate 3c: at-scale distinguishability in the opposing arm.
    for f in FILES:
        ctrl = loads.get(f, {}).get("CONTROL")
        opp = loads.get(f, {}).get("OPPOSING")
        if ctrl is None or opp is None:
            continue
        elig_c = eligible_rows(ctrl["rows"])
        elig_o = eligible_rows(opp["rows"])
        map_c = {canonical_key(r): r for r in elig_c}
        map_o = {canonical_key(r): r for r in elig_o}
        common = set(map_c) & set(map_o)
        changed = [k for k in common if map_c[k] != map_o[k]]
        if not changed:
            msgs.append("FAIL gate3c %s: zero treated eligible rows "
                        "(opposing arm indistinguishable at scale)" % f)
            ok = False
            continue
        diff_r = [k for k in changed
                  if num(map_o[k], "rMultiple") != num(map_c[k], "rMultiple")]
        if not diff_r:
            msgs.append("FAIL gate3c %s: eligible rows changed but all "
                        "rMultiple identical (no treatment effect visible)" % f)
            ok = False
    return ok, msgs, pairing_key, pairing_proof


def analyze(art_dir, iters):
    """Paired analysis (protocol section 5) - only after the gate passes."""
    msgs = []
    gate_ok, gate_msgs, pairing_key, pairing_proof = gate_six_runs(art_dir)
    if not gate_ok:
        return {"gate": {"pass": False, "messages": gate_msgs},
                "note": "run set rejected; no statistics computed"}, False
    loads = {}
    for f in FILES:
        ctrl = load_run(art_dir, f, "CONTROL")
        opp = load_run(art_dir, f, "OPPOSING")
        loads[f] = (ctrl, opp)
    key_fn = (lambda r: r.get("decisionId", "")) if pairing_key == "decisionId" \
        else canonical_key
    per_file = {}
    for f in FILES:
        ctrl, opp = loads[f]
        elig_c = eligible_rows(ctrl["rows"])
        elig_o = eligible_rows(opp["rows"])
        pairs, (ua, ub, ncommon) = day_pairs(elig_c, elig_o, key_fn)
        days_union = set(day_of(r) for r in elig_c) | \
            set(day_of(r) for r in elig_o)
        ci, daily_ci, ndays, obs_d = paired_bootstrap_delta_ci(
            pairs, days_union, iters)
        vals_c = [num(r, "rMultiple") for r in elig_c]
        vals_o = [num(r, "rMultiple") for r in elig_o]
        mean_f = sum(vals_c) / len(vals_c) if vals_c else None
        mean_o = sum(vals_o) / len(vals_o) if vals_o else None
        delta = (mean_o - mean_f) if (mean_f is not None and mean_o is not None) \
            else None
        per_file[f] = {
            "nEligible": {"fixed": len(elig_c), "opposing": len(elig_o)},
            "nPaired": ncommon, "unmatched": {"fixed": ua, "opposing": ub},
            "meanR": {"fixed": round(mean_f, 4) if mean_f is not None else None,
                      "opposing": round(mean_o, 4) if mean_o is not None else None},
            "delta": round(delta, 4) if delta is not None else None,
            "ci": ci, "dailyCi": daily_ci, "observedDailyDelta": obs_d,
            "pairedDays": ndays,
            "nOpen": {"fixed": sum(1 for r in qualified_rows(ctrl["rows"])
                                   if r.get("outcome") == "0"),
                      "opposing": sum(1 for r in qualified_rows(opp["rows"])
                                      if r.get("outcome") == "0")},
        }
    return ({"gate": {"pass": True, "messages": gate_msgs,
                      "pairingKey": pairing_key, "pairingProof": pairing_proof},
             "perFile": per_file, "thresholds": {"minEffect": MIN_EFFECT,
                                                 "minN": MIN_N,
                                                 "iters": iters, "seed": SEED},
             "note": "delta = MeanR(OPPOSING) - MeanR(FIXED); verdict and "
                     "decision ladder are computed in the decision report"},
            True)


def run_selfcheck(art_dir, iters, json_path):
    loads = {}
    for f in FILES:
        ld = load_run(art_dir, f, "CONTROL")
        if ld is not None:
            loads[f] = ld
    ok, msgs = audit_control(loads)
    p_ok, p_msgs = pairing_audit(loads)
    ok = ok and p_ok
    probe = machinery_probe(loads, iters)
    for f in FILES:
        if probe.get(f) and "ci" in probe[f] and \
                not probe[f]["ciIncludesZero"]:
            ok = False
            msgs.append("FAIL %s: machinery probe CI excludes 0 on FIXED vs "
                        "FIXED (bootstrap corruption)" % f)
    out = {
        "mode": "selfcheck",
        "seed": SEED,
        "audit": {"pass": ok, "messages": msgs},
        "pairingAudit": {"pass": p_ok, "messages": p_msgs},
        "machineryProbe": probe,
        "expectedManifest": expected_manifest(),
        "gateReadiness": "six-run artifacts + manifest required before "
                         "--gate; currently PENDING (expected: no new runs "
                         "until authorized)",
    }
    with open(json_path, "w") as fh:
        json.dump(out, fh, indent=1)
    return ok, out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--artifacts", default=DEFAULT_ARTS)
    ap.add_argument("--iters", type=int, default=DEFAULT_ITERS)
    ap.add_argument("--mode", choices=["selfcheck", "gate", "analyze"],
                    default="selfcheck")
    ap.add_argument("--json")
    args = ap.parse_args()
    random.seed(SEED)

    if args.mode == "selfcheck":
        json_path = args.json or SELFCHECK_JSON
        ok, out = run_selfcheck(args.artifacts, args.iters, json_path)
        print("== ED01-D self-check (seed %d) ==" % SEED)
        print("audit:")
        for m in out["audit"]["messages"]:
            print("  %s" % m)
        if ok:
            print("  audit PASS (fingerprints + totals + qualified + closed + "
                  "per-family + eligible + complement + days + window)")
        print("pairing audit:")
        for m in out["pairingAudit"]["messages"]:
            print("  %s" % m)
        if p_ok := out["pairingAudit"]["pass"]:
            print("  pairing PASS (canonical keys unique; decisionId unique "
                  "per segment)")
        print("estimator machinery probe (FIXED vs FIXED, delta=0 expected):")
        for f in FILES:
            pr = out["machineryProbe"].get(f, {})
            if "ci" in pr:
                print("  %-10s nEligible=%d nPaired=%d CI=[%.4f, %.4f] "
                      "dailyCI=[%.4f, %.4f] includes0=%s" %
                      (f, pr["nEligible"], pr["nPaired"], pr["ci"]["lo"],
                       pr["ci"]["hi"], pr["dailyCi"]["lo"],
                       pr["dailyCi"]["hi"], pr["ciIncludesZero"]))
            else:
                print("  %-10s %s" % (f, pr.get("error", "n/a")))
        print("expected six-run manifest (%d runs, all PENDING):" %
              len(out["expectedManifest"]["runs"]))
        for r in out["expectedManifest"]["runs"]:
            print("  %-10s %-8s mode=%-18s %s" %
                  (r["file"], r["kind"], r["mode"], r["artifactDir"]))
        print("wrote %s" % json_path)
        if not ok:
            print("SELF-CHECK FAILED - frozen constants/fingerprints/keys not "
                  "reproduced.")
            return 1
        print("SELF-CHECK PASS - analyzer is deterministic and CONTROL "
              "population reproduces the frozen audit constants.")
        return 0

    if args.mode == "gate":
        ok, msgs, pairing_key, pairing_proof = gate_six_runs(args.artifacts)
        print("== ED01-D pre-analysis gate (protocol 11) ==")
        for m in msgs:
            print("  %s" % m)
        if pairing_proof:
            print("pairing key: %s" % pairing_key)
            for p in pairing_proof:
                print("  %s" % p)
        if not ok:
            print("GATE FAILED - run set incomplete or invalid; no statistics "
                  "computed; re-run after audit.")
            return 1
        print("GATE PASS - all integrity/fallback/distinguishability gates "
              "passed; pairing key: %s" % pairing_key)
        return 0

    out, gate_ok = analyze(args.artifacts, args.iters)
    json_path = args.json or ANALYSIS_JSON
    with open(json_path, "w") as fh:
        json.dump(out, fh, indent=1)
    print("== ED01-D analysis (paired, seed %d) ==" % SEED)
    if not gate_ok:
        for m in out["gate"]["messages"]:
            print("  %s" % m)
        print("GATE FAILED - no statistics computed; run set rejected.")
        return 1
    for f in FILES:
        pf = out["perFile"][f]
        ci = pf["ci"]
        cistr = ("CI=[%.4f, %.4f]" % (ci["lo"], ci["hi"])) if ci else "CI=n/a"
        print("  %-10s delta=%s %s pairedDays=%d paired=%d" %
              (f, ("%+.4f" % pf["delta"]) if pf["delta"] is not None else "n/a",
               cistr, pf["pairedDays"], pf["nPaired"]))
    print("pairing key: %s" % out["gate"]["pairingKey"])
    print("wrote %s" % json_path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
