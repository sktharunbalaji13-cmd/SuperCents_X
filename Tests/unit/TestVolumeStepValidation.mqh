#ifndef __TEST_VOLUME_STEP_VALIDATION_MQH__
#define __TEST_VOLUME_STEP_VALIDATION_MQH__

#include "../TestAssert.mqh"
#include "../../Trading/TradeValidation.mqh"

//--- P52 focused regression: integer-domain volume-step validation (P51).
//    Uses live broker specs (EURUSD in tester) so bounds stay broker-robust;
//    dust forms are produced with the same MathRound/MathFloor ops as the
//    live producers, so the test exercises real representation behavior.
void TestVolumeStepIntDomain(TestCounters &counters)
{
    SUITE_BEGIN("P52 - volume-step int-domain validation");

    CTradeValidation validation;
    validation.SetSymbol("EURUSD");
    string reason = "";

    double volMin  = SymbolInfoDouble("EURUSD", SYMBOL_VOLUME_MIN);
    double volMax  = SymbolInfoDouble("EURUSD", SYMBOL_VOLUME_MAX);
    double volStep = SymbolInfoDouble("EURUSD", SYMBOL_VOLUME_STEP);
    TEST_TRUE(volMin > 0.0 && volStep > 0.0 && volMax > volMin, "P52a: live broker specs readable");

    // Exact boundaries.
    TEST_TRUE(validation.IsVolumeValid(volMin, reason), "P52b: exact minimum accepted");
    TEST_TRUE(validation.IsVolumeValid(volMax, reason), "P52c: exact maximum accepted");

    // Dust forms as emitted by live producers must now PASS (P49/P50 core).
    double dusty030 = MathRound(0.30 / volStep) * volStep;
    double dusty018 = MathRound(0.18 / volStep) * volStep;
    double dusty050 = MathRound(0.50 / volStep) * volStep;
    TEST_TRUE(validation.IsVolumeValid(dusty030, reason), "P52d: producer-form 0.30 accepted");
    TEST_TRUE(validation.IsVolumeValid(dusty018, reason), "P52e: producer-form 0.18 accepted");
    TEST_TRUE(validation.IsVolumeValid(dusty050, reason), "P52f: producer-form 0.50 accepted");

    // Full small grid in producer form: every grid intent accepted.
    bool gridOk = true;
    for(int k = 1; k <= 50; k++)
    {
        double pv = MathRound((volMin + k * volStep) / volStep) * volStep;
        if(!validation.IsVolumeValid(pv, reason))
            gridOk = false;
    }
    TEST_TRUE(gridOk, "P52g: producer-form grid k=1..50 all accepted");
    // Genuinely off-grid volumes still rejected.
    TEST_FALSE(validation.IsVolumeValid(volMin + volStep * 0.5, reason), "P52i: half-step rejected");
    TEST_FALSE(validation.IsVolumeValid(volMin + 0.005, reason), "P52j: 0.015-form rejected");
    TEST_FALSE(validation.IsVolumeValid(volMin + volStep + 0.0000001, reason), "P52k: +1e-7 off-grid rejected");
    TEST_FALSE(validation.IsVolumeValid(volMin + volStep - 0.0000001, reason), "P52l: -1e-7 off-grid rejected");

    // Documented residual band (P51): sub-tolerance dust treated as grid.
    TEST_TRUE(validation.IsVolumeValid(volMin + volStep + 0.000000001, reason), "P52m: +1e-9 dust band accepted");

    // Range violations unchanged.
    TEST_FALSE(validation.IsVolumeValid(volMin - volStep, reason), "P52n: below-minimum rejected");
    TEST_FALSE(validation.IsVolumeValid(volMax + volStep, reason), "P52o: above-maximum rejected");

    // Observed P50 corpus spot vectors (were REJECT-STEP dust failures).
    double spots[6];
    spots[0] = MathRound(0.12 / volStep) * volStep;
    spots[1] = MathRound(0.16 / volStep) * volStep;
    spots[2] = MathRound(0.36 / volStep) * volStep;
    spots[3] = MathRound(0.20 / volStep) * volStep;
    spots[4] = MathRound(0.29 / volStep) * volStep;
    spots[5] = MathRound(0.44 / volStep) * volStep;
    bool spotsOk = true;
    for(int s = 0; s < 6; s++)
    {
        if(!validation.IsVolumeValid(spots[s], reason))
            spotsOk = false;
    }
    TEST_TRUE(spotsOk, "P52p: P50 corpus spot volumes accepted");

    SUITE_END("P52 - volume-step int-domain validation");
}

TestCounters RunVolumeStepTests(void)
{
    TestCounters counters;
    TestVolumeStepIntDomain(counters);
    return counters;
}

#endif
