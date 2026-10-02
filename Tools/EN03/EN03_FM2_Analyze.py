#!/usr/bin/env python3
"""
EN03_FM2_Analyze.py - EN-03 Phase 2 targeted FM-2 adversarial analysis.

Authorized research (docs/Sprint24_EN03_Assessment.md, Phase 2). Reads the
four arm artifacts produced by EN03_FM2_Run.ps1
(fm2_artifacts/<ARM>/en03_fm2_*.csv, one state row per scenario window
W=5..33) and validates the coordinated gate fix against the VERIFIED
trace derived from the fork code (documented in the scenario EA header):

  W=19  H3@16 locks L2@13; BEARISH BOS crosses L2 (bar17 close 1.0838)
        -> trend UNKNOWN->BEARISH; PP HIGH H2 (PP#1).
  W=23  FM-2 TICK: L3@20 locks H3@16; BULLISH BOS crosses H3 (bar19
        close 1.0925) -> trend BEARISH->BULLISH; PP LOW L2 (PP#2,
        activation bar21); bearish CHOCH (bar21 close 1.0838 < 1.0840)
        -> LEGACY gate flips BEARISH (flipGate=1), COORD suppressed
        (coordSkip=1), OFF inert.
  W=24  LEGACY picks up the gate-flip trend change -> PP HIGH H3 (PP#3).
  W=30  LEGACY-only bullish CHOCH (bar29 close 1.0940 > H3 1.0920)
        -> gate flip #2 -> BULLISH (flipGate=2).
  W=31  L4@28 locks H4@25; BULLISH BOS crosses H4 (bar29 close 1.0940,
        no flip - already BULLISH); LEGACY PP LOW L3 (PP#4).

Seven checks:
  CHECK 1  FM-2 tick single effective transition (W=23)
  CHECK 2  no BOS/gate double-flip (flip counts monotone +1 per event)
  CHECK 3  CHOCH direction (LEGACY 2 events W=23+W30; COORD/OFF 1)
  CHECK 4  PP state (LEGACY 4: W19,W23,W24,W31; COORD/OFF 2: W19,W23)
  CHECK 5  no OB/FVG/liquidity divergence (COORD == OFF per window)
  CHECK 6  BOS trajectory (3 events at W=19,W=23,W=31 in ALL arms)
  CHECK 7  replay determinism (COORDINATED2 bytes == COORDINATED bytes)

Verdict: PASS (all 7) or FAIL (quantified). Report + recommendation go
to the user; no A/B selection; no production change; no commit.

Usage: python EN03_FM2_Analyze.py  (run from Tools/EN03)
       python EN03_FM2_Analyze.py --artifacts <dir>
"""

import argparse
import csv
import os
import sys

ARMS = ["LEGACY", "OFF", "COORDINATED", "COORDINATED2"]
W_MIN = 5
W_MAX = 33


def decode_text(data):
    """MQL5 FileWrite defaults to UTF-16LE; fall back to UTF-8 for
    externally-written files."""
    if data[:2] == b"\xff\xfe":
        return data.decode("utf-16")
    return data.decode("utf-8-sig", errors="replace")


def find_fm2(art_dir, arm):
    d = os.path.join(art_dir, arm)
    if not os.path.isdir(d):
        return None
    for name in sorted(os.listdir(d)):
        if name.startswith("en03_fm2_") and name.endswith(".csv"):
            return os.path.join(d, name)
    return None


def load_fm2(path):
    with open(path, "rb") as fh:
        text = decode_text(fh.read())
    rd = list(csv.reader(text.splitlines()))
    if not rd:
        raise ValueError("empty capture: %s" % path)
    hdr = rd[0]
    rows = [dict(zip(hdr, r)) for r in rd[1:]]
    return hdr, rows


def intv(v):
    try:
        return int(v)
    except (TypeError, ValueError):
        return -999


def by_window(rows):
    return {intv(r["window"]): r for r in rows}


def print_result(num, ok, detail):
    print("CHECK %d  %s  %s" % (num, "PASS" if ok else "FAIL", detail))


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("--artifacts", default="fm2_artifacts",
                    help="EN-03 FM2 artifact root (default fm2_artifacts)")
    args = ap.parse_args()

    art_dir = args.artifacts
    if not os.path.isdir(art_dir):
        print("FATAL artifact dir not found:", art_dir)
        sys.exit(2)

    caps = {}
    for arm in ARMS:
        p = find_fm2(art_dir, arm)
        if p is None:
            print("FATAL missing en03_fm2 capture for arm", arm)
            sys.exit(2)
        caps[arm] = (p, load_fm2(p)[1])
        print("loaded %s <- %s (%d rows)" % (arm, os.path.relpath(p), len(caps[arm][1])))

    #--- structural: header + window coverage
    for arm in ARMS:
        _, rows = caps[arm]
        ws = sorted(intv(r["window"]) for r in rows)
        if ws != list(range(W_MIN, W_MAX + 1)):
            print("FATAL %s window coverage wrong: %s" % (arm, ws))
            sys.exit(2)

    W = {arm: by_window(caps[arm][1]) for arm in ARMS}
    ok_all = True

    print("=" * 78)
    print("CHECK 1  FM-2 tick (W=23): single effective trend transition")
    print("=" * 78)
    # LEGACY: BOS flip +1 overwritten by opposite gate flip -> net -1,
    # flipGate 0->1 exactly.
    l = W["LEGACY"][23]
    c = W["COORDINATED"][23]
    o = W["OFF"][23]
    ok1a = (intv(l["trend"]) == -1 and intv(l["flipGate"]) == 1)
    ok1b = (intv(c["trend"]) == 1 and intv(c["flipCoord"]) == 0
            and intv(c["coordSkip"]) == 1)
    ok1c = (intv(o["trend"]) == 1 and intv(o["flipGate"]) == 0
            and intv(o["flipCoord"]) == 0 and intv(o["coordSkip"]) == 0)
    ok1 = ok1a and ok1b and ok1c
    print_result(1, ok1,
                 "LEGACY trend=%s flipGate=%s | COORD trend=%s flipCoord=%s "
                 "coordSkip=%s | OFF trend=%s flipGate=%s"
                 % (l["trend"], l["flipGate"], c["trend"], c["flipCoord"],
                    c["coordSkip"], o["trend"], o["flipGate"]))

    print("=" * 78)
    print("CHECK 2  no BOS/gate double-flip (flip counts +1 per event)")
    print("=" * 78)
    fg = [intv(r["flipGate"]) for r in sorted(caps["LEGACY"][1], key=lambda r: intv(r["window"]))]
    jumps = [fg[i] - fg[i - 1] for i in range(1, len(fg))]
    bad_jumps = [(i, j) for i, j in enumerate(jumps) if j > 1]
    fg_ok = not bad_jumps and fg[-1] == 2
    # LEGACY flips land exactly at W=23 and W=30.
    fg_ev = [i + W_MIN + 1 for i, j in enumerate(jumps) if j == 1]
    fg_ok = fg_ok and fg_ev == [23, 30]
    # flipCoord must stay 0 everywhere; coordSkip exactly {0..22:0, 23..33:1} for COORD.
    fc_all = all(intv(r["flipCoord"]) == 0 for r in caps["COORDINATED"][1])
    cs_coord = [intv(r["coordSkip"]) for r in sorted(caps["COORDINATED"][1],
                                                     key=lambda r: intv(r["window"]))]
    cs_ok = cs_coord == [0] * (23 - W_MIN) + [1] * (W_MAX - 23 + 1)
    off_inert = all(intv(r["flipGate"]) == 0 and intv(r["flipCoord"]) == 0
                    and intv(r["coordSkip"]) == 0 for r in caps["OFF"][1])
    ok2 = fg_ok and fc_all and cs_ok and off_inert
    print_result(2, ok2,
                 "LEGACY flipGate events at %s (final=%d) | COORD flipCoord=0 %s, "
                 "coordSkip=%d (final) | OFF all-zero %s"
                 % (fg_ev, fg[-1], "OK" if fc_all else "VIOLATED", cs_coord[-1],
                    "OK" if off_inert else "VIOLATED"))

    print("=" * 78)
    print("CHECK 3  CHOCH direction (LEGACY 2: W23 bearish + W30 bullish; "
          "COORD/OFF 1: W23)")
    print("=" * 78)
    ch_leg = [intv(r["chochCount"]) for r in sorted(caps["LEGACY"][1],
                                                    key=lambda r: intv(r["window"]))]
    ch_ev_leg = [i + W_MIN + 1 for i, j in enumerate([ch_leg[i] - ch_leg[i - 1]
                                                  for i in range(1, len(ch_leg))]) if j == 1]
    ch_coord = [intv(r["chochCount"]) for r in sorted(caps["COORDINATED"][1],
                                                      key=lambda r: intv(r["window"]))]
    ch_ev_coord = [i + W_MIN + 1 for i, j in enumerate([ch_coord[i] - ch_coord[i - 1]
                                                    for i in range(1, len(ch_coord))]) if j == 1]
    ch_off = [intv(r["chochCount"]) for r in sorted(caps["OFF"][1],
                                                    key=lambda r: intv(r["window"]))]
    ch_ev_off = [i + W_MIN + 1 for i, j in enumerate([ch_off[i] - ch_off[i - 1]
                                                  for i in range(1, len(ch_off))]) if j == 1]
    ok3 = (ch_ev_leg == [23, 30] and ch_leg[-1] == 2
           and ch_ev_coord == [23] and ch_coord[-1] == 1
           and ch_ev_off == [23] and ch_off[-1] == 1)
    print_result(3, ok3,
                 "LEGACY choch events at %s (final=%d) | COORD events at %s (final=%d) | "
                 "OFF events at %s (final=%d)"
                 % (ch_ev_leg, ch_leg[-1], ch_ev_coord, ch_coord[-1],
                    ch_ev_off, ch_off[-1]))

    print("=" * 78)
    print("CHECK 4  PP state (LEGACY 4: W19,W23,W24,W31; COORD/OFF 2: W19,W23)")
    print("=" * 78)
    pp_leg = [intv(r["ppCount"]) for r in sorted(caps["LEGACY"][1],
                                                 key=lambda r: intv(r["window"]))]
    pp_ev_leg = [i + W_MIN + 1 for i, j in enumerate([pp_leg[i] - pp_leg[i - 1]
                                                  for i in range(1, len(pp_leg))]) if j == 1]
    pp_coord = [intv(r["ppCount"]) for r in sorted(caps["COORDINATED"][1],
                                                   key=lambda r: intv(r["window"]))]
    pp_ev_coord = [i + W_MIN + 1 for i, j in enumerate([pp_coord[i] - pp_coord[i - 1]
                                                    for i in range(1, len(pp_coord))]) if j == 1]
    pp_off = [intv(r["ppCount"]) for r in sorted(caps["OFF"][1],
                                                 key=lambda r: intv(r["window"]))]
    ok4 = (pp_ev_leg == [19, 23, 24, 31] and pp_leg[-1] == 4
           and pp_ev_coord == [19, 23] and pp_coord[-1] == 2
           and pp_off[-1] == 2 and pp_off == pp_coord)
    print_result(4, ok4,
                 "LEGACY pp events at %s (final=%d) | COORD at %s (final=%d) | "
                 "OFF final=%d (COORD==OFF %s)"
                 % (pp_ev_leg, pp_leg[-1], pp_ev_coord, pp_coord[-1], pp_off[-1],
                    "OK" if pp_off == pp_coord else "VIOLATED"))

    print("=" * 78)
    print("CHECK 5  no OB/FVG/liquidity divergence (COORD == OFF per window)")
    print("=" * 78)
    div = []
    for w in range(W_MIN, W_MAX + 1):
        for col in ("obCount", "fvgCount", "liqCount", "signalCount"):
            a = W["COORDINATED"][w][col]
            b = W["OFF"][w][col]
            if a != b:
                div.append("W%d.%s %s vs %s" % (w, col, a, b))
    ok5 = not div
    print_result(5, ok5,
                 "COORD vs OFF: %s"
                 % ("byte-identical per window (ob/fvg/liq/signal)"
                    if ok5 else "; ".join(div)))

    print("=" * 78)
    print("CHECK 6  BOS trajectory (3 events at W=19,W=23,W=31 in ALL arms)")
    print("=" * 78)
    bos_traj = {}
    for arm in ARMS:
        rows = sorted(caps[arm][1], key=lambda r: intv(r["window"]))
        ev = [i + W_MIN + 1 for i, j in enumerate([intv(rows[i]["bosCount"])
                                               - intv(rows[i - 1]["bosCount"])
                                               for i in range(1, len(rows))]) if j == 1]
        bos_traj[arm] = (ev, intv(rows[-1]["bosCount"]))
    ok6 = all(ev == [19, 23, 31] and final == 3
              for ev, final in bos_traj.values())
    print_result(6, ok6,
                 "; ".join("%s events at %s final=%d" % (a, ev, f)
                           for a, (ev, f) in bos_traj.items()))

    print("=" * 78)
    print("CHECK 7  replay determinism (COORDINATED2 bytes == COORDINATED)")
    print("=" * 78)
    p1, _ = caps["COORDINATED"]
    p2, _ = caps["COORDINATED2"]
    with open(p1, "rb") as fh:
        b1 = fh.read()
    with open(p2, "rb") as fh:
        b2 = fh.read()
    ok7 = b1 == b2
    print_result(7, ok7,
                 "coord vs coord2: %s (%d bytes)" % ("identical" if ok7 else "DIFFER", len(b1)))

    print()
    print("=" * 78)
    if ok1 and ok2 and ok3 and ok4 and ok5 and ok6 and ok7:
        print("VERDICT PASS - all 7 checks. FM-2 same-tick BOS-flip + opposite")
        print("CHOCH handled exactly once per tick in every arm; coordinated")
        print("gate suppressed the double-flip (coordSkip=1 at W=23) without")
        print("perturbing PP/BOS/CHOCH/OB/FVG/liquidity populations.")
        sys.exit(0)
    print("VERDICT FAIL - quantified above. STOP; report to user; do NOT")
    print("proceed to any production change or A/B selection.")
    sys.exit(1)


if __name__ == "__main__":
    main()
