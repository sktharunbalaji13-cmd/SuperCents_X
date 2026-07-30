#ifndef __TEST_ASSERT_MQH__
#define __TEST_ASSERT_MQH__

struct TestCounters
{
    int total;
    int passed;
    int failed;

    TestCounters(void) { total = 0; passed = 0; failed = 0; }
};

#define TEST_TRUE(cond, msg) \
    { \
        counters.total++; \
        if(!(cond)) { counters.failed++; Print("  FAIL [" + IntegerToString(counters.total) + "] " + msg); } \
        else { counters.passed++; } \
    }

#define TEST_FALSE(cond, msg) \
    { \
        counters.total++; \
        if((cond)) { counters.failed++; Print("  FAIL [" + IntegerToString(counters.total) + "] " + msg); } \
        else { counters.passed++; } \
    }

#define TEST_INT_EQ(expected, actual, msg) \
    { \
        counters.total++; \
        int _e = (expected); int _a = (actual); \
        if(_e != _a) { counters.failed++; \
            Print("  FAIL [" + IntegerToString(counters.total) + "] " + msg \
                + " (exp=" + IntegerToString(_e) + " got=" + IntegerToString(_a) + ")"); } \
        else { counters.passed++; } \
    }

#define TEST_DBL_NEAR(expected, actual, eps, msg) \
    { \
        counters.total++; \
        double _e = (expected); double _a = (actual); double _eps = (eps); \
        if(MathAbs(_e - _a) > _eps) { counters.failed++; \
            Print("  FAIL [" + IntegerToString(counters.total) + "] " + msg \
                + " (exp=" + DoubleToString(_e, 6) + " got=" + DoubleToString(_a, 6) + ")"); } \
        else { counters.passed++; } \
    }

#define TEST_DATETIME_EQ(expected, actual, msg) \
    { \
        counters.total++; \
        datetime _e = (expected); datetime _a = (actual); \
        if(_e != _a) { counters.failed++; \
            Print("  FAIL [" + IntegerToString(counters.total) + "] " + msg \
                + " (exp=" + TimeToString(_e) + " got=" + TimeToString(_a) + ")"); } \
        else { counters.passed++; } \
    }

#define TEST_STR_EQ(expected, actual, msg) \
    { \
        counters.total++; \
        string _e = (expected); string _a = (actual); \
        if(_e != _a) { counters.failed++; \
            Print("  FAIL [" + IntegerToString(counters.total) + "] " + msg \
                + " (exp=\"" + _e + "\" got=\"" + _a + "\")"); } \
        else { counters.passed++; } \
    }

#define TEST_DBL_EQ(expected, actual, msg) \
    { \
        counters.total++; \
        double _e = (expected); double _a = (actual); \
        if(_e != _a) { counters.failed++; \
            Print("  FAIL [" + IntegerToString(counters.total) + "] " + msg \
                + " (exp=" + DoubleToString(_e, 6) + " got=" + DoubleToString(_a, 6) + ")"); } \
        else { counters.passed++; } \
    }

#define TEST_NOT_NULL(ptr, msg) \
    { \
        counters.total++; \
        if((ptr) == NULL) { counters.failed++; Print("  FAIL [" + IntegerToString(counters.total) + "] " + msg); } \
        else { counters.passed++; } \
    }

#define SUITE_BEGIN(name) Print("=== " + name + " ===");
#define SUITE_END(name) Print(">>> " + name + ": " + IntegerToString(counters.passed) + "/" + IntegerToString(counters.total) + " passed, " + IntegerToString(counters.failed) + " failed");

#endif
