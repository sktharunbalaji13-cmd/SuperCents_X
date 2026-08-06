#include "../TestAssert.mqh"
#include "../utils/MockTradeStateProvider.mqh"
#include "../utils/MockRiskEvaluator.mqh"
#include "../../Entry/Validators/DirectionValidator.mqh"
#include "../../Entry/Validators/ConfluenceValidator.mqh"
#include "../../Entry/Validators/FreshnessValidator.mqh"
#include "../../Entry/Validators/SpreadValidator.mqh"
#include "../../Entry/Validators/SessionValidator.mqh"
#include "../../Entry/Validators/DistanceValidator.mqh"
#include "../../Entry/Validators/CooldownValidator.mqh"
#include "../../Entry/Validators/RiskValidator.mqh"
#include "../../Entry/Validators/ValidatorConfig.mqh"

datetime MakeTime(int hour)
{
    MqlDateTime dt;
    dt.year = 2025; dt.mon = 6; dt.day = 15;
    dt.hour = hour; dt.min = 0; dt.sec = 0;
    dt.day_of_week = 0; dt.day_of_year = 0;
    return StructToTime(dt);
}

ConfluenceResult MakeResult(double confidence, ConfluenceDirection dir, int compCount)
{
    ConfluenceResult r;
    r.valid = true;
    r.totalConfidence = confidence;
    r.direction = dir;
    r.componentCount = compCount;
    return r;
}

EntryContext MakeContext(double spread, datetime now, double bid, double ask, int barsSince, double candPrice)
{
    EntryContext ctx;
    ctx.spread = spread;
    ctx.now = now;
    ctx.currentBid = bid;
    ctx.currentAsk = ask;
    ctx.barsSinceSignal = barsSince;
    ctx.candidateEntryPrice = candPrice;
    return ctx;
}

// ─── DirectionValidator ────────────────────────────────────────────

void TestDirectionValidator_Pass(TestCounters &counters)
{
    CDirectionValidator v;
    ConfluenceResult r = MakeResult(80.0, CONFLUENCE_BULLISH, 3);
    EntryContext ctx = MakeContext(10.0, 0, 1.1000, 1.1002, 0, 1.1001);
    EntryFilterResult out;

    v.Validate(r, ctx, out);

    TEST_INT_EQ(FILTER_PASS, out.result, "DirectionValidator PASS bullish");
}

void TestDirectionValidator_PassBearish(TestCounters &counters)
{
    CDirectionValidator v;
    ConfluenceResult r = MakeResult(80.0, CONFLUENCE_BEARISH, 3);
    EntryContext ctx = MakeContext(10.0, 0, 1.1000, 1.1002, 0, 1.1001);
    EntryFilterResult out;

    v.Validate(r, ctx, out);

    TEST_INT_EQ(FILTER_PASS, out.result, "DirectionValidator PASS bearish");
}

void TestDirectionValidator_Fail(TestCounters &counters)
{
    CDirectionValidator v;
    ConfluenceResult r = MakeResult(0.0, CONFLUENCE_NONE, 0);
    EntryContext ctx = MakeContext(10.0, 0, 1.1000, 1.1002, 0, 1.1001);
    EntryFilterResult out;

    v.Validate(r, ctx, out);

    TEST_INT_EQ(FILTER_FAIL, out.result, "DirectionValidator FAIL none");
    TEST_INT_EQ(REASON_DIRECTION_INVALID, out.reason, "DirectionValidator reason");
}

// ─── ConfluenceValidator ───────────────────────────────────────────

void TestConfluenceValidator_Pass(TestCounters &counters)
{
    CConfluenceValidator v;
    ConfluenceResult r = MakeResult(80.0, CONFLUENCE_BULLISH, 3);
    EntryContext ctx = MakeContext(10.0, 0, 1.1000, 1.1002, 0, 1.1001);
    EntryFilterResult out;

    v.Validate(r, ctx, out);

    TEST_INT_EQ(FILTER_PASS, out.result, "ConfluenceValidator PASS (80.0)");
}

void TestConfluenceValidator_Warning(TestCounters &counters)
{
    CConfluenceValidator v;
    ConfluenceResult r = MakeResult(65.0, CONFLUENCE_BULLISH, 3);
    EntryContext ctx = MakeContext(10.0, 0, 1.1000, 1.1002, 0, 1.1001);
    EntryFilterResult out;

    v.Validate(r, ctx, out);

    TEST_INT_EQ(FILTER_WARNING, out.result, "ConfluenceValidator WARNING (65.0)");
}

void TestConfluenceValidator_Fail(TestCounters &counters)
{
    CConfluenceValidator v;
    ConfluenceResult r = MakeResult(30.0, CONFLUENCE_BULLISH, 3);
    EntryContext ctx = MakeContext(10.0, 0, 1.1000, 1.1002, 0, 1.1001);
    EntryFilterResult out;

    v.Validate(r, ctx, out);

    TEST_INT_EQ(FILTER_FAIL, out.result, "ConfluenceValidator FAIL (30.0)");
    TEST_INT_EQ(REASON_CONFIDENCE_LOW, out.reason, "ConfluenceValidator reason");
}

void TestConfluenceValidator_BoundaryFail(TestCounters &counters)
{
    CConfluenceValidator v;
    ConfluenceResult r = MakeResult(59.0, CONFLUENCE_BULLISH, 3);
    EntryContext ctx = MakeContext(10.0, 0, 1.1000, 1.1002, 0, 1.1001);
    EntryFilterResult out;

    v.Validate(r, ctx, out);

    TEST_INT_EQ(FILTER_FAIL, out.result, "ConfluenceValidator boundary just-below (59.0)");
}

void TestConfluenceValidator_BoundaryPass(TestCounters &counters)
{
    CConfluenceValidator v;
    ConfluenceResult r = MakeResult(60.0, CONFLUENCE_BULLISH, 3);
    EntryContext ctx = MakeContext(10.0, 0, 1.1000, 1.1002, 0, 1.1001);
    EntryFilterResult out;

    v.Validate(r, ctx, out);

    TEST_INT_EQ(FILTER_PASS, out.result, "ConfluenceValidator boundary at-min (60.0)");
}

// ─── DD05: per-family floors ───────────────────────────────────────

void TestConfluenceValidator_FamilyLiquidityFloor(TestCounters &counters)
{
    CConfluenceValidator v;
    EntryContext ctx = MakeContext(10.0, 0, 1.1000, 1.1002, 0, 1.1001);
    EntryFilterResult out;

    ConfluenceResult r55 = MakeResult(55.0, CONFLUENCE_BULLISH, 3);
    r55.winningRuleFamily = RULE_FAMILY_LIQUIDITY;
    v.Validate(r55, ctx, out);
    TEST_INT_EQ(FILTER_FAIL, out.result, "Liquidity floor FAIL (55.0 < 0.60)");

    ConfluenceResult r60 = MakeResult(60.0, CONFLUENCE_BULLISH, 3);
    r60.winningRuleFamily = RULE_FAMILY_LIQUIDITY;
    v.Validate(r60, ctx, out);
    TEST_INT_EQ(FILTER_PASS, out.result, "Liquidity floor PASS at (60.0)");

    ConfluenceResult r65 = MakeResult(65.0, CONFLUENCE_BULLISH, 3);
    r65.winningRuleFamily = RULE_FAMILY_LIQUIDITY;
    v.Validate(r65, ctx, out);
    TEST_INT_EQ(FILTER_WARNING, out.result, "Liquidity floor WARNING (65.0)");
}

void TestConfluenceValidator_FamilyFVGFloor(TestCounters &counters)
{
    CConfluenceValidator v;
    EntryContext ctx = MakeContext(10.0, 0, 1.1000, 1.1002, 0, 1.1001);
    EntryFilterResult out;

    ConfluenceResult r39 = MakeResult(39.0, CONFLUENCE_BULLISH, 3);
    r39.winningRuleFamily = RULE_FAMILY_FVG;
    v.Validate(r39, ctx, out);
    TEST_INT_EQ(FILTER_FAIL, out.result, "FVG floor FAIL (39.0 < 0.40)");

    ConfluenceResult r40 = MakeResult(40.0, CONFLUENCE_BULLISH, 3);
    r40.winningRuleFamily = RULE_FAMILY_FVG;
    v.Validate(r40, ctx, out);
    TEST_INT_EQ(FILTER_PASS, out.result, "FVG floor PASS at (40.0)");

    ConfluenceResult r43 = MakeResult(43.0, CONFLUENCE_BULLISH, 3);
    r43.winningRuleFamily = RULE_FAMILY_FVG;
    v.Validate(r43, ctx, out);
    TEST_INT_EQ(FILTER_WARNING, out.result, "FVG floor WARNING (43.0)");

    ConfluenceResult r55 = MakeResult(55.0, CONFLUENCE_BULLISH, 3);
    r55.winningRuleFamily = RULE_FAMILY_FVG;
    v.Validate(r55, ctx, out);
    TEST_INT_EQ(FILTER_PASS, out.result, "FVG PASS above global floor (55.0 >= 0.40)");
}

void TestConfluenceValidator_FamilyBOSFloor(TestCounters &counters)
{
    CConfluenceValidator v;
    EntryContext ctx = MakeContext(10.0, 0, 1.1000, 1.1002, 0, 1.1001);
    EntryFilterResult out;

    ConfluenceResult r34 = MakeResult(34.0, CONFLUENCE_BULLISH, 3);
    r34.winningRuleFamily = RULE_FAMILY_BOS;
    v.Validate(r34, ctx, out);
    TEST_INT_EQ(FILTER_FAIL, out.result, "BOS floor FAIL (34.0 < 0.35)");

    ConfluenceResult r35 = MakeResult(35.0, CONFLUENCE_BULLISH, 3);
    r35.winningRuleFamily = RULE_FAMILY_BOS;
    v.Validate(r35, ctx, out);
    TEST_INT_EQ(FILTER_PASS, out.result, "BOS floor PASS at (35.0)");

    ConfluenceResult r37 = MakeResult(37.0, CONFLUENCE_BULLISH, 3);
    r37.winningRuleFamily = RULE_FAMILY_BOS;
    v.Validate(r37, ctx, out);
    TEST_INT_EQ(FILTER_WARNING, out.result, "BOS floor WARNING (37.0)");
}

void TestConfluenceValidator_FamilyCHOCHFloor(TestCounters &counters)
{
    CConfluenceValidator v;
    EntryContext ctx = MakeContext(10.0, 0, 1.1000, 1.1002, 0, 1.1001);
    EntryFilterResult out;

    ConfluenceResult r34 = MakeResult(34.0, CONFLUENCE_BULLISH, 3);
    r34.winningRuleFamily = RULE_FAMILY_CHOCH;
    v.Validate(r34, ctx, out);
    TEST_INT_EQ(FILTER_FAIL, out.result, "CHOCH floor FAIL (34.0 < 0.35)");

    ConfluenceResult r35 = MakeResult(35.0, CONFLUENCE_BULLISH, 3);
    r35.winningRuleFamily = RULE_FAMILY_CHOCH;
    v.Validate(r35, ctx, out);
    TEST_INT_EQ(FILTER_PASS, out.result, "CHOCH floor PASS at (35.0)");
}

void TestConfluenceValidator_FamilyOrderBlockFloor(TestCounters &counters)
{
    CConfluenceValidator v;
    EntryContext ctx = MakeContext(10.0, 0, 1.1000, 1.1002, 0, 1.1001);
    EntryFilterResult out;

    ConfluenceResult r34 = MakeResult(34.0, CONFLUENCE_BULLISH, 3);
    r34.winningRuleFamily = RULE_FAMILY_ORDER_BLOCK;
    v.Validate(r34, ctx, out);
    TEST_INT_EQ(FILTER_FAIL, out.result, "ORDER_BLOCK floor FAIL (34.0 < 0.35)");

    ConfluenceResult r35 = MakeResult(35.0, CONFLUENCE_BULLISH, 3);
    r35.winningRuleFamily = RULE_FAMILY_ORDER_BLOCK;
    v.Validate(r35, ctx, out);
    TEST_INT_EQ(FILTER_PASS, out.result, "ORDER_BLOCK floor PASS at (35.0)");
}

void TestConfluenceValidator_UnknownFallbackGlobal(TestCounters &counters)
{
    CConfluenceValidator v;
    EntryContext ctx = MakeContext(10.0, 0, 1.1000, 1.1002, 0, 1.1001);
    EntryFilterResult out;

    ConfluenceResult r59 = MakeResult(59.0, CONFLUENCE_BULLISH, 3);
    r59.winningRuleFamily = RULE_FAMILY_UNKNOWN;
    v.Validate(r59, ctx, out);
    TEST_INT_EQ(FILTER_FAIL, out.result, "UNKNOWN family falls back to global floor (59.0 FAIL)");

    ConfluenceResult r60 = MakeResult(60.0, CONFLUENCE_BULLISH, 3);
    r60.winningRuleFamily = RULE_FAMILY_UNKNOWN;
    v.Validate(r60, ctx, out);
    TEST_INT_EQ(FILTER_PASS, out.result, "UNKNOWN family falls back to global floor (60.0 PASS)");
}

void TestConfluenceValidator_CustomFloorOverride(TestCounters &counters)
{
    ConfluenceConfig cfg;
    cfg.familyFloorFVG = 0.50;
    CConfluenceValidator v(cfg);
    EntryContext ctx = MakeContext(10.0, 0, 1.1000, 1.1002, 0, 1.1001);
    EntryFilterResult out;

    ConfluenceResult r49 = MakeResult(49.0, CONFLUENCE_BULLISH, 3);
    r49.winningRuleFamily = RULE_FAMILY_FVG;
    v.Validate(r49, ctx, out);
    TEST_INT_EQ(FILTER_FAIL, out.result, "custom FVG floor FAIL (49.0 < 0.50)");

    ConfluenceResult r50 = MakeResult(50.0, CONFLUENCE_BULLISH, 3);
    r50.winningRuleFamily = RULE_FAMILY_FVG;
    v.Validate(r50, ctx, out);
    TEST_INT_EQ(FILTER_PASS, out.result, "custom FVG floor PASS at (50.0)");
}

// ─── DD05: rule identity helpers ───────────────────────────────────

void TestRuleTypeToFamily_AllRules(TestCounters &counters)
{
    TEST_INT_EQ((int)RULE_FAMILY_BOS, (int)RuleTypeToFamily(RULE_BOS_OB_BULLISH), "BOS_OB_BULLISH -> BOS");
    TEST_INT_EQ((int)RULE_FAMILY_BOS, (int)RuleTypeToFamily(RULE_BOS_OB_BEARISH), "BOS_OB_BEARISH -> BOS");
    TEST_INT_EQ((int)RULE_FAMILY_FVG, (int)RuleTypeToFamily(RULE_OB_FVG_BULLISH), "OB_FVG_BULLISH -> FVG");
    TEST_INT_EQ((int)RULE_FAMILY_FVG, (int)RuleTypeToFamily(RULE_OB_FVG_BEARISH), "OB_FVG_BEARISH -> FVG");
    TEST_INT_EQ((int)RULE_FAMILY_LIQUIDITY, (int)RuleTypeToFamily(RULE_LIQUIDITY_BOS_BULLISH), "LIQUIDITY_BOS_BULLISH -> LIQUIDITY");
    TEST_INT_EQ((int)RULE_FAMILY_LIQUIDITY, (int)RuleTypeToFamily(RULE_LIQUIDITY_BOS_BEARISH), "LIQUIDITY_BOS_BEARISH -> LIQUIDITY");
    TEST_INT_EQ((int)RULE_FAMILY_CHOCH, (int)RuleTypeToFamily(RULE_CHOCH_OB_REVERSAL), "CHOCH_OB_REVERSAL -> CHOCH");
    TEST_INT_EQ((int)RULE_FAMILY_UNKNOWN, (int)RuleTypeToFamily(RULE_NONE), "RULE_NONE -> UNKNOWN");
}

void TestRuleTypeToName_AllRules(TestCounters &counters)
{
    TEST_STR_EQ("BOS_OB_BULLISH", RuleTypeToName(RULE_BOS_OB_BULLISH), "name BOS_OB_BULLISH");
    TEST_STR_EQ("BOS_OB_BEARISH", RuleTypeToName(RULE_BOS_OB_BEARISH), "name BOS_OB_BEARISH");
    TEST_STR_EQ("OB_FVG_BULLISH", RuleTypeToName(RULE_OB_FVG_BULLISH), "name OB_FVG_BULLISH");
    TEST_STR_EQ("OB_FVG_BEARISH", RuleTypeToName(RULE_OB_FVG_BEARISH), "name OB_FVG_BEARISH");
    TEST_STR_EQ("LIQUIDITY_BOS_BULLISH", RuleTypeToName(RULE_LIQUIDITY_BOS_BULLISH), "name LIQUIDITY_BOS_BULLISH");
    TEST_STR_EQ("LIQUIDITY_BOS_BEARISH", RuleTypeToName(RULE_LIQUIDITY_BOS_BEARISH), "name LIQUIDITY_BOS_BEARISH");
    TEST_STR_EQ("CHOCH_OB_REVERSAL", RuleTypeToName(RULE_CHOCH_OB_REVERSAL), "name CHOCH_OB_REVERSAL");
    TEST_STR_EQ("", RuleTypeToName(RULE_NONE), "RULE_NONE has no name");
}

// ─── FreshnessValidator ────────────────────────────────────────────

void TestFreshnessValidator_Pass(TestCounters &counters)
{
    CFreshnessValidator v;
    ConfluenceResult r = MakeResult(80.0, CONFLUENCE_BULLISH, 3);
    EntryContext ctx = MakeContext(10.0, 0, 1.1000, 1.1002, 2, 1.1001);
    EntryFilterResult out;

    v.Validate(r, ctx, out);

    TEST_INT_EQ(FILTER_PASS, out.result, "FreshnessValidator PASS (2 bars)");
}

void TestFreshnessValidator_Warning(TestCounters &counters)
{
    CFreshnessValidator v;
    ConfluenceResult r = MakeResult(80.0, CONFLUENCE_BULLISH, 3);
    EntryContext ctx = MakeContext(10.0, 0, 1.1000, 1.1002, 3, 1.1001);
    EntryFilterResult out;

    v.Validate(r, ctx, out);

    TEST_INT_EQ(FILTER_WARNING, out.result, "FreshnessValidator WARNING (3 bars)");
}

void TestFreshnessValidator_Fail(TestCounters &counters)
{
    CFreshnessValidator v;
    ConfluenceResult r = MakeResult(80.0, CONFLUENCE_BULLISH, 3);
    EntryContext ctx = MakeContext(10.0, 0, 1.1000, 1.1002, 4, 1.1001);
    EntryFilterResult out;

    v.Validate(r, ctx, out);

    TEST_INT_EQ(FILTER_FAIL, out.result, "FreshnessValidator FAIL (4 bars)");
    TEST_INT_EQ(REASON_SIGNAL_EXPIRED, out.reason, "FreshnessValidator reason");
}

void TestFreshnessValidator_BoundaryPass(TestCounters &counters)
{
    CFreshnessValidator v;
    ConfluenceResult r = MakeResult(80.0, CONFLUENCE_BULLISH, 3);
    EntryContext ctx = MakeContext(10.0, 0, 1.1000, 1.1002, 3, 1.1001);
    EntryFilterResult out;

    v.Validate(r, ctx, out);

    TEST_INT_EQ(FILTER_WARNING, out.result, "FreshnessValidator boundary at-max (3) is WARNING");
}

// ─── SpreadValidator ───────────────────────────────────────────────

void TestSpreadValidator_Pass(TestCounters &counters)
{
    CSpreadValidator v;
    ConfluenceResult r = MakeResult(80.0, CONFLUENCE_BULLISH, 3);
    EntryContext ctx = MakeContext(10.0, 0, 1.1000, 1.1002, 0, 1.1001);
    EntryFilterResult out;

    v.Validate(r, ctx, out);

    TEST_INT_EQ(FILTER_PASS, out.result, "SpreadValidator PASS (10 pips)");
}

void TestSpreadValidator_Warning(TestCounters &counters)
{
    CSpreadValidator v;
    ConfluenceResult r = MakeResult(80.0, CONFLUENCE_BULLISH, 3);
    EntryContext ctx = MakeContext(13.0, 0, 1.1000, 1.1002, 0, 1.1001);
    EntryFilterResult out;

    v.Validate(r, ctx, out);

    TEST_INT_EQ(FILTER_WARNING, out.result, "SpreadValidator WARNING (13 pips)");
}

void TestSpreadValidator_Fail(TestCounters &counters)
{
    CSpreadValidator v;
    ConfluenceResult r = MakeResult(80.0, CONFLUENCE_BULLISH, 3);
    EntryContext ctx = MakeContext(20.0, 0, 1.1000, 1.1002, 0, 1.1001);
    EntryFilterResult out;

    v.Validate(r, ctx, out);

    TEST_INT_EQ(FILTER_FAIL, out.result, "SpreadValidator FAIL (20 pips)");
    TEST_INT_EQ(REASON_SPREAD_TOO_HIGH, out.reason, "SpreadValidator reason");
}

void TestSpreadValidator_BoundaryPass(TestCounters &counters)
{
    CSpreadValidator v;
    ConfluenceResult r = MakeResult(80.0, CONFLUENCE_BULLISH, 3);
    EntryContext ctx = MakeContext(15.0, 0, 1.1000, 1.1002, 0, 1.1001);
    EntryFilterResult out;

    v.Validate(r, ctx, out);

    TEST_INT_EQ(FILTER_PASS, out.result, "SpreadValidator boundary at-max (15.0)");
}

void TestSpreadValidator_BoundaryFail(TestCounters &counters)
{
    CSpreadValidator v;
    ConfluenceResult r = MakeResult(80.0, CONFLUENCE_BULLISH, 3);
    EntryContext ctx = MakeContext(15.1, 0, 1.1000, 1.1002, 0, 1.1001);
    EntryFilterResult out;

    v.Validate(r, ctx, out);

    TEST_INT_EQ(FILTER_FAIL, out.result, "SpreadValidator boundary just-over (15.1)");
}

// ─── SessionValidator ──────────────────────────────────────────────

void TestSessionValidator_Pass(TestCounters &counters)
{
    SessionConfig cfg;
    cfg.Add(8, 16);
    CSessionValidator v(cfg);
    ConfluenceResult r = MakeResult(80.0, CONFLUENCE_BULLISH, 3);
    EntryContext ctx = MakeContext(10.0, MakeTime(10), 1.1000, 1.1002, 0, 1.1001);
    EntryFilterResult out;

    v.Validate(r, ctx, out);

    TEST_INT_EQ(FILTER_PASS, out.result, "SessionValidator PASS (hour 10)");
}

void TestSessionValidator_Warning(TestCounters &counters)
{
    SessionConfig cfg;
    cfg.Add(8, 16);
    CSessionValidator v(cfg);
    ConfluenceResult r = MakeResult(80.0, CONFLUENCE_BULLISH, 3);
    EntryContext ctx = MakeContext(10.0, MakeTime(15), 1.1000, 1.1002, 0, 1.1001);
    EntryFilterResult out;

    v.Validate(r, ctx, out);

    TEST_INT_EQ(FILTER_WARNING, out.result, "SessionValidator WARNING (hour 15 = last)");
}

void TestSessionValidator_Fail(TestCounters &counters)
{
    SessionConfig cfg;
    cfg.Add(8, 16);
    CSessionValidator v(cfg);
    ConfluenceResult r = MakeResult(80.0, CONFLUENCE_BULLISH, 3);
    EntryContext ctx = MakeContext(10.0, MakeTime(20), 1.1000, 1.1002, 0, 1.1001);
    EntryFilterResult out;

    v.Validate(r, ctx, out);

    TEST_INT_EQ(FILTER_FAIL, out.result, "SessionValidator FAIL (hour 20)");
    TEST_INT_EQ(REASON_SESSION_CLOSED, out.reason, "SessionValidator reason");
}

void TestSessionValidator_NoConfig(TestCounters &counters)
{
    CSessionValidator v;
    ConfluenceResult r = MakeResult(80.0, CONFLUENCE_BULLISH, 3);
    EntryContext ctx = MakeContext(10.0, MakeTime(20), 1.1000, 1.1002, 0, 1.1001);
    EntryFilterResult out;

    v.Validate(r, ctx, out);

    TEST_INT_EQ(FILTER_PASS, out.result, "SessionValidator PASS (no config)");
}

// ─── DistanceValidator ─────────────────────────────────────────────

void TestDistanceValidator_Pass(TestCounters &counters)
{
    CDistanceValidator v;
    ConfluenceResult r = MakeResult(80.0, CONFLUENCE_BULLISH, 3);
    EntryContext ctx = MakeContext(10.0, 0, 1.1000, 1.1002, 0, 1.1005);
    EntryFilterResult out;

    v.Validate(r, ctx, out);

    TEST_INT_EQ(FILTER_PASS, out.result, "DistanceValidator PASS (close)");
}

void TestDistanceValidator_Warning(TestCounters &counters)
{
    CDistanceValidator v;
    ConfluenceResult r = MakeResult(80.0, CONFLUENCE_BULLISH, 3);
    EntryContext ctx = MakeContext(10.0, 0, 1.1000, 1.1002, 0, 1.1040);
    EntryFilterResult out;

    v.Validate(r, ctx, out);
    // mid = (1.1000+1.1002)/2 = 1.1001, dist = |1.1001-1.1040| = 0.0039 > 0.00375

    TEST_INT_EQ(FILTER_WARNING, out.result, "DistanceValidator WARNING (0.0039)");
}

void TestDistanceValidator_Fail(TestCounters &counters)
{
    CDistanceValidator v;
    ConfluenceResult r = MakeResult(80.0, CONFLUENCE_BULLISH, 3);
    EntryContext ctx = MakeContext(10.0, 0, 1.1000, 1.1002, 0, 1.1060);
    EntryFilterResult out;

    v.Validate(r, ctx, out);
    // mid = (1.1000+1.1002)/2 = 1.1001, dist = |1.1001-1.1060| = 0.0059 > 0.0050

    TEST_INT_EQ(FILTER_FAIL, out.result, "DistanceValidator FAIL (0.0059)");
    TEST_INT_EQ(REASON_DISTANCE_TOO_LARGE, out.reason, "DistanceValidator reason");
}

void TestDistanceValidator_BoundaryWarning(TestCounters &counters)
{
    CDistanceValidator v;
    ConfluenceResult r = MakeResult(80.0, CONFLUENCE_BULLISH, 3);
    EntryContext ctx = MakeContext(10.0, 0, 1.1000, 1.1002, 0, 1.1048);
    EntryFilterResult out;

    v.Validate(r, ctx, out);
    // mid = 1.1001, dist = |1.1001-1.1048| = 0.0047 > 0.00375 → WARNING
    // also 0.0047 < 0.0050 → WARNING (not FAIL)

    TEST_INT_EQ(FILTER_WARNING, out.result, "DistanceValidator boundary below-max (0.0047)");
}

void TestDistanceValidator_BoundaryFail(TestCounters &counters)
{
    CDistanceValidator v;
    ConfluenceResult r = MakeResult(80.0, CONFLUENCE_BULLISH, 3);
    EntryContext ctx = MakeContext(10.0, 0, 1.1000, 1.1002, 0, 1.1060);
    EntryFilterResult out;

    v.Validate(r, ctx, out);

    TEST_INT_EQ(FILTER_FAIL, out.result, "DistanceValidator boundary just-over (0.0059)");
}

// ─── CooldownValidator ─────────────────────────────────────────────

void TestCooldownValidator_Pass(TestCounters &counters)
{
    CMockTradeStateProvider provider;
    provider.SetBarsSinceLastTrade(10);
    CCooldownValidator v(&provider);
    ConfluenceResult r = MakeResult(80.0, CONFLUENCE_BULLISH, 3);
    EntryContext ctx = MakeContext(10.0, 0, 1.1000, 1.1002, 0, 1.1001);
    EntryFilterResult out;

    v.Validate(r, ctx, out);

    TEST_INT_EQ(FILTER_PASS, out.result, "CooldownValidator PASS (10 bars)");
}

void TestCooldownValidator_Fail(TestCounters &counters)
{
    CMockTradeStateProvider provider;
    provider.SetBarsSinceLastTrade(2);
    CCooldownValidator v(&provider);
    ConfluenceResult r = MakeResult(80.0, CONFLUENCE_BULLISH, 3);
    EntryContext ctx = MakeContext(10.0, 0, 1.1000, 1.1002, 0, 1.1001);
    EntryFilterResult out;

    v.Validate(r, ctx, out);

    TEST_INT_EQ(FILTER_FAIL, out.result, "CooldownValidator FAIL (2 bars)");
    TEST_INT_EQ(REASON_COOLDOWN_ACTIVE, out.reason, "CooldownValidator reason");
}

void TestCooldownValidator_NullProvider(TestCounters &counters)
{
    CCooldownValidator v(NULL);
    ConfluenceResult r = MakeResult(80.0, CONFLUENCE_BULLISH, 3);
    EntryContext ctx = MakeContext(10.0, 0, 1.1000, 1.1002, 0, 1.1001);
    EntryFilterResult out;

    v.Validate(r, ctx, out);

    TEST_INT_EQ(FILTER_FAIL, out.result, "CooldownValidator FAIL (NULL provider)");
}

void TestCooldownValidator_BoundaryFail(TestCounters &counters)
{
    CMockTradeStateProvider provider;
    provider.SetBarsSinceLastTrade(4);
    CCooldownValidator v(&provider);
    ConfluenceResult r = MakeResult(80.0, CONFLUENCE_BULLISH, 3);
    EntryContext ctx = MakeContext(10.0, 0, 1.1000, 1.1002, 0, 1.1001);
    EntryFilterResult out;

    v.Validate(r, ctx, out);

    TEST_INT_EQ(FILTER_FAIL, out.result, "CooldownValidator boundary just-below (4 bars)");
}

void TestCooldownValidator_BoundaryPass(TestCounters &counters)
{
    CMockTradeStateProvider provider;
    provider.SetBarsSinceLastTrade(5);
    CCooldownValidator v(&provider);
    ConfluenceResult r = MakeResult(80.0, CONFLUENCE_BULLISH, 3);
    EntryContext ctx = MakeContext(10.0, 0, 1.1000, 1.1002, 0, 1.1001);
    EntryFilterResult out;

    v.Validate(r, ctx, out);

    TEST_INT_EQ(FILTER_PASS, out.result, "CooldownValidator boundary at-min (5 bars)");
}

// ─── RiskValidator ─────────────────────────────────────────────────

void TestRiskValidator_Pass(TestCounters &counters)
{
    CMockRiskEvaluator risk;
    risk.SetAllowed(true);
    risk.SetMaxLots(2.0);
    CRiskValidator v(&risk);
    ConfluenceResult r = MakeResult(80.0, CONFLUENCE_BULLISH, 3);
    EntryContext ctx = MakeContext(10.0, 0, 1.1000, 1.1002, 0, 1.1001);
    EntryFilterResult out;

    v.Validate(r, ctx, out);

    TEST_INT_EQ(FILTER_PASS, out.result, "RiskValidator PASS (approved)");
}

void TestRiskValidator_Fail(TestCounters &counters)
{
    CMockRiskEvaluator risk;
    risk.SetAllowed(false);
    risk.SetRejectionReason("Risk limit exceeded");
    CRiskValidator v(&risk);
    ConfluenceResult r = MakeResult(80.0, CONFLUENCE_BULLISH, 3);
    EntryContext ctx = MakeContext(10.0, 0, 1.1000, 1.1002, 0, 1.1001);
    EntryFilterResult out;

    v.Validate(r, ctx, out);

    TEST_INT_EQ(FILTER_FAIL, out.result, "RiskValidator FAIL (denied)");
    TEST_INT_EQ(REASON_RISK_REJECTED, out.reason, "RiskValidator reason");
}

void TestRiskValidator_NullEvaluator(TestCounters &counters)
{
    CRiskValidator v(NULL);
    ConfluenceResult r = MakeResult(80.0, CONFLUENCE_BULLISH, 3);
    EntryContext ctx = MakeContext(10.0, 0, 1.1000, 1.1002, 0, 1.1001);
    EntryFilterResult out;

    v.Validate(r, ctx, out);

    TEST_INT_EQ(FILTER_FAIL, out.result, "RiskValidator FAIL (NULL evaluator)");
}

void TestRiskValidator_StructFlow(TestCounters &counters)
{
    CMockRiskEvaluator risk;
    risk.SetAllowed(true);
    risk.SetMaxLots(0.42);
    CRiskValidator v(&risk);
    ConfluenceResult r = MakeResult(80.0, CONFLUENCE_BULLISH, 3);
    EntryContext ctx = MakeContext(10.0, 0, 1.1000, 1.1002, 0, 1.1001);
    EntryFilterResult out;

    v.Validate(r, ctx, out);

    TEST_INT_EQ(FILTER_PASS, out.result, "RiskValidator struct flow: approved");
    TEST_STR_EQ("Risk approved, max lots: 0.42", out.explanation, "RiskValidator struct flow: maxLots via RiskEvaluation");

    CMockRiskEvaluator riskDeny;
    riskDeny.SetAllowed(false);
    riskDeny.SetRejectionReason("margin exhausted");
    CRiskValidator v2(&riskDeny);
    EntryFilterResult out2;

    v2.Validate(r, ctx, out2);

    TEST_INT_EQ(FILTER_FAIL, out2.result, "RiskValidator struct flow: denied");
    TEST_STR_EQ("margin exhausted", out2.explanation, "RiskValidator struct flow: reason via RiskEvaluation");
}

// ─── No-Mutation ───────────────────────────────────────────────────

void TestValidatorNoMutation(TestCounters &counters)
{
    ConfluenceResult r = MakeResult(80.0, CONFLUENCE_BULLISH, 3);

    double snapConf = r.totalConfidence;
    ConfluenceDirection snapDir = r.direction;
    int snapComp = r.componentCount;

    EntryContext ctx = MakeContext(10.0, 0, 1.1000, 1.1002, 0, 1.1001);
    double snapSpread = ctx.spread;
    datetime snapNow = ctx.now;
    double snapBid = ctx.currentBid;
    double snapAsk = ctx.currentAsk;
    int snapBars = ctx.barsSinceSignal;
    double snapCand = ctx.candidateEntryPrice;

    CDirectionValidator dv;
    EntryFilterResult out1;
    dv.Validate(r, ctx, out1);

    TEST_DBL_EQ(snapConf, r.totalConfidence, "No-mutation: ConfluenceResult.totalConfidence");
    TEST_INT_EQ((int)snapDir, (int)r.direction, "No-mutation: ConfluenceResult.direction");
    TEST_INT_EQ(snapComp, r.componentCount, "No-mutation: ConfluenceResult.componentCount");
    TEST_DBL_EQ(snapSpread, ctx.spread, "No-mutation: EntryContext.spread");
    TEST_INT_EQ((int)snapNow, (int)ctx.now, "No-mutation: EntryContext.now");
    TEST_DBL_EQ(snapBid, ctx.currentBid, "No-mutation: EntryContext.currentBid");
    TEST_DBL_EQ(snapAsk, ctx.currentAsk, "No-mutation: EntryContext.currentAsk");
    TEST_INT_EQ(snapBars, ctx.barsSinceSignal, "No-mutation: EntryContext.barsSinceSignal");
    TEST_DBL_EQ(snapCand, ctx.candidateEntryPrice, "No-mutation: EntryContext.candidateEntryPrice");
}

// ─── Entry Point ───────────────────────────────────────────────────

TestCounters RunValidatorTests()
{
    TestCounters counters;
    SUITE_BEGIN("Validator Unit Tests");

    TestDirectionValidator_Pass(counters);
    TestDirectionValidator_PassBearish(counters);
    TestDirectionValidator_Fail(counters);

    TestConfluenceValidator_Pass(counters);
    TestConfluenceValidator_Warning(counters);
    TestConfluenceValidator_Fail(counters);
    TestConfluenceValidator_BoundaryFail(counters);
    TestConfluenceValidator_BoundaryPass(counters);

    TestConfluenceValidator_FamilyLiquidityFloor(counters);
    TestConfluenceValidator_FamilyFVGFloor(counters);
    TestConfluenceValidator_FamilyBOSFloor(counters);
    TestConfluenceValidator_FamilyCHOCHFloor(counters);
    TestConfluenceValidator_FamilyOrderBlockFloor(counters);
    TestConfluenceValidator_UnknownFallbackGlobal(counters);
    TestConfluenceValidator_CustomFloorOverride(counters);
    TestRuleTypeToFamily_AllRules(counters);
    TestRuleTypeToName_AllRules(counters);

    TestFreshnessValidator_Pass(counters);
    TestFreshnessValidator_Warning(counters);
    TestFreshnessValidator_Fail(counters);
    TestFreshnessValidator_BoundaryPass(counters);

    TestSpreadValidator_Pass(counters);
    TestSpreadValidator_Warning(counters);
    TestSpreadValidator_Fail(counters);
    TestSpreadValidator_BoundaryPass(counters);
    TestSpreadValidator_BoundaryFail(counters);

    TestSessionValidator_Pass(counters);
    TestSessionValidator_Warning(counters);
    TestSessionValidator_Fail(counters);
    TestSessionValidator_NoConfig(counters);

    TestDistanceValidator_Pass(counters);
    TestDistanceValidator_Warning(counters);
    TestDistanceValidator_Fail(counters);
    TestDistanceValidator_BoundaryWarning(counters);
    TestDistanceValidator_BoundaryFail(counters);

    TestCooldownValidator_Pass(counters);
    TestCooldownValidator_Fail(counters);
    TestCooldownValidator_NullProvider(counters);
    TestCooldownValidator_BoundaryFail(counters);
    TestCooldownValidator_BoundaryPass(counters);

    TestRiskValidator_Pass(counters);
    TestRiskValidator_Fail(counters);
    TestRiskValidator_NullEvaluator(counters);
    TestRiskValidator_StructFlow(counters);

    TestValidatorNoMutation(counters);

    SUITE_END("Validator Unit Tests");
    return counters;
}
