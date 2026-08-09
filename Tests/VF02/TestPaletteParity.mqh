//+------------------------------------------------------------------+
//| TestPaletteParity.mqh - VF02 palette parity regression suite     |
//|                                                                    |
//| Pins every color constant of the visualization palette (§16 of    |
//| the design spec) to its canonical value, verifies the dim tiers   |
//| are channel-scaled from the full tier, and locks the OB           |
//| no-historical-tier lifecycle contract.                            |
//|                                                                    |
//| §16 table (canonical):                                             |
//|   tier      full        frozen (60%)      historical (35%)        |
//|   swing hi  0xE53935    -                 0x501413                |
//|   swing lo  0x43A047    -                 0x173818                |
//|   pivot     0x9E9E9E    -                 0x373737                |
//|   PP hi     0x42A5F5    0x276393          0x173A56                |
//|   PP lo     0xFB8C00    0x965400          0x573100                |
//|   BOS bull  0x00C853    0x007832          0x00461D                |
//|   BOS bear  0xD32F2F    0x7E1C1C          0x4A1010                |
//|   CHOCH     0xFFB300    0x996B00          0x593E00                |
//|   OB        0x1976D2    0x0F467E          0x09294A                |
//|   FVG       0xFFD54F    0x99802F          0x594A1C                |
//|   LQ EQH    0xFFA726    -                 -                       |
//|   LQ EQL    0x26C6DA    -                 -                       |
//|                                                                    |
//| OB lifecycle contract: the OB renderer never emits a               |
//| PROMOTE_HISTORICAL command; OB zones are only Active or Frozen.   |
//+------------------------------------------------------------------+
#ifndef __TEST_PALETTE_PARITY_MQH__
#define __TEST_PALETTE_PARITY_MQH__

#include "../../Visualization/ChartStyle.mqh"
#include "../../Visualization/VisualStateEngine.mqh"
#include "../../Visualization/OrderBlockRenderer.mqh"
#include "../TestAssert.mqh"
#include "../integration/TestReconstruction.mqh"

//+------------------------------------------------------------------+
//| Max per-channel deviation between full and a channel-scaled      |
//| dimmed color (tolerance 1.0 allows hand-tuned spec values).      |
//+------------------------------------------------------------------+
double PPDimDeviation(uint full, uint dim, double factor)
{
    double maxDev = 0.0;
    for(int ch = 0; ch < 3; ch++)
    {
        int shift = 16 - ch * 8;
        double f = (double)((full >> shift) & 0xFF);
        double d = (double)((dim >> shift) & 0xFF);
        double dev = MathAbs(f * factor - d);
        if(dev > maxDev)
            maxDev = dev;
    }
    return maxDev;
}

//+------------------------------------------------------------------+
//| Test 1: CHOCH tier colors (drift regression pin).                |
//+------------------------------------------------------------------+
void RunPPTest_CHOCHTier(TestCounters &counters)
{
    TEST_INT_EQ(0xFFB300, COLOR_CHOCH, "COLOR_CHOCH (active) == 0xFFB300");
    TEST_INT_EQ(0x996B00, COLOR_CHOCH_FROZEN, "COLOR_CHOCH_FROZEN == 0x996B00");
    TEST_INT_EQ(0x593E00, COLOR_CHOCH_HIST, "COLOR_CHOCH_HIST == 0x593E00");
}

//+------------------------------------------------------------------+
//| Test 2: OB tier colors (missing historical constant pin).        |
//+------------------------------------------------------------------+
void RunPPTest_OBTier(TestCounters &counters)
{
    TEST_INT_EQ(0x1976D2, COLOR_OB, "COLOR_OB (active) == 0x1976D2");
    TEST_INT_EQ(0x0F467E, COLOR_OB_FROZEN, "COLOR_OB_FROZEN == 0x0F467E");
    TEST_INT_EQ(0x09294A, COLOR_OB_HIST, "COLOR_OB_HIST == 0x09294A");
}

//+------------------------------------------------------------------+
//| Test 3: full §16 palette sweep (every constant pinned).          |
//+------------------------------------------------------------------+
void RunPPTest_FullSweep(TestCounters &counters)
{
    //--- Active tier
    TEST_INT_EQ(0xE53935, COLOR_SWING_HIGH, "COLOR_SWING_HIGH == 0xE53935");
    TEST_INT_EQ(0x43A047, COLOR_SWING_LOW, "COLOR_SWING_LOW == 0x43A047");
    TEST_INT_EQ(0x9E9E9E, COLOR_PIVOT, "COLOR_PIVOT == 0x9E9E9E");
    TEST_INT_EQ(0x42A5F5, COLOR_PIVOT_PROTECTED_HIGH, "COLOR_PIVOT_PROTECTED_HIGH == 0x42A5F5");
    TEST_INT_EQ(0xFB8C00, COLOR_PIVOT_PROTECTED_LOW, "COLOR_PIVOT_PROTECTED_LOW == 0xFB8C00");
    TEST_INT_EQ(0x00C853, COLOR_BOS_BULLISH, "COLOR_BOS_BULLISH == 0x00C853");
    TEST_INT_EQ(0xD32F2F, COLOR_BOS_BEARISH, "COLOR_BOS_BEARISH == 0xD32F2F");
    TEST_INT_EQ(0xFFB300, COLOR_CHOCH, "COLOR_CHOCH == 0xFFB300");
    TEST_INT_EQ(0x1976D2, COLOR_OB, "COLOR_OB == 0x1976D2");
    TEST_INT_EQ(0xFFD54F, COLOR_FVG, "COLOR_FVG == 0xFFD54F");
    TEST_INT_EQ(0x42A5F5, COLOR_PROTECTED_HIGH, "COLOR_PROTECTED_HIGH == 0x42A5F5");
    TEST_INT_EQ(0xFB8C00, COLOR_PROTECTED_LOW, "COLOR_PROTECTED_LOW == 0xFB8C00");
    TEST_INT_EQ(0xFFA726, COLOR_LIQUIDITY_EQH, "COLOR_LIQUIDITY_EQH == 0xFFA726");
    TEST_INT_EQ(0x26C6DA, COLOR_LIQUIDITY_EQL, "COLOR_LIQUIDITY_EQL == 0x26C6DA");

    //--- Frozen tier
    TEST_INT_EQ(0x007832, COLOR_BOS_BULLISH_FROZEN, "COLOR_BOS_BULLISH_FROZEN == 0x007832");
    TEST_INT_EQ(0x7E1C1C, COLOR_BOS_BEARISH_FROZEN, "COLOR_BOS_BEARISH_FROZEN == 0x7E1C1C");
    TEST_INT_EQ(0x996B00, COLOR_CHOCH_FROZEN, "COLOR_CHOCH_FROZEN == 0x996B00");
    TEST_INT_EQ(0x276393, COLOR_PROTECTED_HIGH_FROZEN, "COLOR_PROTECTED_HIGH_FROZEN == 0x276393");
    TEST_INT_EQ(0x965400, COLOR_PROTECTED_LOW_FROZEN, "COLOR_PROTECTED_LOW_FROZEN == 0x965400");
    TEST_INT_EQ(0x0F467E, COLOR_OB_FROZEN, "COLOR_OB_FROZEN == 0x0F467E");
    TEST_INT_EQ(0x99802F, COLOR_FVG_FROZEN, "COLOR_FVG_FROZEN == 0x99802F");

    //--- Historical tier
    TEST_INT_EQ(0x501413, COLOR_SWING_HIGH_HIST, "COLOR_SWING_HIGH_HIST == 0x501413");
    TEST_INT_EQ(0x173818, COLOR_SWING_LOW_HIST, "COLOR_SWING_LOW_HIST == 0x173818");
    TEST_INT_EQ(0x373737, COLOR_PIVOT_HIST, "COLOR_PIVOT_HIST == 0x373737");
    TEST_INT_EQ(0x00461D, COLOR_BOS_BULLISH_HIST, "COLOR_BOS_BULLISH_HIST == 0x00461D");
    TEST_INT_EQ(0x4A1010, COLOR_BOS_BEARISH_HIST, "COLOR_BOS_BEARISH_HIST == 0x4A1010");
    TEST_INT_EQ(0x593E00, COLOR_CHOCH_HIST, "COLOR_CHOCH_HIST == 0x593E00");
    TEST_INT_EQ(0x173A56, COLOR_PROTECTED_HIGH_HIST, "COLOR_PROTECTED_HIGH_HIST == 0x173A56");
    TEST_INT_EQ(0x573100, COLOR_PROTECTED_LOW_HIST, "COLOR_PROTECTED_LOW_HIST == 0x573100");
    TEST_INT_EQ(0x09294A, COLOR_OB_HIST, "COLOR_OB_HIST == 0x09294A");
    TEST_INT_EQ(0x594A1C, COLOR_FVG_HIST, "COLOR_FVG_HIST == 0x594A1C");
}

//+------------------------------------------------------------------+
//| Test 4: dim math - every frozen/historical tier color must be a  |
//| per-channel scale of its full tier color (max deviation <= 1).   |
//+------------------------------------------------------------------+
void RunPPTest_DimMath(TestCounters &counters)
{
    TEST_TRUE(PPDimDeviation(COLOR_BOS_BULLISH, COLOR_BOS_BULLISH_FROZEN, 0.60) <= 1.0,
        "BOS bullish frozen = 60% scale of active");
    TEST_TRUE(PPDimDeviation(COLOR_BOS_BULLISH, COLOR_BOS_BULLISH_HIST, 0.35) <= 1.0,
        "BOS bullish historical = 35% scale of active");
    TEST_TRUE(PPDimDeviation(COLOR_BOS_BEARISH, COLOR_BOS_BEARISH_FROZEN, 0.60) <= 1.0,
        "BOS bearish frozen = 60% scale of active");
    TEST_TRUE(PPDimDeviation(COLOR_BOS_BEARISH, COLOR_BOS_BEARISH_HIST, 0.35) <= 1.0,
        "BOS bearish historical = 35% scale of active");
    TEST_TRUE(PPDimDeviation(COLOR_CHOCH, COLOR_CHOCH_FROZEN, 0.60) <= 1.0,
        "CHOCH frozen = 60% scale of active");
    TEST_TRUE(PPDimDeviation(COLOR_CHOCH, COLOR_CHOCH_HIST, 0.35) <= 1.0,
        "CHOCH historical = 35% scale of active");
    TEST_TRUE(PPDimDeviation(COLOR_PROTECTED_HIGH, COLOR_PROTECTED_HIGH_FROZEN, 0.60) <= 1.0,
        "Protected high frozen = 60% scale of active");
    TEST_TRUE(PPDimDeviation(COLOR_PROTECTED_HIGH, COLOR_PROTECTED_HIGH_HIST, 0.35) <= 1.0,
        "Protected high historical = 35% scale of active");
    TEST_TRUE(PPDimDeviation(COLOR_PROTECTED_LOW, COLOR_PROTECTED_LOW_FROZEN, 0.60) <= 1.0,
        "Protected low frozen = 60% scale of active");
    TEST_TRUE(PPDimDeviation(COLOR_PROTECTED_LOW, COLOR_PROTECTED_LOW_HIST, 0.35) <= 1.0,
        "Protected low historical = 35% scale of active");
    TEST_TRUE(PPDimDeviation(COLOR_OB, COLOR_OB_FROZEN, 0.60) <= 1.0,
        "OB frozen = 60% scale of active");
    TEST_TRUE(PPDimDeviation(COLOR_OB, COLOR_OB_HIST, 0.35) <= 1.0,
        "OB historical = 35% scale of active");
    TEST_TRUE(PPDimDeviation(COLOR_FVG, COLOR_FVG_FROZEN, 0.60) <= 1.0,
        "FVG frozen = 60% scale of active");
    TEST_TRUE(PPDimDeviation(COLOR_FVG, COLOR_FVG_HIST, 0.35) <= 1.0,
        "FVG historical = 35% scale of active");
    TEST_TRUE(PPDimDeviation(COLOR_SWING_HIGH, COLOR_SWING_HIGH_HIST, 0.35) <= 1.0,
        "Swing high historical = 35% scale of active");
    TEST_TRUE(PPDimDeviation(COLOR_SWING_LOW, COLOR_SWING_LOW_HIST, 0.35) <= 1.0,
        "Swing low historical = 35% scale of active");
    TEST_TRUE(PPDimDeviation(COLOR_PIVOT, COLOR_PIVOT_HIST, 0.35) <= 1.0,
        "Pivot historical = 35% scale of active");
}

//+------------------------------------------------------------------+
//| Test 5: liquidity EQH/EQL parity pin (renderer-level constant    |
//| parity is covered by the VF01 suite; here we pin the constants). |
//+------------------------------------------------------------------+
void RunPPTest_LiquidityParity(TestCounters &counters)
{
    TEST_INT_EQ(0xFFA726, COLOR_LIQUIDITY_EQH, "Liquidity EQH == 0xFFA726 (matches spec)");
    TEST_INT_EQ(0x26C6DA, COLOR_LIQUIDITY_EQL, "Liquidity EQL == 0x26C6DA (matches spec)");
}

//+------------------------------------------------------------------+
//| Test 6: OB no-historical-tier contract. The OB renderer must     |
//| never promote OB zones to the historical tier; states are only   |
//| Active (extending) or Frozen (mitigated). Control: the VSE       |
//| machinery itself CAN promote an OB-named object - proving the    |
//| renderer simply never asks.                                      |
//+------------------------------------------------------------------+
void RunPPTest_OBNoHistorical(TestCounters &counters)
{
    double open[], high[], low[], close[];
    datetime time[];
    RECBuildSeries(0, REC_BARS, open, high, low, close, time);

    CSwingDetector swing;
    CStructuralPivotEngine pivot;
    CBOSDetector bos;
    CTrendState trend;
    CProtectedPointManager pp;
    CCHOCHDetector choch;
    COrderBlockDetector ob;
    CFVGDetector fvg;
    CLiquidityDetector liq;
    CHistoryEpoch epoch;

    CRecChain chain;
    RECInitChain(chain, epoch, swing, pivot, bos, trend, pp, choch, ob, fvg, liq, counters);

    CVisualStateEngine vse;
    COrderBlockRenderer renderer;
    renderer.Init();
    renderer.SetDetector(GetPointer(ob));
    renderer.SetVSE(GetPointer(vse));

    RECDriveChain(chain, open, high, low, close, time, REC_BARS);
    renderer.Update();

    TEST_INT_EQ(1, ob.GetOrderBlockCount(), "Fixture drives exactly 1 OB zone");

    OrderBlock obEvent;
    bool got = ob.GetOrderBlock(0, obEvent);
    TEST_TRUE(got, "First order block retrievable");
    if(!got)
        return;

    string rectName = OBRectName(obEvent.id);

    TEST_TRUE(vse.IsActive(rectName) || vse.IsFrozen(rectName),
        "OB rect registered in VSE as Active or Frozen");
    TEST_FALSE(vse.IsHistorical(rectName),
        "OB rect NOT historical after first Update");

    renderer.Update();
    TEST_FALSE(vse.IsHistorical(rectName),
        "OB rect still NOT historical after second Update (idempotent)");

    //--- Control: the VSE promote machinery works for OB-named objects
    VisualCommand cmd;
    cmd.type = CMD_PROMOTE_HISTORICAL;
    cmd.objName = rectName;
    vse.Execute(cmd);
    TEST_TRUE(vse.IsHistorical(rectName),
        "Control: VSE CAN promote an OB-named object (renderer never asks)");
}

//+------------------------------------------------------------------+
//| Category entry point.                                            |
//+------------------------------------------------------------------+
TestCounters RunPaletteParityTests(void)
{
    TestCounters counters;
    Print("--- Palette Parity Tests ---");

    RunPPTest_CHOCHTier(counters);
    RunPPTest_OBTier(counters);
    RunPPTest_FullSweep(counters);
    RunPPTest_DimMath(counters);
    RunPPTest_LiquidityParity(counters);
    RunPPTest_OBNoHistorical(counters);

    Print(">>> Palette Parity Tests: " + IntegerToString(counters.passed) + "/"
        + IntegerToString(counters.total) + " passed, "
        + IntegerToString(counters.failed) + " failed");
    return counters;
}

#endif // __TEST_PALETTE_PARITY_MQH__
