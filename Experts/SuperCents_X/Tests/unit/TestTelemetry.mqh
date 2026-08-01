#include "../TestAssert.mqh"
#include "../../Telemetry/TelemetryTypes.mqh"
#include "../../Telemetry/ConfigFingerprint.mqh"

// ─── TelemetryTypes ────────────────────────────────────────────────

void TestHeader_ColumnCount(TestCounters &counters)
{
    string parts[];
    int n = StringSplit(TELEMETRY_CSV_HEADER_V1, ',', parts);
    TEST_INT_EQ(45, n, "Frozen v1 header has exactly 45 columns");
    TEST_STR_EQ("schemaVersion", parts[0], "Header starts with schemaVersion");
    TEST_STR_EQ("actualOutcomeSource", parts[44], "Header ends with actualOutcomeSource");
}

void TestRow_ReplayDecisionThreshold(TestCounters &counters)
{
    TelemetryRow row;
    row.confidence = 0.80;
    row.validatorCount = 0;

    TEST_TRUE(row.ReplayDecision(0.70), "Confidence above threshold passes");
    TEST_FALSE(row.ReplayDecision(0.85), "Confidence below threshold fails");
}

void TestRow_ReplayDecisionValidators(TestCounters &counters)
{
    TelemetryRow row;
    row.confidence = 0.80;
    row.validatorCount = 1;
    row.validators[0].name = "TrendValidator";
    row.validators[0].result = FILTER_FAIL;

    TEST_FALSE(row.ReplayDecision(0.70), "Failing validator rejects decision");
    row.validators[0].result = FILTER_PASS;
    TEST_FALSE(row.ReplayDecision(0.95), "Below threshold rejected even if validators pass");
}

void TestRow_ConfluenceGateSkipped(TestCounters &counters)
{
    TelemetryRow row;
    row.confidence = 0.80;
    row.validatorCount = 2;
    row.validators[0].name = "ConfluenceValidator";
    row.validators[0].result = FILTER_FAIL;
    row.validators[1].name = "RiskValidator";
    row.validators[1].result = FILTER_PASS;

    //--- The stored confluence result must be ignored — the threshold is the gate.
    TEST_TRUE(row.ReplayDecision(0.70), "ConfluenceValidator result ignored in replay");
}

void TestRow_ReplayConfidence(TestCounters &counters)
{
    TelemetryRow row;
    row.SetComponent(COMPONENT_STRUCTURE, 0.80, 25.0, 0.20);
    row.SetComponent(COMPONENT_TREND, 0.60, 15.0, 0.09);

    double w[6];
    w[0] = 25.0; w[1] = 20.0; w[2] = 15.0;
    w[3] = 15.0; w[4] = 15.0; w[5] = 10.0;

    double conf = row.ReplayConfidence(w);
    TEST_DBL_NEAR(0.20 + 0.09, conf, 1e-9, "ReplayConfidence sums weighted components");
}

void TestRow_PackUnpackValidators(TestCounters &counters)
{
    TelemetryRow row;
    row.validatorCount = 3;
    row.validators[0].name = "TrendValidator";
    row.validators[0].result = FILTER_PASS;
    row.validators[1].name = "LiquidityValidator";
    row.validators[1].result = FILTER_FAIL;
    row.validators[2].name = "CooldownValidator";
    row.validators[2].result = FILTER_WARNING;

    string packed = row.PackValidatorResults();
    TEST_STR_EQ("TrendValidator=0|LiquidityValidator=2|CooldownValidator=1", packed,
                "Pack produces stable Name=result pipe-joined string");

    TelemetryRow copy;
    bool ok = copy.UnpackValidatorResults(packed);
    TEST_TRUE(ok, "Unpack succeeds");
    TEST_INT_EQ(3, copy.validatorCount, "Unpack restores count");
    TEST_INT_EQ(FILTER_FAIL, copy.GetValidatorResult("LiquidityValidator"), "Unpack restores result");
    TEST_TRUE(copy.HasValidatorResult("TrendValidator"), "HasValidatorResult true for present");
    TEST_FALSE(copy.HasValidatorResult("MissingValidator"), "HasValidatorResult false for absent");
}

void TestRow_ReservedFieldsEmpty(TestCounters &counters)
{
    TelemetryRow row;
    TEST_INT_EQ(0, (int)row.actualOutcome, "actualOutcome starts UNKNOWN (reserved)");
    TEST_INT_EQ(0, (int)row.actualOutcomeSource, "actualOutcomeSource starts NONE (reserved)");
}

// ─── ConfigFingerprint ─────────────────────────────────────────────

void TestFingerprint_Deterministic(TestCounters &counters)
{
    CalibrationConfig cfg;
    string symbol = "EURUSD";
    int tf = PERIOD_H1;

    ulong a = CConfigFingerprint::Compute(cfg, symbol, tf, "FixedRR", "1");
    ulong b = CConfigFingerprint::Compute(cfg, symbol, tf, "FixedRR", "1");
    TEST_DBL_EQ((double)a, (double)b, "Same config yields the same fingerprint");
}

void TestFingerprint_SensitiveToSpreadMode(TestCounters &counters)
{
    CalibrationConfig cfg;
    ulong quote = CConfigFingerprint::Compute(cfg, "EURUSD", PERIOD_H1, "FixedRR", "1");
    cfg.spreadMode = "tick";
    ulong tick = CConfigFingerprint::Compute(cfg, "EURUSD", PERIOD_H1, "FixedRR", "1");
    TEST_FALSE(quote == tick, "Spread mode participates in the fingerprint");
}

void TestFingerprint_SensitiveToDigits(TestCounters &counters)
{
    CalibrationConfig cfg;
    ulong five = CConfigFingerprint::Compute(cfg, "EURUSD", PERIOD_H1, "FixedRR", "1");
    cfg.brokerDigits = 3;
    ulong three = CConfigFingerprint::Compute(cfg, "EURUSD", PERIOD_H1, "FixedRR", "1");
    TEST_FALSE(five == three, "Broker digits participate in the fingerprint");
}

void TestFingerprint_SensitiveToPolicyVersion(TestCounters &counters)
{
    CalibrationConfig cfg;
    ulong v1 = CConfigFingerprint::Compute(cfg, "EURUSD", PERIOD_H1, "FixedRR", "1");
    ulong v2 = CConfigFingerprint::Compute(cfg, "EURUSD", PERIOD_H1, "FixedRR", "2");
    TEST_FALSE(v1 == v2, "Exit policy version participates in the fingerprint");
}

void TestFingerprint_SortDisabledValidators(TestCounters &counters)
{
    string sorted = CConfigFingerprint::SortDisabledValidators("ZebraValidator,alphaValidator,CooldownValidator");
    TEST_STR_EQ("CooldownValidator,ZebraValidator,alphaValidator", sorted,
                "Sort is canonical (uppercase before lowercase)");
    TEST_STR_EQ("", CConfigFingerprint::SortDisabledValidators(""), "Empty input stays empty");
}

void TestFingerprint_CanonicalUnorderedDisabled(TestCounters &counters)
{
    CalibrationConfig cfg;
    cfg.disabledValidators = "B,A";
    ulong ab = CConfigFingerprint::Compute(cfg, "EURUSD", PERIOD_H1, "FixedRR", "1");
    cfg.disabledValidators = "A,B";
    ulong ba = CConfigFingerprint::Compute(cfg, "EURUSD", PERIOD_H1, "FixedRR", "1");
    TEST_DBL_EQ((double)ab, (double)ba, "Disabled-validator order does not change the fingerprint");
}

// ─── Entry Point ───────────────────────────────────────────────────

TestCounters RunTelemetryTests()
{
    TestCounters counters;
    SUITE_BEGIN("Telemetry Schema & Fingerprint Tests");

    TestHeader_ColumnCount(counters);
    TestRow_ReplayDecisionThreshold(counters);
    TestRow_ReplayDecisionValidators(counters);
    TestRow_ConfluenceGateSkipped(counters);
    TestRow_ReplayConfidence(counters);
    TestRow_PackUnpackValidators(counters);
    TestRow_ReservedFieldsEmpty(counters);
    TestFingerprint_Deterministic(counters);
    TestFingerprint_SensitiveToSpreadMode(counters);
    TestFingerprint_SensitiveToDigits(counters);
    TestFingerprint_SensitiveToPolicyVersion(counters);
    TestFingerprint_SortDisabledValidators(counters);
    TestFingerprint_CanonicalUnorderedDisabled(counters);

    SUITE_END("Telemetry Schema & Fingerprint Tests");
    return counters;
}
