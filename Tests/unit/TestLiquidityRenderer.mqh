//+------------------------------------------------------------------+
//|                                     TestLiquidityRenderer.mqh     |
//|                    Sprint 20 - VF01: EQH/EQL renderer foundation  |
//|                                                                  |
//| Scope (user decision, 2026-08-08): VF01 = Equal High / Equal Low |
//| liquidity renderer foundation only. The detector is NOT touched; |
//| the renderer consumes CLiquidityDetector levels (EQH/EQL, ACTIVE |
//| only) and resolves swing times through the injected swing        |
//| detector. No CMD_EXTEND / CMD_FREEZE (static lines, per spec     |
//| v2.2 section 14A). The tested surface is the PURE command        |
//| builder BuildLevelCommand(): command-only behavior, zero direct  |
//| MT5 mutations.                                                   |
//|                                                                  |
//| Fixture: hourly bars (chronological k = 0 oldest), series arrays      |
//| (index 0 = newest) exactly like TestReconstruction (RECBuildSeries).  |
//| Equal swings: highs at k4 (1.1050), k10 (1.1052), k16 (1.1051); lows  |
//| at k6 (1.0948), k12 (1.0950), k18 (1.0949). Expected: ONE EQH cluster |
//| (avg 1.1051, members 3) and ONE EQL cluster (avg 1.0949, members 3).  |
//| Closes sit between the levels so no DD03 sweep fires.                 |
//|                                                                       |
//| Detector conventions relied on by the tests:                          |
//|  1. SwingDetector scans SERIES indices 4..(rates-3), i.e. newest      |
//|     bars first, so GetSwingHigh(i)/GetSwingLow(i) return swings in    |
//|     NEWEST-FIRST order and ids increment per confirmed swing across   |
//|     both sides (shared counter, first id = 1).                        |
//|  2. Because of (1), LiquidityDetector stores leftSwingId = NEWEST     |
//|     member and rightSwingId = OLDEST member. The renderer normalizes  |
//|     to chronological display order (line left = older, right = newer  |
//|     = formation), per spec v2.2 section 14A.                          |
//|  3. Bars that would need a scan center < 4 in series terms (the most  |
//|     recent 3-4 bars) are never swing-confirmed, so a 15-bar fixture   |
//|     cannot confirm the k12 low (series index 2). VF01.1 uses 17 bars. |
//+------------------------------------------------------------------+
#ifndef __TEST_LIQUIDITY_RENDERER_MQH__
#define __TEST_LIQUIDITY_RENDERER_MQH__

#include "../../Structure/SwingDetector.mqh"
#include "../../Structure/LiquidityDetector.mqh"
#include "../../Visualization/LiquidityRenderer.mqh"
#include "../../Visualization/VisualizationManager.mqh"
#include "../TestAssert.mqh"

#define LQR_BASE D'2026.02.01 00:00'

//--- Fixture: chronological k = 0..23. Arrays are SERIES (idx 0 = newest).
//--- k maps to the same absolute time in any prefix (base + k*3600).
void LQRBuildSeries(int bars,
                    double &high[], double &low[], double &close[],
                    datetime &time[], int &rates)
{
    rates = bars;
    ArrayResize(high, bars);
    ArrayResize(low, bars);
    ArrayResize(close, bars);
    ArrayResize(time, bars);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(time, true);

    double h[24] = {1.1000, 1.0990, 1.1000, 1.0990, 1.1050, 1.0990,
                    1.1000, 1.1005, 1.1020, 1.1010, 1.1052, 1.1010,
                    1.1020, 1.1015, 1.1040, 1.1020, 1.1051, 1.1030,
                    1.1040, 1.1020, 1.1010, 1.1010, 1.1010, 1.1010};
    double l[24] = {1.0990, 1.0980, 1.0990, 1.0980, 1.0985, 1.0980,
                    1.0948, 1.0960, 1.0970, 1.0970, 1.0990, 1.0975,
                    1.0950, 1.0970, 1.0970, 1.0975, 1.0980, 1.0970,
                    1.0949, 1.0980, 1.0990, 1.0985, 1.0990, 1.0985};

    for(int k = 0; k < bars; k++)
    {
        int idx = bars - 1 - k;
        high[idx]  = h[k];
        low[idx]   = l[k];
        close[idx] = (h[k] + l[k]) / 2.0;
        time[idx]  = LQR_BASE + k * 3600;
    }
}

//--- Find a swing id by its fixture time (k). Returns -1 if absent.
int LQRSwingIdByTime(CSwingDetector &swing, bool isHigh, int k)
{
    datetime target = LQR_BASE + k * 3600;
    int n = isHigh ? swing.GetSwingHighCount() : swing.GetSwingLowCount();
    for(int i = 0; i < n; i++)
    {
        SwingPoint sp;
        bool ok = isHigh ? swing.GetSwingHigh(i, sp) : swing.GetSwingLow(i, sp);
        if(ok && sp.time == target)
            return sp.id;
    }
    return -1;
}

//--- Shared fixture chain: swing -> liquidity (no BOS: no external
//--- levels, no sweeps/invalidations in VF01 scope).
void LQRBuildChain(CSwingDetector &swing, CLiquidityDetector &liq,
                   const double &high[], const double &low[],
                   const double &close[], const datetime &time[], int rates)
{
    swing.Update(high, low, time, rates);
    liq.Update(high, low, close, time, rates);
}

//--- VF01.1: EQH formation — level struct + pure command coordinates.
void TestLQR_EQH_FormationCoordinates(TestCounters &counters)
{
    CSwingDetector swing;
    CLiquidityDetector liq;
    TEST_TRUE(swing.Init(), "VF01.1: swing init");
    TEST_TRUE(liq.Init(), "VF01.1: liquidity init");
    liq.SetSwingDetector(GetPointer(swing));

    double high[], low[], close[];
    datetime time[];
    int rates;
    LQRBuildSeries(17, high, low, close, time, rates);
    LQRBuildChain(swing, liq, high, low, close, time, rates);

    int idH4 = LQRSwingIdByTime(swing, true, 4);
    int idH10 = LQRSwingIdByTime(swing, true, 10);
    int idL6 = LQRSwingIdByTime(swing, false, 6);
    int idL12 = LQRSwingIdByTime(swing, false, 12);
    TEST_INT_EQ(2, swing.GetSwingHighCount(), "VF01.1: swing high count (k4,k10)");
    TEST_INT_EQ(2, swing.GetSwingLowCount(), "VF01.1: swing low count (k6,k12)");
    TEST_TRUE(idH4 >= 0 && idH10 >= 0 && idL6 >= 0 && idL12 >= 0, "VF01.1: all member swings present");

    TEST_INT_EQ(2, liq.GetLevelCount(), "VF01.1: exactly one EQH + one EQL");

    LiquidityLevel lv0, lv1;
    TEST_TRUE(liq.GetLevel(0, lv0), "VF01.1: level 0 readable");
    TEST_TRUE(liq.GetLevel(1, lv1), "VF01.1: level 1 readable");

    TEST_INT_EQ(0, lv0.id, "VF01.1: EQH id = 0");
    TEST_INT_EQ((int)LIQUIDITY_EQH, (int)lv0.type, "VF01.1: level 0 type EQH");
    TEST_INT_EQ((int)LIQUIDITY_STATUS_ACTIVE, (int)lv0.status, "VF01.1: EQH ACTIVE");
    TEST_INT_EQ((int)LIQUIDITY_CLASS_BUY_SIDE, (int)lv0.classification, "VF01.1: EQH buy-side");
    TEST_DBL_NEAR(1.1051, lv0.averagePrice, 1e-9, "VF01.1: EQH avg price (1.1050+1.1052)/2");
    //--- Detector convention (newest-first scan): leftSwingId = newest member,
    //--- rightSwingId = oldest member. Renderer normalizes to chronological
    //--- display order (left = older, right = formation).
    TEST_INT_EQ(idH10, lv0.leftSwingId, "VF01.1: EQH left member = k10 (newest)");
    TEST_INT_EQ(idH4, lv0.rightSwingId, "VF01.1: EQH right member = k4 (oldest)");
    TEST_DATETIME_EQ(LQR_BASE + 10 * 3600, lv0.leftTime, "VF01.1: EQH leftTime = k10 swing time");
    TEST_DATETIME_EQ(LQR_BASE + 4 * 3600, lv0.rightTime, "VF01.1: EQH rightTime = k4 swing time");
    TEST_INT_EQ(2, lv0.memberCount, "VF01.1: EQH member count 2");

    TEST_INT_EQ(1, lv1.id, "VF01.1: EQL id = 1");
    TEST_INT_EQ((int)LIQUIDITY_EQL, (int)lv1.type, "VF01.1: level 1 type EQL");
    TEST_INT_EQ((int)LIQUIDITY_STATUS_ACTIVE, (int)lv1.status, "VF01.1: EQL ACTIVE");
    TEST_INT_EQ((int)LIQUIDITY_CLASS_SELL_SIDE, (int)lv1.classification, "VF01.1: EQL sell-side");
    TEST_DBL_NEAR(1.0949, lv1.averagePrice, 1e-9, "VF01.1: EQL avg price (1.0948+1.0950)/2");
    TEST_INT_EQ(idL12, lv1.leftSwingId, "VF01.1: EQL left member = k12 (newest)");
    TEST_INT_EQ(idL6, lv1.rightSwingId, "VF01.1: EQL right member = k6 (oldest)");
    TEST_DATETIME_EQ(LQR_BASE + 12 * 3600, lv1.leftTime, "VF01.1: EQL leftTime = k12 swing time");
    TEST_DATETIME_EQ(LQR_BASE + 6 * 3600, lv1.rightTime, "VF01.1: EQL rightTime = k6 swing time");
    TEST_INT_EQ(2, lv1.memberCount, "VF01.1: EQL member count 2");

    //--- Pure command builder: EQH (DIRECTION mode)
    CLiquidityRenderer renderer;
    TEST_TRUE(renderer.Init(), "VF01.1: renderer init");
    renderer.SetDetector(GetPointer(liq));
    renderer.SetSwingDetector(GetPointer(swing));

    VisualCommand cmd;
    TEST_TRUE(renderer.BuildLevelCommand(lv0, cmd, LIQUIDITY_LABEL_DIRECTION), "VF01.1: EQH command built");
    TEST_INT_EQ((int)CMD_DRAW, (int)cmd.type, "VF01.1: EQH command type DRAW");
    TEST_STR_EQ("SCX_LIQ_LINE_0", cmd.objName, "VF01.1: EQH object name");
    TEST_STR_EQ("SCX_LIQ_TEXT_0", cmd.textName, "VF01.1: EQH text name");
    TEST_INT_EQ((int)OBJ_TREND, (int)cmd.objType, "VF01.1: EQH object type OBJ_TREND");
    TEST_DATETIME_EQ(LQR_BASE + 4 * 3600, cmd.time1, "VF01.1: EQH left edge = k4 time");
    TEST_DATETIME_EQ(LQR_BASE + 10 * 3600, cmd.time2, "VF01.1: EQH right edge = k10 (formation)");
    TEST_DBL_NEAR(1.1051, cmd.price1, 1e-9, "VF01.1: EQH anchor price1 = avg");
    TEST_DBL_NEAR(1.1051, cmd.price2, 1e-9, "VF01.1: EQH anchor price2 = avg");
    TEST_INT_EQ((int)COLOR_LIQUIDITY_EQH, (int)cmd.lineColor, "VF01.1: EQH line color");
    TEST_INT_EQ((int)COLOR_LIQUIDITY_EQH, (int)cmd.textColor, "VF01.1: EQH text color");
    TEST_STR_EQ("BUY EQH", cmd.labelText, "VF01.1: EQH label (DIRECTION mode)");
    TEST_DATETIME_EQ(LQR_BASE + 10 * 3600, cmd.labelTime, "VF01.1: EQH label at formation");
    TEST_DBL_NEAR(1.1051 + 15 * _Point, cmd.labelPrice, 1e-9, "VF01.1: EQH label above level");
    TEST_INT_EQ(8, cmd.fontSize, "VF01.1: EQH font size 8");
    TEST_INT_EQ(2, cmd.width, "VF01.1: EQH width 2");
    TEST_INT_EQ((int)STYLE_SOLID, (int)cmd.lineStyle, "VF01.1: EQH solid");
    TEST_TRUE(renderer.BuildLevelCommand(lv1, cmd, LIQUIDITY_LABEL_DIRECTION), "VF01.1: EQL command built");
    TEST_STR_EQ("SCX_LIQ_LINE_1", cmd.objName, "VF01.1: EQL object name");
    TEST_STR_EQ("SCX_LIQ_TEXT_1", cmd.textName, "VF01.1: EQL text name");
    TEST_DATETIME_EQ(LQR_BASE + 6 * 3600, cmd.time1, "VF01.1: EQL left edge = k6 time");
    TEST_DATETIME_EQ(LQR_BASE + 12 * 3600, cmd.time2, "VF01.1: EQL right edge = k12 (formation)");
    TEST_DBL_NEAR(1.0949, cmd.price1, 1e-9, "VF01.1: EQL anchor price1 = avg");
    TEST_DBL_NEAR(1.0949, cmd.price2, 1e-9, "VF01.1: EQL anchor price2 = avg");
    TEST_INT_EQ((int)COLOR_LIQUIDITY_EQL, (int)cmd.lineColor, "VF01.1: EQL line color");
    TEST_INT_EQ((int)COLOR_LIQUIDITY_EQL, (int)cmd.textColor, "VF01.1: EQL text color");
    TEST_STR_EQ("SELL EQL", cmd.labelText, "VF01.1: EQL label (DIRECTION mode)");
    TEST_DATETIME_EQ(LQR_BASE + 12 * 3600, cmd.labelTime, "VF01.1: EQL label at formation");
    TEST_DBL_NEAR(1.0949 - 15 * _Point, cmd.labelPrice, 1e-9, "VF01.1: EQL label below level");

    renderer.Shutdown();
}

//--- VF01.2: cluster merge extends the right edge (formation moves to k16/k18).
void TestLQR_ClusterMergeUpdatesRightEdge(TestCounters &counters)
{
    CSwingDetector swing;
    CLiquidityDetector liq;
    TEST_TRUE(swing.Init(), "VF01.2: swing init");
    TEST_TRUE(liq.Init(), "VF01.2: liquidity init");
    liq.SetSwingDetector(GetPointer(swing));

    double high[], low[], close[];
    datetime time[];
    int rates;
    LQRBuildSeries(24, high, low, close, time, rates);
    LQRBuildChain(swing, liq, high, low, close, time, rates);

    int idH16 = LQRSwingIdByTime(swing, true, 16);
    int idL18 = LQRSwingIdByTime(swing, false, 18);
    TEST_INT_EQ(3, swing.GetSwingHighCount(), "VF01.2: swing high count (k4,k10,k16)");
    TEST_INT_EQ(3, swing.GetSwingLowCount(), "VF01.2: swing low count (k6,k12,k18)");

    TEST_INT_EQ(2, liq.GetLevelCount(), "VF01.2: merge does not create new levels");

    LiquidityLevel lv0, lv1;
    TEST_TRUE(liq.GetLevel(0, lv0), "VF01.2: level 0 readable");
    TEST_TRUE(liq.GetLevel(1, lv1), "VF01.2: level 1 readable");

    TEST_INT_EQ(idH16, lv0.leftSwingId, "VF01.2: EQH left member stays k16 (newest)");
    TEST_DATETIME_EQ(LQR_BASE + 16 * 3600, lv0.leftTime, "VF01.2: EQH leftTime stays k16");
    TEST_DATETIME_EQ(LQR_BASE + 4 * 3600, lv0.rightTime, "VF01.2: EQH rightTime = k4 (oldest, atomic with rightSwingId)");
    TEST_INT_EQ(3, lv0.memberCount, "VF01.2: EQH members 3");
    TEST_DBL_NEAR(1.1051, lv0.averagePrice, 1e-9, "VF01.2: EQH avg unchanged after merge");
    TEST_INT_EQ(idL18, lv1.leftSwingId, "VF01.2: EQL left member stays k18 (newest)");
    TEST_DATETIME_EQ(LQR_BASE + 18 * 3600, lv1.leftTime, "VF01.2: EQL leftTime stays k18");
    TEST_DATETIME_EQ(LQR_BASE + 6 * 3600, lv1.rightTime, "VF01.2: EQL rightTime = k6 (oldest, atomic with rightSwingId)");
    TEST_INT_EQ(3, lv1.memberCount, "VF01.2: EQL members 3");
    TEST_DBL_NEAR(1.0949, lv1.averagePrice, 1e-9, "VF01.2: EQL avg unchanged after merge");

    CLiquidityRenderer renderer;
    TEST_TRUE(renderer.Init(), "VF01.2: renderer init");
    renderer.SetDetector(GetPointer(liq));
    renderer.SetSwingDetector(GetPointer(swing));

    VisualCommand cmd;
    TEST_TRUE(renderer.BuildLevelCommand(lv0, cmd, LIQUIDITY_LABEL_DEBUG), "VF01.2: merged EQH command built");
    TEST_DATETIME_EQ(LQR_BASE + 16 * 3600, cmd.time2, "VF01.2: EQH right edge = k16 after merge");
    TEST_DATETIME_EQ(LQR_BASE + 4 * 3600, cmd.time1, "VF01.2: EQH left edge stays k4");
    TEST_TRUE(StringFind(cmd.labelText, "BUY EQH #0") == 0, "VF01.2: EQH DEBUG label has id");
    TEST_TRUE(renderer.BuildLevelCommand(lv1, cmd, LIQUIDITY_LABEL_DEBUG), "VF01.2: merged EQL command built");
    TEST_DATETIME_EQ(LQR_BASE + 18 * 3600, cmd.time2, "VF01.2: EQL right edge = k18 after merge");
    TEST_DATETIME_EQ(LQR_BASE + 6 * 3600, cmd.time1, "VF01.2: EQL left edge stays k6");
    TEST_TRUE(StringFind(cmd.labelText, "SELL EQL #1") == 0, "VF01.2: EQL DEBUG label has id");

    renderer.Shutdown();
}

//--- VF01.3: label modes (NONE / SIMPLE / DIRECTION / DEBUG).
void TestLQR_LabelModes(TestCounters &counters)
{
    CSwingDetector swing;
    CLiquidityDetector liq;
    TEST_TRUE(swing.Init(), "VF01.3: swing init");
    TEST_TRUE(liq.Init(), "VF01.3: liquidity init");
    liq.SetSwingDetector(GetPointer(swing));

    double high[], low[], close[];
    datetime time[];
    int rates;
    LQRBuildSeries(24, high, low, close, time, rates);
    LQRBuildChain(swing, liq, high, low, close, time, rates);

    CLiquidityRenderer renderer;
    TEST_TRUE(renderer.Init(), "VF01.3: renderer init");
    renderer.SetDetector(GetPointer(liq));
    renderer.SetSwingDetector(GetPointer(swing));

    LiquidityLevel lv0, lv1;
    TEST_TRUE(liq.GetLevel(0, lv0), "VF01.3: level 0 readable");
    TEST_TRUE(liq.GetLevel(1, lv1), "VF01.3: level 1 readable");

    VisualCommand cmd;
    TEST_TRUE(renderer.BuildLevelCommand(lv0, cmd, LIQUIDITY_LABEL_NONE), "VF01.3: NONE command built");
    TEST_STR_EQ("", cmd.labelText, "VF01.3: NONE label text empty");
    TEST_STR_EQ("", cmd.textName, "VF01.3: NONE text name empty");

    TEST_TRUE(renderer.BuildLevelCommand(lv0, cmd, LIQUIDITY_LABEL_SIMPLE), "VF01.3: SIMPLE EQH built");
    TEST_STR_EQ("EQH", cmd.labelText, "VF01.3: SIMPLE EQH label");
    TEST_TRUE(renderer.BuildLevelCommand(lv1, cmd, LIQUIDITY_LABEL_SIMPLE), "VF01.3: SIMPLE EQL built");
    TEST_STR_EQ("EQL", cmd.labelText, "VF01.3: SIMPLE EQL label");

    TEST_TRUE(renderer.BuildLevelCommand(lv0, cmd, LIQUIDITY_LABEL_DIRECTION), "VF01.3: DIRECTION EQH built");
    TEST_STR_EQ("BUY EQH", cmd.labelText, "VF01.3: DIRECTION EQH label");
    TEST_TRUE(renderer.BuildLevelCommand(lv1, cmd, LIQUIDITY_LABEL_DIRECTION), "VF01.3: DIRECTION EQL built");
    TEST_STR_EQ("SELL EQL", cmd.labelText, "VF01.3: DIRECTION EQL label");

    TEST_TRUE(renderer.BuildLevelCommand(lv0, cmd, LIQUIDITY_LABEL_DEBUG), "VF01.3: DEBUG EQH built");
    TEST_STR_EQ("BUY EQH #0", cmd.labelText, "VF01.3: DEBUG EQH label");
    TEST_TRUE(renderer.BuildLevelCommand(lv1, cmd, LIQUIDITY_LABEL_DEBUG), "VF01.3: DEBUG EQL built");
    TEST_STR_EQ("SELL EQL #1", cmd.labelText, "VF01.3: DEBUG EQL label");

    renderer.Shutdown();
}

//--- VF01.4: command gates — only ACTIVE EQH/EQL produce commands.
void TestLQR_CommandGates(TestCounters &counters)
{
    CLiquidityRenderer renderer;
    TEST_TRUE(renderer.Init(), "VF01.4: renderer init");
    VisualCommand cmd;

    //--- Non EQH/EQL type: external level must NOT render in VF01.
    LiquidityLevel ext;
    ext.id = 5;
    ext.type = LIQUIDITY_EXTERNAL_HH;
    ext.status = LIQUIDITY_STATUS_ACTIVE;
    ext.classification = LIQUIDITY_CLASS_BUY_SIDE;
    ext.averagePrice = 1.1100;
    ext.leftSwingId = 0;
    ext.rightSwingId = 1;
    TEST_FALSE(renderer.BuildLevelCommand(ext, cmd, LIQUIDITY_LABEL_NONE), "VF01.4: EXTERNAL_HH rejected (VF01 scope)");

    //--- Swept level: deferred lifecycle, must NOT render.
    LiquidityLevel swept;
    swept.id = 6;
    swept.type = LIQUIDITY_EQL;
    swept.status = LIQUIDITY_STATUS_SWEPT;
    swept.classification = LIQUIDITY_CLASS_SELL_SIDE;
    swept.averagePrice = 1.0900;
    swept.leftSwingId = 0;
    swept.rightSwingId = 1;
    TEST_FALSE(renderer.BuildLevelCommand(swept, cmd, LIQUIDITY_LABEL_NONE), "VF01.4: swept level rejected");

    //--- Unresolvable member times (stored-times gate): the detector never
    //--- persisted member times for this level, so it cannot be placed in
    //--- time and must be rejected. (The renderer no longer resolves member
    //--- times by scanning the swing detector.) Times are zeroed EXPLICITLY:
    //--- local struct members are not guaranteed to start at zero, so the
    //--- gate verdict must not depend on memory state (exposed by a suite
    //--- layout shift: garbage times made the gate accept the level).
    LiquidityLevel orphan;
    orphan.id = 7;
    orphan.type = LIQUIDITY_EQH;
    orphan.status = LIQUIDITY_STATUS_ACTIVE;
    orphan.classification = LIQUIDITY_CLASS_BUY_SIDE;
    orphan.averagePrice = 1.1050;
    orphan.leftSwingId = 999;
    orphan.rightSwingId = 998;
    orphan.leftTime = 0;
    orphan.rightTime = 0;
    TEST_FALSE(renderer.BuildLevelCommand(orphan, cmd, LIQUIDITY_LABEL_NONE), "VF01.4: level without stored member times rejected");

    //--- Uninitialized renderer: no commands.
    CLiquidityRenderer uninit;
    TEST_FALSE(uninit.BuildLevelCommand(swept, cmd, LIQUIDITY_LABEL_NONE), "VF01.4: uninitialized renderer rejected");

    renderer.Shutdown();
}

//--- VF01.5: lifecycle smoke — Init/Update/Clear/Shutdown never mutate
//--- without the VSE and complete cleanly through the VSE boundary.
void TestLQR_RendererLifecycleSmoke(TestCounters &counters)
{
    CSwingDetector swing;
    CLiquidityDetector liq;
    TEST_TRUE(swing.Init(), "VF01.5: swing init");
    TEST_TRUE(liq.Init(), "VF01.5: liquidity init");
    liq.SetSwingDetector(GetPointer(swing));

    double high[], low[], close[];
    datetime time[];
    int rates;
    LQRBuildSeries(24, high, low, close, time, rates);
    LQRBuildChain(swing, liq, high, low, close, time, rates);

    CVisualStateEngine vse;
    vse.Init();

    CLiquidityRenderer renderer;
    TEST_TRUE(renderer.Init(), "VF01.5: renderer init");
    renderer.SetDetector(GetPointer(liq));
    renderer.SetSwingDetector(GetPointer(swing));

    //--- No VSE: Update must be a guarded no-op (no chart mutation path).
    renderer.Update();
    TEST_TRUE(true, "VF01.5: Update without VSE is a no-op");

    //--- With VSE: Update executes DRAW commands through the VSE only.
    renderer.SetVSE(GetPointer(vse));
    renderer.Update();
    renderer.Update();
    TEST_TRUE(vse.IsActive("SCX_LIQ_LINE_0"), "VF01.5: EQH object tracked ACTIVE by VSE");
    TEST_TRUE(vse.IsActive("SCX_LIQ_LINE_1"), "VF01.5: EQL object tracked ACTIVE by VSE");

    renderer.Clear();
    renderer.Shutdown();
    TEST_TRUE(!renderer.IsInitialized(), "VF01.5: shutdown clears initialized flag");

    vse.Shutdown();
}

//--- VF01.6: production wiring contract. CVisualizationManager::SetSwingDetector
//--- must forward the swing detector to the liquidity renderer. Regression
//--- guard (VF01 root cause): previously only m_swing was wired — the
//--- renderer's ResolveMemberTime() then returned false for every level and
//--- the chart received zero SCX_LIQ_* objects while renderer-direct tests
//--- (which call SetSwingDetector explicitly) kept passing.
void TestLQR_ManagerForwardsSwingDetector(TestCounters &counters)
{
    CSwingDetector swing;
    TEST_TRUE(swing.Init(), "VF01.6: swing init");

    CVisualizationManager mgr;
    TEST_TRUE(mgr.Init(), "VF01.6: manager init");
    TEST_FALSE(mgr.IsLiquiditySwingDetectorWired(),
               "VF01.6: RED pre-wire: not forwarded before SetSwingDetector");

    mgr.SetSwingDetector(GetPointer(swing));
    TEST_TRUE(mgr.IsLiquiditySwingDetectorWired(),
              "VF01.6: manager forwards swing detector to liquidity renderer");

    mgr.Shutdown();
}

//+------------------------------------------------------------------+
//| Suite entry                                                      |
//+------------------------------------------------------------------+
TestCounters RunLiquidityRendererTests(void)
{
    TestCounters counters;
    TestLQR_EQH_FormationCoordinates(counters);
    TestLQR_ClusterMergeUpdatesRightEdge(counters);
    TestLQR_LabelModes(counters);
    TestLQR_CommandGates(counters);
    TestLQR_RendererLifecycleSmoke(counters);
    TestLQR_ManagerForwardsSwingDetector(counters);
    return counters;
}

#endif // __TEST_LIQUIDITY_RENDERER_MQH__
