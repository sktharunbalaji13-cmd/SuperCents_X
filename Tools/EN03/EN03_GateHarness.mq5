//+------------------------------------------------------------------+
//|                                           EN03_GateHarness.mq5   |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
//  EN-03 Phase 1 research harness (population-invariance study).
//  RESEARCH-ONLY (docs/Sprint24_EN03_Assessment.md, Phase 1):
//  - Mirrors SuperCents_X.mq5 + CEngine::Init/Update wiring EXACTLY
//    (same config plumbing, same per-bar driver, same telemetry
//    collector), but drives the research fork
//    EN03_ResearchSymbolContext.mqh instead of the production chain.
//  - The ONLY behavioral delta between arms is the EN03GateStrategy
//    input (LEGACY = byte-identical production behavior).
//  - Never linked into production; compiled by the EN03 phase-1 batch
//    only. Validity contract: the LEGACY arm must reproduce the frozen
//    TT01 golden telemetry CSV byte-identical (EN03_Phase1_Analyze.py).
//+------------------------------------------------------------------+
#property copyright "2026, SuperCents_X"
#property link      "https://github.com/"
#property version   "1.00"

//--- Research fork (includes every production dependency re-rooted).
#include "EN03_ResearchSymbolContext.mqh"
#include "../../Core/Config.mqh"

//--- Input parameters: mirror SuperCents_X.mq5 so the frozen capture
//    profile is reproducible (EntryMode 2 = isolation CONTROL profile,
//    B8 weights, tier 0.0, FixedRR 2.0R). The research delta is the
//    EN03GateStrategy input alone.
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

//--- Globals (CEngine-equivalent wiring).
CConfig g_config;
CEventBusAdapter *g_eventBus = NULL;
CTelemetryCollector g_telemetry;
CSymbolContext *g_ctx = NULL;

//+------------------------------------------------------------------+
//| Exact copy of CEngine::CopyOHLCArrays (Engine.mqh:384)            |
//+------------------------------------------------------------------+
bool CopyOHLCArrays(double &open[], double &high[], double &low[], double &close[], datetime &time[])
{
    int bars = Bars(_Symbol, _Period);

    if(bars < 5)
        return false;

    if(CopyOpen(_Symbol, _Period, 0, bars, open) <= 0)
        return false;

    if(CopyHigh(_Symbol, _Period, 0, bars, high) <= 0)
        return false;

    if(CopyLow(_Symbol, _Period, 0, bars, low) <= 0)
        return false;

    if(CopyClose(_Symbol, _Period, 0, bars, close) <= 0)
        return false;

    if(CopyTime(_Symbol, _Period, 0, bars, time) <= 0)
        return false;

    return true;
}

//+------------------------------------------------------------------+
//| Exact copy of CEngine::IsNewBar (Engine.mqh:424)                  |
//+------------------------------------------------------------------+
bool IsNewBar(void)
{
    static datetime lastBarTime = 0;
    datetime currentBarTime = iTime(_Symbol, _Period, 0);

    if(currentBarTime == 0)
        return false;

    if(currentBarTime == lastBarTime)
        return false;

    lastBarTime = currentBarTime;
    return true;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("========================================");
    Print("EN-03 Gate Harness - Phase 1 research (EN-03)");
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

    Print("EN-03 harness initialized (gate strategy=" + EnumToString(EN03GateStrategy) +
          ", entryMode=" + EnumToString(EntryMode) + ")");

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert tick function (exact CEngine::Update driver, Engine.mqh:190)|
//+------------------------------------------------------------------+
void OnTick()
{
    if(!IsNewBar())
        return;

    double open[];
    double high[];
    double low[];
    double close[];
    datetime time[];

    if(!CopyOHLCArrays(open, high, low, close, time))
        return;

    int rates_total = ArraySize(high);

    g_ctx.Update(open, high, low, close, time, rates_total);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    //--- Mirror CEngine::Shutdown order EXACTLY (Engine.mqh:222): the
    //    context must settle+record its pending rows BEFORE the collector
    //    flushes, or the final rows (decisions made within the last 50
    //    bars) are recorded into a disabled collector and lost.
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

    Print("EN-03 harness deinitialized");
}
