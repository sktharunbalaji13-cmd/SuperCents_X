//+------------------------------------------------------------------+
//|                                     TestSwingRenderer.mqh         |
//|               Phase 2A - SwingRenderer FIFO rendered-bookkeeping  |
//|                                                                  |
//| Defect (Phase-1.5 live evidence, EURUSD M15, 25,646 swings):     |
//| CSwingRenderer::Update full-scanned the detector population      |
//| every bar and issued a guaranteed-miss StringFormat+ObjectFind   |
//| for EVERY outside-window swing (25,568 calls/bar steady state;   |
//| 0.70-1.31 s/bar on the live chart). The ObjectFind reconcile     |
//| never needed to exist: only the renderer's own ~78 in-window     |
//| draws can ever be deleted.                                       |
//|                                                                  |
//| Fix under test: the renderer keeps a drawn-id+time FIFO per      |
//| direction. Update draws only NEW in-window swings (binary-       |
//| search window start + index cursor, no population scan) and      |
//| head-deletes the FIFO while a drawn swing falls out of the time  |
//| window.                                                          |
//|                                                                  |
//| Fixture: a deterministic staircase series. Every 3rd bar is a    |
//| strict 5-bar fractal extremum (high 91 over flats 90 / low 87    |
//| under flats 88), alternating H/L; swing id == index+1. With      |
//| 20,448 steps the population matches the live Phase-1.5 scale     |
//| (10,224 highs + 10,224 lows). Fixture bar times are aligned to   |
//| the test chart so the render window (SwingRenderHistoryBars      |
//| bars back) cuts inside the fixture.                              |
//|                                                                  |
//| The head-delete path fires only when the chart window advances   |
//| (frozen in the tester), so it is verified live; tests A-F here   |
//| prove DRAW-path parity with the pre-fix renderer (identical      |
//| chart state, identical VSE command workload) plus FIFO           |
//| bookkeeping correctness, and D/G document the detector-reload    |
//| contract (reconciliation by what was DRAWN, never by id          |
//| collision with reloaded swings).                                 |
//|                                                                  |
//| Detector chain: real CSwingDetector + real CVisualStateEngine    |
//| on the test chart (TestRunnerEA).                                |
//+------------------------------------------------------------------+
#ifndef __TEST_SWING_RENDERER_MQH__
#define __TEST_SWING_RENDERER_MQH__

#include "../../Structure/SwingDetector.mqh"
#include "../../Visualization/SwingRenderer.mqh"
#include "../TestAssert.mqh"

#define SRT_FIXTURE_STEPS 20448

//+------------------------------------------------------------------+
//| Fixture: staircase series producing exactly 'steps' alternating  |
//| swing highs/lows (one 5-bar fractal per 3 bars, no overlaps).    |
//| Swing id = j+1; step j is HIGH (91.0) when j is even, LOW (87.0) |
//| when j is odd. Times are contiguous bars of PeriodSeconds(_Period)|
//| starting at 'base'.                                              |
//+------------------------------------------------------------------+
void SRTBuildSeries(int steps,
                    double &open[], double &high[], double &low[],
                    double &close[], datetime &time[], datetime base)
{
    int bars = 3 * steps + 5;
    int step = PeriodSeconds(_Period);
    ArrayResize(open, bars);
    ArrayResize(high, bars);
    ArrayResize(low, bars);
    ArrayResize(close, bars);
    ArrayResize(time, bars);

    for(int b = 0; b < bars; b++)
    {
        high[b]  = 90.0;
        low[b]   = 88.0;
        open[b]  = 89.0;
        close[b] = 89.0;
        time[b]  = base + b * step;
    }

    for(int j = 0; j < steps; j++)
    {
        int c = 4 + 3 * j;
        if((j & 1) == 0)
            high[c] = 91.0;   // swing high (id 2j+1)
        else
            low[c] = 87.0;    // swing low (id 2j+2)
    }
}

//+------------------------------------------------------------------+
//| Fresh detector chain + renderer + VSE, fully caught up (tick 1). |
//| The fixture tail is aligned to the chart's current bar so the    |
//| render window cuts inside the fixture.                           |
//+------------------------------------------------------------------+
void SRTSetup(TestCounters &counters, int steps,
              CSwingDetector &swing, CSwingRenderer &renderer, CVisualStateEngine &vse,
              double &open[], double &high[], double &low[],
              double &close[], datetime &time[], datetime &base)
{
    int bars = 3 * steps + 5;
    base = iTime(_Symbol, _Period, 0) - (bars - 1) * PeriodSeconds(_Period);
    SRTBuildSeries(steps, open, high, low, close, time, base);
    TEST_TRUE(swing.Init(), "SRT: swing init");
    TEST_TRUE(renderer.Init(), "SRT: renderer init");
    vse.Init();
    renderer.SetDetector(GetPointer(swing));
    renderer.SetVSE(GetPointer(vse));
    renderer.Clear();   // wipe any leftover SCX_SWING_ objects on the chart

    swing.Update(high, low, time, bars);
}

//+------------------------------------------------------------------+
//| Numeric extractor for the VSE PHASE_1_5 diagnostic line          |
//| ("VSE records=.. cmds=.. findCalls=.. findIter=.. objCreate=..   |
//|  objDelete=.."). Returns -1 when the key is absent.              |
//+------------------------------------------------------------------+
int SRTDiagValue(const string &diag, const string key)
{
    int pos = StringFind(diag, key);
    if(pos < 0)
        return -1;
    return (int)StringToInteger(StringSubstr(diag, pos + StringLen(key)));
}

//+------------------------------------------------------------------+
//| Render window start time, exactly as CSwingRenderer computes it. |
//+------------------------------------------------------------------+
datetime SRTRenderStartTime(void)
{
    int totalRates = Bars(_Symbol, _Period);
    int renderBars = MathMin(SwingRenderHistoryBars, MathMax(totalRates - 1, 0));
    return (totalRates > 1) ? iTime(_Symbol, _Period, renderBars) : 0;
}

//+------------------------------------------------------------------+
//| Expected in-window population: detector swings with time >=      |
//| renderStartTime, in detector order (mirrors the pre-fix draw     |
//| gate).                                                           |
//+------------------------------------------------------------------+
void SRTCollectWindow(bool isHigh, CSwingDetector &swing, datetime renderStartTime,
                      int &ids[], datetime &times[], int &count)
{
    count = 0;
    int n = isHigh ? swing.GetSwingHighCount() : swing.GetSwingLowCount();
    SwingPoint sp;
    for(int i = 0; i < n; i++)
    {
        bool ok = isHigh ? swing.GetSwingHigh(i, sp) : swing.GetSwingLow(i, sp);
        if(!ok || sp.time < renderStartTime)
            continue;
        ArrayResize(ids, count + 1);
        ArrayResize(times, count + 1);
        ids[count] = sp.id;
        times[count] = sp.time;
        count++;
    }
}

//+------------------------------------------------------------------+
//| FIFO equality: the renderer's drawn bookkeeping must equal the   |
//| detector's in-window source of truth, id AND time, in order.     |
//+------------------------------------------------------------------+
bool SRTFifoMatches(bool isHigh, CSwingRenderer &renderer,
                    int &ids[], datetime &times[], int count)
{
    int fifo = isHigh ? renderer.GetRenderedSwingHighCount() : renderer.GetRenderedSwingLowCount();
    if(fifo != count)
        return false;
    for(int i = 0; i < count; i++)
    {
        int id = isHigh ? renderer.GetDrawnHighId(i) : renderer.GetDrawnLowId(i);
        datetime t = isHigh ? renderer.GetDrawnHighTime(i) : renderer.GetDrawnLowTime(i);
        if(id != ids[i] || t != times[i])
            return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Real chart probe: count SCX_SWING_ objects on the test chart     |
//| (swings are OBJ_ARROW_DOWN / OBJ_ARROW_UP, so count by prefix).  |
//+------------------------------------------------------------------+
int SRTCountSwingObjects(void)
{
    int total = ObjectsTotal(0, 0, -1);
    int n = 0;
    for(int i = 0; i < total; i++)
    {
        string name = ObjectName(0, i, 0, -1);
        if(StringFind(name, "SCX_SWING_") == 0)
            n++;
    }
    return n;
}

//+------------------------------------------------------------------+
//| TEST A: catch-up on a 20,448-swing population draws exactly the  |
//| in-window population (NOT the full 10,224 per direction - the    |
//| pre-fix renderer never drew outside-window swings, so this test  |
//| pins the draw gate to the window and proves the FIFO equals the  |
//| detector's source of truth).                                     |
//+------------------------------------------------------------------+
void TestSwingRendererCatchUpWindow(TestCounters &counters)
{
    double open[], high[], low[], close[];
    datetime time[], base;
    CSwingDetector swing;
    CSwingRenderer renderer;
    CVisualStateEngine vse;

    SRTSetup(counters, SRT_FIXTURE_STEPS, swing, renderer, vse, open, high, low, close, time, base);
    TEST_INT_EQ(SRT_FIXTURE_STEPS / 2, swing.GetSwingHighCount(), "SRT-A: fixture pin - exactly 10224 highs");
    TEST_INT_EQ(SRT_FIXTURE_STEPS / 2, swing.GetSwingLowCount(), "SRT-A: fixture pin - exactly 10224 lows");

    renderer.Update();

    int idsH[];
    datetime timesH[];
    int idsL[];
    datetime timesL[];
    int expHigh, expLow;
    datetime boundary = SRTRenderStartTime();
    SRTCollectWindow(true, swing, boundary, idsH, timesH, expHigh);
    SRTCollectWindow(false, swing, boundary, idsL, timesL, expLow);
    int totalExp = expHigh + expLow;
    TEST_TRUE(totalExp > 0, "SRT-A: render window cuts inside the fixture");

    TEST_INT_EQ(expHigh, renderer.GetRenderedSwingHighCount(),
        "SRT-A: drawn highs == in-window highs (not 10224)");
    TEST_INT_EQ(expLow, renderer.GetRenderedSwingLowCount(),
        "SRT-A: drawn lows == in-window lows (not 10224)");
    TEST_TRUE(SRTFifoMatches(true, renderer, idsH, timesH, expHigh),
        "SRT-A: high FIFO == detector in-window source of truth");
    TEST_TRUE(SRTFifoMatches(false, renderer, idsL, timesL, expLow),
        "SRT-A: low FIFO == detector in-window source of truth");
    TEST_INT_EQ(SRT_FIXTURE_STEPS / 2, renderer.GetSwingHighDrawCursor(),
        "SRT-A: high draw cursor advanced to the full population");
    TEST_INT_EQ(SRT_FIXTURE_STEPS / 2, renderer.GetSwingLowDrawCursor(),
        "SRT-A: low draw cursor advanced to the full population");
    TEST_INT_EQ(totalExp, SRTCountSwingObjects(),
        "SRT-A: chart carries exactly the in-window objects");

    string diag = vse.GetDiagAndReset();
    TEST_INT_EQ(totalExp, SRTDiagValue(diag, "objCreate="),
        "SRT-A: VSE created exactly the in-window population");
    TEST_INT_EQ(0, SRTDiagValue(diag, "objDelete="),
        "SRT-A: VSE deleted ZERO objects on catch-up");
    TEST_INT_EQ(totalExp, SRTDiagValue(diag, "cmds="),
        "SRT-A: exactly one command per drawn swing");

    renderer.Clear();
    vse.Shutdown();
    renderer.Shutdown();
    swing.Shutdown();
}

//+------------------------------------------------------------------+
//| TEST B: steady-state update with no new swings issues ZERO       |
//| commands and leaves the rendered population untouched. (Pre-fix  |
//| RED: 25,568 guaranteed-miss StringFormat+ObjectFind calls per    |
//| steady update - invisible to the VSE counters, visible only in   |
//| the live per-bar timing; post-fix the steady update does zero    |
//| work.)                                                           |
//+------------------------------------------------------------------+
void TestSwingRendererSteadyZeroPhantomDeletes(TestCounters &counters)
{
    double open[], high[], low[], close[];
    datetime time[], base;
    CSwingDetector swing;
    CSwingRenderer renderer;
    CVisualStateEngine vse;

    SRTSetup(counters, SRT_FIXTURE_STEPS, swing, renderer, vse, open, high, low, close, time, base);
    renderer.Update();
    int h = renderer.GetRenderedSwingHighCount();
    int l = renderer.GetRenderedSwingLowCount();
    TEST_INT_EQ(h + l, SRTCountSwingObjects(), "SRT-B: baseline rendered");
    vse.GetDiagAndReset();   // clear baseline counters

    renderer.Update();       // steady update: detector unchanged

    TEST_INT_EQ(h, renderer.GetRenderedSwingHighCount(),
        "SRT-B: rendered highs unchanged");
    TEST_INT_EQ(l, renderer.GetRenderedSwingLowCount(),
        "SRT-B: rendered lows unchanged");
    TEST_INT_EQ(h + l, SRTCountSwingObjects(),
        "SRT-B: chart objects unchanged");
    TEST_INT_EQ(SRT_FIXTURE_STEPS / 2, swing.GetSwingHighCount(),
        "SRT-B: detector population untouched");

    string diag = vse.GetDiagAndReset();
    TEST_INT_EQ(0, SRTDiagValue(diag, "cmds="),
        "SRT-B: ZERO commands in steady state");
    TEST_INT_EQ(0, SRTDiagValue(diag, "objCreate="), "SRT-B: no creates in steady state");
    TEST_INT_EQ(0, SRTDiagValue(diag, "objDelete="), "SRT-B: no deletes in steady state");

    renderer.Clear();
    vse.Shutdown();
    renderer.Shutdown();
    swing.Shutdown();
}

//+------------------------------------------------------------------+
//| TEST C: one new swing arrives on a live chain - the renderer     |
//| draws exactly it (1 create, 0 deletes, FIFO +1).                 |
//+------------------------------------------------------------------+
void TestSwingRendererIncrementalDraw(TestCounters &counters)
{
    double open[], high[], low[], close[];
    datetime time[], base;
    CSwingDetector swing;
    CSwingRenderer renderer;
    CVisualStateEngine vse;

    SRTSetup(counters, SRT_FIXTURE_STEPS, swing, renderer, vse, open, high, low, close, time, base);
    renderer.Update();
    int h = renderer.GetRenderedSwingHighCount();
    int l = renderer.GetRenderedSwingLowCount();
    vse.GetDiagAndReset();   // clear baseline counters

    //--- one new step arrives (series rebuilt +3 bars; the detector
    //    chain stays live and incremental)
    SRTBuildSeries(SRT_FIXTURE_STEPS + 1, open, high, low, close, time, base);
    swing.Update(high, low, time, 3 * (SRT_FIXTURE_STEPS + 1) + 5);
    TEST_INT_EQ(SRT_FIXTURE_STEPS / 2 + 1, swing.GetSwingHighCount(),
        "SRT-C: fixture pin - 10225 highs after incremental feed");
    TEST_INT_EQ(SRT_FIXTURE_STEPS / 2, swing.GetSwingLowCount(),
        "SRT-C: fixture pin - 10224 lows after incremental feed");

    renderer.Update();

    TEST_INT_EQ(h + 1, renderer.GetRenderedSwingHighCount(),
        "SRT-C: exactly one new high drawn");
    TEST_INT_EQ(l, renderer.GetRenderedSwingLowCount(),
        "SRT-C: no new lows drawn");
    TEST_INT_EQ(h + l + 1, SRTCountSwingObjects(),
        "SRT-C: chart carries exactly one more object");

    string diag = vse.GetDiagAndReset();
    TEST_INT_EQ(1, SRTDiagValue(diag, "objCreate="), "SRT-C: exactly 1 create (the new swing)");
    TEST_INT_EQ(0, SRTDiagValue(diag, "objDelete="), "SRT-C: no deletes");
    TEST_INT_EQ(1, SRTDiagValue(diag, "cmds="), "SRT-C: exactly 1 command");

    renderer.Clear();
    vse.Shutdown();
    renderer.Shutdown();
    swing.Shutdown();
}

//+------------------------------------------------------------------+
//| TEST D: detector rebuild from IDENTICAL history (chart reload,   |
//| renderer untouched) - ZERO commands; the FIFO and chart state    |
//| are preserved.                                                   |
//+------------------------------------------------------------------+
void TestSwingRendererReloadIdenticalNoOp(TestCounters &counters)
{
    double open[], high[], low[], close[];
    datetime time[], base;
    CSwingDetector swing;
    CSwingRenderer renderer;
    CVisualStateEngine vse;

    SRTSetup(counters, SRT_FIXTURE_STEPS, swing, renderer, vse, open, high, low, close, time, base);
    renderer.Update();
    int h = renderer.GetRenderedSwingHighCount();
    int l = renderer.GetRenderedSwingLowCount();
    vse.GetDiagAndReset();

    //--- detector rebuild from the same history (same ids, same times)
    swing.Clear();
    swing.Update(high, low, time, 3 * SRT_FIXTURE_STEPS + 5);
    TEST_INT_EQ(SRT_FIXTURE_STEPS / 2, swing.GetSwingHighCount(), "SRT-D: fixture pin after reload");
    TEST_INT_EQ(SRT_FIXTURE_STEPS / 2, swing.GetSwingLowCount(), "SRT-D: fixture pin after reload");

    renderer.Update();

    TEST_INT_EQ(h, renderer.GetRenderedSwingHighCount(),
        "SRT-D: high FIFO unchanged after identical reload");
    TEST_INT_EQ(l, renderer.GetRenderedSwingLowCount(),
        "SRT-D: low FIFO unchanged after identical reload");
    TEST_INT_EQ(h + l, SRTCountSwingObjects(),
        "SRT-D: chart objects unchanged after identical reload");

    string diag = vse.GetDiagAndReset();
    TEST_INT_EQ(0, SRTDiagValue(diag, "cmds="),
        "SRT-D: ZERO commands after identical reload");
    TEST_INT_EQ(0, SRTDiagValue(diag, "objDelete="),
        "SRT-D: no deletes (identical data - nothing left the window)");

    renderer.Clear();
    vse.Shutdown();
    renderer.Shutdown();
    swing.Shutdown();
}

//+------------------------------------------------------------------+
//| TEST E: reset/deinit/reinit drops the draw cursors AND the drawn-|
//| id+time bookkeeping; the rebuilt render never reuses stale state.|
//+------------------------------------------------------------------+
void TestSwingRendererResetReinit(TestCounters &counters)
{
    double open[], high[], low[], close[];
    datetime time[], base;
    CSwingDetector swing;
    CSwingRenderer renderer;
    CVisualStateEngine vse;

    SRTSetup(counters, SRT_FIXTURE_STEPS, swing, renderer, vse, open, high, low, close, time, base);
    renderer.Update();
    vse.GetDiagAndReset();

    //--- canonical clear (what the manager fires on a history reset)
    renderer.Clear();
    TEST_INT_EQ(0, renderer.GetRenderedSwingHighCount(), "SRT-E: Clear drops high bookkeeping");
    TEST_INT_EQ(0, renderer.GetRenderedSwingLowCount(), "SRT-E: Clear drops low bookkeeping");
    TEST_INT_EQ(0, renderer.GetSwingHighDrawCursor(), "SRT-E: Clear drops the high draw cursor");
    TEST_INT_EQ(0, renderer.GetSwingLowDrawCursor(), "SRT-E: Clear drops the low draw cursor");
    TEST_INT_EQ(0, SRTCountSwingObjects(), "SRT-E: Clear removed every chart object");

    //--- rebuild from the same population: full window redraw, no stale state
    renderer.Update();
    int idsH[];
    datetime timesH[];
    int idsL[];
    datetime timesL[];
    int expHigh, expLow;
    datetime boundary = SRTRenderStartTime();
    SRTCollectWindow(true, swing, boundary, idsH, timesH, expHigh);
    SRTCollectWindow(false, swing, boundary, idsL, timesL, expLow);
    TEST_INT_EQ(expHigh, renderer.GetRenderedSwingHighCount(),
        "SRT-E: re-render after clear = in-window highs again");
    TEST_INT_EQ(expLow, renderer.GetRenderedSwingLowCount(),
        "SRT-E: re-render after clear = in-window lows again");
    TEST_INT_EQ(expHigh + expLow, SRTCountSwingObjects(),
        "SRT-E: chart carries the full window after re-render");

    string diag = vse.GetDiagAndReset();
    TEST_INT_EQ(expHigh + expLow, SRTDiagValue(diag, "objCreate="),
        "SRT-E: re-render created exactly the in-window population");
    TEST_INT_EQ(0, SRTDiagValue(diag, "objDelete="), "SRT-E: re-render deleted nothing");

    //--- shutdown + init cycle
    renderer.Shutdown();
    TEST_INT_EQ(0, renderer.GetRenderedSwingHighCount(), "SRT-E: Shutdown drops high bookkeeping");
    TEST_INT_EQ(0, renderer.GetRenderedSwingLowCount(), "SRT-E: Shutdown drops low bookkeeping");
    TEST_INT_EQ(0, SRTCountSwingObjects(), "SRT-E: Shutdown removed every chart object");
    TEST_TRUE(renderer.Init(), "SRT-E: re-init succeeds");
    renderer.Update();
    TEST_INT_EQ(expHigh, renderer.GetRenderedSwingHighCount(),
        "SRT-E: post-reinit render = in-window highs again");
    TEST_INT_EQ(expLow, renderer.GetRenderedSwingLowCount(),
        "SRT-E: post-reinit render = in-window lows again");
    TEST_TRUE(SRTFifoMatches(true, renderer, idsH, timesH, expHigh),
        "SRT-E: post-reinit high FIFO == source of truth");
    TEST_TRUE(SRTFifoMatches(false, renderer, idsL, timesL, expLow),
        "SRT-E: post-reinit low FIFO == source of truth");

    renderer.Clear();
    vse.Shutdown();
    renderer.Shutdown();
    swing.Shutdown();
}

//+------------------------------------------------------------------+
//| TEST F: visual identity - every chart object carries the exact   |
//| id, price (91.0 + 50*_Point for highs, 87.0 - 50*_Point for      |
//| lows) and time of its source swing; nothing else is on the chart.|
//+------------------------------------------------------------------+
void TestSwingRendererVisualIdentity(TestCounters &counters)
{
    double open[], high[], low[], close[];
    datetime time[], base;
    CSwingDetector swing;
    CSwingRenderer renderer;
    CVisualStateEngine vse;

    SRTSetup(counters, SRT_FIXTURE_STEPS, swing, renderer, vse, open, high, low, close, time, base);
    renderer.Update();

    bool idOk = true;
    for(int i = 0; i < renderer.GetRenderedSwingHighCount(); i++)
    {
        int id = renderer.GetDrawnHighId(i);
        datetime t = renderer.GetDrawnHighTime(i);
        string name = SwingHighName(id);
        if(ObjectFind(0, name) < 0)
        {
            idOk = false;
            break;
        }
        double expPrice = 91.0 + SWING_ARROW_OFFSET_POINTS * _Point;
        if(MathAbs(ObjectGetDouble(0, name, OBJPROP_PRICE) - expPrice) > 1e-9)
        {
            idOk = false;
            break;
        }
        if((datetime)ObjectGetInteger(0, name, OBJPROP_TIME) != t)
        {
            idOk = false;
            break;
        }
    }
    for(int i = 0; i < renderer.GetRenderedSwingLowCount(); i++)
    {
        int id = renderer.GetDrawnLowId(i);
        datetime t = renderer.GetDrawnLowTime(i);
        string name = SwingLowName(id);
        if(ObjectFind(0, name) < 0)
        {
            idOk = false;
            break;
        }
        double expPrice = 87.0 - SWING_ARROW_OFFSET_POINTS * _Point;
        if(MathAbs(ObjectGetDouble(0, name, OBJPROP_PRICE) - expPrice) > 1e-9)
        {
            idOk = false;
            break;
        }
        if((datetime)ObjectGetInteger(0, name, OBJPROP_TIME) != t)
        {
            idOk = false;
            break;
        }
    }
    TEST_TRUE(idOk, "SRT-F: every chart object carries exact id/price/time identity");

    TEST_INT_EQ(renderer.GetRenderedSwingHighCount() + renderer.GetRenderedSwingLowCount(),
        SRTCountSwingObjects(), "SRT-F: no stale or extra swing objects on the chart");

    renderer.Clear();
    vse.Shutdown();
    renderer.Shutdown();
    swing.Shutdown();
}

//+------------------------------------------------------------------+
//| TEST G: detector rebuild from SHIFTED (older) history - the      |
//| window contract reconciles by what was DRAWN (time), never by id |
//| collision with the reloaded swings: every drawn object's own     |
//| time is still in-window, so ZERO commands and the chart state is |
//| preserved. (Pre-fix RED: the ObjectFind scan deleted 50 in-window|
//| drawn objects whose ids collided with shifted out-of-window      |
//| swings.)                                                         |
//+------------------------------------------------------------------+
void TestSwingRendererReloadShiftedContract(TestCounters &counters)
{
    double open[], high[], low[], close[];
    datetime time[], base;
    CSwingDetector swing;
    CSwingRenderer renderer;
    CVisualStateEngine vse;

    SRTSetup(counters, SRT_FIXTURE_STEPS, swing, renderer, vse, open, high, low, close, time, base);
    renderer.Update();
    int h = renderer.GetRenderedSwingHighCount();
    int l = renderer.GetRenderedSwingLowCount();
    TEST_TRUE(h + l > 0, "SRT-G: baseline drawn");
    vse.GetDiagAndReset();

    //--- detector rebuild from a history shifted 150 bars older
    //    (same ids, different times - the reloaded swings carry the
    //    same id range as the drawn ones)
    SRTBuildSeries(SRT_FIXTURE_STEPS, open, high, low, close, time,
                   base - 150 * PeriodSeconds(_Period));
    swing.Clear();
    swing.Update(high, low, time, 3 * SRT_FIXTURE_STEPS + 5);
    TEST_INT_EQ(SRT_FIXTURE_STEPS / 2, swing.GetSwingHighCount(), "SRT-G: fixture pin after shifted reload");
    TEST_INT_EQ(SRT_FIXTURE_STEPS / 2, swing.GetSwingLowCount(), "SRT-G: fixture pin after shifted reload");

    renderer.Update();

    TEST_INT_EQ(h, renderer.GetRenderedSwingHighCount(),
        "SRT-G: high FIFO preserved (time-based window contract)");
    TEST_INT_EQ(l, renderer.GetRenderedSwingLowCount(),
        "SRT-G: low FIFO preserved (time-based window contract)");
    TEST_INT_EQ(h + l, SRTCountSwingObjects(),
        "SRT-G: chart objects preserved (time-based window contract)");

    string diag = vse.GetDiagAndReset();
    TEST_INT_EQ(0, SRTDiagValue(diag, "cmds="),
        "SRT-G: ZERO commands after shifted reload");
    TEST_INT_EQ(0, SRTDiagValue(diag, "objDelete="),
        "SRT-G: no id-collision deletes (pre-fix RED: 50)");

    renderer.Clear();
    vse.Shutdown();
    renderer.Shutdown();
    swing.Shutdown();
}

//+------------------------------------------------------------------+
//| Suite entry.                                                     |
//+------------------------------------------------------------------+
TestCounters RunSwingRendererTests(void)
{
    SUITE_BEGIN("SwingRenderer (Phase 2A: FIFO rendered-bookkeeping fix)");
    TestCounters counters;

    TestSwingRendererCatchUpWindow(counters);             // A
    TestSwingRendererSteadyZeroPhantomDeletes(counters);  // B
    TestSwingRendererIncrementalDraw(counters);           // C
    TestSwingRendererReloadIdenticalNoOp(counters);       // D
    TestSwingRendererResetReinit(counters);               // E
    TestSwingRendererVisualIdentity(counters);            // F
    TestSwingRendererReloadShiftedContract(counters);     // G

    SUITE_END("SwingRenderer (Phase 2A)");
    return counters;
}

#endif // __TEST_SWING_RENDERER_MQH__