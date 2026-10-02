//+------------------------------------------------------------------+
//|                                        EN03_FM2Scenario.mq5      |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/  |
//+------------------------------------------------------------------+
//  EN-03 Phase 2 research EA: targeted FM-2 adversarial scenario
//  (docs/Sprint24_EN03_Assessment.md Phase 2; user authorization
//  2026-08-13: validate the coordinated gate fix on a synthetic
//  same-tick BOS-flip + opposite-CHOCH construction).
//
//  The EA is a one-shot driver: it replays a FIXED 33-bar synthetic
//  table as growing chronological windows (bars 0..W-1, W=5..33) into
//  the research fork EN03_ResearchSymbolContext.mqh, then records one
//  state row per window to Common\Files\Telemetry\en03_fm2_<arm>.csv.
//  The market chart is never read; the scenario is fully deterministic.
//
//  Scenario (verified against the fork's code semantics):
//    bars 4,7,10,13,16,20,25,28,29 are strict 5-bar fractal swings;
//    events at window W = swingCenter + 3:
//      W=19  H3@16 locks L2@13 (1.0840); BEARISH BOS crosses L2 on
//            bar17 close 1.0838 -> trend UNKNOWN->BEARISH; PP HIGH H2.
//      W=23  FM-2 TICK: L3@20 locks H3@16 (1.0920); BULLISH BOS
//            crosses H3 on bar19 close 1.0925 -> trend BEARISH->BULLISH
//            (flip #1); PP LOW L2 (activation bar21); bearish CHOCH on
//            bar21 close 1.0838 < 1.0840 -> LEGACY gate flips BEARISH
//            (flipGate=1); COORDINATED suppresses (coordSkip=1).
//      W=24  LEGACY picks up the gate-flip trend change -> PP HIGH H3.
//      W=30  LEGACY-only bullish CHOCH on bar29 close 1.0940 > 1.0920
//            -> gate flip #2 -> BULLISH (flipGate=2).
//      W=31  L4@28 locks H4@25 (1.0915); BULLISH BOS crosses H4 on
//            bar29 close 1.0940 (no flip - already BULLISH); LEGACY
//            PP LOW L3 (PP#4).
//      W=32  H5@29 locks L4 (no BOS; all closes >= 1.0840).
//    Expected totals: bos=3 all arms; choch LEGACY=2, COORD/OFF=1;
//    PP LEGACY=4 (H2,L2,H3,L3), COORD/OFF=2 (H2,L2);
//    LEGACY trend BULLISH flipGate=2; COORD/OFF BULLISH flipCoord=0,
//    coordSkip COORD=1 / OFF=0.
//
//  RESEARCH-ONLY: never linked into production; compiled by the EN-03
//  phase-2 batch only. No production change, no commit.
//+------------------------------------------------------------------+
#property copyright "2026, SuperCents_X"
#property link      "https://github.com/"
#property version   "1.00"

//--- Research fork (includes every production dependency re-rooted).
#include "EN03_ResearchSymbolContext.mqh"
#include "../../Core/Config.mqh"

//--- Input parameters: mirror EN03_GateHarness.mq5 (frozen capture
//    profile; the ONLY behavioral deltas between arms are
//    EN03GateStrategy and EN03ArmLabel).
input ENUM_ENTRY_MODE EntryMode = ENTRY_MODE_SHADOW;
input ENUM_OUTCOME_TP_MODE OutcomeTpMode = OUTCOME_TP_FIXED_RR;
input double FixedRRTier = 2.0;
input double SwingSignificanceTier = 0.0;
input double WeightStructure       = 25.0;   // Weight: Structure
input double WeightOrderBlock      = 20.0;   // Weight: Order Block
input double WeightFVG             = 15.0;   // Weight: FVG
input double WeightLiquidity       = 15.0;   // Weight: Liquidity
input double WeightTrend           = 15.0;   // Weight: Trend
input double WeightPremiumDiscount = 10.0;   // Weight: Premium/Discount
input ENUM_EN03_GATE_STRATEGY EN03GateStrategy = EN03_GATE_LEGACY;
input string EN03ArmLabel = "legacy";        // artifact tag: legacy|off|coord|coord2

//--- Scenario constants.
#define FM2_BARS     33
#define FM2_STEP_SEC 900
const datetime FM2_BASE = D'2026.01.01 00:00';

//--- Globals (CEngine-equivalent wiring, mirrors EN03_GateHarness.mq5).
CConfig g_config;
CEventBusAdapter *g_eventBus = NULL;
CTelemetryCollector g_telemetry;
CSymbolContext *g_ctx = NULL;

//--- Scenario table (chronological, index 0 = oldest; prices in EURUSD).
//    Verified construction: strict 5-bar fractals for the swing bars
//    4,7,10,13,16,20,25,28,29; equal-high/low neighbors block the crash
//    and poke bars from becoming swings.
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
//| Append one state row for the processed window W (chronological     |
//| prefix bars 0..W-1) to Telemetry/en03_fm2_<arm>.csv               |
//+------------------------------------------------------------------+
void WriteStepRow(int W)
{
    string filePath = StringFormat("Telemetry/en03_fm2_%s.csv", EN03ArmLabel);
    bool exists = FileIsExist(filePath, FILE_COMMON);
    int handle = FileOpen(filePath, FILE_READ | FILE_WRITE | FILE_TXT | FILE_COMMON);
    if(handle == INVALID_HANDLE)
    {
        Print("ERROR: failed to open fm2 file " + filePath);
        return;
    }

    if(!exists || FileSize(handle) == 0)
    {
        FileWrite(handle, "window,time,trend,bosCount,chochCount,ppCount,obCount,fvgCount,liqCount,signalCount,flipGate,flipCoord,coordSkip");
    }

    CTrendState *trendState = (g_ctx != NULL) ? g_ctx.GetTrendState() : NULL;
    CBOSDetector *bosDetector = (g_ctx != NULL) ? g_ctx.GetBOSDetector() : NULL;
    CCHOCHDetector *chochDetector = (g_ctx != NULL) ? g_ctx.GetCHOCHDetector() : NULL;
    CProtectedPointManager *ppManager = (g_ctx != NULL) ? g_ctx.GetProtectedPointManager() : NULL;
    COrderBlockDetector *obDetector = (g_ctx != NULL) ? g_ctx.GetOrderBlockDetector() : NULL;
    CFVGDetector *fvgDetector = (g_ctx != NULL) ? g_ctx.GetFVGDetector() : NULL;
    CLiquidityDetector *liqDetector = (g_ctx != NULL) ? g_ctx.GetLiquidityDetector() : NULL;
    CConfluenceEngine *confluenceEngine = (g_ctx != NULL) ? g_ctx.GetConfluenceEngine() : NULL;

    int trend = (trendState != NULL) ? (int)trendState.GetCurrentTrend() : -1;
    int bos   = (bosDetector != NULL) ? bosDetector.GetBOSCount() : -1;
    int choch = (chochDetector != NULL) ? chochDetector.GetCHOCHCount() : -1;
    int pp    = (ppManager != NULL) ? ppManager.GetProtectedPointCount() : -1;
    int ob    = (obDetector != NULL) ? obDetector.GetOrderBlockCount() : -1;
    int fvg   = (fvgDetector != NULL) ? fvgDetector.GetFVGCount() : -1;
    int liq   = (liqDetector != NULL) ? liqDetector.GetLevelCount() : -1;
    int signal = 0;
    ConfluenceResult cr;
    if(confluenceEngine != NULL && confluenceEngine.GetLatestConfluence(cr) && cr.valid)
        signal = 1;

    if(FileSeek(handle, 0, SEEK_END))
    {
        datetime windowTime = FM2_BASE + (datetime)((W - 1) * FM2_STEP_SEC);
        string line = StringFormat("%d,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d",
            W, TimeToString(windowTime), trend, bos, choch, pp, ob, fvg, liq,
            signal, (g_ctx != NULL) ? g_ctx.GetFlipCountGate() : -1,
            (g_ctx != NULL) ? g_ctx.GetFlipCountCoord() : -1,
            (g_ctx != NULL) ? g_ctx.GetCoordSkipCount() : -1);
        FileWrite(handle, line);
        Print(StringFormat("FM2 W=%02d -> %s", W, line));
    }
    FileClose(handle);
}

//+------------------------------------------------------------------+
//| Drive one growing window W (bars 0..W-1, chronological) into the  |
//| research context and record the post-update state.                |
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
//| Expert initialization function (mirrors EN03_GateHarness.mq5)     |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("========================================");
    Print("EN-03 FM2 Scenario - Phase 2 research (EN-03)");
    Print("========================================");

    ConfluenceWeights w;
    w.structure       = WeightStructure;
    w.orderBlock      = WeightOrderBlock;
    w.fvg             = WeightFVG;
    w.liquidity       = WeightLiquidity;
    w.trend           = WeightTrend;
    w.premiumDiscount = WeightPremiumDiscount;
    if(!w.IsValid())
    {
        Print("ERROR: Confluence weights must sum to 100 (got " +
              DoubleToString(w.structure + w.orderBlock + w.fvg + w.liquidity + w.trend + w.premiumDiscount, 1) + ")");
        return INIT_PARAMETERS_INCORRECT;
    }

    if(!g_config.Init())
    {
        Print("ERROR: Failed to initialize configuration");
        return INIT_FAILED;
    }

    g_config.SetEntryMode(EntryMode);
    g_config.SetOutcomeTpMode(OutcomeTpMode);
    g_config.SetFixedRrTier(FixedRRTier);
    g_config.SetSwingSignificanceTier(SwingSignificanceTier);

    g_eventBus = new CEventBusAdapter();
    if(g_eventBus != NULL)
    {
        if(!g_eventBus.Init())
        {
            Print("ERROR: Failed to initialize EventBus");
            delete g_eventBus;
            g_eventBus = NULL;
        }
    }

    g_ctx = new CSymbolContext(_Symbol, g_config.GetMagicNumber(), g_config.GetEntryMode());
    if(g_ctx == NULL)
        return INIT_FAILED;

    g_ctx.SetGateStrategy(EN03GateStrategy);
    g_ctx.SetWeights(w);
    g_ctx.SetTelemetryCollector(&g_telemetry);

    if(!g_ctx.Init(g_eventBus))
    {
        Print("ERROR: Failed to initialize research context");
        delete g_ctx;
        g_ctx = NULL;
        return INIT_FAILED;
    }

    g_ctx.SetOutcomeTpMode(g_config.GetOutcomeTpMode());
    g_ctx.SetFixedRrTier(g_config.GetFixedRrTier());
    g_ctx.SetSwingSignificanceTier(g_config.GetSwingSignificanceTier());

    g_telemetry.Init();

    Print("EN-03 FM2 scenario initialized (arm=" + EN03ArmLabel +
          ", gateStrategy=" + EnumToString(EN03GateStrategy) +
          ", entryMode=" + EnumToString(EntryMode) + ")");

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert tick function: one-shot scenario replay (W=5..33).         |
//+------------------------------------------------------------------+
void OnTick()
{
    static bool scenarioRan = false;
    if(scenarioRan)
        return;
    scenarioRan = true;

    for(int W = 5; W <= FM2_BARS; W++)
        RunWindow(W);

    Print("FM2 scenario complete (arm=" + EN03ArmLabel + ", windows 5.." +
          IntegerToString(FM2_BARS) + ")");
}

//+------------------------------------------------------------------+
//| Expert deinitialization function (mirrors EN03_GateHarness.mq5)   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    //--- Mirror CEngine::Shutdown order EXACTLY (Engine.mqh:222): the
    //    context must settle+record its pending rows BEFORE the collector
    //    flushes, or the final rows are recorded into a disabled collector.
    if(g_ctx != NULL)
    {
        g_ctx.Shutdown();
        delete g_ctx;
        g_ctx = NULL;
    }

    g_telemetry.Shutdown();

    if(g_eventBus != NULL)
    {
        g_eventBus.Shutdown();
        delete g_eventBus;
        g_eventBus = NULL;
    }

    Print("EN-03 FM2 scenario deinitialized");
}
