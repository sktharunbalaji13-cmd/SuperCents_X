#property strict
#property script_show_inputs

#include "TestAssert.mqh"
#include "unit/TestWalkForward.mqh"
#include "unit/TestMonteCarlo.mqh"
#include "unit/TestRegression.mqh"
#include "unit/TestReportComposer.mqh"
#include "integration/TestValidationLab.mqh"

void OnStart(void)
{
    Print("");
    Print("==========================================");
    Print("  SuperCents_X — Validation Lab Test Suite");
    Print("==========================================");
    Print("");

    int grandTotal = 0;
    int grandPassed = 0;
    int grandFailed = 0;

    TestCounters r;

    r = RunWalkForwardTests();
    grandTotal += r.total; grandPassed += r.passed; grandFailed += r.failed;

    r = RunMonteCarloTests();
    grandTotal += r.total; grandPassed += r.passed; grandFailed += r.failed;

    r = RunRegressionTests();
    grandTotal += r.total; grandPassed += r.passed; grandFailed += r.failed;

    r = RunReportComposerTests();
    grandTotal += r.total; grandPassed += r.passed; grandFailed += r.failed;

    r = RunIntegrationTests();
    grandTotal += r.total; grandPassed += r.passed; grandFailed += r.failed;

    Print("");
    Print("==========================================");
    Print("  GRAND TOTAL: " + IntegerToString(grandPassed) + "/"
        + IntegerToString(grandTotal) + " passed, "
        + IntegerToString(grandFailed) + " failed");
    Print("==========================================");
}
