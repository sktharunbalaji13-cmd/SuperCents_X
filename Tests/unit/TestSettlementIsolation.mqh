//+------------------------------------------------------------------+
//|                                  TestSettlementIsolation.mqh      |
//|                              Sprint 22 (RL-HYP-01) Settlement     |
//|                                   Isolation Design A (TDD RED)    |
//+------------------------------------------------------------------+
//  TDD pins for the settlement-isolation defect class
//  (docs/Sprint22_RL_HYP_01_Settlement_Isolation_Design.md §7).
//
//  The defect: SettleDue() is called ONLY inside the gate-ADMIT branch
//  of CSymbolContext::Update (SymbolContext.mqh:975). A queued row whose
//  boundary bar is GATE-OUT is NOT settled on that bar; it defers to the
//  next ADMIT bar, by which time the boundary bar is CLOSED. The horizon
//  exit reads close[boundaryBar] (ForwardOutcomeSimulator.mqh:172), so
//  the closed-bar read differs from the forming-bar read -> the 58-row
//  divergence class (all exitReason=HORIZON, barsHeld=51).
//
//  Level split (what is and is not unit-pinnable):
//    - Unit-pinnable (THIS file, deterministic, no chart/tester data):
//        T1 read-state dependency: horizon exit CHANGES with the boundary
//           bar read state (forming vs closed) - the mechanism that makes
//           the defect observable at the telemetry level.
//        T2 trigger-exit invariance: TP/SL exits are READ-STATE-INVARIANT
//           - why every observed divergence was exitReason=4 (58/58) and
//           no TP/SL exit diverged.
//        T3 boundary-index pin: entry=50 with maxHold=50 settles at
//           minBar=0 (barsHeld=51, exitPrice=close[0]) - the exact
//           boundary-bar contract Design A restores on GATE-OUT bars.
//        T4 default-maxHold pin: m_maxHoldBars defaults to 50 (the
//           TELEMETRY_SETTLE_MAX_HOLD_BARS contract).
//    - Replay-pinnable (NOT unit-driveable: the pending queue and the
//      per-bar trigger live behind CSymbolContext private state driven by
//      live market data; no production seam exists by Design-A mandate):
//        §7 RED test 1 "settlement runs on a GATE-OUT bar",
//        §7 RED test 2 "admitted-row byte-identity across gate tiers",
//        §7 GREEN-guards 3-5 (no-candidate deferral, decision order,
//        GATE-OUT creates no row).
//      These are carried by the TT01 SETTLEMENT-ISOLATION gate (tiered
//      paired replay over the defect-firing 2026-04-05..07-05 EURUSD M15
//      window; admission-only invariance + horizon-row scheduling
//      independence + INTEGRITY control; Tools/TT01/TT01_Validate.ps1).
//+------------------------------------------------------------------+
#include "../TestAssert.mqh"
#include "../../Telemetry/ForwardOutcomeSimulator.mqh"

//--- Deterministic test policy: fixed SL/TP in absolute price terms.
class CTestSettleIsolationPolicy : public IOutcomePolicy
{
private:
    double m_sl;
    double m_tp;

public:
    CTestSettleIsolationPolicy(double sl, double tp)
        : m_sl(sl), m_tp(tp)
    {}

    virtual string GetName() const    { return "SettleIsolationPolicy"; }
    virtual string GetVersion() const { return "1"; }

    virtual bool ResolveExitLevels(const string symbol,
                                   ENUM_TIMEFRAMES timeframe,
                                   double entryPrice,
                                   ConfluenceDirection direction,
                                   int entryBarIndex,
                                   const double &open[],
                                   const double &high[],
                                   const double &low[],
                                   const double &close[],
                                   PolicyExitLevels &levels)
    {
        levels.valid = true;
        levels.riskDistance = 10.0;               // 1R = 10 price units
        levels.slPrice = entryPrice - m_sl;
        levels.tpPrice = entryPrice + m_tp;
        levels.useTrailing = false;
        levels.trailActivationPrice = 0.0;
        levels.trailDistance = 0.0;
        return true;
    }
};

//--- Helpers to build as-series bar arrays (newest bar first).
void BuildSettleIsolationBars(double &open[], double &high[], double &low[],
                              double &close[], int n, double o, double h,
                              double l, double c)
{
    ArrayResize(open, n);
    ArrayResize(high, n);
    ArrayResize(low, n);
    ArrayResize(close, n);
    for(int i = 0; i < n; i++)
    {
        open[i] = o;
        high[i] = h;
        low[i] = l;
        close[i] = c;
    }
}

// ─── T1: read-state dependency (the divergence mechanism) ──────────

void TestSettleIsolation_HorizonReadStateDependency(TestCounters &counters)
{
    //--- Entry at bar 50, maxHold 50 -> horizon boundary = minBar 0.
    //    Windows are IDENTICAL except the boundary bar (index 0) OHLC:
    //    forming read (partial high/close) vs closed read (final).
    //    Nothing touches SL (90) / TP (115): both exit at the horizon,
    //    so the ONLY difference is the boundary-bar read state.
    int n = 51;
    double open[], high[], low[], close[];

    CTestSettleIsolationPolicy policy(10.0, 15.0);
    CForwardOutcomeSimulator sim;
    sim.SetPolicy(&policy);
    sim.SetMaxHoldBars(50);

    //--- Forming boundary bar: high 103.5, close 103.5 (partial move).
    BuildSettleIsolationBars(open, high, low, close, n, 100.0, 102.0, 98.0, 100.0);
    high[0] = 103.5; close[0] = 103.5; low[0] = 99.5;

    SimulatedOutcome outForming;
    bool okF = sim.Simulate("TEST", PERIOD_H1, CONFLUENCE_BULLISH, 50,
                            open, high, low, close, outForming);

    //--- Closed boundary bar: high 105.5, close 105.5 (full candle).
    BuildSettleIsolationBars(open, high, low, close, n, 100.0, 102.0, 98.0, 100.0);
    high[0] = 105.5; close[0] = 105.5; low[0] = 99.5;

    SimulatedOutcome outClosed;
    bool okC = sim.Simulate("TEST", PERIOD_H1, CONFLUENCE_BULLISH, 50,
                            open, high, low, close, outClosed);

    TEST_TRUE(okF, "forming-read horizon simulate returns true");
    TEST_TRUE(okC, "closed-read horizon simulate returns true");
    TEST_INT_EQ((int)EXIT_REASON_HORIZON, (int)outForming.exitReason,
                "forming read exits at the horizon (exitReason=4)");
    TEST_INT_EQ((int)EXIT_REASON_HORIZON, (int)outClosed.exitReason,
                "closed read exits at the horizon (exitReason=4)");
    TEST_INT_EQ(51, outForming.barsHeld, "forming read barsHeld=51 (boundary = entry-50)");
    TEST_INT_EQ(51, outClosed.barsHeld, "closed read barsHeld=51 (boundary = entry-50)");
    TEST_DBL_NEAR(103.5, outForming.exitPrice, 1e-9,
                  "forming read horizon exit = boundary-bar partial close");
    TEST_DBL_NEAR(105.5, outClosed.exitPrice, 1e-9,
                  "closed read horizon exit = boundary-bar final close");
    TEST_TRUE(MathAbs(outForming.exitPrice - outClosed.exitPrice) > 0.0,
              "the same boundary bar read forming vs closed yields DIFFERENT "
              "horizon exits - the mechanism behind the 58-row divergence "
              "class (deferral -> closed read -> exit mismatch)");
}

// ─── T2: trigger-exit invariance (why only horizon rows diverged) ──

void TestSettleIsolation_TriggerExitReadStateInvariant(TestCounters &counters)
{
    //--- Same windows as T1, but the TP (115) is touched at bar 5 BEFORE
    //    the boundary bar in both reads. The boundary-bar read state is
    //    irrelevant: TP exit must be byte-identical across reads.
    int n = 51;
    double open[], high[], low[], close[];

    CTestSettleIsolationPolicy policy(10.0, 15.0);
    CForwardOutcomeSimulator sim;
    sim.SetPolicy(&policy);
    sim.SetMaxHoldBars(50);

    //--- Forming boundary bar (bar 0 partial), TP touch at bar 5.
    BuildSettleIsolationBars(open, high, low, close, n, 100.0, 102.0, 98.0, 100.0);
    high[5] = 116.0; close[5] = 115.0;
    high[0] = 103.5; close[0] = 103.5; low[0] = 99.5;

    SimulatedOutcome outForming;
    bool okF = sim.Simulate("TEST", PERIOD_H1, CONFLUENCE_BULLISH, 50,
                            open, high, low, close, outForming);

    //--- Closed boundary bar (bar 0 final), TP touch at bar 5.
    BuildSettleIsolationBars(open, high, low, close, n, 100.0, 102.0, 98.0, 100.0);
    high[5] = 116.0; close[5] = 115.0;
    high[0] = 105.5; close[0] = 105.5; low[0] = 99.5;

    SimulatedOutcome outClosed;
    bool okC = sim.Simulate("TEST", PERIOD_H1, CONFLUENCE_BULLISH, 50,
                            open, high, low, close, outClosed);

    TEST_TRUE(okF, "forming-read TP simulate returns true");
    TEST_TRUE(okC, "closed-read TP simulate returns true");
    TEST_INT_EQ((int)EXIT_REASON_TP, (int)outForming.exitReason,
                "forming read exits at TP (exitReason=0)");
    TEST_INT_EQ((int)EXIT_REASON_TP, (int)outClosed.exitReason,
                "closed read exits at TP (exitReason=0)");
    TEST_DBL_NEAR(outForming.exitPrice, outClosed.exitPrice, 1e-9,
                  "TP exit price identical across boundary-bar read states");
    TEST_DBL_NEAR(outForming.rMultiple, outClosed.rMultiple, 1e-9,
                  "TP rMultiple identical across boundary-bar read states");
    TEST_DBL_NEAR(1.5, outForming.rMultiple, 1e-9, "TP rMultiple = 15/10");
    TEST_INT_EQ(outForming.barsHeld, outClosed.barsHeld,
                "TP barsHeld identical across boundary-bar read states");
}

// ─── T3: boundary-index pin (the bar Design A settles on) ──────────

void TestSettleIsolation_HorizonBoundaryIndexPin(TestCounters &counters)
{
    //--- entry=50, maxHold=50 -> minBar=0: the horizon row ALWAYS settles
    //    on index 0, i.e. the CURRENT (forming) bar of the settle call.
    //    Design A guarantees this read happens on the boundary bar itself
    //    even when the gate marks that bar GATE-OUT.
    int n = 51;
    double open[], high[], low[], close[];
    BuildSettleIsolationBars(open, high, low, close, n, 100.0, 102.0, 98.0, 100.0);
    close[0] = 101.25; high[0] = 101.5; low[0] = 99.5;

    CTestSettleIsolationPolicy policy(10.0, 15.0);
    CForwardOutcomeSimulator sim;
    sim.SetPolicy(&policy);
    sim.SetMaxHoldBars(50);

    SimulatedOutcome out;
    bool ok = sim.Simulate("TEST", PERIOD_H1, CONFLUENCE_BULLISH, 50,
                           open, high, low, close, out);

    TEST_TRUE(ok, "boundary-index simulate returns true");
    TEST_INT_EQ((int)EXIT_REASON_HORIZON, (int)out.exitReason,
                "settles at the horizon (exitReason=4)");
    TEST_INT_EQ(51, out.barsHeld, "boundary = entry-50 -> barsHeld=51");
    TEST_DBL_NEAR(101.25, out.exitPrice, 1e-9,
                  "exitPrice = close[entry-50] = close[0] (the settle-bar read)");
    TEST_INT_EQ(50, sim.GetMaxHoldBars(), "maxHold contract = 50");
}

// ─── T4: default maxHold pin (TELEMETRY_SETTLE_MAX_HOLD_BARS) ──────

void TestSettleIsolation_DefaultMaxHoldPin(TestCounters &counters)
{
    CTestSettleIsolationPolicy policy(10.0, 15.0);
    CForwardOutcomeSimulator sim;
    sim.SetPolicy(&policy);

    TEST_INT_EQ(50, sim.GetMaxHoldBars(),
                "simulator defaults to maxHold=50 (TELEMETRY_SETTLE_MAX_HOLD_BARS)");
}

// ─── Entry point ───────────────────────────────────────────────────

TestCounters RunSettlementIsolationTests()
{
    TestCounters counters;
    SUITE_BEGIN("Settlement Isolation Tests (RL-HYP-01)");

    TestSettleIsolation_HorizonReadStateDependency(counters);
    TestSettleIsolation_TriggerExitReadStateInvariant(counters);
    TestSettleIsolation_HorizonBoundaryIndexPin(counters);
    TestSettleIsolation_DefaultMaxHoldPin(counters);

    SUITE_END("Settlement Isolation Tests (RL-HYP-01)");
    return counters;
}
