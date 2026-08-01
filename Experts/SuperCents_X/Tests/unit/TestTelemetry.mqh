#include "../TestAssert.mqh"
#include "../../Telemetry/TelemetryTypes.mqh"
#include "../../Telemetry/ConfigFingerprint.mqh"
#include "../../Telemetry/TelemetryRowBuilder.mqh"

// ─── TelemetryTypes ────────────────────────────────────────────────

void TestHeader_ColumnCount(TestCounters &counters)
{
    string parts[];
    int n = StringSplit(TELEMETRY_CSV_HEADER_V1, ',', parts);
    TEST_INT_EQ(45, n, "Frozen v1 header has exactly 45 columns");
    TEST_STR_EQ("schemaVersion", parts[0], "Header starts with schemaVersion");
    TEST_STR_EQ("actualOutcomeSource", parts[44], "Header ends with actualOutcomeSource");
}

// ─── v2.9.2 schema + row builder ───────────────────────────────────

void TestHeader_V2ColumnCount(TestCounters &counters)
{
    string parts[];
    int n = StringSplit(TELEMETRY_CSV_HEADER_V2, ',', parts);
    TEST_INT_EQ(45, n, "Frozen v2 header has exactly 45 columns");
    TEST_STR_EQ("schemaVersion", parts[0], "v2 header starts with schemaVersion");
    TEST_STR_EQ("actualOutcomeSource", parts[44], "v2 header ends with actualOutcomeSource");
}

void TestSchema_Version2(TestCounters &counters)
{
    TEST_INT_EQ(2, TELEMETRY_SCHEMA_VERSION, "Active schema version is 2");
    TEST_STR_EQ("v2.9.2", TELEMETRY_EA_VERSION, "EA version string updated");
}

ConfluenceResult MakeTestConfluence(void)
{
    ConfluenceResult cr;
    cr.valid = true;
    cr.direction = CONFLUENCE_BULLISH;
    cr.totalConfidence = 40.0;
    cr.componentCount = 2;
    cr.components[0].type = COMPONENT_STRUCTURE;
    cr.components[0].score = 80.0;
    cr.components[0].weight = 25.0;
    cr.components[0].contribution = 20.0;
    cr.components[1].type = COMPONENT_TREND;
    cr.components[1].score = 60.0;
    cr.components[1].weight = 15.0;
    cr.components[1].contribution = 9.0;
    return cr;
}

void TestRowBuilder_NormalizedConfidence(TestCounters &counters)
{
    ConfluenceResult cr = MakeTestConfluence();
    EntryDecision newDec;
    newDec.status = DECISION_QUALIFIED;
    newDec.confidence = 0.40;
    newDec.direction = CONFLUENCE_BULLISH;
    EntryDecision legacyDec;
    legacyDec.status = DECISION_QUALIFIED;
    legacyDec.confidence = 0.40;
    legacyDec.direction = CONFLUENCE_BULLISH;

    ConfluenceWeights w;
    TelemetryRow row;
    bool ok = CTelemetryRowBuilder::Build(row, cr, newDec, true, legacyDec, 0.60,
                                          w, "EURUSD", (int)PERIOD_H1, "", "tick", 5);
    TEST_TRUE(ok, "Build succeeds");
    TEST_INT_EQ(2, (int)row.schemaVersion, "Row stamped schema v2");
    TEST_DBL_NEAR(0.40, row.confidence, 1e-9, "confidence column normalized 0-1");
    TEST_DBL_NEAR(0.40, row.legacyConfidence, 1e-9, "legacyConfidence normalized 0-1 (was 0-100 in v1)");
    TEST_DBL_NEAR(0.40, row.newConfidence, 1e-9, "newConfidence 0-1");
    TEST_DBL_NEAR(0.60, row.confThreshold, 1e-9, "confThreshold preserved");
    TEST_TRUE(row.newDecision, "qualified new decision recorded");
    TEST_TRUE(row.legacyDecision, "qualified legacy decision recorded");
    TEST_TRUE(row.decisionMatch, "qualified/qualified matches");
    TEST_TRUE(row.directionMatch, "direction match");
    TEST_STR_EQ("v2.9.2", row.eaVersion, "row carries v2.9.2 EA version");
}

void TestRowBuilder_ComponentsAndValidators(TestCounters &counters)
{
    ConfluenceResult cr = MakeTestConfluence();
    EntryDecision newDec;
    newDec.status = DECISION_REJECTED;
    newDec.confidence = 0.40;
    newDec.direction = CONFLUENCE_BULLISH;
    newDec.filterCount = 2;
    newDec.filters[0].validatorName = "ConfluenceValidator";
    newDec.filters[0].result = FILTER_FAIL;
    newDec.filters[1].validatorName = "SpreadValidator";
    newDec.filters[1].result = FILTER_PASS;

    ConfluenceWeights w;
    TelemetryRow row;
    CTelemetryRowBuilder::Build(row, cr, newDec, false, EntryDecision(), 0.60,
                                w, "EURUSD", (int)PERIOD_H1, "", "tick", 5);
    TEST_DBL_NEAR(80.0, row.structureRaw, 1e-9, "structure raw mapped");
    TEST_DBL_NEAR(25.0, row.structureWeight, 1e-9, "structure weight mapped");
    TEST_DBL_NEAR(20.0, row.structureContribution, 1e-9, "structure contribution mapped");
    TEST_DBL_NEAR(60.0, row.trendRaw, 1e-9, "trend raw mapped");
    TEST_INT_EQ(2, row.validatorCount, "validator results mapped");
    TEST_STR_EQ("ConfluenceValidator", row.validators[0].name, "first validator name");
    TEST_INT_EQ(FILTER_FAIL, row.validators[0].result, "first validator result");
    TEST_FALSE(row.newDecision, "rejected new decision recorded as false");
    TEST_FALSE(row.legacyDecision, "no legacy decision recorded as false");
    TEST_TRUE(row.decisionMatch, "rejected/no-legacy matches (false == false)");
    TEST_FALSE(row.directionMatch, "no legacy -> no direction match");
    TEST_DBL_NEAR(0.0, row.legacyConfidence, 1e-9, "no legacy -> legacyConfidence 0");
}

void TestRowBuilder_Mismatch(TestCounters &counters)
{
    ConfluenceResult cr = MakeTestConfluence();
    EntryDecision newDec;
    newDec.status = DECISION_REJECTED;
    newDec.confidence = 0.40;
    newDec.direction = CONFLUENCE_BULLISH;
    EntryDecision legacyDec;
    legacyDec.status = DECISION_QUALIFIED;
    legacyDec.confidence = 0.80;
    legacyDec.direction = CONFLUENCE_BULLISH;

    ConfluenceWeights w;
    TelemetryRow row;
    CTelemetryRowBuilder::Build(row, cr, newDec, true, legacyDec, 0.60,
                                w, "EURUSD", (int)PERIOD_H1, "", "tick", 5);
    TEST_FALSE(row.decisionMatch, "qualified legacy vs rejected new -> mismatch");
    TEST_TRUE(row.directionMatch, "same direction -> direction match");
    TEST_DBL_NEAR(0.80, row.legacyConfidence, 1e-9, "legacy confidence 0-1");
    TEST_DBL_NEAR(0.40, row.newConfidence, 1e-9, "new confidence 0-1");
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
    TestHeader_V2ColumnCount(counters);
    TestSchema_Version2(counters);
    TestRowBuilder_NormalizedConfidence(counters);
    TestRowBuilder_ComponentsAndValidators(counters);
    TestRowBuilder_Mismatch(counters);
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
