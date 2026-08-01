#include "../TestAssert.mqh"
#include "../../Calibration/CalibrationMetrics.mqh"
#include "../../Calibration/ThresholdOptimizer.mqh"
#include "../../Calibration/WeightOptimizer.mqh"
#include "../../Calibration/ValidatorAttribution.mqh"
#include "../../Calibration/PromotionGate.mqh"

// ─── CalibrationMetrics ────────────────────────────────────────────

void TestMetrics_ComputeStats(TestCounters &counters)
{
    int n = 4;
    TelemetryRow rows[4];
    for(int i = 0; i < n; i++)
    {
        rows[i].outcome = (int)TELEMETRY_OUTCOME_WIN;
        rows[i].rMultiple = 0.9;
    }
    rows[3].outcome = (int)TELEMETRY_OUTCOME_LOSS;
    rows[3].rMultiple = -1.1;

    bool eligible[4];
    for(int i = 0; i < n; i++)
        eligible[i] = true;

    TradeStats stats;
    CalibrationComputeStats(rows, eligible, n, stats);

    TEST_INT_EQ(4, stats.trades, "Trades counted");
    TEST_INT_EQ(3, stats.wins, "Wins counted");
    TEST_INT_EQ(1, stats.losses, "Losses counted");
    TEST_DBL_NEAR(2.7 / 1.1, stats.profitFactor, 1e-9, "Profit factor 2.7/1.1");
    TEST_DBL_NEAR(0.75, stats.winRate, 1e-9, "Win rate 3/4");
    TEST_DBL_NEAR(0.4, stats.expectancy, 1e-9, "Expectancy (2.7-1.1)/4");
    TEST_DBL_NEAR(1.1, stats.maxDrawdown, 1e-9, "Max drawdown in R units");
}

void TestMetrics_UnsettledSkipped(TestCounters &counters)
{
    int n = 3;
    TelemetryRow rows[3];
    rows[0].outcome = (int)TELEMETRY_OUTCOME_WIN;
    rows[0].rMultiple = 1.0;
    rows[1].outcome = (int)TELEMETRY_OUTCOME_UNKNOWN;   // unsettled
    rows[1].rMultiple = 0.0;
    rows[2].outcome = (int)TELEMETRY_OUTCOME_LOSS;
    rows[2].rMultiple = -1.0;

    bool eligible[3];
    for(int i = 0; i < n; i++)
        eligible[i] = true;

    TradeStats stats;
    CalibrationComputeStats(rows, eligible, n, stats);

    TEST_INT_EQ(2, stats.trades, "Unsettled rows excluded from trades");
    TEST_DBL_NEAR(0.0, stats.expectancy, 1e-9, "Expectancy (1.0-1.0)/2");
}

void TestMetrics_WelchIdentical(TestCounters &counters)
{
    double a[5] = { 0.5, 0.6, 0.7, 0.4, 0.8 };
    double b[5] = { 0.5, 0.6, 0.7, 0.4, 0.8 };
    double p = CalibrationWelchPValue(a, 5, b, 5);
    TEST_DBL_NEAR(1.0, p, 1e-9, "Identical groups give p = 1");
}

void TestMetrics_WelchDifferent(TestCounters &counters)
{
    double a[6] = { 0.9, 0.9, 0.9, 0.9, 0.9, 0.9 };
    double b[6] = { -1.1, -1.1, -1.1, -1.1, -1.1, -1.1 };
    double p = CalibrationWelchPValue(a, 6, b, 6);
    TEST_TRUE(p < 0.001, "Very different groups give p < 0.001");
}

//--- Build a deterministic dataset: rows whose confidence is high are
//    profitable, rows with low confidence lose.  Pattern:
//    index % 10 < 8 -> conf 0.72, R +0.9 ; else conf 0.65, R -1.1
void BuildConfidenceDataset(int n, TelemetryRow &rows[], double confHigh, double rHigh,
                            double confLow, double rLow, int &highCount)
{
    ArrayResize(rows, n);
    highCount = 0;
    for(int i = 0; i < n; i++)
    {
        rows[i] = TelemetryRow();
        bool high = (i % 10 < 8);
        rows[i].confidence = high ? confHigh : confLow;
        rows[i].outcome = high ? (int)TELEMETRY_OUTCOME_WIN : (int)TELEMETRY_OUTCOME_LOSS;
        rows[i].rMultiple = high ? rHigh : rLow;
        rows[i].validatorCount = 0;
        if(high)
            highCount++;
    }
}

// ─── ThresholdOptimizer ────────────────────────────────────────────

void TestThreshold_BestThreshold(TestCounters &counters)
{
    TelemetryRow rows[];
    int highCount = 0;
    BuildConfidenceDataset(1000, rows, 0.72, 0.9, 0.65, -1.1, highCount);

    CThresholdOptimizer optimizer;
    optimizer.Load(rows, 1000);

    ThresholdResult results[THRESHOLD_OPT_MAX_EVALS];
    int n = optimizer.Optimize(0.40, 0.80, 0.05, 0.60, results);

    TEST_INT_EQ(9, n, "9 thresholds evaluated (0.40..0.80 step 0.05)");
    TEST_DBL_NEAR(0.70, results[0].threshold, 1e-9, "Best threshold excludes losers at 0.70");
    TEST_DBL_NEAR(0.9, results[0].stats.expectancy, 1e-9, "Best expectancy = 0.9 (winners only)");
    TEST_INT_EQ(highCount, results[0].settledTrades, "Settled trades = high-confidence rows");
    TEST_TRUE(results[0].significant, "Best threshold significant vs baseline 0.60");
}

void TestThreshold_MonotonicRanking(TestCounters &counters)
{
    TelemetryRow rows[];
    int highCount = 0;
    BuildConfidenceDataset(500, rows, 0.72, 0.9, 0.65, -1.1, highCount);

    CThresholdOptimizer optimizer;
    optimizer.Load(rows, 500);

    ThresholdResult results[THRESHOLD_OPT_MAX_EVALS];
    optimizer.Optimize(0.40, 0.80, 0.05, 0.60, results);

    for(int i = 1; i < 9; i++)
        TEST_TRUE(results[i - 1].stats.expectancy >= results[i].stats.expectancy - 1e-12,
                  "Results sorted by expectancy descending");
}

// ─── WeightOptimizer ───────────────────────────────────────────────

//--- Structure-dependent dataset: only the structure raw carries signal;
//    other components are zero so the weighted score isolates wStructure.
//    High rows: raw 94..97 (win).  Low rows: raw 85..89 (lose).
void BuildWeightDataset(TelemetryRow &rows[], int &n)
{
    n = 600;
    ArrayResize(rows, n);
    for(int i = 0; i < n; i++)
    {
        rows[i] = TelemetryRow();
        bool high = (i % 5 < 4);                       // 480 high, 120 low
        double structureRaw = high ? (94.0 + (i % 5)) : (85.0 + (i % 5));
        rows[i].SetComponent(COMPONENT_STRUCTURE, structureRaw, 25.0, structureRaw * 0.25);
        rows[i].SetComponent(COMPONENT_ORDER_BLOCK, 0.0, 20.0, 0.0);
        rows[i].SetComponent(COMPONENT_FVG, 0.0, 15.0, 0.0);
        rows[i].SetComponent(COMPONENT_LIQUIDITY, 0.0, 15.0, 0.0);
        rows[i].SetComponent(COMPONENT_TREND, 0.0, 15.0, 0.0);
        rows[i].SetComponent(COMPONENT_PREMIUM_DISCOUNT, 0.0, 10.0, 0.0);
        rows[i].confidence = structureRaw * 0.25;
        rows[i].outcome = high ? (int)TELEMETRY_OUTCOME_WIN : (int)TELEMETRY_OUTCOME_LOSS;
        rows[i].rMultiple = high ? 0.9 : -1.1;
        rows[i].validatorCount = 0;
    }
}

void TestWeights_StructureDominant(TestCounters &counters)
{
    TelemetryRow rows[];
    int n = 0;
    BuildWeightDataset(rows, n);

    CWeightOptimizer optimizer;
    optimizer.Load(rows, n);

    double baseline[6] = { 25.0, 20.0, 15.0, 15.0, 15.0, 10.0 };
    WeightCandidate best;
    //--- Threshold is on the 0..100 ReplayConfidence scale.  At wStructure=60
    //    high rows replay 56.4..58.2 (qualify) while low rows replay
    //    51.0..52.8 (excluded); at wStructure=50 nothing qualifies and at
    //    70+ everything qualifies (0.5 expectancy) - so 55 isolates winners.
    int evals = optimizer.Optimize(baseline, 55.0, best);

    TEST_TRUE(evals >= 3003, "Stage 1 coarse scan evaluates all compositions");
    //--- A structure-heavy configuration must isolate the winners.
    TEST_TRUE(best.weights[0] >= 60.0, "Search favours a structure-heavy config");
    TEST_DBL_NEAR(0.9, best.expectancy, 0.001, "Best config trades winners only");
}

// ─── ValidatorAttribution ──────────────────────────────────────────

void BuildAttributionDataset(TelemetryRow &rows[], int &n)
{
    n = 200;
    ArrayResize(rows, n);
    for(int i = 0; i < n; i++)
    {
        rows[i] = TelemetryRow();
        bool profitable = (i < 120);                    // 120 profitable, 80 losing
        rows[i].confidence = 0.85;
        rows[i].validatorCount = 1;
        rows[i].validators[0].name = "VolumeValidator";
        rows[i].validators[0].result = profitable ? FILTER_FAIL : FILTER_PASS;
        rows[i].outcome = profitable ? (int)TELEMETRY_OUTCOME_WIN : (int)TELEMETRY_OUTCOME_LOSS;
        rows[i].rMultiple = profitable ? 0.9 : -1.1;
    }
}

void TestAttribution_WeakenRecommended(TestCounters &counters)
{
    TelemetryRow rows[];
    int n = 0;
    BuildAttributionDataset(rows, n);

    CValidatorAttribution attribution;
    attribution.Load(rows, n);

    AttributionResult results[ATTR_MAX_VALIDATORS];
    int count = attribution.Analyze(0.60, results);

    TEST_INT_EQ(1, count, "One validator analyzed");
    if(count > 0)
    {
        TEST_STR_EQ("VolumeValidator", results[0].validator, "Validator identified");
        TEST_INT_EQ(120, results[0].gateFailCount, "Fail count matches profitable rows it blocks");
        TEST_TRUE(results[0].deltaExpectancy > 0.5, "Removing it improves expectancy materially");
        TEST_TRUE(results[0].recommendWeaken, "Blocks money -> recommend weaken");
        TEST_FALSE(results[0].recommendStrengthen, "Not a protector");
    }
}

// ─── PromotionGate ─────────────────────────────────────────────────

//--- Dataset: high-conf rows win +0.9; low-conf rows lose -1.2.
void BuildPromotionDataset(int n, TelemetryRow &rows[], int &highCount)
{
    ArrayResize(rows, n);
    highCount = 0;
    for(int i = 0; i < n; i++)
    {
        rows[i] = TelemetryRow();
        bool high = (i % 1000 < 800);
        rows[i].confidence = high ? 0.72 : 0.65;
        rows[i].outcome = high ? (int)TELEMETRY_OUTCOME_WIN : (int)TELEMETRY_OUTCOME_LOSS;
        rows[i].rMultiple = high ? 0.9 : -1.2;
        rows[i].validatorCount = 0;
        if(high)
            highCount++;
    }
}

void ComputeGateStats(TelemetryRow &rows[], int n, double threshold, TradeStats &out)
{
    bool eligible[];
    ArrayResize(eligible, n);
    for(int i = 0; i < n; i++)
        eligible[i] = rows[i].ReplayDecision(threshold);
    CalibrationComputeStats(rows, eligible, n, out);
}

void TestGate_PromotesGoodConfig(TestCounters &counters)
{
    TelemetryRow rows[];
    int highCount = 0;
    BuildPromotionDataset(12000, rows, highCount);

    TradeStats candidate;
    TradeStats baseline;
    ComputeGateStats(rows, 12000, 0.70, candidate);
    ComputeGateStats(rows, 12000, 0.60, baseline);

    CPromotionGate gate;
    PromotionReport report;
    bool promoted = gate.Evaluate(rows, 12000, 0xABCD, "good-config",
                                  0.70, 0.60, candidate, baseline, report);

    TEST_TRUE(promoted, "Good config promoted");
    TEST_FALSE(report.inconclusive, "Report not inconclusive");
    TEST_INT_EQ(12000, report.shadowComparisons, "Shadow comparison count reported");
    TEST_INT_EQ(highCount, report.qualifiedSignals, "Qualified signals counted");
    TEST_INT_EQ(8, report.criterionCount, "All 8 criteria evaluated");
}

void TestGate_InsufficientSamplesInconclusive(TestCounters &counters)
{
    TelemetryRow rows[];
    int highCount = 0;
    BuildPromotionDataset(500, rows, highCount);

    TradeStats candidate;
    TradeStats baseline;
    ComputeGateStats(rows, 500, 0.70, candidate);
    ComputeGateStats(rows, 500, 0.60, baseline);

    CPromotionGate gate;
    PromotionReport report;
    bool promoted = gate.Evaluate(rows, 500, 0xABCD, "tiny-config",
                                  0.70, 0.60, candidate, baseline, report);

    TEST_FALSE(promoted, "Tiny sample never promoted");
    TEST_TRUE(report.inconclusive, "Insufficient sample -> INCONCLUSIVE");
}

void TestGate_RejectsWorseConfig(TestCounters &counters)
{
    //--- High-conf rows win +0.4, low-conf rows win +0.5: the baseline
    //    (0.60 threshold) includes the better low-conf trades, so the
    //    candidate (0.70) has LOWER expectancy.
    int n = 12000;
    TelemetryRow rows[];
    ArrayResize(rows, n);
    for(int i = 0; i < n; i++)
    {
        rows[i] = TelemetryRow();
        bool high = (i % 1000 < 800);
        rows[i].confidence = high ? 0.72 : 0.65;
        rows[i].outcome = (int)TELEMETRY_OUTCOME_WIN;
        rows[i].rMultiple = high ? 0.4 : 0.5;
        rows[i].validatorCount = 0;
    }

    TradeStats candidate;
    TradeStats baseline;
    ComputeGateStats(rows, n, 0.70, candidate);
    ComputeGateStats(rows, n, 0.60, baseline);

    CPromotionGate gate;
    PromotionReport report;
    bool promoted = gate.Evaluate(rows, n, 0xABCD, "worse-config",
                                  0.70, 0.60, candidate, baseline, report);

    TEST_FALSE(promoted, "Worse config rejected");
    TEST_FALSE(report.inconclusive, "Fully evaluated (not inconclusive)");
    TEST_DBL_NEAR(0.42, baseline.expectancy, 1e-9, "Baseline expectancy includes better trades");
}

// ─── Entry Point ───────────────────────────────────────────────────

TestCounters RunCalibrationOptimizersTests()
{
    TestCounters counters;
    SUITE_BEGIN("Calibration Optimizers Tests");

    TestMetrics_ComputeStats(counters);
    TestMetrics_UnsettledSkipped(counters);
    TestMetrics_WelchIdentical(counters);
    TestMetrics_WelchDifferent(counters);
    TestThreshold_BestThreshold(counters);
    TestThreshold_MonotonicRanking(counters);
    TestWeights_StructureDominant(counters);
    TestAttribution_WeakenRecommended(counters);
    TestGate_PromotesGoodConfig(counters);
    TestGate_InsufficientSamplesInconclusive(counters);
    TestGate_RejectsWorseConfig(counters);

    SUITE_END("Calibration Optimizers Tests");
    return counters;
}
