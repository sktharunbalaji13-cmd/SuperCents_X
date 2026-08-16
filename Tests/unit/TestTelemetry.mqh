#include "../TestAssert.mqh"
#include "../../Telemetry/TelemetryTypes.mqh"
#include "../../Telemetry/ConfigFingerprint.mqh"
#include "../../Telemetry/TelemetryRowBuilder.mqh"
#include "../../Telemetry/TelemetryCollector.mqh"
#include "../../Telemetry/ActualOutcomeSettler.mqh"

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

// ─── Sprint 17: schema v3 evidence contract ────────────────────────

void TestHeader_V3ColumnCount(TestCounters &counters)
{
    string v2parts[];
    int v2n = StringSplit(TELEMETRY_CSV_HEADER_V2, ',', v2parts);

    string parts[];
    int n = StringSplit(TELEMETRY_CSV_HEADER_V3, ',', parts);
    TEST_INT_EQ(68, n, "v3 header has 68 columns (45 v2 + 23 evidence)");
    TEST_INT_EQ(45 + 23, n, "v3 is strictly append-only over v2");
    TEST_STR_EQ("schemaVersion", parts[0], "v3 header starts with schemaVersion");
    TEST_STR_EQ("signalTime", parts[67], "v3 header ends with signalTime");

    for(int i = 0; i < v2n; i++)
    {
        string msg = StringFormat("v3 keeps v2 column %d (%s) in place", i, v2parts[i]);
        TEST_STR_EQ(v2parts[i], parts[i], msg);
    }
}

// ─── Sprint 20 TC01: schema v3.1 (v4) evidence contract ────────────

void TestHeader_V31ColumnCount(TestCounters &counters)
{
    string v3parts[];
    int v3n = StringSplit(TELEMETRY_CSV_HEADER_V3, ',', v3parts);

    string parts[];
    int n = StringSplit(TELEMETRY_CSV_HEADER_V31, ',', parts);
    TEST_INT_EQ(75, n, "v3.1 header has 75 columns (68 v3 + 7 TC01)");
    TEST_INT_EQ(68 + 7, n, "v3.1 is strictly append-only over v3");
    TEST_STR_EQ("schemaVersion", parts[0], "v3.1 header starts with schemaVersion");
    TEST_STR_EQ("fvgFillTime", parts[74], "v3.1 header ends with fvgFillTime");
    TEST_STR_EQ("layerOrderBlock", parts[68], "column 69 is layerOrderBlock");
    TEST_STR_EQ("layerFVG", parts[69], "column 70 is layerFVG");
    TEST_STR_EQ("fvgClass", parts[70], "column 71 is fvgClass");
    TEST_STR_EQ("fvgSize", parts[71], "column 72 is fvgSize");
    TEST_STR_EQ("fvgStrength", parts[72], "column 73 is fvgStrength");
    TEST_STR_EQ("fvgCreatedTime", parts[73], "column 74 is fvgCreatedTime");

    for(int i = 0; i < v3n; i++)
    {
        string msg = StringFormat("v3.1 keeps v3 column %d (%s) in place", i, v3parts[i]);
        TEST_STR_EQ(v3parts[i], parts[i], msg);
    }
}

// ─── Sprint 22 RL-HYP-01: schema v5 gate contract ───────────────────

void TestHeader_V5ColumnCount(TestCounters &counters)
{
    string v31parts[];
    int v31n = StringSplit(TELEMETRY_CSV_HEADER_V31, ',', v31parts);

    string parts[];
    int n = StringSplit(TELEMETRY_CSV_HEADER_V5, ',', parts);
    TEST_INT_EQ(78, n, "v5 header has 78 columns (75 v3.1 + 3 gate)");
    TEST_INT_EQ(75 + 3, n, "v5 is strictly append-only over v3.1");
    TEST_STR_EQ("schemaVersion", parts[0], "v5 header starts with schemaVersion");
    TEST_STR_EQ("gateDecision", parts[77], "v5 header ends with gateDecision");
    TEST_STR_EQ("swingQualifyingId", parts[75], "column 76 is swingQualifyingId");
    TEST_STR_EQ("swingAmplitude", parts[76], "column 77 is swingAmplitude");
    TEST_STR_EQ("gateDecision", parts[77], "column 78 is gateDecision");

    for(int i = 0; i < v31n; i++)
    {
        string msg = StringFormat("v5 keeps v3.1 column %d (%s) in place", i, v31parts[i]);
        TEST_STR_EQ(v31parts[i], parts[i], msg);
    }
}

void TestHeader_V6ColumnCount(TestCounters &counters)
{
    string v5parts[];
    int v5n = StringSplit(TELEMETRY_CSV_HEADER_V5, ',', v5parts);

    string parts[];
    int n = StringSplit(TELEMETRY_CSV_HEADER_V6, ',', parts);
    TEST_INT_EQ(81, n, "v6 header has 81 columns (78 v5 + 3 identity)");
    TEST_INT_EQ(78 + 3, n, "v6 is strictly append-only over v5");
    TEST_STR_EQ("schemaVersion", parts[0], "v6 header starts with schemaVersion");
    TEST_STR_EQ("gateDecision", parts[77], "v6 keeps v5 column 78 in place");
    TEST_STR_EQ("runId", parts[78], "column 79 is runId");
    TEST_STR_EQ("buildTag", parts[79], "column 80 is buildTag");
    TEST_STR_EQ("gitHead", parts[80], "v6 header ends with gitHead");

    for(int i = 0; i < v5n; i++)
    {
        string msg = StringFormat("v6 keeps v5 column %d (%s) in place", i, v5parts[i]);
        TEST_STR_EQ(v5parts[i], parts[i], msg);
    }
}

void TestSchema_Version31(TestCounters &counters)
{
    TEST_INT_EQ(6, TELEMETRY_SCHEMA_VERSION, "Active schema version is 6 (v6, Sprint 25B B25-01 run identity)");
    TEST_STR_EQ("v3.0", TELEMETRY_EA_VERSION, "EA version string updated");
    TEST_STR_EQ("rule-layer-v1", TELEMETRY_SCORE_ARCHITECTURE, "score architecture versioned");
    TEST_STR_EQ("rule-layer", TELEMETRY_TELEMETRY_ARCHITECTURE, "telemetry architecture tagged");
    TEST_STR_EQ("2026-08", TELEMETRY_EVIDENCE_CONTRACT, "evidence contract revision recorded");
    TEST_STR_EQ("raw", TELEMETRY_CONFIDENCE_MODEL, "confidence model tagged raw");
    TEST_INT_EQ(0, EV_UNKNOWN, "tristate: UNKNOWN == 0");
    TEST_INT_EQ(2, EV_TRUE, "tristate: TRUE == 2");
}

void TestTelemetryRuleNames(TestCounters &counters)
{
    TEST_STR_EQ("BOS_OB_BULLISH", TelemetryRuleName(1), "rule 1 name");
    TEST_STR_EQ("LIQUIDITY_BOS_BULLISH", TelemetryRuleName(5), "rule 5 name");
    TEST_STR_EQ("CHOCH_OB_REVERSAL", TelemetryRuleName(7), "rule 7 name");
    TEST_STR_EQ("", TelemetryRuleName(0), "RULE_NONE has no name");
    TEST_STR_EQ("", TelemetryRuleName(99), "unknown rule has no name");
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
                                          w, "EURUSD", (int)PERIOD_H1, "", "tick", 5, ConfluenceConfig());
    TEST_TRUE(ok, "Build succeeds");
    TEST_INT_EQ((int)TELEMETRY_SCHEMA_VERSION, (int)row.schemaVersion, "Row stamped schema v3.1");
    TEST_DBL_NEAR(0.40, row.confidence, 1e-9, "confidence column normalized 0-1");
    TEST_DBL_NEAR(0.40, row.legacyConfidence, 1e-9, "legacyConfidence normalized 0-1 (was 0-100 in v1)");
    TEST_DBL_NEAR(0.40, row.newConfidence, 1e-9, "newConfidence 0-1");
    TEST_DBL_NEAR(0.60, row.confThreshold, 1e-9, "confThreshold preserved");
    TEST_TRUE(row.newDecision, "qualified new decision recorded");
    TEST_TRUE(row.legacyDecision, "qualified legacy decision recorded");
    TEST_TRUE(row.decisionMatch, "qualified/qualified matches");
    TEST_TRUE(row.directionMatch, "direction match");
    TEST_STR_EQ("v3.0", row.eaVersion, "row carries v3.0 EA version");
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
                                w, "EURUSD", (int)PERIOD_H1, "", "tick", 5, ConfluenceConfig());
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
                                w, "EURUSD", (int)PERIOD_H1, "", "tick", 5, ConfluenceConfig());
    TEST_FALSE(row.decisionMatch, "qualified legacy vs rejected new -> mismatch");
    TEST_TRUE(row.directionMatch, "same direction -> direction match");
    TEST_DBL_NEAR(0.80, row.legacyConfidence, 1e-9, "legacy confidence 0-1");
    TEST_DBL_NEAR(0.40, row.newConfidence, 1e-9, "new confidence 0-1");
}

// ─── Sprint 17: evidence capture row builder ───────────────────────

ConfluenceSignal MakeTestSignal(void)
{
    ConfluenceSignal sig;
    sig.time = TimeCurrent();   // tester clock == row.timestamp basis
    sig.direction = CONFLUENCE_BULLISH;

    sig.score.structural = 15;
    sig.score.liquidity = 30;
    sig.score.confirmation = 15;
    sig.score.total = 60;
    sig.score.trendAligned = true;

    sig.currentRule.matched = true;
    sig.currentRule.type = RULE_LIQUIDITY_BOS_BULLISH;
    sig.currentRule.score = 60;
    sig.currentRule.confidence = 0.60;
    sig.currentRule.direction = CONFLUENCE_BULLISH;
    sig.currentRule.evidenceCount = 2;
    sig.currentRule.evidenceIds[0] = 1;
    sig.currentRule.evidenceIds[1] = 4;

    sig.hasBOS = true;
    sig.hasCHOCH = false;
    sig.hasOrderBlock = false;
    sig.hasFVG = false;
    sig.hasProtectedPoint = false;
    sig.hasLiquiditySweep = true;
    sig.trendAligned = true;

    //--- TC04 classifier snapshot: the engine always sets these at signal
    //    build time; the fixture mirrors the no-FVG contract (all defaults).
    sig.fvgClass = 0;
    sig.fvgSize = 0;
    sig.fvgStrength = 0;
    sig.fvgCreatedTime = 0;
    sig.fvgFillTime = 0;
    return sig;
}

void TestRowBuilder_EvidenceCapture(TestCounters &counters)
{
    ConfluenceResult cr = MakeTestConfluence();
    EntryDecision newDec;
    newDec.status = DECISION_QUALIFIED;
    newDec.confidence = 0.60;
    newDec.direction = CONFLUENCE_BULLISH;
    EntryDecision legacyDec;
    legacyDec.status = DECISION_QUALIFIED;
    legacyDec.confidence = 0.60;
    legacyDec.direction = CONFLUENCE_BULLISH;

    ConfluenceWeights w;
    ConfluenceSignal sig = MakeTestSignal();
    TelemetryRow row;
    bool ok = CTelemetryRowBuilder::BuildWithEvidence(row, cr, newDec, true, legacyDec, 0.60,
                                                      w, "EURUSD", (int)PERIOD_H1, "", "tick", 5, ConfluenceConfig(), sig);
    TEST_TRUE(ok, "BuildWithEvidence succeeds");
    TEST_INT_EQ(6, (int)row.schemaVersion, "Row stamped schema v6 (identity columns)");
    TEST_DBL_NEAR(0.60, row.confidence, 1e-9, "v2 columns still populated (confidence)");
    TEST_DBL_NEAR(80.0, row.structureRaw, 1e-9, "legacy component columns still populated");

    //--- Metadata.
    TEST_STR_EQ("rule-layer-v1", row.scoreArchitecture, "score architecture recorded");
    TEST_STR_EQ("rule-layer", row.telemetryArchitecture, "telemetry architecture recorded");
    TEST_STR_EQ("2026-08", row.evidenceContract, "evidence contract recorded");
    TEST_STR_EQ("raw", row.confidenceModel, "confidence model recorded");
    TEST_INT_EQ(1, row.componentData, "componentData flag set");

    //--- Rule-level evidence.
    TEST_INT_EQ((int)RULE_LIQUIDITY_BOS_BULLISH, row.firedRuleId, "fired rule id (stable int)");
    TEST_STR_EQ("LIQUIDITY_BOS_BULLISH", row.ruleName, "rule name mapped");
    TEST_INT_EQ(60, row.ruleScore, "rule score pre-weighting");
    TEST_DBL_NEAR(0.60, row.ruleConfidence, 1e-9, "rule confidence pre-weighting");
    TEST_INT_EQ(2, row.ruleEvidenceCount, "evidence count");
    TEST_STR_EQ("1,4", row.ruleEvidenceIds, "evidence ids packed");
    TEST_INT_EQ(EV_TRUE, row.trendAligned, "trend alignment tristate true");

    //--- Layer decomposition.
    TEST_INT_EQ(15, row.layerStructural, "structural layer raw");
    TEST_INT_EQ(30, row.layerLiquidity, "liquidity layer raw");
    TEST_INT_EQ(15, row.layerConfirmation, "confirmation layer raw");
    TEST_INT_EQ(60, row.layerTotal, "layer total");

    //--- Evidence flags (tristate).
    TEST_INT_EQ(EV_TRUE, row.hasBOS, "hasBOS true");
    TEST_INT_EQ(EV_FALSE, row.hasCHOCH, "hasCHOCH false (evaluated absent)");
    TEST_INT_EQ(EV_FALSE, row.hasOrderBlock, "hasOrderBlock false");
    TEST_INT_EQ(EV_FALSE, row.hasFVG, "hasFVG false");
    TEST_INT_EQ(EV_FALSE, row.hasProtectedPoint, "hasProtectedPoint false");
    TEST_INT_EQ(EV_TRUE, row.hasLiquiditySweep, "hasLiquiditySweep true");

    //--- Timestamps: signal precedes the decision capture clock (the tester
    //    clock runs from the first bar, so pin the fixture to TimeCurrent()).
    TEST_TRUE(row.signalTime != 0, "signal time recorded");
    TEST_TRUE(row.signalTime <= row.timestamp, "signal precedes decision capture");

    //--- v3.1 columns: fixture signal has no OB/FVG evidence, so the split
    //    layers stay zero and the classifier strings stay UNKNOWN (the
    //    no-FVG default contract; populated only when FVG evidence exists).
    TEST_INT_EQ(0, row.layerOrderBlock, "layerOrderBlock zero when no OB");
    TEST_INT_EQ(0, row.layerFVG, "layerFVG zero when no FVG");
    TEST_STR_EQ("UNKNOWN", row.fvgClass, "fvgClass UNKNOWN without FVG evidence");
    TEST_STR_EQ("UNKNOWN", row.fvgSize, "fvgSize UNKNOWN without FVG evidence");
    TEST_STR_EQ("UNKNOWN", row.fvgStrength, "fvgStrength UNKNOWN without FVG evidence");
    TEST_INT_EQ(0, (int)row.fvgCreatedTime, "fvgCreatedTime zero without FVG evidence");
    TEST_INT_EQ(0, (int)row.fvgFillTime, "fvgFillTime zero without FVG evidence");
}

void TestRowBuilder_LayerSplit(TestCounters &counters)
{
    //--- A signal with both structural sources: OB (15) + FVG (10) must
    //    split into the two v3.1 columns (structural raw stays 25).
    ConfluenceResult cr = MakeTestConfluence();
    EntryDecision newDec;
    newDec.status = DECISION_QUALIFIED;
    newDec.confidence = 0.60;
    newDec.direction = CONFLUENCE_BULLISH;
    EntryDecision legacyDec;
    legacyDec.status = DECISION_QUALIFIED;
    legacyDec.confidence = 0.60;
    legacyDec.direction = CONFLUENCE_BULLISH;

    ConfluenceWeights w;
    ConfluenceSignal sig = MakeTestSignal();
    sig.hasOrderBlock = true;
    sig.hasFVG = true;
    sig.score.structural = 25;
    sig.score.layerOrderBlock = 15;
    sig.score.layerFVG = 10;

    TelemetryRow row;
    bool ok = CTelemetryRowBuilder::BuildWithEvidence(row, cr, newDec, true, legacyDec, 0.60,
                                                      w, "EURUSD", (int)PERIOD_H1, "", "tick", 5, ConfluenceConfig(), sig);
    TEST_TRUE(ok, "BuildWithEvidence succeeds with split layers");
    TEST_INT_EQ(25, row.layerStructural, "structural raw still the sum");
    TEST_INT_EQ(15, row.layerOrderBlock, "OB slice recorded");
    TEST_INT_EQ(10, row.layerFVG, "FVG slice recorded");
}

void TestRowBuilder_EngineUnsettledSplit(TestCounters &counters)
{
    //--- TC02 contract: when the engine produced no layer result
    //    (signal.score.total == 0, e.g. a shadow-rejected decision whose
    //    latest signal was never scored), the component split copied from
    //    `cr` must be zeroed so the row stays SplitConsistent.
    ConfluenceResult cr = MakeTestConfluence();   // components 80/25/20, 60/15/9
    EntryDecision newDec;
    newDec.status = DECISION_REJECTED;
    newDec.confidence = 0.35;
    newDec.direction = CONFLUENCE_BULLISH;
    EntryDecision legacyDec;
    legacyDec.status = DECISION_QUALIFIED;
    legacyDec.confidence = 0.80;
    legacyDec.direction = CONFLUENCE_BULLISH;

    ConfluenceWeights w;
    ConfluenceSignal sig = MakeTestSignal();
    sig.score.structural = 0;
    sig.score.liquidity = 0;
    sig.score.confirmation = 0;
    sig.score.total = 0;

    TelemetryRow row;
    bool ok = CTelemetryRowBuilder::BuildWithEvidence(row, cr, newDec, true, legacyDec, 0.60,
                                                      w, "EURUSD", (int)PERIOD_H1, "", "tick", 5, ConfluenceConfig(), sig);
    TEST_TRUE(ok, "BuildWithEvidence succeeds with unsettled engine signal");
    TEST_INT_EQ(0, row.layerTotal, "no layer result recorded");
    TEST_DBL_NEAR(0.0, row.structureRaw, 1e-9, "structureRaw zeroed without layer backing");
    TEST_DBL_NEAR(0.0, row.obRaw, 1e-9, "obRaw zeroed without layer backing");
    TEST_DBL_NEAR(0.0, row.fvgRaw, 1e-9, "fvgRaw zeroed without layer backing");
    TEST_DBL_NEAR(0.0, row.trendRaw, 1e-9, "trendRaw zeroed without layer backing");
    TEST_DBL_NEAR(0.0, row.liquidityRaw, 1e-9, "liquidityRaw zeroed without layer backing");
    TEST_DBL_NEAR(0.0, row.pdRaw, 1e-9, "pdRaw zeroed without layer backing");
    TEST_DBL_NEAR(0.0, row.structureContribution, 1e-9, "structureContribution zeroed");
    TEST_DBL_NEAR(0.0, row.trendContribution, 1e-9, "trendContribution zeroed");
    TEST_INT_EQ(1, row.componentData, "evidence row flag still set (split is all-zero)");
}

void TestRowBuilder_FVGClassifierSerialized(TestCounters &counters)
{
    //--- TC04: the classifier snapshot carried in the signal is serialized
    //    into the v3.1 columns; rows without FVG evidence keep defaults.
    ConfluenceResult cr = MakeTestConfluence();
    EntryDecision newDec;
    newDec.status = DECISION_QUALIFIED;
    newDec.confidence = 0.60;
    newDec.direction = CONFLUENCE_BULLISH;
    EntryDecision legacyDec;
    legacyDec.status = DECISION_QUALIFIED;
    legacyDec.confidence = 0.60;
    legacyDec.direction = CONFLUENCE_BULLISH;

    ConfluenceWeights w;
    ConfluenceSignal sig = MakeTestSignal();
    sig.hasFVG = true;
    sig.fvgClass = 1;        // FVG_CLASS_BREAKAWAY
    sig.fvgSize = 2;         // FVG_SIZE_MEDIUM
    sig.fvgStrength = 3;     // FVG_STRENGTH_STRONG
    sig.fvgCreatedTime = D'2026.01.05 12:00';
    sig.fvgFillTime = D'2026.01.06 03:00';

    TelemetryRow row;
    bool ok = CTelemetryRowBuilder::BuildWithEvidence(row, cr, newDec, true, legacyDec, 0.60,
                                                      w, "EURUSD", (int)PERIOD_H1, "", "tick", 5, ConfluenceConfig(), sig);
    TEST_TRUE(ok, "BuildWithEvidence succeeds with classifier snapshot");
    TEST_STR_EQ("BREAKAWAY", row.fvgClass, "class mapped BREAKAWAY");
    TEST_STR_EQ("MEDIUM", row.fvgSize, "size mapped MEDIUM");
    TEST_STR_EQ("STRONG", row.fvgStrength, "strength mapped STRONG");
    TEST_INT_EQ((int)D'2026.01.05 12:00', (int)row.fvgCreatedTime, "created time serialized");
    TEST_INT_EQ((int)D'2026.01.06 03:00', (int)row.fvgFillTime, "fill time serialized");

    //--- Mapping helpers: unknown/out-of-range collapse to UNKNOWN.
    TEST_STR_EQ("UNKNOWN", CTelemetryRowBuilder::TelemetryFVGClass(0), "class UNKNOWN for 0");
    TEST_STR_EQ("UNKNOWN", CTelemetryRowBuilder::TelemetryFVGClass(9), "class UNKNOWN for out-of-range");
    TEST_STR_EQ("CONTINUATION", CTelemetryRowBuilder::TelemetryFVGClass(2), "class CONTINUATION");
    TEST_STR_EQ("REVERSAL", CTelemetryRowBuilder::TelemetryFVGClass(3), "class REVERSAL");
    TEST_STR_EQ("SMALL", CTelemetryRowBuilder::TelemetryFVGSize(1), "size SMALL");
    TEST_STR_EQ("LARGE", CTelemetryRowBuilder::TelemetryFVGSize(3), "size LARGE");
    TEST_STR_EQ("WEAK", CTelemetryRowBuilder::TelemetryFVGStrength(1), "strength WEAK");
    TEST_STR_EQ("NORMAL", CTelemetryRowBuilder::TelemetryFVGStrength(2), "strength NORMAL");
}

void TestRowBuilder_EvidenceFallback(TestCounters &counters)
{
    //--- The v2-compatible Build() path stamps schema v3 but must NOT
    //    claim component evidence (componentData stays 0).
    ConfluenceResult cr = MakeTestConfluence();
    EntryDecision newDec;
    newDec.status = DECISION_REJECTED;
    newDec.confidence = 0.40;
    newDec.direction = CONFLUENCE_BULLISH;

    ConfluenceWeights w;
    TelemetryRow row;
    CTelemetryRowBuilder::Build(row, cr, newDec, false, EntryDecision(), 0.60,
                                w, "EURUSD", (int)PERIOD_H1, "", "tick", 5, ConfluenceConfig());
    TEST_INT_EQ(6, (int)row.schemaVersion, "Build() stamps schema v6 (identity columns)");
    TEST_INT_EQ(0, row.componentData, "no evidence claim without a signal");
    TEST_INT_EQ(EV_UNKNOWN, row.hasBOS, "unevaluated flags stay UNKNOWN, not FALSE");
    TEST_INT_EQ(0, row.firedRuleId, "no fired rule");
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

void TestFingerprint_SensitiveToFamilyFloors(TestCounters &counters)
{
    CalibrationConfig cfg;
    ulong defaults = CConfigFingerprint::Compute(cfg, "EURUSD", PERIOD_H1, "FixedRR", "1");
    cfg.familyFloorFVG = 0.50;
    ulong changed = CConfigFingerprint::Compute(cfg, "EURUSD", PERIOD_H1, "FixedRR", "1");
    TEST_FALSE(defaults == changed, "Family floors participate in the fingerprint");
    cfg.familyFloorUnknown = 0.45;
    ulong changed2 = CConfigFingerprint::Compute(cfg, "EURUSD", PERIOD_H1, "FixedRR", "1");
    TEST_FALSE(changed == changed2, "Unknown-family floor participates in the fingerprint");
}

void TestRowBuilder_FingerprintIncludesFloors(TestCounters &counters)
{
    ConfluenceResult cr = MakeTestConfluence();
    EntryDecision newDec;
    newDec.status = DECISION_QUALIFIED;
    newDec.confidence = 0.40;
    newDec.direction = CONFLUENCE_BULLISH;
    ConfluenceWeights w;

    ConfluenceConfig cfgDefault;
    TelemetryRow rowA;
    CTelemetryRowBuilder::Build(rowA, cr, newDec, false, EntryDecision(), 0.60,
                                w, "EURUSD", (int)PERIOD_H1, "", "tick", 5, cfgDefault);

    ConfluenceConfig cfgCustom;
    cfgCustom.familyFloorLiquidity = 0.55;
    cfgCustom.familyFloorUnknown = 0.55;
    TelemetryRow rowB;
    CTelemetryRowBuilder::Build(rowB, cr, newDec, false, EntryDecision(), 0.60,
                                w, "EURUSD", (int)PERIOD_H1, "", "tick", 5, cfgCustom);

    TEST_FALSE(rowA.configFingerprint == rowB.configFingerprint,
               "Row fingerprint reflects the family floors");
}

// ─── ED01: default-input parity (Sprint 20 experiment surface) ─────

void TestRowFingerprint_ED01DefaultParity(TestCounters &counters)
{
    //--- ED01: rows built with the default ED01 inputs must fingerprint
    //    identically to rows built with the B8 ConfluenceConfig defaults,
    //    so a default run is byte-identical to B8 in the telemetry file.
    ConfluenceResult cr = MakeTestConfluence();
    EntryDecision newDec;
    newDec.status = DECISION_QUALIFIED;
    newDec.confidence = 0.40;
    newDec.direction = CONFLUENCE_BULLISH;
    ConfluenceWeights w;

    ConfluenceConfig cfgB8;
    TelemetryRow rowA;
    CTelemetryRowBuilder::Build(rowA, cr, newDec, false, EntryDecision(), 0.60,
                                w, "EURUSD", (int)PERIOD_H1, "", "tick", 5, cfgB8);

    TelemetryRow rowB;
    CTelemetryRowBuilder::Build(rowB, cr, newDec, false, EntryDecision(), 0.60,
                                w, "EURUSD", (int)PERIOD_H1, "", "tick", 5,
                                BuildED01ConfigFromInputs());

    TEST_TRUE(rowA.configFingerprint == rowB.configFingerprint,
              "ED01: default inputs produce the B8 fingerprint (byte-identical)");
}

// ─── GR02A: actual-outcome instrumentation (settlement) ────────────

void TestCollector_RecordAssignsDecisionId(TestCounters &counters)
{
    CTelemetryCollector c;
    c.Init();

    TelemetryRow r1, r2, r3;
    int id1 = c.Record(r1);
    int id2 = c.Record(r2);
    int id3 = c.Record(r3);

    TEST_INT_EQ(1, id1, "first recorded row gets decisionId 1");
    TEST_INT_EQ(2, id2, "second recorded row gets decisionId 2");
    TEST_INT_EQ(3, id3, "third recorded row gets decisionId 3");
    TEST_INT_EQ(1, r1.decisionId, "assigned id is written back into the row");
    c.Shutdown();
}

// ─── B25-01: build/run identity stamping ───────────────────────────

void TestCollector_IdentityStamp(TestCounters &counters)
{
    CTelemetryCollector c;
    c.Init();

    TelemetryRow r1, r2;
    c.Record(r1);
    c.Record(r2);

    TEST_INT_EQ(0, StringFind(r1.runId, "RUN-"), "runId carries the RUN- prefix");
    TEST_INT_EQ(19, StringLen(r1.buildTag), "buildTag is YYYY.MM.dd HH:mm:ss (19 chars)");
    TEST_TRUE(StringLen(r1.runId) >= StringLen(r1.buildTag) + 5,
              "runId embeds buildTag plus the tick suffix");
    bool gitOk = (r1.gitHead == "unknown") || (StringLen(r1.gitHead) == 40);
    TEST_TRUE(gitOk, "gitHead is 40-hex or unknown");

    TEST_STR_EQ(r1.runId, r2.runId, "runId constant within a run");
    TEST_STR_EQ(r1.buildTag, r2.buildTag, "buildTag constant within a run");
    TEST_STR_EQ(r1.gitHead, r2.gitHead, "gitHead constant within a run");

    c.Shutdown();
}

// ─── B25-02: checkpoint flush bounds the buffered window ───────────

void TestCollector_CheckpointFlush(TestCounters &counters)
{
    CTelemetryCollector c;
    c.Init();
    c.SetCheckpointRows(2);

    TelemetryRow r1;
    c.Record(r1);
    TEST_INT_EQ(1, c.BufferedCount(), "row stays buffered below the checkpoint");
    c.Record(r1);
    TEST_INT_EQ(0, c.BufferedCount(), "checkpoint flush clears the buffer at 2 rows");
    TEST_INT_EQ(2, c.GetTotalRows(), "flushed rows counted");

    TelemetryRow r2;
    c.Record(r2);
    TEST_INT_EQ(1, c.BufferedCount(), "buffer refills after a checkpoint");

    TelemetryRow settled;
    settled.outcome = (int)TELEMETRY_OUTCOME_WIN;
    settled.actualOutcome = (int)TELEMETRY_OUTCOME_WIN;
    settled.outcomeSource = (int)OUTCOME_SOURCE_ACTUAL;
    c.Record(settled);
    TEST_INT_EQ(0, c.BufferedCount(), "second checkpoint flushes again");

    c.Shutdown();
}

void TestCollector_ApplyActualOutcome(TestCounters &counters)
{
    CTelemetryCollector c;
    c.Init();

    TelemetryRow r1, r2, r3;
    c.Record(r1);
    c.Record(r2);
    c.Record(r3);

    TEST_FALSE(c.ApplyActualOutcome(0, (int)TELEMETRY_OUTCOME_WIN), "decisionId 0 rejected");
    TEST_FALSE(c.ApplyActualOutcome(99, (int)TELEMETRY_OUTCOME_WIN), "unknown decisionId rejected");

    TEST_TRUE(c.ApplyActualOutcome(2, (int)TELEMETRY_OUTCOME_WIN), "known decisionId settles");

    TelemetryRow out;
    TEST_TRUE(c.GetBufferedRow(2, out), "buffered row 2 readable");
    TEST_INT_EQ((int)TELEMETRY_OUTCOME_WIN, out.actualOutcome, "actualOutcome settled");
    TEST_INT_EQ((int)OUTCOME_SOURCE_ACTUAL, out.actualOutcomeSource, "source marked ACTUAL");

    TelemetryRow untouched;
    TEST_TRUE(c.GetBufferedRow(1, untouched), "buffered row 1 readable");
    TEST_INT_EQ((int)TELEMETRY_OUTCOME_UNKNOWN, untouched.actualOutcome, "other rows untouched");

    TEST_TRUE(c.ApplyActualOutcome(1, (int)TELEMETRY_OUTCOME_LOSS), "second settle works");
    c.Shutdown();
}

void TestActualOutcomeSettler_Classify(TestCounters &counters)
{
    TEST_INT_EQ((int)TELEMETRY_OUTCOME_WIN, CActualOutcomeSettler::ClassifyActual(12.5),
                "positive closed profit -> WIN");
    TEST_INT_EQ((int)TELEMETRY_OUTCOME_LOSS, CActualOutcomeSettler::ClassifyActual(-3.25),
                "negative closed profit -> LOSS");
    TEST_INT_EQ((int)TELEMETRY_OUTCOME_BREAKEVEN, CActualOutcomeSettler::ClassifyActual(0.0),
                "zero closed profit -> BREAKEVEN");
}

void TestActualOutcomeSettler_EventMapping(TestCounters &counters)
{
    CTelemetryCollector c;
    c.Init();

    TelemetryRow r1, r2;
    c.Record(r1);
    c.Record(r2);                              // decisionIds 1, 2

    CActualOutcomeSettler s;
    s.SetCollector(&c);
    s.Register(7, 2);                          // candidate 7 -> decision 2
    s.Register(0, 2);                          // ignored (candidateId 0)
    s.Register(8, 0);                          // ignored (decisionId 0)

    EventData lossEvt;
    lossEvt.eventType = EVENT_POSITION_CLOSED;
    lossEvt.entryDecisionId = 7;
    lossEvt.profit = -2.0;
    s.HandleEvent(lossEvt);
    TelemetryRow out;
    TEST_TRUE(c.GetBufferedRow(2, out), "buffered row 2 readable after LOSS");
    TEST_INT_EQ((int)TELEMETRY_OUTCOME_LOSS, out.actualOutcome, "negative profit settles LOSS");
    TEST_INT_EQ((int)OUTCOME_SOURCE_ACTUAL, out.actualOutcomeSource, "source ACTUAL after loss");

    EventData winEvt;
    winEvt.eventType = EVENT_POSITION_CLOSED;
    winEvt.entryDecisionId = 7;
    winEvt.profit = 4.5;
    s.HandleEvent(winEvt);
    TEST_TRUE(c.GetBufferedRow(2, out), "buffered row 2 readable after WIN");
    TEST_INT_EQ((int)TELEMETRY_OUTCOME_WIN, out.actualOutcome, "positive profit settles WIN");

    EventData beEvt;
    beEvt.eventType = EVENT_POSITION_CLOSED;
    beEvt.entryDecisionId = 7;
    beEvt.profit = 0.0;
    s.HandleEvent(beEvt);
    TEST_TRUE(c.GetBufferedRow(2, out), "buffered row 2 readable after BE");
    TEST_INT_EQ((int)TELEMETRY_OUTCOME_BREAKEVEN, out.actualOutcome, "zero profit settles BREAKEVEN");

    EventData openEvt;
    openEvt.eventType = EVENT_POSITION_OPENED;
    openEvt.entryDecisionId = 7;
    openEvt.profit = 1.0;
    s.HandleEvent(openEvt);
    TEST_TRUE(c.GetBufferedRow(2, out), "buffered row 2 readable after OPENED");
    TEST_INT_EQ((int)TELEMETRY_OUTCOME_BREAKEVEN, out.actualOutcome, "OPENED event ignored");

    EventData unknownEvt;
    unknownEvt.eventType = EVENT_POSITION_CLOSED;
    unknownEvt.entryDecisionId = 99;
    unknownEvt.profit = -1.0;
    s.HandleEvent(unknownEvt);
    TEST_TRUE(c.GetBufferedRow(2, out), "buffered row 2 readable after unknown candidate");
    TEST_INT_EQ((int)TELEMETRY_OUTCOME_BREAKEVEN, out.actualOutcome, "unknown candidate ignored");

    EventData zeroEvt;
    zeroEvt.eventType = EVENT_POSITION_CLOSED;
    zeroEvt.entryDecisionId = 0;
    zeroEvt.profit = 5.0;
    s.HandleEvent(zeroEvt);
    TEST_TRUE(c.GetBufferedRow(2, out), "buffered row 2 readable after candidateId 0");
    TEST_INT_EQ((int)TELEMETRY_OUTCOME_BREAKEVEN, out.actualOutcome, "candidateId 0 ignored");

    EventData missingEvt;
    missingEvt.eventType = EVENT_POSITION_CLOSED;
    missingEvt.entryDecisionId = 7;
    missingEvt.profit = 9.0;
    s.Reset();
    s.HandleEvent(missingEvt);
    TEST_TRUE(c.GetBufferedRow(2, out), "buffered row 2 readable after reset");
    TEST_INT_EQ((int)TELEMETRY_OUTCOME_BREAKEVEN, out.actualOutcome, "reset clears the mapping");

    c.Shutdown();
}

// ─── Entry Point ───────────────────────────────────────────────────

TestCounters RunTelemetryTests()
{
    TestCounters counters;
    SUITE_BEGIN("Telemetry Schema & Fingerprint Tests");

    TestHeader_ColumnCount(counters);
    TestHeader_V2ColumnCount(counters);
    TestHeader_V3ColumnCount(counters);
    TestHeader_V31ColumnCount(counters);
    TestHeader_V5ColumnCount(counters);
    TestHeader_V6ColumnCount(counters);
    TestSchema_Version31(counters);
    TestTelemetryRuleNames(counters);
    TestRowBuilder_NormalizedConfidence(counters);
    TestRowBuilder_ComponentsAndValidators(counters);
    TestRowBuilder_Mismatch(counters);
    TestRowBuilder_EvidenceCapture(counters);
    TestRowBuilder_LayerSplit(counters);
    TestRowBuilder_EvidenceFallback(counters);
    TestRowBuilder_EngineUnsettledSplit(counters);
    TestRowBuilder_FVGClassifierSerialized(counters);
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
    TestFingerprint_SensitiveToFamilyFloors(counters);
    TestRowBuilder_FingerprintIncludesFloors(counters);
    TestRowFingerprint_ED01DefaultParity(counters);
    TestCollector_RecordAssignsDecisionId(counters);
    TestCollector_IdentityStamp(counters);
    TestCollector_CheckpointFlush(counters);
    TestCollector_ApplyActualOutcome(counters);
    TestActualOutcomeSettler_Classify(counters);
    TestActualOutcomeSettler_EventMapping(counters);

    SUITE_END("Telemetry Schema & Fingerprint Tests");
    return counters;
}
