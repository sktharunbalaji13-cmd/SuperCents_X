//+------------------------------------------------------------------+
//|                                  TestSwingSignificanceGate.mqh     |
//|                                          Sprint 22 (RL-HYP-01)     |
//+------------------------------------------------------------------+
//  RL-HYP-01 swing-significance admission gate (frozen
//  docs/Sprint22_RL_HYP_01_Protocol.md §5, §14): an entry candidate is
//  admitted only when a completed structural pivot in the trailing
//  SWING_STRENGTH*2+1 bars of the decision bar — completed BEFORE the
//  decision bar's open — has swing amplitude (distance from the
//  preceding alternating pivot) >= tier x ATR(14) measured at the pivot
//  bar. Gate OFF (tier <= 0.0) admits everything (B8 behavior).
//
//  TDD list (§14, verbatim):
//    (a) amplitude = k*ATR(14) criterion on completed pivots
//    (b) no-qualifying-swing -> not admitted
//    (c) admitted rows byte-identical to ungated (gate 3b)
//    (d) fingerprint invariance under gate (hardcoded token)
//    (e) default 0.0 = byte-identical vs B8 (TT01; unit-level: OFF
//        neutral telemetry + CConfig default 0.0)
//+------------------------------------------------------------------+
#include "../TestAssert.mqh"
#include "../../Structure/SwingSignificanceGate.mqh"
#include "../../Core/Config.mqh"
#include "../../Telemetry/ConfigFingerprint.mqh"

//--- Per-bar OHLC override used to build deterministic fixtures.
struct SwingBarSpec
{
    int    index;
    double high;
    double low;
    double close;
};

//--- Deterministic fixture: n quiet bars (base +/- range/2) with the
//    given overrides. Chronological (0 = oldest). 5-bar fractal swings
//    are detected by the frozen CSwingDetector on this exact data.
void BuildSwingFixture(double &open[], double &high[], double &low[], double &close[],
                       datetime &time[], const int n, const double base, const double range,
                       const SwingBarSpec &ov[], const int ovCount)
{
    ArrayResize(open, n);
    ArrayResize(high, n);
    ArrayResize(low, n);
    ArrayResize(close, n);
    ArrayResize(time, n);
    for(int i = 0; i < n; i++)
    {
        open[i]  = base;
        high[i]  = base + range / 2.0;
        low[i]   = base - range / 2.0;
        close[i] = base;
        time[i]  = D'2026.01.01' + i * 3600;
    }
    for(int k = 0; k < ovCount; k++)
    {
        high[ov[k].index]  = ov[k].high;
        low[ov[k].index]   = ov[k].low;
        close[ov[k].index] = ov[k].close;
    }
}

//--- Drive the frozen chain (SwingDetector -> StructuralPivotEngine)
//    over the fixture and evaluate the gate at the decision bar
//    (d = n-1). The gate receives the as-series OHLC exactly as the
//    runtime decision point sees them (index 0 = newest).
void RunSwingGate(const double &open[], const double &high[], const double &low[],
                  const double &close[], const datetime &time[], const int n,
                  const double tier, SwingGateResult &out,
                  CSwingDetector &detector, CStructuralPivotEngine &pivots)
{
    detector.Init();
    pivots.Init();
    detector.Update(high, low, time, n);
    pivots.Update(&detector);

    double sh[], sl[], sc[];
    ArrayResize(sh, n);
    ArrayResize(sl, n);
    ArrayResize(sc, n);
    for(int i = 0; i < n; i++)
    {
        sh[i] = high[n - 1 - i];
        sl[i] = low[n - 1 - i];
        sc[i] = close[n - 1 - i];
    }
    SwingGateEvaluate(pivots, n - 1, n, sh, sl, sc, tier, out);
}

//--- Independent spec oracle: ATR(14) at the pivot bar, computed in
//    chronological space directly from the §5 definition (mean true
//    range over the 14 bars ending at the pivot bar).
double SwingRefATR14(const double &high[], const double &low[], const double &close[],
                     const int pivotBar, const int atrPeriod)
{
    double sum = 0.0;
    for(int i = pivotBar - atrPeriod + 1; i <= pivotBar; i++)
    {
        double tr = high[i] - low[i];
        double hc = MathAbs(high[i] - close[i - 1]);
        double lc = MathAbs(low[i] - close[i - 1]);
        if(hc > tr) tr = hc;
        if(lc > tr) tr = lc;
        sum += tr;
    }
    return sum / (double)atrPeriod;
}

//─── (e) + config: OFF default and neutral telemetry ────────────────

void TestSwingGate_ConfigAndOffNeutral(TestCounters &counters)
{
    CConfig config;
    TEST_DBL_EQ(0.0, config.GetSwingSignificanceTier(),
                "default SwingSignificanceTier = 0.0 (OFF = B8 behavior, §14)");

    double tiers[];
    ArrayResize(tiers, 3);
    tiers[0] = 1.0;
    tiers[1] = 1.5;
    tiers[2] = 2.0;
    for(int i = 0; i < 3; i++)
    {
        config.SetSwingSignificanceTier(tiers[i]);
        TEST_DBL_EQ(tiers[i], config.GetSwingSignificanceTier(),
                    StringFormat("tier %.1f round-trips", tiers[i]));
    }
    config.SetSwingSignificanceTier(0.0);

    //--- Gate OFF admits every candidate with neutral gate telemetry.
    const int n = 40;
    double open[], high[], low[], close[];
    datetime time[];
    SwingBarSpec noOv[];
    BuildSwingFixture(open, high, low, close, time, n, 1.0, 0.0010, noOv, 0);
    CSwingDetector detector;
    CStructuralPivotEngine pivots;
    SwingGateResult out;
    RunSwingGate(open, high, low, close, time, n, 0.0, out, detector, pivots);
    TEST_TRUE(out.admitted, "tier 0.0 admits every candidate (gate OFF)");
    TEST_STR_EQ("OFF", out.gateDecision, "gate OFF decision token");
    TEST_INT_EQ(0, out.qualifyingPivotId, "gate OFF: no qualifying pivot recorded");
    TEST_DBL_EQ(0.0, out.thresholdKATR, "gate OFF: no k*ATR threshold");
    TEST_DBL_EQ(0.0, out.amplitude, "gate OFF: no amplitude");
}

//─── (a) amplitude = k*ATR(14) criterion on completed pivots ─────────

void TestSwingGate_AmplitudeCriterionKATR(TestCounters &counters)
{
    //--- Fixture A: low swing @30 (0.9970), then high swing @35 (1.0040).
    //    Frozen chain: [L(30)@0.9970, H(35)@1.0040] (strictly alternating).
    //    amplitude = 0.0070. ATR(14)@35 = 0.0230/14 = 0.0016429 (hand-checked
    //    TR sum over bars 22..35: 7x0.0010 quiet [22-28] + 0.0025 [29] +
    //    0.0035 [30] + 0.0030 [31: |1.0005-0.9975| overrides the quiet range]
    //    + 3x0.0010 [32-34] + 0.0040 [35]).
    //    Decision bar d = 39: trailing 5-bar window [35,39] -> H(35) in
    //    window and completed before d's open (e = 35 <= d-3).
    const int n = 40;
    double open[], high[], low[], close[];
    datetime time[];
    SwingBarSpec ov[];
    ArrayResize(ov, 3);
    ov[0].index = 29; ov[0].high = 1.0005; ov[0].low = 0.9980; ov[0].close = 0.9985;
    ov[1].index = 30; ov[1].high = 1.0005; ov[1].low = 0.9970; ov[1].close = 0.9975;
    ov[2].index = 35; ov[2].high = 1.0040; ov[2].low = 1.0000; ov[2].close = 1.0020;
    BuildSwingFixture(open, high, low, close, time, n, 1.0, 0.0010, ov, 3);

    //--- Sanity: the frozen chain detects exactly L@30 then H@35.
    CSwingDetector detector;
    CStructuralPivotEngine pivots;
    detector.Init();
    pivots.Init();
    detector.Update(high, low, time, n);
    pivots.Update(&detector);
    TEST_INT_EQ(2, pivots.GetPivotCount(), "fixture A produces exactly 2 structural pivots");
    StructuralPivot p0, p1;
    TEST_TRUE(pivots.GetPivot(0, p0), "pivot 0 readable");
    TEST_TRUE(pivots.GetPivot(1, p1), "pivot 1 readable");
    TEST_FALSE(p0.isHigh, "pivot 0 is the low swing");
    TEST_TRUE(p1.isHigh, "pivot 1 is the high swing");
    TEST_INT_EQ(30, p0.barIndex, "pivot 0 extremum bar 30");
    TEST_INT_EQ(35, p1.barIndex, "pivot 1 extremum bar 35");
    TEST_DBL_NEAR(0.9970, p0.price, 1e-12, "pivot 0 price");
    TEST_DBL_NEAR(1.0040, p1.price, 1e-12, "pivot 1 price");

    //--- Independent ATR oracle at the pivot bar.
    double refATR = SwingRefATR14(high, low, close, 35, 14);
    TEST_DBL_NEAR(0.0230 / 14.0, refATR, 1e-12, "reference ATR(14)@35 = 0.0230/14 (hand-computed)");

    //--- (a): amplitude >= k*ATR(14) admits at every pre-registered tier.
    double tiers[];
    ArrayResize(tiers, 3);
    tiers[0] = 1.0;
    tiers[1] = 1.5;
    tiers[2] = 2.0;
    for(int i = 0; i < 3; i++)
    {
        SwingGateResult out;
        RunSwingGate(open, high, low, close, time, n, tiers[i], out, detector, pivots);
        string tag = StringFormat("k=%.1f", tiers[i]);
        TEST_TRUE(out.admitted, tag + " amplitude 0.0070 >= k*ATR(14) admits");
        TEST_STR_EQ("ADMIT", out.gateDecision, tag + " ADMIT token");
        TEST_INT_EQ(p1.id, out.qualifyingPivotId, tag + " qualifying pivot = H(35) structural id");
        TEST_DBL_NEAR(0.0070, out.amplitude, 1e-12, tag + " amplitude = |1.0040 - 0.9970|");
        TEST_DBL_NEAR(tiers[i] * refATR, out.thresholdKATR, 1e-12, tag + " threshold = k*ATR(14) at pivot bar");
    }
}

//─── (b) no qualifying swing -> not admitted ─────────────────────────

void TestSwingGate_AmplitudeBelowThresholdGatesOut(TestCounters &counters)
{
    //--- Fixture B: low swing @30 (1.0010), then high swing @35 (1.0015).
    //    amplitude = 0.0005. ATR(14)@35 = 0.0198/14 = 0.0014143 (hand-checked
    //    TR sum over bars 22..35: 6x0.0010 quiet [22-27] + 0.0030 [28] +
    //    0.0010 [29] + 0.0015 [30] + 0.0018 [31] + 0.0010 [32] + 0.0030 [33:
    //    |0.9995-1.0025|] + 0.0010 [34] + 0.0015 [35]). k=1.0 threshold
    //    ~0.001414 > 0.0005 -> GATE-OUT; k=0.3 threshold ~0.000424 < 0.0005
    //    -> ADMIT (boundary pinned); k=0.4 threshold ~0.000566 > 0.0005
    //    -> GATE-OUT (k*ATR crosses the amplitude between 0.3 and 0.4).
    const int n = 40;
    double open[], high[], low[], close[];
    datetime time[];
    SwingBarSpec ov[];
    ArrayResize(ov, 6);
    ov[0].index = 28; ov[0].high = 1.0030; ov[0].low = 1.0020; ov[0].close = 1.0025;
    ov[1].index = 29; ov[1].high = 1.0030; ov[1].low = 1.0020; ov[1].close = 1.0025;
    ov[2].index = 30; ov[2].high = 1.0015; ov[2].low = 1.0010; ov[2].close = 1.0012;
    ov[3].index = 31; ov[3].high = 1.0030; ov[3].low = 1.0020; ov[3].close = 1.0025;
    ov[4].index = 32; ov[4].high = 1.0030; ov[4].low = 1.0020; ov[4].close = 1.0025;
    ov[5].index = 35; ov[5].high = 1.0015; ov[5].low = 1.0005; ov[5].close = 1.0010;
    BuildSwingFixture(open, high, low, close, time, n, 1.0, 0.0010, ov, 6);

    CSwingDetector detector;
    CStructuralPivotEngine pivots;
    detector.Init();
    pivots.Init();
    detector.Update(high, low, time, n);
    pivots.Update(&detector);
    TEST_INT_EQ(2, pivots.GetPivotCount(), "fixture B produces exactly 2 structural pivots");
    StructuralPivot p1;
    TEST_TRUE(pivots.GetPivot(1, p1), "pivot 1 readable");
    TEST_TRUE(p1.isHigh, "pivot 1 is the high swing");
    TEST_INT_EQ(35, p1.barIndex, "pivot 1 extremum bar 35");
    TEST_DBL_NEAR(1.0015, p1.price, 1e-12, "pivot 1 price");

    double refATR = SwingRefATR14(high, low, close, 35, 14);
    TEST_DBL_NEAR(0.0198 / 14.0, refATR, 1e-12, "reference ATR(14)@35 = 0.0198/14 (hand-computed)");

    SwingGateResult out;
    RunSwingGate(open, high, low, close, time, n, 1.0, out, detector, pivots);
    TEST_FALSE(out.admitted, "k=1.0: amplitude 0.0005 < 1.0*ATR(14) -> GATE-OUT (b)");
    TEST_STR_EQ("GATE-OUT", out.gateDecision, "GATE-OUT token");
    TEST_INT_EQ(0, out.qualifyingPivotId, "GATE-OUT records no qualifying pivot");
    TEST_DBL_EQ(0.0, out.thresholdKATR, "GATE-OUT records no threshold");
    TEST_DBL_EQ(0.0, out.amplitude, "GATE-OUT records no amplitude");

    RunSwingGate(open, high, low, close, time, n, 0.3, out, detector, pivots);
    TEST_TRUE(out.admitted, "k=0.3: threshold 0.000424 below amplitude 0.0005 -> ADMIT");
    TEST_STR_EQ("ADMIT", out.gateDecision, "k=0.3 ADMIT token");
    TEST_DBL_NEAR(0.3 * refATR, out.thresholdKATR, 1e-12, "k=0.3 threshold = 0.3*ATR(14)");
    TEST_DBL_NEAR(0.0005, out.amplitude, 1e-12, "k=0.3 amplitude reported");

    RunSwingGate(open, high, low, close, time, n, 0.4, out, detector, pivots);
    TEST_FALSE(out.admitted, "k=0.4: threshold 0.000566 above amplitude 0.0005 -> GATE-OUT (boundary pinned)");
    TEST_STR_EQ("GATE-OUT", out.gateDecision, "k=0.4 GATE-OUT token");
    TEST_DBL_EQ(0.0, out.thresholdKATR, "k=0.4 gates out: no threshold recorded");
    TEST_DBL_EQ(0.0, out.amplitude, "k=0.4 gates out: no amplitude recorded");
}

void TestSwingGate_NoPivotInWindowGatesOut(TestCounters &counters)
{
    //--- No swings anywhere: empty chain -> GATE-OUT.
    const int n = 40;
    double open[], high[], low[], close[];
    datetime time[];
    SwingBarSpec noOv[];
    BuildSwingFixture(open, high, low, close, time, n, 1.0, 0.0010, noOv, 0);
    CSwingDetector detector;
    CStructuralPivotEngine pivots;
    SwingGateResult out;
    RunSwingGate(open, high, low, close, time, n, 1.0, out, detector, pivots);
    TEST_INT_EQ(0, pivots.GetPivotCount(), "quiet fixture: no pivots");
    TEST_FALSE(out.admitted, "no pivot anywhere -> GATE-OUT (b)");

    //--- A pivot exists but OUTSIDE the trailing window (low swing @30).
    SwingBarSpec ov[];
    ArrayResize(ov, 2);
    ov[0].index = 29; ov[0].high = 1.0005; ov[0].low = 0.9980; ov[0].close = 0.9985;
    ov[1].index = 30; ov[1].high = 1.0005; ov[1].low = 0.9970; ov[1].close = 0.9975;
    BuildSwingFixture(open, high, low, close, time, n, 1.0, 0.0010, ov, 2);
    RunSwingGate(open, high, low, close, time, n, 1.0, out, detector, pivots);
    TEST_INT_EQ(1, pivots.GetPivotCount(), "fixture: exactly one low pivot");
    TEST_FALSE(out.admitted, "pivot outside the trailing window -> GATE-OUT (b)");
}

void TestSwingGate_TrailingWindowBounds(TestCounters &counters)
{
    //--- Window bounds with fixture-A lows (L@30 = 0.9970) and a high
    //    swing of qualifying amplitude (>= k*ATR at every tested tier)
    //    placed at the window boundaries:
    //      e = 36 = d-3  -> completed before d's open -> ADMIT
    //      e = 35 = d-4  -> oldest in-window bar        -> ADMIT
    //      e = 34 = d-5  -> stale, outside window       -> GATE-OUT
    //      e = 37 = d-2  -> confirmed only by the decision bar
    //                       (NOT completed before its open) -> GATE-OUT
    const int n = 40;
    double open[], high[], low[], close[];
    datetime time[];

    for(int run = 0; run < 4; run++)
    {
        int e = 34 + run;
        SwingBarSpec ov[];
        ArrayResize(ov, 3);
        ov[0].index = 29; ov[0].high = 1.0005; ov[0].low = 0.9980; ov[0].close = 0.9985;
        ov[1].index = 30; ov[1].high = 1.0005; ov[1].low = 0.9970; ov[1].close = 0.9975;
        ov[2].index = e;  ov[2].high = 1.0040; ov[2].low = 1.0030; ov[2].close = 1.0035;
        BuildSwingFixture(open, high, low, close, time, n, 1.0, 0.0010, ov, 3);

        CSwingDetector detector;
        CStructuralPivotEngine pivots;
        SwingGateResult out;
        RunSwingGate(open, high, low, close, time, n, 1.0, out, detector, pivots);

        string tag = StringFormat("e=%d (d=%d)", e, n - 1);
        TEST_INT_EQ(2, pivots.GetPivotCount(), tag + ": chain [L(30), H(e)]");
        if(e == 36 || e == 35)
        {
            TEST_TRUE(out.admitted, tag + ": qualifying swing in window -> ADMIT");
            TEST_STR_EQ("ADMIT", out.gateDecision, tag + " ADMIT token");
        }
        else
        {
            TEST_FALSE(out.admitted, tag + ": outside window / confirmed by decision bar -> GATE-OUT");
            TEST_STR_EQ("GATE-OUT", out.gateDecision, tag + " GATE-OUT token");
        }
    }
}

void TestSwingGate_FirstPivotNeverQualifies(TestCounters &counters)
{
    //--- A single low swing at e=36 (inside the window): the FIRST
    //    structural pivot has no preceding alternating pivot, so the §5
    //    amplitude is unmeasurable -> GATE-OUT.
    const int n = 40;
    double open[], high[], low[], close[];
    datetime time[];
    SwingBarSpec ov[];
    ArrayResize(ov, 1);
    ov[0].index = 36; ov[0].high = 0.9960; ov[0].low = 0.9950; ov[0].close = 0.9955;
    BuildSwingFixture(open, high, low, close, time, n, 1.0, 0.0010, ov, 1);

    CSwingDetector detector;
    CStructuralPivotEngine pivots;
    SwingGateResult out;
    RunSwingGate(open, high, low, close, time, n, 1.0, out, detector, pivots);
    TEST_INT_EQ(1, pivots.GetPivotCount(), "fixture: single first pivot");
    TEST_FALSE(out.admitted, "first pivot has no preceding alternating pivot -> GATE-OUT (b)");
}

//─── (c) admitted rows byte-identical to ungated (gate 3b) ──────────

int RowSharedFieldDiffs(const TelemetryRow &a, const TelemetryRow &b)
{
    int d = 0;
    if(a.schemaVersion != b.schemaVersion) d++;
    if(a.configFingerprint != b.configFingerprint) d++;
    if(a.timestamp != b.timestamp) d++;
    if(a.symbol != b.symbol) d++;
    if(a.timeframe != b.timeframe) d++;
    if(a.eaVersion != b.eaVersion) d++;
    if(a.decisionId != b.decisionId) d++;
    if(a.direction != b.direction) d++;
    if(a.confidence != b.confidence) d++;
    if(a.structureRaw != b.structureRaw) d++;
    if(a.structureWeight != b.structureWeight) d++;
    if(a.structureContribution != b.structureContribution) d++;
    if(a.obRaw != b.obRaw) d++;
    if(a.obWeight != b.obWeight) d++;
    if(a.obContribution != b.obContribution) d++;
    if(a.fvgRaw != b.fvgRaw) d++;
    if(a.fvgWeight != b.fvgWeight) d++;
    if(a.fvgContribution != b.fvgContribution) d++;
    if(a.trendRaw != b.trendRaw) d++;
    if(a.trendWeight != b.trendWeight) d++;
    if(a.trendContribution != b.trendContribution) d++;
    if(a.liquidityRaw != b.liquidityRaw) d++;
    if(a.liquidityWeight != b.liquidityWeight) d++;
    if(a.liquidityContribution != b.liquidityContribution) d++;
    if(a.pdRaw != b.pdRaw) d++;
    if(a.pdWeight != b.pdWeight) d++;
    if(a.pdContribution != b.pdContribution) d++;
    if(a.validatorCount != b.validatorCount) d++;
    if(a.confThreshold != b.confThreshold) d++;
    if(a.newDecision != b.newDecision) d++;
    if(a.legacyDecision != b.legacyDecision) d++;
    if(a.decisionMatch != b.decisionMatch) d++;
    if(a.directionMatch != b.directionMatch) d++;
    if(a.legacyConfidence != b.legacyConfidence) d++;
    if(a.newConfidence != b.newConfidence) d++;
    if(a.disabledValidators != b.disabledValidators) d++;
    if(a.outcomeSource != b.outcomeSource) d++;
    if(a.outcome != b.outcome) d++;
    if(a.rMultiple != b.rMultiple) d++;
    if(a.barsHeld != b.barsHeld) d++;
    if(a.exitReason != b.exitReason) d++;
    if(a.entryPrice != b.entryPrice) d++;
    if(a.exitPrice != b.exitPrice) d++;
    if(a.actualOutcome != b.actualOutcome) d++;
    if(a.actualOutcomeSource != b.actualOutcomeSource) d++;
    if(a.scoreArchitecture != b.scoreArchitecture) d++;
    if(a.telemetryArchitecture != b.telemetryArchitecture) d++;
    if(a.evidenceContract != b.evidenceContract) d++;
    if(a.confidenceModel != b.confidenceModel) d++;
    if(a.componentData != b.componentData) d++;
    if(a.firedRuleId != b.firedRuleId) d++;
    if(a.ruleName != b.ruleName) d++;
    if(a.ruleScore != b.ruleScore) d++;
    if(a.ruleConfidence != b.ruleConfidence) d++;
    if(a.ruleEvidenceCount != b.ruleEvidenceCount) d++;
    if(a.ruleEvidenceIds != b.ruleEvidenceIds) d++;
    if(a.trendAligned != b.trendAligned) d++;
    if(a.layerStructural != b.layerStructural) d++;
    if(a.layerLiquidity != b.layerLiquidity) d++;
    if(a.layerConfirmation != b.layerConfirmation) d++;
    if(a.layerTotal != b.layerTotal) d++;
    if(a.hasBOS != b.hasBOS) d++;
    if(a.hasCHOCH != b.hasCHOCH) d++;
    if(a.hasOrderBlock != b.hasOrderBlock) d++;
    if(a.hasFVG != b.hasFVG) d++;
    if(a.hasProtectedPoint != b.hasProtectedPoint) d++;
    if(a.hasLiquiditySweep != b.hasLiquiditySweep) d++;
    if(a.signalTime != b.signalTime) d++;
    if(a.layerOrderBlock != b.layerOrderBlock) d++;
    if(a.layerFVG != b.layerFVG) d++;
    if(a.fvgClass != b.fvgClass) d++;
    if(a.fvgSize != b.fvgSize) d++;
    if(a.fvgStrength != b.fvgStrength) d++;
    if(a.fvgCreatedTime != b.fvgCreatedTime) d++;
    if(a.fvgFillTime != b.fvgFillTime) d++;
    return d;
}

void TestSwingGate_AdmittedRowByteIdentical(TestCounters &counters)
{
    //--- (c) gate 3b: the gate introduces exactly the 3 new telemetry
    //    columns; every other row field is byte-identical to the ungated
    //    row (all 75 shared columns).
    TelemetryRow off;
    TelemetryRow admit = off;
    SwingGateResult gate;
    gate.admitted = true;
    gate.gateDecision = "ADMIT";
    gate.qualifyingPivotId = 7;
    gate.thresholdKATR = 0.0030;
    gate.amplitude = 0.0070;
    SwingGateApplyToRow(admit, gate);

    TEST_INT_EQ(0, RowSharedFieldDiffs(off, admit),
                "admitted row byte-identical to ungated in all shared columns (gate 3b)");
    TEST_INT_EQ(7, admit.swingQualifyingId, "gate column: qualifying swing id");
    TEST_DBL_NEAR(0.0030, admit.swingAmplitude, 1e-12, "gate column: significance amplitude (k*ATR value)");
    TEST_STR_EQ("ADMIT", admit.gateDecision, "gate column: gate decision token");
    TEST_INT_EQ(0, off.swingQualifyingId, "OFF row: neutral qualifying id");
    TEST_DBL_EQ(0.0, off.swingAmplitude, "OFF row: neutral amplitude");
    TEST_STR_EQ("OFF", off.gateDecision, "OFF row: neutral decision token");

    //--- State preservation: gate evaluation never mutates the chain.
    const int n = 40;
    double open[], high[], low[], close[];
    datetime time[];
    SwingBarSpec ov[];
    ArrayResize(ov, 3);
    ov[0].index = 29; ov[0].high = 1.0005; ov[0].low = 0.9980; ov[0].close = 0.9985;
    ov[1].index = 30; ov[1].high = 1.0005; ov[1].low = 0.9970; ov[1].close = 0.9975;
    ov[2].index = 35; ov[2].high = 1.0040; ov[2].low = 1.0000; ov[2].close = 1.0020;
    BuildSwingFixture(open, high, low, close, time, n, 1.0, 0.0010, ov, 3);

    CSwingDetector detector;
    CStructuralPivotEngine pivots;
    detector.Init();
    pivots.Init();
    detector.Update(high, low, time, n);
    pivots.Update(&detector);
    int pivotCount = pivots.GetPivotCount();
    int swingHigh = detector.GetSwingHighCount();
    int swingLow  = detector.GetSwingLowCount();
    StructuralPivot snap[];
    ArrayResize(snap, pivotCount);
    for(int i = 0; i < pivotCount; i++)
        pivots.GetPivot(i, snap[i]);

    double sh[], sl[], sc[];
    ArrayResize(sh, n);
    ArrayResize(sl, n);
    ArrayResize(sc, n);
    for(int i = 0; i < n; i++)
    {
        sh[i] = high[n - 1 - i];
        sl[i] = low[n - 1 - i];
        sc[i] = close[n - 1 - i];
    }
    SwingGateResult out;
    SwingGateEvaluate(pivots, n - 1, n, sh, sl, sc, 1.5, out);
    TEST_TRUE(out.admitted, "fixture A admits at k=1.5");

    TEST_INT_EQ(pivotCount, pivots.GetPivotCount(), "gate does not add/remove pivots");
    TEST_INT_EQ(swingHigh, detector.GetSwingHighCount(), "gate does not add/remove high swings");
    TEST_INT_EQ(swingLow, detector.GetSwingLowCount(), "gate does not add/remove low swings");
    bool identical = true;
    for(int i = 0; i < pivotCount; i++)
    {
        StructuralPivot p;
        pivots.GetPivot(i, p);
        if(p.id != snap[i].id || p.price != snap[i].price || p.barIndex != snap[i].barIndex
                || p.isHigh != snap[i].isHigh || p.swingID != snap[i].swingID)
            identical = false;
    }
    TEST_TRUE(identical, "gate evaluation leaves the pivot chain byte-identical");
}

//─── (d) fingerprint invariance under the gate ──────────────────────

void TestSwingGate_FingerprintInvariant(TestCounters &counters)
{
    //--- (d) §11.1: the gate parameter stays OUTSIDE the configuration
    //    fingerprint — the row builder's canonical string is unchanged
    //    (the "FixedRR"/"1" hardcoded-token precedent, ED01-E). The tier
    //    lives in CConfig, which never reaches CConfigFingerprint.
    //    The runtime builds the canonical with spreadMode "tick" and the
    //    broker's SYMBOL_DIGITS (Portfolio/SymbolContext.mqh), so this
    //    unit test must mirror the runtime args, not the struct default
    //    ("quote"); all other fields equal the runtime values already.
    CalibrationConfig cfg;
    cfg.spreadMode = "tick";
    string symbol = "EURUSD";
    int tf = (int)PERIOD_H1;
    ulong base = CConfigFingerprint::Compute(cfg, symbol, tf, "FixedRR", "1");

    double tiers[];
    ArrayResize(tiers, 4);
    tiers[0] = 0.0;
    tiers[1] = 1.0;
    tiers[2] = 1.5;
    tiers[3] = 2.0;
    for(int i = 0; i < 4; i++)
    {
        CConfig c;
        c.SetSwingSignificanceTier(tiers[i]);
        ulong fp = CConfigFingerprint::Compute(cfg, symbol, tf, "FixedRR", "1");
        TEST_TRUE(fp == base,
                  StringFormat("tier %.1f: fingerprint invariant (gate outside the canonical string)", tiers[i]));
    }

    //--- B8 parity: the default-input fingerprint (the one serialized in
    //    every RL-HYP-01 arm) is the frozen EURUSD_H1 CONTROL fingerprint.
    TEST_TRUE(base == 3005138848403243456ULL,
              "default-input fingerprint = frozen EURUSD_H1 CONTROL fingerprint (3005138848403243456)");
}

//─── Entry point ────────────────────────────────────────────────────

TestCounters RunSwingSignificanceGateTests()
{
    TestCounters counters;
    SUITE_BEGIN("Swing-Significance Gate Tests (RL-HYP-01)");

    TestSwingGate_ConfigAndOffNeutral(counters);
    TestSwingGate_AmplitudeCriterionKATR(counters);
    TestSwingGate_AmplitudeBelowThresholdGatesOut(counters);
    TestSwingGate_NoPivotInWindowGatesOut(counters);
    TestSwingGate_TrailingWindowBounds(counters);
    TestSwingGate_FirstPivotNeverQualifies(counters);
    TestSwingGate_AdmittedRowByteIdentical(counters);
    TestSwingGate_FingerprintInvariant(counters);

    SUITE_END("Swing-Significance Gate Tests (RL-HYP-01)");
    return counters;
}
