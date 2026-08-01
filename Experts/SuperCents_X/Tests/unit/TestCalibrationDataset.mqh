//+------------------------------------------------------------------+
//|                                  TestCalibrationDataset.mqh       |
//|                                      Copyright 2026, SuperCents_X|
//|                                             Sprint 15.3            |
//+------------------------------------------------------------------+
//  Unit tests for CCalibrationDataset::ParseUnsigned — the unsigned
//  fingerprint parser that must keep full ulong range. StringToInteger
//  saturates at INT64_MAX (0x7FFFFFFFFFFFFFFF), which previously merged
//  every fingerprint above INT64_MAX into one phantom set.
//+------------------------------------------------------------------+
#ifndef __TEST_CALIBRATION_DATASET_MQH__
#define __TEST_CALIBRATION_DATASET_MQH__

#include "../../Telemetry/CalibrationDataset.mqh"

TestCounters RunCalibrationDatasetTests(void)
{
    TestCounters counters;

    SUITE_BEGIN("CalibrationDataset.ParseUnsigned");

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

    SUITE_END("CalibrationDataset.ParseUnsigned");

    return counters;
}

#endif
