//+------------------------------------------------------------------+
//|                                      TestReconstruction.mqh       |
//|                    Sprint 20 - LC03: deterministic reconstruction |
//|                                                                  |
//| Scope (user decision, 2026-08-07):                              |
//|   PRIMARY:  after a canonical LC02 reset (CHistoryEpoch SHRINK   |
//|     or TIME_RESET broadcast), rebuilding the detector chain from |
//|     the current history reproduces the exact state of a fresh    |
//|     full scan over that same history, at all 9 detector layers   |
//|     (swing, pivot, BOS, trend, protected point, CHOCH, order     |
//|     block, FVG, liquidity).                                      |
//|   SECONDARY: incremental extension is deterministic within its   |
//|     own operating model (identical input sequence -> identical   |
//|     output state). Incremental replay is NOT required to equal   |
//|     a fresh full scan.                                           |
//|                                                                  |
//| Known order-dependence (ledger E11, NOT lifecycle defects; the   |
//| primary criterion does not depend on them):                      |
//|   - BOS:     full scan emits crossings oldest-first; incremental |
//|              discovery follows pivot-lock order (ids/trend can    |
//|              diverge for >= 2 opposite BOS).                     |
//|   - Swing:   the center cursor re-evaluates the chronological    |
//|              bar rates_total-3 on every grow, so one bar can be  |
//|              scanned at multiple centers under incremental feed. |
//|   - FVG:     delta scan is front-anchored on time[0]; the full   |
//|              scan is back-anchored, so id assignment order       |
//|              differs.                                            |
//|                                                                  |
//| Fixture: 24 hourly bars (B0 oldest .. B23 newest), DD02-derived  |
//| with opens and a 3-bar crash tail. Full-scan expectation (pins   |
//| the fixture) AFTER the C4 closed-bar fixes: 4 swings (2H/2L),    |
//| 4 pivots, 1 BOS (bearish @B13), BULLISH trend, 1 protected low   |
//| (8.00 @B6), 0 CHOCH, 0 order blocks, 3 FVGs and 1 external       |
//| liquidity level (10.00).                                         |
//+------------------------------------------------------------------+
#ifndef __TEST_RECONSTRUCTION_MQH__
#define __TEST_RECONSTRUCTION_MQH__

#include "../../Core/HistoryEpoch.mqh"
#include "../../Structure/SwingDetector.mqh"
#include "../../Structure/StructuralPivotEngine.mqh"
#include "../../Structure/BOSDetector.mqh"
#include "../../Structure/TrendState.mqh"
#include "../../Structure/ProtectedPointManager.mqh"
#include "../../Structure/CHOCHDetector.mqh"
#include "../../Structure/OrderBlockDetector.mqh"
#include "../../Structure/FVGDetector.mqh"
#include "../../Structure/LiquidityDetector.mqh"
#include "../TestAssert.mqh"

#define REC_BARS 24

//--- Chain view over one detector stack (production dependency order:
//--- swing -> pivot -> BOS -> trend -> PP -> CHOCH -> OB -> FVG -> liquidity)
struct CRecChain
{
    CSwingDetector          *swing;
    CStructuralPivotEngine  *pivot;
    CBOSDetector            *bos;
    CTrendState             *trend;
    CProtectedPointManager  *pp;
    CCHOCHDetector          *choch;
    COrderBlockDetector     *ob;
    CFVGDetector            *fvg;
    CLiquidityDetector      *liq;
};

//+------------------------------------------------------------------+
//| Fixture: 24 hourly bars. shiftHours shifts every bar time        |
//| (TIME_RESET scenario). bars selects a prefix B0..B(bars-1).      |
//+------------------------------------------------------------------+
void RECBuildSeries(int shiftHours, int bars,
                    double &open[], double &high[], double &low[],
                    double &close[], datetime &time[])
{
    // Chronological B0 (oldest) .. B23 (newest); array idx = bars-1-k.
    // DD02-derived body (B0..B20) + crash tail (B21..B23):
    //   B21 high (9.58) < B19 low (9.60) -> bearish FVG @B20
    //   B21/B22 close below the protected low 8.00 -> CHOCH at bar 1
    double o[REC_BARS] = {9.40, 9.55, 9.80, 9.60, 9.35, 9.25, 8.90, 8.20, 8.60, 9.10, 9.50, 9.60, 9.30, 9.00, 8.00, 8.10, 7.70, 8.60, 10.05, 10.00, 10.00, 9.55, 7.60, 7.55};
    double h[REC_BARS] = {9.50, 9.70, 9.90, 9.60, 9.40, 9.30, 9.00, 8.60, 9.20, 9.60, 10.00, 9.70, 9.40, 9.10, 8.60, 8.30, 8.60, 10.20, 10.10, 10.05, 10.00, 9.58, 7.62, 7.58};
    double l[REC_BARS] = {9.30, 9.45, 9.55, 9.40, 9.20, 8.60, 8.00, 8.20, 8.50, 8.80, 9.20, 9.00, 8.70, 8.30, 8.00, 7.50, 7.90, 8.90, 9.70, 9.60, 9.55, 7.40, 7.50, 7.45};
    double c[REC_BARS] = {9.45, 9.65, 10.20, 9.50, 9.30, 8.70, 8.10, 8.50, 9.00, 9.40, 9.80, 9.30, 8.90, 7.90, 8.20, 7.60, 8.30, 10.10, 9.90, 10.02, 9.95, 7.60, 7.55, 7.50};

    ArrayResize(open, bars);
    ArrayResize(high, bars);
    ArrayResize(low, bars);
    ArrayResize(close, bars);
    ArrayResize(time, bars);
    ArraySetAsSeries(open, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(time, true);

    datetime base = D'2026.01.01 00:00';
    for(int k = 0; k < bars; k++)
    {
        int idx = bars - 1 - k;
        open[idx]  = o[k];
        high[idx]  = h[k];
        low[idx]   = l[k];
        close[idx] = c[k];
        time[idx]  = base + k * 3600 + shiftHours * 3600;
    }
}

//+------------------------------------------------------------------+
//| Drive the full production chain (no epoch call).                 |
//+------------------------------------------------------------------+
void RECDriveChain(CRecChain &c,
                   const double &open[], const double &high[],
                   const double &low[], const double &close[],
                   const datetime &time[], int rates)
{
    c.swing.Update(high, low, time, rates);
    c.pivot.Update(c.swing);
    c.bos.Update(c.pivot, close, time, rates);
    c.trend.Update(c.bos);

    //--- PP activation seam (production semantics): the "current bar
    //--- time" is the last CLOSED bar (time[1]).
    datetime actTime[1];
    actTime[0] = (rates >= 2) ? time[1] : time[0];
    c.pp.Update(c.pivot, c.bos, c.trend, actTime);

    c.choch.Update(c.trend, c.pp, close, time, rates, _Point);
    c.ob.Update(c.choch, c.trend, c.pp, open, high, low, close, time, rates);
    c.fvg.Update(open, high, low, close, time, rates, c.trend);
    c.liq.Update(high, low, close, time, rates);
}

//+------------------------------------------------------------------+
//| Production tick: epoch detection + broadcast FIRST, then drive.  |
//+------------------------------------------------------------------+
void RECEpochTick(CRecChain &c, CHistoryEpoch &epoch,
                  const double &open[], const double &high[],
                  const double &low[], const double &close[],
                  const datetime &time[], int rates)
{
    epoch.Update(rates, time[0]);
    RECDriveChain(c, open, high, low, close, time, rates);
}

//+------------------------------------------------------------------+
//| Build a chain: point the view at the detector objects, init all  |
//| detectors in production order and register them with the epoch.  |
//+------------------------------------------------------------------+
void RECInitChain(CRecChain &c, CHistoryEpoch &epoch,
                  CSwingDetector &swing, CStructuralPivotEngine &pivot,
                  CBOSDetector &bos, CTrendState &trend,
                  CProtectedPointManager &pp, CCHOCHDetector &choch,
                  COrderBlockDetector &ob, CFVGDetector &fvg,
                  CLiquidityDetector &liq, TestCounters &counters)
{
    c.swing = GetPointer(swing);
    c.pivot = GetPointer(pivot);
    c.bos   = GetPointer(bos);
    c.trend = GetPointer(trend);
    c.pp    = GetPointer(pp);
    c.choch = GetPointer(choch);
    c.ob    = GetPointer(ob);
    c.fvg   = GetPointer(fvg);
    c.liq   = GetPointer(liq);

    TEST_TRUE(swing.Init(), "SwingDetector init (reconstruction)");
    TEST_TRUE(pivot.Init(), "PivotEngine init (reconstruction)");
    TEST_TRUE(bos.Init(), "BOSDetector init (reconstruction)");
    TEST_TRUE(trend.Init(), "TrendState init (reconstruction)");
    TEST_TRUE(pp.Init(), "ProtectedPointManager init (reconstruction)");
    TEST_TRUE(choch.Init(), "CHOCHDetector init (reconstruction)");
    TEST_TRUE(ob.Init(), "OrderBlockDetector init (reconstruction)");
    TEST_TRUE(fvg.Init(), "FVGDetector init (reconstruction)");
    TEST_TRUE(liq.Init(), "LiquidityDetector init (reconstruction)");

    fvg.SetBOSDetector(GetPointer(bos));
    fvg.SetCHOCHDetector(GetPointer(choch));
    liq.SetSwingDetector(GetPointer(swing));
    liq.SetBOSDetector(GetPointer(bos));

    epoch.AddConsumer(c.swing);
    epoch.AddConsumer(c.pivot);
    epoch.AddConsumer(c.bos);
    epoch.AddConsumer(c.trend);
    epoch.AddConsumer(c.pp);
    epoch.AddConsumer(c.choch);
    epoch.AddConsumer(c.ob);
    epoch.AddConsumer(c.fvg);
    epoch.AddConsumer(c.liq);
}

//+------------------------------------------------------------------+
//| Layer comparators: rebuild state vs fresh-scan state.            |
//+------------------------------------------------------------------+
void RECCompareSwingLayer(CRecChain &a, CRecChain &b, string tag, TestCounters &counters)
{
    TEST_INT_EQ(a.swing.GetSwingHighCount(), b.swing.GetSwingHighCount(), tag + ": swing high count");
    TEST_INT_EQ(a.swing.GetSwingLowCount(),  b.swing.GetSwingLowCount(),  tag + ": swing low count");
    int n = MathMin(a.swing.GetSwingHighCount(), b.swing.GetSwingHighCount());
    for(int i = 0; i < n; i++)
    {
        SwingPoint sa, sb;
        a.swing.GetSwingHigh(i, sa);
        b.swing.GetSwingHigh(i, sb);
        string t = StringFormat("%s: swing high[%d]", tag, i);
        TEST_INT_EQ(sa.id, sb.id, t + " id");
        TEST_DATETIME_EQ(sa.time, sb.time, t + " time");
        TEST_DBL_NEAR(sa.price, sb.price, 1e-9, t + " price");
        TEST_INT_EQ(sa.barIndex, sb.barIndex, t + " barIndex");
        TEST_TRUE(sa.isHigh == sb.isHigh, t + " isHigh");
    }
    n = MathMin(a.swing.GetSwingLowCount(), b.swing.GetSwingLowCount());
    for(int i = 0; i < n; i++)
    {
        SwingPoint sa, sb;
        a.swing.GetSwingLow(i, sa);
        b.swing.GetSwingLow(i, sb);
        string t = StringFormat("%s: swing low[%d]", tag, i);
        TEST_INT_EQ(sa.id, sb.id, t + " id");
        TEST_DATETIME_EQ(sa.time, sb.time, t + " time");
        TEST_DBL_NEAR(sa.price, sb.price, 1e-9, t + " price");
        TEST_INT_EQ(sa.barIndex, sb.barIndex, t + " barIndex");
        TEST_TRUE(sa.isHigh == sb.isHigh, t + " isHigh");
    }
}

void RECComparePivotLayer(CRecChain &a, CRecChain &b, string tag, TestCounters &counters)
{
    TEST_INT_EQ(a.pivot.GetPivotCount(), b.pivot.GetPivotCount(), tag + ": pivot count");
    int n = MathMin(a.pivot.GetPivotCount(), b.pivot.GetPivotCount());
    for(int i = 0; i < n; i++)
    {
        StructuralPivot pa, pb;
        a.pivot.GetPivot(i, pa);
        b.pivot.GetPivot(i, pb);
        string t = StringFormat("%s: pivot[%d]", tag, i);
        TEST_INT_EQ(pa.id, pb.id, t + " id");
        TEST_INT_EQ(pa.swingID, pb.swingID, t + " swingID");
        TEST_DATETIME_EQ(pa.time, pb.time, t + " time");
        TEST_DBL_NEAR(pa.price, pb.price, 1e-9, t + " price");
        TEST_INT_EQ(pa.barIndex, pb.barIndex, t + " barIndex");
        TEST_TRUE(pa.isHigh == pb.isHigh, t + " isHigh");
        TEST_TRUE(pa.isProtected == pb.isProtected, t + " isProtected");
        TEST_TRUE(pa.isBroken == pb.isBroken, t + " isBroken");
    }
}

void RECCompareBOSLayer(CRecChain &a, CRecChain &b, string tag, TestCounters &counters)
{
    TEST_INT_EQ(a.bos.GetBOSCount(), b.bos.GetBOSCount(), tag + ": BOS count");
    int n = MathMin(a.bos.GetBOSCount(), b.bos.GetBOSCount());
    for(int i = 0; i < n; i++)
    {
        BOSEvent ba, bb;
        a.bos.GetBOS(i, ba);
        b.bos.GetBOS(i, bb);
        string t = StringFormat("%s: BOS[%d]", tag, i);
        TEST_INT_EQ(ba.id, bb.id, t + " id");
        TEST_INT_EQ(ba.brokenPivotID, bb.brokenPivotID, t + " brokenPivotID");
        TEST_TRUE(ba.bullish == bb.bullish, t + " bullish");
        TEST_DATETIME_EQ(ba.breakTime, bb.breakTime, t + " breakTime");
        TEST_INT_EQ(ba.breakBar, bb.breakBar, t + " breakBar");
        TEST_DBL_NEAR(ba.pivotPrice, bb.pivotPrice, 1e-9, t + " pivotPrice");
        TEST_DBL_NEAR(ba.closePrice, bb.closePrice, 1e-9, t + " closePrice");
    }
}

void RECCompareTrendLayer(CRecChain &a, CRecChain &b, string tag, TestCounters &counters)
{
    TEST_INT_EQ((int)a.trend.GetCurrentTrend(), (int)b.trend.GetCurrentTrend(), tag + ": trend");
    TEST_INT_EQ(a.trend.GetBullishBOSCount(), b.trend.GetBullishBOSCount(), tag + ": bullish BOS count");
    TEST_INT_EQ(a.trend.GetBearishBOSCount(), b.trend.GetBearishBOSCount(), tag + ": bearish BOS count");
}

void RECComparePPLayer(CRecChain &a, CRecChain &b, string tag, TestCounters &counters)
{
    TEST_INT_EQ(a.pp.GetProtectedPointCount(), b.pp.GetProtectedPointCount(), tag + ": PP count");
    int n = MathMin(a.pp.GetProtectedPointCount(), b.pp.GetProtectedPointCount());
    for(int i = 0; i < n; i++)
    {
        ProtectedPoint pa, pb;
        a.pp.GetProtectedPoint(i, pa);
        b.pp.GetProtectedPoint(i, pb);
        string t = StringFormat("%s: PP[%d]", tag, i);
        TEST_INT_EQ(pa.id, pb.id, t + " id");
        TEST_INT_EQ(pa.pivotID, pb.pivotID, t + " pivotID");
        TEST_TRUE(pa.isHigh == pb.isHigh, t + " isHigh");
        TEST_DATETIME_EQ(pa.time, pb.time, t + " time");
        TEST_DBL_NEAR(pa.price, pb.price, 1e-9, t + " price");
        TEST_INT_EQ(pa.barIndex, pb.barIndex, t + " barIndex");
        TEST_TRUE(pa.active == pb.active, t + " active");
        TEST_DATETIME_EQ(pa.activationTime, pb.activationTime, t + " activationTime");
    }
    ProtectedPoint ha, hb, la, lb;
    bool hasHa = a.pp.GetActiveHigh(ha);
    bool hasHb = b.pp.GetActiveHigh(hb);
    TEST_TRUE(hasHa == hasHb, tag + ": active high presence");
    if(hasHa && hasHb)
        TEST_INT_EQ(ha.id, hb.id, tag + ": active high id");
    bool hasLa = a.pp.GetActiveLow(la);
    bool hasLb = b.pp.GetActiveLow(lb);
    TEST_TRUE(hasLa == hasLb, tag + ": active low presence");
    if(hasLa && hasLb)
        TEST_INT_EQ(la.id, lb.id, tag + ": active low id");
}

void RECCompareCHOCHLayer(CRecChain &a, CRecChain &b, string tag, TestCounters &counters)
{
    TEST_INT_EQ(a.choch.GetCHOCHCount(), b.choch.GetCHOCHCount(), tag + ": CHOCH count");
    int n = MathMin(a.choch.GetCHOCHCount(), b.choch.GetCHOCHCount());
    for(int i = 0; i < n; i++)
    {
        CHOCHEvent ca, cb;
        a.choch.GetCHOCH(i, ca);
        b.choch.GetCHOCH(i, cb);
        string t = StringFormat("%s: CHOCH[%d]", tag, i);
        TEST_INT_EQ(ca.id, cb.id, t + " id");
        TEST_INT_EQ(ca.protectedPointID, cb.protectedPointID, t + " protectedPointID");
        TEST_TRUE(ca.bullish == cb.bullish, t + " bullish");
        TEST_DATETIME_EQ(ca.time, cb.time, t + " time");
        TEST_DBL_NEAR(ca.breakPrice, cb.breakPrice, 1e-9, t + " breakPrice");
        TEST_INT_EQ(ca.barIndex, cb.barIndex, t + " barIndex");
    }
}

void RECCompareOBLayer(CRecChain &a, CRecChain &b, string tag, TestCounters &counters)
{
    TEST_INT_EQ(a.ob.GetOrderBlockCount(), b.ob.GetOrderBlockCount(), tag + ": OB count");
    int n = MathMin(a.ob.GetOrderBlockCount(), b.ob.GetOrderBlockCount());
    for(int i = 0; i < n; i++)
    {
        OrderBlock oa, ob;
        a.ob.GetOrderBlock(i, oa);
        b.ob.GetOrderBlock(i, ob);
        string t = StringFormat("%s: OB[%d]", tag, i);
        TEST_INT_EQ(oa.id, ob.id, t + " id");
        TEST_INT_EQ(oa.chochID, ob.chochID, t + " chochID");
        TEST_TRUE(oa.bullish == ob.bullish, t + " bullish");
        TEST_DATETIME_EQ(oa.time, ob.time, t + " time");
        TEST_DBL_NEAR(oa.open, ob.open, 1e-9, t + " open");
        TEST_DBL_NEAR(oa.high, ob.high, 1e-9, t + " high");
        TEST_DBL_NEAR(oa.low, ob.low, 1e-9, t + " low");
        TEST_DBL_NEAR(oa.close, ob.close, 1e-9, t + " close");
        TEST_INT_EQ(oa.candleIndex, ob.candleIndex, t + " candleIndex");
        TEST_TRUE(oa.mitigated == ob.mitigated, t + " mitigated");
        TEST_TRUE(oa.invalidated == ob.invalidated, t + " invalidated");
        TEST_DBL_NEAR(oa.qualityScore, ob.qualityScore, 1e-9, t + " qualityScore");
    }
}

void RECCompareFVGLayer(CRecChain &a, CRecChain &b, string tag, TestCounters &counters)
{
    TEST_INT_EQ(a.fvg.GetFVGCount(), b.fvg.GetFVGCount(), tag + ": FVG count");
    int n = MathMin(a.fvg.GetFVGCount(), b.fvg.GetFVGCount());
    for(int i = 0; i < n; i++)
    {
        FairValueGap fa, fb;
        a.fvg.GetFVG(i, fa);
        b.fvg.GetFVG(i, fb);
        string t = StringFormat("%s: FVG[%d]", tag, i);
        TEST_INT_EQ(fa.id, fb.id, t + " id");
        TEST_TRUE(fa.bullish == fb.bullish, t + " bullish");
        TEST_DATETIME_EQ(fa.time, fb.time, t + " time");
        TEST_INT_EQ(fa.candleIndex, fb.candleIndex, t + " candleIndex");
        TEST_DBL_NEAR(fa.upper, fb.upper, 1e-9, t + " upper");
        TEST_DBL_NEAR(fa.lower, fb.lower, 1e-9, t + " lower");
        TEST_TRUE(fa.filled == fb.filled, t + " filled");
        TEST_DATETIME_EQ(fa.fillTime, fb.fillTime, t + " fillTime");
        TEST_TRUE(fa.invalidated == fb.invalidated, t + " invalidated");
        TEST_INT_EQ(fa.chochId, fb.chochId, t + " chochId");
        TEST_DBL_NEAR(fa.qualityScore, fb.qualityScore, 1e-9, t + " qualityScore");
        TEST_INT_EQ(fa.fvgClass, fb.fvgClass, t + " fvgClass");
        TEST_INT_EQ(fa.classEventId, fb.classEventId, t + " classEventId");
        TEST_INT_EQ(fa.classEventType, fb.classEventType, t + " classEventType");
        TEST_DBL_NEAR(fa.gapSizePips, fb.gapSizePips, 1e-9, t + " gapSizePips");
        TEST_INT_EQ(fa.sizeCategory, fb.sizeCategory, t + " sizeCategory");
        TEST_INT_EQ(fa.strength, fb.strength, t + " strength");
        TEST_DBL_NEAR(fa.displacementBodyPips, fb.displacementBodyPips, 1e-9, t + " displacementBodyPips");
    }
}

void RECCompareLiquidityLayer(CRecChain &a, CRecChain &b, string tag, TestCounters &counters)
{
    TEST_INT_EQ(a.liq.GetLevelCount(), b.liq.GetLevelCount(), tag + ": liquidity level count");
    int n = MathMin(a.liq.GetLevelCount(), b.liq.GetLevelCount());
    for(int i = 0; i < n; i++)
    {
        LiquidityLevel la, lb;
        a.liq.GetLevel(i, la);
        b.liq.GetLevel(i, lb);
        string t = StringFormat("%s: liquidity[%d]", tag, i);
        TEST_INT_EQ(la.id, lb.id, t + " id");
        TEST_DATETIME_EQ(la.time, lb.time, t + " time");
        TEST_DBL_NEAR(la.price, lb.price, 1e-9, t + " price");
        TEST_DBL_NEAR(la.averagePrice, lb.averagePrice, 1e-9, t + " averagePrice");
        TEST_INT_EQ(la.memberCount, lb.memberCount, t + " memberCount");
        TEST_INT_EQ((int)la.type, (int)lb.type, t + " type");
        TEST_INT_EQ((int)la.classification, (int)lb.classification, t + " classification");
        TEST_INT_EQ((int)la.status, (int)lb.status, t + " status");
        TEST_INT_EQ((int)la.origin, (int)lb.origin, t + " origin");
        TEST_INT_EQ(la.leftSwingId, lb.leftSwingId, t + " leftSwingId");
        TEST_INT_EQ(la.rightSwingId, lb.rightSwingId, t + " rightSwingId");
        TEST_STR_EQ(la.memberIdStr, lb.memberIdStr, t + " memberIdStr");
        TEST_TRUE(la.swept == lb.swept, t + " swept");
        TEST_TRUE(la.mitigated == lb.mitigated, t + " mitigated");
        TEST_TRUE(la.invalidated == lb.invalidated, t + " invalidated");
        TEST_DATETIME_EQ(la.detectedTime, lb.detectedTime, t + " detectedTime");
        TEST_INT_EQ(la.detectedBar, lb.detectedBar, t + " detectedBar");
        TEST_DATETIME_EQ(la.sweptTime, lb.sweptTime, t + " sweptTime");
        TEST_INT_EQ(la.sweptBar, lb.sweptBar, t + " sweptBar");
        TEST_DATETIME_EQ(la.mitigatedTime, lb.mitigatedTime, t + " mitigatedTime");
        TEST_INT_EQ(la.mitigatedBar, lb.mitigatedBar, t + " mitigatedBar");
        TEST_DBL_NEAR(la.mitigatedPrice, lb.mitigatedPrice, 1e-9, t + " mitigatedPrice");
        TEST_DATETIME_EQ(la.invalidatedTime, lb.invalidatedTime, t + " invalidatedTime");
        TEST_INT_EQ(la.invalidatedBar, lb.invalidatedBar, t + " invalidatedBar");
        TEST_DBL_NEAR(la.invalidatedPrice, lb.invalidatedPrice, 1e-9, t + " invalidatedPrice");
        TEST_STR_EQ(la.invalidatedReason, lb.invalidatedReason, t + " invalidatedReason");
    }
}

void RECCompareAllLayers(CRecChain &a, CRecChain &b, string tag, TestCounters &counters)
{
    RECCompareSwingLayer(a, b, tag, counters);
    RECComparePivotLayer(a, b, tag, counters);
    RECCompareBOSLayer(a, b, tag, counters);
    RECCompareTrendLayer(a, b, tag, counters);
    RECComparePPLayer(a, b, tag, counters);
    RECCompareCHOCHLayer(a, b, tag, counters);
    RECCompareOBLayer(a, b, tag, counters);
    RECCompareFVGLayer(a, b, tag, counters);
    RECCompareLiquidityLayer(a, b, tag, counters);
}

//+------------------------------------------------------------------+
//| Fixture pin: a fresh full scan of the 24-bar series must fire    |
//| every one of the 9 layers with the expected counts.              |
//+------------------------------------------------------------------+
void TestREC_FixtureFiresAllLayers(TestCounters &counters)
{
    double open[], high[], low[], close[];
    datetime time[];
    RECBuildSeries(0, REC_BARS, open, high, low, close, time);

    CRecChain a;
    CSwingDetector swingA;
    CStructuralPivotEngine pivotA;
    CBOSDetector bosA;
    CTrendState trendA;
    CProtectedPointManager ppA;
    CCHOCHDetector chochA;
    COrderBlockDetector obA;
    CFVGDetector fvgA;
    CLiquidityDetector liqA;
    CHistoryEpoch epochA;
    RECInitChain(a, epochA, swingA, pivotA, bosA, trendA, ppA, chochA, obA, fvgA, liqA, counters);

    RECEpochTick(a, epochA, open, high, low, close, time, REC_BARS);

    TEST_INT_EQ(2, a.swing.GetSwingHighCount(), "fixture: swing high count (10.20/10.00/9.90) [C4: 2 of 3, newest-edge swing no longer read-ahead into the forming bar]");
    TEST_INT_EQ(2, a.swing.GetSwingLowCount(), "fixture: swing low count (7.50/8.00)");
    TEST_INT_EQ(4, a.pivot.GetPivotCount(), "fixture: pivot count [C4]");
    TEST_INT_EQ(1, a.bos.GetBOSCount(), "fixture: BOS count (bearish @B13) [C4: bullish @B17 removed]");
    TEST_INT_EQ((int)TREND_BULLISH, (int)a.trend.GetCurrentTrend(), "fixture: trend BULLISH");
    TEST_INT_EQ(1, a.pp.GetProtectedPointCount(), "fixture: protected point count (active low 8.00)");
    TEST_INT_EQ(0, a.choch.GetCHOCHCount(), "fixture: CHOCH count (none: the low-PP consuming BOS left no trend flip) [C4]");
    TEST_INT_EQ(0, a.ob.GetOrderBlockCount(), "fixture: order block count (none w/o bullish BOS anchor) [C4]");
    TEST_INT_EQ(3, a.fvg.GetFVGCount(), "fixture: FVG count (@B20/@B16/@B3)");
    TEST_INT_EQ(1, a.liq.GetLevelCount(), "fixture: liquidity level count [C4: 1 of 2 external levels still formed]");
}

//+------------------------------------------------------------------+
//| PRIMARY (SHRINK path): pre-reset feed of the full 24-bar series, |
//| then rates_total 24->23 (B0..B22) triggers HISTORY_EVENT_SHRINK  |
//| and the epoch broadcast; the rebuild scan of the 23-bar history  |
//| must equal a fresh full scan of the same 23-bar history at all   |
//| 9 layers.                                                        |
//+------------------------------------------------------------------+
void TestREC_ShrinkRebuildMatchesFreshScan(TestCounters &counters)
{
    double o24[], h24[], l24[], c24[];
    datetime t24[];
    RECBuildSeries(0, REC_BARS, o24, h24, l24, c24, t24);
    double o23[], h23[], l23[], c23[];
    datetime t23[];
    RECBuildSeries(0, REC_BARS - 1, o23, h23, l23, c23, t23);

    //--- Baseline: fresh chain over the 23-bar history only.
    CRecChain base;
    CSwingDetector swingB;
    CStructuralPivotEngine pivotB;
    CBOSDetector bosB;
    CTrendState trendB;
    CProtectedPointManager ppB;
    CCHOCHDetector chochB;
    COrderBlockDetector obB;
    CFVGDetector fvgB;
    CLiquidityDetector liqB;
    CHistoryEpoch epochB;
    RECInitChain(base, epochB, swingB, pivotB, bosB, trendB, ppB, chochB, obB, fvgB, liqB, counters);
    RECEpochTick(base, epochB, o23, h23, l23, c23, t23, REC_BARS - 1);

    //--- Rebuild path: 24-bar feed, then SHRINK broadcast, then the
    //--- rebuild scan of the 23-bar history.
    CRecChain rb;
    CSwingDetector swingR;
    CStructuralPivotEngine pivotR;
    CBOSDetector bosR;
    CTrendState trendR;
    CProtectedPointManager ppR;
    CCHOCHDetector chochR;
    COrderBlockDetector obR;
    CFVGDetector fvgR;
    CLiquidityDetector liqR;
    CHistoryEpoch epochR;
    RECInitChain(rb, epochR, swingR, pivotR, bosR, trendR, ppR, chochR, obR, fvgR, liqR, counters);

    RECEpochTick(rb, epochR, o24, h24, l24, c24, t24, REC_BARS);

    EHistoryEvent ev = epochR.Update(REC_BARS - 1, t23[0]);
    TEST_INT_EQ((int)ev, (int)HISTORY_EVENT_SHRINK, "SHRINK: 24->23 detected as SHRINK");
    TEST_INT_EQ(epochR.GetEpoch(), 1, "SHRINK: epoch bumped to 1");
    RECDriveChain(rb, o23, h23, l23, c23, t23, REC_BARS - 1);

    RECCompareAllLayers(base, rb, "SHRINK rebuild", counters);
}

//+------------------------------------------------------------------+
//| PRIMARY (TIME_RESET path): pre-reset feed of the 24-bar series   |
//| at base times, then the same 24 bars with all times shifted back |
//| 3h (newest bar time went backwards) triggers                     |
//| HISTORY_EVENT_TIME_RESET; the rebuild scan of the shifted        |
//| history must equal a fresh full scan of the shifted history at   |
//| all 9 layers.                                                    |
//+------------------------------------------------------------------+
void TestREC_TimeResetRebuildMatchesFreshScan(TestCounters &counters)
{
    double o1[], h1[], l1[], c1[];
    datetime t1[];
    RECBuildSeries(0, REC_BARS, o1, h1, l1, c1, t1);
    double o2[], h2[], l2[], c2[];
    datetime t2[];
    RECBuildSeries(-3, REC_BARS, o2, h2, l2, c2, t2);

    //--- Baseline: fresh chain over the shifted history.
    CRecChain base;
    CSwingDetector swingB;
    CStructuralPivotEngine pivotB;
    CBOSDetector bosB;
    CTrendState trendB;
    CProtectedPointManager ppB;
    CCHOCHDetector chochB;
    COrderBlockDetector obB;
    CFVGDetector fvgB;
    CLiquidityDetector liqB;
    CHistoryEpoch epochB;
    RECInitChain(base, epochB, swingB, pivotB, bosB, trendB, ppB, chochB, obB, fvgB, liqB, counters);
    RECEpochTick(base, epochB, o2, h2, l2, c2, t2, REC_BARS);

    //--- Rebuild path: base-time feed, then TIME_RESET broadcast,
    //--- then the rebuild scan of the shifted history.
    CRecChain rb;
    CSwingDetector swingR;
    CStructuralPivotEngine pivotR;
    CBOSDetector bosR;
    CTrendState trendR;
    CProtectedPointManager ppR;
    CCHOCHDetector chochR;
    COrderBlockDetector obR;
    CFVGDetector fvgR;
    CLiquidityDetector liqR;
    CHistoryEpoch epochR;
    RECInitChain(rb, epochR, swingR, pivotR, bosR, trendR, ppR, chochR, obR, fvgR, liqR, counters);

    RECEpochTick(rb, epochR, o1, h1, l1, c1, t1, REC_BARS);

    EHistoryEvent ev = epochR.Update(REC_BARS, t2[0]);
    TEST_INT_EQ((int)ev, (int)HISTORY_EVENT_TIME_RESET, "TIME_RESET: shifted newest bar detected as TIME_RESET");
    TEST_INT_EQ(epochR.GetEpoch(), 1, "TIME_RESET: epoch bumped to 1");
    RECDriveChain(rb, o2, h2, l2, c2, t2, REC_BARS);

    RECCompareAllLayers(base, rb, "TIME_RESET rebuild", counters);
}

//+------------------------------------------------------------------+
//| SECONDARY: incremental extension is deterministic within its own |
//| operating model. Two identical chains fed the identical sequence |
//| of prefix ticks (12/16/20/24 bars) must end in identical state   |
//| at all 9 layers. NOTE: incremental state is NOT required to      |
//| equal a fresh full scan (order-dependence, ledger E11).         |
//+------------------------------------------------------------------+
void TestREC_IncrementalExtensionDeterministic(TestCounters &counters)
{
    CRecChain a, b;
    CSwingDetector swingA, swingB;
    CStructuralPivotEngine pivotA, pivotB;
    CBOSDetector bosA, bosB;
    CTrendState trendA, trendB;
    CProtectedPointManager ppA, ppB;
    CCHOCHDetector chochA, chochB;
    COrderBlockDetector obA, obB;
    CFVGDetector fvgA, fvgB;
    CLiquidityDetector liqA, liqB;
    CHistoryEpoch epochA, epochB;
    RECInitChain(a, epochA, swingA, pivotA, bosA, trendA, ppA, chochA, obA, fvgA, liqA, counters);
    RECInitChain(b, epochB, swingB, pivotB, bosB, trendB, ppB, chochB, obB, fvgB, liqB, counters);

    int ticks[4] = {12, 16, 20, REC_BARS};
    for(int t = 0; t < 4; t++)
    {
        double open[], high[], low[], close[];
        datetime time[];
        RECBuildSeries(0, ticks[t], open, high, low, close, time);
        RECEpochTick(a, epochA, open, high, low, close, time, ticks[t]);
        RECEpochTick(b, epochB, open, high, low, close, time, ticks[t]);
    }

    RECCompareAllLayers(a, b, "incremental twin", counters);
}

//+------------------------------------------------------------------+
//| Suite entry (21st category).                                     |
//+------------------------------------------------------------------+
TestCounters RunReconstructionTests(void)
{
    TestCounters counters;
    SUITE_BEGIN("Reconstruction Tests");

    TestREC_FixtureFiresAllLayers(counters);
    TestREC_ShrinkRebuildMatchesFreshScan(counters);
    TestREC_TimeResetRebuildMatchesFreshScan(counters);
    TestREC_IncrementalExtensionDeterministic(counters);

    SUITE_END("Reconstruction Tests");
    return counters;
}

#endif // __TEST_RECONSTRUCTION_MQH__
