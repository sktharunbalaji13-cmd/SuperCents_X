//+------------------------------------------------------------------+
//|                                     CalibrationRunner.mq5          |
//|                                      Copyright 2026, SuperCents_X|
//|                                             v2.9.2 (Sprint 14.6)  |
//+------------------------------------------------------------------+
//  Offline calibration engine (run in the Strategy Tester or live).
//  Replays stored telemetry rows and runs one experiment per input:
//
//    MODE_THRESHOLD   - confidence threshold sweep
//    MODE_WEIGHTS     - 3-stage confluence weight search
//    MODE_ABLATION    - validator leave-one-out attribution
//    MODE_PROMOTION   - CI-style promotion gate vs the locked baseline
//    MODE_ABLATION_CROSSCHECK - attribution at the candidate threshold
//
//  Telemetry rows are read from Common\Files\Telemetry/
//  (telemetry_v2_*.csv, schemaVersion = 2), reports + manifests are
//  written to Files/Calibration/.
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, SuperCents_X"
#property link      ""
#property version   "3.00"
#property strict

#include "Calibration/ExperimentRunner.mqh"

//--- Experiment to run.
enum ENUM_CALIB_MODE_INPUT
{
    CALIB_INPUT_THRESHOLD = 0,
    CALIB_INPUT_WEIGHTS,
    CALIB_INPUT_ABLATION,
    CALIB_INPUT_PROMOTION,
    CALIB_INPUT_ABLATION_CROSSCHECK
};

input ENUM_CALIB_MODE_INPUT CalibrationMode = CALIB_INPUT_THRESHOLD;
input string                TelemetryDirectory  = "Telemetry";     // telemetry store (relative to Files)
input string                ReportDirectory     = "Calibration";   // report output (relative to Files)
input string                FingerprintFilter   = "";              // "" = every fingerprint in the store
input double                CandidateConfidence = 0.60;            // candidate threshold for replay
input double                WeightStructure     = 25.0;            // baseline weights
input double                WeightOrderBlock    = 20.0;
input double                WeightFVG           = 15.0;
input double                WeightLiquidity     = 15.0;
input double                WeightTrend         = 15.0;
input double                WeightPremium       = 10.0;

CLogger g_logger(MODULE_UNKNOWN, "CalibrationRunner");
CExperimentRunner g_runner;
bool g_ranOnce = false;

//+------------------------------------------------------------------+
//| EA-style entry points (Sprint 15.3: run in the Strategy Tester)  |
//+------------------------------------------------------------------+
int OnInit(void)
{
    return INIT_SUCCEEDED;
}

void OnTick(void)
{
    if(!g_ranOnce)
    {
        g_ranOnce = true;
        RunOnce();
    }
}

//+------------------------------------------------------------------+
//| Script program start function (kept for chart usage)             |
//+------------------------------------------------------------------+
void RunOnce(void)
{
    g_logger.LogInfo("========================== CALIBRATION RUNNER ==========================");
    g_logger.LogInfo(StringFormat("Mode: %d  Telemetry: %s  Reports: %s",
                                  (int)CalibrationMode, TelemetryDirectory, ReportDirectory));

    g_runner.SetDirectories(TelemetryDirectory, ReportDirectory);
    int total = g_runner.LoadDataset();
    if(total == 0)
    {
        g_logger.LogError("CalibrationRunner: no telemetry rows found — run the EA in shadow mode first");
        return;
    }

    CalibrationConfig cfg;
    cfg.minConfidence = CandidateConfidence;
    cfg.weights[0] = WeightStructure;
    cfg.weights[1] = WeightOrderBlock;
    cfg.weights[2] = WeightFVG;
    cfg.weights[3] = WeightLiquidity;
    cfg.weights[4] = WeightTrend;
    cfg.weights[5] = WeightPremium;

    //--- Enumerate fingerprints present in the store.
    ulong fps[];
    EnumerateFingerprints(fps);
    if(ArraySize(fps) == 0)
    {
        g_logger.LogError("CalibrationRunner: no fingerprints found");
        return;
    }

    //--- Optional filter: single fingerprint by hex value.
    ulong targetFp = 0;
    bool hasTarget = (FingerprintFilter != "");
    if(hasTarget)
    {
        targetFp = ParseHex64(FingerprintFilter);
        bool found = false;
        for(int i = 0; i < ArraySize(fps); i++)
        {
            if(fps[i] == targetFp)
            {
                found = true;
                break;
            }
        }
        if(!found)
        {
            g_logger.LogWarn(StringFormat("CalibrationRunner: fingerprint %s not in store", FingerprintFilter));
            return;
        }
    }

    int runs = 0;
    for(int i = 0; i < ArraySize(fps); i++)
    {
        if(hasTarget && fps[i] != targetFp)
            continue;

        ENUM_CALIBRATION_MODE mode = (ENUM_CALIBRATION_MODE)CalibrationMode;
        g_logger.LogInfo(StringFormat("CalibrationRunner: running %s on %016llX",
                                      (mode == CALIB_MODE_THRESHOLD ? "threshold"
                                      : mode == CALIB_MODE_WEIGHTS ? "weights"
                                      : mode == CALIB_MODE_ABLATION ? "ablation"
                                      : mode == CALIB_MODE_PROMOTION ? "promotion"
                                      : "ablation_crosscheck"), fps[i]));

        if(g_runner.Run(mode, cfg, fps[i]))
            runs++;
    }

    g_logger.LogInfo(StringFormat("CalibrationRunner: %d experiment(s) completed", runs));
    g_logger.LogInfo("======================================================================");
}

//+------------------------------------------------------------------+
//| Collect distinct fingerprints from the loaded dataset            |
//+------------------------------------------------------------------+
ulong ParseHex64(const string hex)
{
    string s = hex;
    StringTrimLeft(s);
    StringTrimRight(s);
    if(StringFind(s, "0x") == 0 || StringFind(s, "0X") == 0)
        s = StringSubstr(s, 2);

    ulong value = 0;
    int len = StringLen(s);
    for(int i = 0; i < len && i < 16; i++)
    {
        value <<= 4;
        int c = StringGetCharacter(s, i);
        if(c >= '0' && c <= '9')
            value += (c - '0');
        else if(c >= 'a' && c <= 'f')
            value += (c - 'a' + 10);
        else if(c >= 'A' && c <= 'F')
            value += (c - 'A' + 10);
        else
            break;
    }
    return value;
}

void EnumerateFingerprints(ulong &fps[])
{
    ArrayResize(fps, 0);
    for(int i = 0; i < g_runner.GetDatasetCount(); i++)
    {
        TelemetryRow row;
        if(!GetDatasetRow(i, row))
            continue;
        bool seen = false;
        for(int k = 0; k < ArraySize(fps); k++)
        {
            if(fps[k] == row.configFingerprint)
            {
                seen = true;
                break;
            }
        }
        if(!seen)
        {
            int idx = ArraySize(fps);
            ArrayResize(fps, idx + 1);
            fps[idx] = row.configFingerprint;
        }
    }
}

//--- Bridge: the runner keeps its dataset private, expose via a shim.
bool GetDatasetRow(int index, TelemetryRow &row)
{
    return g_runner.GetRow(index, row);
}

