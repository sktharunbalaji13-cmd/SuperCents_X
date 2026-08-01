#include "../TestAssert.mqh"
#include "../../Providers/ProductionTradeStateProvider.mqh"
#include "../../Providers/ProductionRiskEvaluator.mqh"
#include "../../Entry/CShadowTradeStateProvider.mqh"
#include "../../Entry/CShadowRiskEvaluator.mqh"
#include "../../Entry/Validators/CooldownValidator.mqh"
#include "../../Entry/Validators/RiskValidator.mqh"

// ─── RiskEvaluation struct contract ────────────────────────────────

void TestRiskEvaluation_Defaults(TestCounters &counters)
{
    RiskEvaluation ev;
    TEST_FALSE(ev.allowed, "RiskEvaluation default: not allowed");
    TEST_DBL_EQ(0.0, ev.recommendedLots, "RiskEvaluation default: zero lots");
    TEST_STR_EQ("", ev.reason, "RiskEvaluation default: empty reason");
    TEST_DBL_EQ(0.0, ev.riskPercent, "RiskEvaluation default: riskPercent zero");
    TEST_DBL_EQ(0.0, ev.marginRequired, "RiskEvaluation default: margin zero");
    TEST_DBL_EQ(0.0, ev.freeMarginAfterTrade, "RiskEvaluation default: free margin zero");
    TEST_INT_EQ((int)RR_NONE, (int)ev.rejectionReason, "RiskEvaluation default: RR_NONE");
}

// ─── CShadowTradeStateProvider (permissive contract) ───────────────

void TestShadowTradeState_Contract(TestCounters &counters)
{
    CShadowTradeStateProvider p;
    TEST_INT_EQ(999999, p.GetBarsSinceLastTrade(), "ShadowTradeState: never-traded sentinel");
    TEST_FALSE(p.HasOpenPosition(), "ShadowTradeState: no open position");
    TEST_INT_EQ(0, (int)p.GetLastTradeTime(), "ShadowTradeState: no trade time");
    TEST_STR_EQ("ShadowTradeState", p.GetName(), "ShadowTradeState: name");
}

void TestShadowRisk_Contract(TestCounters &counters)
{
    CShadowRiskEvaluator r;
    RiskEvaluation ev = r.Evaluate(60.0);
    TEST_TRUE(ev.allowed, "ShadowRisk: always allowed");
    TEST_DBL_EQ(1.0, ev.recommendedLots, "ShadowRisk: fixed 1.0 lots");
    TEST_INT_EQ((int)RR_NONE, (int)ev.rejectionReason, "ShadowRisk: RR_NONE");
}

// ─── CProductionTradeStateProvider (deterministic, empty tester history)

void TestProdTradeState_EmptyHistory(TestCounters &counters)
{
    CProductionTradeStateProvider p("EURUSD", 42424242);
    TEST_INT_EQ(0, (int)p.GetLastTradeTime(), "ProductionTradeState: no deals -> 0");
    TEST_INT_EQ(INT_MAX, p.GetBarsSinceLastTrade(), "ProductionTradeState: no deals -> INT_MAX");
    TEST_FALSE(p.HasOpenPosition(), "ProductionTradeState: no positions");
    TEST_STR_EQ("ProductionTradeState", p.GetName(), "ProductionTradeState: name");
}

// ─── CProductionRiskEvaluator (deterministic vs tester account) ────

void TestProdRisk_FreshAccount(TestCounters &counters)
{
    CProductionRiskEvaluator r("EURUSD");
    RiskEvaluation ev = r.Evaluate(60.0);

    TEST_TRUE(ev.allowed, "ProductionRisk: 10000 GBP account can afford min lot");
    TEST_INT_EQ((int)RR_NONE, (int)ev.rejectionReason, "ProductionRisk: approved -> RR_NONE");

    double volumeMin = SymbolInfoDouble("EURUSD", SYMBOL_VOLUME_MIN);
    double volumeMax = SymbolInfoDouble("EURUSD", SYMBOL_VOLUME_MAX);

    TEST_TRUE(ev.recommendedLots > volumeMin, "ProductionRisk: maxLots above broker minimum");
    TEST_TRUE(ev.recommendedLots <= volumeMax + 0.01, "ProductionRisk: maxLots within broker limits");

    TEST_TRUE(ev.marginRequired > 0.0, "ProductionRisk: margin context populated");
    TEST_TRUE(ev.marginRequired * 1.25 <= AccountInfoDouble(ACCOUNT_MARGIN_FREE),
              "ProductionRisk: recommended size affordable within buffer");
    TEST_TRUE(ev.freeMarginAfterTrade >= 0.0, "ProductionRisk: free margin after trade sane");
    TEST_TRUE(ev.freeMarginAfterTrade < AccountInfoDouble(ACCOUNT_MARGIN_FREE),
              "ProductionRisk: free margin after trade < free margin");
}

void TestProdRisk_Determinism(TestCounters &counters)
{
    CProductionRiskEvaluator r("EURUSD");
    RiskEvaluation a = r.Evaluate(60.0);
    RiskEvaluation b = r.Evaluate(60.0);
    TEST_DBL_EQ(a.recommendedLots, b.recommendedLots, "ProductionRisk: deterministic maxLots");
    TEST_INT_EQ((int)a.rejectionReason, (int)b.rejectionReason, "ProductionRisk: deterministic reason");
    TEST_INT_EQ((int)a.allowed, (int)b.allowed, "ProductionRisk: deterministic allowed");
}

void TestProdRisk_MarginContextScale(TestCounters &counters)
{
    //--- The margin context must be internally consistent: required margin
    //    for the recommended lots must be affordable within the buffer.
    CProductionRiskEvaluator r("EURUSD");
    RiskEvaluation ev = r.Evaluate(60.0);
    if(ev.allowed && ev.marginRequired > 0.0)
    {
        double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
        TEST_TRUE(ev.marginRequired * 1.25 <= freeMargin,
                  "ProductionRisk: marginRequired*1.25 fits in free margin");
    }
    else
    {
        TEST_TRUE(true, "ProductionRisk: skipped (not allowed)");
    }
}

void TestProdRisk_NoOvershoot_LinearEstimate(TestCounters &counters)
{
    //--- Even when the linear margin estimate overshoots (margin floors,
    //    tiered leverage), the step-down must yield an affordable size.
    CProductionRiskEvaluator r("EURUSD");
    RiskEvaluation ev = r.Evaluate(60.0);
    TEST_TRUE(ev.allowed, "ProductionRisk: still allowed after step-down");
    TEST_TRUE(ev.marginRequired > 0.0, "ProductionRisk: step-down kept margin context");
    TEST_TRUE(ev.marginRequired * 1.25 <= AccountInfoDouble(ACCOUNT_MARGIN_FREE),
              "ProductionRisk: post-step-down size affordable");
    TEST_TRUE(ev.freeMarginAfterTrade >= 0.0, "ProductionRisk: post-step-down free margin non-negative");
}

// ─── Provider equivalence on a fresh account (Sprint 15.3) ─────────

void TestProviderEquivalence_FreshAccount(TestCounters &counters)
{
    //--- Fresh tester account: production cooldown must behave exactly like
    //    the shadow sentinel for the validator (never traded -> PASS).
    CProductionTradeStateProvider prodState("EURUSD", 42424242);
    CShadowTradeStateProvider shadowState;

    ConfluenceResult r;
    r.valid = true;
    r.totalConfidence = 80.0;
    r.direction = CONFLUENCE_BULLISH;
    r.componentCount = 3;

    EntryContext ctx;
    ctx.spread = 10.0;
    ctx.now = 0;
    ctx.currentBid = 1.1000;
    ctx.currentAsk = 1.1002;
    ctx.barsSinceSignal = 0;
    ctx.candidateEntryPrice = 1.1001;

    EntryFilterResult outProd;
    EntryFilterResult outShadow;

    CCooldownValidator vProd(&prodState);
    CCooldownValidator vShadow(&shadowState);
    vProd.Validate(r, ctx, outProd);
    vShadow.Validate(r, ctx, outShadow);

    TEST_INT_EQ((int)outProd.result, (int)outShadow.result,
                "Provider equivalence: cooldown outcome identical (PASS) on fresh account");
    TEST_INT_EQ(FILTER_PASS, outProd.result,
                "Provider equivalence: production cooldown PASS (never traded)");

    //--- Risk: production allows (affordable) — shadow allows with 1.0 lots.
    CProductionRiskEvaluator prodRisk("EURUSD");
    CShadowRiskEvaluator shadowRisk;
    EntryFilterResult outRiskProd;
    EntryFilterResult outRiskShadow;

    CRiskValidator vRiskProd(&prodRisk);
    CRiskValidator vRiskShadow(&shadowRisk);
    vRiskProd.Validate(r, ctx, outRiskProd);
    vRiskShadow.Validate(r, ctx, outRiskShadow);

    TEST_INT_EQ((int)outRiskProd.result, (int)outRiskShadow.result,
                "Provider equivalence: risk outcome identical (PASS) on fresh account");
    TEST_INT_EQ(FILTER_PASS, outRiskProd.result,
                "Provider equivalence: production risk PASS on fresh account");
}

// ─── Entry Point ───────────────────────────────────────────────────

TestCounters RunProductionProviderTests()
{
    TestCounters counters;
    SUITE_BEGIN("Production Provider Tests");

    TestRiskEvaluation_Defaults(counters);
    TestShadowTradeState_Contract(counters);
    TestShadowRisk_Contract(counters);
    TestProdTradeState_EmptyHistory(counters);
    TestProdRisk_FreshAccount(counters);
    TestProdRisk_Determinism(counters);
    TestProdRisk_MarginContextScale(counters);
    TestProdRisk_NoOvershoot_LinearEstimate(counters);
    TestProviderEquivalence_FreshAccount(counters);

    SUITE_END("Production Provider Tests");
    return counters;
}
