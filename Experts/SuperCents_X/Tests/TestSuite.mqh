#property strict

#include "TestAssert.mqh"
#include "unit/TestWalkForward.mqh"
#include "unit/TestMonteCarlo.mqh"
#include "unit/TestRegression.mqh"
#include "unit/TestReportComposer.mqh"
#include "unit/TestConfluenceEngine.mqh"
#include "unit/TestValidators.mqh"
#include "unit/TestValidatorRegistry.mqh"
#include "unit/TestOrchestratorPipeline.mqh"
#include "unit/TestTelemetry.mqh"
#include "unit/TestForwardOutcomeSimulator.mqh"
#include "unit/TestCalibrationDataset.mqh"
#include "unit/TestCalibrationOptimizers.mqh"
#include "unit/TestProductionProviders.mqh"
#include "integration/TestValidationLab.mqh"

TestCounters RunAllSuperCentsTests(void)
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

    r = RunValidatorTests();
    grandTotal += r.total; grandPassed += r.passed; grandFailed += r.failed;

    r = RunValidatorRegistryTests();
    grandTotal += r.total; grandPassed += r.passed; grandFailed += r.failed;

    r = RunOrchestratorPipelineTests();
    grandTotal += r.total; grandPassed += r.passed; grandFailed += r.failed;

    r = RunIntegrationTests();
    grandTotal += r.total; grandPassed += r.passed; grandFailed += r.failed;

    r = RunConfluenceEngineTests();
    grandTotal += r.total; grandPassed += r.passed; grandFailed += r.failed;

    r = RunTelemetryTests();
    grandTotal += r.total; grandPassed += r.passed; grandFailed += r.failed;

    r = RunForwardOutcomeSimulatorTests();
    grandTotal += r.total; grandPassed += r.passed; grandFailed += r.failed;

    r = RunCalibrationDatasetTests();
    grandTotal += r.total; grandPassed += r.passed; grandFailed += r.failed;

    r = RunCalibrationOptimizersTests();
    grandTotal += r.total; grandPassed += r.passed; grandFailed += r.failed;

    r = RunProductionProviderTests();
    grandTotal += r.total; grandPassed += r.passed; grandFailed += r.failed;

    Print("");
    Print("==========================================");
    Print("  GRAND TOTAL: " + IntegerToString(grandPassed) + "/"
        + IntegerToString(grandTotal) + " passed, "
        + IntegerToString(grandFailed) + " failed");
    Print("==========================================");

    TestCounters result;
    result.total = grandTotal;
    result.passed = grandPassed;
    result.failed = grandFailed;
    return result;
}
