//+------------------------------------------------------------------+
//|                                     TestPivotRenderer.mqh         |
//|               Phase 2A - PivotRenderer FIFO rendered-bookkeeping  |
//|                                                                  |
//| Defect (Phase-1.5 live evidence, EURUSD M15, 20,448 pivots):     |
//| CPivotRenderer::Update drew the ENTIRE detector population on    |
//| catch-up (20,448 CMD_DRAW) and then ran its FIFO on the          |
//| detector COUNT (while(count > MaxHistoricalPivots)), issuing     |
//| 20,398 CMD_DELETE every update - including steady state, where   |
//| the deletes were pure waste (the objects had already been        |
//| removed on the previous update). The FIFO never tracked what     |
//| the renderer actually drew.                                      |
//|                                                                  |
//| Fix under test: the renderer keeps a drawn-id bookkeeping array  |
//| (m_drawnPivotIds). Catch-up draws only the newest                |
//| MaxHistoricalPivots (window skip); the FIFO deletes the oldest   |
//| DRAWN id when the rendered population exceeds the limit.         |
//|                                                                  |
//| Fixture: a deterministic staircase series. Every 3rd bar is a    |
//| strict 5-bar fractal extremum (high 91 over flats 90 / low 87    |
//| under flats 88), alternating H/L. The pivot engine locks+promotes|
//| on every opposite-type swing, so pivots == swings EXACTLY and    |
//| pivot id == index + 1. With 20,448 pivots the population matches |
//| the live Phase-1.5 measurement (Pivot 11.892s catch-up).         |
//|                                                                  |
//| Discriminators: VSE counters (cmds/objCreate/objDelete) prove    |
//| the command workload; chart-object probes prove the visible      |
//| state; renderer surfaces prove the bookkeeping. RED pre-fix:     |
//|   A: objCreate=20448 objDelete=20398 cmds=20846                  |
//|   B: cmds=20398 (phantom deletes every steady update)            |
//|                                                                  |
//| Detector chain: real CSwingDetector + CStructuralPivotEngine     |
//| + real CVisualStateEngine on the test chart (TestRunnerEA).      |
//+------------------------------------------------------------------+
#ifndef __TEST_PIVOT_RENDERER_MQH__
#define __TEST_PIVOT_RENDERER_MQH__

#include "../../Structure/SwingDetector.mqh"
#include "../../Structure/StructuralPivotEngine.mqh"
#include "../../Visualization/PivotRenderer.mqh"
#include "../TestAssert.mqh"

#define PTR_FIXTURE_PIVOTS 20448

//+------------------------------------------------------------------+
//| Fixture: staircase series producing exactly 'pivots' alternating |
//| swing highs/lows (one 5-bar fractal per 3 bars, no overlaps).    |
//| Swing id = j+1; pivot id = index+1; pivot i is HIGH (91.0) when  |
//| i is even, LOW (87.0) when i is odd.                             |
//+------------------------------------------------------------------+
void PTRBuildSeries(int pivots,
                    double &open[], double &high[], double &low[],
                    double &close[], datetime &time[])
{
    int bars = 3 * pivots + 5;
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
        time[b]  = D'2026.01.01' + b * 3600;
    }

    for(int j = 0; j < pivots; j++)
    {
        int c = 4 + 3 * j;
        if((j & 1) == 0)
            high[c] = 91.0;   // swing high (id j+1, odd)
        else
            low[c] = 87.0;    // swing low (id j+1, even)
    }
}

//+------------------------------------------------------------------+
//| Fresh detector chain + renderer + VSE, fully caught up (tick 1). |
//+------------------------------------------------------------------+
void PTRSetup(TestCounters &counters, int pivots,
              CSwingDetector &swing, CStructuralPivotEngine &pivot,
              CPivotRenderer &renderer, CVisualStateEngine &vse,
              double &open[], double &high[], double &low[],
              double &close[], datetime &time[])
{
    PTRBuildSeries(pivots, open, high, low, close, time);
    TEST_TRUE(swing.Init(), "PTR: swing init");
    TEST_TRUE(pivot.Init(), "PTR: pivot init");
    TEST_TRUE(renderer.Init(), "PTR: renderer init");
    vse.Init();
    renderer.SetDetector(GetPointer(pivot));
    renderer.SetVSE(GetPointer(vse));
    renderer.Clear();   // wipe any leftover SCX_PIVOT_ objects on the chart

    swing.Update(high, low, time, 3 * pivots + 5);
    pivot.Update(GetPointer(swing));
}

//+------------------------------------------------------------------+
//| Numeric extractor for the VSE PHASE_1_5 diagnostic line          |
//| ("VSE records=.. cmds=.. findCalls=.. findIter=.. objCreate=..   |
//|  objDelete=.."). Returns -1 when the key is absent.              |
//+------------------------------------------------------------------+
int PTRDiagValue(const string &diag, const string key)
{
    int pos = StringFind(diag, key);
    if(pos < 0)
        return -1;
    return (int)StringToInteger(StringSubstr(diag, pos + StringLen(key)));
}

//+------------------------------------------------------------------+
//| Real chart probe: count SCX_PIVOT_ objects on the test chart.    |
//+------------------------------------------------------------------+
int PTRCountPivotObjects(void)
{
    int total = ObjectsTotal(0, 0, OBJ_ARROW);
    int n = 0;
    for(int i = 0; i < total; i++)
    {
        string name = ObjectName(0, i, 0, OBJ_ARROW);
        if(StringFind(name, "SCX_PIVOT_") == 0)
            n++;
    }
    return n;
}

//+------------------------------------------------------------------+
//| Drawn-id window check: ids must be exactly firstId..firstId+49.  |
//+------------------------------------------------------------------+
bool PTREqualIdWindow(CPivotRenderer &renderer, int firstId)
{
    for(int i = 0; i < MaxHistoricalPivots; i++)
    {
        if(renderer.GetDrawnPivotId(i) != firstId + i)
            return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| TEST A: catch-up on a 20,448-pivot population renders exactly    |
//| the newest 50 - one draw per object, ZERO deletes, no draw-and-  |
//| delete storm (RED pre-fix: 20,448 draws + 20,398 deletes).       |
//+------------------------------------------------------------------+
void TestPivotRendererCatchUpWindow(TestCounters &counters)
{
    double open[], high[], low[], close[];
    datetime time[];
    CSwingDetector swing;
    CStructuralPivotEngine pivot;
    CPivotRenderer renderer;
    CVisualStateEngine vse;

    PTRSetup(counters, PTR_FIXTURE_PIVOTS, swing, pivot, renderer, vse, open, high, low, close, time);
    TEST_INT_EQ(PTR_FIXTURE_PIVOTS, pivot.GetPivotCount(), "PTR-A: fixture pin - exactly 20448 pivots");

    renderer.Update();

    TEST_INT_EQ(MaxHistoricalPivots, renderer.GetRenderedPivotCount(),
        "PTR-A: rendered population = newest 50 (not 20448)");
    TEST_INT_EQ(PTR_FIXTURE_PIVOTS, renderer.GetPivotDrawCursor(),
        "PTR-A: draw cursor advanced to the full population");
    TEST_INT_EQ(MaxHistoricalPivots, PTRCountPivotObjects(),
        "PTR-A: chart carries exactly 50 pivot objects");
    TEST_TRUE(PTREqualIdWindow(renderer, PTR_FIXTURE_PIVOTS - MaxHistoricalPivots + 1),
        "PTR-A: drawn ids are the newest 50 (20399..20448)");

    bool srcOk = true;
    StructuralPivot p;
    for(int i = 0; i < MaxHistoricalPivots; i++)
    {
        pivot.GetPivot(pivot.GetPivotCount() - MaxHistoricalPivots + i, p);
        if(p.id != renderer.GetDrawnPivotId(i))
            srcOk = false;
    }
    TEST_TRUE(srcOk, "PTR-A: drawn ids match the detector's newest-50 source of truth");

    string diag = vse.GetDiagAndReset();
    TEST_INT_EQ(MaxHistoricalPivots, PTRDiagValue(diag, "objCreate="),
        "PTR-A: VSE created exactly 50 objects (RED pre-fix: 20448)");
    TEST_INT_EQ(0, PTRDiagValue(diag, "objDelete="),
        "PTR-A: VSE deleted ZERO objects on catch-up (RED pre-fix: 20398)");
    TEST_INT_EQ(MaxHistoricalPivots, PTRDiagValue(diag, "cmds="),
        "PTR-A: exactly 50 commands executed (RED pre-fix: 20846)");

    renderer.Clear();
    vse.Shutdown();
    renderer.Shutdown();
    pivot.Shutdown();
    swing.Shutdown();
}

//+------------------------------------------------------------------+
//| TEST B: steady-state update with no new pivots issues ZERO       |
//| commands (RED pre-fix: 20,398 phantom delete commands per        |
//| update) and the rendered population is untouched.                |
//+------------------------------------------------------------------+
void TestPivotRendererSteadyZeroPhantomDeletes(TestCounters &counters)
{
    double open[], high[], low[], close[];
    datetime time[];
    CSwingDetector swing;
    CStructuralPivotEngine pivot;
    CPivotRenderer renderer;
    CVisualStateEngine vse;

    PTRSetup(counters, PTR_FIXTURE_PIVOTS, swing, pivot, renderer, vse, open, high, low, close, time);
    renderer.Update();
    TEST_INT_EQ(MaxHistoricalPivots, renderer.GetRenderedPivotCount(), "PTR-B: baseline rendered");
    vse.GetDiagAndReset();   // clear baseline counters

    renderer.Update();       // steady update: detector unchanged

    TEST_INT_EQ(MaxHistoricalPivots, renderer.GetRenderedPivotCount(),
        "PTR-B: rendered population unchanged");
    TEST_TRUE(PTREqualIdWindow(renderer, PTR_FIXTURE_PIVOTS - MaxHistoricalPivots + 1),
        "PTR-B: drawn ids unchanged (no delete shifted the window)");
    TEST_INT_EQ(MaxHistoricalPivots, PTRCountPivotObjects(),
        "PTR-B: chart still carries exactly 50 pivot objects");
    TEST_INT_EQ(PTR_FIXTURE_PIVOTS, pivot.GetPivotCount(),
        "PTR-B: detector population untouched");

    string diag = vse.GetDiagAndReset();
    TEST_INT_EQ(0, PTRDiagValue(diag, "cmds="),
        "PTR-B: ZERO commands in steady state (RED pre-fix: 20398 phantom deletes)");
    TEST_INT_EQ(0, PTRDiagValue(diag, "objCreate="), "PTR-B: no creates in steady state");
    TEST_INT_EQ(0, PTRDiagValue(diag, "objDelete="), "PTR-B: no deletes in steady state");

    renderer.Clear();
    vse.Shutdown();
    renderer.Shutdown();
    pivot.Shutdown();
    swing.Shutdown();
}

//+------------------------------------------------------------------+
//| TEST C: one new pivot arrives on a live chain - the renderer     |
//| draws it, then FIFO-deletes the oldest DRAWN pivot (20399):      |
//| exactly 1 draw + 1 delete, newest 50 preserved (20400..20449).   |
//+------------------------------------------------------------------+
void TestPivotRendererWindowSlideOne(TestCounters &counters)
{
    double open[], high[], low[], close[];
    datetime time[];
    CSwingDetector swing;
    CStructuralPivotEngine pivot;
    CPivotRenderer renderer;
    CVisualStateEngine vse;

    //--- tick 1: full catch-up on the 20,448 population
    PTRSetup(counters, PTR_FIXTURE_PIVOTS, swing, pivot, renderer, vse, open, high, low, close, time);
    renderer.Update();
    TEST_INT_EQ(MaxHistoricalPivots, renderer.GetRenderedPivotCount(), "PTR-C: baseline rendered");
    vse.GetDiagAndReset();   // clear baseline counters

    //--- tick 2: one new swing arrives (series rebuilt +3 bars; the
    //    detector/pivot/renderer chains stay live and incremental)
    PTRBuildSeries(PTR_FIXTURE_PIVOTS + 1, open, high, low, close, time);
    swing.Update(high, low, time, 3 * (PTR_FIXTURE_PIVOTS + 1) + 5);
    pivot.Update(GetPointer(swing));
    TEST_INT_EQ(PTR_FIXTURE_PIVOTS + 1, pivot.GetPivotCount(),
        "PTR-C: fixture pin - 20449 pivots after incremental feed");

    renderer.Update();

    TEST_INT_EQ(MaxHistoricalPivots, renderer.GetRenderedPivotCount(),
        "PTR-C: rendered population stays at newest 50");
    TEST_TRUE(PTREqualIdWindow(renderer, PTR_FIXTURE_PIVOTS + 1 - MaxHistoricalPivots + 1),
        "PTR-C: drawn ids = 20400..20449 (oldest 20399 dropped)");
    TEST_INT_EQ(MaxHistoricalPivots, PTRCountPivotObjects(),
        "PTR-C: chart still carries exactly 50 pivot objects");

    TEST_TRUE(ObjectFind(0, PivotName(PTR_FIXTURE_PIVOTS + 1 - MaxHistoricalPivots)) < 0,
        "PTR-C: dropped pivot 20399 is gone from the chart");
    TEST_TRUE(ObjectFind(0, PivotName(PTR_FIXTURE_PIVOTS + 1)) >= 0,
        "PTR-C: new pivot 20449 IS on the chart");

    string diag = vse.GetDiagAndReset();
    TEST_INT_EQ(1, PTRDiagValue(diag, "objCreate="), "PTR-C: exactly 1 create (the new pivot)");
    TEST_INT_EQ(1, PTRDiagValue(diag, "objDelete="), "PTR-C: exactly 1 delete (the oldest drawn)");
    TEST_INT_EQ(2, PTRDiagValue(diag, "cmds="), "PTR-C: exactly 2 commands");

    renderer.Clear();
    vse.Shutdown();
    renderer.Shutdown();
    pivot.Shutdown();
    swing.Shutdown();
}

//+------------------------------------------------------------------+
//| TEST D: three new pivots arrive - the FIFO deletes the three     |
//| oldest DRAWN pivots (20399, 20400, 20401): 3 draws + 3 deletes,  |
//| newest 50 preserved (20402..20451).                              |
//+------------------------------------------------------------------+
void TestPivotRendererWindowSlideMany(TestCounters &counters)
{
    double open[], high[], low[], close[];
    datetime time[];
    CSwingDetector swing;
    CStructuralPivotEngine pivot;
    CPivotRenderer renderer;
    CVisualStateEngine vse;

    //--- tick 1: full catch-up on the 20,448 population
    PTRSetup(counters, PTR_FIXTURE_PIVOTS, swing, pivot, renderer, vse, open, high, low, close, time);
    renderer.Update();
    TEST_INT_EQ(MaxHistoricalPivots, renderer.GetRenderedPivotCount(), "PTR-D: baseline rendered");
    vse.GetDiagAndReset();   // clear baseline counters

    //--- tick 2: three new swings arrive (series rebuilt +9 bars)
    PTRBuildSeries(PTR_FIXTURE_PIVOTS + 3, open, high, low, close, time);
    swing.Update(high, low, time, 3 * (PTR_FIXTURE_PIVOTS + 3) + 5);
    pivot.Update(GetPointer(swing));
    TEST_INT_EQ(PTR_FIXTURE_PIVOTS + 3, pivot.GetPivotCount(),
        "PTR-D: fixture pin - 20451 pivots after incremental feed");

    renderer.Update();

    TEST_INT_EQ(MaxHistoricalPivots, renderer.GetRenderedPivotCount(),
        "PTR-D: rendered population stays at newest 50");
    TEST_TRUE(PTREqualIdWindow(renderer, PTR_FIXTURE_PIVOTS + 3 - MaxHistoricalPivots + 1),
        "PTR-D: drawn ids = 20402..20451 (three oldest dropped)");
    TEST_INT_EQ(MaxHistoricalPivots, PTRCountPivotObjects(),
        "PTR-D: chart still carries exactly 50 pivot objects");

    TEST_TRUE(ObjectFind(0, PivotName(PTR_FIXTURE_PIVOTS + 3 - MaxHistoricalPivots - 2)) < 0,
        "PTR-D: dropped pivot 20400 is gone from the chart");
    TEST_TRUE(ObjectFind(0, PivotName(PTR_FIXTURE_PIVOTS + 3 - MaxHistoricalPivots - 1)) < 0,
        "PTR-D: dropped pivot 20401 is gone from the chart");
    TEST_TRUE(ObjectFind(0, PivotName(PTR_FIXTURE_PIVOTS + 2)) >= 0,
        "PTR-D: pivot 20450 IS on the chart");
    TEST_TRUE(ObjectFind(0, PivotName(PTR_FIXTURE_PIVOTS + 3)) >= 0,
        "PTR-D: pivot 20451 IS on the chart");

    string diag = vse.GetDiagAndReset();
    TEST_INT_EQ(3, PTRDiagValue(diag, "objCreate="), "PTR-D: exactly 3 creates");
    TEST_INT_EQ(3, PTRDiagValue(diag, "objDelete="), "PTR-D: exactly 3 deletes");
    TEST_INT_EQ(6, PTRDiagValue(diag, "cmds="), "PTR-D: exactly 6 commands");

    renderer.Clear();
    vse.Shutdown();
    renderer.Shutdown();
    pivot.Shutdown();
    swing.Shutdown();
}

//+------------------------------------------------------------------+
//| TEST E: reset/deinit/reinit drops the draw cursor AND the drawn- |
//| id bookkeeping; the rebuilt render never reuses stale state      |
//| (RED pre-fix: the FIFO ran on detector-index arithmetic, so a    |
//| rebuilt state could issue deletes for pivots never drawn).       |
//+------------------------------------------------------------------+
void TestPivotRendererResetReinit(TestCounters &counters)
{
    double open[], high[], low[], close[];
    datetime time[];
    CSwingDetector swing;
    CStructuralPivotEngine pivot;
    CPivotRenderer renderer;
    CVisualStateEngine vse;

    PTRSetup(counters, PTR_FIXTURE_PIVOTS, swing, pivot, renderer, vse, open, high, low, close, time);
    renderer.Update();
    TEST_INT_EQ(MaxHistoricalPivots, renderer.GetRenderedPivotCount(), "PTR-E: baseline rendered");
    vse.GetDiagAndReset();

    //--- canonical clear (what the manager fires on a history reset)
    renderer.Clear();
    TEST_INT_EQ(0, renderer.GetRenderedPivotCount(), "PTR-E: Clear drops drawn bookkeeping");
    TEST_INT_EQ(0, renderer.GetPivotDrawCursor(), "PTR-E: Clear drops the draw cursor");
    TEST_INT_EQ(0, PTRCountPivotObjects(), "PTR-E: Clear removed every chart object");

    //--- rebuild from the same population: full window redraw, no stale state
    renderer.Update();
    TEST_INT_EQ(MaxHistoricalPivots, renderer.GetRenderedPivotCount(),
        "PTR-E: re-render after clear = newest 50 again");
    TEST_TRUE(PTREqualIdWindow(renderer, PTR_FIXTURE_PIVOTS - MaxHistoricalPivots + 1),
        "PTR-E: re-render drew the newest 50 ids");
    TEST_INT_EQ(MaxHistoricalPivots, PTRCountPivotObjects(),
        "PTR-E: chart carries exactly 50 pivot objects after re-render");

    string diag = vse.GetDiagAndReset();
    TEST_INT_EQ(MaxHistoricalPivots, PTRDiagValue(diag, "objCreate="),
        "PTR-E: re-render created exactly 50 objects");
    TEST_INT_EQ(0, PTRDiagValue(diag, "objDelete="), "PTR-E: re-render deleted nothing");

    //--- shutdown + init cycle
    renderer.Shutdown();
    TEST_INT_EQ(0, renderer.GetRenderedPivotCount(), "PTR-E: Shutdown drops drawn bookkeeping");
    TEST_INT_EQ(0, PTRCountPivotObjects(), "PTR-E: Shutdown removed every chart object");
    TEST_TRUE(renderer.Init(), "PTR-E: re-init succeeds");
    renderer.Update();
    TEST_INT_EQ(MaxHistoricalPivots, renderer.GetRenderedPivotCount(),
        "PTR-E: post-reinit render = newest 50 again");
    TEST_TRUE(PTREqualIdWindow(renderer, PTR_FIXTURE_PIVOTS - MaxHistoricalPivots + 1),
        "PTR-E: post-reinit drew the newest 50 ids");

    renderer.Clear();
    vse.Shutdown();
    renderer.Shutdown();
    pivot.Shutdown();
    swing.Shutdown();
}

//+------------------------------------------------------------------+
//| TEST F: visual identity - every chart object carries the exact   |
//| id, price (91.0 + 50*_Point for highs, 87.0 - 50*_Point for      |
//| lows) and time of its source pivot; nothing else is on the chart.|
//+------------------------------------------------------------------+
void TestPivotRendererVisualIdentity(TestCounters &counters)
{
    double open[], high[], low[], close[];
    datetime time[];
    CSwingDetector swing;
    CStructuralPivotEngine pivot;
    CPivotRenderer renderer;
    CVisualStateEngine vse;

    PTRSetup(counters, PTR_FIXTURE_PIVOTS, swing, pivot, renderer, vse, open, high, low, close, time);
    renderer.Update();

    bool idOk = true;
    for(int i = 0; i < MaxHistoricalPivots; i++)
    {
        int id = renderer.GetDrawnPivotId(i);
        string name = PivotName(id);
        if(ObjectFind(0, name) < 0)
        {
            idOk = false;
            break;
        }

        double expPrice = (((id - 1) & 1) == 0)
            ? 91.0 + PIVOT_ARROW_OFFSET_POINTS * _Point
            : 87.0 - PIVOT_ARROW_OFFSET_POINTS * _Point;
        if(MathAbs(ObjectGetDouble(0, name, OBJPROP_PRICE) - expPrice) > 1e-9)
        {
            idOk = false;
            break;
        }

        datetime expTime = D'2026.01.01' + (4 + 3 * (id - 1)) * 3600;
        if((datetime)ObjectGetInteger(0, name, OBJPROP_TIME) != expTime)
        {
            idOk = false;
            break;
        }
    }
    TEST_TRUE(idOk, "PTR-F: all 50 chart objects carry exact id/price/time identity");

    TEST_INT_EQ(MaxHistoricalPivots, PTRCountPivotObjects(),
        "PTR-F: no stale or extra pivot objects on the chart");

    renderer.Clear();
    vse.Shutdown();
    renderer.Shutdown();
    pivot.Shutdown();
    swing.Shutdown();
}

//+------------------------------------------------------------------+
//| Suite entry.                                                     |
//+------------------------------------------------------------------+
TestCounters RunPivotRendererTests(void)
{
    SUITE_BEGIN("PivotRenderer (Phase 2A: FIFO rendered-bookkeeping fix)");
    TestCounters counters;

    TestPivotRendererCatchUpWindow(counters);              // A
    TestPivotRendererSteadyZeroPhantomDeletes(counters);   // B
    TestPivotRendererWindowSlideOne(counters);             // C
    TestPivotRendererWindowSlideMany(counters);            // D
    TestPivotRendererResetReinit(counters);                // E
    TestPivotRendererVisualIdentity(counters);             // F

    SUITE_END("PivotRenderer (Phase 2A)");
    return counters;
}

#endif // __TEST_PIVOT_RENDERER_MQH__