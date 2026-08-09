#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ED01-E analyzer: fixed-RR TP tier sweep vs the 2.0R baseline.

Frozen protocol: docs/Sprint20_ED01E_Protocol.md (FROZEN 2026-08-09).
Predecessor pattern: Tools/ED01/ED01_D_Analyze.py (loader/audit/bootstrap).

Modes:
  --selfcheck : audit the frozen CONTROL artifacts (frozen constants,
                fingerprints, pairing-key uniqueness) + estimator machinery
                probe (CONTROL vs CONTROL self-pairing, delta == 0) +
                expected 15-run manifest. No statistic on the tiers and no
                verdict is emitted (tier artifacts do not exist yet).
                FAILS LOUDLY on any violation. Writes
                results_ED01E_selfcheck.json.
  --gate      : pre-analysis gate (protocol section 11, gates 1/2/3a/3b/3c
                + TP-hit monotonicity warning) against the 15-run artifacts
                + tier manifest. FAILS LOUDLY when any run artifact, .done
                marker, or manifest entry is missing or violates a hard
                gate. Chooses and records the pairing key (decisionId vs
                canonical stable key).
  --analyze   : paired analysis (protocol section 5) after the gate passes.
                Four pre-registered comparisons per file (1.0/1.5/2.5/3.0
                vs 2.0R CONTROL); delta = MeanR(tier) - MeanR(2R). Writes
                results_ED01E.json.

Determinism: random.seed(20260813) fixed once per run (protocol section 11
gate 4); reruns reproduce identical CIs and JSON byte-for-byte.
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
SELFCHECK_JSON = os.path.join(os.path.dirname(DEFAULT_ARTS), "results_ED01E_selfcheck.json")
ANALYSIS_JSON = os.path.join(os.path.dirname(DEFAULT_ARTS), "results_ED01E.json")
MANIFEST_JSON = os.path.join(os.path.dirname(DEFAULT_ARTS), "ED01_E_manifest.json")

# Frozen GR01 RULE_FAMILY map (same as ED01-C/D).
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
    "INTEGRITY": "CONTROL_ED01E_INTEGRITY",
    "TP1R": "CONTROL_ED01E_TP1R",
    "TP1P5R": "CONTROL_ED01E_TP1P5R",
    "TP2P5R": "CONTROL_ED01E_TP2P5R",
    "TP3R": "CONTROL_ED01E_TP3R",
}
TIER_RUNS = ["TP1R", "TP1P5R", "TP2P5R", "TP3R"]
TIER_VALUES = {"TP1R": 1.0, "TP1P5R": 1.5, "TP2P5R": 2.5, "TP3R": 3.0}

# Frozen audit constants (protocol section 3, measured 2026-08-09).
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
AUDIT_DAYS = {"EURUSD_H1": 63, "GBPJPY_H1": 41, "EURUSD_M15": 65}
# Baseline (2.0R) statistics, informational (protocol section 3).
BASELINE_MEANR = {"EURUSD_H1": -0.0239, "GBPJPY_H1": -0.0599, "EURUSD_M15": -0.0126}
BASELINE_WR = {"EURUSD_H1": 0.3254, "GBPJPY_H1": 0.3134, "EURUSD_M15": 0.3315}

WINDOW_START = "2026.04.05"
WINDOW_END = "2026.07.05"

SEED = 20260813
MIN_PAIRED_DAYS = 10
MIN_N = 50
MIN_EFFECT = 0.10
DEFAULT_ITERS = 10000

# Columns the tier may legitimately change (protocol 11 gate 3b).
OUTCOME_COLS = {"outcome", "rMultiple", "barsHeld", "exitPrice",
                "exitReason", "outcomeSource"}

# Expected 15-run set (protocol section 14): (file, run kind).
FIFTEEN_RUNS = [
    ("EURUSD_H1", "INTEGRITY"), ("GBPJPY_H1", "INTEGRITY"), ("EURUSD_M15", "INTEGRITY"),
    ("EURUSD_H1", "TP1R"), ("EURUSD_H1", "TP1P5R"), ("EURUSD_H1", "TP2P5R"), ("EURUSD_H1", "TP3R"),
    ("GBPJPY_H1", "TP1R"), ("GBPJPY_H1", "TP1P5R"), ("GBPJPY_H1", "TP2P5R"), ("GBPJPY_H1", "TP3R"),
    ("EURUSD_M15", "TP1R"), ("EURUSD_M15", "TP1P5R"), ("EURUSD_M15", "TP2P5R"), ("EURUSD_M15", "TP3R"),
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
    """ALL closed rows, all families (protocol section 3 - the TP-distance
    question applies to every settled row of the entry population)."""
    return [r for r in rows if r.get("newDecision") == "1"
            and r.get("outcome") in ("1", "2", "3")]


def tp_hit_rate(closed):
    """Share of closed rows exiting at the TP target (exitReason ==
    EXIT_REASON_TP == 1, TelemetryTypes.mqh:143-149)."""
    if not closed:
        return None
    return sum(1 for r in closed if r.get("exitReason") == "1") / len(closed)


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
    """Protocol 11 gate 5 + section 3 frozen constants on CONTROL runs."""
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
        days = sorted({day_of(r) for r in closed})
        if len(days) != AUDIT_DAYS[f]:
            msgs.append("FAIL %s: closed days %d != frozen %d" %
                        (f, len(days), AUDIT_DAYS[f]))
            ok = False
        ok = window_audit(rows, msgs, f, hard=True) and ok
    return ok, msgs


def pairing_audit(loads):
    """Cross-run pairing identity audit on CONTROL (protocol 14)."""
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


def day_pairs(rows_a, rows_b, key_fn):
    """Pair closed rows by key_fn; return (pairs_by_day, unmatched) where
    pairs_by_day[d] = list of d_r = rMultiple(b) - rMultiple(a)."""
    a = {key_fn(r): r for r in rows_a}
    b = {key_fn(r): r for r in rows_b}
    common = sorted(set(a) & set(b))
    pairs_by_day = {}
    for k in common:
        d_r = num(b[k], "rMultiple") - num(a[k], "rMultiple")
        pairs_by_day.setdefault(day_of(a[k]), []).append(d_r)
    unmatched_a = len(rows_a) - len(common)
    unmatched_b = len(rows_b) - len(common)
    return pairs_by_day, (unmatched_a, unmatched_b, len(common))


def paired_bootstrap_delta_ci(pairs_by_day, days_union, iters):
    """Protocol section 5 paired day-stratified bootstrap (seed set once).

    Resample days with replacement from the union of days holding any
    closed row; each sampled day contributes its paired TIER-2R
    differences; the pooled mean of d_r over the sampled pairs is one
    draw. Auxiliary estimator: per-day mean of d_r over sampled days with
    pairs. Returns (pooled_ci, daily_ci, n_paired_days, observed_daily).
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
    """CONTROL vs CONTROL self-pairing probe (no tier arm yet).

    Self-pairing the CONTROL run against itself by canonical key must
    yield delta == 0 exactly and a CI including 0 for every file.
    Exercises the bootstrap path deterministically.
    """
    out = {}
    for f in FILES:
        ld = loads.get(f)
        if not ld:
            out[f] = {"error": "no CONTROL run"}
            continue
        cl = closed_rows(ld["rows"])
        pairs, (ua, ub, ncommon) = day_pairs(cl, cl, canonical_key)
        ci, daily_ci, ndays, obs_d = paired_bootstrap_delta_ci(
            pairs, [day_of(r) for r in cl], iters)
        if ci is None:
            out[f] = {"nPaired": ncommon, "pairedDays": ndays,
                      "error": "paired days < %d" % MIN_PAIRED_DAYS}
            continue
        out[f] = {"nClosed": len(cl), "nPaired": ncommon,
                  "pairedDays": ndays, "ci": ci, "dailyCi": daily_ci,
                  "observedDailyDelta": round(obs_d, 6),
                  "ciIncludesZero": ci["lo"] <= 0.0 <= ci["hi"]}
    return out


def expected_manifest():
    """Expected 15-run tier manifest spec (protocol 14)."""
    runs = []
    for f, kind in FIFTEEN_RUNS:
        runs.append({
            "file": f, "kind": kind, "tier": TIER_VALUES.get(kind, 2.0),
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
            "manifestFile": "Tools/ED01/ED01_E_manifest.json",
            "profile": "Control profile + FixedRRTier input only "
                       "(EA input double FixedRRTier, default 2.0; "
                       "OutcomeTpMode stays FIXED_RR)",
            "window": [WINDOW_START, WINDOW_END],
            "pairingKey": "decisionId if integrity gate 3a proves it "
                          "invariant, else canonical {signalTime, "
                          "configFingerprint, symbol, timeframe} "
                          "(uniqueness verified by audit)"}


def gate_fifteen_runs(art_dir):
    """Pre-analysis gate (protocol 11 gates 1/2/3a/3b/3c/5 + manifest
    + TP-hit monotonicity warning).

    FAILS LOUDLY on any missing artifact, .done, or manifest entry, and on
    any hard gate violation. Returns (ok, msgs, pairing_key, pairing_proof,
    monotonicity).
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
        msgs.append("FAIL: tier manifest missing: %s" % MANIFEST_JSON)
        ok = False

    loads = {}
    for f, kind in FIFTEEN_RUNS:
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
        for f, kind in FIFTEEN_RUNS:
            present = False
            for entry in (manifest.get("runs") or []):
                if (entry.get("file") == f and entry.get("kind") == kind):
                    present = True
                    tier = entry.get("tier")
                    if tier is None:
                        msgs.append("FAIL manifest %s/%s: missing tier field" %
                                    (f, kind))
                        ok = False
                    elif float(tier) != TIER_VALUES.get(kind, 2.0):
                        msgs.append("FAIL manifest %s/%s: tier %s != frozen %s" %
                                    (f, kind, tier, TIER_VALUES.get(kind, 2.0)))
                        ok = False
                    if entry.get("status") != "DONE":
                        msgs.append("FAIL manifest %s/%s: status %s != DONE" %
                                    (f, kind, entry.get("status")))
                        ok = False
            if not present:
                msgs.append("FAIL manifest: missing entry %s/%s" % (f, kind))
                ok = False

    # Gates 1 + 2 on every available run (all arms).
    for f in FILES:
        for kind in ["CONTROL"] + ["INTEGRITY"] + TIER_RUNS:
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

    # Gate 3a: integrity reruns (2.0R tier, new code) row-for-row
    # byte-identical to CONTROL (decisionId + all 75 columns).
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

    # Gate 3b: decision-identity invariance across tiers - all columns
    # identical to CONTROL except the outcome columns. Gate 3c:
    # distinguishability per tier - at least one closed row with rMultiple
    # differing from CONTROL.
    for f in FILES:
        ctrl = loads.get(f, {}).get("CONTROL")
        if ctrl is None:
            continue
        key_fn = (lambda r: r.get("decisionId", "")) if pairing_key == "decisionId" \
            else canonical_key
        for kind in TIER_RUNS:
            arm = loads.get(f, {}).get(kind)
            if arm is None:
                continue
            c_seg, a_seg = ctrl["segments"], arm["segments"]
            if sorted(c_seg) != sorted(a_seg):
                msgs.append("FAIL gate3b %s/%s: segment file sets differ: "
                            "%s vs %s" % (f, kind, sorted(c_seg), sorted(a_seg)))
                ok = False
                continue
            outside = []
            treated = 0
            for name in sorted(c_seg):
                crows = {key_fn(r): r for r in c_seg[name]}
                arows = {key_fn(r): r for r in a_seg[name]}
                if set(crows) != set(arows):
                    msgs.append("FAIL gate3b %s/%s %s: decision identity sets "
                                "differ (%d vs %d) - tier perturbed decisions" %
                                (f, kind, name, len(crows), len(arows)))
                    ok = False
                    continue
                for k in crows:
                    a, b = crows[k], arows[k]
                    if sorted(a.keys()) != sorted(b.keys()):
                        outside.append((name, k, "column set differs"))
                        continue
                    for c in sorted(a.keys()):
                        if c in OUTCOME_COLS:
                            continue
                        if a[c] != b[c]:
                            outside.append((name, k, c))
                    if num(a, "rMultiple") != num(b, "rMultiple"):
                        treated += 1
            if outside:
                msgs.append("FAIL gate3b %s/%s: %d row(s) differ outside the "
                            "outcome columns %s (first: %s)" %
                            (f, kind, len(outside),
                             sorted(OUTCOME_COLS), outside[:3]))
                ok = False
            if treated == 0:
                msgs.append("FAIL gate3c %s/%s: zero closed rows treated "
                            "(rMultiple identical to CONTROL everywhere) - "
                            "tier indistinguishable at scale" % (f, kind))
                ok = False
            else:
                msgs.append("OK   gate3c %s/%s: %d closed rows treated" %
                            (f, kind, treated))

    # Mechanism sanity (warning only): TP-hit rate monotonically
    # non-increasing in tier 1.0 -> 1.5 -> 2.0 -> 2.5 -> 3.0.
    monotonicity = {}
    for f in FILES:
        arm_rates = []
        for kind in TIER_RUNS + ["CONTROL"]:
            ld = loads.get(f, {}).get(kind)
            rate = tp_hit_rate(closed_rows(ld["rows"])) if ld else None
            arm_rates.append((TIER_VALUES.get(kind, 2.0), rate))
        arm_rates.sort(key=lambda x: x[0])
        rates = [r for _, r in arm_rates]
        ordered = [t for t, _ in arm_rates]
        ok_rates = [r for r in rates if r is not None]
        if len(ok_rates) == 5:
            monotonic = all(ok_rates[i] >= ok_rates[i + 1]
                            for i in range(len(ok_rates) - 1))
            monotonicity[f] = {
                "rates": {("2.0" if t == 2.0 else ("%.1f" % t)): r
                          for t, r in arm_rates},
                "monotonicNonIncreasing": bool(monotonic),
            }
            if not monotonic:
                msgs.append("WARN tp-hit %s: rate NOT monotonically "
                            "decreasing in tier: %s" % (f, arm_rates))
        else:
            msgs.append("WARN tp-hit %s: incomplete arm set for monotonicity "
                        "check (%d/5 arms)" % (f, len(ok_rates)))
    return ok, msgs, pairing_key, pairing_proof, monotonicity


def analyze(art_dir, iters):
    """Paired analysis (protocol section 5) - only after the gate passes."""
    msgs = []
    gate_ok, gate_msgs, pairing_key, pairing_proof, monotonicity = \
        gate_fifteen_runs(art_dir)
    if not gate_ok:
        return {"gate": {"pass": False, "messages": gate_msgs},
                "note": "run set rejected; no statistics computed"}, False
    loads = {}
    for f in FILES:
        ctrl = load_run(art_dir, f, "CONTROL")
        arms = {kind: load_run(art_dir, f, kind) for kind in TIER_RUNS}
        loads[f] = (ctrl, arms)
    key_fn = (lambda r: r.get("decisionId", "")) if pairing_key == "decisionId" \
        else canonical_key
    per_file = {}
    for f in FILES:
        ctrl, arms = loads[f]
        cl_c = closed_rows(ctrl["rows"])
        comps = {}
        for kind in TIER_RUNS:
            arm = arms.get(kind)
            if arm is None:
                comps[kind] = {"error": "missing arm"}
                continue
            cl_a = closed_rows(arm["rows"])
            pairs, (ua, ub, ncommon) = day_pairs(cl_c, cl_a, key_fn)
            days_union = set(day_of(r) for r in cl_c) | \
                set(day_of(r) for r in cl_a)
            ci, daily_ci, ndays, obs_d = paired_bootstrap_delta_ci(
                pairs, days_union, iters)
            vals_c = [num(r, "rMultiple") for r in cl_c]
            vals_a = [num(r, "rMultiple") for r in cl_a]
            mean_c = sum(vals_c) / len(vals_c) if vals_c else None
            mean_a = sum(vals_a) / len(vals_a) if vals_a else None
            delta = (mean_a - mean_c) if (mean_c is not None and mean_a is not None) \
                else None
            wr_c = sum(1 for r in cl_c if r.get("outcome") == "1") / len(cl_c) \
                if cl_c else None
            wr_a = sum(1 for r in cl_a if r.get("outcome") == "1") / len(cl_a) \
                if cl_a else None
            # outcome transition matrix 2R -> tier (WIN=1, LOSS=2, BREAKEVEN=3)
            trans = {}
            for k in set(key_fn(r) for r in cl_c) & set(key_fn(r) for r in cl_a):
                key = (cl_c and next((r for r in cl_c if key_fn(r) == k), None))
                key2 = next((r for r in cl_a if key_fn(r) == k), None)
                if key is None or key2 is None:
                    continue
                t = (key.get("outcome", "?"), key2.get("outcome", "?"))
                trans[t] = trans.get(t, 0) + 1
            comps[kind] = {
                "tier": TIER_VALUES[kind],
                "nClosed": {"twoR": len(cl_c), "tier": len(cl_a)},
                "nPaired": ncommon,
                "unmatched": {"twoR": ua, "tier": ub},
                "meanR": {"twoR": round(mean_c, 4) if mean_c is not None else None,
                          "tier": round(mean_a, 4) if mean_a is not None else None},
                "delta": round(delta, 4) if delta is not None else None,
                "ci": ci, "dailyCi": daily_ci, "observedDailyDelta": obs_d,
                "pairedDays": ndays,
                "winRate": {"twoR": round(wr_c, 4) if wr_c is not None else None,
                            "tier": round(wr_a, 4) if wr_a is not None else None},
                "tpHitRate": {"twoR": tp_hit_rate(cl_c),
                              "tier": tp_hit_rate(cl_a)},
                "transition2RtoTier": trans,
                "nOpen": {
                    "twoR": sum(1 for r in qualified_rows(ctrl["rows"])
                                if r.get("outcome") == "0"),
                    "tier": sum(1 for r in qualified_rows(arm["rows"])
                                if r.get("outcome") == "0")},
            }
        per_file[f] = comps
    return ({"gate": {"pass": True, "messages": gate_msgs,
                      "pairingKey": pairing_key, "pairingProof": pairing_proof},
             "perFile": per_file, "thresholds": {"minEffect": MIN_EFFECT,
                                                 "minN": MIN_N,
                                                 "iters": iters, "seed": SEED},
             "note": "delta = MeanR(tier) - MeanR(2.0R); verdict and "
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
            msgs.append("FAIL %s: machinery probe CI excludes 0 on CONTROL vs "
                        "CONTROL (bootstrap corruption)" % f)
    out = {
        "mode": "selfcheck",
        "seed": SEED,
        "audit": {"pass": ok, "messages": msgs},
        "pairingAudit": {"pass": p_ok, "messages": p_msgs},
        "machineryProbe": probe,
        "expectedManifest": expected_manifest(),
        "gateReadiness": "15-run artifacts + tier manifest required before "
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
        print("== ED01-E self-check (seed %d) ==" % SEED)
        print("audit:")
        for m in out["audit"]["messages"]:
            print("  %s" % m)
        if ok:
            print("  audit PASS (fingerprints + totals + qualified + closed + "
                  "per-family + days + window)")
        print("pairing audit:")
        for m in out["pairingAudit"]["messages"]:
            print("  %s" % m)
        if p_ok := out["pairingAudit"]["pass"]:
            print("  pairing PASS (canonical keys unique; decisionId unique "
                  "per segment)")
        print("estimator machinery probe (CONTROL vs CONTROL, delta=0 expected):")
        for f in FILES:
            pr = out["machineryProbe"].get(f, {})
            if "ci" in pr:
                print("  %-10s nClosed=%d nPaired=%d CI=[%.4f, %.4f] "
                      "dailyCI=[%.4f, %.4f] includes0=%s" %
                      (f, pr["nClosed"], pr["nPaired"], pr["ci"]["lo"],
                       pr["ci"]["hi"], pr["dailyCi"]["lo"],
                       pr["dailyCi"]["hi"], pr["ciIncludesZero"]))
            else:
                print("  %-10s %s" % (f, pr.get("error", "n/a")))
        print("expected 15-run tier manifest (%d runs, all PENDING):" %
              len(out["expectedManifest"]["runs"]))
        for r in out["expectedManifest"]["runs"]:
            print("  %-10s %-8s tier=%-4s %s" %
                  (r["file"], r["kind"], r["tier"], r["artifactDir"]))
        print("wrote %s" % json_path)
        if not ok:
            print("SELF-CHECK FAILED - frozen constants/fingerprints/keys not "
                  "reproduced.")
            return 1
        print("SELF-CHECK PASS - analyzer is deterministic and CONTROL "
              "population reproduces the frozen audit constants.")
        return 0

    if args.mode == "gate":
        ok, msgs, pairing_key, pairing_proof, monotonicity = \
            gate_fifteen_runs(args.artifacts)
        print("== ED01-E pre-analysis gate (protocol 11) ==")
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
        print("GATE PASS - all integrity/identity/distinguishability gates "
              "passed; pairing key: %s" % pairing_key)
        return 0

    out, gate_ok = analyze(args.artifacts, args.iters)
    json_path = args.json or ANALYSIS_JSON
    with open(json_path, "w") as fh:
        json.dump(out, fh, indent=1)
    print("== ED01-E analysis (paired, seed %d) ==" % SEED)
    if not gate_ok:
        for m in out["gate"]["messages"]:
            print("  %s" % m)
        print("GATE FAILED - no statistics computed; run set rejected.")
        return 1
    for f in FILES:
        for kind in TIER_RUNS:
            pf = out["perFile"][f].get(kind, {})
            if "error" in pf:
                print("  %-10s %-6s %s" % (f, kind, pf["error"]))
                continue
            ci = pf["ci"]
            cistr = ("CI=[%.4f, %.4f]" % (ci["lo"], ci["hi"])) if ci else "CI=n/a"
            print("  %-10s %-6s delta=%s %s pairedDays=%d paired=%d "
                  "tpHit(2R/tier)=%s/%s" %
                  (f, kind, ("%+.4f" % pf["delta"]) if pf["delta"] is not None
                   else "n/a", cistr, pf["pairedDays"], pf["nPaired"],
                   ("%.4f" % pf["tpHitRate"]["twoR"]) if pf["tpHitRate"]["twoR"]
                   is not None else "n/a",
                   ("%.4f" % pf["tpHitRate"]["tier"]) if pf["tpHitRate"]["tier"]
                   is not None else "n/a"))
    print("pairing key: %s" % out["gate"]["pairingKey"])
    print("wrote %s" % json_path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
