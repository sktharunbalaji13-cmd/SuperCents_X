#include "../TestAssert.mqh"
#include "../utils/MockValidator.mqh"
#include "../../Entry/ValidatorRegistry.mqh"

// ─── Tests ─────────────────────────────────────────────────────────

void TestRegister_NewValidator(TestCounters &counters)
{
    CValidatorRegistry reg;
    CMockValidator v("ValidatorA", FILTER_PASS);

    bool ok = reg.Register(&v);

    TEST_TRUE(ok, "Register new validator returns true");
    TEST_INT_EQ(1, reg.Count(), "Register increases count to 1");
}

void TestRegister_DuplicateName(TestCounters &counters)
{
    CValidatorRegistry reg;
    CMockValidator v1("ValidatorA", FILTER_PASS);
    CMockValidator v2("ValidatorA", FILTER_WARNING);

    bool first = reg.Register(&v1);
    bool second = reg.Register(&v2);

    TEST_TRUE(first, "First registration accepted");
    TEST_FALSE(second, "Duplicate name rejected");
    TEST_INT_EQ(1, reg.Count(), "Count unchanged after duplicate");
}

void TestRegister_NullValidator(TestCounters &counters)
{
    CValidatorRegistry reg;

    bool ok = reg.Register(NULL);

    TEST_FALSE(ok, "Register NULL returns false");
    TEST_INT_EQ(0, reg.Count(), "Count remains 0 after NULL register");
}

void TestUnregister_Existing(TestCounters &counters)
{
    CValidatorRegistry reg;
    CMockValidator v1("V1", FILTER_PASS);
    CMockValidator v2("V2", FILTER_PASS);
    reg.Register(&v1);
    reg.Register(&v2);

    bool ok = reg.Unregister("V1");

    TEST_TRUE(ok, "Unregister existing returns true");
    TEST_INT_EQ(1, reg.Count(), "Count decreased after unregister");
    TEST_STR_EQ("V2", reg.GetValidator(0).GetName(), "Remaining validator is V2");
}

void TestUnregister_NotFound(TestCounters &counters)
{
    CValidatorRegistry reg;
    CMockValidator v("V1", FILTER_PASS);
    reg.Register(&v);

    bool ok = reg.Unregister("NonExistent");

    TEST_FALSE(ok, "Unregister non-existent returns false");
    TEST_INT_EQ(1, reg.Count(), "Count unchanged after non-existent unregister");
}

void TestEnableDisable(TestCounters &counters)
{
    CValidatorRegistry reg;
    CMockValidator v("V1", FILTER_PASS);
    reg.Register(&v);

    reg.SetEnabled("V1", false);
    TEST_FALSE(reg.IsEnabled("V1"), "Validator disabled after SetEnabled(false)");
    TEST_FALSE(reg.IsEnabledAt(0), "IsEnabledAt returns false for disabled");

    reg.SetEnabled("V1", true);
    TEST_TRUE(reg.IsEnabled("V1"), "Validator re-enabled after SetEnabled(true)");
    TEST_TRUE(reg.IsEnabledAt(0), "IsEnabledAt returns true for enabled");
}

void TestClear(TestCounters &counters)
{
    CValidatorRegistry reg;
    CMockValidator v1("V1", FILTER_PASS);
    CMockValidator v2("V2", FILTER_PASS);
    reg.Register(&v1);
    reg.Register(&v2);

    reg.Clear();

    TEST_INT_EQ(0, reg.Count(), "Count is 0 after Clear");
}

void TestCountByCategory(TestCounters &counters)
{
    CValidatorRegistry reg;
    CMockValidator v1("Setup1", FILTER_PASS);
    v1.SetCategory(CATEGORY_SETUP);
    CMockValidator v2("Market1", FILTER_PASS);
    v2.SetCategory(CATEGORY_MARKET);
    CMockValidator v3("Setup2", FILTER_PASS);
    v3.SetCategory(CATEGORY_SETUP);

    reg.Register(&v1);
    reg.Register(&v2);
    reg.Register(&v3);

    TEST_INT_EQ(2, reg.CountByCategory(CATEGORY_SETUP), "CountByCategory SETUP = 2");
    TEST_INT_EQ(1, reg.CountByCategory(CATEGORY_MARKET), "CountByCategory MARKET = 1");
    TEST_INT_EQ(0, reg.CountByCategory(CATEGORY_ACCOUNT), "CountByCategory ACCOUNT = 0");
}

void TestExecutionOrder(TestCounters &counters)
{
    CValidatorRegistry reg;
    CMockValidator v1("First", FILTER_PASS);
    CMockValidator v2("Second", FILTER_PASS);
    CMockValidator v3("Third", FILTER_PASS);

    reg.Register(&v1);
    reg.Register(&v2);
    reg.Register(&v3);

    IEntryValidator *gv0 = reg.GetValidator(0);
    IEntryValidator *gv1 = reg.GetValidator(1);
    IEntryValidator *gv2 = reg.GetValidator(2);

    TEST_NOT_NULL(gv0, "GetValidator(0) not NULL");
    TEST_NOT_NULL(gv1, "GetValidator(1) not NULL");
    TEST_NOT_NULL(gv2, "GetValidator(2) not NULL");

    if(gv0 != NULL)
        TEST_STR_EQ("First", gv0.GetName(), "Validator order [0] = First");
    if(gv1 != NULL)
        TEST_STR_EQ("Second", gv1.GetName(), "Validator order [1] = Second");
    if(gv2 != NULL)
        TEST_STR_EQ("Third", gv2.GetName(), "Validator order [2] = Third");
}

// ─── Entry Point ───────────────────────────────────────────────────

TestCounters RunValidatorRegistryTests()
{
    TestCounters counters;
    SUITE_BEGIN("Validator Registry Tests");

    TestRegister_NewValidator(counters);
    TestRegister_DuplicateName(counters);
    TestRegister_NullValidator(counters);
    TestUnregister_Existing(counters);
    TestUnregister_NotFound(counters);
    TestEnableDisable(counters);
    TestClear(counters);
    TestCountByCategory(counters);
    TestExecutionOrder(counters);

    SUITE_END("Validator Registry Tests");
    return counters;
}
