//+------------------------------------------------------------------+
//|                                      TestSwingGateWiring.mqh      |
//|                                            Sprint 22 (RL-HYP-01)  |
//+------------------------------------------------------------------+
//  B1/B2 clearance (docs/Sprint22_RL_HYP_01_Protocol.md §14/§15.3.2):
//  the SwingSignificanceTier input must travel
//
//      SuperCents_X.mq5 input -> CEngine -> CConfig -> CSymbolContext
//      -> SwingGateEvaluate at the runtime decision point.
//
//  These tests pin the plumbing at the unit level (the replay-level
//  proof is the TT01 active-tier run):
//
//    - engine plumbing:  CEngine default tier 0.0 (OFF, B8 behavior)
//      and SetSwingSignificanceTier round-trips through the config
//      (the EA input lands on the engine);
//    - context plumbing: CSymbolContext default tier 0.0 (OFF) and
//      the setter lands on the context that gates decisions;
//    - fingerprint:      the tier stays OUTSIDE the canonical
//      fingerprint (gate 3b: all arms fingerprint-identical).
//+------------------------------------------------------------------+
#include "../TestAssert.mqh"
#include "../../Core/Config.mqh"
#include "../../Core/Engine.mqh"
#include "../../Portfolio/SymbolContext.mqh"

//─── Engine plumbing: EA input -> engine -> config ──────────────────

void TestSwingGateWiring_EngineRoundTrip(TestCounters &counters)
{
    CEngine engine;

    TEST_DBL_EQ(0.0, engine.GetSwingSignificanceTier(),
                "engine default tier 0.0 (gate OFF, B8 behavior)");

    engine.SetSwingSignificanceTier(1.0);
    TEST_DBL_EQ(1.0, engine.GetSwingSignificanceTier(), "engine tier 1.0 round-trips");

    engine.SetSwingSignificanceTier(1.5);
    TEST_DBL_EQ(1.5, engine.GetSwingSignificanceTier(), "engine tier 1.5 round-trips");

    engine.SetSwingSignificanceTier(2.0);
    TEST_DBL_EQ(2.0, engine.GetSwingSignificanceTier(), "engine tier 2.0 round-trips");

    engine.SetSwingSignificanceTier(0.0);
    TEST_DBL_EQ(0.0, engine.GetSwingSignificanceTier(), "engine tier 0.0 restores OFF");
}

//─── Context plumbing: engine Init forward lands on the context ─────

void TestSwingGateWiring_ContextRoundTrip(TestCounters &counters)
{
    CSymbolContext ctx("TEST", 0, ENTRY_MODE_NEW);

    TEST_DBL_EQ(0.0, ctx.GetSwingSignificanceTier(),
                "context default tier 0.0 (gate OFF, B8 behavior)");

    ctx.SetSwingSignificanceTier(1.5);
    TEST_DBL_EQ(1.5, ctx.GetSwingSignificanceTier(), "context tier 1.5 round-trips");

    ctx.SetSwingSignificanceTier(0.0);
    TEST_DBL_EQ(0.0, ctx.GetSwingSignificanceTier(), "context tier 0.0 restores OFF");
}

//─── Fingerprint contract at the wiring level ───────────────────────

void TestSwingGateWiring_FingerprintInvariant(TestCounters &counters)
{
    //--- §11.1: the tier is an EXPERIMENT parameter, never part of the
    //    canonical fingerprint (the "FixedRR"/"1" hardcoded-token
    //    precedent, ED01-E). Mirrors the runtime args (spreadMode
    //    "tick", broker SYMBOL_DIGITS) exactly as SymbolContext.mqh does.
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
                  StringFormat("wiring tier %.1f: fingerprint invariant", tiers[i]));
    }
}

//─── Entry point ────────────────────────────────────────────────────

TestCounters RunSwingGateWiringTests()
{
    TestCounters counters;
    SUITE_BEGIN("Swing-Gate Wiring Tests (RL-HYP-01)");

    TestSwingGateWiring_EngineRoundTrip(counters);
    TestSwingGateWiring_ContextRoundTrip(counters);
    TestSwingGateWiring_FingerprintInvariant(counters);

    SUITE_END("Swing-Gate Wiring Tests (RL-HYP-01)");
    return counters;
}
