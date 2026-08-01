#include "../TestAssert.mqh"
#include "../../Telemetry/ForwardOutcomeSimulator.mqh"

//--- Deterministic test policy: fixed SL/TP in absolute price terms.
class CTestOutcomePolicy : public IOutcomePolicy
{
private:
    double m_sl;
    double m_tp;
    double m_activation;
    double m_trail;
    string m_name;
    string m_version;

public:
    CTestOutcomePolicy(double sl, double tp, string name = "TestPolicy",
                       string version = "1", double activation = 0.0, double trail = 0.0)
        : m_sl(sl)
        , m_tp(tp)
        , m_activation(activation)
        , m_trail(trail)
        , m_name(name)
        , m_version(version)
    {}

    virtual string GetName() const    { return m_name; }
    virtual string GetVersion() const { return m_version; }

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
        levels.slPrice = entryPrice - m_sl;       // long convention; shorts flip below
        levels.tpPrice = entryPrice + m_tp;
        levels.useTrailing = (m_trail > 0.0);
        levels.trailActivationPrice = entryPrice + m_activation;
        levels.trailDistance = m_trail;
        return true;
    }
};

//--- Helpers to build as-series bar arrays.
void BuildBars(double &open[], double &high[], double &low[], double &close[],
               int n, double o, double h, double l, double c)
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

// ─── Fixed RR simulation ───────────────────────────────────────────

void TestSim_TPHit(TestCounters &counters)
{
    //--- Entry bar index 5 (older). Newer bars (0..4) rally into TP.
    int n = 10;
    double open[], high[], low[], close[];
    BuildBars(open, high, low, close, n, 100.0, 100.0, 100.0, 100.0);

    //--- Newest bars first: bar 4 = entry+1, which reaches 116 (TP = 115).
    open[4] = 100.0; high[4] = 116.0; low[4] = 99.0; close[4] = 115.0;

    CTestOutcomePolicy policy(10.0, 15.0);   // SL 90, TP 115, 1R = 10
    CForwardOutcomeSimulator sim;
    sim.SetPolicy(&policy);

    SimulatedOutcome out;
    bool ok = sim.Simulate("TEST", PERIOD_H1, CONFLUENCE_BULLISH, 5, open, high, low, close, out);

    TEST_TRUE(ok, "Simulate returns true");
    TEST_INT_EQ((int)TELEMETRY_OUTCOME_WIN, (int)out.outcome, "TP hit classifies as WIN");
    TEST_DBL_NEAR(1.5, out.rMultiple, 1e-9, "rMultiple = tp distance / risk (15/10)");
    TEST_INT_EQ(2, out.barsHeld, "Bars held = entry bar + next bar (entry-inclusive)");
    TEST_INT_EQ((int)EXIT_REASON_TP, (int)out.exitReason, "Exit reason TP");
}

void TestSim_SLHit(TestCounters &counters)
{
    int n = 10;
    double open[], high[], low[], close[];
    BuildBars(open, high, low, close, n, 100.0, 100.0, 100.0, 100.0);

    //--- Bar 4 drops through SL (90).
    open[4] = 100.0; high[4] = 101.0; low[4] = 89.0; close[4] = 90.0;

    CTestOutcomePolicy policy(10.0, 15.0);
    CForwardOutcomeSimulator sim;
    sim.SetPolicy(&policy);

    SimulatedOutcome out;
    bool ok = sim.Simulate("TEST", PERIOD_H1, CONFLUENCE_BULLISH, 5, open, high, low, close, out);

    TEST_TRUE(ok, "Simulate returns true");
    TEST_INT_EQ((int)TELEMETRY_OUTCOME_LOSS, (int)out.outcome, "SL hit classifies as LOSS");
    TEST_DBL_NEAR(-1.0, out.rMultiple, 1e-9, "rMultiple = -1 on SL");
}

void TestSim_TieBreakSLWins(TestCounters &counters)
{
    int n = 10;
    double open[], high[], low[], close[];
    BuildBars(open, high, low, close, n, 100.0, 100.0, 100.0, 100.0);

    //--- Same bar touches SL (90) and TP (115): conservative SL wins.
    open[4] = 100.0; high[4] = 116.0; low[4] = 89.0; close[4] = 100.0;

    CTestOutcomePolicy policy(10.0, 15.0);
    CForwardOutcomeSimulator sim;
    sim.SetPolicy(&policy);

    SimulatedOutcome out;
    sim.Simulate("TEST", PERIOD_H1, CONFLUENCE_BULLISH, 5, open, high, low, close, out);

    TEST_INT_EQ((int)TELEMETRY_OUTCOME_LOSS, (int)out.outcome, "Tie bar resolves to SL (conservative)");
    TEST_DBL_NEAR(-1.0, out.rMultiple, 1e-9, "Tie-break rMultiple = -1");
}

void TestSim_HorizonExit(TestCounters &counters)
{
    int n = 10;
    double open[], high[], low[], close[];
    BuildBars(open, high, low, close, n, 100.0, 102.0, 98.0, 101.0);

    //--- Nothing hits SL/TP in the window; exit at last scanned close.
    CTestOutcomePolicy policy(10.0, 15.0);
    CForwardOutcomeSimulator sim;
    sim.SetPolicy(&policy);
    sim.SetMaxHoldBars(3);

    SimulatedOutcome out;
    bool ok = sim.Simulate("TEST", PERIOD_H1, CONFLUENCE_BULLISH, 5, open, high, low, close, out);

    TEST_TRUE(ok, "Simulate returns true");
    TEST_INT_EQ((int)EXIT_REASON_HORIZON, (int)out.exitReason, "Horizon exit reason");
    TEST_INT_EQ(4, out.barsHeld, "Bars held = entry - last + 1 (5-2+1)");
}

void TestSim_TrailingRatchetsStop(TestCounters &counters)
{
    //--- Policy: SL 10, TP 100 (never hit), activation +15, trail 5.
    //    Price rallies to 122 (activation hit at >= 115), stop ratchets to 117.
    //    Then price dips to 116 (above 117? no — 116 < 117: stop touched -> exit).
    int n = 12;
    double open[], high[], low[], close[];
    BuildBars(open, high, low, close, n, 100.0, 100.0, 100.0, 100.0);

    open[4] = 100.0; high[4] = 122.0; low[4] = 100.0; close[4] = 121.0;  // activation hit
    open[3] = 121.0; high[3] = 122.0; low[3] = 116.0; close[3] = 116.5;  // dips through stop 117

    CTestOutcomePolicy policy(10.0, 100.0, "TrailingTest", "1", 15.0, 5.0);
    CForwardOutcomeSimulator sim;
    sim.SetPolicy(&policy);

    SimulatedOutcome out;
    bool ok = sim.Simulate("TEST", PERIOD_H1, CONFLUENCE_BULLISH, 5, open, high, low, close, out);

    TEST_TRUE(ok, "Simulate returns true");
    TEST_DBL_NEAR(1.7, out.rMultiple, 1e-9, "Trailing exit at 117: (117-100)/10 = 1.7R");
    TEST_INT_EQ((int)TELEMETRY_OUTCOME_WIN, (int)out.outcome, "Trailing exit above breakeven is a WIN");
}

void TestSim_TrailingBreakevenNotHit(TestCounters &counters)
{
    //--- Activation hit, stop ratchets to breakeven (100), but price never
    //    trades through the stop on subsequent bars — the trade must NOT
    //    close until the stop is actually touched.
    int n = 12;
    double open[], high[], low[], close[];
    BuildBars(open, high, low, close, n, 100.0, 102.0, 98.0, 101.0);

    //--- Bar 4: activation at 115 reached (high 122); trail 25 -> stop 97 (below entry).
    open[4] = 100.0; high[4] = 122.0; low[4] = 100.0; close[4] = 121.0;
    //--- Bar 3: high 123 -> stop ratchets to 98; low 100 (stop NOT touched).
    open[3] = 121.0; high[3] = 123.0; low[3] = 100.0; close[3] = 102.0;
    //--- Bar 2: high 124 -> stop ratchets to 99; low 101 (stop NOT touched).
    open[2] = 102.0; high[2] = 124.0; low[2] = 101.0; close[2] = 103.0;
    //--- Bar 1: high 125 -> stop ratchets to 100; low 102 (stop NOT touched).
    open[1] = 103.0; high[1] = 125.0; low[1] = 102.0; close[1] = 104.0;
    //--- Bar 0: low 99.5 -> stop (100) touched: exit at 100.
    open[0] = 104.0; high[0] = 105.0; low[0] = 99.5; close[0] = 100.0;

    CTestOutcomePolicy policy(10.0, 100.0, "TrailingTest2", "1", 15.0, 25.0);
    CForwardOutcomeSimulator sim;
    sim.SetPolicy(&policy);

    SimulatedOutcome out;
    bool ok = sim.Simulate("TEST", PERIOD_H1, CONFLUENCE_BULLISH, 5, open, high, low, close, out);

    TEST_TRUE(ok, "Simulate returns true");
    TEST_INT_EQ((int)TELEMETRY_OUTCOME_BREAKEVEN, (int)out.outcome,
                "Exit at breakeven classifies as BREAKEVEN");
    TEST_INT_EQ(6, out.barsHeld, "Trade stays open until the stop is actually touched");
}

// ─── Entry Point ───────────────────────────────────────────────────

TestCounters RunForwardOutcomeSimulatorTests()
{
    TestCounters counters;
    SUITE_BEGIN("Forward Outcome Simulator Tests");

    TestSim_TPHit(counters);
    TestSim_SLHit(counters);
    TestSim_TieBreakSLWins(counters);
    TestSim_HorizonExit(counters);
    TestSim_TrailingRatchetsStop(counters);
    TestSim_TrailingBreakevenNotHit(counters);

    SUITE_END("Forward Outcome Simulator Tests");
    return counters;
}
