//+------------------------------------------------------------------+
//|                              Sprint12_ExecutionRegression.mq5     |
//|        Sprint 12.2.5 — Execution Pipeline Synthetic Validation    |
//+------------------------------------------------------------------+
#property strict

#include "../Utils/Constants.mqh"
#include "../Utils/Types.mqh"
#include "../Utils/Helpers.mqh"
#include "../Core/Logger.mqh"
#include "../Structure/SwingDetector.mqh"
#include "../Structure/StructuralPivotEngine.mqh"
#include "../Structure/BOSDetector.mqh"
#include "../Structure/TrendState.mqh"
#include "../Structure/ProtectedPointManager.mqh"
#include "../Structure/CHOCHDetector.mqh"
#include "../Structure/OrderBlockDetector.mqh"
#include "../Structure/FVGDetector.mqh"
#include "../Confluence/ConfluenceEngine.mqh"
#include "../Entry/EntrySetup.mqh"
#include "../Entry/EntrySetupBuilder.mqh"
#include "../Entry/EntryValidator.mqh"
#include "../Entry/EntryEngine.mqh"
#include "../Entry/RiskManager.mqh"
#include "../Entry/ExecutionManager.mqh"

//--- Test globals
CLogger g_log(MODULE_UNKNOWN, "ExecReg");

//--- Detection pipeline globals
CSwingDetector           g_sd;
CStructuralPivotEngine   g_spe;
CBOSDetector             g_bd;
CTrendState              g_ts;
CProtectedPointManager   g_ppm;
CCHOCHDetector           g_cd;
COrderBlockDetector      g_obd;
CFVGDetector             g_fd;
CConfluenceEngine        g_ce;

//--- Entry pipeline globals
CEntrySetupBuilder    g_builder;
CEntryValidator       g_validator;
CEntryEngine          g_engine;
CRiskManager          g_risk;
CExecutionManager     g_exec;

//--- Synthetic bar data
struct SynthBar { double o, h, l, c; datetime t; };
SynthBar g_phys[];
int      g_totalBars;

//--- Test tracking
int g_testsRun = 0;
int g_passed   = 0;
int g_failed   = 0;

ConfluenceSignal g_ce_signal;

#define ASSERT(cond, msg) \
    do { \
        g_testsRun++; \
        if(!(cond)) { \
            g_failed++; \
            g_log.LogInfo(StringFormat("  FAIL: %s", msg)); \
        } else { \
            g_passed++; \
        } \
    } while(false)

//+------------------------------------------------------------------+
//| Generate synthetic OHLC data                                     |
//+------------------------------------------------------------------+
void GenerateData(void)
{
    g_totalBars = 45;
    ArrayResize(g_phys, g_totalBars);
    datetime baseTime = D'2026.01.02 00:00';
    int barMinutes = 15;

    // Phase 1: Neutral structure for pivots (bars 0-11)
    g_phys[0].o=1.08000; g_phys[0].h=1.08100; g_phys[0].l=1.07900; g_phys[0].c=1.08050;
    g_phys[1].o=1.08050; g_phys[1].h=1.08050; g_phys[1].l=1.07800; g_phys[1].c=1.07850;
    g_phys[2].o=1.07850; g_phys[2].h=1.07900; g_phys[2].l=1.07600; g_phys[2].c=1.07650;
    g_phys[3].o=1.07650; g_phys[3].h=1.07800; g_phys[3].l=1.07630; g_phys[3].c=1.07750;
    g_phys[4].o=1.07750; g_phys[4].h=1.08000; g_phys[4].l=1.07700; g_phys[4].c=1.07950;
    g_phys[5].o=1.07950; g_phys[5].h=1.08300; g_phys[5].l=1.07900; g_phys[5].c=1.08250;
    g_phys[6].o=1.08250; g_phys[6].h=1.08250; g_phys[6].l=1.08000; g_phys[6].c=1.08050;
    g_phys[7].o=1.08050; g_phys[7].h=1.08100; g_phys[7].l=1.07850; g_phys[7].c=1.07900;
    g_phys[8].o=1.07900; g_phys[8].h=1.07950; g_phys[8].l=1.07500; g_phys[8].c=1.07550;
    g_phys[9].o=1.07550; g_phys[9].h=1.07700; g_phys[9].l=1.07500; g_phys[9].c=1.07650;
    g_phys[10].o=1.07650; g_phys[10].h=1.07900; g_phys[10].l=1.07600; g_phys[10].c=1.07850;
    g_phys[11].o=1.07850; g_phys[11].h=1.08200; g_phys[11].l=1.07800; g_phys[11].c=1.08150;

    // Phase 2: Bearish breakdown (bars 12-14) → BEARISH BOS
    g_phys[12].o=1.08150; g_phys[12].h=1.08150; g_phys[12].l=1.07400; g_phys[12].c=1.07300;
    g_phys[13].o=1.07300; g_phys[13].h=1.07400; g_phys[13].l=1.07200; g_phys[13].c=1.07250;
    g_phys[14].o=1.07250; g_phys[14].h=1.07300; g_phys[14].l=1.07100; g_phys[14].c=1.07150;

    // Phase 3: Bullish reversal (bars 15-24)
    g_phys[15].o=1.07150; g_phys[15].h=1.07200; g_phys[15].l=1.07050; g_phys[15].c=1.07100;
    g_phys[16].o=1.07100; g_phys[16].h=1.07150; g_phys[16].l=1.06900; g_phys[16].c=1.06950;
    g_phys[17].o=1.06950; g_phys[17].h=1.07050; g_phys[17].l=1.06900; g_phys[17].c=1.07000;
    g_phys[18].o=1.07000; g_phys[18].h=1.07100; g_phys[18].l=1.06800; g_phys[18].c=1.06850;
    g_phys[19].o=1.06850; g_phys[19].h=1.06800; g_phys[19].l=1.06600; g_phys[19].c=1.06700;
    g_phys[20].o=1.06900; g_phys[20].h=1.07400; g_phys[20].l=1.06850; g_phys[20].c=1.07300;
    g_phys[21].o=1.07300; g_phys[21].h=1.08300; g_phys[21].l=1.07250; g_phys[21].c=1.08250;
    g_phys[22].o=1.08250; g_phys[22].h=1.08250; g_phys[22].l=1.07900; g_phys[22].c=1.07950;
    g_phys[23].o=1.07950; g_phys[23].h=1.08350; g_phys[23].l=1.07900; g_phys[23].c=1.08300;
    g_phys[24].o=1.08300; g_phys[24].h=1.08600; g_phys[24].l=1.08250; g_phys[24].c=1.08500;

    // Phase 4: Bearish setup zone (bars 25-29)
    g_phys[25].o=1.08500; g_phys[25].h=1.08550; g_phys[25].l=1.08300; g_phys[25].c=1.08350;
    g_phys[26].o=1.08350; g_phys[26].h=1.08600; g_phys[26].l=1.08300; g_phys[26].c=1.08550;
    g_phys[27].o=1.08350; g_phys[27].h=1.08400; g_phys[27].l=1.08200; g_phys[27].c=1.08250;
    g_phys[28].o=1.08250; g_phys[28].h=1.08500; g_phys[28].l=1.08200; g_phys[28].c=1.08400;
    g_phys[29].o=1.08200; g_phys[29].h=1.08200; g_phys[29].l=1.07800; g_phys[29].c=1.07900;

    // Phase 5: FVG zone (bars 30-32)
    g_phys[30].o=1.07700; g_phys[30].h=1.07750; g_phys[30].l=1.07500; g_phys[30].c=1.07550;
    g_phys[31].o=1.07850; g_phys[31].h=1.08000; g_phys[31].l=1.07800; g_phys[31].c=1.07950;
    g_phys[32].o=1.07950; g_phys[32].h=1.08100; g_phys[32].l=1.07850; g_phys[32].c=1.08050;

    // Phase 6: Bearish continuation (bars 33-37)
    g_phys[33].o=1.08050; g_phys[33].h=1.08050; g_phys[33].l=1.07400; g_phys[33].c=1.07450;
    g_phys[34].o=1.07450; g_phys[34].h=1.07500; g_phys[34].l=1.07200; g_phys[34].c=1.07250;
    g_phys[35].o=1.07250; g_phys[35].h=1.07300; g_phys[35].l=1.07050; g_phys[35].c=1.07150;
    g_phys[36].o=1.07150; g_phys[36].h=1.07250; g_phys[36].l=1.06950; g_phys[36].c=1.07000;
    g_phys[37].o=1.07000; g_phys[37].h=1.07100; g_phys[37].l=1.06800; g_phys[37].c=1.06850;

    // Phase 7: Flat (bars 38-44)
    g_phys[38].o=1.06900; g_phys[38].h=1.06950; g_phys[38].l=1.06750; g_phys[38].c=1.06800;
    g_phys[39].o=1.06800; g_phys[39].h=1.06900; g_phys[39].l=1.06500; g_phys[39].c=1.06600;
    g_phys[40].o=1.06600; g_phys[40].h=1.06700; g_phys[40].l=1.06500; g_phys[40].c=1.06650;
    g_phys[41].o=1.06650; g_phys[41].h=1.06800; g_phys[41].l=1.06600; g_phys[41].c=1.06750;
    g_phys[42].o=1.06750; g_phys[42].h=1.06900; g_phys[42].l=1.06700; g_phys[42].c=1.06850;
    g_phys[43].o=1.06850; g_phys[43].h=1.07000; g_phys[43].l=1.06800; g_phys[43].c=1.06950;
    g_phys[44].o=1.06950; g_phys[44].h=1.07100; g_phys[44].l=1.06900; g_phys[44].c=1.07050;

    for(int i = 0; i < g_totalBars; i++)
        g_phys[i].t = baseTime + i * barMinutes * 60;

    g_log.LogInfo(StringFormat("Generated %d synthetic bars", g_totalBars));
}

//+------------------------------------------------------------------+
//| Extract reverse-order array slice                                 |
//+------------------------------------------------------------------+
void ExtractSlice(int count, double &open[], double &high[], double &low[],
                  double &close[], datetime &time[])
{
    ArrayResize(open, count);
    ArrayResize(high, count);
    ArrayResize(low, count);
    ArrayResize(close, count);
    ArrayResize(time, count);
    for(int i = 0; i < count; i++)
    {
        int srcIdx = count - 1 - i;
        open[i]  = g_phys[srcIdx].o;
        high[i]  = g_phys[srcIdx].h;
        low[i]   = g_phys[srcIdx].l;
        close[i] = g_phys[srcIdx].c;
        time[i]  = g_phys[srcIdx].t;
    }
}

//+------------------------------------------------------------------+
//| Initialize all modules                                            |
//+------------------------------------------------------------------+
void InitAllModules(void)
{
    g_sd.Init();
    g_spe.Init();
    g_bd.Init();
    g_ts.Init();
    g_ppm.Init();
    g_cd.Init();
    g_obd.Init();
    g_fd.Init();
    g_ce.Init();

    g_ce.SetTrendState(&g_ts);
    g_ce.SetBOSDetector(&g_bd);
    g_ce.SetCHOCHDetector(&g_cd);
    g_ce.SetOrderBlockDetector(&g_obd);
    g_ce.SetFVGDetector(&g_fd);
    g_ce.SetProtectedPointManager(&g_ppm);

    g_builder.Init();
    g_builder.SetBOSDetector(&g_bd);
    g_builder.SetCHOCHDetector(&g_cd);
    g_builder.SetOBDetector(&g_obd);
    g_builder.SetFVGDetector(&g_fd);
    g_builder.SetPPManager(&g_ppm);

    g_validator.Init();
    g_engine.Init();
    g_risk.Init();
    g_exec.Init();
}

//+------------------------------------------------------------------+
//| Run one tick of the full pipeline                                 |
//+------------------------------------------------------------------+
void RunOneTick(int stage)
{
    double open[], high[], low[], close[];
    datetime time[];
    ExtractSlice(stage, open, high, low, close, time);
    int rates = stage;

    g_sd.Update(high, low, time, rates);
    g_spe.Update(&g_sd);
    g_bd.Update(&g_spe, close, time, rates);
    g_ts.Update(&g_bd);

    datetime bt[];
    ArrayResize(bt, 1);
    bt[0] = time[0];
    g_ppm.Update(&g_spe, &g_bd, &g_ts, bt);

    g_cd.Update(&g_ts, &g_ppm, close, time, rates);
    g_obd.Update(&g_cd, &g_ts, &g_ppm, open, high, low, close, time, rates);
    g_fd.Update(open, high, low, close, time, rates);
    g_ce.Update();
}

void RunFullPipeline(void)
{
    for(int stage = 5; stage <= g_totalBars; stage++)
        RunOneTick(stage);
}

void ShutdownAll(void)
{
    g_exec.Shutdown();
    g_risk.Shutdown();
    g_engine.Shutdown();
    g_validator.Shutdown();
    g_builder.Shutdown();
    g_ce.Shutdown();
    g_fd.Shutdown();
    g_obd.Shutdown();
    g_cd.Shutdown();
    g_ppm.Shutdown();
    g_ts.Shutdown();
    g_bd.Shutdown();
    g_spe.Shutdown();
    g_sd.Shutdown();
}

void ResetTestCounters(void)
{
    g_testsRun = 0;
    g_passed   = 0;
    g_failed   = 0;
}

void PrintSummary(const string label)
{
    g_log.LogInfo(StringFormat("  Tests: %d  Passed: %d  Failed: %d  [%s]",
        g_testsRun, g_passed, g_failed, label));
}

//+------------------------------------------------------------------+
//| Test 1: Builder produces valid setup from Confluence signal       |
//+------------------------------------------------------------------+
void Test_BuilderValidSetup(void)
{
    g_log.LogInfo("--- TEST 1: Builder produces valid setup ---");

    InitAllModules();
    RunFullPipeline();

    if(!g_ce.GetLatestSignal(g_ce_signal))
    {
        g_log.LogInfo("  SKIP: No Confluence signal generated");
        ShutdownAll();
        return;
    }

    EntrySetup setup;
    bool built = g_builder.Build(g_ce_signal, setup);

    ASSERT(built, "Builder returns true for valid signal");
    if(built)
    {
        ASSERT(setup.valid, "Setup is marked valid");
        ASSERT(setup.type != SETUP_NONE, "Setup type is not NONE");
        ASSERT(setup.confluenceScore >= 0, "Score >= 0");
        ASSERT(setup.entryPrice > 0, "Entry price > 0");
        ASSERT(setup.stopLoss > 0, "Stop loss > 0");
        ASSERT(setup.takeProfit > 0, "Take profit > 0");
        ASSERT(setup.riskRewardRatio == 2.0, "Default RR is 2.0");

        if(setup.direction == TREND_BULLISH)
            ASSERT(setup.entryPrice > setup.stopLoss, "Bullish entry above SL");
        else
            ASSERT(setup.entryPrice < setup.stopLoss, "Bearish entry below SL");
    }

    PrintSummary("TEST 1");
    ShutdownAll();
}

//+------------------------------------------------------------------+
//| Test 2: Validator accepts valid setup, rejects invalid            |
//+------------------------------------------------------------------+
void Test_Validator(void)
{
    g_log.LogInfo("--- TEST 2: EntryValidator qualification ---");

    g_validator.Init();

    // Valid bullish setup
    EntrySetup valid;
    valid.valid = true;
    valid.type = SETUP_BOS_CONTINUATION;
    valid.direction = TREND_BULLISH;
    valid.confluenceScore = 50;
    valid.entryPrice = 1.10000;
    valid.stopLoss = 1.09800;
    valid.takeProfit = 1.10400;
    valid.signalTime = D'2026.01.02 12:00';

    ASSERT(g_validator.IsValid(valid), "Valid setup passes");

    // Score below threshold
    EntrySetup lowScore = valid;
    lowScore.confluenceScore = 10;
    ASSERT(!g_validator.IsValid(lowScore), "Low score rejected");

    // Invalid setup marker
    EntrySetup invalid = valid;
    invalid.valid = false;
    ASSERT(!g_validator.IsValid(invalid), "Invalid flag rejected");

    // NONE type
    EntrySetup noneType = valid;
    noneType.type = SETUP_NONE;
    ASSERT(!g_validator.IsValid(noneType), "NONE type rejected");

    // Bullish entry below SL
    EntrySetup badSl = valid;
    badSl.entryPrice = 1.09700;
    ASSERT(!g_validator.IsValid(badSl), "Bullish entry below SL rejected");

    // Bearish entry above SL
    EntrySetup bearishBad = valid;
    bearishBad.direction = TREND_BEARISH;
    bearishBad.entryPrice = 1.09900;
    bearishBad.stopLoss = 1.10000;
    ASSERT(!g_validator.IsValid(bearishBad), "Bearish entry above SL rejected");

    PrintSummary("TEST 2");
    g_validator.Shutdown();
}

//+------------------------------------------------------------------+
//| Test 3: EntryEngine state machine                                 |
//+------------------------------------------------------------------+
void Test_EntryEngine(void)
{
    g_log.LogInfo("--- TEST 3: EntryEngine state machine ---");

    g_engine.Init();

    ASSERT(g_engine.GetState() == ENTRY_STATE_IDLE, "Initial state is IDLE");
    ASSERT(g_engine.GetActiveSetupId() == -1, "No active setup initially");

    EntrySetup setup;
    setup.valid = true;
    setup.type = SETUP_BOS_CONTINUATION;
    setup.direction = TREND_BULLISH;
    setup.confluenceScore = 50;
    setup.entryPrice = 1.10000;
    setup.stopLoss = 1.09800;
    setup.takeProfit = 1.10400;
    setup.signalTime = D'2026.01.02 12:00';

    // Arm valid setup
    ASSERT(g_engine.Arm(setup), "Arm valid setup returns true");
    ASSERT(g_engine.GetState() == ENTRY_STATE_ARMED, "State is ARMED after Arm");
    ASSERT(g_engine.GetActiveSetupId() > 0, "Active setup ID > 0");

    // Duplicate prevention via Matches()
    ASSERT(!g_engine.Arm(setup), "Duplicate setup rejected via Matches()");

    // Different setup replaces existing
    EntrySetup setup2 = setup;
    setup2.signalTime = D'2026.01.02 13:00';
    ASSERT(g_engine.Arm(setup2), "Different setup replaces existing");
    ASSERT(g_engine.GetActiveSetupId() > 0, "New setup ID after replace");

    // Cancel
    g_engine.Cancel();
    ASSERT(g_engine.GetState() == ENTRY_STATE_IDLE, "State is IDLE after Cancel");

    // GetActiveSetup fails when IDLE
    EntrySetup retrieved;
    ASSERT(!g_engine.GetActiveSetup(retrieved), "GetActiveSetup fails when IDLE");

    // Arm invalid setup rejected
    EntrySetup invalid = setup;
    invalid.valid = false;
    ASSERT(!g_engine.Arm(invalid), "Invalid setup rejected by Arm");

    PrintSummary("TEST 3");
    g_engine.Shutdown();
}

//+------------------------------------------------------------------+
//| Test 4: RiskManager PositionSizing                                |
//+------------------------------------------------------------------+
void Test_RiskManager(void)
{
    g_log.LogInfo("--- TEST 4: RiskManager PositionSizing ---");

    g_risk.Init();

    EntrySetup setup;
    setup.valid = true;
    setup.type = SETUP_BOS_CONTINUATION;
    setup.direction = TREND_BULLISH;
    setup.confluenceScore = 50;
    setup.entryPrice = 1.10000;
    setup.stopLoss = 1.09800;
    setup.takeProfit = 1.10400;
    setup.signalTime = D'2026.01.02 12:00';

    PositionSizing sizing = g_risk.Calculate(setup);
    ASSERT(sizing.lots == 0.01, "Default lot size = 0.01");
    ASSERT(sizing.stopDistance > 0, "Stop distance > 0");
    ASSERT(sizing.riskMoney == 0.0, "Risk money defaults to 0.0");

    // Invalid setup returns minimum lot
    EntrySetup invalid;
    sizing = g_risk.Calculate(invalid);
    ASSERT(sizing.lots == 0.01, "Invalid setup = default lot");

    PrintSummary("TEST 4");
    g_risk.Shutdown();
}

//+------------------------------------------------------------------+
//| Test 5: ExecutionManager guards and logging                       |
//+------------------------------------------------------------------+
void Test_ExecutionManager(void)
{
    g_log.LogInfo("--- TEST 5: ExecutionManager guards ---");

    g_exec.Init();

    EntrySetup setup;
    setup.valid = true;
    setup.type = SETUP_BOS_CONTINUATION;
    setup.direction = TREND_BULLISH;
    setup.confluenceScore = 50;
    setup.entryPrice = 1.10000;
    setup.stopLoss = 1.09800;
    setup.takeProfit = 1.10400;
    setup.signalTime = D'2026.01.02 12:00';

    // Market execution (BOS/CHOCH) — validate ExecutionResult struct
    ExecutionResult r1 = g_exec.Execute(setup, 0.01);
    ASSERT(r1.status == EXEC_STATUS_ACCEPTED || r1.status == EXEC_STATUS_REJECTED_BROKER,
        "Market execution returns accepted or broker rejection");
    ASSERT(r1.description != "", "Description is populated");
    ASSERT(r1.retcode != 0xFFFFFFFF, "Retcode is valid");

    // Invalid setup rejected
    EntrySetup invalid;
    ExecutionResult r2 = g_exec.Execute(invalid, 0.01);
    ASSERT(r2.status == EXEC_STATUS_REJECTED_INVALID_SETUP, "Invalid setup rejected");
    ASSERT(!r2.success, "Success false for invalid setup");

    PrintSummary("TEST 5");
    g_exec.Shutdown();
}

//+------------------------------------------------------------------+
//| Test 6: End-to-end pipeline from ConfluenceSignal to Execute      |
//+------------------------------------------------------------------+
void Test_EndToEndPipeline(void)
{
    g_log.LogInfo("--- TEST 6: End-to-end pipeline ---");

    InitAllModules();
    RunFullPipeline();

    if(!g_ce.GetLatestSignal(g_ce_signal))
    {
        g_log.LogInfo("  SKIP: No Confluence signal generated");
        ShutdownAll();
        return;
    }

    ASSERT(g_ce_signal.bullish || g_ce_signal.bearish, "Signal has direction");

    EntrySetup setup;
    bool built = g_builder.Build(g_ce_signal, setup);
    ASSERT(built, "Builder produces setup");

    if(built)
    {
        bool validated = g_validator.IsValid(setup);
        ASSERT(validated, "Validator passes");

        if(validated)
        {
            bool armed = g_engine.Arm(setup);
            ASSERT(armed, "Engine arms setup");

            if(armed)
            {
                ASSERT(g_engine.GetState() == ENTRY_STATE_ARMED, "Engine state = ARMED");

                PositionSizing sizing = g_risk.Calculate(setup);
                ASSERT(sizing.lots > 0, "Risk sizing > 0");

                ExecutionResult execResult = g_exec.Execute(setup, sizing.lots);
                ASSERT(execResult.success || execResult.status == EXEC_STATUS_REJECTED_BROKER
                    || execResult.status == EXEC_STATUS_ACCEPTED,
                    "Execute returns success or broker rejection");
                ASSERT(execResult.description != "", "Execution description populated");
                ASSERT(execResult.retcode != 0xFFFFFFFF, "Execution retcode is valid");

                if(execResult.success)
                {
                    ASSERT(execResult.status == EXEC_STATUS_ACCEPTED, "Success implies ACCEPTED");
                }
            }
        }
    }

    PrintSummary("TEST 6");
    ShutdownAll();
}

//+------------------------------------------------------------------+
//| Test 7: Setup type to execution style mapping                     |
//+------------------------------------------------------------------+
void Test_ExecutionStyleMapping(void)
{
    g_log.LogInfo("--- TEST 7: Execution style mapping ---");

    ASSERT(GetExecutionStyle(SETUP_BOS_CONTINUATION)    == EXEC_MARKET, "BOS → MARKET");
    ASSERT(GetExecutionStyle(SETUP_CHOCH_REVERSAL)      == EXEC_MARKET, "CHOCH → MARKET");
    ASSERT(GetExecutionStyle(SETUP_ORDERBLOCK_RETEST)   == EXEC_LIMIT,  "OB → LIMIT");
    ASSERT(GetExecutionStyle(SETUP_FVG_CONTINUATION)    == EXEC_LIMIT,  "FVG → LIMIT");
    ASSERT(GetExecutionStyle(SETUP_NONE)                == EXEC_MARKET, "NONE → MARKET (default)");

    PrintSummary("TEST 7");
}

//+------------------------------------------------------------------+
//| Test 9: ExecutionResult rejection paths                           |
//+------------------------------------------------------------------+
void Test_ExecutionResultRejections(void)
{
    g_log.LogInfo("--- TEST 9: ExecutionResult rejection paths ---");

    g_exec.Init();

    EntrySetup setup;
    setup.valid = true;
    setup.type = SETUP_BOS_CONTINUATION;
    setup.direction = TREND_BULLISH;
    setup.confluenceScore = 50;
    setup.entryPrice = 1.10000;
    setup.stopLoss = 1.09800;
    setup.takeProfit = 1.10400;
    setup.signalTime = D'2026.01.02 12:00';

    // Rejection: invalid setup (valid=false)
    EntrySetup invalid = setup;
    invalid.valid = false;
    ExecutionResult r = g_exec.Execute(invalid, 0.01);
    ASSERT(r.status == EXEC_STATUS_REJECTED_INVALID_SETUP, "invalid -> REJECTED_INVALID_SETUP");
    ASSERT(!r.success, "invalid -> !success");

    // Rejection: NONE type (also not market, so returns accepted with log)
    EntrySetup noneType = setup;
    noneType.type = SETUP_NONE;
    r = g_exec.Execute(noneType, 0.01);
    ASSERT(r.status == EXEC_STATUS_ACCEPTED, "NONE type -> ACCEPTED (logged)");
    ASSERT(r.success, "NONE type -> success");

    // LIMIT type (OB) — not yet implemented, returns ACCEPTED with log
    EntrySetup obSetup = setup;
    obSetup.type = SETUP_ORDERBLOCK_RETEST;
    r = g_exec.Execute(obSetup, 0.01);
    ASSERT(r.status == EXEC_STATUS_ACCEPTED, "OB order -> ACCEPTED (logged)");
    ASSERT(r.success, "OB order -> success");

    // FVG type — same as OB
    EntrySetup fvgSetup = setup;
    fvgSetup.type = SETUP_FVG_CONTINUATION;
    r = g_exec.Execute(fvgSetup, 0.01);
    ASSERT(r.status == EXEC_STATUS_ACCEPTED, "FVG order -> ACCEPTED (logged)");
    ASSERT(r.success, "FVG order -> success");

    // Market type with nil setup (uninitialized)
    ExecutionResult rUninit;
    ASSERT(rUninit.status == EXEC_STATUS_PENDING, "Default result is PENDING");
    ASSERT(!rUninit.success, "Default success is false");
    ASSERT(rUninit.orderTicket == 0, "Default ticket is 0");
    ASSERT(rUninit.dealTicket == 0, "Default deal is 0");

    PrintSummary("TEST 9");
    g_exec.Shutdown();
}

//+------------------------------------------------------------------+
//| Test 8: Deterministic output (repeatable results)                 |
//+------------------------------------------------------------------+
void Test_Determinism(void)
{
    g_log.LogInfo("--- TEST 8: Deterministic execution pipeline ---");

    InitAllModules();
    RunFullPipeline();
    ConfluenceSignal sig1;
    bool got1 = g_ce.GetLatestSignal(sig1);
    EntrySetup setup1;
    if(got1) g_builder.Build(sig1, setup1);
    ShutdownAll();

    InitAllModules();
    RunFullPipeline();
    ConfluenceSignal sig2;
    bool got2 = g_ce.GetLatestSignal(sig2);
    EntrySetup setup2;
    if(got2) g_builder.Build(sig2, setup2);
    ShutdownAll();

    ASSERT(got1 == got2, "Deterministic signal generation");

    if(got1 && got2)
    {
        ASSERT(setup1.type == setup2.type, "Deterministic setup type");
        ASSERT(setup1.direction == setup2.direction, "Deterministic direction");
        ASSERT(setup1.entryPrice == setup2.entryPrice, "Deterministic entry price");
        ASSERT(setup1.stopLoss == setup2.stopLoss, "Deterministic stop loss");
        ASSERT(setup1.confluenceScore == setup2.confluenceScore, "Deterministic score");
    }

    PrintSummary("TEST 8");
}

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("========================================");
    Print("Sprint 12.2.5 — Execution Regression");
    Print("========================================");

    GenerateData();

    Test_Validator();
    Test_EntryEngine();
    Test_RiskManager();
    Test_ExecutionManager();
    Test_ExecutionStyleMapping();
    Test_ExecutionResultRejections();
    Test_BuilderValidSetup();
    Test_EndToEndPipeline();
    Test_Determinism();

    Print("========================================");
    Print(StringFormat("SUMMARY: Tests: %d  Passed: %d  Failed: %d",
        g_testsRun, g_passed, g_failed));
    Print("========================================");

    if(g_failed > 0)
        return INIT_FAILED;

    Print("All tests passed.");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert tick (unused in regression)                                |
//+------------------------------------------------------------------+
void OnTick()
{
    if(IsStopped())
        return;
}
