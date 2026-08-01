#include "../TestAssert.mqh"
#include "../../Calibration/CalibrationStructural.mqh"

//--- Fill one settled row with confidence/outcome and component data.
//    raws/weights use the weight-array order (S, OB, FVG, Liq, Trend, PD).
void FillSRow(TelemetryRow &row, double conf, int outcome, double r,
              const double &raws[], const double &weights[])
{
    row = TelemetryRow();
    row.confidence = conf;
    row.outcome = outcome;
    row.rMultiple = r;
    row.validatorCount = 0;
    for(int c = 0; c < TELEMETRY_COMPONENT_COUNT; c++)
        row.SetComponent(CalibrationStructuralToEnum(c), raws[c], weights[c],
                         raws[c] * weights[c] / 100.0);
}

//--- Spearman on perfectly monotone data: rho = +1; inverted: rho = -1.
void TestStructural_SpearmanPerfect(TestCounters &counters)
{
    int n = 8;
    double a[], b[], c[];
    ArrayResize(a, n); ArrayResize(b, n); ArrayResize(c, n);
    for(int i = 0; i < n; i++)
    {
        a[i] = (double)i;
        b[i] = (double)i * 2.0 + 1.0;
        c[i] = (double)(n - 1 - i);
    }
    TEST_DBL_NEAR(1.0, CalibrationSpearman(a, b, n), 1e-9, "Perfect monotone -> rho 1");
    TEST_DBL_NEAR(-1.0, CalibrationSpearman(a, c, n), 1e-9, "Inverted -> rho -1");
    TEST_DBL_NEAR(0.0, CalibrationSpearman(a, b, 2), 0.0, "n < 3 -> 0");
}

//--- Average-rank tie handling: ranks of (10,20,20,30) = (1, 2.5, 2.5, 4).
void TestStructural_AvgRanks(TestCounters &counters)
{
    int n = 4;
    double v[];
    ArrayResize(v, n);
    v[0] = 10.0; v[1] = 20.0; v[2] = 20.0; v[3] = 30.0;
    double ranks[];
    CalibrationRanks(v, n, ranks);
    TEST_DBL_NEAR(1.0, ranks[0], 1e-9, "Rank of 10 = 1");
    TEST_DBL_NEAR(2.5, ranks[1], 1e-9, "Rank of 20 (first) = 2.5");
    TEST_DBL_NEAR(2.5, ranks[2], 1e-9, "Rank of 20 (second) = 2.5");
    TEST_DBL_NEAR(4.0, ranks[3], 1e-9, "Rank of 30 = 4");
}

//--- Spearman with ties (known value): (1,1,2,3) vs (1,2,2,4).
//    Ranks a = (1.5,1.5,3,4), b = (1,2.5,2.5,4):
//    d = (-0.5,-1,0.5,0) -> sumD2 = 0.25+1+0.25 = 1.5
//    rho = 1 - 6*1.5/(4*15) = 1 - 9/60 = 0.85
void TestStructural_SpearmanTies(TestCounters &counters)
{
    int n = 4;
    double a[], b[];
    ArrayResize(a, n); ArrayResize(b, n);
    a[0] = 1.0; a[1] = 1.0; a[2] = 2.0; a[3] = 3.0;
    b[0] = 1.0; b[1] = 2.0; b[2] = 2.0; b[3] = 4.0;
    TEST_DBL_NEAR(0.85, CalibrationSpearman(a, b, n), 1e-9, "Tied ranks handled (rho 0.85)");
}

//--- Kendall tau-b: perfect = 1, inverted = -1; tied example known.
void TestStructural_KendallPerfect(TestCounters &counters)
{
    int n = 6;
    double a[], b[], c[];
    ArrayResize(a, n); ArrayResize(b, n); ArrayResize(c, n);
    for(int i = 0; i < n; i++)
    {
        a[i] = (double)i;
        b[i] = (double)i + 5.0;
        c[i] = (double)(n - 1 - i);
    }
    TEST_DBL_NEAR(1.0, CalibrationKendallTau(a, b, n), 1e-9, "Perfect -> tau 1");
    TEST_DBL_NEAR(-1.0, CalibrationKendallTau(a, c, n), 1e-9, "Inverted -> tau -1");
    TEST_DBL_NEAR(0.0, CalibrationKendallTau(a, b, 2), 0.0, "n < 3 -> 0");

    //--- a = (1,1,2,3), b = (1,2,2,4): pairs (4 choose 2 = 6):
    //    (1,2): x tie, y 1<2 -> tiesB
    //    (1,3): x 1<2, y 1<2 -> concordant
    //    (1,4): x 1<3, y 1<4 -> concordant
    //    (2,3): x 1<2, y 2=2 -> tiesA
    //    (2,4): x 1<3, y 2<4 -> concordant
    //    (3,4): x 2<3, y 2<4 -> concordant
    //    P=4, Q=0, tiesA=1, tiesB=1 -> tau = 4/sqrt((4+0+1)(4+0+1)) = 0.8
    int m = 4;
    double x[], y[];
    ArrayResize(x, m); ArrayResize(y, m);
    x[0] = 1.0; x[1] = 1.0; x[2] = 2.0; x[3] = 3.0;
    y[0] = 1.0; y[1] = 2.0; y[2] = 2.0; y[3] = 4.0;
    TEST_DBL_NEAR(0.8, CalibrationKendallTau(x, y, m), 1e-9, "Tied example (tau 0.8)");
}

//--- Component activation + fired count on synthetic rows.
void TestStructural_ActivationAndFired(TestCounters &counters)
{
    int n = 60;
    TelemetryRow rows[];
    ArrayResize(rows, n);
    for(int i = 0; i < n; i++)
    {
        double raws[6];
        double weights[6];
        for(int c = 0; c < TELEMETRY_COMPONENT_COUNT; c++)
        {
            weights[c] = 15.0;
            raws[c] = 0.0;
        }
        int fired = (i < 20) ? 1 : (i < 40) ? 2 : 3;
        for(int c = 0; c < fired; c++)
            raws[c] = 60.0;
        bool win = (fired >= 2);
        double conf = 0.40 + 0.05 * (double)fired;
        FillSRow(rows[i], conf, win ? (int)TELEMETRY_OUTCOME_WIN : (int)TELEMETRY_OUTCOME_LOSS,
                 win ? 1.0 : -1.0, raws, weights);
    }

    StructuralComponentStat comps[];
    CalibrationStructuralComponents(rows, n, comps);
    TEST_INT_EQ(60, comps[0].activeRows, "Structure active in all 60 rows");
    TEST_DBL_NEAR(100.0, comps[0].activationPct, 1e-9, "Structure activation pct 100%");
    TEST_INT_EQ(40, comps[1].activeRows, "OrderBlock active in 40 rows");
    TEST_INT_EQ(20, comps[2].activeRows, "FVG active in 20 rows");
    TEST_INT_EQ(0, comps[0].absentTrades, "No rows without structure");

    StructuralFiredCount fired[];
    CalibrationStructuralFiredCounts(rows, n, fired);
    TEST_INT_EQ(20, fired[1].trades, "Fired=1 group has 20 trades");
    TEST_INT_EQ(20, fired[2].trades, "Fired=2 group has 20 trades");
    TEST_INT_EQ(20, fired[3].trades, "Fired=3 group has 20 trades");
    TEST_DBL_NEAR(1.0, fired[3].winRate, 1e-9, "Fired=3 group all wins");
    TEST_DBL_NEAR(0.0, fired[1].winRate, 1e-9, "Fired=1 group all losses");
    TEST_TRUE(fired[3].meanConf > fired[1].meanConf, "Confidence grows with fired count");
}

//--- Rank correlations on synthetic rows: confidence correlates with win prob.
void TestStructural_RankCorrelations(TestCounters &counters)
{
    MathSrand(42);
    int n = 800;
    TelemetryRow rows[];
    ArrayResize(rows, n);
    for(int i = 0; i < n; i++)
    {
        double raws[6];
        double weights[6];
        for(int c = 0; c < TELEMETRY_COMPONENT_COUNT; c++)
        {
            weights[c] = 15.0;
            raws[c] = 0.0;
        }
        //--- win probability monotone in confidence (0.02..0.98).
        double pWin = 0.02 + 0.96 * (double)(i % 100) / 99.0;
        double conf = 0.35 + 0.25 * (double)(i % 100) / 99.0;
        bool win = ((MathRand() % 1000) < (int)(pWin * 1000.0));
        //--- rMultiple deterministic monotone in pWin (tests the rank
        //    machinery exactly); the binary win/loss tests the wl path.
        double r = pWin * 2.0 - 1.0;
        raws[0] = conf * 100.0;
        FillSRow(rows[i], conf, win ? (int)TELEMETRY_OUTCOME_WIN : (int)TELEMETRY_OUTCOME_LOSS,
                 r, raws, weights);
    }

    StructuralCorrelation corr[];
    CalibrationStructuralCorrelations(rows, n, corr);
    TEST_INT_EQ(4 + TELEMETRY_COMPONENT_COUNT, ArraySize(corr), "Correlation table size");
    TEST_TRUE(corr[0].value > 0.99, "Spearman conf vs r ~1 (monotone targets)");
    TEST_TRUE(corr[1].value > 0.99, "Kendall conf vs r ~1 (monotone targets)");
    TEST_TRUE(corr[2].value > 0.45, "Spearman conf vs win/loss positive");
    TEST_TRUE(corr[3].value > 0.30, "Kendall conf vs win/loss positive");
}

//--- Ablation: a dominant component's removal drops gate trades; an
//    inactive component (weight 0) is exactly neutral.
void TestStructural_AblationDominant(TestCounters &counters)
{
    int n = 100;
    TelemetryRow rows[];
    ArrayResize(rows, n);
    for(int i = 0; i < n; i++)
    {
        double raws[6];
        double weights[6];
        for(int c = 0; c < TELEMETRY_COMPONENT_COUNT; c++)
        {
            weights[c] = 0.0;
            raws[c] = 0.0;
        }
        //--- structure 80%, OB 20% -> full replay 0.56 + 0.06 = 0.62.
        weights[0] = 80.0;
        weights[1] = 20.0;
        raws[0] = 70.0;
        raws[1] = 30.0;
        bool win = (i < 60);
        FillSRow(rows[i], 0.62, win ? (int)TELEMETRY_OUTCOME_WIN : (int)TELEMETRY_OUTCOME_LOSS,
                 win ? 2.0 : -1.0, raws, weights);
    }

    StructuralAblation abl[];
    CalibrationStructuralAblation(rows, n, 0.60, abl);

    //--- Baseline: conf 0.62 >= 0.60 for all rows -> 100 trades.
    TEST_INT_EQ(100, (int)abl[0].baselineTrades, "Baseline gate takes all 100");
    //--- Structure removed: replay 0.06 -> 0 trades; OB removed: 0.56 -> 0 trades.
    TEST_INT_EQ(0, (int)abl[0].looTrades, "Dominant component removed -> no trades");
    TEST_INT_EQ(0, (int)abl[1].looTrades, "OB removed -> score drops below gate");
    //--- Inactive component (fvg): replay unchanged (0.62) -> fully neutral.
    TEST_INT_EQ(100, (int)abl[2].looTrades, "Inactive component removal is neutral");
    TEST_DBL_NEAR(0.0, abl[2].deltaTrades, 1e-9, "No trade delta for inactive component");
    TEST_DBL_NEAR(0.0, abl[2].deltaExp, 1e-9, "No expectancy delta for inactive component");
    //--- Dominant component carries the population: large negative deltas.
    TEST_TRUE(abl[0].deltaTrades < -90.0, "Structure removal is a large negative delta");
    TEST_TRUE(abl[0].infoContrib > abl[2].infoContrib,
              "Information contribution of structure exceeds inactive component");
}

//--- Replay confidence: LOO zeroes a weight, alone isolates a component.
void TestStructural_ReplayConfidence(TestCounters &counters)
{
    TelemetryRow row = TelemetryRow();
    double raws[6];
    double weights[6];
    for(int c = 0; c < TELEMETRY_COMPONENT_COUNT; c++)
    {
        weights[c] = 10.0;
        raws[c] = 0.0;
    }
    raws[0] = 60.0;   // contributes 6.0
    raws[1] = 80.0;   // contributes 8.0
    row.SetComponent(CalibrationStructuralToEnum(0), raws[0], weights[0], 6.0);
    row.SetComponent(CalibrationStructuralToEnum(1), raws[1], weights[1], 8.0);

    //--- Full score (weights 10 each -> total 60): 14.0/100? No: 60/100+80/100 = 1.4 -> 100 clamp.
    //    weights sum = 60, raw*weight/100: 60*10/100 + 80*10/100 = 6 + 8 = 14 -> conf 0.14.
    double full = CalibrationStructuralReplay(row, -1, -1);
    TEST_DBL_NEAR(0.14, full, 1e-9, "Full replay = 0.14");

    double loo0 = CalibrationStructuralReplay(row, 0, -1);
    TEST_DBL_NEAR(0.08, loo0, 1e-9, "Structure removed -> 0.08");

    double alone1 = CalibrationStructuralReplay(row, -1, 1);
    TEST_DBL_NEAR(0.08, alone1, 1e-9, "OrderBlock alone -> 0.08");

    double alone0 = CalibrationStructuralReplay(row, -1, 0);
    TEST_DBL_NEAR(0.06, alone0, 1e-9, "Structure alone -> 0.06");
}

TestCounters RunCalibrationStructuralTests(void)
{
    TestCounters counters;
    SUITE_BEGIN("Calibration Structural Tests");

    TestStructural_SpearmanPerfect(counters);
    TestStructural_AvgRanks(counters);
    TestStructural_SpearmanTies(counters);
    TestStructural_KendallPerfect(counters);
    TestStructural_ActivationAndFired(counters);
    TestStructural_RankCorrelations(counters);
    TestStructural_AblationDominant(counters);
    TestStructural_ReplayConfidence(counters);

    SUITE_END("Calibration Structural Tests");
    return counters;
}
