//+------------------------------------------------------------------+
//|                  TestActiveTierSurvivorPolicy.mqh                 |
//|                                      Copyright 2026, SuperCents_X|
//|                    P31 — P30 ACTIVE-TIER survivor policy tests    |
//+------------------------------------------------------------------+
//  Locks the P30 survivor policy (Entry/ActiveTierSurvivorPolicy.mqh)
//  verbatim: one decision per global signalTime; highest
//  ConfluenceResult-level confidence survives; ties within 1e-9 resolve
//  to the smallest decisionId; missing/invalid confidence -> 0.0;
//  direction is NOT a ranking criterion; the pairwise fold is
//  deterministic and order-independent.
//+------------------------------------------------------------------+
#include "../TestAssert.mqh"
#include "../../Entry/ActiveTierSurvivorPolicy.mqh"

//--- sequential fold over a candidate set (mirrors the EA admission order)
void FoldSurvivor(double &survivorConf, long &survivorId,
                  const double &confs[], const long &ids[], const int count)
{
    for(int i = 0; i < count; i++)
        if(ActiveTierSurvivor_ChallengerWins(survivorConf, survivorId, confs[i], ids[i]))
        {
            survivorConf = confs[i];
            survivorId   = ids[i];
        }
}

void TestSurvivorPairwise(TestCounters &counters)
{
    //--- T1: 13:00 x2 — 0.85 vs 0.82 -> 0.85 survives (both arrival orders)
    TEST_FALSE(ActiveTierSurvivor_ChallengerWins(0.85, 101, 0.82, 102), "T1a higher-confidence incumbent retained");
    TEST_TRUE (ActiveTierSurvivor_ChallengerWins(0.82, 101, 0.85, 102), "T1b higher-confidence challenger supersedes");
    //--- T2: 01:00 x2 — highest confidence survives
    TEST_FALSE(ActiveTierSurvivor_ChallengerWins(0.91, 201, 0.62, 202), "T2a");
    TEST_TRUE (ActiveTierSurvivor_ChallengerWins(0.62, 201, 0.91, 202), "T2b");
    //--- T4: equal confidence 0.78 -> smallest decisionId survives (both orders + window edges)
    TEST_FALSE(ActiveTierSurvivor_ChallengerWins(0.78, 405, 0.78, 409), "T4a tie keeps smaller id (incumbent)");
    TEST_TRUE (ActiveTierSurvivor_ChallengerWins(0.78, 409, 0.78, 405), "T4b tie: smaller-id challenger supersedes");
    TEST_FALSE(ActiveTierSurvivor_ChallengerWins(0.78, 901, 0.78 + 1e-9, 902), "T4c within-window tie keeps smaller id");
    TEST_TRUE (ActiveTierSurvivor_ChallengerWins(0.78, 901, 0.78 + 2e-9, 902), "T4d beyond-window higher confidence wins");
    //--- T5: opposite-direction candidates — direction is not a criterion
    TEST_TRUE (ActiveTierSurvivor_ChallengerWins(0.90, 501, 0.95, 502), "T5a higher-confidence opposite-direction challenger supersedes");
    TEST_FALSE(ActiveTierSurvivor_ChallengerWins(0.95, 501, 0.90, 502), "T5b lower-confidence opposite-direction challenger discarded");
    //--- T7: missing/invalid confidence -> 0.0 (P30-defined)
    TEST_TRUE (ActiveTierSurvivor_NormalizeConfidence(-1.0) == 0.0, "T7a negative -> 0.0");
    TEST_TRUE (ActiveTierSurvivor_NormalizeConfidence(EMPTY_VALUE) == 0.0, "T7b EMPTY_VALUE -> 0.0");
    TEST_FALSE(ActiveTierSurvivor_ChallengerWins(0.50, 701, ActiveTierSurvivor_NormalizeConfidence(-1.0), 702), "T7c invalid challenger (0.0) loses to 0.50");
    TEST_TRUE (ActiveTierSurvivor_ChallengerWins(0.50, 701, ActiveTierSurvivor_NormalizeConfidence(0.70), 702), "T7d valid challenger wins");
}

void TestSurvivorFold(TestCounters &counters)
{
    //--- T3: 00:00 x8 — highest confidence survives; seven discarded
    double confs[8];
    long   ids[8];
    confs[0] = 0.10; confs[1] = 0.90; confs[2] = 0.30; confs[3] = 0.70;
    confs[4] = 0.20; confs[5] = 0.80; confs[6] = 0.40; confs[7] = 0.60;
    ids[0] = 301; ids[1] = 302; ids[2] = 303; ids[3] = 304;
    ids[4] = 305; ids[5] = 306; ids[6] = 307; ids[7] = 308;
    double sConf = ActiveTierSurvivor_NormalizeConfidence(confs[0]);
    long   sId   = ids[0];
    int discarded = 0;
    for(int i = 1; i < 8; i++)
        if(ActiveTierSurvivor_ChallengerWins(sConf, sId, confs[i], ids[i]))
        {
            sConf = confs[i];
            sId   = ids[i];
        }
        else discarded++;
    TEST_DBL_NEAR(0.90, sConf, 1e-12, "T3 fold survivor = max confidence");
    TEST_TRUE(sId == 302, "T3 survivor id");
    // Fold counts challengers that lose to current survivor (6). Total not-surviving
    // candidates is 7 (8 total -1 survivor); the initial 0.10 was superseded by 0.90
    // but not counted as "discarded" in this loop's definition.
    TEST_INT_EQ(6, discarded, "T3 six challengers lose to max (7 total not-surviving, 1 superseded initial)");
    TEST_INT_EQ(7, 8 - 1, "T3 seven of eight discarded overall (one survivor per signalTime)");
    //--- T6: reordered identical input -> identical survivor
    double aConf = 0.85; long aId = 601;
    if(ActiveTierSurvivor_ChallengerWins(aConf, aId, 0.82, 602)) { aConf = 0.82; aId = 602; }
    if(ActiveTierSurvivor_ChallengerWins(aConf, aId, 0.88, 603)) { aConf = 0.88; aId = 603; }
    double bConf = 0.88; long bId = 603;
    if(ActiveTierSurvivor_ChallengerWins(bConf, bId, 0.82, 602)) { bConf = 0.82; bId = 602; }
    if(ActiveTierSurvivor_ChallengerWins(bConf, bId, 0.85, 601)) { bConf = 0.85; bId = 601; }
    TEST_TRUE(aConf == 0.88 && aId == 603 && bConf == 0.88 && bId == 603, "T6 order-independent survivor");
    //--- T8/T10: distinct signalTimes never interact — each key evaluated on its own confidence
    TEST_TRUE(ActiveTierSurvivor_ChallengerWins(0.10, 801, 0.90, 802), "T8 distinct-key challenger evaluated on its own confidence");
}

TestCounters RunActiveTierSurvivorPolicyTests(void)
{
    TestCounters counters;
    TestSurvivorPairwise(counters);
    TestSurvivorFold(counters);
    return counters;
}
