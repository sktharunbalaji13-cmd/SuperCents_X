//+------------------------------------------------------------------+
//|                                  TestCalibrationDataset.mqh       |
//|                                      Copyright 2026, SuperCents_X|
//|                                             Sprint 15.3 / 17      |
//+------------------------------------------------------------------+
//  Unit tests for CCalibrationDataset::ParseUnsigned — the unsigned
//  fingerprint parser that must keep full ulong range. StringToInteger
//  saturates at INT64_MAX (0x7FFFFFFFFFFFFFFF), which previously merged
//  every fingerprint above INT64_MAX into one phantom set.
//
//  Sprint 17: schema v3 reader contract tests — v2 lines still parse,
//  v3 evidence lines round-trip, unknown versions are refused.
//  Sprint 20 TC01: schema v3.1 (v4) reader contract — v3.1 lines
//  round-trip all 7 appended columns, v5+ refused.
//+------------------------------------------------------------------+
#ifndef __TEST_CALIBRATION_DATASET_MQH__
#define __TEST_CALIBRATION_DATASET_MQH__

#include "../../Telemetry/CalibrationDataset.mqh"

//--- A literal v2 (45-column) line as it appears in telemetry_v2_*.csv.
//    Ground truth for backward compatibility: every v2 column position
//    is exercised with a distinctive value.
string TestV2Line(void)
{
    return "2,123456789,2026.01.05 10:00:00,EURUSD,15,v3.0,1,1,0.45000000,"
           "0.00000000,0.000000,0.00000000,"
           "0.00000000,0.000000,0.00000000,"
           "0.00000000,0.000000,0.00000000,"
           "0.00000000,0.000000,0.00000000,"
           "0.00000000,0.000000,0.00000000,"
           "0.00000000,0.000000,0.00000000,"
           "ConfluenceValidator=0,0.600000,1,1,1,1,0.45000000,0.45000000,,"
           "1,1,2.00000000,33,1,1.08000,1.09000,"
           "0,0";
}

//--- A literal v3 (68-column) line: the v2 prefix above plus the 23
//    evidence columns, matching TELEMETRY_CSV_HEADER_V3.
string TestV3Line(void)
{
    return "3" + StringSubstr(TestV2Line(), 1) + ","
           "rule-layer-v1,rule-layer,2026-08,raw,1,"
           "5,LIQUIDITY_BOS_BULLISH,60,0.60000000,2,\"1,4\",2,"
           "15,30,15,60,"
           "2,1,1,1,1,2,"
           "2026.01.05 09:45:00";
}

//--- A literal v4 (75-column) line: the v3 line above plus the 7
//    Sprint 20 TC01 columns (layerOrderBlock/layerFVG + FVG classifier
//    and gap timestamps), matching TELEMETRY_CSV_HEADER_V31.
string TestV31Line(void)
{
    return "4" + StringSubstr(TestV3Line(), 1) + ","
           "15,10,REVERSAL,MEDIUM,STRONG,"
           "2026.01.05 09:30:00,2026.01.05 09:45:00";
}

void TestParse_V2BackwardCompatible(TestCounters &counters)
{
    TelemetryRow row;
    bool ok = CCalibrationDataset::ParseRow(TestV2Line(), row);
    TEST_TRUE(ok, "v2 line parses under the v3 reader");
    TEST_INT_EQ(2, (int)row.schemaVersion, "v2 row keeps schemaVersion 2");
    TEST_DBL_NEAR(0.45, row.confidence, 1e-9, "v2 confidence preserved");
    TEST_DBL_NEAR(0.60, row.confThreshold, 1e-9, "v2 threshold preserved");
    TEST_INT_EQ(1, row.outcome, (string)TELEMETRY_OUTCOME_WIN + " outcome preserved");
    TEST_INT_EQ(0, row.componentData, "v2 row carries no evidence (componentData 0)");
    TEST_INT_EQ(0, row.firedRuleId, "v2 row has no fired rule");
    TEST_INT_EQ(EV_UNKNOWN, row.hasBOS, "v2 row flags stay UNKNOWN");
    TEST_INT_EQ(0, (int)row.signalTime, "v2 row has no signal time");
}

void TestParse_V3EvidenceRoundTrip(TestCounters &counters)
{
    TelemetryRow row;
    bool ok = CCalibrationDataset::ParseRow(TestV3Line(), row);
    TEST_TRUE(ok, "v3 line parses");
    TEST_INT_EQ(3, (int)row.schemaVersion, "v3 row keeps schemaVersion 3");
    TEST_DBL_NEAR(0.45, row.confidence, 1e-9, "v3 row keeps v2 columns (confidence)");
    TEST_STR_EQ("rule-layer-v1", row.scoreArchitecture, "score architecture parsed");
    TEST_STR_EQ("rule-layer", row.telemetryArchitecture, "telemetry architecture parsed");
    TEST_STR_EQ("2026-08", row.evidenceContract, "evidence contract parsed");
    TEST_STR_EQ("raw", row.confidenceModel, "confidence model parsed");
    TEST_INT_EQ(1, row.componentData, "componentData parsed");
    TEST_INT_EQ(5, row.firedRuleId, "fired rule id parsed");
    TEST_STR_EQ("LIQUIDITY_BOS_BULLISH", row.ruleName, "rule name parsed");
    TEST_INT_EQ(60, row.ruleScore, "rule score parsed");
    TEST_DBL_NEAR(0.60, row.ruleConfidence, 1e-9, "rule confidence parsed");
    TEST_INT_EQ(2, row.ruleEvidenceCount, "evidence count parsed");
    TEST_STR_EQ("1,4", row.ruleEvidenceIds, "evidence ids parsed");
    TEST_INT_EQ(EV_TRUE, row.trendAligned, "trendAligned parsed");
    TEST_INT_EQ(15, row.layerStructural, "structural layer parsed");
    TEST_INT_EQ(30, row.layerLiquidity, "liquidity layer parsed");
    TEST_INT_EQ(15, row.layerConfirmation, "confirmation layer parsed");
    TEST_INT_EQ(60, row.layerTotal, "layer total parsed");
    TEST_INT_EQ(EV_TRUE, row.hasBOS, "hasBOS parsed");
    TEST_INT_EQ(EV_TRUE, row.hasLiquiditySweep, "hasLiquiditySweep parsed");
    TEST_INT_EQ(EV_FALSE, row.hasProtectedPoint, "hasProtectedPoint parsed");
    TEST_TRUE(row.signalTime == StringToTime("2026.01.05 09:45:00"), "signalTime exact");
}

void TestParse_V31EvidenceRoundTrip(TestCounters &counters)
{
    TelemetryRow row;
    bool ok = CCalibrationDataset::ParseRow(TestV31Line(), row);
    TEST_TRUE(ok, "v3.1 line parses");
    TEST_INT_EQ(4, (int)row.schemaVersion, "v4 row keeps schemaVersion 4");
    TEST_DBL_NEAR(0.45, row.confidence, 1e-9, "v4 row keeps v2 columns (confidence)");
    TEST_STR_EQ("rule-layer-v1", row.scoreArchitecture, "v4 score architecture parsed");
    TEST_INT_EQ(60, row.layerTotal, "v4 layer total parsed");
    TEST_INT_EQ(15, row.layerOrderBlock, "layerOrderBlock parsed");
    TEST_INT_EQ(10, row.layerFVG, "layerFVG parsed");
    TEST_STR_EQ("REVERSAL", row.fvgClass, "fvgClass parsed");
    TEST_STR_EQ("MEDIUM", row.fvgSize, "fvgSize parsed");
    TEST_STR_EQ("STRONG", row.fvgStrength, "fvgStrength parsed");
    TEST_TRUE(row.fvgCreatedTime == StringToTime("2026.01.05 09:30:00"), "fvgCreatedTime exact");
    TEST_TRUE(row.fvgFillTime == StringToTime("2026.01.05 09:45:00"), "fvgFillTime exact");
}

void TestParse_RefusesUnknownVersions(TestCounters &counters)
{
    TelemetryRow row;
    string v5 = TestV31Line();
    StringSetCharacter(v5, 0, '5');
    TEST_FALSE(CCalibrationDataset::ParseRow(v5, row), "schemaVersion 5 refused");

    string v1 = TestV3Line();
    StringSetCharacter(v1, 0, '1');
    TEST_FALSE(CCalibrationDataset::ParseRow(v1, row), "schemaVersion 1 refused");

    string junk = TestV3Line() + ",extra";
    TEST_FALSE(CCalibrationDataset::ParseRow(junk, row), "v3 line with extra column refused");

    string junk4 = TestV31Line() + ",extra";
    TEST_FALSE(CCalibrationDataset::ParseRow(junk4, row), "v4 line with extra column refused");

    string shortV3 = TestV3Line();
    StringSetCharacter(shortV3, 0, '3');
    //--- Strip the last evidence column -> v3 with 67 columns must be refused.
    int lastComma = StringFind(shortV3, ",", StringLen(shortV3) - 24);
    if(lastComma > 0)
    {
        shortV3 = StringSubstr(shortV3, 0, lastComma);
        TEST_FALSE(CCalibrationDataset::ParseRow(shortV3, row), "67-column v3 line refused");
    }
    else
    {
        TEST_TRUE(false, "test harness could not trim v3 line");
    }

    //--- A v3 line with 68 columns but the v4 header shape must refuse too:
    //    column count is bound to the declared version.
    string mismatch = TestV3Line();
    StringSetCharacter(mismatch, 0, '4');
    TEST_FALSE(CCalibrationDataset::ParseRow(mismatch, row), "v4 label with 68 columns refused");
}

TestCounters RunCalibrationDatasetTests(void)
{
    TestCounters counters;

    SUITE_BEGIN("CalibrationDataset.ParseUnsigned + schema v3/v3.1 reader");

    TEST_TRUE(CCalibrationDataset::ParseUnsigned("0") == 0, "empty/zero: 0 -> 0");

    TEST_TRUE(CCalibrationDataset::ParseUnsigned("7") == 7, "small: 7 -> 7");

    TEST_TRUE(CCalibrationDataset::ParseUnsigned("2098382509486611519") == (ulong)2098382509486611519,
              "int64-range fp round-trips exactly");

    TEST_TRUE(CCalibrationDataset::ParseUnsigned("9223372036854775807") == 9223372036854775807,
              "INT64_MAX boundary parses exactly (not truncated)");

    //--- The two real fingerprints that previously saturated to 0x7FFF...
    ulong big1 = CCalibrationDataset::ParseUnsigned("17300017028236539594");
    TEST_TRUE(big1 == 17300017028236539594,
              "17300017028236539594 (>INT64_MAX) parses exactly, not 0x7FFF");
    TEST_TRUE(big1 != 9223372036854775807,
              "17300017028236539594 is NOT the INT64_MAX phantom");

    ulong big2 = CCalibrationDataset::ParseUnsigned("13861655276212279635");
    TEST_TRUE(big2 == 13861655276212279635,
              "13861655276212279635 (>INT64_MAX) parses exactly, not 0x7FFF");
    TEST_TRUE(big2 != big1, "two large fingerprints stay distinct");

    ulong max = CCalibrationDataset::ParseUnsigned("18446744073709551615");
    TEST_TRUE(max == 18446744073709551615, "ULONG_MAX parses exactly");
    TEST_TRUE(max != 9223372036854775807, "ULONG_MAX is NOT the INT64_MAX phantom");

    //--- Schema v3/v3.1 reader contract.
    TestParse_V2BackwardCompatible(counters);
    TestParse_V3EvidenceRoundTrip(counters);
    TestParse_V31EvidenceRoundTrip(counters);
    TestParse_RefusesUnknownVersions(counters);

    SUITE_END("CalibrationDataset.ParseUnsigned + schema v3/v3.1 reader");

    return counters;
}

#endif
