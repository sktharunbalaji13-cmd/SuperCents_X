import csv
import glob
import json
import math
import os
import random

PROJECT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ROOT = os.path.dirname(os.path.dirname(PROJECT))
MERGED = os.path.join(ROOT, "Evidence", "Sprint17", "merged")
OUT = os.path.join(PROJECT, "Tools", "GR01")
REPORT = os.path.join(OUT, "reports")
os.makedirs(REPORT, exist_ok=True)

RULE_FAMILY = {
    "LIQUIDITY_BOS_BULLISH": "LIQUIDITY",
    "LIQUIDITY_BOS_BEARISH": "LIQUIDITY",
    "OB_FVG_BULLISH": "FVG",
    "OB_FVG_BEARISH": "FVG",
    "BOS_OB_BULLISH": "BOS",
    "BOS_OB_BEARISH": "BOS",
    "CHOCH_OB_REVERSAL": "CHOCH",
}
RULE_OB_CONTENT = {
    "OB_FVG_BULLISH": True,
    "OB_FVG_BEARISH": True,
    "BOS_OB_BULLISH": True,
    "BOS_OB_BEARISH": True,
}
FLOORS_CURRENT = {
    "LIQUIDITY": 0.60,
    "FVG": 0.40,
    "BOS": 0.35,
    "CHOCH": 0.35,
    "ORDER_BLOCK": 0.35,
    "UNKNOWN": 0.60,
}
SWEEP = [0.30, 0.35, 0.40, 0.45, 0.50, 0.55, 0.60, 0.65, 0.70, 0.75, 0.80]
BASE_WR = 0.3321
FAMILIES = ["LIQUIDITY", "FVG", "BOS", "CHOCH", "UNKNOWN", "ORDER_BLOCK"]
RUN_GROUPS = {"EURUSD_M15": [], "EURUSD_H1": [], "GBPJPY_H1": []}
for g in RUN_GROUPS:
    RUN_GROUPS[g] = [f for f in sorted(glob.glob(os.path.join(MERGED, "telemetry_v3_%s_*.csv" % g)))]

random.seed(20260807)

FILES = sorted(glob.glob(os.path.join(MERGED, "telemetry_v3_*.csv")))
assert len(FILES) == 19, "expected 19 frozen files, got %d" % len(FILES)


def family_of(row):
    name = (row.get("ruleName") or "").strip()
    return RULE_FAMILY.get(name, "UNKNOWN")


def num(row, key):
    try:
        return float(row.get(key, "0") or "0")
    except ValueError:
        return 0.0


def stats(rows):
    wins = sum(1 for r in rows if r[1] == "1")
    losses = sum(1 for r in rows if r[1] == "2")
    be = sum(1 for r in rows if r[1] == "3")
    n = len(rows)
    decided = wins + losses
    if decided == 0:
        return {"n": n, "wins": wins, "losses": losses, "be": be, "wr": None,
                "meanR": None, "confMean": None, "confMax": None}
    rm = [r[2] for r in rows]
    cf = [r[3] for r in rows]
    return {
        "n": n,
        "wins": wins,
        "losses": losses,
        "be": be,
        "wr": round(wins / decided, 4),
        "meanR": round(sum(rm) / len(rm), 4),
        "confMean": round(sum(cf) / len(cf), 4),
        "confMax": round(max(cf), 4),
    }


def bootstrap_ci(rows, iters=10000):
    n = len(rows)
    if n == 0:
        return None
    wins = [r for r in rows if r[1] == "1"]
    p = len(wins) / n
    rates = []
    for _ in range(iters):
        k = 0
        for _ in range(n):
            if random.random() < p:
                k += 1
        rates.append(k / n)
    rates.sort()
    return {"lo": round(rates[250], 4), "hi": round(rates[9750], 4)}


def load_rows(path):
    out = []
    with open(path, newline="", encoding="utf-16") as fh:
        for r in csv.DictReader(fh):
            o = r.get("outcome", "")
            if o not in ("1", "2", "3"):
                continue
            out.append((family_of(r), o, num(r, "rMultiple"), num(r, "confidence")))
    return out


print("loading frozen Sprint 17 merged dataset (%d files, utf-16)..." % len(FILES))
ALL = []
PER_FILE = []
for f in FILES:
    frows = load_rows(f)
    PER_FILE.append((os.path.basename(f), frows))
    ALL.extend(frows)

TOTAL = len(ALL)
print("decided rows (WIN+LOSS): %d" % TOTAL)

by_family = {fam: [r for r in ALL if r[0] == fam] for fam in FAMILIES}
FAMILY_N = {fam: len(rows) for fam, rows in by_family.items()}
print("family counts:", {k: v for k, v in FAMILY_N.items() if v > 0})
assert FAMILY_N["LIQUIDITY"] == 3553, FAMILY_N["LIQUIDITY"]
assert FAMILY_N["FVG"] == 12320, FAMILY_N["FVG"]
assert FAMILY_N["BOS"] == 858, FAMILY_N["BOS"]
assert FAMILY_N["CHOCH"] == 342, FAMILY_N["CHOCH"]
assert FAMILY_N["LIQUIDITY"] + FAMILY_N["FVG"] + FAMILY_N["BOS"] + FAMILY_N["CHOCH"] == 17073

report = {"dataset": {"files": len(FILES), "decidedRows": TOTAL}, "families": {}, "sweeps": {},
          "bootstrap": {}, "walkForward": {}}

for fam in FAMILIES:
    rows = by_family[fam]
    s = stats(rows)
    report["families"][fam] = s
    floor = FLOORS_CURRENT[fam]
    admitted = [r for r in rows if r[3] >= floor]
    report["families"][fam]["floorCurrent"] = floor
    report["families"][fam]["admittedCurrent"] = stats(admitted)
    report["bootstrap"][fam] = bootstrap_ci(rows)

    sweep = []
    for fl in SWEEP:
        q = [r for r in rows if r[3] >= fl]
        sw = stats(q)
        sweep.append({"floor": fl, "n": sw["n"], "wr": sw["wr"], "meanR": sw["meanR"]})
    report["sweeps"][fam] = sweep

    min_n = min(500, max(100, int(0.1 * len(rows))))
    candidates = [(sw["meanR"], sw["floor"], sw["n"], sw["wr"]) for sw in sweep
                  if sw["n"] is not None and sw["n"] >= min_n and sw["meanR"] is not None]
    best = max(candidates, key=lambda c: c[0]) if candidates else None
    report["families"][fam]["proposal"] = {
        "minN": min_n,
        "floor": best[1] if best else None,
        "n": best[2] if best else None,
        "wr": best[3] if best else None,
        "meanR": best[0] if best else None,
    }

wf = {}
for name, frows in PER_FILE:
    counts = {}
    for fam in FAMILIES:
        fr = [r for r in frows if r[0] == fam]
        if fr:
            sw = stats(fr)
            if sw["n"] >= 30:
                counts[fam] = sw
    wf[name] = counts
report["walkForward"] = wf

with open(os.path.join(REPORT, "gr01_funnel_data.json"), "w", encoding="utf-8") as fh:
    json.dump(report, fh, indent=2, sort_keys=True)


def md(text):
    return "`%s`" % text if isinstance(text, str) else text


lines = []
lines.append("# GR01 - Per-Family Admission Floor Funnel Report")
lines.append("")
lines.append("- Dataset: frozen Sprint 17 (19 merged v3 files, immutability enforced)")
lines.append("- Universe: decided rows (outcome WIN/LOSS/BE), %d rows; wr = WIN/(WIN+LOSS); base wr %.4f" % (TOTAL, BASE_WR))
lines.append("- Mapping: RuleTypeToFamily single-valued (SignalTypes.mqh); UNKNOWN = rule-0/evaluator path")
lines.append("- Generated by: `Tools/GR01/gr01_funnel.py` (read-only over frozen dataset)")
lines.append("")
lines.append("## 1. Current funnel at DD05 floors (fingerprint B7 policy)")
lines.append("")
lines.append("| Family | Floor | Qualified n | Qualified wr | Qualified meanR | Family n | Family wr | Family meanR |")
lines.append("|---|---|---|---|---|---|---|---|")
for fam in ["LIQUIDITY", "BOS", "CHOCH", "FVG", "UNKNOWN", "ORDER_BLOCK"]:
    s = report["families"][fam]
    a = s["admittedCurrent"]
    if s["n"] == 0:
        lines.append("| %s | %.2f | 0 | - | - | 0 | - | - |" % (fam, s["floorCurrent"]))
        continue
    lines.append("| %s | %.2f | %d | %s | %s | %d | %s | %s |" % (
        fam, s["floorCurrent"], a["n"],
        "%.4f" % a["wr"] if a["wr"] is not None else "-",
        "%.4f" % a["meanR"] if a["meanR"] is not None else "-",
        s["n"], "%.4f" % s["wr"], "%.4f" % s["meanR"]))
lines.append("")
lines.append("## 2. Proposal (expectancy-maximizing floor, min admitted n per family)")
lines.append("")
lines.append("| Family | minN | Proposal floor | Qualified n | Qualified wr | Qualified meanR | Decision vs base %.4f |" % BASE_WR)
lines.append("|---|---|---|---|---|---|---|")
for fam in ["LIQUIDITY", "BOS", "CHOCH", "FVG", "UNKNOWN", "ORDER_BLOCK"]:
    s = report["families"][fam]
    p = s["proposal"]
    if p["floor"] is None:
        lines.append("| %s | %d | - | - | - | - | no admissible config |" % (fam, p["minN"]))
        continue
    delta = "%.4f vs base" % p["wr"]
    lines.append("| %s | %d | %.2f | %d | %.4f | %.4f | %s |" % (
        fam, p["minN"], p["floor"], p["n"], p["wr"], p["meanR"], delta))
lines.append("")
lines.append("## 3. Floor sweep (admitted subset per floor)")
lines.append("")
for fam in ["LIQUIDITY", "BOS", "CHOCH", "FVG", "UNKNOWN", "ORDER_BLOCK"]:
    if report["families"][fam]["n"] == 0:
        continue
    lines.append("### %s (family n=%d, wr=%.4f, meanR=%.4f)" % (
        fam, report["families"][fam]["n"], report["families"][fam]["wr"],
        report["families"][fam]["meanR"]))
    lines.append("")
    lines.append("| Floor | Qualified n | Qualified wr | Qualified meanR |")
    lines.append("|---|---|---|---|")
    for sw in report["sweeps"][fam]:
        lines.append("| %.2f | %d | %s | %s |" % (
            sw["floor"], sw["n"],
            "%.4f" % sw["wr"] if sw["wr"] is not None else "-",
            "%.4f" % sw["meanR"] if sw["meanR"] is not None else "-"))
    lines.append("")
lines.append("## 4. Bootstrap 95%% CI on family wr (Monte Carlo stage)")
lines.append("")
lines.append("| Family | wr | CI lo | CI hi | vs base |")
lines.append("|---|---|---|---|---|")
for fam in ["LIQUIDITY", "BOS", "CHOCH", "FVG", "UNKNOWN", "ORDER_BLOCK"]:
    s = report["families"][fam]
    b = report["bootstrap"][fam]
    if s["n"] == 0 or b is None:
        lines.append("| %s | - | - | - | - |" % fam)
        continue
    lines.append("| %s | %.4f | %.4f | %.4f | %s |" % (
        fam, s["wr"], b["lo"], b["hi"],
        "above" if s["wr"] > BASE_WR else "at-or-below"))
lines.append("")
lines.append("## 5. Walk-forward stability (per-file wr by family, n>=30)")
lines.append("")
lines.append("| File | %s |" % " | ".join(["%s (wr, n)" % fam for fam in ["LIQUIDITY", "BOS", "CHOCH", "FVG"]]))
lines.append("|---|---|")
for name, counts in wf.items():
    cells = []
    for fam in ["LIQUIDITY", "BOS", "CHOCH", "FVG"]:
        c = counts.get(fam)
        cells.append("%s, %d" % ("%.4f" % c["wr"] if c else "-", c["n"] if c else 0))
    lines.append("| %s | %s |" % (name, " | ".join(cells)))

with open(os.path.join(REPORT, "gr01_funnel_report.md"), "w", encoding="utf-8") as fh:
    fh.write("\n".join(lines) + "\n")

print("saved: %s" % os.path.join(REPORT, "gr01_funnel_data.json"))
print("saved: %s" % os.path.join(REPORT, "gr01_funnel_report.md"))
