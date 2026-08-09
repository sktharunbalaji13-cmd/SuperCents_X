#include "../TestAssert.mqh"
#include "../utils/MockValidator.mqh"
#include "../../Entry/EntryOrchestrator.mqh"

ConfluenceResult MakeDefaultResult()
{
    ConfluenceResult r;
    r.valid = true;
    r.totalConfidence = 80.0;
    r.direction = CONFLUENCE_BULLISH;
    r.componentCount = 3;
    return r;
}

EntryContext MakeDefaultContext()
{
    EntryContext ctx;
    ctx.spread = 10.0;
    ctx.now = 0;
    ctx.currentBid = 1.1000;
    ctx.currentAsk = 1.1002;
    ctx.barsSinceSignal = 2;
    ctx.candidateEntryPrice = 1.1001;
    return ctx;
}

// ─── Tests ─────────────────────────────────────────────────────────

void TestEmptyRegistry(TestCounters &counters)
{
    CEntryOrchestrator orch;
    orch.Init();

    ConfluenceResult r = MakeDefaultResult();
    EntryDecision d = orch.Evaluate(r, 10.0, 0, 1.1000, 1.1002, 2, 1.1001);

    TEST_INT_EQ(DECISION_QUALIFIED, (int)d.status, "Empty registry → QUALIFIED");
    TEST_INT_EQ(0, d.filterCount, "Empty registry → 0 filters");
}

void TestSinglePass(TestCounters &counters)
{
    CEntryOrchestrator orch;
    orch.Init();
    CMockValidator v("PassV", FILTER_PASS);
    orch.RegisterValidator(&v);

    ConfluenceResult r = MakeDefaultResult();
    EntryDecision d = orch.Evaluate(r, 10.0, 0, 1.1000, 1.1002, 2, 1.1001);

    TEST_INT_EQ(DECISION_QUALIFIED, (int)d.status, "Single PASS → QUALIFIED");
    TEST_INT_EQ(1, d.filterCount, "Single PASS → 1 filter");
    TEST_INT_EQ(FILTER_PASS, (int)d.filters[0].result, "Filter result is PASS");
}

void TestSingleFail(TestCounters &counters)
{
    CEntryOrchestrator orch;
    orch.Init();
    CMockValidator v("FailV", FILTER_FAIL);
    orch.RegisterValidator(&v);

    ConfluenceResult r = MakeDefaultResult();
    EntryDecision d = orch.Evaluate(r, 10.0, 0, 1.1000, 1.1002, 2, 1.1001);

    TEST_INT_EQ(DECISION_REJECTED, (int)d.status, "Single FAIL → REJECTED");
    TEST_INT_EQ(1, d.filterCount, "Single FAIL → 1 filter");
    TEST_INT_EQ(1, d.rejectionCount, "Single FAIL → 1 rejection");
}

void TestStopOnFirstFail(TestCounters &counters)
{
    CEntryOrchestrator orch;
    orch.Init();
    CMockValidator v1("PassV", FILTER_PASS);
    CMockValidator v2("FailV", FILTER_FAIL);
    CMockValidator v3("NeverRun", FILTER_WARNING);
    orch.RegisterValidator(&v1);
    orch.RegisterValidator(&v2);
    orch.RegisterValidator(&v3);

    ConfluenceResult r = MakeDefaultResult();
    EntryDecision d = orch.Evaluate(r, 10.0, 0, 1.1000, 1.1002, 2, 1.1001);

    TEST_INT_EQ(DECISION_REJECTED, (int)d.status, "Stop-on-FAIL → REJECTED");
    TEST_INT_EQ(2, d.filterCount, "Stop-on-FAIL → 2 filters recorded (1 PASS + 1 FAIL)");
    TEST_INT_EQ(1, d.rejectionCount, "Stop-on-FAIL → 1 rejection");

    // v3 must not have been invoked
    TEST_INT_EQ(0, v3.GetInvokeCount(), "Stop-on-FAIL → third validator never invoked");
}

void TestWarningAccumulation(TestCounters &counters)
{
    CEntryOrchestrator orch;
    orch.Init();
    CMockValidator v1("Warn1", FILTER_WARNING);
    CMockValidator v2("Warn2", FILTER_WARNING);
    CMockValidator v3("PassV", FILTER_PASS);
    orch.RegisterValidator(&v1);
    orch.RegisterValidator(&v2);
    orch.RegisterValidator(&v3);

    ConfluenceResult r = MakeDefaultResult();
    EntryDecision d = orch.Evaluate(r, 10.0, 0, 1.1000, 1.1002, 2, 1.1001);

    TEST_INT_EQ(DECISION_QUALIFIED, (int)d.status, "Warning accumulation → QUALIFIED");
    TEST_INT_EQ(3, d.filterCount, "Warning accumulation → 3 filters");
    TEST_INT_EQ(0, d.rejectionCount, "Warning accumulation → 0 rejections");
    TEST_INT_EQ(1, v3.GetInvokeCount(), "Warning accumulation → third validator invoked");
}

void TestFailAfterWarning(TestCounters &counters)
{
    CEntryOrchestrator orch;
    orch.Init();
    CMockValidator v1("WarnV", FILTER_WARNING);
    CMockValidator v2("FailV", FILTER_FAIL);
    CMockValidator v3("NeverRun", FILTER_PASS);
    orch.RegisterValidator(&v1);
    orch.RegisterValidator(&v2);
    orch.RegisterValidator(&v3);

    ConfluenceResult r = MakeDefaultResult();
    EntryDecision d = orch.Evaluate(r, 10.0, 0, 1.1000, 1.1002, 2, 1.1001);

    TEST_INT_EQ(DECISION_REJECTED, (int)d.status, "FAIL after WARNING → REJECTED");
    TEST_INT_EQ(2, d.filterCount, "FAIL after WARNING → 2 filters");
    TEST_INT_EQ(0, v3.GetInvokeCount(), "FAIL after WARNING → third not invoked");
}

void TestDisabledValidator(TestCounters &counters)
{
    CEntryOrchestrator orch;
    orch.Init();
    CMockValidator v1("EnabledV", FILTER_PASS);
    CMockValidator v2("DisabledV", FILTER_FAIL);
    orch.RegisterValidator(&v1);
    orch.RegisterValidator(&v2);

    orch.GetRegistry().SetEnabled("DisabledV", false);

    ConfluenceResult r = MakeDefaultResult();
    EntryDecision d = orch.Evaluate(r, 10.0, 0, 1.1000, 1.1002, 2, 1.1001);

    TEST_INT_EQ(DECISION_QUALIFIED, (int)d.status, "Disabled FAIL → QUALIFIED (skipped)");
    TEST_INT_EQ(1, d.filterCount, "Disabled FAIL → only enabled validator counted");
    TEST_INT_EQ(0, v2.GetInvokeCount(), "Disabled FAIL → never invoked");
}

void TestFilterOrderPreservation(TestCounters &counters)
{
    CEntryOrchestrator orch;
    orch.Init();
    CMockValidator v1("First", FILTER_PASS);
    CMockValidator v2("Second", FILTER_WARNING);
    CMockValidator v3("Third", FILTER_PASS);
    orch.RegisterValidator(&v1);
    orch.RegisterValidator(&v2);
    orch.RegisterValidator(&v3);

    ConfluenceResult r = MakeDefaultResult();
    EntryDecision d = orch.Evaluate(r, 10.0, 0, 1.1000, 1.1002, 2, 1.1001);

    TEST_INT_EQ(FILTER_PASS, (int)d.filters[0].result, "Filter[0] = PASS (First)");
    TEST_INT_EQ(FILTER_WARNING, (int)d.filters[1].result, "Filter[1] = WARNING (Second)");
    TEST_INT_EQ(FILTER_PASS, (int)d.filters[2].result, "Filter[2] = PASS (Third)");
    TEST_INT_EQ(3, d.filterCount, "All 3 filters recorded");
}

// ─── Determinism ───────────────────────────────────────────────────

void TestDeterminism(TestCounters &counters)
{
    CEntryOrchestrator orch;
    orch.Init();

    CMockValidator v1("V1", FILTER_PASS);
    CMockValidator v2("V2", FILTER_WARNING);
    CMockValidator v3("V3", FILTER_PASS);
    orch.RegisterValidator(&v1);
    orch.RegisterValidator(&v2);
    orch.RegisterValidator(&v3);

    ConfluenceResult r = MakeDefaultResult();

    EntryDecision first = orch.Evaluate(r, 10.0, 0, 1.1000, 1.1002, 2, 1.1001);
    EntryDecision sample;

    bool allIdentical = true;

    for(int iter = 0; iter < 1000; iter++)
    {
        sample = orch.Evaluate(r, 10.0, 0, 1.1000, 1.1002, 2, 1.1001);

        if(sample.status != first.status
            || sample.filterCount != first.filterCount
            || sample.rejectionCount != first.rejectionCount)
        {
            allIdentical = false;
            break;
        }

        for(int f = 0; f < sample.filterCount; f++)
        {
            if(sample.filters[f].result != first.filters[f].result
                || sample.filters[f].reason != first.filters[f].reason)
            {
                allIdentical = false;
                break;
            }
        }

        if(!allIdentical)
            break;
    }

    TEST_TRUE(allIdentical, "Determinism: 1000 identical decisions");
}

// ─── Entry Point ───────────────────────────────────────────────────

TestCounters RunOrchestratorPipelineTests()
{
    TestCounters counters;
    SUITE_BEGIN("Orchestrator Pipeline Tests");

    TestEmptyRegistry(counters);
    TestSinglePass(counters);
    TestSingleFail(counters);
    TestStopOnFirstFail(counters);
    TestWarningAccumulation(counters);
    TestFailAfterWarning(counters);
    TestDisabledValidator(counters);
    TestFilterOrderPreservation(counters);
    TestDeterminism(counters);

    SUITE_END("Orchestrator Pipeline Tests");
    return counters;
}
