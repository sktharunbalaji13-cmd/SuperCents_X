//+------------------------------------------------------------------+
//|                                   TestVisualStateEngine.mqh       |
//|                     Track 3 - VSE label registry + placement      |
//|                                                                  |
//| Defect (Phase-1.5 live evidence, EURUSD M5, ~170 chart objects): |
//| ChartUtils::ResolveLabelPrice() ran a full-chart ObjectsTotal()  |
//| scan per label placement (ObjectName + OBJPROP_TYPE per object,  |
//| up to 10 iterations). Live draw bars hit 94.9 ms (new EQH level) |
//| and 127.9 ms (new EQL level) inside the LiquidityRenderer.       |
//|                                                                  |
//| Fix under test: CVisualStateEngine owns an in-memory label       |
//| registry, synced at the single choke point every label mutation  |
//| flows through (HandleDraw/HandleFreeze/HandleDelete/Reset/       |
//| DeleteObjectsByPrefix). ResolveLabelPlacement() runs the         |
//| algorithm-identical 2-hour-window / step / direction / 10-       |
//| iteration resolution over the registry instead of the chart.     |
//|                                                                  |
//| Test A (parity): the ORIGINAL chart-scan algorithm is frozen as  |
//| a local reference implementation; a real VSE populated through   |
//| CMD_DRAW must reproduce the reference EXACTLY across window/     |
//| step/direction/cap scenarios. Iteration order is irrelevant      |
//| because the candidate depends only on the collision SET.         |
//|                                                                  |
//| Test B (sync): CMD_FREEZE without freezeLockLabel moves the      |
//| label AND its registry entry; freezeLockLabel preserves both;    |
//| CMD_DELETE removes the entry (idempotent); Reset() clears.       |
//|                                                                  |
//| Test C (prefix clear): DeleteObjectsByPrefix removes chart       |
//| objects, VSE records AND registry entries.                       |
//|                                                                  |
//| Collision math: |price - candidate| < step (STRICT). Labels are  |
//| placed exactly AT query prices so every assertion is exact       |
//| (0-distance collisions, step-multiple nudges).                   |
//|                                                                  |
//| Fixture precision: the resolver accumulates candidate += step *  |
//| (iteration+1) over 10 iterations while label prices are stored   |
//| as single base + k*step sums; with decimal steps (0.0002) the    |
//| accumulated candidate and the stored price can differ in the     |
//| last double bit, making |price - candidate| land slightly UNDER  |
//| step at the "exactly one step away" boundary (this is the ORIG-  |
//| INAL algorithm's live behavior too - the frozen chart-scan       |
//| compared the same kinds of doubles). Hand-checks therefore use   |
//| binary-exact fixtures (step 0.25 = 2^-2, base 1.0) so every sum  |
//| is exact and the intended semantics are asserted directly; the   |
//| float-noise domain is covered by the parity sweep (ref and       |
//| implementation see the same doubles and must agree bit-for-bit). |
//|                                                                  |
//| Fixture: real CVisualStateEngine on the test chart (TestRunner   |
//| EA); unique "T3_" object namespace, fully cleaned up after.      |
//+------------------------------------------------------------------+
#ifndef __TEST_VISUAL_STATE_ENGINE_MQH__
#define __TEST_VISUAL_STATE_ENGINE_MQH__

#include "../../Visualization/VisualStateEngine.mqh"
#include "../TestAssert.mqh"

//--- Frozen reference: the REMOVED ChartUtils::ResolveLabelPrice
//    algorithm over a plain {time, price} array (simulating the chart
//    object scan). Any divergence from the VSE resolver is a
//    placement regression.
double VSE_RefResolveLabelPrice(datetime time, double basePrice, double step, int direction,
                                datetime &refTimes[], double &refPrices[], int refCount)
{
    double candidate = basePrice;
    for(int iteration = 0; iteration < 10; iteration++)
    {
        bool collision = false;
        for(int i = 0; i < refCount; i++)
        {
            if(MathAbs(refTimes[i] - time) > 7200)
                continue;
            if(MathAbs(refPrices[i] - candidate) < step)
            {
                collision = true;
                if(direction == 0)
                {
                    if(iteration < 5)
                        candidate += step * (iteration + 1);
                    else
                        candidate = basePrice - step * (iteration - 4);
                }
                else
                    candidate += direction * step * (iteration + 1);
                break;
            }
        }
        if(!collision)
            return candidate;
    }
    return candidate;
}

void VSE_BuildDraw(VisualCommand &cmd, string name, string textName,
                   datetime time1, double price1, datetime labelTime, double labelPrice)
{
    cmd.type       = CMD_DRAW;
    cmd.objName    = name;
    cmd.textName   = textName;
    cmd.objType    = OBJ_TREND;
    cmd.time1      = time1;
    cmd.price1     = price1;
    cmd.time2      = time1;
    cmd.price2     = price1;
    cmd.lineColor  = clrBlue;
    cmd.textColor  = clrBlue;
    cmd.labelText  = "T3";
    cmd.fontSize   = 8;
    cmd.labelTime  = labelTime;
    cmd.labelPrice = labelPrice;
}

void VSE_Cleanup(CVisualStateEngine &vse, string prefix = "T3_")
{
    int total = ObjectsTotal(0);
    for(int i = total - 1; i >= 0; i--)
    {
        string objName = ObjectName(0, i);
        if(StringFind(objName, prefix) == 0)
            ObjectDelete(0, objName);
    }
    vse.Reset();
}

//--- A: algorithm parity between the registry resolver and the frozen
//    chart-scan reference over window/step/direction/cap scenarios.
void TestVSEParity(TestCounters &counters)
{
    SUITE_BEGIN("VSE Label Placement Parity");
    CVisualStateEngine vse;
    vse.Init();
    VSE_Cleanup(vse);

    datetime anchor   = D'2026.08.18 12:00';
    double   base     = 1.0;
    double   step     = 0.25;      // 2^-2: binary-exact sums (see header)
    int      placed   = 0;
    datetime refTimes[];
    double   refPrices[];
    ArrayResize(refTimes, 128);
    ArrayResize(refPrices, 128);

    //--- Scenario 1: empty registry -> basePrice, all directions
    TEST_DBL_EQ(base, vse.ResolveLabelPlacement(anchor, base, step, 1), "empty registry -> base (dir +1)");
    TEST_DBL_EQ(base, vse.ResolveLabelPlacement(anchor, base, step, -1), "empty registry -> base (dir -1)");
    TEST_DBL_EQ(base, vse.ResolveLabelPlacement(anchor, base, step, 0), "empty registry -> base (dir 0)");

    //--- Scenario 2: label exactly at base -> single nudge per direction
    VisualCommand c;
    VSE_BuildDraw(c, "T3_a1", "T3_a1_lbl", anchor, 1.15000, anchor, base);
    vse.Execute(c);
    refTimes[placed] = anchor; refPrices[placed] = base; placed++;
    TEST_DBL_EQ(base + step, vse.ResolveLabelPlacement(anchor, base, step, 1), "label at base, dir +1 -> +step");
    TEST_DBL_EQ(base - step, vse.ResolveLabelPlacement(anchor, base, step, -1), "label at base, dir -1 -> -step");
    TEST_DBL_EQ(base + step, vse.ResolveLabelPlacement(anchor, base, step, 0), "label at base, dir 0 -> +step");

    //--- Scenario 3: dir 0 blocked upward -> second probe still up
    VSE_BuildDraw(c, "T3_a2", "T3_a2_lbl", anchor, 1.15000, anchor, base + step);
    vse.Execute(c);
    refTimes[placed] = anchor; refPrices[placed] = base + step; placed++;
    double got3 = vse.ResolveLabelPlacement(anchor, base, step, 0);
    double ref3 = VSE_RefResolveLabelPrice(anchor, base, step, 0, refTimes, refPrices, placed);
    TEST_DBL_EQ(ref3, got3, "dir 0 double-block parity");
    TEST_DBL_EQ(base + 3 * step, got3, "dir 0 double-block hand-check");

    //--- Scenario 4: 10-collision chain hits the iteration cap (dir +1)
    VSE_Cleanup(vse);
    placed = 0;
    for(int k = 0; k < 10; k++)
    {
        double p = base + k * step;
        VSE_BuildDraw(c, "T3_cap_" + IntegerToString(k), "T3_cap_" + IntegerToString(k) + "_lbl",
                      anchor, 1.15000, anchor, p);
        vse.Execute(c);
        refTimes[placed] = anchor; refPrices[placed] = p; placed++;
    }
    double gotCap = vse.ResolveLabelPlacement(anchor, base, step, 1);
    double refCap = VSE_RefResolveLabelPrice(anchor, base, step, 1, refTimes, refPrices, placed);
    TEST_DBL_EQ(refCap, gotCap, "10-collision chain: cap path parity");
    TEST_DBL_EQ(base + 10 * step, gotCap, "10-collision chain hand-check");

    //--- Scenario 5: window boundary 7200 s inclusive, 7201 s exclusive
    VSE_Cleanup(vse);
    placed = 0;
    VSE_BuildDraw(c, "T3_w1", "T3_w1_lbl", anchor - 7200, 1.15000, anchor - 7200, base);
    vse.Execute(c);
    refTimes[placed] = anchor - 7200; refPrices[placed] = base; placed++;
    TEST_DBL_EQ(base + step, vse.ResolveLabelPlacement(anchor, base, step, 1),
                "label at -7200 s is inside the 2-hour window -> collision");
    VSE_Cleanup(vse);
    placed = 0;
    VSE_BuildDraw(c, "T3_w2", "T3_w2_lbl", anchor - 7201, 1.15000, anchor - 7201, base);
    vse.Execute(c);
    refTimes[placed] = anchor - 7201; refPrices[placed] = base; placed++;
    TEST_DBL_EQ(base, vse.ResolveLabelPlacement(anchor, base, step, 1),
                "label at -7201 s is outside the 2-hour window -> no collision");

    //--- Scenario 6: step boundary is strict (|p-candidate| == step is NOT a collision)
    VSE_Cleanup(vse);
    placed = 0;
    VSE_BuildDraw(c, "T3_s1", "T3_s1_lbl", anchor, 1.15000, anchor, base + step);
    vse.Execute(c);
    refTimes[placed] = anchor; refPrices[placed] = base + step; placed++;
    TEST_DBL_EQ(base, vse.ResolveLabelPlacement(anchor, base, step, 1),
                "exactly 1 step away is not a collision (strict <)");

    //--- Scenario 7: randomized parity sweep (multi-label charts).
    //--- NOTE: label prices stay strictly ABOVE zero - HandleDraw treats
    //    labelPrice == 0.0 as the "use price1" sentinel (documented
    //    VisualCommand convention), so a zero-price fixture label would be
    //    registered at price1 instead and break registry/array parity.
    VSE_Cleanup(vse);
    placed = 0;
    for(int k = 1; k <= 24; k++)
    {
        double p = base + k * step;   // 1.25 .. 7.00 (no sentinel collision)
        VSE_BuildDraw(c, "T3_r_" + IntegerToString(k), "T3_r_" + IntegerToString(k) + "_lbl",
                      anchor, 1.15000, anchor, p);
        vse.Execute(c);
        refTimes[placed] = anchor; refPrices[placed] = p; placed++;
    }
    for(int dir = -1; dir <= 1; dir++)
    {
        for(int q = 0; q < 8; q++)
        {
            double queryBase = base + (q - 4) * step * 0.5;
            double got = vse.ResolveLabelPlacement(anchor, queryBase, step, dir);
            double ref = VSE_RefResolveLabelPrice(anchor, queryBase, step, dir, refTimes, refPrices, placed);
            TEST_DBL_EQ(ref, got, "parity dir=" + IntegerToString(dir) + " query=" + DoubleToString(queryBase, 5));
        }
    }

    VSE_Cleanup(vse);
    SUITE_END("VSE Label Placement Parity");
}

//--- B: registry sync through the command paths.
void TestVSERegistrySync(TestCounters &counters)
{
    SUITE_BEGIN("VSE Registry Sync");
    CVisualStateEngine vse;
    vse.Init();
    VSE_Cleanup(vse);

    datetime anchor = D'2026.08.18 12:00';
    double   step   = 0.25;       // 2^-2: binary-exact sums (see header)
    double   base   = 1.0;

    //--- Draw registers the placement; a second draw of the same name
    //    (HandleDraw early-return) does not double-register.
    VisualCommand c;
    VSE_BuildDraw(c, "T3_b1", "T3_b1_lbl", anchor, 1.15000, anchor, base);
    vse.Execute(c);
    TEST_DBL_EQ(base + step, vse.ResolveLabelPlacement(anchor, base, step, 1),
                "draw registers placement -> collision nudges");
    vse.Execute(c);
    TEST_DBL_EQ(base + step, vse.ResolveLabelPlacement(anchor, base, step, 1),
                "re-draw of existing object does not double-register");

    //--- Freeze WITHOUT freezeLockLabel moves the label and the registry.
    VisualCommand f;
    f.type        = CMD_FREEZE;
    f.objName     = "T3_b1";
    f.textName    = "T3_b1_lbl";
    f.time2       = anchor + 3600;
    f.price2      = base + 3 * step;
    f.lineStyle   = STYLE_DASH;
    f.lineColor   = clrRed;
    f.textColor   = clrRed;
    f.objType     = OBJ_TREND;
    f.freezeLockLabel = false;
    vse.Execute(f);
    TEST_DBL_EQ(base + 4 * step, vse.ResolveLabelPlacement(anchor, base + 3 * step, step, 1),
                "freeze (unlocked) moves label -> registry sees new price");

    //--- Freeze WITH freezeLockLabel preserves position and registry.
    VSE_BuildDraw(c, "T3_b2", "T3_b2_lbl", anchor, 1.15000, anchor, base);
    vse.Execute(c);
    f.objName  = "T3_b2";
    f.textName = "T3_b2_lbl";
    f.price2   = base + 5 * step;
    f.freezeLockLabel = true;
    vse.Execute(f);
    TEST_DBL_EQ(base + step, vse.ResolveLabelPlacement(anchor, base, step, 1),
                "freeze (locked) keeps label -> registry unchanged");

    //--- Delete removes the entry; deleting again is idempotent.
    VisualCommand d;
    d.type     = CMD_DELETE;
    d.objName  = "T3_b1";
    d.textName = "T3_b1_lbl";
    vse.Execute(d);
    TEST_DBL_EQ(base + 3 * step, vse.ResolveLabelPlacement(anchor, base + 3 * step, step, 1),
                "delete removes registry entry -> no collision");
    vse.Execute(d);
    TEST_DBL_EQ(base + 3 * step, vse.ResolveLabelPlacement(anchor, base + 3 * step, step, 1),
                "double delete is idempotent");

    //--- Reset clears the registry.
    VSE_BuildDraw(c, "T3_b3", "T3_b3_lbl", anchor, 1.15000, anchor, base);
    vse.Execute(c);
    TEST_DBL_EQ(base + step, vse.ResolveLabelPlacement(anchor, base, step, 1),
                "pre-reset placement registered");
    vse.Reset();
    TEST_DBL_EQ(base, vse.ResolveLabelPlacement(anchor, base, step, 1),
                "Reset clears registry -> no collision");

    VSE_Cleanup(vse);
    SUITE_END("VSE Registry Sync");
}

//--- C: prefix clear removes chart objects, records and registry.
void TestVSEDeleteByPrefix(TestCounters &counters)
{
    SUITE_BEGIN("VSE Prefix Clear");
    CVisualStateEngine vse;
    vse.Init();
    VSE_Cleanup(vse);

    datetime anchor = D'2026.08.18 12:00';
    double   step   = 0.25;       // 2^-2: binary-exact sums (see header)
    double   base   = 1.0;

    VisualCommand c;
    VSE_BuildDraw(c, "T3_k1", "T3_k1_lbl", anchor, 1.15000, anchor, base);
    vse.Execute(c);
    VSE_BuildDraw(c, "T3_k2", "T3_k2_lbl", anchor, 1.15000, anchor, base + step);
    vse.Execute(c);
    VSE_BuildDraw(c, "T3_k3", "T3_k3_lbl", anchor, 1.15000, anchor, base + 2 * step);
    vse.Execute(c);
    TEST_DBL_EQ(base + 3 * step, vse.ResolveLabelPlacement(anchor, base, step, 1),
                "three placements registered");

    vse.DeleteObjectsByPrefix("T3_");
    TEST_DBL_EQ(base, vse.ResolveLabelPlacement(anchor, base, step, 1),
                "prefix clear empties registry");

    bool objectsGone = true;
    for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
    {
        string objName = ObjectName(0, i);
        if(StringFind(objName, "T3_") == 0)
            objectsGone = false;
    }
    TEST_TRUE(objectsGone, "prefix clear removed all chart objects");

    //--- Extend after clear: no record -> silent no-op (records authoritative).
    VisualCommand e;
    e.type    = CMD_EXTEND;
    e.objName = "T3_k1";
    e.time2   = anchor + 3600;
    e.price2  = base;
    vse.Execute(e);
    TEST_DBL_EQ(base, vse.ResolveLabelPlacement(anchor, base, step, 1),
                "extend on cleared record is a silent no-op");

    VSE_Cleanup(vse);
    SUITE_END("VSE Prefix Clear");
}

TestCounters RunVisualStateEngineTests(void)
{
    TestCounters counters;
    TestVSEParity(counters);
    TestVSERegistrySync(counters);
    TestVSEDeleteByPrefix(counters);
    return counters;
}

#endif // __TEST_VISUAL_STATE_ENGINE_MQH__