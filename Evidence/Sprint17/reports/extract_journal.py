import re

LOG = r"C:\Users\k.tharun balaji\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\Tester\logs\20260802.log"
OUTDIR = r"C:\Users\k.tharun balaji\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Evidence\Sprint17\logs"

MARKERS = re.compile(r"CalibrationRunner|ExperimentRunner|\[Telemetry\]|SymbolContext|TradeManager|EntryOrchestrator|EntryEngine|ORDER-SENT|ERROR|Test passed|TELEMETRY SUMMARY|settlement|unsettled|Deinitializing|deinitialized|ENTRY_MODE_NEW|collector initialized|running (schema_health|structural)|Verdict|Score|Mode:")

def to_sec(t):
    try:
        h, m, s = t.split(":")
        return int(h) * 3600 + int(m) * 60 + float(s)
    except Exception:
        return None

WINDOWS = {
    "run1_eurusd_m15.log": (to_sec("17:08:30"), to_sec("18:01:30")),
    "run2_eurusd_h1.log": (to_sec("18:06:20"), to_sec("18:08:15")),
    "run3_gbpjpy_h1.log": (to_sec("18:10:20"), to_sec("18:12:20")),
    "gates.log": (to_sec("18:13:00"), to_sec("18:33:00")),
}
out = {k: open(OUTDIR + "\\" + k, "w", encoding="utf-8", newline="\n") for k in WINDOWS}
counts = {k: 0 for k in WINDOWS}

chunk = 67108864
with open(LOG, "rb") as f:
    carry = b""
    while True:
        data = f.read(chunk)
        if not data:
            break
        text = (carry + data).decode("utf-16", errors="replace")
        lines = text.split("\n")
        carry = lines[-1].encode("utf-16", errors="ignore")
        for ln in lines[:-1]:
            parts = ln.split("\t")
            if len(parts) < 4:
                continue
            t = to_sec(parts[2])
            if t is None:
                continue
            if not MARKERS.search(ln):
                continue
            for name, (lo, hi) in WINDOWS.items():
                if lo <= t <= hi:
                    out[name].write(ln + "\n")
                    counts[name] += 1

for name, fh in out.items():
    fh.close()
    print(f"{name}: {counts[name]} lines")
