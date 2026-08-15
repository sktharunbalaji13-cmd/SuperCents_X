#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ED01 RL-HYP-01 analyzer: swing-significance admission gate vs the 2.0R
B8 CONTROL (opportunity-level paired estimator, Amendment A1 + A2).

Frozen protocol: docs/Sprint22_RL_HYP_01_Protocol.md (FROZEN 2026-08-11;
Amendment A1 opportunity-level estimand; Amendment A2 pairing key =
canonical {signalTime, configFingerprint, symbol, timeframe} ACCEPTED and
frozen 2026-08-11, section 16.2).
Predecessor pattern: Tools/ED01/ED01_E_Analyze.py (loader/audit/bootstrap).

Modes:
  --selfcheck : audit the frozen CONTROL artifacts (frozen constants,
                fingerprints, canonical-key uniqueness) + estimator
                machinery probe (CONTROL vs CONTROL self-pairing under the
                opportunity-level estimator, delta == 0, CI includes 0) +
                expected 12-run manifest. No statistic on the tiers and no
                verdict is emitted (tier artifacts do not exist yet).
                FAILS LOUDLY on any violation. Writes
                results_RLHYP01_selfcheck.json.
  --gate      : pre-analysis gate (protocol section 11, gates 1/2/3a/3b/3c/5
                under Amendment A2) against the 12-run artifacts + manifest.
                FAILS LOUDLY when any run artifact, .done marker, or
                manifest entry is missing or violates a hard gate. The
                pairing key is FIXED by Amendment A2 to the canonical
                {signalTime, configFingerprint, symbol, timeframe}; gate 3a
                additionally certifies decisionId invariance on the UNGATED
                integrity rerun (the A2 integrity certificate).
  --analyze   : paired opportunity-level analysis (protocol section 6)
                after the gate passes. Three pre-registered comparisons per
                file (K=1.0/1.5/2.0 vs ungated CONTROL); Treatment_R =
                actual rMultiple if ADMITTED else 0R if GATED-OUT;
                d = Treatment_R - Control_R; verifies the Amendment A1
                identity Delta = -(nGatedOut/nTotal) x MeanR(gated-out) and
                d == 0 on every admitted row. Reports primary + secondary
                estimands, composition controls (section 9), Bonferroni
                98.33% sensitivity CIs, and section 8 decision inputs (no
                verdict emitted - the decision report does that). Writes
                results_RLHYP01.json.

Determinism: random.seed(20260811) fixed once per run (protocol section 11
gate 4); reruns reproduce identical CIs and JSON byte-for-byte.
"""
import argparse
import csv
import glob
import json
import os
import random
import re
import sys

PROJECT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DEFAULT_ARTS = os.path.join(PROJECT, "Tools", "ED01", "artifacts")
SELFCHECK_JSON = os.path.join(os.path.dirname(DEFAULT_ARTS), "results_RLHYP01_selfcheck.json")
ANALYSIS_JSON = os.path.join(os.path.dirname(DEFAULT_ARTS), "results_RLHYP01.json")
MANIFEST_JSON = os.path.join(os.path.dirname(DEFAULT_ARTS), "ED01_RLHYP01_manifest.json")

# Frozen GR01 RULE_FAMILY map (same as ED01-C/D/E).
RULE_FAMILY = {
    "LIQUIDITY_BOS_BULLISH": "LIQUIDITY",
    "LIQUIDITY_BOS_BEARISH": "LIQUIDITY",
    "OB_FVG_BULLISH": "FVG",
    "OB_FVG_BEARISH": "FVG",
    "BOS_OB_BULLISH": "BOS",
    "BOS_OB_BEARISH": "BOS",
    "CHOCH_OB_REVERSAL": "CHOCH",
}

# Frozen per-file default-config fingerprints (protocol section 4).
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
    "INTEGRITY": "CONTROL_RLHYP01_INTEGRITY",
    "K1P0": "CONTROL_RLHYP01_K1P0",
    "K1P5": "CONTROL_RLHYP01_K1P5",
    "K2P0": "CONTROL_RLHYP01_K2P0",
}
TIER_RUNS = ["K1P0", "K1P5", "K2P0"]
TIER_VALUES = {"K1P0": 1.0, "K1P5": 1.5, "K2P0": 2.0}

# Frozen audit constants (protocol section 4, measured 2026-08-09).
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
BASELINE_MEANR = {"EURUSD_H1": -0.0239, "GBPJPY_H1": -0.0599, "EURUSD_M15": -0.0126}

WINDOW_START = "2026.04.05"
WINDOW_END = "2026.07.05"

SEED = 20260811
MIN_PAIRED_DAYS = 10
MIN_N = 50
MIN_EFFECT = 0.10
DEFAULT_ITERS = 10000
# Bonferroni sensitivity: alpha = 0.05/3 -> 98.33% CI (protocol section 7).
SENS_TAIL = (0.05 / 3.0) / 2.0

# v5 gate telemetry defaults (gate OFF rows; measured from the TT01 v5
# default replay). Gate ON rows carry gateDecision=ADMIT, a qualifying
# swing id and a positive amplitude.
GATE_DEFAULTS = {"gateDecision": "OFF", "swingQualifyingId": "0",
                 "swingAmplitude": "0.00000000"}
GATE_COLS = ["gateDecision", "swingQualifyingId", "swingAmplitude"]

# Expected 12-run set (protocol section 14): 3 integrity + 9 treatment.
TWELVE_RUNS = [
    ("EURUSD_H1", "INTEGRITY"), ("GBPJPY_H1", "INTEGRITY"), ("EURUSD_M15", "INTEGRITY"),
    ("EURUSD_H1", "K1P0"), ("EURUSD_H1", "K1P5"), ("EURUSD_H1", "K2P0"),
    ("GBPJPY_H1", "K1P0"), ("GBPJPY_H1", "K1P5"), ("GBPJPY_H1", "K2P0"),
    ("EURUSD_M15", "K1P0"), ("EURUSD_M15", "K1P5"), ("EURUSD_M15", "K2P0"),
]

# Amendment A2 (protocol section 16.2): pairing key is FIXED to the
# canonical opportunity identity. decisionId stays the row-for-row
# certificate of the UNGATED integrity rerun (gate 3a) only.
PAIRING_KEY = "canonical"


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
    """Canonical stable decision identity (Amendment A2, protocol section
    16.2; ED01-D/E protocol 14): {signalTime, configFingerprint, symbol,
    timeframe}."""
    return (row.get("signalTime", ""), row.get("configFingerprint", ""),
            row.get("symbol", ""), row.get("timeframe", ""))


def seg_date(name):
    """Date-suffix of a telemetry segment file, agnostic of the v4/v5
    filename prefix (CONTROL segments are telemetry_v4_*, the new arms
    telemetry_v5_* - a frozen design difference, protocol section 14)."""
    return name.rsplit("_", 1)[-1]


IDENTITY_FLIP_COLS = ("decisionId", "schemaVersion")

# B25-01 provenance identity columns (schema v6; append-only over v5).
# Constant per run, carry NO behavioral meaning - exempted from every
# shared-column byte-compare and validated explicitly instead (constancy,
# formats, cross-arm binary population) by gate_identity_provenance.
IDENTITY_COLS = ("runId", "buildTag", "gitHead")


def load_run(art_dir, file_key, run_kind):
    """Load one run dir. CONTROL artifacts are frozen v4; the new arms are
    v5 (v4's 75 columns + the 3 gate-telemetry columns). Returns
    (rows, fingerprints, segments) or None."""
    d = os.path.join(art_dir, file_key, RUN_DIRS[run_kind])
    if not os.path.isdir(d):
        return None
    done = os.path.isfile(os.path.join(d, ".done"))
    pat = "telemetry_v4_*.csv" if run_kind == "CONTROL" else "telemetry_v5_*.csv"
    rows = []
    segments = {}
    for path in sorted(glob.glob(os.path.join(d, pat))):
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
    """Eligible decision population (protocol section 4): newDecision == 1,
    outcome in (1,2,3); censored (outcome 0) excluded and reported as
    nOpen."""
    return [r for r in rows if r.get("newDecision") == "1"
            and r.get("outcome") in ("1", "2", "3")]


def window_audit(rows, msgs, f, hard=True):
    bad = [r for r in rows if not (WINDOW_START <= day_of(r) <= WINDOW_END)]
    if bad:
        msgs.append(("FAIL " if hard else "WARN ") + "%s: %d rows outside "
                    "frozen window [%s, %s] (e.g. %s)" %
                    (f, len(bad), WINDOW_START, WINDOW_END, day_of(bad[0])))
        return hard
    return True


def audit_control(loads):
    """Protocol 11 gate 5 + section 4 frozen constants on CONTROL runs."""
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


def canonical_uniqueness_audit(loads):
    """Amendment A2 hard audit 1: canonical-key uniqueness within each arm
    and across the merged run set, per file (protocol 16.2)."""
    msgs = []
    ok = True
    for f in FILES:
        for kind in ["CONTROL"] + ["INTEGRITY"] + TIER_RUNS:
            ld = loads.get(f, {}).get(kind)
            if ld is None:
                continue
            rows = ld["rows"]
            keys = [canonical_key(r) for r in rows]
            if len(keys) != len(set(keys)):
                msgs.append("FAIL %s/%s: duplicate canonical keys across merged "
                            "run (dups=%d)" % (f, kind, len(keys) - len(set(keys))))
                ok = False
            for name, seg in sorted(ld["segments"].items()):
                ids = [r.get("decisionId", "") for r in seg]
                if len(ids) != len(set(ids)):
                    msgs.append("FAIL %s/%s: duplicate decisionId in segment %s "
                                "(dups=%d)" % (f, kind, name, len(ids) - len(set(ids))))
                    ok = False
                skeys = [canonical_key(r) for r in seg]
                if len(skeys) != len(set(skeys)):
                    msgs.append("FAIL %s/%s: duplicate canonical keys in segment "
                                "%s (dups=%d)" % (f, kind, name,
                                                  len(skeys) - len(set(skeys))))
                    ok = False
    return ok, msgs


def opportunity_pairs(ctrl_closed, arm_rows, key_fn):
    """Amendment A1/A2 pairing: for every CONTROL closed row, Treatment_R =
    actual rMultiple if the canonical key is present in the treatment arm
    (ADMITTED), else 0R (GATED-OUT). Returns (rows_by_day, nGatedOut,
    nAdmitted, gated_out_rows)."""
    arm_keys = {key_fn(r): r for r in arm_rows}
    rows_by_day = {}
    n_admitted = 0
    gated = []
    for r in ctrl_closed:
        key = key_fn(r)
        c_r = num(r, "rMultiple")
        if key in arm_keys:
            t_r = num(arm_keys[key], "rMultiple")
            n_admitted += 1
        else:
            t_r = 0.0
            gated.append(r)
        d = t_r - c_r
        rows_by_day.setdefault(day_of(r), []).append(
            {"d": d, "t": t_r, "c": c_r, "admitted": key in arm_keys})
    return rows_by_day, len(gated), n_admitted, gated


def day_stratified_bootstrap(rows_by_day, days_union, iters, tail=0.025):
    """Protocol section 6 paired day-stratified bootstrap (seed set once).

    Resample days with replacement from the union of days holding any
    eligible CONTROL row; each sampled day contributes all its paired
    (Treatment_R - Control_R) differences; the pooled mean over sampled
    rows is one draw. Auxiliary estimator: mean of per-day means.
    Returns (pooled_ci, daily_ci, n_paired_days, observed_daily).
    """
    days = sorted(set(days_union))
    paired_days = [d for d in days if rows_by_day.get(d)]
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
            vals = rows_by_day.get(d, [])
            s += sum(v["d"] for v in vals)
            m += len(vals)
            if vals:
                t += sum(v["d"] for v in vals) / len(vals)
                c += 1
        pooled.append(s / max(m, 1))
        daily.append(t / max(c, 1))
    pooled.sort()
    daily.sort()
    k = int(iters * tail)
    obs_d = (sum(sum(v["d"] for v in rows_by_day[d]) / len(rows_by_day[d])
                 for d in paired_days) / len(paired_days))
    return ({"lo": pooled[k], "hi": pooled[iters - k - 1]},
            {"lo": daily[k], "hi": daily[iters - k - 1]},
            len(paired_days), obs_d)


def machinery_probe(loads, iters):
    """Opportunity-level machinery probe: CONTROL vs CONTROL self-pairing
    under the A1 estimator (zero gated-out by construction) must yield
    delta == 0 exactly and a CI including 0 for every file."""
    out = {}
    for f in FILES:
        ld = loads.get(f)
        if not ld:
            out[f] = {"error": "no CONTROL run"}
            continue
        cl = closed_rows(ld["rows"])
        rows_by_day, n_gated, n_adm, _ = opportunity_pairs(cl, cl, canonical_key)
        ci, daily_ci, ndays, obs_d = day_stratified_bootstrap(
            rows_by_day, [day_of(r) for r in cl], iters)
        delta = sum(v["d"] for vs in rows_by_day.values() for v in vs) / len(cl)
        if ci is None:
            out[f] = {"nClosed": len(cl), "nGatedOut": n_gated,
                      "pairedDays": ndays, "error": "paired days < %d" % MIN_PAIRED_DAYS}
            continue
        out[f] = {"nClosed": len(cl), "nGatedOut": n_gated,
                  "nAdmitted": n_adm, "pairedDays": ndays,
                  "delta": round(delta, 10), "ci": ci, "dailyCi": daily_ci,
                  "observedDailyDelta": round(obs_d, 6),
                  "ciIncludesZero": ci["lo"] <= 0.0 <= ci["hi"]}
    return out


def expected_manifest():
    """Expected 12-run manifest spec (protocol section 14 + A2)."""
    runs = []
    for f, kind in TWELVE_RUNS:
        runs.append({
            "file": f, "kind": kind, "tier": TIER_VALUES.get(kind, 0.0),
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
            "manifestFile": "Tools/ED01/ED01_RLHYP01_manifest.json",
            "profile": "Control profile + SwingSignificanceTier input only "
                       "(EA input double SwingSignificanceTier, default 0.0 "
                       "= OFF/ungated; 0.0 for INTEGRITY, 1.0/1.5/2.0 for "
                       "K1P0/K1P5/K2P0)",
            "window": [WINDOW_START, WINDOW_END],
            "pairingKey": "canonical {signalTime, configFingerprint, "
                          "symbol, timeframe} (Amendment A2, protocol "
                          "16.2; decisionId NOT a cross-arm pairing key "
                          "when admission gating changes the recorded "
                          "population; decisionId stays the ungated "
                          "integrity-rerun certificate, gate 3a)"}


def gate_3a_integrity(loads):
    """Gate 3a: the UNGATED integrity rerun is row-for-row byte-identical
    to CONTROL on decisionId + all shared columns; the gate columns must
    sit at their OFF defaults. This certifies decisionId invariance for the
    ungated rerun (Amendment A2 integrity certificate). B25-01 identity
    columns are exempted (provenance; validated by gate_identity_provenance).
    Returns (ok, msgs, proof)."""
    msgs = []
    ok = True
    proof = []
    for f in FILES:
        ctrl = loads.get(f, {}).get("CONTROL")
        integ = loads.get(f, {}).get("INTEGRITY")
        if ctrl is None or integ is None:
            msgs.append("FAIL gate3a %s: CONTROL or INTEGRITY arm missing" % f)
            ok = False
            continue
        c_seg, i_seg = ctrl["segments"], integ["segments"]
        c_dates = {seg_date(n): n for n in c_seg}
        i_dates = {seg_date(n): n for n in i_seg}
        if sorted(c_dates) != sorted(i_dates):
            msgs.append("FAIL gate3a %s: segment date sets differ: %s vs %s" %
                        (f, sorted(c_dates), sorted(i_dates)))
            ok = False
            continue
        seg_ok = True
        for date in sorted(c_dates):
            crows = sorted(c_seg[c_dates[date]],
                           key=lambda r: r.get("decisionId", ""))
            irows = sorted(i_seg[i_dates[date]],
                           key=lambda r: r.get("decisionId", ""))
            if len(crows) != len(irows):
                msgs.append("FAIL gate3a %s %s: row count %d != CONTROL %d" %
                            (f, date, len(irows), len(crows)))
                ok = False
                seg_ok = False
                continue
            if not crows:
                continue
            ccols = sorted(crows[0].keys())
            bad = False
            for a, b in zip(crows, irows):
                exempt = [c for c in (list(GATE_COLS) + list(IDENTITY_COLS))
                          if c not in a and c in b]
                if sorted(b.keys()) != sorted(sorted(a.keys()) + exempt):
                    msgs.append("FAIL gate3a %s %s: column set differs "
                                "(decisionId=%s)" % (f, date, a.get("decisionId", "")))
                    ok = False
                    bad = True
                    break
                if a.get("decisionId") != b.get("decisionId"):
                    msgs.append("FAIL gate3a %s %s: decisionId differs at "
                                "position %s" % (f, date, a.get("decisionId", "")))
                    ok = False
                    bad = True
                    break
                if any(a[c] != b[c] for c in ccols
                       if c not in IDENTITY_FLIP_COLS and c not in IDENTITY_COLS):
                    msgs.append("FAIL gate3a %s %s: row-for-row divergence on "
                                "shared columns (decisionId=%s)" %
                                (f, date, a.get("decisionId", "")))
                    ok = False
                    bad = True
                    break
                for c in GATE_COLS:
                    if b.get(c) != GATE_DEFAULTS.get(c):
                        msgs.append("FAIL gate3a %s %s: gate column %s = %r, "
                                    "expected OFF default %r (decisionId=%s)" %
                                    (f, date, c, b.get(c), GATE_DEFAULTS.get(c),
                                     a.get("decisionId", "")))
                        ok = False
                        bad = True
                        break
                if bad:
                    break
            if not seg_ok or bad:
                seg_ok = False
        if seg_ok:
            proof.append("%s: decisionId invariant (integrity rerun "
                         "reproduces CONTROL row-for-row on decisionId + "
                         "all shared columns except the frozen schemaVersion "
                         "4->5 flip; gate columns at OFF defaults)" % f)
        else:
            proof.append("%s: integrity rerun DIVERGES from CONTROL" % f)
    return ok, msgs, proof


def gate_3b_admission_only(loads):
    """Gate 3b: for every tier run, admitted rows are byte-identical to
    CONTROL in ALL shared columns (the gate must not perturb any admitted
    decision; gate columns carry ADMIT telemetry); treatment canonical keys
    are a subset of CONTROL keys; all treatment rows are ADMIT. Returns
    (ok, msgs)."""
    msgs = []
    ok = True
    for f in FILES:
        ctrl = loads.get(f, {}).get("CONTROL")
        if ctrl is None:
            msgs.append("FAIL gate3b %s: CONTROL arm missing" % f)
            ok = False
            continue
        c_all = {canonical_key(r): r for r in ctrl["rows"]}
        for kind in TIER_RUNS:
            arm = loads.get(f, {}).get(kind)
            if arm is None:
                msgs.append("FAIL gate3b %s/%s: treatment arm missing" % (f, kind))
                ok = False
                continue
            outside = []
            foreign = []
            n_admit = 0
            for r in arm["rows"]:
                if r.get("gateDecision") != "ADMIT":
                    msgs.append("FAIL gate3b %s/%s: row with gateDecision=%r "
                                "(expected ADMIT on every treatment row)" %
                                (f, kind, r.get("gateDecision")))
                    ok = False
                if num(r, "swingAmplitude") <= 0.0:
                    msgs.append("FAIL gate3b %s/%s: row with non-positive "
                                "swingAmplitude %r" %
                                (f, kind, r.get("swingAmplitude")))
                    ok = False
                if r.get("swingQualifyingId") in (None, "", "0"):
                    msgs.append("FAIL gate3b %s/%s: row with unset "
                                "swingQualifyingId" % (f, kind))
                    ok = False
                key = canonical_key(r)
                if key not in c_all:
                    foreign.append(key)
                    continue
                n_admit += 1
                a = c_all[key]
                for c in sorted(a.keys()):
                    if c in IDENTITY_FLIP_COLS or c in IDENTITY_COLS:
                        continue
                    if a[c] != r[c]:
                        outside.append((c, key))
                        break
            if foreign:
                msgs.append("FAIL gate3b %s/%s: %d treatment row(s) with "
                            "canonical keys absent from CONTROL (foreign "
                            "identities)" % (f, kind, len(foreign)))
                ok = False
            if outside:
                msgs.append("FAIL gate3b %s/%s: %d admitted row(s) differ "
                            "from CONTROL outside decisionId (first: %s)" %
                            (f, kind, len(outside), outside[:3]))
                ok = False
            if n_admit == 0:
                msgs.append("FAIL gate3b %s/%s: zero admitted rows" % (f, kind))
                ok = False
    return ok, msgs


def gate_3c_distinguishability(loads):
    """Gate 3c: each tier has at least one gated-out row on the primary
    file (nGatedOut >= 1 on EURUSD_H1)."""
    msgs = []
    ok = True
    for kind in TIER_RUNS:
        ctrl = loads.get(PRIMARY_FILE, {}).get("CONTROL")
        arm = loads.get(PRIMARY_FILE, {}).get(kind)
        if ctrl is None or arm is None:
            msgs.append("FAIL gate3c %s: CONTROL or %s arm missing" %
                        (PRIMARY_FILE, kind))
            ok = False
            continue
        c_keys = {canonical_key(r) for r in closed_rows(ctrl["rows"])}
        a_keys = {canonical_key(r) for r in closed_rows(arm["rows"])}
        n_gated = len(c_keys - a_keys)
        if n_gated < 1:
            msgs.append("FAIL gate3c %s/%s: nGatedOut=%d (need >= 1)" %
                        (PRIMARY_FILE, kind, n_gated))
            ok = False
        else:
            msgs.append("OK   gate3c %s/%s: nGatedOut=%d" %
                        (PRIMARY_FILE, kind, n_gated))
    return ok, msgs


def gate_row_counts(loads):
    """Gates 1 + 2: fingerprints + row-count integrity on every arm;
    treatment arms report admitted counts with nGatedOut = CONTROL - arm."""
    msgs = []
    ok = True
    for f in FILES:
        ctrl = loads.get(f, {}).get("CONTROL")
        if ctrl is None:
            msgs.append("FAIL gate2 %s: CONTROL arm missing" % f)
            ok = False
            continue
        n_c_total = len(ctrl["rows"])
        n_c_closed = len(closed_rows(ctrl["rows"]))
        for kind in ["INTEGRITY"] + TIER_RUNS:
            ld = loads.get(f, {}).get(kind)
            if ld is None:
                msgs.append("FAIL gate2 %s/%s: arm missing" % (f, kind))
                ok = False
                continue
            rows = ld["rows"]
            if ld["fps"] != [FINGERPRINTS[f]]:
                msgs.append("FAIL gate1 %s/%s: fingerprints %s != frozen %s" %
                            (f, kind, ld["fps"], FINGERPRINTS[f]))
                ok = False
            n_closed = len(closed_rows(rows))
            if kind == "INTEGRITY":
                if len(rows) != n_c_total or n_closed != n_c_closed:
                    msgs.append("FAIL gate2 %s/INTEGRITY: rows %d/%d != CONTROL "
                                "%d/%d (integrity rerun must be ungated)" %
                                (f, len(rows), n_closed, n_c_total, n_c_closed))
                    ok = False
            else:
                n_gated = n_c_closed - n_closed
                if n_gated < 0:
                    msgs.append("FAIL gate2 %s/%s: treatment closed %d > "
                                "CONTROL closed %d" % (f, kind, n_closed, n_c_closed))
                    ok = False
                msgs.append("OK   gate2 %s/%s: total=%d qualified=%d closed=%d "
                            "nGatedOut=%d" %
                            (f, kind, len(rows),
                             len(qualified_rows(rows)), n_closed, n_gated))
    return ok, msgs


def gate_identity_provenance(loads):
    """B25-01 additive provenance gate: every arm whose rows carry identity
    columns must record a constant, well-formed runId/buildTag/gitHead; the
    binary population (buildTag + gitHead) must be identical across ALL arms
    of a file (same compile, same commit); runId must differ per arm (runs
    distinguishable). Arms without identity columns (historical v5 artifacts)
    are skipped - backward compatibility. Returns (ok, msgs)."""
    msgs = []
    ok = True
    run_id_re = re.compile(r"^RUN-\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2}-\d+$")
    tag_re = re.compile(r"^\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2}$")
    head_re = re.compile(r"^[0-9a-f]{40}$")
    for f in FILES:
        arms = loads.get(f, {})
        present = {}
        for kind, arm in arms.items():
            if arm is None or not arm["rows"]:
                continue
            if IDENTITY_COLS[0] in arm["rows"][0]:
                present[kind] = arm
        if not present:
            msgs.append("OK   identity %s: no identity columns (historical "
                        "v5 artifacts) - skipped" % f)
            continue
        for kind, arm in sorted(present.items()):
            rows = arm["rows"]
            run_ids = {r.get("runId") for r in rows}
            tags = {r.get("buildTag") for r in rows}
            heads = {r.get("gitHead") for r in rows}
            if len(run_ids) != 1:
                msgs.append("FAIL identity %s/%s: runId not constant "
                            "(%d distinct)" % (f, kind, len(run_ids)))
                ok = False
            if len(tags) != 1:
                msgs.append("FAIL identity %s/%s: buildTag not constant "
                            "(%d distinct)" % (f, kind, len(tags)))
                ok = False
            if len(heads) != 1:
                msgs.append("FAIL identity %s/%s: gitHead not constant "
                            "(%d distinct)" % (f, kind, len(heads)))
                ok = False
            rid = next(iter(run_ids))
            if not run_id_re.match(rid):
                msgs.append("FAIL identity %s/%s: malformed runId %r" %
                            (f, kind, rid))
                ok = False
            tag = next(iter(tags))
            if not tag_re.match(tag):
                msgs.append("FAIL identity %s/%s: malformed buildTag %r" %
                            (f, kind, tag))
                ok = False
            head = next(iter(heads))
            if head != "unknown" and not head_re.match(head):
                msgs.append("FAIL identity %s/%s: malformed gitHead %r" %
                            (f, kind, head))
                ok = False
        all_tags = {next(iter({r.get("buildTag") for r in a["rows"]}))
                    for a in present.values()}
        all_heads = {next(iter({r.get("gitHead") for r in a["rows"]}))
                     for a in present.values()}
        if len(all_tags) != 1:
            msgs.append("FAIL identity %s: buildTag differs across arms (%s)"
                        % (f, sorted(all_tags)))
            ok = False
        if len(all_heads) != 1:
            msgs.append("FAIL identity %s: gitHead differs across arms (%s)"
                        % (f, sorted(all_heads)))
            ok = False
        if len(present) > 1:
            all_run_ids = {next(iter({r.get("runId") for r in a["rows"]}))
                           for a in present.values()}
            if len(all_run_ids) != len(present):
                msgs.append("FAIL identity %s: %d arms share a runId (runs "
                            "not distinguishable)" % (f, len(present)))
                ok = False
        msgs.append("OK   identity %s: %d arm(s) constant/well-formed, "
                    "binary population identical" % (f, len(present)))
    return ok, msgs


def gate_twelve_runs(art_dir, manifest_path):
    """Pre-analysis gate (protocol 11 gates 1/2/3a/3b/3c/5 + manifest) under
    Amendment A2. Returns (ok, msgs, pairing_key, pairing_proof)."""
    msgs = []
    ok = True
    manifest = None
    if os.path.isfile(manifest_path):
        try:
            with open(manifest_path, encoding="utf-8-sig") as fh:
                manifest = json.load(fh)
        except (ValueError, OSError) as e:
            msgs.append("FAIL manifest: unreadable %s (%s)" % (manifest_path, e))
            ok = False
    else:
        msgs.append("FAIL: tier manifest missing: %s" % manifest_path)
        ok = False

    loads = {}
    for f, kind in TWELVE_RUNS:
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
        for f, kind in TWELVE_RUNS:
            present = False
            for entry in (manifest.get("runs") or []):
                if (entry.get("file") == f and entry.get("kind") == kind):
                    present = True
                    tier = entry.get("tier")
                    if tier is None:
                        msgs.append("FAIL manifest %s/%s: missing tier field" %
                                    (f, kind))
                        ok = False
                    elif float(tier) != TIER_VALUES.get(kind, 0.0):
                        msgs.append("FAIL manifest %s/%s: tier %s != frozen %s" %
                                    (f, kind, tier, TIER_VALUES.get(kind, 0.0)))
                        ok = False
                    if entry.get("status") != "DONE":
                        msgs.append("FAIL manifest %s/%s: status %s != DONE" %
                                    (f, kind, entry.get("status")))
                        ok = False
            if not present:
                msgs.append("FAIL manifest: missing entry %s/%s" % (f, kind))
                ok = False

    flat_ctrl = {}
    for f in FILES:
        sub = loads.get(f) or {}
        flat_ctrl[f] = sub.get("CONTROL")
    g_ok, g_msgs = audit_control(flat_ctrl)
    ok = ok and g_ok
    msgs.extend(g_msgs)
    u_ok, u_msgs = canonical_uniqueness_audit(loads)
    ok = ok and u_ok
    msgs.extend(u_msgs)
    r_ok, r_msgs = gate_row_counts(loads)
    ok = ok and r_ok
    msgs.extend(r_msgs)
    a_ok, a_msgs, proof = gate_3a_integrity(loads)
    ok = ok and a_ok
    msgs.extend(a_msgs)
    b_ok, b_msgs = gate_3b_admission_only(loads)
    ok = ok and b_ok
    msgs.extend(b_msgs)
    c_ok, c_msgs = gate_3c_distinguishability(loads)
    ok = ok and c_ok
    msgs.extend(c_msgs)
    i_ok, i_msgs = gate_identity_provenance(loads)
    ok = ok and i_ok
    msgs.extend(i_msgs)
    if not all("decisionId invariant" in p for p in proof):
        msgs.append("FAIL gate3a: ungated integrity rerun must certify "
                    "decisionId invariance (Amendment A2 integrity "
                    "certificate); analysis pairing key stays canonical.")
        ok = False
    return ok, msgs, PAIRING_KEY, proof


def composition_view(ctrl_closed, arm_rows, key_fn, keep_families=None,
                    exclude_family=None):
    """Opportunity-level delta on a family-restricted CONTROL population
    (protocol section 9)."""
    pop = [r for r in ctrl_closed
           if (keep_families is None or family_of(r) in keep_families)
           and (exclude_family is None or family_of(r) != exclude_family)]
    if not pop:
        return None
    rows_by_day, n_gated, n_adm, _ = opportunity_pairs(pop, arm_rows, key_fn)
    delta = sum(v["d"] for vs in rows_by_day.values() for v in vs) / len(pop)
    return {"n": len(pop), "nGatedOut": n_gated, "delta": round(delta, 6)}


def analyze(art_dir, iters, manifest_path=MANIFEST_JSON):
    """Paired opportunity-level analysis (protocol section 6) - only after
    the gate passes. Computes statistics + section 8 decision inputs; the
    verdict itself is emitted by the decision report (section 15.3 step 9).
    """
    msgs = []
    gate_ok, gate_msgs, pairing_key, proof = gate_twelve_runs(art_dir, manifest_path)
    if not gate_ok:
        return {"gate": {"pass": False, "messages": gate_msgs},
                "note": "run set rejected; no statistics computed"}, False
    loads = {}
    for f in FILES:
        ctrl = load_run(art_dir, f, "CONTROL")
        arms = {kind: load_run(art_dir, f, kind) for kind in TIER_RUNS}
        loads[f] = (ctrl, arms)
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
            a_keys = {canonical_key(r): r for r in cl_a}
            rows_by_day, n_gated, n_adm, gated_rows = opportunity_pairs(
                cl_c, cl_a, canonical_key)
            n_total = len(cl_c)
            days_union = [day_of(r) for r in cl_c]
            ci, daily_ci, ndays, obs_d = day_stratified_bootstrap(
                rows_by_day, days_union, iters)
            sens_ci, sens_daily, _, _ = day_stratified_bootstrap(
                rows_by_day, days_union, iters, tail=SENS_TAIL)
            delta = sum(v["d"] for vs in rows_by_day.values() for v in vs) / n_total
            gated_mean = (sum(num(r, "rMultiple") for r in gated_rows) /
                          len(gated_rows)) if gated_rows else None
            a1_pred = -(n_gated / n_total) * gated_mean if gated_mean is not None else None
            # Identity check 1 (Amendment A1): delta == -(share)*MeanR(gated-out)
            identity_a1 = (abs(delta - a1_pred) < 1e-12) if a1_pred is not None else False
            # Identity check 2 (section 6): every admitted row contributes d == 0
            bad_admitted = [v for vs in rows_by_day.values() for v in vs
                            if v["admitted"] and abs(v["d"]) > 1e-12]
            admission_rate = n_adm / n_total
            gated_out_rate = n_gated / n_total
            share_flags = []
            if admission_rate < 0.10:
                share_flags.append("SAMPLE-CONSTRAINED secondary "
                                   "(admission rate %.1f%% < 10%%)" % (100 * admission_rate))
            if gated_out_rate < 0.10:
                share_flags.append("SAMPLE-CONSTRAINED primary "
                                   "(gated-out rate %.1f%% < 10%%; |delta| "
                                   "structurally unreachable, section 9.3)" %
                                   (100 * gated_out_rate))
            wr_c = sum(1 for r in cl_c if r.get("outcome") == "1") / len(cl_c)
            wr_a = sum(1 for r in cl_a if r.get("outcome") == "1") / len(cl_a) \
                if cl_a else None
            comp = {}
            comp["UNKNOWN-removed"] = composition_view(
                cl_c, cl_a, canonical_key, exclude_family="UNKNOWN")
            for fam in ("FVG", "BOS", "LIQUIDITY"):
                comp[fam + "-removed"] = composition_view(
                    cl_c, cl_a, canonical_key, exclude_family=fam)
            mean_c = sum(num(r, "rMultiple") for r in cl_c) / n_total
            comps[kind] = {
                "tier": TIER_VALUES[kind],
                "nTotal": n_total, "nAdmitted": n_adm, "nGatedOut": n_gated,
                "admissionRate": round(admission_rate, 6),
                "gatedOutRate": round(gated_out_rate, 6),
                "meanR": {"control": round(mean_c, 6),
                          "gatedOut": round(gated_mean, 6) if gated_mean is not None else None},
                "delta": round(delta, 6),
                "a1Identity": {"predictedDelta": round(a1_pred, 6)
                               if a1_pred is not None else None,
                               "reproduced": identity_a1},
                "admittedDzeroViolations": len(bad_admitted),
                "ci": ci, "dailyCi": daily_ci, "sensitivityCi9833": sens_ci,
                "observedDailyDelta": obs_d, "pairedDays": ndays,
                "winRate": {"control": round(wr_c, 4),
                            "admitted": round(wr_a, 4) if wr_a is not None else None},
                "nOpen": {"control": sum(1 for r in qualified_rows(ctrl["rows"])
                                         if r.get("outcome") == "0"),
                          "treatment": sum(1 for r in qualified_rows(arm["rows"])
                                           if r.get("outcome") == "0")},
                "composition": comp,
                "shareFlags": share_flags,
                # Section 8 decision inputs (report-only; verdict emitted by
                # the decision report).
                "decisionInputs": {
                    "absDeltaAtLeast010": abs(delta) >= MIN_EFFECT,
                    "ciExcludesZero": bool(ci) and not (ci["lo"] <= 0.0 <= ci["hi"]),
                    "nAtLeast50": n_total >= MIN_N,
                    "pairedDaysAtLeast10": ndays >= MIN_PAIRED_DAYS,
                    "estimatorsAgree": bool(ci and daily_ci) and (
                        (delta > 0) == (obs_d > 0)) if delta != 0 else True,
                },
            }
        per_file[f] = comps
    # Cross-file direction agreement (section 8): primary vs stability file.
    m15 = per_file.get(STABILITY_FILE, {})
    direction = {}
    for kind in TIER_RUNS:
        h1 = per_file.get(PRIMARY_FILE, {}).get(kind, {})
        m = m15.get(kind, {})
        if "error" in h1 or "error" in m:
            direction[kind] = {"primaryDelta": h1.get("delta"),
                               "stabilityDelta": m.get("delta"),
                               "agree": None}
        else:
            direction[kind] = {"primaryDelta": h1["delta"],
                               "stabilityDelta": m["delta"],
                               "agree": bool(h1["delta"] and m["delta"]
                                             and (h1["delta"] > 0) == (m["delta"] > 0))}
    return ({"gate": {"pass": True, "messages": gate_msgs,
                      "pairingKey": pairing_key, "pairingProof": proof},
             "perFile": per_file, "direction": direction,
             "thresholds": {"minEffect": MIN_EFFECT, "minN": MIN_N,
                            "minPairedDays": MIN_PAIRED_DAYS,
                            "iters": iters, "seed": SEED,
                            "sensitivityCi": "98.33%% (Bonferroni 0.05/3)"},
             "note": "delta = Mean(Treatment_R - Control_R) over the "
                     "complete eligible CONTROL population (Amendment A1); "
                     "Treatment_R = rMultiple if ADMITTED else 0R if "
                     "GATED-OUT; pairing key = canonical (Amendment A2); "
                     "verdict and decision ladder are computed in the "
                     "decision report"},
            True)


def run_selfcheck(art_dir, iters, json_path):
    loads = {}
    for f in FILES:
        ld = load_run(art_dir, f, "CONTROL")
        if ld is not None:
            loads[f] = ld
    ok, msgs = audit_control(loads)
    p_ok, p_msgs = canonical_uniqueness_audit(loads)
    ok = ok and p_ok
    probe = machinery_probe(loads, iters)
    for f in FILES:
        if probe.get(f) and "ci" in probe[f] and \
                not probe[f]["ciIncludesZero"]:
            ok = False
            msgs.append("FAIL %s: machinery probe CI excludes 0 on CONTROL vs "
                        "CONTROL (bootstrap corruption)" % f)
        if probe.get(f) and "delta" in probe[f] and probe[f]["delta"] != 0.0:
            ok = False
            msgs.append("FAIL %s: machinery probe delta %r != 0 on CONTROL vs "
                        "CONTROL" % (f, probe[f]["delta"]))
    out = {
        "mode": "selfcheck",
        "seed": SEED,
        "pairingKey": PAIRING_KEY,
        "audit": {"pass": ok, "messages": msgs},
        "pairingAudit": {"pass": p_ok, "messages": p_msgs},
        "machineryProbe": probe,
        "expectedManifest": expected_manifest(),
        "gateReadiness": "12-run artifacts + tier manifest required before "
                         "--gate; currently PENDING (expected: no new runs "
                         "until authorized)",
    }
    with open(json_path, "w") as fh:
        json.dump(out, fh, indent=1)
    return ok, out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--artifacts", default=DEFAULT_ARTS)
    ap.add_argument("--manifest", default=MANIFEST_JSON)
    ap.add_argument("--iters", type=int, default=DEFAULT_ITERS)
    ap.add_argument("--mode", choices=["selfcheck", "gate", "analyze"],
                    default="selfcheck")
    ap.add_argument("--json")
    args = ap.parse_args()
    random.seed(SEED)

    if args.mode == "selfcheck":
        json_path = args.json or SELFCHECK_JSON
        ok, out = run_selfcheck(args.artifacts, args.iters, json_path)
        print("== ED01 RL-HYP-01 self-check (seed %d, pairing key: %s) ==" %
              (SEED, PAIRING_KEY))
        print("audit:")
        for m in out["audit"]["messages"]:
            print("  %s" % m)
        if ok:
            print("  audit PASS (fingerprints + totals + qualified + closed + "
                  "per-family + days + window)")
        print("pairing audit (canonical-key uniqueness, Amendment A2):")
        for m in out["pairingAudit"]["messages"]:
            print("  %s" % m)
        if p_ok := out["pairingAudit"]["pass"]:
            print("  pairing PASS (canonical keys unique; decisionId unique "
                  "per segment)")
        print("estimator machinery probe (CONTROL vs CONTROL, delta=0 expected):")
        for f in FILES:
            pr = out["machineryProbe"].get(f, {})
            if "ci" in pr:
                print("  %-10s nClosed=%d nGatedOut=%d delta=%r CI=[%.4f, %.4f] "
                      "includes0=%s" %
                      (f, pr["nClosed"], pr["nGatedOut"], pr["delta"],
                       pr["ci"]["lo"], pr["ci"]["hi"], pr["ciIncludesZero"]))
            else:
                print("  %-10s %s" % (f, pr.get("error", "n/a")))
        print("expected 12-run manifest (%d runs, all PENDING):" %
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
        ok, msgs, pairing_key, proof = gate_twelve_runs(args.artifacts, args.manifest)
        print("== ED01 RL-HYP-01 pre-analysis gate (protocol 11 + A2) ==")
        for m in msgs:
            print("  %s" % m)
        if proof:
            print("pairing key: %s" % pairing_key)
            for p in proof:
                print("  %s" % p)
        if not ok:
            print("GATE FAILED - run set incomplete or invalid; no statistics "
                  "computed; re-run after audit.")
            return 1
        print("GATE PASS - all integrity/identity/distinguishability gates "
              "passed; pairing key: %s (Amendment A2)" % pairing_key)
        return 0

    out, gate_ok = analyze(args.artifacts, args.iters, args.manifest)
    json_path = args.json or ANALYSIS_JSON
    with open(json_path, "w") as fh:
        json.dump(out, fh, indent=1)
    print("== ED01 RL-HYP-01 analysis (paired opportunity-level, seed %d, "
          "pairing key: %s) ==" % (SEED, PAIRING_KEY))
    if not gate_ok:
        for m in out["gate"]["messages"]:
            print("  %s" % m)
        print("GATE FAILED - no statistics computed; run set rejected.")
        return 1
    for f in FILES:
        for kind in TIER_RUNS:
            pf = out["perFile"][f].get(kind, {})
            if "error" in pf:
                print("  %-10s %-4s %s" % (f, kind, pf["error"]))
                continue
            ci = pf["ci"]
            cistr = ("CI=[%.4f, %.4f]" % (ci["lo"], ci["hi"])) if ci else "CI=n/a"
            print("  %-10s %-4s delta=%+.4f %s nGated=%d/%d pairedDays=%d "
                  "a1Reproduced=%s dZeroViol=%d" %
                  (f, kind, pf["delta"], cistr, pf["nGatedOut"], pf["nTotal"],
                   pf["pairedDays"], pf["a1Identity"]["reproduced"],
                   pf["admittedDzeroViolations"]))
    print("pairing key: %s (Amendment A2)" % out["gate"]["pairingKey"])
    print("wrote %s" % json_path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
