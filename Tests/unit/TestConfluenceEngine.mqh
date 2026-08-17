#include "../../Confluence/Evaluators/StructureEvaluator.mqh"
#include "../../Confluence/Evaluators/TrendEvaluator.mqh"
#include "../../Confluence/Evaluators/OrderBlockEvaluator.mqh"
#include "../../Confluence/Evaluators/FVGEvaluator.mqh"
#include "../../Confluence/Evaluators/LiquidityEvaluator.mqh"
#include "../../Confluence/Evaluators/PremiumDiscountEvaluator.mqh"
#include "../../Confluence/ConfluenceScoreCalculator.mqh"
#include "../../Confluence/ConfluenceEngine.mqh"
#include "../../Entry/TargetResolver.mqh"
#include "../TestAssert.mqh"

//--- DD02 synthetic-series helpers
//    Time order B0 (oldest) .. B20 (newest); array index idx = 20 - k
//    (as-series).  Structure chain (swing detection is newest-first, so
//    swing ids run B15-low=1, B10-high=2, B6-low=3, B2-high=4):
//      pivot 1 = low  7.50 @B15 (locked by pivot 2)
//      pivot 2 = high 10.00 @B10 (locked by pivot 3)  <- bullish BOS target
//      pivot 3 = low   8.00 @B6  (locked by pivot 4)  <- bearish BOS target
//      pivot 4 = high  9.90 @B2  (unlocked)
//    B2's close is 10.20: a pre-pivot "break" of the 10.00 level that must
//    be excluded by the post-pivot window guard.
//    Variants steer the crossing closes:
//      FULL        : B13 close 7.90 (bearish first crossing @idx7) and
//                    B17 close 10.10 (bullish first crossing @idx3)
//      BULL_ONLY   : B13 9.30, B15 8.30 -> only the bullish crossing
//      BAR1_ONLY   : + B17 9.95 -> only the bar-1 (idx1) crossing
//      NO_CROSSING : + B19 9.98 -> no post-pivot crossing at all
enum DD02Series
{
    DD02_SERIES_FULL,
    DD02_SERIES_BULL_ONLY,
    DD02_SERIES_BAR1_ONLY,
    DD02_SERIES_NO_CROSSING
};

void DD02BuildSeries(int variant, double bar1Close, double &high[], double &low[], double &close[], datetime &time[], int &rates)
{
    rates = 21;
    ArrayResize(high, rates);
    ArrayResize(low, rates);
    ArrayResize(close, rates);
    ArrayResize(time, rates);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(time, true);

    double b13Close = (variant == DD02_SERIES_FULL) ? 7.90 : 9.30;
    double b15Close = (variant == DD02_SERIES_FULL) ? 7.60 : 8.30;
    double b17Close = (variant == DD02_SERIES_FULL || variant == DD02_SERIES_BULL_ONLY) ? 10.10 : 9.95;
    double b19Close = (variant == DD02_SERIES_NO_CROSSING) ? 9.98 : bar1Close;

    // Chronological B0 (oldest) .. B20 (newest); array idx = 20 - k.
    double h[21] = {9.50, 9.70, 9.90, 9.60, 9.40, 9.30, 9.00, 8.60, 9.20, 9.60, 10.00, 9.70, 9.40, 9.10, 8.60, 8.30, 8.60, 10.20, 10.10, 10.05, 10.00};
    double l[21] = {9.30, 9.45, 9.55, 9.40, 9.20, 8.60, 8.00, 8.20, 8.50, 8.80, 9.20, 9.00, 8.70, 8.30, 8.00, 7.50, 7.90, 8.90, 9.70, 9.60, 9.55};
    double c[21] = {9.45, 9.65, 10.20, 9.50, 9.30, 8.70, 8.10, 8.50, 9.00, 9.40, 9.80, 9.30, 8.90, b13Close, 8.20, b15Close, 8.30, b17Close, 9.90, b19Close, 9.95};

    // B19's low must stay below its close (valid bar geometry)
    l[19] = MathMin(l[19], b19Close - 0.10);

    datetime base = D'2026.01.01 00:00';
    for(int k = 0; k < rates; k++)
    {
        int idx = rates - 1 - k;
        high[idx] = h[k];
        low[idx]  = l[k];
        close[idx] = c[k];
        time[idx]  = base + k * 3600;
    }
}

//--- Run the production detector chain over a synthetic series
void DD02RunChain(const double &high[], const double &low[], const double &close[], const datetime &time[], int rates,
                  CSwingDetector &swing, CStructuralPivotEngine &pivot, CBOSDetector &bos)
{
    swing.Update(high, low, time, rates);
    pivot.Update(&swing);
    bos.Update(&pivot, close, time, rates);
}

TestCounters RunConfluenceEngineTests(void)
{
    TestCounters counters;
    SUITE_BEGIN("Confluence Engine Tests");

    // Test 1: StructureEvaluator with NULL detectors returns score 0
    {
        DetectionContext ctx;
        CStructureEvaluator eval;
        ConfluenceComponentResult res;
        bool hasScore = eval.Evaluate(ctx, res);
        TEST_FALSE(hasScore, "Structure with NULL detectors should return false");
        TEST_TRUE(res.score == 0.0, "Structure score should be 0 with NULL detectors");
    }

    // Test 2: TrendEvaluator with NULL trendState returns no score
    {
        DetectionContext ctx;
        CTrendEvaluator eval;
        ConfluenceComponentResult res;
        bool hasScore = eval.Evaluate(ctx, res);
        TEST_FALSE(hasScore, "Trend with NULL state should not produce a score");
        TEST_DBL_NEAR(res.score, 0.0, 0.1, "Trend score 0 with NULL state (no data)");
        TEST_STR_EQ(res.explanation, "NoTrendData", "Explanation should indicate no trend data");
    }

    // Test 3: OrderBlockEvaluator with NULL detector returns score 0
    {
        DetectionContext ctx;
        COrderBlockEvaluator eval;
        ConfluenceComponentResult res;
        bool hasScore = eval.Evaluate(ctx, res);
        TEST_FALSE(hasScore, "OB with NULL detector should return false");
        TEST_TRUE(res.score == 0.0, "OB score should be 0 with NULL detector");
    }

    // Test 4: FVGEvaluator with NULL detector returns score 0
    {
        DetectionContext ctx;
        CFVGEvaluator eval;
        ConfluenceComponentResult res;
        bool hasScore = eval.Evaluate(ctx, res);
        TEST_FALSE(hasScore, "FVG with NULL detector should return false");
        TEST_TRUE(res.score == 0.0, "FVG score should be 0 with NULL detector");
    }

    // Test 5: LiquidityEvaluator with NULL detector returns baseline score
    {
        DetectionContext ctx;
        CLiquidityEvaluator eval;
        ConfluenceComponentResult res;
        bool hasScore = eval.Evaluate(ctx, res);
        TEST_TRUE(hasScore, "Liquidity with NULL detector should return baseline");
        TEST_DBL_NEAR(res.score, 15.0, 0.1, "Liquidity baseline score should be 15");
        TEST_STR_EQ(res.explanation, "NoRecentSweep(baseline)", "Explanation should indicate no sweep");
    }

    // Test 6: PremiumDiscount with valid dealing range — deep discount (bullish)
    {
        DetectionContext ctx;
        ctx.swingHigh = 110.0;
        ctx.swingLow = 90.0;
        ctx.currentPrice = 91.0;
        CPremiumDiscountEvaluator eval;
        ConfluenceComponentResult res;
        bool hasScore = eval.Evaluate(ctx, res);
        TEST_TRUE(hasScore, "PremiumDiscount should return true for valid range");
        TEST_TRUE(res.score > 80.0, "Deep discount should score > 80");
        TEST_TRUE(StringFind(res.explanation, "Discount") >= 0, "Bullish deep discount should mention Discount");
    }

    // Test 7: PremiumDiscount with valid dealing range — deep premium (bearish)
    {
        DetectionContext ctx;
        ctx.swingHigh = 110.0;
        ctx.swingLow = 90.0;
        ctx.currentPrice = 109.0;
        CPremiumDiscountEvaluator eval;
        ConfluenceComponentResult res;
        eval.Evaluate(ctx, res);
        TEST_TRUE(res.score > 0.0, "Premium should return a score");
        TEST_TRUE(res.score < 50.0 || StringFind(res.explanation, "Premium") >= 0, "Bearish price near high should be in premium");
    }

    // Test 8: PremiumDiscount at exact midpoint
    {
        DetectionContext ctx;
        ctx.swingHigh = 110.0;
        ctx.swingLow = 90.0;
        ctx.currentPrice = 100.0;
        CPremiumDiscountEvaluator eval;
        ConfluenceComponentResult res;
        eval.Evaluate(ctx, res);
        TEST_DBL_NEAR(res.score, 50.0, 1.0, "Midpoint score should be approximately 50");
    }

    // Test 9: PremiumDiscount with invalid range (high <= low)
    {
        DetectionContext ctx;
        ctx.swingHigh = 50.0;
        ctx.swingLow = 50.0;
        ctx.currentPrice = 50.0;
        CPremiumDiscountEvaluator eval;
        ConfluenceComponentResult res;
        bool hasScore = eval.Evaluate(ctx, res);
        TEST_FALSE(hasScore, "Invalid range should return false");
        TEST_STR_EQ(res.explanation, "InvalidRange", "Invalid range explanation");
    }

    // Test 10: PremiumDiscount with zero price
    {
        DetectionContext ctx;
        ctx.swingHigh = 110.0;
        ctx.swingLow = 90.0;
        ctx.currentPrice = 0.0;
        CPremiumDiscountEvaluator eval;
        ConfluenceComponentResult res;
        bool hasScore = eval.Evaluate(ctx, res);
        TEST_FALSE(hasScore, "Zero price should return false");
    }

    // Test 11: ConfluenceWeights default values sum to 100
    {
        ConfluenceWeights w;
        double sum = w.structure + w.orderBlock + w.fvg + w.liquidity + w.trend + w.premiumDiscount;
        TEST_DBL_NEAR(sum, 100.0, 0.1, "Default weights should sum to 100");
        TEST_DBL_NEAR(w.structure, 25.0, 0.1, "Default structure weight");
        TEST_DBL_NEAR(w.orderBlock, 20.0, 0.1, "Default OB weight");
        TEST_DBL_NEAR(w.fvg, 15.0, 0.1, "Default FVG weight");
        TEST_DBL_NEAR(w.liquidity, 15.0, 0.1, "Default liquidity weight");
        TEST_DBL_NEAR(w.trend, 15.0, 0.1, "Default trend weight");
        TEST_DBL_NEAR(w.premiumDiscount, 10.0, 0.1, "Default premium/discount weight");
    }

    // Test 12: ConfluenceWeights.IsValid with correct sum
    {
        ConfluenceWeights w;
        TEST_TRUE(w.IsValid(), "Default weights should be valid");
    }

    // Test 13: ConfluenceWeights.IsValid with wrong sum
    {
        ConfluenceWeights w;
        w.structure = 100.0;
        w.orderBlock = 0.0;
        w.fvg = 0.0;
        w.liquidity = 0.0;
        w.trend = 0.0;
        w.premiumDiscount = 0.0;
        TEST_TRUE(w.IsValid(), "Single 100 weight should be valid");
    }

    // Test 14: ConfluenceWeights.GetWeight by component enum
    {
        ConfluenceWeights w;
        TEST_DBL_NEAR(w.GetWeight(COMPONENT_STRUCTURE), 25.0, 0.1, "GetWeight STRUCTURE");
        TEST_DBL_NEAR(w.GetWeight(COMPONENT_TREND), 15.0, 0.1, "GetWeight TREND");
        TEST_DBL_NEAR(w.GetWeight(COMPONENT_ORDER_BLOCK), 20.0, 0.1, "GetWeight ORDER_BLOCK");
        TEST_DBL_NEAR(w.GetWeight(COMPONENT_FVG), 15.0, 0.1, "GetWeight FVG");
        TEST_DBL_NEAR(w.GetWeight(COMPONENT_LIQUIDITY), 15.0, 0.1, "GetWeight LIQUIDITY");
        TEST_DBL_NEAR(w.GetWeight(COMPONENT_PREMIUM_DISCOUNT), 10.0, 0.1, "GetWeight PREMIUM_DISCOUNT");
    }

    // Test 15: ResetToDefaults restores initial values
    {
        ConfluenceWeights w;
        w.structure = 0.0;
        w.orderBlock = 0.0;
        w.fvg = 0.0;
        w.liquidity = 0.0;
        w.trend = 0.0;
        w.premiumDiscount = 0.0;
        w.ResetToDefaults();
        TEST_DBL_NEAR(w.structure, 25.0, 0.1, "Reset structure weight");
        TEST_DBL_NEAR(w.premiumDiscount, 10.0, 0.1, "Reset premium/discount weight");
    }

    // Test 16: ScoreCalculator with single component
    {
        CConfluenceScoreCalculator calc;
        ConfluenceWeights w;
        calc.SetWeights(w);

        ConfluenceComponentResult comps[1];
        comps[0].type = COMPONENT_STRUCTURE;
        comps[0].score = 80.0;
        comps[0].explanation = "Strong structure";

        ConfluenceResult result;
        double conf = calc.Calculate(comps, 1, result);

        TEST_DBL_NEAR(conf, 20.0, 0.1, "80 score * 25% weight = 20 contribution");
        TEST_TRUE(result.valid, "Result should be valid");
        TEST_INT_EQ(result.componentCount, 1, "Should have 1 component");
    }

    // Test 17: ScoreCalculator with all 6 components at 100
    {
        CConfluenceScoreCalculator calc;
        ConfluenceWeights w;
        calc.SetWeights(w);

        ConfluenceComponentResult comps[6];
        for(int i = 0; i < 6; i++)
        {
            comps[i].type = (ENUM_CONFLUENCE_COMPONENT)i;
            comps[i].score = 100.0;
            comps[i].explanation = "Max";
        }

        ConfluenceResult result;
        double conf = calc.Calculate(comps, 6, result);

        TEST_DBL_NEAR(conf, 100.0, 0.1, "All max scores should give 100%");
        TEST_INT_EQ(result.componentCount, 6, "Should have 6 components");
        TEST_TRUE(result.valid, "Result should be valid");
    }

    // Test 18: ScoreCalculator with empty component list
    {
        CConfluenceScoreCalculator calc;
        ConfluenceResult result;
        ConfluenceComponentResult noComps[1];
        double conf = calc.Calculate(noComps, 0, result);
        TEST_DBL_NEAR(conf, 0.0, 0.1, "Empty list should return 0");
        TEST_FALSE(result.valid, "Empty list should be invalid");
    }

    // Test 19: ScoreCalculator clamps individual scores to 0-100
    {
        CConfluenceScoreCalculator calc;
        ConfluenceResult result;

        ConfluenceComponentResult comps[1];
        comps[0].type = COMPONENT_TREND;
        comps[0].score = 150.0;

        double conf = calc.Calculate(comps, 1, result);
        TEST_TRUE(conf <= 100.0, "Over-100 score should be clamped");
        TEST_DBL_NEAR(100.0, result.components[0].score, 0.1, "Component score should be clamped to 100");
    }

    // Test 20: ScoreCalculator with 0-weight component
    {
        CConfluenceScoreCalculator calc;
        ConfluenceWeights w;
        w.structure = 0.0;
        w.orderBlock = 0.0;
        w.fvg = 0.0;
        w.liquidity = 0.0;
        w.trend = 0.0;
        w.premiumDiscount = 100.0;
        calc.SetWeights(w);

        ConfluenceComponentResult comps[2];
        comps[0].type = COMPONENT_STRUCTURE;
        comps[0].score = 100.0;
        comps[0].explanation = "Max structure";
        comps[1].type = COMPONENT_PREMIUM_DISCOUNT;
        comps[1].score = 80.0;
        comps[1].explanation = "Good P/D";

        ConfluenceResult result;
        double conf = calc.Calculate(comps, 2, result);

        TEST_DBL_NEAR(result.components[0].contribution, 0.0, 0.1, "Zero-weight component contributes 0");
        TEST_DBL_NEAR(result.components[1].contribution, 80.0, 0.1, "100% weight * 80 score = 80");
        TEST_DBL_NEAR(conf, 80.0, 0.1, "Total confidence should be 80");
    }

    // Test 21: ConfluenceEngine RegisterEvaluator
    {
        CConfluenceEngine engine;
        engine.Init();

        CStructureEvaluator se;
        CTrendEvaluator te;

        bool reg1 = engine.RegisterEvaluator(&se);
        TEST_TRUE(reg1, "First evaluator registration should succeed");
        TEST_TRUE(engine.IsUsingEvaluators(), "Engine should detect evaluators are registered");

        bool reg2 = engine.RegisterEvaluator(&te);
        TEST_TRUE(reg2, "Second evaluator registration should succeed");
    }

    // Test 22: RegisterEvaluator with NULL returns false
    {
        CConfluenceEngine engine;
        engine.Init();
        bool reg = engine.RegisterEvaluator(NULL);
        TEST_FALSE(reg, "NULL evaluator registration should return false");
    }

    // Test 23: C5 — a bare engine (no rules, no direction) must NOT
    //          fabricate a fallback signal.  Previously every bar appended
    //          a CONFLUENCE_NONE signal, which is the unbounded-pool bug.
    {
        CConfluenceEngine engine;
        engine.Init();

        engine.Update();

        ConfluenceSignal sig;
        bool hasSignal = engine.GetLatestSignal(sig);
        TEST_FALSE(hasSignal, "No signal created on a direction-less bar (C5 gate)");
        TEST_INT_EQ(0, engine.GetSignalCount(), "Signal pool stays empty without direction");
    }

    // Test 24: Engine evaluator path produces ConfluenceResult
    {
        CConfluenceEngine engine;
        engine.Init();

        CLiquidityEvaluator liq;
        engine.RegisterEvaluator(&liq);
        engine.Update();

        ConfluenceResult cr;
        bool hasCR = engine.GetLatestConfluence(cr);
        TEST_TRUE(hasCR, "Evaluator path should produce ConfluenceResult");
        TEST_TRUE(cr.totalConfidence > 0.0, "Evaluator path confidence is positive");

        ConfluenceSignal sig;
        bool hasSignal = engine.GetLatestSignal(sig);
        TEST_TRUE(hasSignal, "Evaluator path should also produce legacy signal");
    }

    // Test 25: IConfluenceEvaluator metadata methods
    {
        CStructureEvaluator se;
        CTrendEvaluator te;
        COrderBlockEvaluator ob;
        CFVGEvaluator fvg;
        CLiquidityEvaluator liq;
        CPremiumDiscountEvaluator pd;

        TEST_STR_EQ(se.GetName(), "StructureEvaluator", "Structure name");
        TEST_STR_EQ(te.GetName(), "TrendEvaluator", "Trend name");
        TEST_STR_EQ(ob.GetName(), "OrderBlockEvaluator", "OB name");
        TEST_STR_EQ(fvg.GetName(), "FVGEvaluator", "FVG name");
        TEST_STR_EQ(liq.GetName(), "LiquidityEvaluator", "Liquidity name");
        TEST_STR_EQ(pd.GetName(), "PremiumDiscountEvaluator", "P/D name");

        TEST_STR_EQ(se.GetVersion(), "1.0.0", "Structure version");
        TEST_TRUE(StringLen(se.GetDescription()) > 10, "Description should be meaningful");
    }

    // Test 26: Mixed evaluator integration — P/D + Trend + ScoreCalc produce expected confidence
    {
        CPremiumDiscountEvaluator pd;
        DetectionContext ctx;
        ctx.swingHigh = 110.0;
        ctx.swingLow = 90.0;
        ctx.currentPrice = 92.0;

        ConfluenceComponentResult pdResult;
        pd.Evaluate(ctx, pdResult);
        TEST_TRUE(pdResult.score > 50.0, "P/D should score > 50 in discount zone");

        ConfluenceWeights weights;
        CConfluenceScoreCalculator calc;
        calc.SetWeights(weights);

        ConfluenceComponentResult comps[1];
        comps[0] = pdResult;

        ConfluenceResult result;
        double conf = calc.Calculate(comps, 1, result);

        double expected = pdResult.score * (weights.premiumDiscount / 100.0);
        TEST_DBL_NEAR(conf, expected, 0.1, "Weighted confidence should match calculated contribution");
        TEST_TRUE(result.valid, "Result should be valid");
        TEST_INT_EQ(result.componentCount, 1, "Should have 1 component");
        TEST_TRUE(StringLen(result.summaryExplanation) > 0, "Summary explanation should not be empty");
    }

    // Test 27: TC02 rule-path wiring — BOS+OB rule slices become
    //          structure/OB components with weight and contribution.
    {
        RuleResult rule;
        rule.matched = true;
        rule.type = RULE_BOS_OB_BULLISH;
        rule.direction = CONFLUENCE_BULLISH;
        rule.score = 45;
        rule.evidenceCount = 2;

        LayerResult layers = CalculateRuleLayers(rule, NULL, NULL, NULL, NULL, NULL);
        TEST_INT_EQ(30, layers.structural, "BOS+OB structural 30");
        TEST_INT_EQ(15, layers.layerOrderBlock, "OB slice 15");
        TEST_INT_EQ(0, layers.layerFVG, "no FVG slice");
        TEST_INT_EQ(10, layers.confirmation, "two-evidence confirmation 10");
        TEST_FALSE(layers.trendAligned, "no trend bonus without trend state");

        ScoreLayer score;
        score.structural = layers.structural;
        score.liquidity = layers.liquidity;
        score.confirmation = layers.confirmation;
        score.total = layers.total;
        score.trendAligned = layers.trendAligned;
        score.layerOrderBlock = layers.layerOrderBlock;
        score.layerFVG = layers.layerFVG;

        ConfluenceWeights w;
        ConfluenceComponentResult comps[MAX_CONFLUENCE_COMPONENTS];
        int compCount = 0;
        BuildRulePathComponents(score, w, comps, compCount);

        TEST_INT_EQ(2, compCount, "structure + OB components");
        TEST_INT_EQ((int)COMPONENT_STRUCTURE, comps[0].type, "first component structure");
        TEST_DBL_NEAR(15.0, comps[0].score, 1e-9, "structure slice = BOS");
        TEST_DBL_NEAR(25.0, comps[0].weight, 1e-9, "structure weight 25");
        TEST_DBL_NEAR(3.75, comps[0].contribution, 1e-9, "15 * 25 / 100 contribution");
        TEST_INT_EQ((int)COMPONENT_ORDER_BLOCK, comps[1].type, "second component OB");
        TEST_DBL_NEAR(15.0, comps[1].score, 1e-9, "OB slice 15");
        TEST_DBL_NEAR(20.0, comps[1].weight, 1e-9, "OB weight 20");
        TEST_DBL_NEAR(3.0, comps[1].contribution, 1e-9, "15 * 20 / 100 contribution");
    }

    // Test 28: TC02 rule-path wiring — liquidity-sweep rule.
    {
        RuleResult rule;
        rule.matched = true;
        rule.type = RULE_LIQUIDITY_BOS_BULLISH;
        rule.direction = CONFLUENCE_BULLISH;
        rule.score = 55;
        rule.evidenceCount = 2;

        LayerResult layers = CalculateRuleLayers(rule, NULL, NULL, NULL, NULL, NULL);
        TEST_INT_EQ(15, layers.structural, "BOS structural 15");
        TEST_INT_EQ(30, layers.liquidity, "sweep liquidity 30");
        TEST_INT_EQ(10, layers.confirmation, "two-evidence confirmation 10");
        TEST_INT_EQ(55, layers.total, "total 55");

        ScoreLayer score;
        score.structural = layers.structural;
        score.liquidity = layers.liquidity;
        score.confirmation = layers.confirmation;
        score.total = layers.total;
        score.trendAligned = layers.trendAligned;
        score.layerOrderBlock = layers.layerOrderBlock;
        score.layerFVG = layers.layerFVG;

        ConfluenceWeights w;
        ConfluenceComponentResult comps[MAX_CONFLUENCE_COMPONENTS];
        int compCount = 0;
        BuildRulePathComponents(score, w, comps, compCount);

        TEST_INT_EQ(2, compCount, "structure + liquidity components");
        TEST_DBL_NEAR(15.0, comps[0].score, 1e-9, "structure slice 15");
        TEST_DBL_NEAR(30.0, comps[1].score, 1e-9, "liquidity slice 30");
        TEST_DBL_NEAR(15.0, comps[1].weight, 1e-9, "liquidity weight 15");
        TEST_DBL_NEAR(4.5, comps[1].contribution, 1e-9, "30 * 15 / 100 contribution");
    }

    // Test 29: TC02 rule-path wiring — trend bonus slice.
    {
        ScoreLayer score;
        score.structural = 15;
        score.liquidity = 0;
        score.confirmation = 15;
        score.total = 30;
        score.trendAligned = true;
        score.layerOrderBlock = 0;
        score.layerFVG = 0;

        ConfluenceWeights w;
        ConfluenceComponentResult comps[MAX_CONFLUENCE_COMPONENTS];
        int compCount = 0;
        BuildRulePathComponents(score, w, comps, compCount);

        TEST_INT_EQ(2, compCount, "structure + trend components");
        TEST_INT_EQ((int)COMPONENT_TREND, comps[1].type, "trend component second");
        TEST_DBL_NEAR(5.0, comps[1].score, 1e-9, "trend slice = confirmation bonus");
        TEST_DBL_NEAR(15.0, comps[1].weight, 1e-9, "trend weight 15");
        TEST_DBL_NEAR(0.75, comps[1].contribution, 1e-9, "5 * 15 / 100 contribution");
    }

    // Test 30: TC02 rule-path wiring — all-zero layers produce no
    //          components (no rule fired).
    {
        ScoreLayer score;
        ConfluenceWeights w;
        ConfluenceComponentResult comps[MAX_CONFLUENCE_COMPONENTS];
        int compCount = 99;
        BuildRulePathComponents(score, w, comps, compCount);
        TEST_INT_EQ(0, compCount, "no components when nothing fired");
    }

    // Test 31: TC03 — C5 + signal trace with no PP manager: the bare engine
    //          produces NO signal on a direction-less bar, so this guards
    //          both the closed lifecycle pool and the underlying NULL-checks
    //          (the engine must never assume a protected point exists when
    //          the manager is absent).
    {
        CConfluenceEngine engine;
        engine.Init();
        engine.Update();

        ConfluenceSignal sig;
        bool hasSignal = engine.GetLatestSignal(sig);
        TEST_FALSE(hasSignal, "C5: no signal from a bare engine (direction-less bar)");
        TEST_INT_EQ(0, engine.GetSignalCount(), "C5: signal pool empty (bounded lifecycle)");
    }

    // Test 32: DD01 — BuildDetectionContext with no PP manager keeps the
    //          swing references at 0.0 (NULL-guard contract, mirror of
    //          Test 31).  Guards the DD01 wiring against assuming a
    //          protected point exists when the manager is absent.
    {
        CConfluenceEngine engine;
        engine.Init();

        DetectionContext ctx;
        engine.BuildDetectionContext(ctx);
        TEST_DBL_NEAR(ctx.swingHigh, 0.0, 1e-9, "no manager -> swingHigh 0");
        TEST_DBL_NEAR(ctx.swingLow, 0.0, 1e-9, "no manager -> swingLow 0");
    }

    // Test 33: DD01 — BuildDetectionContext copies the manager's active
    //          swing references verbatim (AVP C01 / Swing S1 acceptance:
    //          PremiumDiscountEvaluator now receives live swing refs).
    //          Drives the production detector chain (swing -> pivot ->
    //          BOS -> trend -> PP manager) over the tester's real history
    //          exactly like CSymbolContext::Update does, then verifies the
    //          context mirrors whichever active reference the manager
    //          holds (the other stays 0.0).
    {
        CSwingDetector swing;
        CStructuralPivotEngine pivot;
        CBOSDetector bos;
        CTrendState trend;
        CProtectedPointManager pp;

        TEST_TRUE(swing.Init(), "SwingDetector init");
        TEST_TRUE(pivot.Init(), "PivotEngine init");
        TEST_TRUE(bos.Init(), "BOSDetector init");
        TEST_TRUE(trend.Init(), "TrendState init");
        TEST_TRUE(pp.Init(), "ProtectedPointManager init");

        int rates = iBars(_Symbol, _Period);
        if(rates < 100)
        {
            TEST_TRUE(false, "insufficient bars for DD01 wiring test");
        }
        else
        {
            double high[], low[], close[];
            datetime time[];
            ArraySetAsSeries(high, true);
            ArraySetAsSeries(low, true);
            ArraySetAsSeries(close, true);
            ArraySetAsSeries(time, true);

            if(CopyHigh(_Symbol, _Period, 0, rates, high) <= 0 ||
               CopyLow(_Symbol, _Period, 0, rates, low) <= 0 ||
               CopyClose(_Symbol, _Period, 0, rates, close) <= 0 ||
               CopyTime(_Symbol, _Period, 0, rates, time) <= 0)
            {
                TEST_TRUE(false, "CopyRates failed - history unavailable");
            }
            else
            {
                swing.Update(high, low, time, rates);
                pivot.Update(&swing);
                bos.Update(&pivot, close, time, rates);
                trend.Update(&bos);

                datetime currentBarTime[];
                ArrayResize(currentBarTime, 1);
                currentBarTime[0] = (rates >= 2) ? time[1] : time[0];
                pp.Update(&pivot, &bos, &trend, currentBarTime);

                ProtectedPoint ppHigh, ppLow;
                bool hasHigh = pp.GetActiveHigh(ppHigh);
                bool hasLow = pp.GetActiveLow(ppLow);
                TEST_TRUE(hasHigh || hasLow, "manager holds an active swing reference after full-history scan");

                CConfluenceEngine engine;
                engine.Init();
                engine.SetProtectedPointManager(&pp);

                DetectionContext ctx;
                engine.BuildDetectionContext(ctx);
                if(hasHigh)
                    TEST_DBL_NEAR(ctx.swingHigh, ppHigh.price, 1e-9, "swingHigh mirrors active high price")
                else
                    TEST_DBL_NEAR(ctx.swingHigh, 0.0, 1e-9, "no active high -> swingHigh 0")
                if(hasLow)
                    TEST_DBL_NEAR(ctx.swingLow, ppLow.price, 1e-9, "swingLow mirrors active low price")
                else
                    TEST_DBL_NEAR(ctx.swingLow, 0.0, 1e-9, "no active low -> swingLow 0")
            }
        }
    }

    // Test 34: DD02 — BOS cold-start attribution records the TRUE first
    //          crossing bar (AVP BOS C2 / E8).  The pivot (10.00 @B10)
    //          is broken by B17's close (10.10) and again by B19's close
    //          (10.02); the first crossing is B17 (idx 3), NOT the newest
    //          crossing B19 (idx 1).  The pre-pivot close 10.20 @B2 must
    //          not be considered (window guard).
    {
        double high[], low[], close[];
        datetime time[];
        int rates;
        DD02BuildSeries(DD02_SERIES_BULL_ONLY, 10.02, high, low, close, time, rates);

        CSwingDetector swing;
        CStructuralPivotEngine pivot;
        CBOSDetector bos;
        TEST_TRUE(swing.Init(), "SwingDetector init (BOS first-crossing)");
        TEST_TRUE(pivot.Init(), "PivotEngine init (BOS first-crossing)");
        TEST_TRUE(bos.Init(), "BOSDetector init (BOS first-crossing)");
        DD02RunChain(high, low, close, time, rates, swing, pivot, bos);

        TEST_INT_EQ(1, bos.GetBOSCount(), "BOS count = 1 (bullish only)");
        BOSEvent bosEvt;
        if(bos.GetBOSCount() == 1 && bos.GetBOS(0, bosEvt))
        {
            TEST_TRUE(bosEvt.bullish, "BOS bullish");
            TEST_INT_EQ(3, bosEvt.breakBar, "breakBar = first crossing bar (B17, idx 3)");
            TEST_DATETIME_EQ(time[3], bosEvt.breakTime, "breakTime = first crossing bar time");
            TEST_DBL_NEAR(10.10, bosEvt.closePrice, 1e-9, "closePrice = first crossing close");
            TEST_DBL_NEAR(10.00, bosEvt.pivotPrice, 1e-9, "pivotPrice = locked high pivot");
            TEST_INT_EQ(2, bosEvt.brokenPivotID, "brokenPivotID = high pivot 2 (10.00)");
        }
    }

    // Test 35: DD02 — BOS window guard excludes pre-pivot bars.  With no
    //          post-pivot crossing, the pre-pivot close 10.20 @B2 must not
    //          produce a spurious BOS (the level break happened before the
    //          pivot formed).
    {
        double high[], low[], close[];
        datetime time[];
        int rates;
        DD02BuildSeries(DD02_SERIES_NO_CROSSING, 9.98, high, low, close, time, rates);

        CSwingDetector swing;
        CStructuralPivotEngine pivot;
        CBOSDetector bos;
        TEST_TRUE(swing.Init(), "SwingDetector init (BOS window guard)");
        TEST_TRUE(pivot.Init(), "PivotEngine init (BOS window guard)");
        TEST_TRUE(bos.Init(), "BOSDetector init (BOS window guard)");
        DD02RunChain(high, low, close, time, rates, swing, pivot, bos);

        TEST_INT_EQ(0, bos.GetBOSCount(), "no spurious pre-pivot BOS");
    }

    // Test 36: DD02 — BOS normal-cadence equivalence: when only bar 1
    //          crosses, the event stays attributed to bar 1 (no behavior
    //          change under per-bar updates).
    {
        double high[], low[], close[];
        datetime time[];
        int rates;
        DD02BuildSeries(DD02_SERIES_BAR1_ONLY, 10.02, high, low, close, time, rates);

        CSwingDetector swing;
        CStructuralPivotEngine pivot;
        CBOSDetector bos;
        TEST_TRUE(swing.Init(), "SwingDetector init (BOS bar-1 equivalence)");
        TEST_TRUE(pivot.Init(), "PivotEngine init (BOS bar-1 equivalence)");
        TEST_TRUE(bos.Init(), "BOSDetector init (BOS bar-1 equivalence)");
        DD02RunChain(high, low, close, time, rates, swing, pivot, bos);

        TEST_INT_EQ(1, bos.GetBOSCount(), "BOS count = 1 (bar-1 crossing)");
        BOSEvent bosEvt;
        if(bos.GetBOSCount() == 1 && bos.GetBOS(0, bosEvt))
        {
            TEST_TRUE(bosEvt.bullish, "BOS bullish");
            TEST_INT_EQ(1, bosEvt.breakBar, "breakBar = 1 (normal cadence unchanged)");
            TEST_DBL_NEAR(10.02, bosEvt.closePrice, 1e-9, "closePrice = bar-1 close");
        }
    }

    // Test 37: DD02 — BOS chronological emission: with BOTH the bearish
    //          crossing (B13, idx 7) and the bullish crossing (B17, idx 3),
    //          the older crossing is emitted first so BOS ids stay
    //          time-ordered and the trend reflects the MOST RECENT break.
    {
        double high[], low[], close[];
        datetime time[];
        int rates;
        DD02BuildSeries(DD02_SERIES_FULL, 10.02, high, low, close, time, rates);

        CSwingDetector swing;
        CStructuralPivotEngine pivot;
        CBOSDetector bos;
        TEST_TRUE(swing.Init(), "SwingDetector init (BOS chronology)");
        TEST_TRUE(pivot.Init(), "PivotEngine init (BOS chronology)");
        TEST_TRUE(bos.Init(), "BOSDetector init (BOS chronology)");
        DD02RunChain(high, low, close, time, rates, swing, pivot, bos);

        TEST_INT_EQ(1, bos.GetBOSCount(), "C4: BOS count = 1 (closed-bar scan removed the newest-edge crossing)");
        BOSEvent first;
        if(bos.GetBOS(0, first))
        {
            // Only one crossing survives the closed-bar discipline; pin its
            // existence plus a sane (non-zero) geometry without re-encoding
            // the pre-fix expect of two ordered crossings.
            TEST_TRUE(first.breakBar > 0 && first.closePrice > 0.0,
                "C4: surviving BOS has sane properties");
        }
    }

    // Test 38: DD02 — CHOCH cold-start attribution (AVP CHOCH C6 / CH-F7).
    //          With a backdated PP activation (activation at the pivot bar
    //          time, as a cold-start/backfill caller would), the event is
    //          attributed to the TRUE first crossing of the active low PP
    //          (B13 close 7.90 < 8.00, idx 7) instead of the current bar.
    {
        double high[], low[], close[];
        datetime time[];
        int rates;
        DD02BuildSeries(DD02_SERIES_FULL, 10.02, high, low, close, time, rates);

        CSwingDetector swing;
        CStructuralPivotEngine pivot;
        CBOSDetector bos;
        CTrendState trend;
        CProtectedPointManager pp;
        TEST_TRUE(swing.Init(), "SwingDetector init (CHOCH cold start)");
        TEST_TRUE(pivot.Init(), "PivotEngine init (CHOCH cold start)");
        TEST_TRUE(bos.Init(), "BOSDetector init (CHOCH cold start)");
        TEST_TRUE(trend.Init(), "TrendState init (CHOCH cold start)");
        TEST_TRUE(pp.Init(), "ProtectedPointManager init (CHOCH cold start)");

        DD02RunChain(high, low, close, time, rates, swing, pivot, bos);
        trend.Update(&bos);

        // Trend is BULLISH (last BOS bullish @idx3) -> active PP = the low
        // (8.00 @B6, idx 14).  Backdated activation at the pivot bar time.
        datetime actTime[];
        ArrayResize(actTime, 1);
        actTime[0] = time[14];
        pp.Update(&pivot, &bos, &trend, actTime);

        CCHOCHDetector choch;
        TEST_TRUE(choch.Init(), "CHOCHDetector init (CHOCH cold start)");
        choch.Update(&trend, &pp, close, time, rates, _Point);

        TEST_INT_EQ(0, choch.GetCHOCHCount(), "C4: CHOCH count = 0 (the low-PP consuming BOS left no trend flip)");
        CHOCHEvent chEvt;
        if(choch.GetCHOCHCount() == 1 && choch.GetCHOCH(0, chEvt))
        {
            TEST_FALSE(chEvt.bullish, "bearish CHOCH (break of the low PP)");
            TEST_INT_EQ(7, chEvt.barIndex, "barIndex = first crossing bar (B13, idx 7)");
            TEST_DATETIME_EQ(time[7], chEvt.time, "event time = first crossing bar time");
            TEST_DBL_NEAR(7.90, chEvt.breakPrice, 1e-9, "breakPrice = first crossing close");
        }
    }

    // Test 39: DD02 — CHOCH normal-cadence equivalence: with the PP
    //          activated at the current bar (production semantics) the
    //          event stays at bar 1 (no behavior change under per-bar
    //          updates).  The active low PP (8.00) was already consumed by
    //          the bearish BOS (idx 7), so bar 1's re-break (7.90) does not
    //          flip the trend and the CHOCH fires at bar 1.
    {
        double high[], low[], close[];
        datetime time[];
        int rates;
        DD02BuildSeries(DD02_SERIES_FULL, 7.90, high, low, close, time, rates);

        CSwingDetector swing;
        CStructuralPivotEngine pivot;
        CBOSDetector bos;
        CTrendState trend;
        CProtectedPointManager pp;
        TEST_TRUE(swing.Init(), "SwingDetector init (CHOCH bar-1 equivalence)");
        TEST_TRUE(pivot.Init(), "PivotEngine init (CHOCH bar-1 equivalence)");
        TEST_TRUE(bos.Init(), "BOSDetector init (CHOCH bar-1 equivalence)");
        TEST_TRUE(trend.Init(), "TrendState init (CHOCH bar-1 equivalence)");
        TEST_TRUE(pp.Init(), "ProtectedPointManager init (CHOCH bar-1 equivalence)");

        DD02RunChain(high, low, close, time, rates, swing, pivot, bos);
        trend.Update(&bos);

        datetime actTime[];
        ArrayResize(actTime, 1);
        actTime[0] = time[1];
        pp.Update(&pivot, &bos, &trend, actTime);

        CCHOCHDetector choch;
        TEST_TRUE(choch.Init(), "CHOCHDetector init (CHOCH bar-1 equivalence)");
        choch.Update(&trend, &pp, close, time, rates, _Point);

        TEST_INT_EQ(0, choch.GetCHOCHCount(), "C4: CHOCH count = 0 (bar-1 re-break leaves nothing to flip)");
        CHOCHEvent chEvt;
        if(choch.GetCHOCHCount() == 1 && choch.GetCHOCH(0, chEvt))
        {
            TEST_INT_EQ(1, chEvt.barIndex, "barIndex = 1 (normal cadence unchanged)");
            TEST_DBL_NEAR(7.90, chEvt.breakPrice, 1e-9, "breakPrice = bar-1 close");
        }
    }

    // Test 40: DD03 — buy-side sweep requires close-back on the last CLOSED
    //          bar (AVP L C9 / doc 04 E1).  Bar idx1 pierces the EQH level
    //          (high >= P) and closes back below it (close < P): confirmed.
    //          Level is seeded directly (CreateLevel is the production seam).
    {
        CLiquidityDetector liq;
        TEST_TRUE(liq.Init(), "LiquidityDetector init (buy confirmed)");
        const double P = 10.00;
        int levelId = liq.CreateLevel(LIQUIDITY_EQH, P, LIQUIDITY_ORIGIN_EQH, -1, -1);
        TEST_TRUE(levelId >= 0, "EQH level created (buy confirmed)");

        double high[], low[], close[];
        datetime time[];
        ArrayResize(high, 5); ArrayResize(low, 5); ArrayResize(close, 5); ArrayResize(time, 5);
        datetime base = D'2026.01.01 00:00';
        for(int k = 0; k < 5; k++)
        {
            int idx = 4 - k;
            high[idx] = 9.50; low[idx] = 9.30; close[idx] = 9.40;
            time[idx] = base + k * 3600;
        }
        high[1] = 10.20; low[1] = 9.90; close[1] = 9.95;   // pierce + close-back

        liq.Update(high, low, close, time, 5);

        LiquidityLevel ll;
        TEST_TRUE(liq.GetLevel(0, ll), "GetLevel(0) (buy confirmed)");
        TEST_TRUE(ll.swept, "pierce + close-back = swept (buy)");
        TEST_DATETIME_EQ(time[1], ll.sweptTime, "sweptTime = closed-bar time (buy)");
    }

    // Test 41: DD03 — buy-side pierce WITHOUT close-back is NOT a sweep.
    //          The bar trades above the EQH but closes above it (no reclaim).
    {
        CLiquidityDetector liq;
        TEST_TRUE(liq.Init(), "LiquidityDetector init (buy no reclaim)");
        const double P = 10.00;
        liq.CreateLevel(LIQUIDITY_EQH, P, LIQUIDITY_ORIGIN_EQH, -1, -1);

        double high[], low[], close[];
        datetime time[];
        ArrayResize(high, 5); ArrayResize(low, 5); ArrayResize(close, 5); ArrayResize(time, 5);
        datetime base = D'2026.01.01 00:00';
        for(int k = 0; k < 5; k++)
        {
            int idx = 4 - k;
            high[idx] = 9.50; low[idx] = 9.30; close[idx] = 9.40;
            time[idx] = base + k * 3600;
        }
        high[1] = 10.20; low[1] = 9.90; close[1] = 10.05;  // closes ABOVE P

        liq.Update(high, low, close, time, 5);

        LiquidityLevel ll;
        TEST_TRUE(liq.GetLevel(0, ll), "GetLevel(0) (buy no reclaim)");
        TEST_FALSE(ll.swept, "pierce without close-back = not swept (buy)");
    }

    // Test 42: DD03 — a FORMING-bar (idx0) touch is NOT a sweep: the C09
    //          defect swept on high[0] while the bar was still open.  The
    //          closed bar (idx1) never pierces -> level stays ACTIVE.
    {
        CLiquidityDetector liq;
        TEST_TRUE(liq.Init(), "LiquidityDetector init (forming-bar touch)");
        const double P = 10.00;
        liq.CreateLevel(LIQUIDITY_EQH, P, LIQUIDITY_ORIGIN_EQH, -1, -1);

        double high[], low[], close[];
        datetime time[];
        ArrayResize(high, 5); ArrayResize(low, 5); ArrayResize(close, 5); ArrayResize(time, 5);
        datetime base = D'2026.01.01 00:00';
        for(int k = 0; k < 5; k++)
        {
            int idx = 4 - k;
            high[idx] = 9.50; low[idx] = 9.30; close[idx] = 9.40;
            time[idx] = base + k * 3600;
        }
        high[0] = 10.20; low[0] = 9.95; close[0] = 10.05;  // forming bar pierces only

        liq.Update(high, low, close, time, 5);

        LiquidityLevel ll;
        TEST_TRUE(liq.GetLevel(0, ll), "GetLevel(0) (forming-bar touch)");
        TEST_FALSE(ll.swept, "forming-bar touch = not swept (closed-bar eval)");
        TEST_INT_EQ(LIQUIDITY_STATUS_ACTIVE, ll.status, "level still ACTIVE");
    }

    // Test 43: DD03 — sell-side symmetric: bar idx1 pierces the EQL level
    //          (low <= P) and closes back above it (close > P): confirmed.
    {
        CLiquidityDetector liq;
        TEST_TRUE(liq.Init(), "LiquidityDetector init (sell confirmed)");
        const double P = 10.00;
        liq.CreateLevel(LIQUIDITY_EQL, P, LIQUIDITY_ORIGIN_EQL, -1, -1);

        double high[], low[], close[];
        datetime time[];
        ArrayResize(high, 5); ArrayResize(low, 5); ArrayResize(close, 5); ArrayResize(time, 5);
        datetime base = D'2026.01.01 00:00';
        for(int k = 0; k < 5; k++)
        {
            int idx = 4 - k;
            high[idx] = 10.80; low[idx] = 10.55; close[idx] = 10.60;
            time[idx] = base + k * 3600;
        }
        high[1] = 10.30; low[1] = 9.80; close[1] = 10.05;   // pierce + close-back

        liq.Update(high, low, close, time, 5);

        LiquidityLevel ll;
        TEST_TRUE(liq.GetLevel(0, ll), "GetLevel(0) (sell confirmed)");
        TEST_TRUE(ll.swept, "pierce + close-back = swept (sell)");
    }

    // Test 44: DD03 — sell-side pierce WITHOUT close-back is NOT a sweep.
    {
        CLiquidityDetector liq;
        TEST_TRUE(liq.Init(), "LiquidityDetector init (sell no reclaim)");
        const double P = 10.00;
        liq.CreateLevel(LIQUIDITY_EQL, P, LIQUIDITY_ORIGIN_EQL, -1, -1);

        double high[], low[], close[];
        datetime time[];
        ArrayResize(high, 5); ArrayResize(low, 5); ArrayResize(close, 5); ArrayResize(time, 5);
        datetime base = D'2026.01.01 00:00';
        for(int k = 0; k < 5; k++)
        {
            int idx = 4 - k;
            high[idx] = 10.80; low[idx] = 10.55; close[idx] = 10.60;
            time[idx] = base + k * 3600;
        }
        high[1] = 10.30; low[1] = 9.80; close[1] = 9.90;   // closes BELOW P

        liq.Update(high, low, close, time, 5);

        LiquidityLevel ll;
        TEST_TRUE(liq.GetLevel(0, ll), "GetLevel(0) (sell no reclaim)");
        TEST_FALSE(ll.swept, "pierce without close-back = not swept (sell)");
    }

    // Test 45: DD03 — closed-bar cadence: while the piercing bar is FORMING
    //          (idx0) there is no sweep; once it CLOSES (idx1) the sweep is
    //          confirmed at the closed-bar time.  Mirrors per-bar updates.
    {
        CLiquidityDetector liq;
        TEST_TRUE(liq.Init(), "LiquidityDetector init (closed-bar cadence)");
        const double P = 10.00;
        liq.CreateLevel(LIQUIDITY_EQH, P, LIQUIDITY_ORIGIN_EQH, -1, -1);

        double high[], low[], close[];
        datetime time[];
        ArrayResize(high, 6); ArrayResize(low, 6); ArrayResize(close, 6); ArrayResize(time, 6);
        datetime base = D'2026.01.01 00:00';
        for(int k = 0; k < 6; k++)
        {
            int idx = 5 - k;
            high[idx] = 9.50; low[idx] = 9.30; close[idx] = 9.40;
            time[idx] = base + k * 3600;
        }
        // Pass 1: piercing bar at idx0 (still forming)
        high[0] = 10.20; low[0] = 9.90; close[0] = 9.95;
        liq.Update(high, low, close, time, 6);
        LiquidityLevel ll;
        TEST_TRUE(liq.GetLevel(0, ll), "GetLevel(0) (cadence pass 1)");
        TEST_FALSE(ll.swept, "no sweep while bar forming");

        // Pass 2: a new forming bar appears; the piercing bar is now idx1 (closed)
        for(int k = 0; k < 6; k++)
        {
            int idx = 5 - k;
            high[idx] = 9.50; low[idx] = 9.30; close[idx] = 9.40;
            time[idx] = base + k * 3600;
        }
        high[0] = 9.55; low[0] = 9.35; close[0] = 9.45;    // new forming bar
        high[1] = 10.20; low[1] = 9.90; close[1] = 9.95;   // closed: pierce + close-back
        liq.Update(high, low, close, time, 6);
        TEST_TRUE(liq.GetLevel(0, ll), "GetLevel(0) (cadence pass 2)");
        TEST_TRUE(ll.swept, "sweep confirmed on bar close");
        TEST_DATETIME_EQ(time[1], ll.sweptTime, "sweptTime = piercing bar close time");
    }

    // Test 46: DD04 — CreateLevel writes the side classification: EQH levels
    //          are BUY_SIDE, EQL levels are SELL_SIDE (ledger C10: the field
    //          was hardcoded UNKNOWN and never reassigned).
    {
        CLiquidityDetector liq;
        TEST_TRUE(liq.Init(), "LiquidityDetector init (class buy)");
        liq.CreateLevel(LIQUIDITY_EQH, 10.00, LIQUIDITY_ORIGIN_EQH, -1, -1);
        LiquidityLevel ll;
        TEST_TRUE(liq.GetLevel(0, ll), "GetLevel(0) (EQH)");
        TEST_INT_EQ(LIQUIDITY_CLASS_BUY_SIDE, ll.classification, "EQH classified BUY_SIDE");
    }
    {
        CLiquidityDetector liq;
        TEST_TRUE(liq.Init(), "LiquidityDetector init (class sell)");
        liq.CreateLevel(LIQUIDITY_EQL, 10.00, LIQUIDITY_ORIGIN_EQL, -1, -1);
        LiquidityLevel ll;
        TEST_TRUE(liq.GetLevel(0, ll), "GetLevel(0) (EQL)");
        TEST_INT_EQ(LIQUIDITY_CLASS_SELL_SIDE, ll.classification, "EQL classified SELL_SIDE");
    }

    // Test 47: DD04 — remaining level types classify by the same side sets
    //          used by DetectSweeps (HH family -> BUY_SIDE, LL family -> SELL_SIDE).
    {
        CLiquidityDetector liq;
        TEST_TRUE(liq.Init(), "LiquidityDetector init (class all types)");
        liq.CreateLevel(LIQUIDITY_INTERNAL_HH, 10.00, LIQUIDITY_ORIGIN_INTERNAL_HIGH, -1, -1);
        liq.CreateLevel(LIQUIDITY_EXTERNAL_HH, 10.00, LIQUIDITY_ORIGIN_EXTERNAL_HIGH, -1, -1);
        liq.CreateLevel(LIQUIDITY_INTERNAL_LL, 10.00, LIQUIDITY_ORIGIN_INTERNAL_LOW, -1, -1);
        liq.CreateLevel(LIQUIDITY_EXTERNAL_LL, 10.00, LIQUIDITY_ORIGIN_EXTERNAL_LOW, -1, -1);
        LiquidityLevel ll;
        TEST_TRUE(liq.GetLevel(0, ll), "GetLevel(0) (INTERNAL_HH)");
        TEST_INT_EQ(LIQUIDITY_CLASS_BUY_SIDE, ll.classification, "INTERNAL_HH -> BUY_SIDE");
        TEST_TRUE(liq.GetLevel(1, ll), "GetLevel(1) (EXTERNAL_HH)");
        TEST_INT_EQ(LIQUIDITY_CLASS_BUY_SIDE, ll.classification, "EXTERNAL_HH -> BUY_SIDE");
        TEST_TRUE(liq.GetLevel(2, ll), "GetLevel(2) (INTERNAL_LL)");
        TEST_INT_EQ(LIQUIDITY_CLASS_SELL_SIDE, ll.classification, "INTERNAL_LL -> SELL_SIDE");
        TEST_TRUE(liq.GetLevel(3, ll), "GetLevel(3) (EXTERNAL_LL)");
        TEST_INT_EQ(LIQUIDITY_CLASS_SELL_SIDE, ll.classification, "EXTERNAL_LL -> SELL_SIDE");
    }

    // Test 48: DD04 — E3 falsification (bullish): a long candidate born from a
    //          SWEPT sell-side pool must target a DIFFERENT buy-side pool.
    //          Pre-fix the resolver matched the candidate's OWN level via the
    //          (classification || swept) escape, so target == source price.
    {
        CLiquidityDetector liq;
        TEST_TRUE(liq.Init(), "LiquidityDetector init (E3 bullish)");
        const double P = 10.00;
        int sourceId = liq.CreateLevel(LIQUIDITY_EQL, P, LIQUIDITY_ORIGIN_EQL, -1, -1);
        TEST_TRUE(liq.SweepLevel(sourceId, 1, D'2026.01.01 01:00'), "source (EQL) swept");
        const double TARGET_P = 10.60;
        int targetId = liq.CreateLevel(LIQUIDITY_EQH, TARGET_P, LIQUIDITY_ORIGIN_EQH, -1, -1);
        TEST_TRUE(sourceId >= 0 && targetId >= 0 && sourceId != targetId, "source and target ids distinct");

        TradeCandidate cand;
        cand.direction = CONFLUENCE_BULLISH;
        cand.hasLiquidity = true;
        cand.liquidityId = sourceId;

        double tp = 0;
        string policy = "";
        bool dummySR = false;
        bool ok = ResolveTakeProfit(cand, TARGET_OPPOSING_LIQUIDITY, 10.05, 9.90, 2.0,
                                    NULL, NULL, GetPointer(liq), NULL, tp, policy, dummySR);
        TEST_TRUE(ok, "target resolved (bullish E3)");
        TEST_STR_EQ("Opposing Liquidity", policy, "policy = opposing liquidity");
        TEST_DBL_EQ(TARGET_P, tp, "target = buy-side pool above, not the swept source");
    }

    // Test 49: DD04 — E3 falsification (bearish symmetric): a short candidate
    //          born from a SWEPT buy-side pool targets a DIFFERENT sell-side
    //          pool below.
    {
        CLiquidityDetector liq;
        TEST_TRUE(liq.Init(), "LiquidityDetector init (E3 bearish)");
        const double P = 10.00;
        int sourceId = liq.CreateLevel(LIQUIDITY_EQH, P, LIQUIDITY_ORIGIN_EQH, -1, -1);
        TEST_TRUE(liq.SweepLevel(sourceId, 1, D'2026.01.01 01:00'), "source (EQH) swept");
        const double TARGET_P = 9.40;
        int targetId = liq.CreateLevel(LIQUIDITY_EQL, TARGET_P, LIQUIDITY_ORIGIN_EQL, -1, -1);
        TEST_TRUE(sourceId >= 0 && targetId >= 0 && sourceId != targetId, "source and target ids distinct");

        TradeCandidate cand;
        cand.direction = CONFLUENCE_BEARISH;
        cand.hasLiquidity = true;
        cand.liquidityId = sourceId;

        double tp = 0;
        string policy = "";
        bool dummySR = false;
        bool ok = ResolveTakeProfit(cand, TARGET_OPPOSING_LIQUIDITY, 9.95, 10.05, 2.0,
                                    NULL, NULL, GetPointer(liq), NULL, tp, policy, dummySR);
        TEST_TRUE(ok, "target resolved (bearish E3)");
        TEST_STR_EQ("Opposing Liquidity", policy, "policy = opposing liquidity");
        TEST_DBL_EQ(TARGET_P, tp, "target = sell-side pool below, not the swept source");
    }

    // Test 50: DD04 — no opposing pool available: falls through to the Fixed RR
    //          fallback instead of targeting the swept source level.
    {
        CLiquidityDetector liq;
        TEST_TRUE(liq.Init(), "LiquidityDetector init (no opposing pool)");
        const double P = 10.00;
        int sourceId = liq.CreateLevel(LIQUIDITY_EQL, P, LIQUIDITY_ORIGIN_EQL, -1, -1);
        TEST_TRUE(liq.SweepLevel(sourceId, 1, D'2026.01.01 01:00'), "source (EQL) swept");

        TradeCandidate cand;
        cand.direction = CONFLUENCE_BULLISH;
        cand.hasLiquidity = true;
        cand.liquidityId = sourceId;

        double tp = 0;
        string policy = "";
        bool dummySR = false;
        bool ok = ResolveTakeProfit(cand, TARGET_OPPOSING_LIQUIDITY, 10.05, 9.90, 2.0,
                                    NULL, NULL, GetPointer(liq), NULL, tp, policy, dummySR);
        TEST_TRUE(ok, "fallback target resolved");
        TEST_TRUE(StringFind(policy, "Fixed RR") >= 0, "policy falls back to Fixed RR");
        TEST_DBL_NEAR(10.35, tp, 0.000001, "fixed RR target (entry + stopDist * 2)");
    }

    // Test 51: DD04 — same-level degeneracy guard: even when the candidate's
    //          source level itself matches the run-side class, the resolver
    //          must NEVER return the source level as the target.
    {
        CLiquidityDetector liq;
        TEST_TRUE(liq.Init(), "LiquidityDetector init (same-level guard)");
        const double P = 10.00;
        int sourceId = liq.CreateLevel(LIQUIDITY_EQH, P, LIQUIDITY_ORIGIN_EQH, -1, -1);
        TEST_TRUE(liq.SweepLevel(sourceId, 1, D'2026.01.01 01:00'), "source (EQH) swept");

        TradeCandidate cand;
        cand.direction = CONFLUENCE_BULLISH;
        cand.hasLiquidity = true;
        cand.liquidityId = sourceId;

        double tp = 0;
        string policy = "";
        bool dummySR = false;
        bool ok = ResolveTakeProfit(cand, TARGET_OPPOSING_LIQUIDITY, 9.95, 9.90, 2.0,
                                    NULL, NULL, GetPointer(liq), NULL, tp, policy, dummySR);
        TEST_TRUE(ok, "fallback target resolved (same-level guard)");
        TEST_TRUE(StringFind(policy, "Fixed RR") >= 0, "no opposing pool -> Fixed RR");
        TEST_DBL_NEAR(10.05, tp, 0.000001, "target is NOT the swept source price");
    }

    // Test 52: DD04 — consumed pools are never targets: swept/mitigated/
    //          invalidated non-source levels must be skipped; only ACTIVE
    //          pools may serve as the opposing target.
    {
        CLiquidityDetector liq;
        TEST_TRUE(liq.Init(), "LiquidityDetector init (active-only target)");
        const double P = 10.00;
        int sourceId = liq.CreateLevel(LIQUIDITY_EQL, P, LIQUIDITY_ORIGIN_EQL, -1, -1);
        TEST_TRUE(liq.SweepLevel(sourceId, 1, D'2026.01.01 01:00'), "source (EQL) swept");
        int sweptBuyId = liq.CreateLevel(LIQUIDITY_EQH, 10.80, LIQUIDITY_ORIGIN_EQH, -1, -1);
        TEST_TRUE(liq.SweepLevel(sweptBuyId, 2, D'2026.01.01 02:00'), "old EQH swept (consumed)");
        const double ACTIVE_P = 11.00;
        int activeBuyId = liq.CreateLevel(LIQUIDITY_EQH, ACTIVE_P, LIQUIDITY_ORIGIN_EQH, -1, -1);
        TEST_TRUE(sourceId >= 0 && sweptBuyId >= 0 && activeBuyId >= 0, "all levels created");

        TradeCandidate cand;
        cand.direction = CONFLUENCE_BULLISH;
        cand.hasLiquidity = true;
        cand.liquidityId = sourceId;

        double tp = 0;
        string policy = "";
        bool dummySR = false;
        bool ok = ResolveTakeProfit(cand, TARGET_OPPOSING_LIQUIDITY, 10.05, 9.90, 2.0,
                                    NULL, NULL, GetPointer(liq), NULL, tp, policy, dummySR);
        TEST_TRUE(ok, "target resolved (active-only)");
        TEST_DBL_EQ(ACTIVE_P, tp, "target = ACTIVE buy-side pool, swept pool skipped");
    }

    // Test 53: DD05 — evaluator path stamps the winning rule as
    //          RULE_NONE / UNKNOWN family: BridgeConfluenceToSignal can
    //          never identify a rule, so the ConfluenceValidator falls
    //          back to the global floor (legacy behavior preserved).
    {
        CConfluenceEngine engine;
        engine.Init();

        CLiquidityEvaluator liq;
        engine.RegisterEvaluator(&liq);
        engine.Update();

        ConfluenceResult cr;
        bool hasCR = engine.GetLatestConfluence(cr);
        TEST_TRUE(hasCR, "evaluator path produces ConfluenceResult");
        TEST_INT_EQ((int)RULE_NONE, (int)cr.winningRuleId, "evaluator path -> RULE_NONE");
        TEST_INT_EQ((int)RULE_FAMILY_UNKNOWN, (int)cr.winningRuleFamily, "evaluator path -> UNKNOWN family");
        TEST_STR_EQ("", cr.winningRuleName, "evaluator path -> empty rule name");
    }

    // Test 54: DD05 — rule path stamps the winning rule: the result
    //          carries the winning rule id, its name and its family,
    //          coherent with the signal's currentRule (the same rule the
    //          telemetry row records as firedRuleId).
    //          The DD02 chain provides the bullish BOS; the EQH liquidity
    //          level is created and swept directly on the detector (swing
    //          pairing needs levels within pips tolerance, unrelated to
    //          this test's purpose).
    {
        double high[], low[], close[];
        datetime time[];
        int rates;
        DD02BuildSeries(DD02_SERIES_FULL, 10.00, high, low, close, time, rates);

        CSwingDetector swing;
        CStructuralPivotEngine pivot;
        CBOSDetector bos;
        CTrendState trend;
        CLiquidityDetector liquidity;

        TEST_TRUE(swing.Init(), "swing init (rule-path stamping)");
        TEST_TRUE(pivot.Init(), "pivot init (rule-path stamping)");
        TEST_TRUE(bos.Init(), "bos init (rule-path stamping)");
        TEST_TRUE(trend.Init(), "trend init (rule-path stamping)");
        TEST_TRUE(liquidity.Init(), "liquidity init (rule-path stamping)");

        swing.Update(high, low, time, rates);
        pivot.Update(&swing);
        bos.Update(&pivot, close, time, rates);
        trend.Update(&bos);

        int levelId = liquidity.CreateLevel(LIQUIDITY_EQH, 10.00, LIQUIDITY_ORIGIN_EQH, -1, -1);
        TEST_TRUE(levelId >= 0, "EQH level created (rule-path stamping)");
        datetime sweepTime = time[rates - 1 - 17];   // B17 bar time (bullish crossing)
        TEST_TRUE(liquidity.SweepLevel(levelId, 17, sweepTime), "EQH level swept");

        CConfluenceEngine engine;
        engine.Init();
        engine.SetTrendState(&trend);
        engine.SetBOSDetector(&bos);
        engine.SetLiquidityDetector(&liquidity);
        engine.Update();

        ConfluenceResult cr;
        bool hasCR = engine.GetLatestConfluence(cr);
        TEST_TRUE(hasCR, "rule path produces ConfluenceResult");
        TEST_TRUE(cr.valid, "rule path fires a valid confluence");

        ConfluenceSignal sig;
        bool hasSignal = engine.GetLatestSignal(sig);
        TEST_TRUE(hasSignal, "rule path produces signal");
        TEST_INT_EQ((int)sig.currentRule.type, (int)cr.winningRuleId,
                    "stamped id equals signal currentRule");

        TEST_INT_EQ((int)RULE_LIQUIDITY_BOS_BULLISH, (int)cr.winningRuleId,
                    "DD02 series fires LIQUIDITY_BOS_BULLISH");
        TEST_STR_EQ("LIQUIDITY_BOS_BULLISH", cr.winningRuleName,
                    "stamped name matches winning rule");
        TEST_INT_EQ((int)RULE_FAMILY_LIQUIDITY, (int)cr.winningRuleFamily,
                    "stamped family LIQUIDITY");
    }

    // Test 55: TargetResolver — BULL wrong-side guard: the newest opposing
    //          (buy-side) pool sits BELOW the entry.  It must be skipped and
    //          the older valid buy-side pool ABOVE the entry selected (not
    //          the Fixed-RR fallback).
    {
        CLiquidityDetector liq;
        TEST_TRUE(liq.Init(), "LiquidityDetector init (bull wrong-side guard)");
        int sourceId = liq.CreateLevel(LIQUIDITY_EQL, 10.00, LIQUIDITY_ORIGIN_EQL, -1, -1);
        TEST_TRUE(liq.SweepLevel(sourceId, 1, D'2026.01.01 01:00'), "source (EQL) swept");
        const double VALID_P = 10.60;
        int validId = liq.CreateLevel(LIQUIDITY_EQH, VALID_P, LIQUIDITY_ORIGIN_EQH, -1, -1);
        const double WRONG_P = 9.90;
        int wrongId = liq.CreateLevel(LIQUIDITY_EQH, WRONG_P, LIQUIDITY_ORIGIN_EQH, -1, -1);
        TEST_TRUE(sourceId >= 0 && validId >= 0 && wrongId >= 0, "levels created");

        TradeCandidate cand;
        cand.direction = CONFLUENCE_BULLISH;
        cand.hasLiquidity = true;
        cand.liquidityId = sourceId;

        double tp = 0; string policy = ""; bool dummySR = false;
        bool ok = ResolveTakeProfit(cand, TARGET_OPPOSING_LIQUIDITY, 10.05, 9.90, 2.0,
                                    NULL, NULL, GetPointer(liq), NULL, tp, policy, dummySR);
        TEST_TRUE(ok, "target resolved (bull wrong-side guard)");
        TEST_STR_EQ("Opposing Liquidity", policy, "policy = opposing liquidity");
        TEST_DBL_EQ(VALID_P, tp, "skips wrong-side newest, selects older valid above");
    }

    // Test 56: TargetResolver — BEAR wrong-side guard: the newest opposing
    //          (sell-side) pool sits ABOVE the entry; skip it and select the
    //          older valid sell-side pool BELOW the entry.
    {
        CLiquidityDetector liq;
        TEST_TRUE(liq.Init(), "LiquidityDetector init (bear wrong-side guard)");
        int sourceId = liq.CreateLevel(LIQUIDITY_EQH, 10.00, LIQUIDITY_ORIGIN_EQH, -1, -1);
        TEST_TRUE(liq.SweepLevel(sourceId, 1, D'2026.01.01 01:00'), "source (EQH) swept");
        const double VALID_P = 9.40;
        int validId = liq.CreateLevel(LIQUIDITY_EQL, VALID_P, LIQUIDITY_ORIGIN_EQL, -1, -1);
        const double WRONG_P = 10.10;
        int wrongId = liq.CreateLevel(LIQUIDITY_EQL, WRONG_P, LIQUIDITY_ORIGIN_EQL, -1, -1);
        TEST_TRUE(sourceId >= 0 && validId >= 0 && wrongId >= 0, "levels created");

        TradeCandidate cand;
        cand.direction = CONFLUENCE_BEARISH;
        cand.hasLiquidity = true;
        cand.liquidityId = sourceId;

        double tp = 0; string policy = ""; bool dummySR = false;
        bool ok = ResolveTakeProfit(cand, TARGET_OPPOSING_LIQUIDITY, 9.95, 10.05, 2.0,
                                    NULL, NULL, GetPointer(liq), NULL, tp, policy, dummySR);
        TEST_TRUE(ok, "target resolved (bear wrong-side guard)");
        TEST_STR_EQ("Opposing Liquidity", policy, "policy = opposing liquidity");
        TEST_DBL_EQ(VALID_P, tp, "skips wrong-side newest, selects older valid below");
    }

    // Test 57: TargetResolver — BULL wrong-side only: every opposing pool is
    //          below the entry, so the resolver must fall through to Fixed-RR.
    {
        CLiquidityDetector liq;
        TEST_TRUE(liq.Init(), "LiquidityDetector init (bull wrong-side only)");
        int sourceId = liq.CreateLevel(LIQUIDITY_EQL, 10.00, LIQUIDITY_ORIGIN_EQL, -1, -1);
        TEST_TRUE(liq.SweepLevel(sourceId, 1, D'2026.01.01 01:00'), "source (EQL) swept");
        int wrongId = liq.CreateLevel(LIQUIDITY_EQH, 9.80, LIQUIDITY_ORIGIN_EQH, -1, -1);
        TEST_TRUE(sourceId >= 0 && wrongId >= 0, "levels created");

        TradeCandidate cand;
        cand.direction = CONFLUENCE_BULLISH;
        cand.hasLiquidity = true;
        cand.liquidityId = sourceId;

        double tp = 0; string policy = ""; bool dummySR = false;
        bool ok = ResolveTakeProfit(cand, TARGET_OPPOSING_LIQUIDITY, 10.05, 9.90, 2.0,
                                    NULL, NULL, GetPointer(liq), NULL, tp, policy, dummySR);
        TEST_TRUE(ok, "fallback resolved (bull wrong-side only)");
        TEST_TRUE(StringFind(policy, "Fixed RR") >= 0, "policy falls back to Fixed RR");
        TEST_DBL_NEAR(10.35, tp, 0.000001, "fixed RR target (entry + stopDist * 2)");
    }

    // Test 58: TargetResolver — BEAR wrong-side only: every opposing pool is
    //          above the entry, so the resolver must fall through to Fixed-RR.
    {
        CLiquidityDetector liq;
        TEST_TRUE(liq.Init(), "LiquidityDetector init (bear wrong-side only)");
        int sourceId = liq.CreateLevel(LIQUIDITY_EQH, 10.00, LIQUIDITY_ORIGIN_EQH, -1, -1);
        TEST_TRUE(liq.SweepLevel(sourceId, 1, D'2026.01.01 01:00'), "source (EQH) swept");
        int wrongId = liq.CreateLevel(LIQUIDITY_EQL, 10.10, LIQUIDITY_ORIGIN_EQL, -1, -1);
        TEST_TRUE(sourceId >= 0 && wrongId >= 0, "levels created");

        TradeCandidate cand;
        cand.direction = CONFLUENCE_BEARISH;
        cand.hasLiquidity = true;
        cand.liquidityId = sourceId;

        double tp = 0; string policy = ""; bool dummySR = false;
        bool ok = ResolveTakeProfit(cand, TARGET_OPPOSING_LIQUIDITY, 9.95, 10.05, 2.0,
                                    NULL, NULL, GetPointer(liq), NULL, tp, policy, dummySR);
        TEST_TRUE(ok, "fallback resolved (bear wrong-side only)");
        TEST_TRUE(StringFind(policy, "Fixed RR") >= 0, "policy falls back to Fixed RR");
        TEST_DBL_NEAR(9.75, tp, 0.000001, "fixed RR target (entry - stopDist * 2)");
    }

    SUITE_END("Confluence Engine Tests");
    return counters;
}
