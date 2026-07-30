#ifndef __BENCHMARK_TYPES_MQH__
#define __BENCHMARK_TYPES_MQH__

#define BENCH_WARMUP 1
#define BENCH_MEASURED 20
#define MAX_BENCH_ITERATIONS 50000

struct BenchmarkResult
{
    string      label;
    ulong       rawUs[];
    int         warmupCount;
    int         measuredCount;
    int         totalCount;
    int         inputSize;
    string      throughputUnit;

    double      minUs;
    double      avgUs;
    double      maxUs;
    double      stdDevUs;
    double      rsd;
    double      throughput;

    void Init(string _label, int _warmup, int _measured, int _inputSize, string _unit)
    {
        label = _label;
        warmupCount = _warmup;
        measuredCount = _measured;
        totalCount = 0;
        inputSize = _inputSize;
        throughputUnit = _unit;
        ArrayResize(rawUs, warmupCount + measuredCount);
        minUs = 0; avgUs = 0; maxUs = 0; stdDevUs = 0; rsd = 0; throughput = 0;
    }

    bool AddMeasurement(ulong us)
    {
        if(totalCount >= ArraySize(rawUs))
            return false;
        rawUs[totalCount] = us;
        totalCount++;
        return true;
    }

    bool Compute(void)
    {
        int startIdx = warmupCount;
        int n = totalCount - warmupCount;
        if(n < 1)
        {
            Print("  WARN: " + label + " has no measured runs");
            return false;
        }

        double sum = 0.0;
        minUs = 1e18;
        maxUs = 0.0;
        for(int i = startIdx; i < totalCount; i++)
        {
            double val = (double)rawUs[i];
            sum += val;
            if(val < minUs) minUs = val;
            if(val > maxUs) maxUs = val;
        }
        avgUs = sum / n;

        double variance = 0.0;
        for(int i = startIdx; i < totalCount; i++)
        {
            double diff = (double)rawUs[i] - avgUs;
            variance += diff * diff;
        }
        variance /= n;
        stdDevUs = MathSqrt(variance);
        rsd = (avgUs > 0.0) ? stdDevUs / avgUs : 0.0;

        if(avgUs > 0.0)
        {
            if(inputSize > 0)
                throughput = (double)inputSize / (avgUs / 1000000.0);
            else
                throughput = 1.0 / (avgUs / 1000000.0);
        }

        return true;
    }

    void PrintResult(void)
    {
        Print("  Benchmark: " + label);
        if(inputSize > 0)
            Print("    Input: " + IntegerToString(inputSize) + " " + throughputUnit);
        Print("    Results: Min=" + DoubleToString(minUs, 1) + " us, Avg=" + DoubleToString(avgUs, 1) + " us, Max=" + DoubleToString(maxUs, 1) + " us");
        Print("    StdDev: " + DoubleToString(stdDevUs, 1) + " us, RSD: " + DoubleToString(rsd * 100.0, 2) + "%");
        Print("    Throughput: " + DoubleToString(throughput, 1) + " " + throughputUnit + "/sec");
    }

    string ToBaselineLine(void)
    {
        return StringFormat("%s AvgUs=%.1f MinUs=%.1f MaxUs=%.1f StdDevUs=%.1f RSD=%.4f Input=%d Unit=%s",
            label, avgUs, minUs, maxUs, stdDevUs, rsd, inputSize, throughputUnit);
    }
};

string BuildHeader(void)
{
    return StringFormat(
        "Validation Lab Performance Baseline\n"
        "Version=v2.7-validation-lab\n"
        "Compiler=MQL5 Build %d\n"
        "Date=%s\n"
        "Terminal=%s\n"
        "------------------------------",
        __MQLBUILD__, __DATETIME__, TerminalInfoString(TERMINAL_NAME));
}

#define SUITE_BENCH(name) Print("=== " + name + " ===");
#define SUITE_BENCH_END(name) Print(">>> " + name + " complete");

#endif
