#include "../../Confluence/Evaluators/StructureEvaluator.mqh"
#include "../../Confluence/Evaluators/TrendEvaluator.mqh"
#include "../../Confluence/Evaluators/OrderBlockEvaluator.mqh"
#include "../../Confluence/Evaluators/FVGEvaluator.mqh"
#include "../../Confluence/Evaluators/LiquidityEvaluator.mqh"
#include "../../Confluence/Evaluators/PremiumDiscountEvaluator.mqh"
#include "../../Confluence/ConfluenceScoreCalculator.mqh"
#include "../../Confluence/ConfluenceEngine.mqh"
#include "../TestAssert.mqh"

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

    // Test 23: Engine rule fallback path produces valid signal
    {
        CConfluenceEngine engine;
        engine.Init();

        engine.Update();

        ConfluenceSignal sig;
        bool hasSignal = engine.GetLatestSignal(sig);
        TEST_TRUE(hasSignal, "Rule fallback should produce a signal");
        TEST_TRUE(sig.id > 0, "Signal should have a valid ID");
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

    SUITE_END("Confluence Engine Tests");
    return counters;
}
