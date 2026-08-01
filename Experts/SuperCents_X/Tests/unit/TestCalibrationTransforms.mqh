#include "../TestAssert.mqh"
#include "../../Calibration/CalibrationReport.mqh"
#include "../../Calibration/CalibrationTransforms.mqh"

//--- Fill one settled row with the given confidence/outcome.
void FillTRow(TelemetryRow &row, double conf, int outcome, double r)
{
    row = TelemetryRow();
    row.confidence = conf;
    row.outcome = outcome;
    row.rMultiple = r;
    row.validatorCount = 0;
}

//--- Overconfident dataset: everything claims 0.60 but only 30% win.
void BuildOverconfident(TelemetryRow &rows[], int &n, int extraScratches = 0, int extraUnknown = 0)
{
    n = 100 + extraScratches + extraUnknown;
    ArrayResize(rows, n);
    for(int i = 0; i < 100; i++)
    {
        bool win = (i < 30);
        FillTRow(rows[i], 0.60,
                 win ? (int)TELEMETRY_OUTCOME_WIN : (int)TELEMETRY_OUTCOME_LOSS,
                 win ? 2.0 : -1.0);
    }
    for(int i = 100; i < 100 + extraScratches; i++)
        FillTRow(rows[i], 0.60, (int)TELEMETRY_OUTCOME_BREAKEVEN, 0.0);
    for(int i = 100 + extraScratches; i < n; i++)
        FillTRow(rows[i], 0.60, (int)TELEMETRY_OUTCOME_UNKNOWN, 0.0);
}

double ApplyMean(const CalibrationTransformParams &p, const double &confs[], int n)
{
    double s = 0.0;
    for(int i = 0; i < n; i++)
        s += CalibrationTransformApply(confs[i], p);
    return s / (double)n;
}

//--- Isotonic fit is monotone non-decreasing and reduces ECE on the
//    overconfident dataset (Calibration Gain).
void TestTransform_IsotonicMonotoneAndGain(TestCounters &counters)
{
    TelemetryRow rows[];
    int n = 0;
    BuildOverconfident(rows, n);

    CalibrationTransformParams p;
    bool ok = CalibrationFitIsotonic(rows, n, p);
    TEST_TRUE(ok, "Isotonic fit succeeds");
    TEST_INT_EQ(CALIB_TRANSFORM_ISOTONIC_V1, p.type, "Model type recorded");
    TEST_INT_EQ(1, p.nodeCount, "Single block (one unique confidence)");
    TEST_DBL_NEAR(0.30, p.nodesY[0], 1e-9, "Fitted value = empirical win rate");

    double confs[9] = { 0.10, 0.30, 0.55, 0.599, 0.60, 0.61, 0.70, 0.90, 1.00 };
    double prev = -1.0;
    bool monotone = true;
    for(int i = 0; i < 9; i++)
    {
        double v = CalibrationTransformApply(confs[i], p);
        if(v < prev - 1e-12)
            monotone = false;
        prev = v;
    }
    TEST_TRUE(monotone, "Apply is monotone non-decreasing");
    TEST_DBL_NEAR(0.30, CalibrationTransformApply(0.60, p), 1e-9, "0.60 maps to fitted 0.30");
    TEST_DBL_NEAR(0.30, CalibrationTransformApply(0.9, p), 1e-9, "Above support clamps to last node");

    //--- Calibration Gain on the transformed score.
    TelemetryRow trows[];
    ArrayResize(trows, n);
    for(int i = 0; i < n; i++)
    {
        trows[i] = rows[i];
        trows[i].confidence = CalibrationTransformApply(rows[i].confidence, p);
    }
    CalibrationBin bins[];
    int binCount = 0;
    CalibrationSummary summary;
    CalibrationAnalyze(trows, n, 0.05, bins, binCount, summary);

    TEST_DBL_NEAR(0.025, summary.ece, 1e-9, "Transformed ECE |0.30 - 0.325|");
    TEST_TRUE(summary.ece < 0.05, "ECE after isotonic near zero");
}

//--- Platt scaling recovers a positive monotone mapping and yields
//    calibration gain on a dataset with a genuine confidence signal.
void TestTransform_PlattRecovers(TestCounters &counters)
{
    int n = 200;
    TelemetryRow rows[];
    ArrayResize(rows, n);
    for(int i = 0; i < n; i++)
    {
        double x = 0.35 + (double)(i % 25) / 25.0 * 0.25;
        double pWin = CalibrationSigmoid(2.0 * x - 1.0);
        bool win = ((i * 7) % 100) < (int)(pWin * 100.0);
        FillTRow(rows[i], x, win ? (int)TELEMETRY_OUTCOME_WIN : (int)TELEMETRY_OUTCOME_LOSS,
                 win ? 2.0 : -1.0);
    }

    CalibrationTransformParams p;
    bool ok = CalibrationFitPlatt(rows, n, p);
    TEST_TRUE(ok, "Platt fit succeeds");
    TEST_TRUE(p.a > 0.3, "Fitted slope is positive (higher conf -> higher win rate)");

    //--- Raw ECE vs transformed ECE on the same rows.
    CalibrationBin rawBins[];
    int rawBinCount = 0;
    CalibrationSummary rawSummary;
    CalibrationAnalyze(rows, n, 0.05, rawBins, rawBinCount, rawSummary);

    TelemetryRow trows[];
    ArrayResize(trows, n);
    for(int i = 0; i < n; i++)
    {
        trows[i] = rows[i];
        trows[i].confidence = CalibrationTransformApply(rows[i].confidence, p);
    }
    CalibrationBin bins[];
    int binCount = 0;
    CalibrationSummary summary;
    CalibrationAnalyze(trows, n, 0.05, bins, binCount, summary);

    TEST_TRUE(summary.ece < rawSummary.ece - 0.005, "Calibration gain on the fit set");
}

void TestTransform_PlattOverconfidentGain(TestCounters &counters)
{
    TelemetryRow rows[];
    int n = 0;
    BuildOverconfident(rows, n);

    CalibrationTransformParams p;
    TEST_TRUE(CalibrationFitPlatt(rows, n, p), "Platt fit succeeds");
    TEST_DBL_NEAR(0.0, p.a, 1e-9, "Degenerate x -> bias-only model (a = 0)");
    TEST_DBL_NEAR(0.30, CalibrationSigmoid(p.b), 1e-9, "Bias maps to empirical win rate");

    TelemetryRow trows[];
    ArrayResize(trows, n);
    for(int i = 0; i < n; i++)
    {
        trows[i] = rows[i];
        trows[i].confidence = CalibrationTransformApply(rows[i].confidence, p);
    }
    CalibrationBin bins[];
    int binCount = 0;
    CalibrationSummary summary;
    CalibrationAnalyze(trows, n, 0.05, bins, binCount, summary);

    //--- All rows share one confidence, so transformed ECE is small.
    TEST_TRUE(summary.ece < 0.05, "ECE after Platt near zero");
    double rawEce = 0.325;
    TEST_TRUE(rawEce - summary.ece > 0.25, "Calibration Gain dECE > 0.25");
}

//--- Temperature scaling flattens an overconfident score: T > 1 and the
//    mapped mean tracks the empirical win rate.
void TestTransform_TemperatureFlattens(TestCounters &counters)
{
    TelemetryRow rows[];
    int n = 0;
    BuildOverconfident(rows, n);

    CalibrationTransformParams p;
    TEST_TRUE(CalibrationFitTemperature(rows, n, p), "Temperature fit succeeds");
    TEST_TRUE(MathExp(p.t) > 1.0, "T > 1 for overconfident input");

    double confs[3] = { 0.55, 0.60, 0.60 };
    TEST_DBL_NEAR(0.30, ApplyMean(p, confs, 3), 0.05, "Mapped mean tracks 30% win rate");
}

//--- Apply always returns [0, 1] and clamps outside fit support.
void TestTransform_Clamping(TestCounters &counters)
{
    TelemetryRow rows[];
    int n = 0;
    BuildOverconfident(rows, n);
    CalibrationTransformParams p;
    CalibrationFitIsotonic(rows, n, p);

    double probe[7] = { -1.0, 0.0, 0.25, 0.60, 0.75, 1.0, 1.5 };
    bool inRange = true;
    for(int i = 0; i < 7; i++)
    {
        double v = CalibrationTransformApply(probe[i], p);
        if(v < 0.0 || v > 1.0)
            inRange = false;
    }
    TEST_TRUE(inRange, "Apply clamps to [0, 1]");
}

//--- Serialized params round-trip exactly and re-apply identically.
void TestTransform_SerializeRoundTrip(TestCounters &counters)
{
    int n = 200;
    TelemetryRow rows[];
    ArrayResize(rows, n);
    for(int i = 0; i < n; i++)
    {
        double x = 0.35 + (double)(i % 25) / 25.0 * 0.25;
        bool win = ((i * 7) % 100) < (int)(CalibrationSigmoid(2.0 * x - 1.0) * 100.0);
        FillTRow(rows[i], x, win ? (int)TELEMETRY_OUTCOME_WIN : (int)TELEMETRY_OUTCOME_LOSS,
                 win ? 2.0 : -1.0);
    }

    CalibrationTransformParams p;
    CalibrationFitPlatt(rows, n, p);

    string lines[];
    CalibrationTransformSerialize(p, lines);

    CalibrationTransformParams q;
    bool ok = CalibrationTransformDeserialize(lines, q);
    TEST_TRUE(ok, "Deserialize succeeds");
    TEST_INT_EQ(p.type, q.type, "Type round-trips");
    TEST_DBL_NEAR(p.a, q.a, 1e-9, "Slope round-trips");
    TEST_DBL_NEAR(p.b, q.b, 1e-9, "Intercept round-trips");

    double confs[4] = { 0.35, 0.44, 0.52, 0.60 };
    bool same = true;
    for(int i = 0; i < 4; i++)
    {
        if(MathAbs(CalibrationTransformApply(confs[i], p) -
                   CalibrationTransformApply(confs[i], q)) > 1e-9)
            same = false;
    }
    TEST_TRUE(same, "Re-application identical after round-trip");
}

//--- Same data, two fits -> identical parameters (reproducibility).
void TestTransform_Determinism(TestCounters &counters)
{
    TelemetryRow rows[];
    int n = 0;
    BuildOverconfident(rows, n);

    CalibrationTransformParams p1;
    CalibrationTransformParams p2;
    CalibrationFitTemperature(rows, n, p1);
    CalibrationFitTemperature(rows, n, p2);

    TEST_DBL_NEAR(p1.t, p2.t, 1e-12, "Temperature identical across fits");
    TEST_DBL_NEAR(p1.b, p2.b, 1e-12, "Bias identical across fits");
}

//--- Scratches and UNKNOWN rows never enter the fit.
void TestTransform_ScratchesExcluded(TestCounters &counters)
{
    TelemetryRow rows[];
    int n = 0;
    BuildOverconfident(rows, n, 100, 10);

    CalibrationTransformParams p;
    TEST_TRUE(CalibrationFitIsotonic(rows, n, p), "Fit succeeds with scratch/unknown rows");
    TEST_DBL_NEAR(0.30, p.nodesY[0], 1e-9,
                  "Fitted rate = 30/100 (scratches/unknown excluded, not 30/210)");
}

//--- All-wins input: PAV yields a constant 1.0 mapping (one knot per
//    distinct confidence, all equal to 1.0).
void TestTransform_AllSameClass(TestCounters &counters)
{
    int n = 50;
    TelemetryRow rows[];
    ArrayResize(rows, n);
    for(int i = 0; i < n; i++)
        FillTRow(rows[i], 0.40 + (double)(i % 10) / 100.0, (int)TELEMETRY_OUTCOME_WIN, 2.0);

    CalibrationTransformParams p;
    TEST_TRUE(CalibrationFitIsotonic(rows, n, p), "All-win fit succeeds");
    TEST_INT_EQ(10, p.nodeCount, "One knot per distinct confidence (no violations to merge)");
    bool allOne = true;
    for(int k = 0; k < p.nodeCount; k++)
    {
        if(MathAbs(p.nodesY[k] - 1.0) > 1e-12)
            allOne = false;
    }
    TEST_TRUE(allOne, "All knots equal 1.0");
    TEST_DBL_NEAR(1.0, CalibrationTransformApply(0.5, p), 1e-9, "Maps to 1.0");
}

// ─── Entry Point ───────────────────────────────────────────────────

TestCounters RunCalibrationTransformsTests(void)
{
    TestCounters counters;
    SUITE_BEGIN("Calibration Transforms Tests");

    TestTransform_IsotonicMonotoneAndGain(counters);
    TestTransform_PlattRecovers(counters);
    TestTransform_PlattOverconfidentGain(counters);
    TestTransform_TemperatureFlattens(counters);
    TestTransform_Clamping(counters);
    TestTransform_SerializeRoundTrip(counters);
    TestTransform_Determinism(counters);
    TestTransform_ScratchesExcluded(counters);
    TestTransform_AllSameClass(counters);

    SUITE_END("Calibration Transforms Tests");
    return counters;
}
