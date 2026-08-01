#include "../TestAssert.mqh"
#include "../../Calibration/CalibrationReport.mqh"

//--- Fill one settled row with the given confidence/outcome.
void FillSettledRow(TelemetryRow &row, double conf, int outcome, double r)
{
    row = TelemetryRow();
    row.confidence = conf;
    row.outcome = outcome;
    row.rMultiple = r;
    row.validatorCount = 0;
}

int FindBin(const CalibrationBin &bins[], double lo, double hi)
{
    for(int i = 0; i < ArraySize(bins); i++)
    {
        if(MathAbs(bins[i].binLo - lo) < 1e-9 && MathAbs(bins[i].binHi - hi) < 1e-9)
            return i;
    }
    return -1;
}

int SumBinTrades(const CalibrationBin &bins[])
{
    int s = 0;
    for(int i = 0; i < ArraySize(bins); i++)
        s += bins[i].trades;
    return s;
}

//--- Perfectly calibrated rows at bin centers: ECE and MCE are exactly 0.
//    Groups (200 rows each): c=0.475 with 95 wins, c=0.575 with 115 wins,
//    c=0.675 with 135 wins — winRate matches each bin center.
void TestReport_PerfectlyCalibrated(TestCounters &counters)
{
    int n = 600;
    TelemetryRow rows[];
    ArrayResize(rows, n);
    const double confs[3] = { 0.475, 0.575, 0.675 };
    const int wins[3] = { 95, 115, 135 };
    int k = 0;
    for(int g = 0; g < 3; g++)
    {
        for(int i = 0; i < 200; i++)
        {
            bool win = (i < wins[g]);
            FillSettledRow(rows[k], confs[g],
                           win ? (int)TELEMETRY_OUTCOME_WIN : (int)TELEMETRY_OUTCOME_LOSS,
                           win ? 2.0 : -1.0);
            k++;
        }
    }

    CalibrationBin bins[];
    int binCount = 0;
    CalibrationSummary summary;
    CalibrationAnalyze(rows, n, 0.05, bins, binCount, summary);

    TEST_INT_EQ(3, binCount, "Three bins populated");
    TEST_INT_EQ(600, summary.decidedRows, "All 600 rows decided");
    TEST_DBL_NEAR(0.0, summary.ece, 1e-12, "Perfectly calibrated -> ECE 0");
    TEST_DBL_NEAR(0.0, summary.mce, 1e-12, "Perfectly calibrated -> MCE 0");

    double brier = (49.875 + 48.875 + 43.875) / 600.0;
    TEST_DBL_NEAR(brier, summary.brier, 1e-9, "Brier matches closed form");

    int binIdx = FindBin(bins, 0.45, 0.50);
    TEST_TRUE(binIdx >= 0, "Bin [0.45, 0.50) present");
    TEST_INT_EQ(200, bins[binIdx].trades, "Bin trade count 200");
    TEST_DBL_NEAR(0.475, bins[binIdx].winRate, 1e-12, "Win rate matches center");

    TEST_INT_EQ(600, SumBinTrades(bins), "Histogram conservation");
}

//--- Compressed scores: everything claims 0.60 but only 30% win.
void TestReport_CompressedScores(TestCounters &counters)
{
    int n = 400;
    TelemetryRow rows[];
    ArrayResize(rows, n);
    for(int i = 0; i < n; i++)
    {
        bool win = (i < 120);
        FillSettledRow(rows[i], 0.60,
                       win ? (int)TELEMETRY_OUTCOME_WIN : (int)TELEMETRY_OUTCOME_LOSS,
                       win ? 2.0 : -1.0);
    }

    CalibrationBin bins[];
    int binCount = 0;
    CalibrationSummary summary;
    CalibrationAnalyze(rows, n, 0.05, bins, binCount, summary);

    TEST_INT_EQ(1, binCount, "One bin populated");
    TEST_DBL_NEAR(0.325, summary.ece, 1e-12, "ECE = |0.30 - 0.625|");
    TEST_DBL_NEAR(0.325, summary.mce, 1e-12, "MCE equals ECE (single bin)");
    TEST_DBL_NEAR(0.3, summary.brier, 1e-9, "Brier = (120*0.16 + 280*0.36)/400");
    TEST_DBL_NEAR(0.60, summary.confMin, 1e-9, "Conf min");
    TEST_DBL_NEAR(0.60, summary.confMax, 1e-9, "Conf max");
    TEST_DBL_NEAR(0.60, summary.confMean, 1e-9, "Conf mean");
    TEST_DBL_NEAR(0.60, summary.confP50, 1e-9, "Conf P50");
    TEST_DBL_NEAR(0.60, summary.confP90, 1e-9, "Conf P90");
    TEST_INT_EQ(400, SumBinTrades(bins), "Histogram conservation");
}

//--- BREAKEVEN rows count as settled trades but not in winRate;
//    UNKNOWN rows are excluded from the histogram entirely.
void TestReport_BEAndUnknownExcluded(TestCounters &counters)
{
    int n = 4;
    TelemetryRow rows[];
    ArrayResize(rows, n);
    FillSettledRow(rows[0], 0.50, (int)TELEMETRY_OUTCOME_WIN, 2.0);
    FillSettledRow(rows[1], 0.50, (int)TELEMETRY_OUTCOME_LOSS, -1.0);
    FillSettledRow(rows[2], 0.50, (int)TELEMETRY_OUTCOME_BREAKEVEN, 0.0);
    FillSettledRow(rows[3], 0.50, (int)TELEMETRY_OUTCOME_UNKNOWN, 0.0);

    CalibrationBin bins[];
    int binCount = 0;
    CalibrationSummary summary;
    CalibrationAnalyze(rows, n, 0.05, bins, binCount, summary);

    TEST_INT_EQ(4, summary.totalRows, "All rows counted in total");
    TEST_INT_EQ(3, summary.decidedRows, "UNKNOWN excluded from decided");
    TEST_INT_EQ(3, SumBinTrades(bins), "Histogram conservation (BE settled, UNKNOWN out)");

    int binIdx = FindBin(bins, 0.50, 0.55);
    TEST_TRUE(binIdx >= 0, "Bin [0.50, 0.55) present");
    TEST_INT_EQ(3, bins[binIdx].trades, "BE row is a settled trade");
    TEST_INT_EQ(1, bins[binIdx].wins, "One win");
    TEST_INT_EQ(1, bins[binIdx].losses, "One loss");
    TEST_INT_EQ(1, bins[binIdx].scratches, "BE row is a scratch");
    TEST_DBL_NEAR(0.5, bins[binIdx].winRate, 1e-12, "Win rate excludes scratch");
    TEST_DBL_NEAR(0.25, summary.brier, 1e-9, "Brier over WIN/LOSS rows only");
}

//--- Single row: no NaN, underpopulated flag set, MCE = |1 - center|.
void TestReport_EmptyBinsNoNaN(TestCounters &counters)
{
    int n = 1;
    TelemetryRow rows[];
    ArrayResize(rows, n);
    FillSettledRow(rows[0], 0.0, (int)TELEMETRY_OUTCOME_WIN, 2.0);

    CalibrationBin bins[];
    int binCount = 0;
    CalibrationSummary summary;
    CalibrationAnalyze(rows, n, 0.05, bins, binCount, summary);

    TEST_INT_EQ(1, binCount, "Only the [0.00, 0.05) bin populated");
    TEST_INT_EQ(1, summary.underpopulatedBins, "1-row bin flagged underpopulated");
    TEST_DBL_NEAR(1.0, summary.brier, 1e-9, "Brier = (0-1)^2");
    TEST_DBL_NEAR(0.975, summary.ece, 1e-12, "ECE = |1.0 - 0.025|");
    TEST_DBL_NEAR(0.975, summary.mce, 1e-12, "MCE = ECE");
    TEST_INT_EQ(1, SumBinTrades(bins), "Histogram conservation");
}

//--- The user-mandated invariant: sum(bin.trades) == summary.decidedRows
//    across a mixed dataset (wins, losses, BE, UNKNOWN, multiple bins).
void TestReport_HistogramConservation(TestCounters &counters)
{
    int n = 28;
    TelemetryRow rows[];
    ArrayResize(rows, n);
    int k = 0;
    for(int i = 0; i < 10; i++)
        FillSettledRow(rows[k++], 0.42, (i < 6 ? (int)TELEMETRY_OUTCOME_WIN : (int)TELEMETRY_OUTCOME_LOSS),
                       i < 6 ? 2.0 : -1.0);
    for(int i = 0; i < 10; i++)
        FillSettledRow(rows[k++], 0.61, (i < 3 ? (int)TELEMETRY_OUTCOME_WIN : (int)TELEMETRY_OUTCOME_LOSS),
                       i < 3 ? 2.0 : -1.0);
    for(int i = 0; i < 5; i++)
        FillSettledRow(rows[k++], 0.61, (int)TELEMETRY_OUTCOME_BREAKEVEN, 0.0);
    for(int i = 0; i < 3; i++)
        FillSettledRow(rows[k++], 0.61, (int)TELEMETRY_OUTCOME_UNKNOWN, 0.0);

    CalibrationBin bins[];
    int binCount = 0;
    CalibrationSummary summary;
    CalibrationAnalyze(rows, n, 0.05, bins, binCount, summary);

    TEST_INT_EQ(2, binCount, "Two bins populated (0.42 and 0.61 groups)");
    TEST_INT_EQ(25, summary.decidedRows, "Decided = 28 - 3 UNKNOWN");
    TEST_INT_EQ(summary.decidedRows, SumBinTrades(bins),
                "INVARIANT: sum(bin.trades) == summary.decidedRows");
    TEST_INT_EQ(n, summary.totalRows, "Total rows unchanged");
}

//--- Confidence exactly on bin boundaries lands in the correct bin;
//    c == 1.0 lands in the inclusive final bin; near-boundary values
//    (0.5999 / 0.6001) stay on their own side.
void TestReport_BinBoundaries(TestCounters &counters)
{
    int n = 6;
    TelemetryRow rows[];
    ArrayResize(rows, n);
    FillSettledRow(rows[0], 0.0, (int)TELEMETRY_OUTCOME_WIN, 2.0);
    FillSettledRow(rows[1], 0.60, (int)TELEMETRY_OUTCOME_LOSS, -1.0);
    FillSettledRow(rows[2], 0.65, (int)TELEMETRY_OUTCOME_WIN, 2.0);
    FillSettledRow(rows[3], 1.0, (int)TELEMETRY_OUTCOME_WIN, 2.0);
    FillSettledRow(rows[4], 0.5999, (int)TELEMETRY_OUTCOME_WIN, 2.0);
    FillSettledRow(rows[5], 0.6001, (int)TELEMETRY_OUTCOME_LOSS, -1.0);

    CalibrationBin bins[];
    int binCount = 0;
    CalibrationSummary summary;
    CalibrationAnalyze(rows, n, 0.05, bins, binCount, summary);

    int b0 = FindBin(bins, 0.00, 0.05);
    int b11 = FindBin(bins, 0.55, 0.60);
    int b12 = FindBin(bins, 0.60, 0.65);
    int b13 = FindBin(bins, 0.65, 0.70);
    int b20 = FindBin(bins, 1.00, 1.00);

    TEST_TRUE(b0 >= 0 && bins[b0].trades == 1, "c=0.0 in [0.00, 0.05)");
    TEST_TRUE(b11 >= 0 && bins[b11].trades == 1, "c=0.5999 stays in [0.55, 0.60)");
    TEST_TRUE(b12 >= 0 && bins[b12].trades == 2, "c=0.60 and c=0.6001 in [0.60, 0.65)");
    TEST_TRUE(b13 >= 0 && bins[b13].trades == 1, "c=0.65 in [0.65, 0.70)");
    TEST_TRUE(b20 >= 0 && bins[b20].trades == 1, "c=1.0 in inclusive final bin");
    TEST_INT_EQ(5, binCount, "All five bins populated");
    TEST_INT_EQ(6, SumBinTrades(bins), "Histogram conservation");
}

//--- Per-bin expectancy/PF/maxDD match a direct CalibrationComputeStats
//    call over the same rows.
void TestReport_PerBinStatsMatchComputeStats(TestCounters &counters)
{
    int n = 4;
    TelemetryRow rows[];
    ArrayResize(rows, n);
    FillSettledRow(rows[0], 0.72, (int)TELEMETRY_OUTCOME_WIN, 0.9);
    FillSettledRow(rows[1], 0.72, (int)TELEMETRY_OUTCOME_WIN, 1.1);
    FillSettledRow(rows[2], 0.72, (int)TELEMETRY_OUTCOME_LOSS, -1.1);
    FillSettledRow(rows[3], 0.72, (int)TELEMETRY_OUTCOME_WIN, 2.0);

    bool eligible[];
    ArrayResize(eligible, n);
    for(int i = 0; i < n; i++)
        eligible[i] = true;
    TradeStats direct;
    CalibrationComputeStats(rows, eligible, n, direct);

    CalibrationBin bins[];
    int binCount = 0;
    CalibrationSummary summary;
    CalibrationAnalyze(rows, n, 0.05, bins, binCount, summary);

    int binIdx = FindBin(bins, 0.70, 0.75);
    TEST_TRUE(binIdx >= 0, "Bin [0.70, 0.75) present");
    TEST_INT_EQ(4, bins[binIdx].trades, "All rows in the bin");
    TEST_INT_EQ(3, bins[binIdx].wins, "Three wins");
    TEST_INT_EQ(1, bins[binIdx].losses, "One loss");
    TEST_DBL_NEAR(direct.expectancy, bins[binIdx].expectancy, 1e-12, "Expectancy matches");
    TEST_DBL_NEAR(direct.profitFactor, bins[binIdx].profitFactor, 1e-12, "PF matches");
    TEST_DBL_NEAR(direct.maxDrawdown, bins[binIdx].maxDrawdown, 1e-12, "MaxDD matches");
    TEST_DBL_NEAR(direct.winRate, bins[binIdx].winRate, 1e-12, "Win rate matches");
}

// ─── Entry Point ───────────────────────────────────────────────────

TestCounters RunCalibrationReportTests(void)
{
    TestCounters counters;
    SUITE_BEGIN("Calibration Report Tests");

    TestReport_PerfectlyCalibrated(counters);
    TestReport_CompressedScores(counters);
    TestReport_BEAndUnknownExcluded(counters);
    TestReport_EmptyBinsNoNaN(counters);
    TestReport_HistogramConservation(counters);
    TestReport_BinBoundaries(counters);
    TestReport_PerBinStatsMatchComputeStats(counters);

    SUITE_END("Calibration Report Tests");
    return counters;
}
