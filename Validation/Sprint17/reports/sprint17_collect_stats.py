import csv, glob, hashlib, json, os

TELEMETRY = r"C:\Users\k.tharun balaji\AppData\Roaming\MetaQuotes\Terminal\Common\Files\Telemetry"
RUNS = ["EURUSD_M15", "EURUSD_H1", "GBPJPY_H1"]
OUT = r"C:\Users\KA757~1.THA\AppData\Local\Temp\opencode\sprint17_stats.json"

def load_dir(d):
    files = sorted(glob.glob(os.path.join(TELEMETRY, d, "telemetry_v3_*.csv")))
    rows = []
    header = None
    for f in files:
        with open(f, newline='', encoding='utf-16') as fh:
            rd = csv.DictReader(fh)
            if header is None:
                header = rd.fieldnames
            for r in rd:
                rows.append(r)
    return files, rows, header

report = {"runs": {}, "merged": {}}
all_keys = set()
merged_sha = {}
lines = []

for d in RUNS:
    files, rows, header = load_dir(d)
    keys = set()
    dups = 0
    n_win = n_loss = n_be = n_unknown = n_bad_outcome = 0
    combos = set()
    for r in rows:
        o = r.get("outcome", "")
        if o == "0": n_unknown += 1
        elif o == "1": n_win += 1
        elif o == "2": n_loss += 1
        elif o == "3": n_be += 1
        else: n_bad_outcome += 1
        k = (r.get("configFingerprint"), r.get("symbol"), r.get("timeframe"), r.get("signalTime"), r.get("firedRuleId"))
        if k in keys: dups += 1
        keys.add(k)
        all_keys.add(k)
        combos.add((r.get("configFingerprint"), r.get("symbol"), r.get("timeframe"), r.get("firedRuleId"), r.get("ruleEvidenceIds", "")))
    ts = [r.get("timestamp", "") for r in rows]
    fps = sorted(set(r.get("configFingerprint") for r in rows))
    syms = sorted(set(r.get("symbol") for r in rows))
    tfs = sorted(set(r.get("timeframe") for r in rows))
    shas = {}
    for f in files:
        with open(f, 'rb') as fh:
            shas[os.path.basename(f)] = hashlib.sha256(fh.read()).hexdigest()
        lines.append(f"{d}/{os.path.basename(f)}|{shas[os.path.basename(f)]}")
    n_rows = len(rows)
    report["runs"][d] = {
        "files": len(files), "rows": n_rows,
        "win": n_win, "loss": n_loss, "breakeven": n_be, "unknown": n_unknown,
        "badOutcome": n_bad_outcome,
        "decided": n_win + n_loss + n_be,
        "coveragePct": round(100.0 * (n_win + n_loss + n_be) / n_rows, 2) if n_rows else None,
        "dupKeys": dups, "uniqueKeys": len(keys),
        "evidenceCombos": len(combos),
        "minTs": min(ts) if ts else None, "maxTs": max(ts) if ts else None,
        "fingerprints": fps, "symbols": syms, "timeframes": tfs,
        "headerCols": len(header) if header else 0,
        "sha256": shas,
    }

mf = sorted(glob.glob(os.path.join(TELEMETRY, "merged", "telemetry_v3_*.csv")))
mrows = 0
for f in mf:
    with open(f, newline='', encoding='utf-16') as fh:
        mrows += sum(1 for _ in csv.DictReader(fh))
report["merged"]["files"] = len(mf)
report["merged"]["rows"] = mrows

run_total = sum(report["runs"][d]["rows"] for d in RUNS)
report["conservation"] = {
    "sumRuns": run_total, "mergedRows": mrows, "match": run_total == mrows,
    "uniqueKeysAll": len(all_keys), "dupKeysAcrossRuns": run_total - len(all_keys),
}

lines.sort()
digest = hashlib.sha256("\n".join(lines).encode("utf-8")).hexdigest()
report["datasetFingerprint"] = {
    "inputs": len(lines),
    "digest": digest,
    "formula": "SHA256(sorted '<runDir>/<filename>|<fileSHA256>' lines)",
}

with open(OUT, "w", encoding="utf-8") as fh:
    json.dump(report, fh, indent=2, sort_keys=True)
print(json.dumps({k: v for k, v in report.items() if k != "runs"}, indent=2))
for d in RUNS:
    r = report["runs"][d]
    print(f"{d}: files={r['files']} rows={r['rows']} win={r['win']} loss={r['loss']} be={r['breakeven']} unknown={r['unknown']} decided={r['decided']} coverage={r['coveragePct']}% dups={r['dupKeys']} combos={r['evidenceCombos']} range={r['minTs']}..{r['maxTs']} sym={r['symbols']} tf={r['timeframes']}")
print("saved:", OUT)
