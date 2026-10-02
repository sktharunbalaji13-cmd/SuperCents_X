//+------------------------------------------------------------------+
//|                                      EN03_FM2ScenarioProd.mq5    |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/  |
//+------------------------------------------------------------------+
//  EN-03 Option B G4 gate: FM-2 adversarial scenario against the
//  PRODUCTION gate (Portfolio/SymbolContext.mqh, Option B).
//  (docs/Sprint24_EN03_OptionB_Plan.md G4: production behavior must
//  match the frozen COORDINATED FM-2 trace, incl. the W=23 same-tick
//  suppression, with replay determinism.)
//
//  One-shot driver: replays the FIXED 33-bar synthetic table as
//  growing chronological windows (bars 0..W-1, W=5..33) into the
//  PRODUCTION context, then records one state row per window to
//  Common\Files\Telemetry\en03_fm2prod_<label>.csv.
//
//  Schema (production-observable): window,time,trend,bosCount,
//  chochCount,ppCount,obCount,fvgCount,liqCount,flipCount
//  (flipCount = TrendState::GetTrendFlipCount; the fork CSV's
//  research-only columns flipGate/flipCoord/coordSkip/signalCount are
//  not produced by the production chain; the W=23 same-tick
//  suppression is evidenced by the gate's "gate suppressed" journal
//  line + flipCount staying 1).
//
//  RESEARCH-ONLY harness: never linked into production, no commit.
//+------------------------------------------------------------------+
#property copyright "2026, SuperCents_X"
#property link      "https://github.com/"
#property version   "1.00"

//--- PRODUCTION chain (the exact context under test).
#include "../../Portfolio/SymbolContext.mqh"

//--- Input parameters (artifact tag only; the gate is unconditional).
input string EN03ArmLabel = "prod1";

//--- Scenario constants.
#define FM2_BARS     33
#define FM2_STEP_SEC 900
const datetime FM2_BASE = D'2026.01.01 00:00';

CSymbolContext *g_ctx = NULL;

//--- Scenario table (chronological, index 0 = oldest; prices in EURUSD).
//    Identical to EN03_FM2Scenario.mq5 (frozen Phase-2 table).
const double FM2_OPEN[FM2_BARS] =
{
    1.0900, 1.0900, 1.0905, 1.0892, 1.0888, 1.0890, 1.0880, 1.0870,
    1.0835, 1.0845, 1.0860, 1.0930, 1.0910, 1.0885, 1.0845, 1.0850,
    1.0845, 1.0905, 1.0838, 1.0840, 1.0925, 1.0900, 1.0838, 1.0840,
    1.0842, 1.0845, 1.0910, 1.0885, 1.0860, 1.0845, 1.0940, 1.0915,
    1.0905
};
const double FM2_HIGH[FM2_BARS] =
{
    1.0905, 1.0908, 1.0898, 1.0895, 1.0940, 1.0895, 1.0885, 1.0875,
    1.0850, 1.0865, 1.0935, 1.0930, 1.0915, 1.0890, 1.0855, 1.0850,
    1.0920, 1.0910, 1.0845, 1.0925, 1.0925, 1.0925, 1.0845, 1.0848,
    1.0849, 1.0915, 1.0910, 1.0890, 1.0925, 1.0942, 1.0935, 1.0918,
    1.0930
};
const double FM2_LOW[FM2_BARS] =
{
    1.0895, 1.0895, 1.0890, 1.0885, 1.0880, 1.0875, 1.0865, 1.0830,
    1.0835, 1.0840, 1.0855, 1.0905, 1.0880, 1.0840, 1.0845, 1.0845,
    1.0830, 1.0830, 1.0832, 1.0838, 1.0830, 1.0835, 1.0834, 1.0835,
    1.0838, 1.0842, 1.0880, 1.0855, 1.0840, 1.0845, 1.0910, 1.0900,
    1.0900
};
const double FM2_CLOSE[FM2_BARS] =
{
    1.0900, 1.0905, 1.0892, 1.0888, 1.0890, 1.0880, 1.0870, 1.0835,
    1.0845, 1.0860, 1.0930, 1.0910, 1.0885, 1.0845, 1.0850, 1.0845,
    1.0905, 1.0838, 1.0840, 1.0925, 1.0900, 1.0838, 1.0840, 1.0842,
    1.0845, 1.0910, 1.0885, 1.0860, 1.0925, 1.0940, 1.0915, 1.0905,
    1.0925
};

//+------------------------------------------------------------------+
//| Append one state row for the processed window W (chronological   |
//| prefix bars 0..W-1) to Telemetry/en03_fm2prod_<label>.csv        |
//+------------------------------------------------------------------+
void WriteStepRow(int W)
{
    string filePath = StringFormat("Telemetry/en03_fm2prod_%s.csv", EN03ArmLabel);
    bool exists = FileIsExist(filePath, FILE_COMMON);
    int handle = FileOpen(filePath, FILE_READ | FILE_WRITE | FILE_TXT | FILE_COMMON);
    if(handle == INVALID_HANDLE)
    {
        Print("ERROR: failed to open fm2prod file " + filePath);
        return;
    }

    if(!exists || FileSize(handle) == 0)
    {
        FileWrite(handle, "window,time,trend,bosCount,chochCount,ppCount,obCount,fvgCount,liqCount,flipCount");
    }

    CTrendState *trendState = (g_ctx != NULL) ? g_ctx.GetTrendState() : NULL;
    CBOSDetector *bosDetector = (g_ctx != NULL) ? g_ctx.GetBOSDetector() : NULL;
    CCHOCHDetector *chochDetector = (g_ctx != NULL) ? g_ctx.GetCHOCHDetector() : NULL;
    CProtectedPointManager *ppManager = (g_ctx != NULL) ? g_ctx.GetProtectedPointManager() : NULL;
    COrderBlockDetector *obDetector = (g_ctx != NULL) ? g_ctx.GetOrderBlockDetector() : NULL;
    CFVGDetector *fvgDetector = (g_ctx != NULL) ? g_ctx.GetFVGDetector() : NULL;
    CLiquidityDetector *liqDetector = (g_ctx != NULL) ? g_ctx.GetLiquidityDetector() : NULL;

    int trend = (trendState != NULL) ? (int)trendState.GetCurrentTrend() : -1;
    int bos   = (bosDetector != NULL) ? bosDetector.GetBOSCount() : -1;
    int choch = (chochDetector != NULL) ? chochDetector.GetCHOCHCount() : -1;
    int pp    = (ppManager != NULL) ? ppManager.GetProtectedPointCount() : -1;
    int ob    = (obDetector != NULL) ? obDetector.GetOrderBlockCount() : -1;
    int fvg   = (fvgDetector != NULL) ? fvgDetector.GetFVGCount() : -1;
    int liq   = (liqDetector != NULL) ? liqDetector.GetLevelCount() : -1;
    int flips = (trendState != NULL) ? trendState.GetTrendFlipCount() : -1;

    if(FileSeek(handle, 0, SEEK_END))
    {
        datetime windowTime = FM2_BASE + (datetime)((W - 1) * FM2_STEP_SEC);
        string line = StringFormat("%d,%s,%d,%d,%d,%d,%d,%d,%d,%d",
            W, TimeToString(windowTime), trend, bos, choch, pp, ob, fvg, liq, flips);
        FileWrite(handle, line);
        Print(StringFormat("FM2PROD W=%02d -> %s", W, line));
    }
    FileClose(handle);
}

//+------------------------------------------------------------------+
//| Drive one growing window W (bars 0..W-1, chronological) into the |
//| production context and record the post-update state.             |
//+------------------------------------------------------------------+
void RunWindow(int W)
{
    double open[];
    double high[];
    double low[];
    double close[];
    datetime time[];

    ArrayResize(open, W);
    ArrayResize(high, W);
    ArrayResize(low, W);
    ArrayResize(close, W);
    ArrayResize(time, W);

    for(int k = 0; k < W; k++)
    {
        open[k]  = FM2_OPEN[k];
        high[k]  = FM2_HIGH[k];
        low[k]   = FM2_LOW[k];
        close[k] = FM2_CLOSE[k];
        time[k]  = FM2_BASE + (datetime)(k * FM2_STEP_SEC);
    }

    g_ctx.Update(open, high, low, close, time, W);
    WriteStepRow(W);
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("========================================");
    Print("EN-03 FM2 Scenario - PRODUCTION gate (Option B, G4)");
    Print("========================================");

    g_ctx = new CSymbolContext(_Symbol, 0, ENTRY_MODE_LEGACY);
    if(g_ctx == NULL)
        return INIT_FAILED;

    if(!g_ctx.Init(NULL))
    {
        Print("ERROR: Failed to initialize production context");
        delete g_ctx;
        g_ctx = NULL;
        return INIT_FAILED;
    }

    Print("EN-03 FM2 scenario initialized (PROD arm=" + EN03ArmLabel + ")");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert tick function: one-shot scenario replay (W=5..33).        |
//+------------------------------------------------------------------+
void OnTick()
{
    static bool scenarioRan = false;
    if(scenarioRan)
        return;
    scenarioRan = true;

    for(int W = 5; W <= FM2_BARS; W++)
        RunWindow(W);

    Print("FM2 scenario complete (PROD arm=" + EN03ArmLabel + ", windows 5.." +
          IntegerToString(FM2_BARS) + ")");
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if(g_ctx != NULL)
    {
        g_ctx.Shutdown();
        delete g_ctx;
        g_ctx = NULL;
    }

    Print("EN-03 FM2 scenario deinitialized (PROD)");
}