//+------------------------------------------------------------------+
//|                                         Sprint8_OBTest.mq5        |
//|        Sprint 8.2 - Full Pipeline Order Block Synthetic Test      |
//+------------------------------------------------------------------+
#property strict

#include "../../Experts/SuperCents_X/Utils/Constants.mqh"
#include "../../Experts/SuperCents_X/Utils/Types.mqh"
#include "../../Experts/SuperCents_X/Utils/Helpers.mqh"
#include "../../Experts/SuperCents_X/Core/Logger.mqh"
#include "../../Experts/SuperCents_X/Structure/SwingDetector.mqh"
#include "../../Experts/SuperCents_X/Structure/StructuralPivotEngine.mqh"
#include "../../Experts/SuperCents_X/Structure/BOSDetector.mqh"
#include "../../Experts/SuperCents_X/Structure/TrendState.mqh"
#include "../../Experts/SuperCents_X/Structure/ProtectedPointManager.mqh"
#include "../../Experts/SuperCents_X/Structure/CHOCHDetector.mqh"
#include "../../Experts/SuperCents_X/Structure/OrderBlockDetector.mqh"

//--- Test globals
CLogger g_log(MODULE_UNKNOWN, "OBTest");
CSwingDetector g_sd;
CStructuralPivotEngine g_spe;
CBOSDetector g_bd;
CTrendState g_ts;
CProtectedPointManager g_ppm;
CCHOCHDetector g_cd;
COrderBlockDetector g_obd;

//--- Physical bar data (chronological: 0 = oldest, N-1 = newest)
struct SynthBar { double o, h, l, c; datetime t; };
SynthBar g_phys[];
int g_totalBars;

//+------------------------------------------------------------------+
//| Generate synthetic OHLC data                                     |
//+------------------------------------------------------------------+
void GenerateData(void)
{
    g_totalBars = 35;
    ArrayResize(g_phys, g_totalBars);
    datetime baseTime = D'2026.01.02 00:00';
    int barMinutes = 15;

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
    g_phys[12].o=1.08150; g_phys[12].h=1.08150; g_phys[12].l=1.07400; g_phys[12].c=1.07450;
    g_phys[13].o=1.07450; g_phys[13].h=1.07500; g_phys[13].l=1.07300; g_phys[13].c=1.07350;
    g_phys[14].o=1.07350; g_phys[14].h=1.07400; g_phys[14].l=1.07200; g_phys[14].c=1.07250;
    g_phys[15].o=1.07300; g_phys[15].h=1.07350; g_phys[15].l=1.07100; g_phys[15].c=1.07150;
    g_phys[16].o=1.07150; g_phys[16].h=1.08000; g_phys[16].l=1.07100; g_phys[16].c=1.07900;
    g_phys[17].o=1.07900; g_phys[17].h=1.08400; g_phys[17].l=1.07850; g_phys[17].c=1.08350;
    g_phys[18].o=1.08350; g_phys[18].h=1.08450; g_phys[18].l=1.08300; g_phys[18].c=1.08400;
    g_phys[19].o=1.08400; g_phys[19].h=1.08400; g_phys[19].l=1.08100; g_phys[19].c=1.08150;
    g_phys[20].o=1.08150; g_phys[20].h=1.08500; g_phys[20].l=1.08100; g_phys[20].c=1.08450;
    g_phys[21].o=1.08450; g_phys[21].h=1.08600; g_phys[21].l=1.08350; g_phys[21].c=1.08550;
    g_phys[22].o=1.08550; g_phys[22].h=1.08550; g_phys[22].l=1.08200; g_phys[22].c=1.08250;
    g_phys[23].o=1.08250; g_phys[23].h=1.08300; g_phys[23].l=1.08000; g_phys[23].c=1.08050;
    g_phys[24].o=1.08050; g_phys[24].h=1.08100; g_phys[24].l=1.07750; g_phys[24].c=1.07800;
    g_phys[25].o=1.07800; g_phys[25].h=1.07950; g_phys[25].l=1.07750; g_phys[25].c=1.07900;
    g_phys[26].o=1.07900; g_phys[26].h=1.08200; g_phys[26].l=1.07850; g_phys[26].c=1.08150;
    g_phys[27].o=1.08000; g_phys[27].h=1.08100; g_phys[27].l=1.07950; g_phys[27].c=1.08050;
    g_phys[28].o=1.08050; g_phys[28].h=1.08100; g_phys[28].l=1.07500; g_phys[28].c=1.07600;
    g_phys[29].o=1.07600; g_phys[29].h=1.07650; g_phys[29].l=1.07200; g_phys[29].c=1.07250;

    // Remaining bars: neutral
    for(int i = 30; i < g_totalBars; i++)
    {
        g_phys[i].o=1.07400; g_phys[i].h=1.07500; g_phys[i].l=1.07300; g_phys[i].c=1.07400;
    }

    // Set timestamps
    for(int i = 0; i < g_totalBars; i++)
    {
        g_phys[i].t = baseTime + i * barMinutes * 60;
    }

    g_log.LogInfo(StringFormat("Generated %d synthetic physical bars", g_totalBars));
}

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
void PrintCandle(const double &o[], const double &h[], const double &l[],
                 const double &c[], const datetime &t[], int idx, string label)
{
    g_log.LogInfo(StringFormat("  %s [%d] T=%s O=%.5f H=%.5f L=%.5f C=%.5f",
        label, idx, TimeToString(t[idx], TIME_DATE | TIME_MINUTES),
        o[idx], h[idx], l[idx], c[idx]));
}

//+------------------------------------------------------------------+
void RunPipeline(void)
{
    g_log.LogInfo("========================================");
    g_log.LogInfo("Running full pipeline INCREMENTALLY...");

    g_sd.Init();
    g_spe.Init();
    g_bd.Init();
    g_ts.Init();
    g_ppm.Init();
    g_cd.Init();
    g_obd.Init();

    int totalBars = g_totalBars;

    for(int stage = 5; stage <= totalBars; stage++)
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

        static int lastChochCount = 0;
        static int lastObCount = 0;
        if(g_cd.GetCHOCHCount() > lastChochCount || g_obd.GetOrderBlockCount() > lastObCount)
        {
            g_log.LogInfo(StringFormat("--- Stage %d/%d (bar %s) ---",
                stage, totalBars, TimeToString(time[0], TIME_DATE | TIME_MINUTES)));
            g_log.LogInfo(StringFormat("  CHOCH: %d, OB: %d",
                g_cd.GetCHOCHCount(), g_obd.GetOrderBlockCount()));

            for(int i = lastChochCount; i < g_cd.GetCHOCHCount(); i++)
            {
                CHOCHEvent e;
                if(g_cd.GetCHOCH(i, e))
                    g_log.LogInfo(StringFormat("  NEW CHOCH #%d: ID=%d %s close=%.5f",
                        i, e.id, e.bullish ? "Bullish" : "Bearish", e.breakPrice));
            }
            for(int i = lastObCount; i < g_obd.GetOrderBlockCount(); i++)
            {
                OrderBlock ob;
                if(g_obd.GetOrderBlock(i, ob))
                    g_log.LogInfo(StringFormat("  NEW OB #%d: ID=%d CHOCH=%d %s at %s idx=%d O=%.5f H=%.5f L=%.5f C=%.5f",
                        i, ob.id, ob.chochID, ob.bullish ? "Bullish" : "Bearish",
                        TimeToString(ob.time, TIME_DATE | TIME_MINUTES),
                        ob.candleIndex, ob.open, ob.high, ob.low, ob.close));
            }
            lastChochCount = g_cd.GetCHOCHCount();
            lastObCount = g_obd.GetOrderBlockCount();
        }
    }

    //--- FINAL VALIDATION
    g_log.LogInfo("========================================");
    g_log.LogInfo("FINAL RESULTS");
    g_log.LogInfo("========================================");
    g_log.LogInfo(StringFormat("CHOCH Events: %d", g_cd.GetCHOCHCount()));
    g_log.LogInfo(StringFormat("Order Blocks: %d", g_obd.GetOrderBlockCount()));

    g_log.LogInfo("--- CHOCH Events ---");
    for(int i = 0; i < g_cd.GetCHOCHCount(); i++)
    {
        CHOCHEvent e;
        if(g_cd.GetCHOCH(i, e))
            g_log.LogInfo(StringFormat("  CHOCH #%d: ID=%d %s at %s close=%.5f",
                i, e.id, e.bullish ? "Bullish" : "Bearish",
                TimeToString(e.time, TIME_DATE | TIME_MINUTES), e.breakPrice));
    }

    g_log.LogInfo("--- Order Blocks ---");
    for(int i = 0; i < g_obd.GetOrderBlockCount(); i++)
    {
        OrderBlock ob;
        if(g_obd.GetOrderBlock(i, ob))
        {
            string dirStr = ob.bullish ? "Bullish" : "Bearish";
            string candleDir = (ob.close > ob.open) ? "Bullish" : "Bearish";
            g_log.LogInfo(StringFormat("  OB #%d: ID=%d CHOCH=%d %s T=%s O=%.5f H=%.5f L=%.5f C=%.5f idx=%d cDir=%s quality=%.1f",
                i, ob.id, ob.chochID, dirStr,
                TimeToString(ob.time, TIME_DATE | TIME_MINUTES),
                ob.open, ob.high, ob.low, ob.close, ob.candleIndex, candleDir, ob.qualityScore));
        }
    }

    //--- VALIDATION CHECKS
    g_log.LogInfo("--- Validation ---");
    int errors = 0;
    int obCount = g_obd.GetOrderBlockCount();

    for(int i = 0; i < obCount; i++)
    {
        OrderBlock ob;
        g_obd.GetOrderBlock(i, ob);
        bool found = false;
        for(int j = 0; j < g_cd.GetCHOCHCount(); j++)
        {
            CHOCHEvent e;
            if(g_cd.GetCHOCH(j, e) && e.id == ob.chochID)
            {
                found = true;
                if(e.bullish != ob.bullish)
                {
                    g_log.LogInfo(StringFormat("  ERROR: OB %d direction mismatch with CHOCH %d", ob.id, ob.chochID));
                    errors++;
                }
                if(ob.time > e.time)
                {
                    g_log.LogInfo(StringFormat("  ERROR: OB %d time (%s) > CHOCH %d time (%s)",
                        ob.id, TimeToString(ob.time, TIME_DATE | TIME_MINUTES),
                        e.id, TimeToString(e.time, TIME_DATE | TIME_MINUTES)));
                    errors++;
                }
                break;
            }
        }
        if(!found)
        {
            g_log.LogInfo(StringFormat("  ERROR: OB %d references non-existent CHOCH %d", ob.id, ob.chochID));
            errors++;
        }
    }

    for(int i = 0; i < obCount; i++)
    {
        OrderBlock a;
        g_obd.GetOrderBlock(i, a);
        for(int j = i + 1; j < obCount; j++)
        {
            OrderBlock b;
            g_obd.GetOrderBlock(j, b);
            if(a.id == b.id)
            {
                g_log.LogInfo(StringFormat("  ERROR: Duplicate OB ID %d", a.id));
                errors++;
            }
            if(a.chochID == b.chochID)
            {
                g_log.LogInfo(StringFormat("  ERROR: Duplicate CHOCH ref %d in OBs %d and %d", a.chochID, a.id, b.id));
                errors++;
            }
        }
    }

    for(int i = 1; i < obCount; i++)
    {
        OrderBlock a, b;
        g_obd.GetOrderBlock(i - 1, a);
        g_obd.GetOrderBlock(i, b);
        if(b.id != a.id + 1)
        {
            g_log.LogInfo(StringFormat("  ERROR: Non-sequential IDs: %d then %d", a.id, b.id));
            errors++;
        }
    }

    for(int i = 0; i < obCount; i++)
    {
        OrderBlock ob;
        g_obd.GetOrderBlock(i, ob);
        if(ob.open == ob.close)
        {
            g_log.LogInfo(StringFormat("  ERROR: OB %d has invalid body (open==close)", ob.id));
            errors++;
        }
        bool candleBearish = ob.close < ob.open;
        if(ob.bullish && !candleBearish)
        {
            g_log.LogInfo(StringFormat("  ERROR: OB %d is Bullish but candle is Bullish (should be Bearish)", ob.id));
            errors++;
        }
        if(!ob.bullish && candleBearish)
        {
            g_log.LogInfo(StringFormat("  ERROR: OB %d is Bearish but candle is Bearish (should be Bullish)", ob.id));
            errors++;
        }
    }

    for(int i = 0; i < obCount; i++)
    {
        OrderBlock ob;
        g_obd.GetOrderBlock(i, ob);
        if(ob.qualityScore != 1.0)
        {
            g_log.LogInfo(StringFormat("  ERROR: OB %d qualityScore = %.1f (expected 1.0)", ob.id, ob.qualityScore));
            errors++;
        }
    }

    g_log.LogInfo("========================================");
    if(errors == 0 && obCount > 0)
    {
        g_log.LogInfo("ALL VALIDATIONS PASSED");
        g_log.LogInfo(StringFormat("  %d Order Block(s) correctly detected and validated", obCount));
    }
    else if(errors == 0 && obCount == 0)
    {
        g_log.LogInfo("NO ORDER BLOCKS DETECTED - check synthetic data design");
    }
    else
    {
        g_log.LogInfo(StringFormat("VALIDATION FAILED with %d error(s)", errors));
    }
    g_log.LogInfo("========================================");

    g_obd.Shutdown();
    g_cd.Shutdown();
    g_ppm.Shutdown();
    g_ts.Shutdown();
    g_bd.Shutdown();
    g_spe.Shutdown();
    g_sd.Shutdown();
}

//+------------------------------------------------------------------+
void OnStart(void)
{
    Print("========================================");
    Print("Sprint 8.2 - Order Block Detector Synthetic Test");
    Print("========================================");

    GenerateData();
    RunPipeline();

    Print("========================================");
    Print("Test complete");
    Print("========================================");
}
//+------------------------------------------------------------------+
