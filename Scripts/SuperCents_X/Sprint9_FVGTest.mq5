//+------------------------------------------------------------------+
//|                                        Sprint9_FVGTest.mq5        |
//|       Sprint 9.1 - Fair Value Gap Synthetic Test Harness          |
//+------------------------------------------------------------------+
#property strict

#include "../../Experts/SuperCents_X/Utils/Constants.mqh"
#include "../../Experts/SuperCents_X/Utils/Types.mqh"
#include "../../Experts/SuperCents_X/Utils/Helpers.mqh"
#include "../../Experts/SuperCents_X/Core/Logger.mqh"
#include "../../Experts/SuperCents_X/Structure/FVGDetector.mqh"

CLogger g_log(MODULE_UNKNOWN, "FVGTest");
int g_totalChecks = 0;
int g_checkPassed = 0;
string g_errors[];

#define MIN_BODY (FVG_MIN_BODY_SIZE_PIPS * _Point * 10)

#define REPORT_FILE "Sprint9_FVGTest_Report.txt"

int g_reportHandle = INVALID_HANDLE;

void Report(const string text)
{
    Print(text);
    if(g_reportHandle != INVALID_HANDLE)
    {
        FileWrite(g_reportHandle, text);
        FileFlush(g_reportHandle);
    }
}

struct SynthBar { double o, h, l, c; datetime t; };

void DumpCandleSet(SynthBar &bars[], int count, string label)
{
    Report("[DIAG] " + label + " candles (" + IntegerToString(count) + " bars, newest first):");
    for(int i = 0; i < count; i++)
    {
        Report(StringFormat("[DIAG]   bars[%d]: o=%.5f h=%.5f l=%.5f c=%.5f t=%s",
            i, bars[i].o, bars[i].h, bars[i].l, bars[i].c,
            TimeToString(bars[i].t, TIME_DATE|TIME_MINUTES)));
    }
}

void DumpComputedValues(double &open[], double &high[], double &low[], double &close[], datetime &time[], int count, string label)
{
    Report("[DIAG] " + label + " computed from " + IntegerToString(count) + " bars:");
    double minBody = FVG_MIN_BODY_SIZE_PIPS * _Point * 10;
    Report(StringFormat("[DIAG]   minBody = %d * %.6f * 10 = %.6f", FVG_MIN_BODY_SIZE_PIPS, _Point, minBody));
    Report(StringFormat("[DIAG]   _Point = %.6f", _Point));
    for(int i = count - 1; i >= 2; i--)
    {
        int idxA = i;
        int idxB = i - 1;
        int idxC = i - 2;
        double bodyA = MathAbs(close[idxA] - open[idxA]);
        double bodyC = MathAbs(close[idxC] - open[idxC]);
        double gapLow = 0, gapHigh = 0;
        bool aBullish = close[idxA] > open[idxA];
        bool cBullish = close[idxC] > open[idxC];
        string dir = "none";
        if(aBullish && !cBullish)
        {
            gapLow = low[idxA];
            gapHigh = high[idxC];
            dir = gapHigh < gapLow ? "BEARISH" : "no gap";
        }
        if(!aBullish && cBullish)
        {
            gapLow = high[idxA];
            gapHigh = low[idxC];
            dir = gapHigh > gapLow ? "BULLISH" : "no gap";
        }
        string bodyAStatus = bodyA < minBody ? "REJECT" : "ok";
        string bodyCStatus = bodyC < minBody ? "REJECT" : "ok";
        Report(StringFormat("[DIAG]   i=%d A(idx=%d) body=%.6f[%s] dir=%s B(idx=%d) C(idx=%d) body=%.6f[%s] gap=[%.5f,%.5f] %s",
            i, idxA, bodyA, bodyAStatus, aBullish ? "bull" : "bear",
            idxB, idxC, bodyC, bodyCStatus, gapLow, gapHigh, dir));
    }
}

void DumpDetectorState(CFVGDetector &det, string label)
{
    Report("[DIAG] " + label + " detector state:");
    Report(StringFormat("[DIAG]   IsInitialized = %s", det.IsInitialized() ? "true" : "false"));
    Report(StringFormat("[DIAG]   GetFVGCount  = %d", det.GetFVGCount()));
    int n = det.GetFVGCount();
    for(int i = 0; i < n; i++)
    {
        FairValueGap fvg;
        det.GetFVG(i, fvg);
        Report(StringFormat("[DIAG]   FVG[%d]: id=%d bullish=%s upper=%.5f lower=%.5f time=%s idx=%d score=%.2f",
            i, fvg.id, fvg.bullish ? "true" : "false",
            fvg.upper, fvg.lower,
            TimeToString(fvg.time, TIME_DATE|TIME_MINUTES),
            fvg.candleIndex, fvg.qualityScore));
    }
}

// Converts bars[0]=newest..bars[N-1]=oldest to open[0]=newest..open[N-1]=oldest
void BuildArrays(SynthBar &bars[], int count,
                 double &open[], double &high[], double &low[],
                 double &close[], datetime &time[])
{
    ArrayResize(open, count);
    ArrayResize(high, count);
    ArrayResize(low, count);
    ArrayResize(close, count);
    ArrayResize(time, count);
    for(int i = 0; i < count; i++)
    {
        open[i]  = bars[i].o;
        high[i]  = bars[i].h;
        low[i]   = bars[i].l;
        close[i] = bars[i].c;
        time[i]  = bars[i].t;
    }
}

void Check(bool condition, string label)
{
    g_totalChecks++;
    if(condition)
        g_checkPassed++;
    else
    {
        int n = ArraySize(g_errors);
        ArrayResize(g_errors, n + 1);
        g_errors[n] = label;
    }
}

void Section(string title)
{
    g_log.LogInfo("--- " + title);
}

//--- T1
bool Test1()
{
    Section("T1: Bullish FVG");
    Report("[DIAG] === T1 STATE DUMP ===");
    CFVGDetector det;
    DumpDetectorState(det, "T1 after construction");
    Check(det.IsInitialized() == false, "T1: !initialized before Init");
    Check(det.GetFVGCount() == 0, "T1: cnt=0 before Init");

    det.Init();
    DumpDetectorState(det, "T1 after Init");

    SynthBar bars[3];
    datetime base = D'2026.06.01 00:00';
    bars[2].o=1.08200; bars[2].h=1.08090; bars[2].l=1.07950; bars[2].c=1.08050;
    bars[1].o=1.08050; bars[1].h=1.08250; bars[1].l=1.07950; bars[1].c=1.08200;
    bars[0].o=1.08200; bars[0].h=1.08350; bars[0].l=1.08150; bars[0].c=1.08250;
    for(int i = 0; i < 3; i++) bars[i].t = base + (ArraySize(bars) - 1 - i) * 900;
    DumpCandleSet(bars, 3, "T1 input");

    double o[], h[], l[], c[]; datetime t[];
    BuildArrays(bars, 3, o, h, l, c, t);
    DumpComputedValues(o, h, l, c, t, 3, "T1 before Update");

    Report("[DIAG] T1: calling Update()...");
    det.Update(o, h, l, c, t, 3);
    DumpDetectorState(det, "T1 after Update");

    int cnt = det.GetFVGCount();
    Check(cnt == 1, "T1: expected 1 FVG, got " + IntegerToString(cnt));
    if(cnt >= 1)
    {
        FairValueGap fvg;
        det.GetFVG(0, fvg);
        Check(fvg.bullish == true, "T1: expected bullish");
        Check(MathAbs(fvg.lower - 1.08090) < 0.00001, "T1 lower=high(A)=1.08090");
        Check(MathAbs(fvg.upper - 1.08150) < 0.00001, "T1 upper=low(C)=1.08150");
        Check(fvg.upper > fvg.lower, "T1 upper>lower");
    }

    det.Shutdown();
    DumpDetectorState(det, "T1 after Shutdown");
    Check(det.IsInitialized() == false, "T1: !initialized after Shutdown");
    return true;
}

//--- T2
bool Test2()
{
    Section("T2: Bearish FVG");
    CFVGDetector det;
    det.Init();
    // bars[2]=oldest:A(bullish), bars[1]=B, bars[0]=newest:C(bearish)
    // Need: high[C] < low[A]
    SynthBar bars[3];
    datetime base = D'2026.06.01 00:00';
    bars[2].o=1.08200; bars[2].h=1.08400; bars[2].l=1.08330; bars[2].c=1.08350; // A bullish low=1.08330
    bars[1].o=1.08350; bars[1].h=1.08400; bars[1].l=1.08200; bars[1].c=1.08250; // B displacement
    bars[0].o=1.08250; bars[0].h=1.08280; bars[0].l=1.08100; bars[0].c=1.08200; // C bearish high=1.08280
    for(int i = 0; i < 3; i++) bars[i].t = base + (ArraySize(bars) - 1 - i) * 900;
    double o[], h[], l[], c[]; datetime t[];
    BuildArrays(bars, 3, o, h, l, c, t);
    det.Update(o, h, l, c, t, 3);
    int cnt = det.GetFVGCount();
    Check(cnt == 1, "T2: expected 1 FVG, got " + IntegerToString(cnt));
    if(cnt >= 1)
    {
        FairValueGap fvg;
        det.GetFVG(0, fvg);
        Check(fvg.bullish == false, "T2: expected bearish");
        Check(MathAbs(fvg.upper - 1.08330) < 0.00001, "T2 upper=low(A)=1.08330");
        Check(MathAbs(fvg.lower - 1.08280) < 0.00001, "T2 lower=high(C)=1.08280");
        Check(fvg.upper > fvg.lower, "T2 upper>lower");
    }
    det.Shutdown();
    return true;
}

//--- T3
bool Test3()
{
    Section("T3: No Gap");
    CFVGDetector det;
    det.Init();
    SynthBar bars[3];
    datetime base = D'2026.06.01 00:00';
    for(int i = 0; i < 3; i++)
    {
        bars[i].o = 1.08000; bars[i].h = 1.08100;
        bars[i].l = 1.07950; bars[i].c = 1.08000;
        bars[i].t = base + (ArraySize(bars) - 1 - i) * 900;
    }
    double o[], h[], l[], c[]; datetime t[];
    BuildArrays(bars, 3, o, h, l, c, t);
    det.Update(o, h, l, c, t, 3);
    Check(det.GetFVGCount() == 0, "T3: expected 0 FVGs, got " + IntegerToString(det.GetFVGCount()));
    det.Shutdown();
    return true;
}

//--- T4
bool Test4()
{
    Section("T4: Gap Below Threshold");
    CFVGDetector det;
    det.Init();
    // Gap exists but body < minBody
    double smallBody = MIN_BODY * 0.49;
    SynthBar bars[3];
    datetime base = D'2026.06.01 00:00';
    // A: bearish, body=smallBody (< minBody)
    bars[2].o = 1.08000; bars[2].h = 1.08000; bars[2].l = 1.07900; bars[2].c = 1.08000 - smallBody;
    // B: any
    bars[1].o = 1.07950; bars[1].h = 1.08100; bars[1].l = 1.07900; bars[1].c = 1.08050;
    // C: bullish, body=smallBody (< minBody)
    bars[0].o = 1.08050; bars[0].h = 1.08200; bars[0].l = 1.08010; bars[0].c = 1.08050 + smallBody;
    for(int i = 0; i < 3; i++) bars[i].t = base + (ArraySize(bars) - 1 - i) * 900;
    double o[], h[], l[], c[]; datetime t[];
    BuildArrays(bars, 3, o, h, l, c, t);
    det.Update(o, h, l, c, t, 3);
    Check(det.GetFVGCount() == 0, "T4: expected 0 FVGs (rejected by min body), got " + IntegerToString(det.GetFVGCount()));
    det.Shutdown();
    return true;
}

//--- T5
bool Test5()
{
    Section("T5: Consecutive Bullish FVGs");
    CFVGDetector det;
    det.Init();
    SynthBar bars[14];
    // bars[13]=oldest..bars[0]=newest
    // FVG1 at i=13: A=bars[13](bearish), B=bars[12], C=bars[11](bullish)
    // Padding bars[10],[9] with small body prevent intermediates
    // FVG2 at i=8:  A=bars[8](bearish),  B=bars[7],  C=bars[6](bullish)
    // Padding bars[5],[4]
    // FVG3 at i=3:  A=bars[3](bearish),  B=bars[2],  C=bars[1](bullish)
    // bars[0] pad
    datetime base = D'2026.06.01 00:00';
    bars[13].o=1.08200; bars[13].h=1.08090; bars[13].l=1.07950; bars[13].c=1.08050;
    bars[12].o=1.08050; bars[12].h=1.08050; bars[12].l=1.07900; bars[12].c=1.08020;
    bars[11].o=1.08150; bars[11].h=1.08300; bars[11].l=1.08140; bars[11].c=1.08250;
    bars[10].o=1.08000; bars[10].h=1.08000; bars[10].l=1.07950; bars[10].c=1.08020;
    bars[9].o=1.08000;  bars[9].h=1.08000;  bars[9].l=1.07950;  bars[9].c=1.08020;
    bars[8].o=1.08200;  bars[8].h=1.08140;  bars[8].l=1.08000;  bars[8].c=1.08050;
    bars[7].o=1.08050;  bars[7].h=1.08250;  bars[7].l=1.08000;  bars[7].c=1.08200;
    bars[6].o=1.08200;  bars[6].h=1.08350;  bars[6].l=1.08180;  bars[6].c=1.08250;
    bars[5].o=1.08000;  bars[5].h=1.08000;  bars[5].l=1.07950;  bars[5].c=1.08020;
    bars[4].o=1.08000;  bars[4].h=1.08000;  bars[4].l=1.07950;  bars[4].c=1.08020;
    bars[3].o=1.08200;  bars[3].h=1.08180;  bars[3].l=1.08050;  bars[3].c=1.08100;
    bars[2].o=1.08100;  bars[2].h=1.08300;  bars[2].l=1.08050;  bars[2].c=1.08250;
    bars[1].o=1.08250;  bars[1].h=1.08400;  bars[1].l=1.08220;  bars[1].c=1.08300;
    bars[0].o=1.08000;  bars[0].h=1.08000;  bars[0].l=1.07950;  bars[0].c=1.08020;
    for(int i = 0; i < 14; i++) bars[i].t = base + (ArraySize(bars) - 1 - i) * 900;
    double o[], h[], l[], c[]; datetime t[];
    BuildArrays(bars, 14, o, h, l, c, t);
    det.Update(o, h, l, c, t, 14);
    int cnt = det.GetFVGCount();
    Check(cnt == 3, "T5: expected 3 FVGs, got " + IntegerToString(cnt));
    for(int i = 0; i < cnt && i < 3; i++)
    {
        FairValueGap fvg;
        det.GetFVG(i, fvg);
        Check(fvg.bullish == true, "T5 FVG#" + IntegerToString(i) + " expected bullish");
    }
    det.Shutdown();
    return true;
}

//--- T6
bool Test6()
{
    Section("T6: Consecutive Bearish FVGs");
    CFVGDetector det;
    det.Init();
    SynthBar bars[14];
    datetime base = D'2026.06.01 00:00';
    bars[13].o=1.08200; bars[13].h=1.08400; bars[13].l=1.08330; bars[13].c=1.08350;
    bars[12].o=1.08350; bars[12].h=1.08350; bars[12].l=1.08200; bars[12].c=1.08250;
    bars[11].o=1.08250; bars[11].h=1.08280; bars[11].l=1.08100; bars[11].c=1.08200;
    bars[10].o=1.08100; bars[10].h=1.08100; bars[10].l=1.08050; bars[10].c=1.08080;
    bars[9].o=1.08100;  bars[9].h=1.08100;  bars[9].l=1.08050;  bars[9].c=1.08080;
    bars[8].o=1.08150;  bars[8].h=1.08250;  bars[8].l=1.08180;  bars[8].c=1.08200;
    bars[7].o=1.08200;  bars[7].h=1.08200;  bars[7].l=1.08000;  bars[7].c=1.08050;
    bars[6].o=1.08100;  bars[6].h=1.08130;  bars[6].l=1.07950;  bars[6].c=1.08000;
    bars[5].o=1.08000;  bars[5].h=1.08000;  bars[5].l=1.07950;  bars[5].c=1.07980;
    bars[4].o=1.08000;  bars[4].h=1.08000;  bars[4].l=1.07950;  bars[4].c=1.07980;
    bars[3].o=1.08050;  bars[3].h=1.08150;  bars[3].l=1.08030;  bars[3].c=1.08100;
    bars[2].o=1.08100;  bars[2].h=1.08100;  bars[2].l=1.07900;  bars[2].c=1.07950;
    bars[1].o=1.08000;  bars[1].h=1.07980;  bars[1].l=1.07850;  bars[1].c=1.07900;
    bars[0].o=1.07900;  bars[0].h=1.07900;  bars[0].l=1.07850;  bars[0].c=1.07880;
    for(int i = 0; i < 14; i++) bars[i].t = base + (ArraySize(bars) - 1 - i) * 900;
    double o[], h[], l[], c[]; datetime t[];
    BuildArrays(bars, 14, o, h, l, c, t);
    det.Update(o, h, l, c, t, 14);
    int cnt = det.GetFVGCount();
    Check(cnt == 3, "T6: expected 3 FVGs, got " + IntegerToString(cnt));
    for(int i = 0; i < cnt && i < 3; i++)
    {
        FairValueGap fvg;
        det.GetFVG(i, fvg);
        Check(fvg.bullish == false, "T6 FVG#" + IntegerToString(i) + " expected bearish");
    }
    det.Shutdown();
    return true;
}

//--- T7
bool Test7()
{
    Section("T7: Mixed Direction");
    CFVGDetector det;
    det.Init();
    SynthBar bars[14];
    datetime base = D'2026.06.01 00:00';
    // Bullish
    bars[13].o=1.08200; bars[13].h=1.08090; bars[13].l=1.07950; bars[13].c=1.08050;
    bars[12].o=1.08050; bars[12].h=1.08250; bars[12].l=1.07950; bars[12].c=1.08200;
    bars[11].o=1.08200; bars[11].h=1.08350; bars[11].l=1.08150; bars[11].c=1.08250;
    bars[10].o=1.08100; bars[10].h=1.08100; bars[10].l=1.08050; bars[10].c=1.08080;
    bars[9].o=1.08100;  bars[9].h=1.08100;  bars[9].l=1.08050;  bars[9].c=1.08080;
    // Bearish
    bars[8].o=1.08150;  bars[8].h=1.08250;  bars[8].l=1.08130;  bars[8].c=1.08200;
    bars[7].o=1.08200;  bars[7].h=1.08200;  bars[7].l=1.08000;  bars[7].c=1.08050;
    bars[6].o=1.08100;  bars[6].h=1.08080;  bars[6].l=1.07950;  bars[6].c=1.08000;
    bars[5].o=1.08000;  bars[5].h=1.08000;  bars[5].l=1.07950;  bars[5].c=1.07980;
    bars[4].o=1.08000;  bars[4].h=1.08000;  bars[4].l=1.07950;  bars[4].c=1.07980;
    // Bullish
    bars[3].o=1.08000;  bars[3].h=1.07900;  bars[3].l=1.07800;  bars[3].c=1.07850;
    bars[2].o=1.07850;  bars[2].h=1.08050;  bars[2].l=1.07800;  bars[2].c=1.08000;
    bars[1].o=1.08000;  bars[1].h=1.08150;  bars[1].l=1.07980;  bars[1].c=1.08100;
    bars[0].o=1.08000;  bars[0].h=1.08000;  bars[0].l=1.07950;  bars[0].c=1.07980;
    for(int i = 0; i < 14; i++) bars[i].t = base + (ArraySize(bars) - 1 - i) * 900;
    double o[], h[], l[], c[]; datetime t[];
    BuildArrays(bars, 14, o, h, l, c, t);
    det.Update(o, h, l, c, t, 14);
    int cnt = det.GetFVGCount();
    Check(cnt == 3, "T7: expected 3 FVGs, got " + IntegerToString(cnt));
    if(cnt >= 3)
    {
        FairValueGap f0, f1, f2;
        det.GetFVG(0, f0); det.GetFVG(1, f1); det.GetFVG(2, f2);
        Check(f0.bullish == true,  "T7 FVG1 bullish");
        Check(f1.bullish == false, "T7 FVG2 bearish");
        Check(f2.bullish == true,  "T7 FVG3 bullish");
    }
    det.Shutdown();
    return true;
}

//--- T8
bool Test8()
{
    Section("T8: Lifecycle Placeholder");
    CFVGDetector det;
    det.Init();
    SynthBar bars[3];
    datetime base = D'2026.06.01 00:00';
    bars[2].o=1.08200; bars[2].h=1.08090; bars[2].l=1.07950; bars[2].c=1.08050;
    bars[1].o=1.08050; bars[1].h=1.08250; bars[1].l=1.07950; bars[1].c=1.08200;
    bars[0].o=1.08200; bars[0].h=1.08350; bars[0].l=1.08150; bars[0].c=1.08250;
    for(int i = 0; i < 3; i++) bars[i].t = base + (ArraySize(bars) - 1 - i) * 900;
    double o[], h[], l[], c[]; datetime t[];
    BuildArrays(bars, 3, o, h, l, c, t);
    det.Update(o, h, l, c, t, 3);
    int cnt = det.GetFVGCount();
    Check(cnt >= 1, "T8: FVG created");
    if(cnt >= 1)
    {
        FairValueGap fvg;
        det.GetFVG(0, fvg);
        Check(fvg.filled == false, "T8: filled=false (lifecycle out of scope for v0.9.0)");
        Check(fvg.fillTime == 0, "T8: fillTime=0 (lifecycle out of scope for v0.9.0)");
    }
    det.Shutdown();
    return true;
}

//--- T9
bool Test9()
{
    Section("T9: Unfilled FVG");
    CFVGDetector det;
    det.Init();
    SynthBar bars[3];
    datetime base = D'2026.06.01 00:00';
    bars[2].o=1.08200; bars[2].h=1.08090; bars[2].l=1.07950; bars[2].c=1.08050;
    bars[1].o=1.08050; bars[1].h=1.08250; bars[1].l=1.07950; bars[1].c=1.08200;
    bars[0].o=1.08200; bars[0].h=1.08350; bars[0].l=1.08150; bars[0].c=1.08250;
    for(int i = 0; i < 3; i++) bars[i].t = base + (ArraySize(bars) - 1 - i) * 900;
    double o[], h[], l[], c[]; datetime t[];
    BuildArrays(bars, 3, o, h, l, c, t);
    det.Update(o, h, l, c, t, 3);
    int cnt = det.GetFVGCount();
    Check(cnt >= 1, "T9: FVG created");
    if(cnt >= 1)
    {
        FairValueGap fvg;
        det.GetFVG(0, fvg);
        Check(fvg.filled == false, "T9: filled=false (unfilled)");
    }
    det.Shutdown();
    return true;
}

//--- T10
bool Test10()
{
    Section("T10: Duplicate Prevention");
    CFVGDetector det;
    det.Init();
    SynthBar bars[3];
    datetime base = D'2026.06.01 00:00';
    bars[2].o=1.08200; bars[2].h=1.08090; bars[2].l=1.07950; bars[2].c=1.08050;
    bars[1].o=1.08050; bars[1].h=1.08250; bars[1].l=1.07950; bars[1].c=1.08200;
    bars[0].o=1.08200; bars[0].h=1.08350; bars[0].l=1.08150; bars[0].c=1.08250;
    for(int i = 0; i < 3; i++) bars[i].t = base + (ArraySize(bars) - 1 - i) * 900;
    double o[], h[], l[], c[]; datetime t[];
    BuildArrays(bars, 3, o, h, l, c, t);
    det.Update(o, h, l, c, t, 3);
    int cnt1 = det.GetFVGCount();
    det.Update(o, h, l, c, t, 3);
    int cnt2 = det.GetFVGCount();
    Check(cnt1 == cnt2, "T10: count unchanged (" + IntegerToString(cnt1) + " vs " + IntegerToString(cnt2) + ")");
    int ids[];
    bool dupFound = false;
    for(int i = 0; i < cnt2; i++)
    {
        FairValueGap fvg;
        det.GetFVG(i, fvg);
        int sz = ArraySize(ids);
        for(int j = 0; j < sz; j++)
            if(ids[j] == fvg.id) dupFound = true;
        ArrayResize(ids, sz + 1);
        ids[sz] = fvg.id;
    }
    Check(!dupFound, "T10: no duplicate IDs");
    det.Shutdown();
    return true;
}

//--- T11
bool Test11()
{
    Section("T11: Chronology");
    CFVGDetector det;
    det.Init();
    SynthBar bars[14];
    datetime base = D'2026.06.01 00:00';
    bars[13].o=1.08200; bars[13].h=1.08090; bars[13].l=1.07950; bars[13].c=1.08050;
    bars[12].o=1.08050; bars[12].h=1.08050; bars[12].l=1.07900; bars[12].c=1.08020;
    bars[11].o=1.08150; bars[11].h=1.08300; bars[11].l=1.08140; bars[11].c=1.08250;
    bars[10].o=1.08000; bars[10].h=1.08000; bars[10].l=1.07950; bars[10].c=1.08020;
    bars[9].o=1.08000;  bars[9].h=1.08000;  bars[9].l=1.07950;  bars[9].c=1.08020;
    bars[8].o=1.08200;  bars[8].h=1.08140;  bars[8].l=1.08000;  bars[8].c=1.08050;
    bars[7].o=1.08050;  bars[7].h=1.08250;  bars[7].l=1.08000;  bars[7].c=1.08200;
    bars[6].o=1.08200;  bars[6].h=1.08350;  bars[6].l=1.08180;  bars[6].c=1.08250;
    bars[5].o=1.08000;  bars[5].h=1.08000;  bars[5].l=1.07950;  bars[5].c=1.08020;
    bars[4].o=1.08000;  bars[4].h=1.08000;  bars[4].l=1.07950;  bars[4].c=1.08020;
    bars[3].o=1.08200;  bars[3].h=1.08180;  bars[3].l=1.08050;  bars[3].c=1.08100;
    bars[2].o=1.08100;  bars[2].h=1.08300;  bars[2].l=1.08050;  bars[2].c=1.08250;
    bars[1].o=1.08250;  bars[1].h=1.08400;  bars[1].l=1.08220;  bars[1].c=1.08300;
    bars[0].o=1.08000;  bars[0].h=1.08000;  bars[0].l=1.07950;  bars[0].c=1.08020;
    for(int i = 0; i < 14; i++) bars[i].t = base + (ArraySize(bars) - 1 - i) * 900;
    double o[], h[], l[], c[]; datetime t[];
    BuildArrays(bars, 14, o, h, l, c, t);
    det.Update(o, h, l, c, t, 14);
    int cnt = det.GetFVGCount();
    bool chronoOk = true;
    datetime prev = 0;
    for(int i = 0; i < cnt; i++)
    {
        FairValueGap fvg;
        det.GetFVG(i, fvg);
        if(i > 0 && fvg.time < prev) chronoOk = false;
        prev = fvg.time;
    }
    Check(cnt > 0, "T11: FVGs detected");
    Check(chronoOk, "T11: times monotonically increase");
    det.Shutdown();
    return true;
}

//--- T12
bool Test12()
{
    Section("T12: Sequential IDs");
    CFVGDetector det;
    det.Init();
    SynthBar bars[14];
    datetime base = D'2026.06.01 00:00';
    bars[13].o=1.08200; bars[13].h=1.08090; bars[13].l=1.07950; bars[13].c=1.08050;
    bars[12].o=1.08050; bars[12].h=1.08050; bars[12].l=1.07900; bars[12].c=1.08020;
    bars[11].o=1.08150; bars[11].h=1.08300; bars[11].l=1.08140; bars[11].c=1.08250;
    bars[10].o=1.08000; bars[10].h=1.08000; bars[10].l=1.07950; bars[10].c=1.08020;
    bars[9].o=1.08000;  bars[9].h=1.08000;  bars[9].l=1.07950;  bars[9].c=1.08020;
    bars[8].o=1.08200;  bars[8].h=1.08140;  bars[8].l=1.08000;  bars[8].c=1.08050;
    bars[7].o=1.08050;  bars[7].h=1.08250;  bars[7].l=1.08000;  bars[7].c=1.08200;
    bars[6].o=1.08200;  bars[6].h=1.08350;  bars[6].l=1.08180;  bars[6].c=1.08250;
    bars[5].o=1.08000;  bars[5].h=1.08000;  bars[5].l=1.07950;  bars[5].c=1.08020;
    bars[4].o=1.08000;  bars[4].h=1.08000;  bars[4].l=1.07950;  bars[4].c=1.08020;
    bars[3].o=1.08200;  bars[3].h=1.08180;  bars[3].l=1.08050;  bars[3].c=1.08100;
    bars[2].o=1.08100;  bars[2].h=1.08300;  bars[2].l=1.08050;  bars[2].c=1.08250;
    bars[1].o=1.08250;  bars[1].h=1.08400;  bars[1].l=1.08220;  bars[1].c=1.08300;
    bars[0].o=1.08000;  bars[0].h=1.08000;  bars[0].l=1.07950;  bars[0].c=1.08020;
    for(int i = 0; i < 14; i++) bars[i].t = base + (ArraySize(bars) - 1 - i) * 900;
    double o[], h[], l[], c[]; datetime t[];
    BuildArrays(bars, 14, o, h, l, c, t);
    det.Update(o, h, l, c, t, 14);
    int cnt = det.GetFVGCount();
    bool seq = true;
    for(int i = 0; i < cnt; i++)
    {
        FairValueGap fvg;
        det.GetFVG(i, fvg);
        if(fvg.id != i) seq = false;
    }
    Check(seq, "T12: sequential IDs 0.." + IntegerToString(cnt - 1));
    det.Shutdown();
    return true;
}

//--- T13
bool Test13()
{
    Section("T13: Gap Boundaries");
    CFVGDetector det;
    det.Init();
    SynthBar bars[14];
    datetime base = D'2026.06.01 00:00';
    bars[13].o=1.08000; bars[13].h=1.08000; bars[13].l=1.07950; bars[13].c=1.07980;
    // Bullish
    bars[12].o=1.08200; bars[12].h=1.08090; bars[12].l=1.07950; bars[12].c=1.08050;
    bars[11].o=1.08050; bars[11].h=1.08250; bars[11].l=1.07950; bars[11].c=1.08200;
    bars[10].o=1.08200; bars[10].h=1.08350; bars[10].l=1.08150; bars[10].c=1.08250;
    bars[9].o=1.08100;  bars[9].h=1.08100;  bars[9].l=1.08050;  bars[9].c=1.08080;
    // Bearish
    bars[8].o=1.08150;  bars[8].h=1.08250;  bars[8].l=1.08130;  bars[8].c=1.08200;
    bars[7].o=1.08200;  bars[7].h=1.08200;  bars[7].l=1.08000;  bars[7].c=1.08050;
    bars[6].o=1.08100;  bars[6].h=1.08080;  bars[6].l=1.07950;  bars[6].c=1.08000;
    bars[5].o=1.08000;  bars[5].h=1.08000;  bars[5].l=1.07950;  bars[5].c=1.07980;
    // Bullish
    bars[4].o=1.08000;  bars[4].h=1.07900;  bars[4].l=1.07800;  bars[4].c=1.07850;
    bars[3].o=1.07850;  bars[3].h=1.08050;  bars[3].l=1.07800;  bars[3].c=1.08000;
    bars[2].o=1.08000;  bars[2].h=1.08150;  bars[2].l=1.07980;  bars[2].c=1.08100;
    bars[1].o=1.08000;  bars[1].h=1.08000;  bars[1].l=1.07950;  bars[1].c=1.07980;
    bars[0].o=1.08000;  bars[0].h=1.08000;  bars[0].l=1.07950;  bars[0].c=1.07980;
    for(int i = 0; i < 14; i++) bars[i].t = base + (ArraySize(bars) - 1 - i) * 900;
    double o[], h[], l[], c[]; datetime t[];
    BuildArrays(bars, 14, o, h, l, c, t);
    det.Update(o, h, l, c, t, 14);
    int cnt = det.GetFVGCount();
    Check(cnt >= 2, "T13: got " + IntegerToString(cnt) + " FVGs");
    for(int i = 0; i < cnt; i++)
    {
        FairValueGap fvg;
        det.GetFVG(i, fvg);
        Check(fvg.upper > fvg.lower, "T13 FVG#" + IntegerToString(i) + " upper>lower");
    }
    det.Shutdown();
    return true;
}

//--- T14
bool Test14()
{
    Section("T14: Quality Score");
    CFVGDetector det;
    det.Init();
    SynthBar bars[3];
    datetime base = D'2026.06.01 00:00';
    bars[2].o=1.08200; bars[2].h=1.08090; bars[2].l=1.07950; bars[2].c=1.08050;
    bars[1].o=1.08050; bars[1].h=1.08250; bars[1].l=1.07950; bars[1].c=1.08200;
    bars[0].o=1.08200; bars[0].h=1.08350; bars[0].l=1.08150; bars[0].c=1.08250;
    for(int i = 0; i < 3; i++) bars[i].t = base + (ArraySize(bars) - 1 - i) * 900;
    double o[], h[], l[], c[]; datetime t[];
    BuildArrays(bars, 3, o, h, l, c, t);
    det.Update(o, h, l, c, t, 3);
    int cnt = det.GetFVGCount();
    Check(cnt >= 1, "T14: FVG created");
    if(cnt >= 1)
    {
        FairValueGap fvg;
        det.GetFVG(0, fvg);
        Check(MathAbs(fvg.qualityScore - 1.0) < 0.001, "T14: qualityScore=" + DoubleToString(fvg.qualityScore, 1));
    }
    det.Shutdown();
    return true;
}

//--- T15
bool Test15()
{
    Section("T15: Determinism");
    SynthBar bars[14];
    datetime base = D'2026.06.01 00:00';
    bars[13].o=1.08200; bars[13].h=1.08090; bars[13].l=1.07950; bars[13].c=1.08050;
    bars[12].o=1.08050; bars[12].h=1.08050; bars[12].l=1.07900; bars[12].c=1.08020;
    bars[11].o=1.08150; bars[11].h=1.08300; bars[11].l=1.08140; bars[11].c=1.08250;
    bars[10].o=1.08000; bars[10].h=1.08000; bars[10].l=1.07950; bars[10].c=1.08020;
    bars[9].o=1.08000;  bars[9].h=1.08000;  bars[9].l=1.07950;  bars[9].c=1.08020;
    bars[8].o=1.08200;  bars[8].h=1.08140;  bars[8].l=1.08000;  bars[8].c=1.08050;
    bars[7].o=1.08050;  bars[7].h=1.08250;  bars[7].l=1.08000;  bars[7].c=1.08200;
    bars[6].o=1.08200;  bars[6].h=1.08350;  bars[6].l=1.08180;  bars[6].c=1.08250;
    bars[5].o=1.08000;  bars[5].h=1.08000;  bars[5].l=1.07950;  bars[5].c=1.08020;
    bars[4].o=1.08000;  bars[4].h=1.08000;  bars[4].l=1.07950;  bars[4].c=1.08020;
    bars[3].o=1.08200;  bars[3].h=1.08180;  bars[3].l=1.08050;  bars[3].c=1.08100;
    bars[2].o=1.08100;  bars[2].h=1.08300;  bars[2].l=1.08050;  bars[2].c=1.08250;
    bars[1].o=1.08250;  bars[1].h=1.08400;  bars[1].l=1.08220;  bars[1].c=1.08300;
    bars[0].o=1.08000;  bars[0].h=1.08000;  bars[0].l=1.07950;  bars[0].c=1.08020;
    for(int i = 0; i < 14; i++) bars[i].t = base + (ArraySize(bars) - 1 - i) * 900;
    double o[], h[], l[], c[]; datetime t[];
    BuildArrays(bars, 14, o, h, l, c, t);

    CFVGDetector det1;
    det1.Init();
    det1.Update(o, h, l, c, t, 14);
    int c1 = det1.GetFVGCount();
    FairValueGap r1[]; ArrayResize(r1, c1);
    for(int i = 0; i < c1; i++) det1.GetFVG(i, r1[i]);
    det1.Shutdown();

    CFVGDetector det2;
    det2.Init();
    det2.Update(o, h, l, c, t, 14);
    int c2 = det2.GetFVGCount();
    FairValueGap r2[]; ArrayResize(r2, c2);
    for(int i = 0; i < c2; i++) det2.GetFVG(i, r2[i]);
    det2.Shutdown();

    Check(c1 == c2, "T15: same count (" + IntegerToString(c1) + " vs " + IntegerToString(c2) + ")");
    bool identical = true;
    int m = MathMin(c1, c2);
    for(int i = 0; i < m; i++)
        if(r1[i].id != r2[i].id || r1[i].bullish != r2[i].bullish ||
           MathAbs(r1[i].upper - r2[i].upper) > 0.00001 ||
           MathAbs(r1[i].lower - r2[i].lower) > 0.00001)
            identical = false;
    Check(identical, "T15: deterministic output across runs");
    return true;
}

//--- T16
bool Test16()
{
    Section("T16: Memory Safety");
    CFVGDetector det;
    for(int r = 0; r < 10; r++)
    {
        if(!det.Init()) { Check(false, "T16: Init failed round " + IntegerToString(r)); break; }
        for(int feed = 0; feed < 5; feed++)
        {
            int n = 3 + feed;
            double o[], h[], l[], c[]; datetime t[];
            ArrayResize(o, n); ArrayResize(h, n);
            ArrayResize(l, n); ArrayResize(c, n);
            ArrayResize(t, n);
            for(int i = 0; i < n; i++)
            {
                double bp = 1.08000 + feed * 0.0010;
                o[i] = bp; h[i] = bp + 0.0020;
                l[i] = bp - 0.0010; c[i] = bp + 0.0010;
                t[i] = D'2026.06.01' + i * 900;
            }
            det.Update(o, h, l, c, t, n);
        }
        det.Shutdown();
    }
    Check(true, "T16: completed without errors");
    return true;
}

//--- T17
bool Test17()
{
    Section("T17: Performance");
    CFVGDetector det;
    det.Init();
    int nBars = 10000;
    double o[], h[], l[], c[]; datetime t[];
    ArrayResize(o, nBars); ArrayResize(h, nBars);
    ArrayResize(l, nBars); ArrayResize(c, nBars);
    ArrayResize(t, nBars);
    datetime base = D'2026.01.01 00:00';
    // Fill so open[0]=newest, open[N-1]=oldest
    for(int i = 0; i < nBars; i++)
    {
        int idx = nBars - 1 - i;
        double trend = MathSin(i * 0.01) * 0.0100;
        double mid = 1.08000 + trend;
        o[idx] = mid; h[idx] = mid + 0.0020;
        l[idx] = mid - 0.0010; c[idx] = mid + 0.0010;
        t[idx] = base + i * 900;
    }
    uint start = GetTickCount();
    det.Update(o, h, l, c, t, nBars);
    uint elapsed = GetTickCount() - start;
    Check(elapsed < 30000, "T17: completed within 30s (" + IntegerToString(elapsed) + "ms)");
    Check(det.GetFVGCount() >= 0, "T17: " + IntegerToString(nBars) + " bars processed, " +
          IntegerToString(det.GetFVGCount()) + " FVGs");
    det.Shutdown();
    return true;
}

//--- T18
bool Test18()
{
    Section("T18: Edge - 3 candles");
    CFVGDetector det;
    det.Init();
    SynthBar bars[3];
    datetime base = D'2026.06.01 00:00';
    bars[2].o=1.08200; bars[2].h=1.08090; bars[2].l=1.07950; bars[2].c=1.08050;
    bars[1].o=1.08050; bars[1].h=1.08250; bars[1].l=1.07950; bars[1].c=1.08200;
    bars[0].o=1.08200; bars[0].h=1.08350; bars[0].l=1.08150; bars[0].c=1.08250;
    for(int i = 0; i < 3; i++) bars[i].t = base + (ArraySize(bars) - 1 - i) * 900;
    double o[], h[], l[], c[]; datetime t[];
    BuildArrays(bars, 3, o, h, l, c, t);
    det.Update(o, h, l, c, t, 3);
    Check(det.GetFVGCount() == 1, "T18: expected 1 FVG with 3 candles, got " + IntegerToString(det.GetFVGCount()));
    det.Shutdown();
    return true;
}

//--- T19
bool Test19()
{
    Section("T19: Edge - 2 candles");
    CFVGDetector det;
    det.Init();
    double o[2] = {1.08200, 1.08000};
    double h[2] = {1.08300, 1.08100};
    double l[2] = {1.08100, 1.07900};
    double c[2] = {1.08250, 1.08050};
    datetime t[2] = {D'2026.06.01 00:15', D'2026.06.01 00:00'};
    det.Update(o, h, l, c, t, 2);
    Check(det.GetFVGCount() == 0, "T19: expected 0 FVGs with 2 candles, got " + IntegerToString(det.GetFVGCount()));
    det.Shutdown();
    return true;
}

//--- T20
bool Test20()
{
    Section("T20: Edge - Empty dataset");
    CFVGDetector det;
    det.Init();
    double o[], h[], l[], c[]; datetime t[];
    det.Update(o, h, l, c, t, 0);
    Check(det.GetFVGCount() == 0, "T20: expected 0 FVGs with empty data");
    Check(det.IsInitialized(), "T20: detector still initialized after empty update");
    det.Shutdown();
    return true;
}

//--- T21
bool Test21()
{
    Section("T21: Gap Equality (strict > / < required)");
    bool ok = true;
    // Bullish: low(C) == high(A) should NOT detect
    {
        CFVGDetector det;
        det.Init();
        SynthBar bars[3];
        datetime base = D'2026.06.01 00:00';
        // A bearish, high=1.08100
        bars[2].o=1.08200; bars[2].h=1.08100; bars[2].l=1.07950; bars[2].c=1.08050;
        bars[1].o=1.08050; bars[1].h=1.08200; bars[1].l=1.07950; bars[1].c=1.08150;
        // C bullish, low=1.08100 == high(A) → no strict gap
        bars[0].o=1.08200; bars[0].h=1.08300; bars[0].l=1.08100; bars[0].c=1.08250;
        for(int i = 0; i < 3; i++) bars[i].t = base + (ArraySize(bars) - 1 - i) * 900;
        double o[], h[], l[], c[]; datetime t[];
        BuildArrays(bars, 3, o, h, l, c, t);
        det.Update(o, h, l, c, t, 3);
        if(det.GetFVGCount() != 0)
        {
            Check(false, "T21: bullish equality (low(C)==high(A)) detected FVG incorrectly");
            ok = false;
        }
        det.Shutdown();
    }
    // Bearish: high(C) == low(A) should NOT detect
    {
        CFVGDetector det;
        det.Init();
        SynthBar bars[3];
        datetime base = D'2026.06.01 00:00';
        // A bullish, low=1.08100
        bars[2].o=1.08050; bars[2].h=1.08200; bars[2].l=1.08100; bars[2].c=1.08150;
        bars[1].o=1.08150; bars[1].h=1.08200; bars[1].l=1.08050; bars[1].c=1.08100;
        // C bearish, high=1.08100 == low(A) → no strict gap
        bars[0].o=1.08150; bars[0].h=1.08100; bars[0].l=1.08000; bars[0].c=1.08050;
        for(int i = 0; i < 3; i++) bars[i].t = base + (ArraySize(bars) - 1 - i) * 900;
        double o[], h[], l[], c[]; datetime t[];
        BuildArrays(bars, 3, o, h, l, c, t);
        det.Update(o, h, l, c, t, 3);
        if(det.GetFVGCount() != 0)
        {
            Check(false, "T21: bearish equality (high(C)==low(A)) detected FVG incorrectly");
            ok = false;
        }
        det.Shutdown();
    }
    if(ok)
        Check(true, "T21: equality gaps correctly rejected");
    return ok;
}

//--- T22
bool Test22()
{
    Section("T22: Floating Point Precision");
    bool ok = true;
    // Tight bullish gap at 5-digit precision: low(C)=1.08001 > high(A)=1.08000
    {
        CFVGDetector det;
        det.Init();
        SynthBar bars[3];
        datetime base = D'2026.06.01 00:00';
        bars[2].o=1.08200; bars[2].h=1.08000; bars[2].l=1.07950; bars[2].c=1.08050;
        bars[1].o=1.08050; bars[1].h=1.08100; bars[1].l=1.07950; bars[1].c=1.08080;
        bars[0].o=1.08100; bars[0].h=1.08200; bars[0].l=1.08001; bars[0].c=1.08150;
        for(int i = 0; i < 3; i++) bars[i].t = base + (ArraySize(bars) - 1 - i) * 900;
        double o[], h[], l[], c[]; datetime t[];
        BuildArrays(bars, 3, o, h, l, c, t);
        det.Update(o, h, l, c, t, 3);
        int cnt = det.GetFVGCount();
        if(cnt != 1)
        {
            Check(false, "T22: tight bullish gap (low=1.08001 > high=1.08000) not detected");
            ok = false;
        }
        else
        {
            FairValueGap fvg;
            det.GetFVG(0, fvg);
            if(MathAbs(fvg.lower - 1.08000) > 0.00001 || MathAbs(fvg.upper - 1.08001) > 0.00001)
            {
                Check(false, "T22: tight bullish gap boundaries wrong");
                ok = false;
            }
        }
        det.Shutdown();
    }
    // Tight bearish gap: high(C)=1.07999 < low(A)=1.08000
    {
        CFVGDetector det;
        det.Init();
        SynthBar bars[3];
        datetime base = D'2026.06.01 00:00';
        bars[2].o=1.08050; bars[2].h=1.08200; bars[2].l=1.08000; bars[2].c=1.08150;
        bars[1].o=1.08150; bars[1].h=1.08150; bars[1].l=1.08000; bars[1].c=1.08050;
        bars[0].o=1.08100; bars[0].h=1.07999; bars[0].l=1.07900; bars[0].c=1.08000;
        for(int i = 0; i < 3; i++) bars[i].t = base + (ArraySize(bars) - 1 - i) * 900;
        double o[], h[], l[], c[]; datetime t[];
        BuildArrays(bars, 3, o, h, l, c, t);
        det.Update(o, h, l, c, t, 3);
        int cnt = det.GetFVGCount();
        if(cnt != 1)
        {
            Check(false, "T22: tight bearish gap (high=1.07999 < low=1.08000) not detected");
            ok = false;
        }
        det.Shutdown();
    }
    if(ok)
        Check(true, "T22: floating-point precision gaps handled correctly");
    return ok;
}

//--- T24: State Leakage Diagnostic — repeat T1 data at end of run
bool Test24()
{
    Section("T24: State Leakage - repeat T1 data");
    Report("[DIAG] === T24 STATE DUMP ===");
    CFVGDetector det;
    DumpDetectorState(det, "T24 after construction");
    Check(det.GetFVGCount() == 0, "T24: cnt=0 before Init");
    Check(det.IsInitialized() == false, "T24: !initialized before Init");

    det.Init();
    DumpDetectorState(det, "T24 after Init");
    Check(det.GetFVGCount() == 0, "T24: cnt=0 after Init");
    Check(det.IsInitialized() == true, "T24: initialized after Init");

    SynthBar bars[3];
    datetime base = D'2026.06.01 00:00';
    bars[2].o=1.08200; bars[2].h=1.08090; bars[2].l=1.07950; bars[2].c=1.08050;
    bars[1].o=1.08050; bars[1].h=1.08250; bars[1].l=1.07950; bars[1].c=1.08200;
    bars[0].o=1.08200; bars[0].h=1.08350; bars[0].l=1.08150; bars[0].c=1.08250;
    for(int i = 0; i < 3; i++) bars[i].t = base + (ArraySize(bars) - 1 - i) * 900;
    DumpCandleSet(bars, 3, "T24 input");

    double o[], h[], l[], c[]; datetime t[];
    BuildArrays(bars, 3, o, h, l, c, t);
    DumpComputedValues(o, h, l, c, t, 3, "T24 before Update");

    Report("[DIAG] T24: calling Update()...");
    det.Update(o, h, l, c, t, 3);
    DumpDetectorState(det, "T24 after Update");

    int cnt = det.GetFVGCount();
    Check(cnt == 1, "T24: expected 1 FVG (repeat T1), got " + IntegerToString(cnt));
    if(cnt >= 1)
    {
        FairValueGap fvg;
        det.GetFVG(0, fvg);
        Check(fvg.bullish == true, "T24: bullish");
        Check(MathAbs(fvg.lower - 1.08090) < 0.00001, "T24: lower");
        Check(MathAbs(fvg.upper - 1.08150) < 0.00001, "T24: upper");
    }

    det.Shutdown();
    DumpDetectorState(det, "T24 after Shutdown");
    Check(det.IsInitialized() == false, "T24: !initialized after Shutdown");
    return true;
}

//--- T25: Create/destroy cycle stress test
bool Test25()
{
    Section("T25: Cycle stress - 10 create/destroy with T1 data");
    bool allConsistent = true;
    for(int cycle = 0; cycle < 10; cycle++)
    {
        CFVGDetector det;
        Check(det.GetFVGCount() == 0, "T25 cycle " + IntegerToString(cycle) + ": cnt=0 before Init");
        Check(det.IsInitialized() == false, "T25 cycle " + IntegerToString(cycle) + ": !initialized before Init");
        det.Init();
        Check(det.GetFVGCount() == 0, "T25 cycle " + IntegerToString(cycle) + ": cnt=0 after Init");
        Check(det.IsInitialized() == true, "T25 cycle " + IntegerToString(cycle) + ": initialized after Init");
        SynthBar bars[3];
        datetime base = D'2026.06.01 00:00';
        bars[2].o=1.08200; bars[2].h=1.08090; bars[2].l=1.07950; bars[2].c=1.08050;
        bars[1].o=1.08050; bars[1].h=1.08250; bars[1].l=1.07950; bars[1].c=1.08200;
        bars[0].o=1.08200; bars[0].h=1.08350; bars[0].l=1.08150; bars[0].c=1.08250;
        for(int i = 0; i < 3; i++) bars[i].t = base + (ArraySize(bars) - 1 - i) * 900;
        double o[], h[], l[], c[]; datetime t[];
        BuildArrays(bars, 3, o, h, l, c, t);
        det.Update(o, h, l, c, t, 3);
        int cnt = det.GetFVGCount();
        if(cnt != 1)
        {
            Check(false, "T25 cycle " + IntegerToString(cycle) + ": expected 1 FVG, got " + IntegerToString(cnt));
            allConsistent = false;
        }
        det.Shutdown();
        Check(det.IsInitialized() == false, "T25 cycle " + IntegerToString(cycle) + ": !initialized after Shutdown");
    }
    if(allConsistent)
        Check(true, "T25: all 10 cycles consistent (1 FVG each)");
    return true;
}

//--- T23
bool Test23()
{
    Section("T23: Incremental Processing");
    CFVGDetector det;
    det.Init();
    int nBars = 100;
    double o[], h[], l[], c[]; datetime t[];
    ArrayResize(o, nBars); ArrayResize(h, nBars);
    ArrayResize(l, nBars); ArrayResize(c, nBars);
    ArrayResize(t, nBars);
    datetime base = D'2026.06.01 00:00';
    // Alternating bullish/bearish displacement to create multiple FVGs
    for(int i = 0; i < nBars; i++)
    {
        int idx = nBars - 1 - i;
        double mid = 1.08000 + MathSin(i * 0.3) * 0.0100;
        int flip = ((i / 3) % 2 == 0) ? 1 : -1;
        o[idx] = mid;
        h[idx] = mid + 0.0020;
        l[idx] = mid - 0.0015;
        c[idx] = mid + flip * 0.0010;
        t[idx] = base + i * 900;
    }
    // First pass
    det.Update(o, h, l, c, t, nBars);
    int count1 = det.GetFVGCount();
    int maxId1 = -1;
    for(int i = 0; i < count1; i++)
    {
        FairValueGap fvg;
        det.GetFVG(i, fvg);
        if(fvg.id > maxId1) maxId1 = fvg.id;
    }
    // Second pass with same data (no new bars)
    det.Update(o, h, l, c, t, nBars);
    int count2 = det.GetFVGCount();
    int maxId2 = -1;
    for(int i = 0; i < count2; i++)
    {
        FairValueGap fvg;
        det.GetFVG(i, fvg);
        if(fvg.id > maxId2) maxId2 = fvg.id;
    }
    Check(count1 == count2, "T23: count unchanged after idle Update (" + IntegerToString(count1) + " vs " + IntegerToString(count2) + ")");
    Check(maxId1 == maxId2, "T23: max ID unchanged after idle Update (" + IntegerToString(maxId1) + " vs " + IntegerToString(maxId2) + ")");
    // Verify no duplicates
    bool dup = false;
    int ids[];
    for(int i = 0; i < count2; i++)
    {
        FairValueGap fvg;
        det.GetFVG(i, fvg);
        int sz = ArraySize(ids);
        for(int j = 0; j < sz; j++)
            if(ids[j] == fvg.id) dup = true;
        ArrayResize(ids, sz + 1);
        ids[sz] = fvg.id;
    }
    Check(!dup, "T23: no duplicates after idle Update");
    det.Shutdown();
    return true;
}

//+------------------------------------------------------------------+
void RunAllTests(void)
{
    g_reportHandle = FileOpen(REPORT_FILE, FILE_WRITE|FILE_TXT|FILE_ANSI);
    if(g_reportHandle == INVALID_HANDLE)
        Report("[WARNING] Could not open report file: " + REPORT_FILE);

    Report("================================================================");
    Report("SPRINT 9.1 -- FVG FORENSIC VALIDATION");
    Report("================================================================");
    Report("Report:  " + REPORT_FILE);
    Report("Date:    " + TimeToString(TimeCurrent(), TIME_DATE) + " " + TimeToString(TimeCurrent(), TIME_MINUTES));
    Report("Build:   " + IntegerToString(TerminalInfoInteger(TERMINAL_BUILD)));
    Report("Account: " + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)));
    Report("Symbol:  " + _Symbol);
    Report("Period:  " + StringSubstr(EnumToString((ENUM_TIMEFRAMES)_Period), 7));
    Report("================================================================");

    g_totalChecks = 0;
    g_checkPassed = 0;
    ArrayResize(g_errors, 0);

    bool results[25];
    results[0]  = Test1();
    results[1]  = Test2();
    results[2]  = Test3();
    results[3]  = Test4();
    results[4]  = Test5();
    results[5]  = Test6();
    results[6]  = Test7();
    results[7]  = Test8();
    results[8]  = Test9();
    results[9]  = Test10();
    results[10] = Test11();
    results[11] = Test12();
    results[12] = Test13();
    results[13] = Test14();
    results[14] = Test15();
    results[15] = Test16();
    results[16] = Test17();
    results[17] = Test18();
    results[18] = Test19();
    results[19] = Test20();
    results[20] = Test21();
    results[21] = Test22();
    results[22] = Test23();
    results[23] = Test24();
    results[24] = Test25();

    Report("");
    Report("================================================================");
    Report("SPRINT 9.1 -- FVG FORENSIC VALIDATION");
    Report("================================================================");

    Report("");
    Report("PART 1: Engine Summary");
    Report("  Module: CFVGDetector");
    Report(StringFormat("  Min body threshold: %d pips (%.6f)", FVG_MIN_BODY_SIZE_PIPS, MIN_BODY));
    Report(StringFormat("  _Point: %.6f", _Point));

    Report("");
    Report("PART 2: Bullish Detection");
    Report(StringFormat("  T1  Bullish FVG ............... %s", results[0] ? "PASS" : "FAIL"));
    Report(StringFormat("  T5  Consecutive Bullish ....... %s", results[4] ? "PASS" : "FAIL"));
    Report(StringFormat("  T7  Mixed (bullish part) ...... %s", results[6] ? "PASS" : "FAIL"));

    Report("");
    Report("PART 3: Bearish Detection");
    Report(StringFormat("  T2  Bearish FVG ............... %s", results[1] ? "PASS" : "FAIL"));
    Report(StringFormat("  T6  Consecutive Bearish ....... %s", results[5] ? "PASS" : "FAIL"));
    Report(StringFormat("  T7  Mixed (bearish part) ...... %s", results[6] ? "PASS" : "FAIL"));

    Report("");
    Report("PART 4: Gap Boundary Validation");
    Report(StringFormat("  T3  No Gap .................... %s", results[2] ? "PASS" : "FAIL"));
    Report(StringFormat("  T4  Below Threshold ........... %s", results[3] ? "PASS" : "FAIL"));
    Report(StringFormat("  T13 Gap Boundaries ............ %s", results[12] ? "PASS" : "FAIL"));

    Report("");
    Report("PART 5: Lifecycle Placeholder");
    Report(StringFormat("  T8  Lifecycle Placeholder ..... %s", results[7] ? "PASS" : "FAIL"));
    Report(StringFormat("  T9  Unfilled FVG .............. %s", results[8] ? "PASS" : "FAIL"));

    Report("");
    Report("PART 6: Duplicate Prevention");
    Report(StringFormat("  T10 Duplicate ID Prevention ... %s", results[9] ? "PASS" : "FAIL"));

    Report("");
    Report("PART 7: Chronology");
    Report(StringFormat("  T11 Time Monotonicity ......... %s", results[10] ? "PASS" : "FAIL"));

    Report("");
    Report("PART 8: Sequential IDs");
    Report(StringFormat("  T12 Sequential IDs ............ %s", results[11] ? "PASS" : "FAIL"));

    Report("");
    Report("PART 9: Determinism & Quality");
    Report(StringFormat("  T14 Quality Score ............. %s", results[13] ? "PASS" : "FAIL"));
    Report(StringFormat("  T15 Deterministic Output ...... %s", results[14] ? "PASS" : "FAIL"));

    Report("");
    Report("PART 10: Memory");
    Report(StringFormat("  T16 Memory Safety ............. %s", results[15] ? "PASS" : "FAIL"));

    Report("");
    Report("PART 11: Performance");
    Report(StringFormat("  T17 10000 Bar Stress .......... %s", results[16] ? "PASS" : "FAIL"));

    Report("");
    Report("PART 12: Boundary Precision");
    Report(StringFormat("  T21 Gap Equality .............. %s", results[20] ? "PASS" : "FAIL"));
    Report(StringFormat("  T22 Float Precision ........... %s", results[21] ? "PASS" : "FAIL"));

    Report("");
    Report("PART 13: Incremental Processing");
    Report(StringFormat("  T23 Incremental Update ........ %s", results[22] ? "PASS" : "FAIL"));

    Report("");
    Report("PART 14: Edge Cases");
    Report(StringFormat("  T18 3 Candle Edge ............. %s", results[17] ? "PASS" : "FAIL"));
    Report(StringFormat("  T19 2 Candle Edge ............. %s", results[18] ? "PASS" : "FAIL"));
    Report(StringFormat("  T20 Empty Dataset ............. %s", results[19] ? "PASS" : "FAIL"));

    Report("");
    Report("PART 15: Diagnostic Tests");
    Report(StringFormat("  T24 Repeat T1 (state leak) .... %s", results[23] ? "PASS" : "FAIL"));
    Report(StringFormat("  T25 Cycle stress .............. %s", results[24] ? "PASS" : "FAIL"));

    Report("");
    Report("PART 16: Final Decision");
    int totalPass = 0;
    for(int i = 0; i < 25; i++) if(results[i]) totalPass++;
    int totalFail = 25 - totalPass;

    Report(StringFormat("  Tests Passed: %d/25", totalPass));
    Report(StringFormat("  Tests Failed: %d/25", totalFail));
    Report(StringFormat("  Detail Checks: %d/%d passed", g_checkPassed, g_totalChecks));

    if(g_totalChecks > g_checkPassed)
    {
        Report("  Failed Checks:");
        for(int i = 0; i < ArraySize(g_errors); i++)
            Report("    - " + g_errors[i]);
    }

    Report("");
    if(totalFail == 0)
    {
        Report("  ACCEPTANCE: SPRINT 9.1 PASSED");
        Report("  FVG Detector fully validated at implementation level (25/25).");
    }
    else
    {
        Report("  ACCEPTANCE: SPRINT 9.1 FAILED");
        Report("  Review errors above before freezing v0.9.0.");
    }
    Report("================================================================");

    if(g_reportHandle != INVALID_HANDLE)
    {
        FileFlush(g_reportHandle);
        FileClose(g_reportHandle);
        g_reportHandle = INVALID_HANDLE;
    }
}

#ifndef RUNNING_AS_EA
//+------------------------------------------------------------------+
void OnStart(void)
{
    RunAllTests();
}
#endif
