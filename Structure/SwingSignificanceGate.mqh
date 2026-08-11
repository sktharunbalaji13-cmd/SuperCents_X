//+------------------------------------------------------------------+
//|                                  SwingSignificanceGate.mqh         |
//|                                          Sprint 22 (RL-HYP-01)     |
//+------------------------------------------------------------------+
//  RL-HYP-01 swing-significance admission gate (frozen
//  docs/Sprint22_RL_HYP_01_Protocol.md §5, §11, §14): an entry
//  candidate is admitted only when a completed structural pivot in the
//  trailing SWING_STRENGTH*2+1 bars of the decision bar — completed
//  BEFORE the decision bar's open — has swing amplitude (price distance
//  from the preceding alternating pivot) >= k * ATR(14), measured at
//  the pivot bar.
//
//  - tier <= 0.0 => gate OFF: every candidate is admitted with neutral
//    telemetry (B8 behavior, byte-identical).
//  - The gate resolves ONLY on completed pivots (extremum e requires
//    confirmation bars e+1..e+2; e+2 must close before the decision
//    bar's open => e <= d - SWING_STRENGTH - 1). No look-ahead, no
//    repainting (gate 3b proof).
//  - The gate NEVER mutates the frozen SwingDetector /
//    StructuralPivotEngine chain (evaluated through a const engine).
//  - The tier is OUTSIDE the configuration fingerprint (§11.1, ED01-E
//    hardcoded-token precedent) — verified by the fingerprint tests.
//+------------------------------------------------------------------+
#ifndef __SWING_SIGNIFICANCE_GATE_MQH__
#define __SWING_SIGNIFICANCE_GATE_MQH__

#include "../Utils/Constants.mqh"
#include "StructuralPivotEngine.mqh"
#include "../Telemetry/TelemetryTypes.mqh"

//--- ATR(14) is frozen in the protocol (§5); k multiplies this period.
#define SWING_GATE_ATR_PERIOD        14
#define SWING_GATE_DECISION_ADMIT    "ADMIT"
#define SWING_GATE_DECISION_OUT      "GATE-OUT"
#define SWING_GATE_DECISION_OFF      "OFF"

//--- Gate evaluation result (also the telemetry source, §14).
struct SwingGateResult
{
    bool   admitted;
    string gateDecision;      // ADMIT | GATE-OUT | OFF
    int    qualifyingPivotId; // structural pivot id (0 = none)
    double thresholdKATR;     // k * ATR(14) at the qualifying pivot bar
    double amplitude;         // |pivot price - preceding alternating pivot|
};

//--- ATR(14) at chronological bar `pivotBar`, computed directly from
//    the as-series OHLC arrays (index 0 = newest; chronological bar i
//    maps to series index barCount-1-i) with the current bar acting as
//    the confirmation close — the §5 definition, no indicator state.
double SwingGateATR14(const int pivotBar, const int barCount,
                      const double &high[], const double &low[], const double &close[])
{
    double sum = 0.0;
    int start = pivotBar - SWING_GATE_ATR_PERIOD + 1;
    if(start < 0)
        start = 0;
    for(int i = start; i <= pivotBar; i++)
    {
        int s = barCount - 1 - i;
        double tr = high[s] - low[s];
        if(s + 1 < barCount)
        {
            double hc = MathAbs(high[s] - close[s + 1]);
            double lc = MathAbs(low[s] - close[s + 1]);
            if(hc > tr) tr = hc;
            if(lc > tr) tr = lc;
        }
        sum += tr;
    }
    return sum / (double)SWING_GATE_ATR_PERIOD;
}

//--- Evaluate the gate at the decision bar (chronological index d;
//    barCount = total bars).  high/low/close are as-series OHLC exactly
//    as the runtime decision point sees them (index 0 = newest).
//    The pivot chain is read-only; the gate never mutates it.
void SwingGateEvaluate(const CStructuralPivotEngine &pivots,
                       const int decisionBar, const int barCount,
                       const double &high[], const double &low[], const double &close[],
                       const double tier, SwingGateResult &out)
{
    //--- Neutral result.
    out.admitted = false;
    out.gateDecision = SWING_GATE_DECISION_OUT;
    out.qualifyingPivotId = 0;
    out.thresholdKATR = 0.0;
    out.amplitude = 0.0;

    //--- Gate OFF: tier <= 0.0 admits every candidate (B8 behavior).
    if(tier <= 0.0)
    {
        out.admitted = true;
        out.gateDecision = SWING_GATE_DECISION_OFF;
        return;
    }

    //--- Trailing window: SWING_STRENGTH*2+1 bars ending at the decision
    //    bar [d - SWING_STRENGTH*2, d].  Completion rule: extremum bar e
    //    is confirmed at bar e + SWING_STRENGTH, which must close BEFORE
    //    the decision bar's open => e <= d - SWING_STRENGTH - 1.
    const int windowStart = decisionBar - (SWING_STRENGTH * 2 + 1) + 1;
    const int lastCompleted = decisionBar - SWING_STRENGTH - 1;

    //--- Newest pivot first; the chain is chronological so once the
    //    window start is passed all older pivots are outside too.
    for(int i = pivots.GetPivotCount() - 1; i >= 0; i--)
    {
        StructuralPivot p;
        if(!pivots.GetPivot(i, p))
            continue;

        if(p.barIndex < windowStart)
            break;
        if(p.barIndex > lastCompleted)
            continue; // not completed before the decision bar's open

        //--- Amplitude requires the preceding ALTERNATING pivot.
        if(i == 0)
            continue;
        StructuralPivot prev;
        if(!pivots.GetPivot(i - 1, prev))
            continue;
        if(prev.isHigh == p.isHigh)
            continue;

        double amplitude = MathAbs(p.price - prev.price);
        double threshold = tier * SwingGateATR14(p.barIndex, barCount, high, low, close);

        if(amplitude >= threshold)
        {
            out.admitted = true;
            out.gateDecision = SWING_GATE_DECISION_ADMIT;
            out.qualifyingPivotId = p.id;
            out.thresholdKATR = threshold;
            out.amplitude = amplitude;
            return;
        }
    }
}

//--- Stamp the gate result onto a telemetry row (§14 columns; the row
//    keeps every other field untouched, gate 3b admission-only
//    invariance).  swingAmplitude records the k*ATR(14) significance
//    threshold at decision time (the value that proves the gate
//    operated).
void SwingGateApplyToRow(TelemetryRow &row, const SwingGateResult &gate)
{
    row.swingQualifyingId = gate.qualifyingPivotId;
    row.swingAmplitude = gate.thresholdKATR;
    row.gateDecision = gate.gateDecision;
}

#endif // __SWING_SIGNIFICANCE_GATE_MQH__
