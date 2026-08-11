//+------------------------------------------------------------------+
//|                                  TestTelemetryHealth.mqh          |
//|                                      Copyright 2026, SuperCents_X|
//|                                             Sprint 17 (Step 6)    |
//+------------------------------------------------------------------+
//  Schema Health Gate unit tests.  Every dataset is materialized as a
//  real CSV in Common\Files (via the analyzer's own serializer) and
//  reloaded through CCalibrationDataset so the gate is exercised on
//  the same write->parse pipeline used in production.
//+------------------------------------------------------------------+
#ifndef __TEST_TELEMETRY_HEALTH_MQH__
#define __TEST_TELEMETRY_HEALTH_MQH__

#include "../TestAssert.mqh"
#include "../../Telemetry/TelemetryHealthReport.mqh"

//--- One v5 evidence row (schema v5) with sane defaults (rule 5, WIN).
TelemetryRow HealthRow(int ruleId = 5, int decisionId = 0, int outcome = 1)
{
    TelemetryRow row;
    row.schemaVersion = (int)TELEMETRY_SCHEMA_VERSION;
    row.configFingerprint = 0x1D1EF3C650D79C3F;
    row.timestamp = StringToTime("2026.01.05 09:45:00");
    row.symbol = "EURUSD";
    row.timeframe = 15;
    row.eaVersion = "v3.0";
    row.decisionId = decisionId;
    row.direction = 1;
    row.confidence = 0.45;
    row.confThreshold = 0.60;
    row.newDecision = true;
    row.legacyDecision = true;
    row.decisionMatch = true;
    row.directionMatch = true;
    row.legacyConfidence = 0.45;
    row.newConfidence = 0.45;
    row.outcomeSource = 1;
    row.outcome = outcome;
    row.rMultiple = 1.0;
    row.exitReason = 1;
    row.actualOutcome = outcome;
    row.actualOutcomeSource = 1;
    row.scoreArchitecture = "rule-layer-v1";
    row.telemetryArchitecture = "rule-layer";
    row.evidenceContract = "2026-08";
    row.confidenceModel = "raw";
    row.componentData = 1;
    row.firedRuleId = ruleId;
    if(ruleId == 1)
        row.ruleName = "BOS_OB_BULLISH";
    else
        row.ruleName = "LIQUIDITY_BOS_BULLISH";
    row.ruleScore = 60;
    row.ruleConfidence = 0.60;
    row.ruleEvidenceCount = 2;
    row.ruleEvidenceIds = "1,4";
    row.trendAligned = EV_TRUE;
    row.layerStructural = 15;
    row.layerLiquidity = 30;
    row.layerConfirmation = 15;
    row.layerTotal = 60;

    //--- TC02 wiring contract: split raws with weights/contributions
    //    (rule path: contribution = raw * weight / 100).  BOS 15,
    //    sweep 30, trend bonus 5 — split-consistent with the layers.
    row.structureRaw = 15.0;
    row.structureWeight = 25.0;
    row.structureContribution = 3.75;
    row.obRaw = 0.0;
    row.obWeight = 20.0;
    row.obContribution = 0.0;
    row.fvgRaw = 0.0;
    row.fvgWeight = 15.0;
    row.fvgContribution = 0.0;
    row.liquidityRaw = 30.0;
    row.liquidityWeight = 15.0;
    row.liquidityContribution = 4.5;
    row.trendRaw = 5.0;
    row.trendWeight = 15.0;
    row.trendContribution = 0.75;
    row.pdRaw = 0.0;
    row.pdWeight = 10.0;
    row.pdContribution = 0.0;
    row.hasBOS = EV_TRUE;
    row.hasCHOCH = EV_FALSE;
    row.hasOrderBlock = EV_FALSE;
    row.hasFVG = EV_FALSE;
    row.hasProtectedPoint = EV_FALSE;
    row.hasLiquiditySweep = EV_TRUE;
    row.signalTime = StringToTime("2026.01.05 09:44:00");
    return row;
}

//--- Serialize rows to a temp CSV in Common\Files and load them back.
bool HealthWriteLoad(const string fname, const TelemetryRow &rows[], int count,
                     CCalibrationDataset &out)
{
    string path = "HealthTest_" + fname + ".csv";
    FileDelete(path, FILE_COMMON);
    int h = FileOpen(path, FILE_READ | FILE_WRITE | FILE_TXT | FILE_COMMON);
    if(h == INVALID_HANDLE)
        return false;
    FileWrite(h, TELEMETRY_CSV_HEADER_V5);
    for(int i = 0; i < count; i++)
        FileWrite(h, CTelemetryHealthAnalyzer::SerializeRow(rows[i]));
    FileClose(h);
    bool ok = out.LoadFile(path);
    FileDelete(path, FILE_COMMON);
    return ok;
}

//====================================================================
//  Perfect dataset: every check passes, score 100, verdict PASS.
//====================================================================
void TestHealth_PerfectDataset(TestCounters &counters)
{
    TelemetryRow r1 = HealthRow(5, 0, 1);
    TelemetryRow r2 = HealthRow(5, 1, 2);
    TelemetryRow r3 = HealthRow(1, 2, 3);
    r3.ruleEvidenceIds = "";
    TelemetryRow rows[3];
    rows[0] = r1; rows[1] = r2; rows[2] = r3;

    CCalibrationDataset ds;
    TEST_TRUE(HealthWriteLoad("perfect", rows, 3, ds), "perfect dataset loads");

    CTelemetryHealthAnalyzer a;
    TelemetryHealthReport rep = a.Analyze(ds);

    TEST_INT_EQ(3, rep.parse.totalRows, "total rows");
    TEST_INT_EQ(0, rep.parse.schemaFailures, "no refused rows");
    TEST_DBL_NEAR(1.0, rep.parse.parseSuccessRate, 1e-9, "parse rate 100%");
    TEST_TRUE(rep.schema.schemaVersionPass, "schema version pass");
    TEST_INT_EQ(3, rep.schema.schemaVersionCounts[5], "all rows v5");
    TEST_TRUE(rep.schema.legacyConsistencyPass, "legacy consistency pass");
    TEST_TRUE(rep.schema.roundTripPass, "round-trip pass");
    TEST_INT_EQ(0, rep.schema.missingMarkerCount, "no MISSING markers");
    TEST_TRUE(rep.schema.coverageApplicable, "coverage applicable");
    TEST_INT_EQ(3, rep.components.componentDataRows, "all rows carry component data");
    TEST_INT_EQ(3, rep.components.decidedRows, "all rows decided");
    TEST_DBL_NEAR(1.0, rep.components.componentCoverage, 1e-9, "100% component coverage");
    TEST_INT_EQ(0, rep.components.missingLayerRows, "no missing layers");
    TEST_INT_EQ(0, rep.components.missingEvidenceRows, "no missing evidence");
    TEST_INT_EQ(2, rep.components.distinctEvidenceCombos, "combos \"1,4\" + \"\"");
    TEST_INT_EQ(2, rep.components.ruleCount, "two distinct rules");
    TEST_INT_EQ(5, rep.components.ruleCoverage[0].ruleId, "most frequent rule first");
    TEST_INT_EQ(2, rep.components.ruleCoverage[0].totalRows, "rule 5 seen twice");
    TEST_DBL_NEAR(100.0, rep.components.ruleCoverage[0].coveragePct, 1e-9, "rule 5 fully covered");
    TEST_DBL_NEAR(60.0, rep.layers.layerTotalMean, 1e-9, "layer total mean 60");
    TEST_INT_EQ(100, rep.healthScore, "perfect score 100");
    TEST_INT_EQ(HEALTH_PASS, rep.verdict, "verdict PASS");
}

//====================================================================
//  Empty dataset: trivially healthy, no checks applicable.
//====================================================================
void TestHealth_EmptyDataset(TestCounters &counters)
{
    string path = "HealthTest_empty.csv";
    FileDelete(path, FILE_COMMON);
    int h = FileOpen(path, FILE_READ | FILE_WRITE | FILE_TXT | FILE_COMMON);
    TEST_TRUE(h != INVALID_HANDLE, "empty file opens");
    FileWrite(h, TELEMETRY_CSV_HEADER_V5);
    FileClose(h);

    CCalibrationDataset ds;
    ds.LoadFile(path);
    FileDelete(path, FILE_COMMON);

    TEST_INT_EQ(0, ds.GetCount(), "zero rows loaded");

    CTelemetryHealthAnalyzer a;
    TelemetryHealthReport rep = a.Analyze(ds);
    TEST_INT_EQ(100, rep.healthScore, "empty dataset trivially passes");
    TEST_INT_EQ(HEALTH_PASS, rep.verdict, "empty dataset verdict PASS");
    TEST_FALSE(rep.schema.coverageApplicable, "coverage not applicable");
}

//====================================================================
//  Missing layers: componentData=1 but layerTotal==0 -> 10 pts lost.
//====================================================================
void TestHealth_MissingLayers(TestCounters &counters)
{
    TelemetryRow r1 = HealthRow(5, 0, 1);
    TelemetryRow r2 = HealthRow(5, 1, 2);
    r2.layerTotal = 0;
    TelemetryRow noSignal = HealthRow(0, 0, 1);
    noSignal.layerTotal = 0;
    noSignal.ruleName = "";
    TelemetryRow rows[3];
    rows[0] = r1; rows[1] = r2; rows[2] = noSignal;

    CCalibrationDataset ds;
    TEST_TRUE(HealthWriteLoad("missinglayers", rows, 3, ds), "dataset loads");

    CTelemetryHealthAnalyzer a;
    TelemetryHealthReport rep = a.Analyze(ds);

    TEST_INT_EQ(1, rep.components.missingLayerRows,
                "only the fired rule-5 row without layers counts");
    TEST_INT_EQ(90, rep.healthScore, "score 90 (10 pts lost)");
    TEST_INT_EQ(HEALTH_WARN, rep.verdict, "verdict WARN (90 < 95)");
}

//====================================================================
//  Missing evidence: all flags EV_UNKNOWN on a component row.
//====================================================================
void TestHealth_MissingEvidence(TestCounters &counters)
{
    TelemetryRow r1 = HealthRow(5, 0, 1);
    TelemetryRow r2 = HealthRow(5, 1, 2);
    r2.hasBOS = EV_UNKNOWN;
    r2.hasCHOCH = EV_UNKNOWN;
    r2.hasOrderBlock = EV_UNKNOWN;
    r2.hasFVG = EV_UNKNOWN;
    r2.hasProtectedPoint = EV_UNKNOWN;
    r2.hasLiquiditySweep = EV_UNKNOWN;
    TelemetryRow rows[2];
    rows[0] = r1; rows[1] = r2;

    CCalibrationDataset ds;
    TEST_TRUE(HealthWriteLoad("missingevidence", rows, 2, ds), "dataset loads");

    CTelemetryHealthAnalyzer a;
    TelemetryHealthReport rep = a.Analyze(ds);

    TEST_INT_EQ(1, rep.components.missingEvidenceRows, "one missing-evidence row");
    TEST_INT_EQ(90, rep.healthScore, "score 90");
    TEST_INT_EQ(HEALTH_WARN, rep.verdict, "verdict WARN");
}

//--- A genuine v2 line: the first 45 columns of the v3 serialization
//    (the v3 layout is strictly append-only over v2, so truncating the
//    trailing 23 evidence columns reproduces the legacy file format).
string HealthV2Line(const TelemetryRow &row)
{
    string line = CTelemetryHealthAnalyzer::SerializeRow(row);
    int comma = -1;
    for(int k = 1; k <= 45; k++)
    {
        int next = StringFind(line, ",", comma + 1);
        if(next < 0)
            return line;
        comma = next;
    }
    return StringSubstr(line, 0, comma);
}

//====================================================================
//  Mixed schema versions: a v2 row survives but fails the v5 gate.
//====================================================================
void TestHealth_SchemaVersionMixed(TestCounters &counters)
{
    TelemetryRow v2row = HealthRow(1, 1, 2);
    v2row.schemaVersion = 2;
    v2row.componentData = 0;
    v2row.structureRaw = 80.0;
    v2row.liquidityRaw = 25.0;

    string path = "HealthTest_mixedv.csv";
    FileDelete(path, FILE_COMMON);
    int h = FileOpen(path, FILE_READ | FILE_WRITE | FILE_TXT | FILE_COMMON);
    TEST_TRUE(h != INVALID_HANDLE, "mixed file opens");
    FileWrite(h, TELEMETRY_CSV_HEADER_V31);
    FileWrite(h, CTelemetryHealthAnalyzer::SerializeRow(HealthRow(5, 0, 1)));
    FileWrite(h, HealthV2Line(v2row));
    FileClose(h);

    CCalibrationDataset ds;
    TEST_TRUE(ds.LoadFile(path), "mixed dataset loads");
    FileDelete(path, FILE_COMMON);
    TEST_INT_EQ(2, ds.GetCount(), "both rows parsed");
    TEST_INT_EQ(0, ds.GetSkippedRows(), "nothing refused");

    CTelemetryHealthAnalyzer a;
    TelemetryHealthReport rep = a.Analyze(ds);

    TEST_FALSE(rep.schema.schemaVersionPass, "mixed versions fail the v5 gate");
    TEST_INT_EQ(1, rep.schema.schemaVersionCounts[5], "one v5 row");
    TEST_INT_EQ(1, rep.schema.schemaVersionCounts[2], "one v2 row");
    TEST_INT_EQ(85, rep.healthScore, "score 85 (15 pts lost)");
    TEST_INT_EQ(HEALTH_WARN, rep.verdict, "verdict WARN");
}

//====================================================================
//  Legacy v3 file: 68-column rows under the v3 header still load and
//  stay healthy (100% v3 counts toward the version gate).
//====================================================================
void TestHealth_LegacyV3FileStillLoads(TestCounters &counters)
{
    string path = "HealthTest_v3legacy.csv";
    FileDelete(path, FILE_COMMON);
    int h = FileOpen(path, FILE_READ | FILE_WRITE | FILE_TXT | FILE_COMMON);
    TEST_TRUE(h != INVALID_HANDLE, "legacy file opens");
    FileWrite(h, TELEMETRY_CSV_HEADER_V3);
    TelemetryRow r1 = HealthRow(5, 0, 1);
    TelemetryRow r2 = HealthRow(5, 1, 2);
    FileWrite(h, HealthV3Line(r1));
    FileWrite(h, HealthV3Line(r2));
    FileClose(h);

    CCalibrationDataset ds;
    TEST_TRUE(ds.LoadFile(path), "legacy v3 dataset loads");
    FileDelete(path, FILE_COMMON);
    TEST_INT_EQ(2, ds.GetCount(), "both v3 rows parsed");
    TEST_INT_EQ(0, ds.GetSkippedRows(), "nothing refused");

    CTelemetryHealthAnalyzer a;
    TelemetryHealthReport rep = a.Analyze(ds);

    TEST_TRUE(rep.schema.schemaVersionPass, "100% v3 still passes the gate");
    TEST_INT_EQ(2, rep.schema.schemaVersionCounts[3], "two v3 rows");
    TEST_INT_EQ(0, rep.schema.schemaVersionCounts[5], "no v5 rows");
    TEST_TRUE(rep.schema.roundTripPass, "round-trip only audits active-schema rows");
    TEST_INT_EQ(100, rep.healthScore, "legacy file stays healthy");
    TEST_INT_EQ(HEALTH_PASS, rep.verdict, "verdict PASS");
}

//====================================================================
//  Mixed v3 + v5 rows in one v5 file: both parse, gate passes.
//====================================================================
void TestHealth_MixedV3V4Rows(TestCounters &counters)
{
    string path = "HealthTest_mixv34.csv";
    FileDelete(path, FILE_COMMON);
    int h = FileOpen(path, FILE_READ | FILE_WRITE | FILE_TXT | FILE_COMMON);
    TEST_TRUE(h != INVALID_HANDLE, "mixed file opens");
    FileWrite(h, TELEMETRY_CSV_HEADER_V5);
    FileWrite(h, HealthV3Line(HealthRow(5, 0, 1)));
    FileWrite(h, CTelemetryHealthAnalyzer::SerializeRow(HealthRow(1, 1, 2)));
    FileClose(h);

    CCalibrationDataset ds;
    TEST_TRUE(ds.LoadFile(path), "mixed v3+v5 dataset loads");
    FileDelete(path, FILE_COMMON);
    TEST_INT_EQ(2, ds.GetCount(), "both rows parsed");

    CTelemetryHealthAnalyzer a;
    TelemetryHealthReport rep = a.Analyze(ds);

    TEST_TRUE(rep.schema.schemaVersionPass, "v3 + v5 mix passes the gate");
    TEST_INT_EQ(1, rep.schema.schemaVersionCounts[3], "one v3 row");
    TEST_INT_EQ(1, rep.schema.schemaVersionCounts[5], "one v5 row");
    TEST_INT_EQ(100, rep.healthScore, "mixed file healthy");
    TEST_INT_EQ(HEALTH_PASS, rep.verdict, "verdict PASS");
}

//--- A genuine v3 (68-column) line: stamp v3, then truncate the
//    v3-shape serialization at the end of field 68. The v3.1/v5 layouts
//    are strictly append-only over v3, so this reproduces the exact
//    legacy file format written before Sprint 20 — including the pre-TC02
//    contract of zero legacy raws (the v3.0 engine never computed them).
//    Commas inside the quoted ruleEvidenceIds field must not count as
//    separators.
string HealthV3Line(const TelemetryRow &row)
{
    TelemetryRow v3 = row;
    v3.schemaVersion = 3;
    v3.structureRaw = 0.0;       v3.structureWeight = 0.0;       v3.structureContribution = 0.0;
    v3.obRaw = 0.0;              v3.obWeight = 0.0;              v3.obContribution = 0.0;
    v3.fvgRaw = 0.0;             v3.fvgWeight = 0.0;             v3.fvgContribution = 0.0;
    v3.trendRaw = 0.0;           v3.trendWeight = 0.0;           v3.trendContribution = 0.0;
    v3.liquidityRaw = 0.0;       v3.liquidityWeight = 0.0;       v3.liquidityContribution = 0.0;
    v3.pdRaw = 0.0;              v3.pdWeight = 0.0;              v3.pdContribution = 0.0;

    string line = CTelemetryHealthAnalyzer::SerializeRow(v3);
    int len = StringLen(line);
    int commaCount = 0;
    int cut = -1;
    bool inQuote = false;
    for(int i = 0; i < len; i++)
    {
        ushort c = StringGetCharacter(line, i);
        if(c == '"')
            inQuote = !inQuote;
        else if(c == ',' && !inQuote)
        {
            commaCount++;
            if(commaCount == 68)
            {
                cut = i;
                break;
            }
        }
    }
    if(cut < 0)
        return line;
    return StringSubstr(line, 0, cut);
}

//====================================================================
//  Evaluator-path rows (TC02): raws carry no rule-path meaning; the
//  contribution slices rebuild the engine's int-truncated layers.
//====================================================================
void TestHealth_ContribInvariant(TestCounters &counters)
{
    TelemetryRow r1 = HealthRow(5, 0, 1);
    TelemetryRow r2 = HealthRow(5, 1, 2);
    r2.structureRaw = 0.0;        r2.obRaw = 0.0;        r2.fvgRaw = 0.0;
    r2.liquidityRaw = 0.0;        r2.trendRaw = 0.0;     r2.pdRaw = 0.0;
    r2.structureContribution = 20.0;
    r2.liquidityContribution = 10.0;
    r2.trendContribution = 5.0;
    r2.layerStructural = 20;
    r2.layerLiquidity = 10;
    r2.layerConfirmation = 5;
    r2.layerTotal = 35;
    TelemetryRow rows[2];
    rows[0] = r1; rows[1] = r2;

    CCalibrationDataset ds;
    TEST_TRUE(HealthWriteLoad("contrib", rows, 2, ds), "contrib dataset loads");

    CTelemetryHealthAnalyzer a;
    TelemetryHealthReport rep = a.Analyze(ds);

    TEST_TRUE(rep.schema.legacyConsistencyPass, "contribution-split rows pass the gate");
    TEST_INT_EQ(100, rep.healthScore, "score 100");
    TEST_INT_EQ(HEALTH_PASS, rep.verdict, "verdict PASS");
}

//====================================================================
void TestHealth_LegacyInconsistent(TestCounters &counters)
{
    TelemetryRow r1 = HealthRow(5, 0, 1);
    TelemetryRow r2 = HealthRow(5, 1, 2);
    r2.structureRaw = 80.0;
    TelemetryRow rows[2];
    rows[0] = r1; rows[1] = r2;

    CCalibrationDataset ds;
    TEST_TRUE(HealthWriteLoad("legacybad", rows, 2, ds), "dataset loads");

    CTelemetryHealthAnalyzer a;
    TelemetryHealthReport rep = a.Analyze(ds);

    TEST_FALSE(rep.schema.legacyConsistencyPass, "raws violating the v4 split flagged");
    TEST_INT_EQ(90, rep.healthScore, "score 90 (10 pts lost)");
    TEST_INT_EQ(HEALTH_WARN, rep.verdict, "verdict WARN");
}

//====================================================================
//  MISSING markers anywhere in string fields.
//====================================================================
void TestHealth_MissingMarkers(TestCounters &counters)
{
    TelemetryRow r1 = HealthRow(5, 0, 1);
    TelemetryRow r2 = HealthRow(5, 1, 2);
    r2.ruleName = "MISSING";
    TelemetryRow rows[2];
    rows[0] = r1; rows[1] = r2;

    CCalibrationDataset ds;
    TEST_TRUE(HealthWriteLoad("markers", rows, 2, ds), "dataset loads");

    CTelemetryHealthAnalyzer a;
    TelemetryHealthReport rep = a.Analyze(ds);

    TEST_INT_EQ(1, rep.schema.missingMarkerCount, "one MISSING marker");
    TEST_INT_EQ(90, rep.healthScore, "score 90");
    TEST_INT_EQ(HEALTH_WARN, rep.verdict, "verdict WARN");
}

//====================================================================
//  Per-flag coverage: fraction of component rows with a real value.
//====================================================================
void TestHealth_FlagCoverage(TestCounters &counters)
{
    TelemetryRow r1 = HealthRow(5, 0, 1);
    r1.hasOrderBlock = EV_UNKNOWN;
    r1.hasFVG = EV_UNKNOWN;
    r1.hasProtectedPoint = EV_UNKNOWN;
    TelemetryRow r2 = HealthRow(5, 1, 2);
    TelemetryRow rows[2];
    rows[0] = r1; rows[1] = r2;

    CCalibrationDataset ds;
    TEST_TRUE(HealthWriteLoad("flags", rows, 2, ds), "dataset loads");

    CTelemetryHealthAnalyzer a;
    TelemetryHealthReport rep = a.Analyze(ds);

    TEST_DBL_NEAR(1.0, rep.components.flagCoverageBOS, 1e-9, "BOS always set");
    TEST_DBL_NEAR(1.0, rep.components.flagCoverageCHOCH, 1e-9, "CHOCH always set");
    TEST_DBL_NEAR(0.5, rep.components.flagCoverageOrderBlock, 1e-9, "OB set on half");
    TEST_DBL_NEAR(0.5, rep.components.flagCoverageFVG, 1e-9, "FVG set on half");
    TEST_DBL_NEAR(0.5, rep.components.flagCoverageProtectedPoint, 1e-9, "PP set on half");
    TEST_DBL_NEAR(1.0, rep.components.flagCoverageLiquiditySweep, 1e-9, "sweep always set");
}

//====================================================================
//  Rule frequency: sorted descending, per-rule coverage computed.
//====================================================================
void TestHealth_RuleFrequency(TestCounters &counters)
{
    TelemetryRow r1 = HealthRow(1, 0, 1);
    TelemetryRow r2 = HealthRow(5, 1, 2);
    TelemetryRow r3 = HealthRow(5, 2, 3);
    TelemetryRow rows[3];
    rows[0] = r1; rows[1] = r2; rows[2] = r3;

    CCalibrationDataset ds;
    TEST_TRUE(HealthWriteLoad("rules", rows, 3, ds), "dataset loads");

    CTelemetryHealthAnalyzer a;
    TelemetryHealthReport rep = a.Analyze(ds);

    TEST_INT_EQ(2, rep.components.ruleCount, "two rules");
    TEST_INT_EQ(5, rep.components.ruleCoverage[0].ruleId, "rule 5 most frequent");
    TEST_INT_EQ(2, rep.components.ruleCoverage[0].totalRows, "rule 5 twice");
    TEST_INT_EQ(1, rep.components.ruleCoverage[1].ruleId, "rule 1 second");
    TEST_DBL_NEAR(100.0, rep.components.ruleCoverage[1].coveragePct, 1e-9, "rule 1 fully covered");
}

//====================================================================
//  Round-trip failure: a 9-decimal confidence cannot survive %.8f.
//====================================================================
void TestHealth_RoundTripCorrupt(TestCounters &counters)
{
    string path = "HealthTest_roundtrip.csv";
    FileDelete(path, FILE_COMMON);
    int h = FileOpen(path, FILE_READ | FILE_WRITE | FILE_TXT | FILE_COMMON);
    TEST_TRUE(h != INVALID_HANDLE, "corrupt file opens");
    FileWrite(h, TELEMETRY_CSV_HEADER_V5);
    TelemetryRow r1 = HealthRow(5, 0, 1);
    string line = CTelemetryHealthAnalyzer::SerializeRow(r1);
    StringReplace(line, "0.45000000", "0.450000001");
    FileWrite(h, line);
    FileClose(h);

    CCalibrationDataset ds;
    TEST_TRUE(ds.LoadFile(path), "corrupt-precision line still parses");
    FileDelete(path, FILE_COMMON);

    CTelemetryHealthAnalyzer a;
    TelemetryHealthReport rep = a.Analyze(ds);

    TEST_FALSE(rep.schema.roundTripPass, "round-trip detects precision loss");
    TEST_INT_EQ(1, rep.schema.roundTripFailures, "one failed row");
    TEST_INT_EQ(85, rep.healthScore, "score 85 (15 pts lost)");
    TEST_INT_EQ(HEALTH_WARN, rep.verdict, "verdict WARN");
}

//====================================================================
//  Refused lines: malformed CSV rows surface as parse failures.
//====================================================================
void TestHealth_ParseFailures(TestCounters &counters)
{
    string path = "HealthTest_parse.csv";
    FileDelete(path, FILE_COMMON);
    int h = FileOpen(path, FILE_READ | FILE_WRITE | FILE_TXT | FILE_COMMON);
    TEST_TRUE(h != INVALID_HANDLE, "parse file opens");
    FileWrite(h, TELEMETRY_CSV_HEADER_V5);
    TelemetryRow r1 = HealthRow(5, 0, 1);
    FileWrite(h, CTelemetryHealthAnalyzer::SerializeRow(r1));
    FileWrite(h, "3,1,2,3");   // malformed: refused by the reader
    FileClose(h);

    CCalibrationDataset ds;
    TEST_TRUE(ds.LoadFile(path), "good line loads");
    FileDelete(path, FILE_COMMON);

    TEST_INT_EQ(1, ds.GetCount(), "only the good row parsed");
    TEST_INT_EQ(1, ds.GetSkippedRows(), "one refused line");

    CTelemetryHealthAnalyzer a;
    TelemetryHealthReport rep = a.Analyze(ds);

    TEST_INT_EQ(1, rep.parse.schemaFailures, "refused rows surfaced");
    TEST_DBL_NEAR(0.5, rep.parse.parseSuccessRate, 1e-9, "50% parse rate");
    TEST_INT_EQ(85, rep.healthScore, "score 85 (15 pts lost)");
    TEST_INT_EQ(HEALTH_WARN, rep.verdict, "verdict WARN");
}

//====================================================================
//  Unexpected enum values: corruption detector fires.
//====================================================================
void TestHealth_UnexpectedEnums(TestCounters &counters)
{
    TelemetryRow r1 = HealthRow(5, 0, 1);
    TelemetryRow r2 = HealthRow(5, 1, 2);
    r2.direction = 9;
    TelemetryRow rows[2];
    rows[0] = r1; rows[1] = r2;

    CCalibrationDataset ds;
    TEST_TRUE(HealthWriteLoad("enums", rows, 2, ds), "dataset loads");

    CTelemetryHealthAnalyzer a;
    TelemetryHealthReport rep = a.Analyze(ds);

    TEST_INT_EQ(1, rep.parse.unexpectedEnumCount, "bad direction flagged");
    TEST_INT_EQ(85, rep.healthScore, "score 85");
    TEST_INT_EQ(HEALTH_WARN, rep.verdict, "verdict WARN");
}

//====================================================================
//  Layer distribution: min / mean / max over component rows.
//====================================================================
void TestHealth_LayerDistribution(TestCounters &counters)
{
    TelemetryRow r1 = HealthRow(5, 0, 1);          // 15/30/15/60
    TelemetryRow r2 = HealthRow(5, 1, 2);
    r2.layerStructural = 5;
    r2.layerLiquidity = 10;
    r2.layerConfirmation = 5;
    r2.layerTotal = 20;
    r2.structureRaw = 5.0;        // split-consistent with the layers
    r2.liquidityRaw = 10.0;
    r2.structureContribution = 1.25;
    r2.liquidityContribution = 1.5;
    r2.trendRaw = 5.0;            // trendAligned stays EV_TRUE
    r2.trendContribution = 0.75;
    TelemetryRow rows[2];
    rows[0] = r1; rows[1] = r2;

    CCalibrationDataset ds;
    TEST_TRUE(HealthWriteLoad("layers", rows, 2, ds), "dataset loads");

    CTelemetryHealthAnalyzer a;
    TelemetryHealthReport rep = a.Analyze(ds);

    TEST_INT_EQ(5, rep.layers.layerStructuralMin, "structural min");
    TEST_INT_EQ(15, rep.layers.layerStructuralMax, "structural max");
    TEST_DBL_NEAR(10.0, rep.layers.layerStructuralMean, 1e-9, "structural mean");
    TEST_INT_EQ(10, rep.layers.layerLiquidityMin, "liquidity min");
    TEST_DBL_NEAR(20.0, rep.layers.layerLiquidityMean, 1e-9, "liquidity mean");
    TEST_INT_EQ(30, rep.layers.layerLiquidityMax, "liquidity max");
    TEST_DBL_NEAR(10.0, rep.layers.layerConfirmationMean, 1e-9, "confirmation mean");
    TEST_INT_EQ(20, rep.layers.layerTotalMin, "total min");
    TEST_DBL_NEAR(40.0, rep.layers.layerTotalMean, 1e-9, "total mean");
    TEST_INT_EQ(60, rep.layers.layerTotalMax, "total max");
}

//====================================================================
//  Decided rows: only settled outcomes count.
//====================================================================
void TestHealth_DecidedRows(TestCounters &counters)
{
    TelemetryRow r1 = HealthRow(5, 0, 1);
    TelemetryRow r2 = HealthRow(5, 1, 0);   // UNKNOWN
    TelemetryRow r3 = HealthRow(1, 2, 3);   // BREAKEVEN
    TelemetryRow rows[3];
    rows[0] = r1; rows[1] = r2; rows[2] = r3;

    CCalibrationDataset ds;
    TEST_TRUE(HealthWriteLoad("decided", rows, 3, ds), "dataset loads");

    CTelemetryHealthAnalyzer a;
    TelemetryHealthReport rep = a.Analyze(ds);

    TEST_INT_EQ(2, rep.components.decidedRows, "WIN + BREAKEVEN decided");
    TEST_DBL_NEAR(3.0 / 2.0, rep.components.componentCoverage, 1e-9, "coverage vs decided rows");
}

//====================================================================
//  Multiple defects stack: score drops into FAIL territory.
//====================================================================
void TestHealth_MultipleDefectsFail(TestCounters &counters)
{
    TelemetryRow r1 = HealthRow(5, 0, 1);
    r1.ruleName = "MISSING";
    TelemetryRow r2 = HealthRow(5, 1, 2);
    r2.layerTotal = 0;
    r2.structureRaw = 80.0;
    TelemetryRow rows[2];
    rows[0] = r1; rows[1] = r2;

    CCalibrationDataset ds;
    TEST_TRUE(HealthWriteLoad("multidefect", rows, 2, ds), "dataset loads");

    CTelemetryHealthAnalyzer a;
    TelemetryHealthReport rep = a.Analyze(ds);

    TEST_INT_EQ(70, rep.healthScore, "score 70 (markers + layers + legacy)");
    TEST_INT_EQ(HEALTH_FAIL, rep.verdict, "verdict FAIL below 80");
}

//====================================================================
//  Renderers: card, CSV, JSON and verdict strings stay coherent.
//====================================================================
void TestHealth_Renderers(TestCounters &counters)
{
    TelemetryRow r1 = HealthRow(5, 0, 1);
    TelemetryRow rows[1];
    rows[0] = r1;

    CCalibrationDataset ds;
    TEST_TRUE(HealthWriteLoad("render", rows, 1, ds), "dataset loads");

    CTelemetryHealthAnalyzer a;
    TelemetryHealthReport rep = a.Analyze(ds);

    string card = CTelemetryHealthAnalyzer::RenderCard(rep);
    TEST_TRUE(StringFind(card, "SCHEMA HEALTH GATE") >= 0, "card header present");
    TEST_TRUE(StringFind(card, "PASS") >= 0, "card shows verdict");
    TEST_TRUE(StringFind(card, "Rule 5") >= 0, "card lists rules");

    string csv = CTelemetryHealthAnalyzer::RenderCsv(rep);
    TEST_TRUE(StringFind(csv, "section,key,value") == 0, "csv header first");
    TEST_TRUE(StringFind(csv, "score,healthScore,100") >= 0, "csv carries score");
    TEST_TRUE(StringFind(csv, "rule,5,") >= 0, "csv carries per-rule rows");

    string json = CTelemetryHealthAnalyzer::RenderJson(rep);
    TEST_TRUE(StringFind(json, "\"healthReportVersion\": 1") >= 0, "json versioned");
    TEST_TRUE(StringFind(json, "\"verdict\": \"PASS\"") >= 0, "json verdict");
    TEST_TRUE(StringFind(json, "\"score\": 100") >= 0, "json score");

    TEST_STR_EQ("PASS", CTelemetryHealthAnalyzer::VerdictString(HEALTH_PASS), "PASS string");
    TEST_STR_EQ("WARN", CTelemetryHealthAnalyzer::VerdictString(HEALTH_WARN), "WARN string");
    TEST_STR_EQ("FAIL", CTelemetryHealthAnalyzer::VerdictString(HEALTH_FAIL), "FAIL string");
    TEST_STR_EQ("N/A", CTelemetryHealthAnalyzer::VerdictString(HEALTH_NA), "N/A string");
    TEST_STR_EQ("UNKNOWN", CTelemetryHealthAnalyzer::VerdictString((ENUM_HEALTH_VERDICT)99), "unknown verdict");
}

//====================================================================
//  Health weights: constants add up to 100.
//====================================================================
void TestHealth_WeightsSum(TestCounters &counters)
{
    int sum = HEALTH_WEIGHT_SCHEMA_VERSION
            + HEALTH_WEIGHT_PARSE_SUCCESS
            + HEALTH_WEIGHT_COMPONENT_COVERAGE
            + HEALTH_WEIGHT_MISSING_LAYERS
            + HEALTH_WEIGHT_MISSING_EVIDENCE
            + HEALTH_WEIGHT_MISSING_MARKERS
            + HEALTH_WEIGHT_ROUND_TRIP
            + HEALTH_WEIGHT_LEGACY_CONSIST;
    TEST_INT_EQ(100, sum, "weights sum to 100");
}

TestCounters RunTelemetryHealthTests(void)
{
    TestCounters counters;
    SUITE_BEGIN("Telemetry Health Gate Tests");

    TestHealth_PerfectDataset(counters);
    TestHealth_EmptyDataset(counters);
    TestHealth_MissingLayers(counters);
    TestHealth_MissingEvidence(counters);
    TestHealth_SchemaVersionMixed(counters);
    TestHealth_LegacyV3FileStillLoads(counters);
    TestHealth_MixedV3V4Rows(counters);
    TestHealth_LegacyInconsistent(counters);
    TestHealth_ContribInvariant(counters);
    TestHealth_MissingMarkers(counters);
    TestHealth_FlagCoverage(counters);
    TestHealth_RuleFrequency(counters);
    TestHealth_RoundTripCorrupt(counters);
    TestHealth_ParseFailures(counters);
    TestHealth_UnexpectedEnums(counters);
    TestHealth_LayerDistribution(counters);
    TestHealth_DecidedRows(counters);
    TestHealth_MultipleDefectsFail(counters);
    TestHealth_Renderers(counters);
    TestHealth_WeightsSum(counters);

    SUITE_END("Telemetry Health Gate Tests");
    return counters;
}

#endif
