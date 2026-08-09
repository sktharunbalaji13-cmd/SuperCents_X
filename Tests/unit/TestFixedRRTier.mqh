//+------------------------------------------------------------------+
//|                                      TestFixedRRTier.mqh         |
//|                                            Sprint 20 (ED01-E)     |
//+------------------------------------------------------------------+
//  ED01-E prerequisite (frozen docs/Sprint20_ED01E_Protocol.md):
//  the settle-time FixedRR policy must accept a TP R-multiple tier
//  without changing the SL/risk geometry or the fingerprint token.
//  These tests pin the tier contract:
//
//    - tiered resolution:   TP = entry +/- dir x riskDistance x tier
//      for every pre-registered tier {1.0, 1.5, 2.5, 3.0}, with SL and
//      risk distance identical to the 2.0R reference;
//    - default identity:    a default policy resolves byte-identical to
//      the legacy CFixedRRPolicy(1.0, 2.0) (B8 behavior, no re-freeze);
//    - SetTpR:              post-construction tier changes take effect
//      at resolve time; non-positive tiers are ignored;
//    - fingerprint:         GetFingerprintToken() stays "FixedRR@1"
//      for every tier (gate 3b: all arms fingerprint-identical);
//    - config:              CConfig default tier is 2.0R and the setter
//      round-trips every pre-registered tier.
//+------------------------------------------------------------------+
#include "../TestAssert.mqh"
#include "../../Telemetry/OutcomePolicies.mqh"
#include "../../Core/Config.mqh"

//--- Deterministic quiet bars: 1R = 0.001, SL = 0.999, TP(2R) = 1.002.
void BuildQuietBarsTier(double &open[], double &high[], double &low[], double &close[],
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

bool LevelsIdenticalTier(const PolicyExitLevels &a, const PolicyExitLevels &b)
{
    return a.valid == b.valid
        && a.slPrice == b.slPrice
        && a.tpPrice == b.tpPrice
        && a.riskDistance == b.riskDistance
        && a.useTrailing == b.useTrailing;
}

//--- Pre-registered tiers (protocol section 3: exactly these four
//    comparisons against the 2.0R CONTROL).
void TierList(double &tiers[])
{
    ArrayResize(tiers, 4);
    tiers[0] = 1.0;
    tiers[1] = 1.5;
    tiers[2] = 2.5;
    tiers[3] = 3.0;
}

//─── Tiered TP resolution ───────────────────────────────────────────

void TestFixedRrTier_TieredTpResolution(TestCounters &counters)
{
    double open[], high[], low[], close[];
    BuildQuietBarsTier(open, high, low, close, 40);

    double tiers[];
    TierList(tiers);

    for(int dirIdx = 0; dirIdx < 2; dirIdx++)
    {
        ConfluenceDirection dir = (dirIdx == 0) ? CONFLUENCE_BULLISH : CONFLUENCE_BEARISH;
        string dirTag = (dirIdx == 0) ? "bullish" : "bearish";
        int side = (dirIdx == 0) ? 1 : -1;

        CFixedRRPolicy reference(1.0, 2.0);
        PolicyExitLevels refLevels;
        TEST_TRUE(reference.ResolveExitLevels("TEST", PERIOD_H1, 1.0, dir, 20,
                                              open, high, low, close, refLevels),
                  "2.0R reference resolves (" + dirTag + ")");

        for(int i = 0; i < ArraySize(tiers); i++)
        {
            double tier = tiers[i];
            string tag = StringFormat("tier %.1fR (%s)", tier, dirTag);

            CFixedRRPolicy policy(1.0, tier);
            PolicyExitLevels levels;
            TEST_TRUE(policy.ResolveExitLevels("TEST", PERIOD_H1, 1.0, dir, 20,
                                               open, high, low, close, levels),
                      tag + " resolves");

            double expectedTp = 1.0 + side * refLevels.riskDistance * tier;
            TEST_DBL_EQ(expectedTp, levels.tpPrice, tag + " TP = entry +/- risk x tier");
            TEST_DBL_EQ(refLevels.slPrice, levels.slPrice, tag + " SL identical to 2.0R reference");
            TEST_DBL_EQ(refLevels.riskDistance, levels.riskDistance, tag + " risk distance identical to 2.0R reference");
        }
    }
}

//─── Default identity (B8) ──────────────────────────────────────────

void TestFixedRrTier_DefaultByteIdentical(TestCounters &counters)
{
    double open[], high[], low[], close[];
    BuildQuietBarsTier(open, high, low, close, 40);

    CFixedRRPolicy def;
    CFixedRRPolicy legacy(1.0, 2.0);

    for(int dirIdx = 0; dirIdx < 2; dirIdx++)
    {
        ConfluenceDirection dir = (dirIdx == 0) ? CONFLUENCE_BULLISH : CONFLUENCE_BEARISH;
        PolicyExitLevels a, b;
        TEST_TRUE(def.ResolveExitLevels("TEST", PERIOD_H1, 1.0, dir, 20,
                                        open, high, low, close, a), "default resolves");
        TEST_TRUE(legacy.ResolveExitLevels("TEST", PERIOD_H1, 1.0, dir, 20,
                                           open, high, low, close, b), "legacy resolves");
        TEST_TRUE(LevelsIdenticalTier(a, b),
                  "default policy byte-identical to CFixedRRPolicy(1.0, 2.0) — B8 baseline");
    }
}

//─── SetTpR ─────────────────────────────────────────────────────────

void TestFixedRrTier_SetTpR(TestCounters &counters)
{
    double open[], high[], low[], close[];
    BuildQuietBarsTier(open, high, low, close, 40);

    CFixedRRPolicy policy(1.0, 2.0);
    policy.SetTpR(2.5);

    CFixedRRPolicy direct(1.0, 2.5);
    PolicyExitLevels a, b;
    TEST_TRUE(policy.ResolveExitLevels("TEST", PERIOD_H1, 1.0, CONFLUENCE_BULLISH, 20,
                                       open, high, low, close, a), "tiered policy resolves");
    TEST_TRUE(direct.ResolveExitLevels("TEST", PERIOD_H1, 1.0, CONFLUENCE_BULLISH, 20,
                                       open, high, low, close, b), "direct 2.5R resolves");
    TEST_TRUE(LevelsIdenticalTier(a, b), "SetTpR(2.5) matches constructed 2.5R");

    policy.SetTpR(2.0);
    CFixedRRPolicy legacy(1.0, 2.0);
    PolicyExitLevels c, d;
    TEST_TRUE(policy.ResolveExitLevels("TEST", PERIOD_H1, 1.0, CONFLUENCE_BULLISH, 20,
                                       open, high, low, close, c), "reset tier resolves");
    TEST_TRUE(legacy.ResolveExitLevels("TEST", PERIOD_H1, 1.0, CONFLUENCE_BULLISH, 20,
                                       open, high, low, close, d), "legacy resolves");
    TEST_TRUE(LevelsIdenticalTier(c, d), "SetTpR(2.0) restores B8-identical levels");
}

void TestFixedRrTier_InvalidTierIgnored(TestCounters &counters)
{
    double open[], high[], low[], close[];
    BuildQuietBarsTier(open, high, low, close, 40);

    CFixedRRPolicy policy(1.0, 2.0);
    policy.SetTpR(0.0);
    policy.SetTpR(-1.0);

    CFixedRRPolicy legacy(1.0, 2.0);
    PolicyExitLevels a, b;
    TEST_TRUE(policy.ResolveExitLevels("TEST", PERIOD_H1, 1.0, CONFLUENCE_BULLISH, 20,
                                       open, high, low, close, a), "invalid-tier policy resolves");
    TEST_TRUE(legacy.ResolveExitLevels("TEST", PERIOD_H1, 1.0, CONFLUENCE_BULLISH, 20,
                                       open, high, low, close, b), "legacy resolves");
    TEST_TRUE(LevelsIdenticalTier(a, b), "non-positive tiers ignored (stays 2.0R)");
}

//─── Fingerprint invariance ─────────────────────────────────────────

void TestFixedRrTier_FingerprintInvariant(TestCounters &counters)
{
    double tiers[];
    TierList(tiers);

    for(int i = 0; i < ArraySize(tiers); i++)
    {
        CFixedRRPolicy policy(1.0, tiers[i]);
        string tag = StringFormat("tier %.1fR", tiers[i]);
        TEST_STR_EQ("FixedRR@1", policy.GetFingerprintToken(),
                    tag + " fingerprint token invariant (gate 3b: arms identical)");
    }

    CFixedRRPolicy def;
    TEST_STR_EQ("FixedRR@1", def.GetFingerprintToken(), "default fingerprint token");
}

//─── Config default and round-trip ──────────────────────────────────

void TestFixedRrTier_ConfigDefaultAndRoundTrip(TestCounters &counters)
{
    CConfig config;
    TEST_DBL_EQ(2.0, config.GetFixedRrTier(), "default FixedRR tier is 2.0R (B8)");

    config.SetFixedRrTier(1.0);
    TEST_DBL_EQ(1.0, config.GetFixedRrTier(), "tier 1.0 round-trips");

    config.SetFixedRrTier(1.5);
    TEST_DBL_EQ(1.5, config.GetFixedRrTier(), "tier 1.5 round-trips");

    config.SetFixedRrTier(2.5);
    TEST_DBL_EQ(2.5, config.GetFixedRrTier(), "tier 2.5 round-trips");

    config.SetFixedRrTier(3.0);
    TEST_DBL_EQ(3.0, config.GetFixedRrTier(), "tier 3.0 round-trips");

    config.SetFixedRrTier(2.0);
    TEST_DBL_EQ(2.0, config.GetFixedRrTier(), "tier 2.0 round-trips (control)");
}

//─── Entry point ────────────────────────────────────────────────────

TestCounters RunFixedRrTierTests()
{
    TestCounters counters;
    SUITE_BEGIN("Fixed-RR Tier Tests");

    TestFixedRrTier_TieredTpResolution(counters);
    TestFixedRrTier_DefaultByteIdentical(counters);
    TestFixedRrTier_SetTpR(counters);
    TestFixedRrTier_InvalidTierIgnored(counters);
    TestFixedRrTier_FingerprintInvariant(counters);
    TestFixedRrTier_ConfigDefaultAndRoundTrip(counters);

    SUITE_END("Fixed-RR Tier Tests");
    return counters;
}
