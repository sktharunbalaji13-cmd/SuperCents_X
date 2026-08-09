//+------------------------------------------------------------------+
//|                                      TestOutcomeTpPolicy.mqh      |
//|                                            Sprint 20 (ED01-D)     |
//+------------------------------------------------------------------+
//  ED01-D prerequisite (frozen docs/Sprint20_ED01D_PreRequisite.md):
//  the replay outcome simulator must be able to distinguish
//  TARGET_OPPOSING_LIQUIDITY from the legacy fixed-RR path. These tests
//  pin the COpposingLiquidityTPPolicy contract:
//
//    - opposing-pool fixture:  an ACTIVE opposite-class pool resolves and
//      the policy's TP becomes the pool price (DIFFERENT from FixedRR);
//    - fallback fixture:       when no opposing pool resolves (absent
//      source context, absent detector, no opposing pool), the policy
//      produces levels BYTE-IDENTICAL to CFixedRRPolicy;
//    - simulator-level:        the two arms produce different outcomes on
//      the same series when a pool exists, identical outcomes when not.
//+------------------------------------------------------------------+
#include "../TestAssert.mqh"
#include "../../Telemetry/OutcomePolicies.mqh"
#include "../../Telemetry/ForwardOutcomeSimulator.mqh"

//--- Deterministic quiet bars: 1R = 0.001, FixedRR SL = 0.999, TP = 1.002.
void BuildQuietBars(double &open[], double &high[], double &low[], double &close[],
                    int n, double base = 1.0, double range = 0.001)
{
    ArrayResize(open, n);
    ArrayResize(high, n);
    ArrayResize(low, n);
    ArrayResize(close, n);
    for(int i = 0; i < n; i++)
    {
        open[i] = base;
        high[i] = base + range / 2.0;
        low[i] = base - range / 2.0;
        close[i] = base;
    }
}

//--- Resolve levels with the legacy policy (reference for byte-identical).
bool ResolveFixedRR(PolicyExitLevels &levels, double entryPrice,
                    double &open[], double &high[], double &low[], double &close[],
                    int entryBarIndex)
{
    CFixedRRPolicy legacy;
    return legacy.ResolveExitLevels("TEST", PERIOD_H1, entryPrice,
                                    CONFLUENCE_BULLISH, entryBarIndex,
                                    open, high, low, close, levels);
}

bool LevelsIdentical(const PolicyExitLevels &a, const PolicyExitLevels &b)
{
    return a.valid == b.valid
        && a.slPrice == b.slPrice
        && a.tpPrice == b.tpPrice
        && a.riskDistance == b.riskDistance
        && a.useTrailing == b.useTrailing;
}

//─── Policy: opposing pool resolves ─────────────────────────────────

void TestTpPolicy_OpposingPool_Resolves(TestCounters &counters)
{
    //--- Bullish: source EQL swept; ACTIVE EQH pool at 1.05 above.
    CLiquidityDetector liq;
    TEST_TRUE(liq.Init(), "LiquidityDetector init (opposing resolves)");
    int sourceId = liq.CreateLevel(LIQUIDITY_EQL, 1.00, LIQUIDITY_ORIGIN_EQL, -1, -1);
    TEST_TRUE(liq.SweepLevel(sourceId, 1, D'2026.01.01 01:00'), "source (EQL) swept");
    const double TARGET_P = 1.05;
    int targetId = liq.CreateLevel(LIQUIDITY_EQH, TARGET_P, LIQUIDITY_ORIGIN_EQH, -1, -1);
    TEST_TRUE(sourceId >= 0 && targetId >= 0 && sourceId != targetId, "source and target ids distinct");

    double open[], high[], low[], close[];
    BuildQuietBars(open, high, low, close, 40);

    COpposingLiquidityTPPolicy policy(GetPointer(liq));
    policy.SetSourceLiquidity(true, sourceId);

    PolicyExitLevels levels;
    bool ok = policy.ResolveExitLevels("TEST", PERIOD_H1, 1.0, CONFLUENCE_BULLISH,
                                       20, open, high, low, close, levels);
    TEST_TRUE(ok, "levels resolved");
    TEST_TRUE(levels.valid, "levels valid");
    TEST_DBL_EQ(TARGET_P, levels.tpPrice, "TP = opposing ACTIVE buy-side pool (not FixedRR)");

    PolicyExitLevels legacy;
    ResolveFixedRR(legacy, 1.0, open, high, low, close, 20);
    TEST_TRUE(levels.tpPrice != legacy.tpPrice, "TP differs from the FixedRR arm (gate: opposing-pool fixture)");
    TEST_DBL_EQ(legacy.slPrice, levels.slPrice, "SL identical to FixedRR");
    TEST_DBL_EQ(legacy.riskDistance, levels.riskDistance, "risk distance identical to FixedRR");
}

void TestTpPolicy_Bearish_OpposingPool(TestCounters &counters)
{
    //--- Bearish: source EQH swept; ACTIVE EQL pool at 0.95 below.
    CLiquidityDetector liq;
    TEST_TRUE(liq.Init(), "LiquidityDetector init (bearish opposing)");
    int sourceId = liq.CreateLevel(LIQUIDITY_EQH, 1.00, LIQUIDITY_ORIGIN_EQH, -1, -1);
    TEST_TRUE(liq.SweepLevel(sourceId, 1, D'2026.01.01 01:00'), "source (EQH) swept");
    const double TARGET_P = 0.95;
    int targetId = liq.CreateLevel(LIQUIDITY_EQL, TARGET_P, LIQUIDITY_ORIGIN_EQL, -1, -1);
    TEST_TRUE(sourceId >= 0 && targetId >= 0 && sourceId != targetId, "source and target ids distinct");

    double open[], high[], low[], close[];
    BuildQuietBars(open, high, low, close, 40);

    COpposingLiquidityTPPolicy policy(GetPointer(liq));
    policy.SetSourceLiquidity(true, sourceId);

    PolicyExitLevels levels;
    bool ok = policy.ResolveExitLevels("TEST", PERIOD_H1, 1.0, CONFLUENCE_BEARISH,
                                       20, open, high, low, close, levels);
    TEST_TRUE(ok, "levels resolved (bearish)");
    TEST_DBL_EQ(TARGET_P, levels.tpPrice, "TP = opposing ACTIVE sell-side pool below");

    PolicyExitLevels legacy;
    CFixedRRPolicy lpol;
    lpol.ResolveExitLevels("TEST", PERIOD_H1, 1.0, CONFLUENCE_BEARISH,
                           20, open, high, low, close, legacy);
    TEST_TRUE(levels.tpPrice != legacy.tpPrice, "TP differs from the FixedRR arm (bearish)");
}

//─── Policy: fallback byte-identical to FixedRR ─────────────────────

void TestTpPolicy_NoOpposingPool_ByteIdentical(TestCounters &counters)
{
    //--- Only the swept source exists: no ACTIVE opposing pool.
    CLiquidityDetector liq;
    TEST_TRUE(liq.Init(), "LiquidityDetector init (no opposing pool)");
    int sourceId = liq.CreateLevel(LIQUIDITY_EQL, 1.00, LIQUIDITY_ORIGIN_EQL, -1, -1);
    TEST_TRUE(liq.SweepLevel(sourceId, 1, D'2026.01.01 01:00'), "source (EQL) swept");

    double open[], high[], low[], close[];
    BuildQuietBars(open, high, low, close, 40);

    COpposingLiquidityTPPolicy policy(GetPointer(liq));
    policy.SetSourceLiquidity(true, sourceId);

    PolicyExitLevels levels, legacy;
    bool ok = policy.ResolveExitLevels("TEST", PERIOD_H1, 1.0, CONFLUENCE_BULLISH,
                                       20, open, high, low, close, levels);
    ResolveFixedRR(legacy, 1.0, open, high, low, close, 20);
    TEST_TRUE(ok, "levels resolved");
    TEST_TRUE(LevelsIdentical(levels, legacy),
              "no opposing pool -> BYTE-IDENTICAL to FixedRR (gate: fallback fixture)");
}

void TestTpPolicy_NoLiquidityContext_ByteIdentical(TestCounters &counters)
{
    //--- Detector present with an opposing pool, but no source context:
    //    the row was not a liquidity decision -> FixedRR unchanged.
    CLiquidityDetector liq;
    TEST_TRUE(liq.Init(), "LiquidityDetector init (no source context)");
    int sourceId = liq.CreateLevel(LIQUIDITY_EQL, 1.00, LIQUIDITY_ORIGIN_EQL, -1, -1);
    int targetId = liq.CreateLevel(LIQUIDITY_EQH, 1.05, LIQUIDITY_ORIGIN_EQH, -1, -1);
    TEST_TRUE(sourceId >= 0 && targetId >= 0, "levels created");

    double open[], high[], low[], close[];
    BuildQuietBars(open, high, low, close, 40);

    COpposingLiquidityTPPolicy policy(GetPointer(liq));
    policy.SetSourceLiquidity(false, -1);

    PolicyExitLevels levels, legacy;
    bool ok = policy.ResolveExitLevels("TEST", PERIOD_H1, 1.0, CONFLUENCE_BULLISH,
                                       20, open, high, low, close, levels);
    ResolveFixedRR(legacy, 1.0, open, high, low, close, 20);
    TEST_TRUE(ok, "levels resolved (no context)");
    TEST_TRUE(LevelsIdentical(levels, legacy),
              "no source liquidity context -> BYTE-IDENTICAL to FixedRR");
}

void TestTpPolicy_NullDetector_ByteIdentical(TestCounters &counters)
{
    double open[], high[], low[], close[];
    BuildQuietBars(open, high, low, close, 40);

    COpposingLiquidityTPPolicy policy(NULL);
    policy.SetSourceLiquidity(true, 7);

    PolicyExitLevels levels, legacy;
    bool ok = policy.ResolveExitLevels("TEST", PERIOD_H1, 1.0, CONFLUENCE_BULLISH,
                                       20, open, high, low, close, levels);
    ResolveFixedRR(legacy, 1.0, open, high, low, close, 20);
    TEST_TRUE(ok, "levels resolved (null detector)");
    TEST_TRUE(LevelsIdentical(levels, legacy),
              "null detector -> BYTE-IDENTICAL to FixedRR");
}

void TestTpPolicy_SameLevelOnly_FixedRR(TestCounters &counters)
{
    //--- Source of the run-side class swept: no other pool -> the target
    //    must NOT be the source price; FixedRR stays.
    CLiquidityDetector liq;
    TEST_TRUE(liq.Init(), "LiquidityDetector init (same-level only)");
    int sourceId = liq.CreateLevel(LIQUIDITY_EQH, 1.00, LIQUIDITY_ORIGIN_EQH, -1, -1);
    TEST_TRUE(liq.SweepLevel(sourceId, 1, D'2026.01.01 01:00'), "source (EQH) swept");

    double open[], high[], low[], close[];
    BuildQuietBars(open, high, low, close, 40);

    COpposingLiquidityTPPolicy policy(GetPointer(liq));
    policy.SetSourceLiquidity(true, sourceId);

    PolicyExitLevels levels, legacy;
    bool ok = policy.ResolveExitLevels("TEST", PERIOD_H1, 1.0, CONFLUENCE_BULLISH,
                                       20, open, high, low, close, levels);
    ResolveFixedRR(legacy, 1.0, open, high, low, close, 20);
    TEST_TRUE(ok, "levels resolved (same-level only)");
    TEST_TRUE(LevelsIdentical(levels, legacy),
              "same-level-only -> FixedRR (never the source price)");
}

void TestTpPolicy_ConsumedSkipped_ActiveWins(TestCounters &counters)
{
    //--- Swept opposing pool + ACTIVE opposing pool: the ACTIVE pool wins.
    CLiquidityDetector liq;
    TEST_TRUE(liq.Init(), "LiquidityDetector init (consumed skipped)");
    int sourceId = liq.CreateLevel(LIQUIDITY_EQL, 1.00, LIQUIDITY_ORIGIN_EQL, -1, -1);
    TEST_TRUE(liq.SweepLevel(sourceId, 1, D'2026.01.01 01:00'), "source (EQL) swept");
    int sweptBuyId = liq.CreateLevel(LIQUIDITY_EQH, 1.08, LIQUIDITY_ORIGIN_EQH, -1, -1);
    TEST_TRUE(liq.SweepLevel(sweptBuyId, 2, D'2026.01.01 02:00'), "old EQH swept (consumed)");
    const double ACTIVE_P = 1.10;
    int activeBuyId = liq.CreateLevel(LIQUIDITY_EQH, ACTIVE_P, LIQUIDITY_ORIGIN_EQH, -1, -1);
    TEST_TRUE(sourceId >= 0 && sweptBuyId >= 0 && activeBuyId >= 0, "all levels created");

    double open[], high[], low[], close[];
    BuildQuietBars(open, high, low, close, 40);

    COpposingLiquidityTPPolicy policy(GetPointer(liq));
    policy.SetSourceLiquidity(true, sourceId);

    PolicyExitLevels levels;
    bool ok = policy.ResolveExitLevels("TEST", PERIOD_H1, 1.0, CONFLUENCE_BULLISH,
                                       20, open, high, low, close, levels);
    TEST_TRUE(ok, "levels resolved (consumed skipped)");
    TEST_DBL_EQ(ACTIVE_P, levels.tpPrice, "TP = ACTIVE pool; swept pool skipped (DD04 semantics)");
}

//─── Simulator level: the two arms distinguish / fall back ──────────

void TestTpPolicy_Simulator_DistinguishesArms(TestCounters &counters)
{
    //--- Gate: opposing-pool fixture at the SIMULATOR level. Same series:
    //    bar 16 rallies past FixedRR TP (1.002) but stays below the opposing
    //    pool (1.05); later the decline hits SL (0.999).
    //    Fixed arm: TP exit at bar 16 -> WIN +2R.
    //    Opposing arm: no TP reachable -> SL exit -> LOSS -1R.
    int n = 40;
    double open[], high[], low[], close[];
    BuildQuietBars(open, high, low, close, n);
    const int ENTRY = 20;
    //--- forward bars 19..17 flat
    //--- bar 16: high 1.0030 hits FixedRR TP 1.002; low 0.9996 above SL 0.999
    high[16] = 1.0030; low[16] = 0.9996;
    //--- bars 15..14 mild decline (above SL)
    high[15] = 1.0002; low[15] = 0.9993;
    high[14] = 1.0001; low[14] = 0.9993;
    //--- bar 13: low 0.9985 hits SL 0.999
    low[13] = 0.9985;

    CLiquidityDetector liq;
    TEST_TRUE(liq.Init(), "LiquidityDetector init (simulator arms)");
    int sourceId = liq.CreateLevel(LIQUIDITY_EQL, 1.00, LIQUIDITY_ORIGIN_EQL, -1, -1);
    TEST_TRUE(liq.SweepLevel(sourceId, 1, D'2026.01.01 01:00'), "source (EQL) swept");
    int targetId = liq.CreateLevel(LIQUIDITY_EQH, 1.05, LIQUIDITY_ORIGIN_EQH, -1, -1);
    TEST_TRUE(sourceId >= 0 && targetId >= 0, "levels created");

    CForwardOutcomeSimulator fixedSim;
    CFixedRRPolicy fixedPolicy;
    fixedSim.SetPolicy(&fixedPolicy);

    COpposingLiquidityTPPolicy opposingPolicy(GetPointer(liq));
    opposingPolicy.SetSourceLiquidity(true, sourceId);
    CForwardOutcomeSimulator opposingSim;
    opposingSim.SetPolicy(&opposingPolicy);

    SimulatedOutcome fixedOut, opposingOut;
    bool okF = fixedSim.Simulate("TEST", PERIOD_H1, CONFLUENCE_BULLISH, ENTRY,
                                 open, high, low, close, fixedOut);
    bool okO = opposingSim.Simulate("TEST", PERIOD_H1, CONFLUENCE_BULLISH, ENTRY,
                                    open, high, low, close, opposingOut);
    TEST_TRUE(okF && okO, "both arms simulate");

    TEST_INT_EQ((int)TELEMETRY_OUTCOME_WIN, (int)fixedOut.outcome, "FixedRR arm: WIN (TP)");
    TEST_INT_EQ((int)EXIT_REASON_TP, (int)fixedOut.exitReason, "FixedRR arm exits at TP");
    TEST_INT_EQ((int)TELEMETRY_OUTCOME_LOSS, (int)opposingOut.outcome,
                "Opposing arm: LOSS (SL) - DIFFERENT OUTCOME (gate: opposing-pool fixture)");
    TEST_INT_EQ((int)EXIT_REASON_SL, (int)opposingOut.exitReason, "Opposing arm exits at SL");
    TEST_DBL_NEAR(2.0, fixedOut.rMultiple, 1e-9, "FixedRR rMultiple = +2R");
    TEST_DBL_NEAR(-1.0, opposingOut.rMultiple, 1e-9, "Opposing rMultiple = -1R");
}

void TestTpPolicy_Simulator_FallbackIdentical(TestCounters &counters)
{
    //--- Gate: fallback fixture at the SIMULATOR level. No opposing pool
    //    (no source context): both arms must produce IDENTICAL outcomes.
    int n = 40;
    double open[], high[], low[], close[];
    BuildQuietBars(open, high, low, close, n);
    const int ENTRY = 20;
    high[16] = 1.0030; low[16] = 0.9996;
    high[15] = 1.0002; low[15] = 0.9993;
    high[14] = 1.0001; low[14] = 0.9993;
    low[13] = 0.9985;

    CForwardOutcomeSimulator fixedSim;
    CFixedRRPolicy fixedPolicy;
    fixedSim.SetPolicy(&fixedPolicy);

    COpposingLiquidityTPPolicy opposingPolicy(NULL);
    opposingPolicy.SetSourceLiquidity(false, -1);
    CForwardOutcomeSimulator opposingSim;
    opposingSim.SetPolicy(&opposingPolicy);

    SimulatedOutcome fixedOut, opposingOut;
    bool okF = fixedSim.Simulate("TEST", PERIOD_H1, CONFLUENCE_BULLISH, ENTRY,
                                 open, high, low, close, fixedOut);
    bool okO = opposingSim.Simulate("TEST", PERIOD_H1, CONFLUENCE_BULLISH, ENTRY,
                                    open, high, low, close, opposingOut);
    TEST_TRUE(okF && okO, "both arms simulate (fallback)");
    TEST_INT_EQ((int)fixedOut.outcome, (int)opposingOut.outcome,
                "same outcome class (gate: fallback fixture)");
    TEST_DBL_EQ(fixedOut.rMultiple, opposingOut.rMultiple, "identical rMultiple");
    TEST_DBL_EQ(fixedOut.exitPrice, opposingOut.exitPrice, "identical exit price");
    TEST_INT_EQ((int)fixedOut.exitReason, (int)opposingOut.exitReason, "identical exit reason");
    TEST_INT_EQ(fixedOut.barsHeld, opposingOut.barsHeld, "identical bars held");
}

//─── Identity / defaults ────────────────────────────────────────────

void TestTpPolicy_IdentityAndDefaultMode(TestCounters &counters)
{
    TEST_INT_EQ((int)OUTCOME_TP_FIXED_RR, 0, "default outcome TP mode is FixedRR (legacy behavior preserved)");
    TEST_TRUE((int)OUTCOME_TP_OPPOSING_LIQUIDITY == 1, "opposing-liquidity mode is selectable (1)");

    COpposingLiquidityTPPolicy policy(NULL);
    TEST_STR_EQ("OpposingLiquidityTP", policy.GetName(), "policy name");
    TEST_STR_EQ("1", policy.GetVersion(), "policy version");
    TEST_STR_EQ("OpposingLiquidityTP@1", policy.GetFingerprintToken(),
                "fingerprint token (arm selection recorded in the simulator manifest)");
}

//─── Entry point ────────────────────────────────────────────────────

TestCounters RunOutcomeTpPolicyTests()
{
    TestCounters counters;
    SUITE_BEGIN("Outcome TP Policy Tests");

    TestTpPolicy_OpposingPool_Resolves(counters);
    TestTpPolicy_Bearish_OpposingPool(counters);
    TestTpPolicy_NoOpposingPool_ByteIdentical(counters);
    TestTpPolicy_NoLiquidityContext_ByteIdentical(counters);
    TestTpPolicy_NullDetector_ByteIdentical(counters);
    TestTpPolicy_SameLevelOnly_FixedRR(counters);
    TestTpPolicy_ConsumedSkipped_ActiveWins(counters);
    TestTpPolicy_Simulator_DistinguishesArms(counters);
    TestTpPolicy_Simulator_FallbackIdentical(counters);
    TestTpPolicy_IdentityAndDefaultMode(counters);

    SUITE_END("Outcome TP Policy Tests");
    return counters;
}
