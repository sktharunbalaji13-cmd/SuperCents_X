#include "../Validation/MonteCarloSimulator.mqh"
#include "../Validation/MonteCarloTypes.mqh"
#include "BenchmarkTypes.mqh"

int RunMonteCarloBenchmarks(string &lines[], int &lineIdx)
{
    int totalBenchmarks = 0;

    SUITE_BENCH("MonteCarlo Benchmarks");

    int warmup = BENCH_WARMUP;
    int measured = BENCH_MEASURED;
    int iterValues[5] = {100, 500, 1000, 5000, 10000};
    int tradeValues[4] = {20, 100, 500, 1000};

    EventData syntheticTrades[1000];
    for(int i = 0; i < 1000; i++)
        syntheticTrades[i].profit = (i % 3 == 0) ? 200.0 : -80.0;

    MonteCarloRun mcRuns[];
    ArrayResize(mcRuns, MAX_MC_RUNS);

    for(int ti = 0; ti < 4; ti++)
    {
        int tradeCount = tradeValues[ti];

        for(int ii = 0; ii < 5; ii++)
        {
            int iterations = iterValues[ii];

            CMonteCarloSimulator sim;
            sim.Init();

            MonteCarloConfig cfg;
            cfg.modes[0] = PERTURB_TRADE_ORDER;
            cfg.modeCount = 1;
            cfg.iterations = iterations;
            cfg.randomSeed = 54321;

            string label = StringFormat("MonteCarlo.%dTrades.%dIter", tradeCount, iterations);
            BenchmarkResult br;
            br.Init(label, warmup, measured, iterations, "iterations");

            for(int run = 0; run < warmup + measured; run++)
            {
                int runCount = 0;
                ulong t0 = GetMicrosecondCount();
                sim.ExecuteAll(syntheticTrades, tradeCount, cfg, mcRuns, runCount);
                ulong t1 = GetMicrosecondCount();
                br.AddMeasurement(t1 - t0);
            }

            if(br.Compute())
            {
                br.PrintResult();
                lines[lineIdx] = br.ToBaselineLine();
                lineIdx++;
                totalBenchmarks++;
            }
        }
    }

    SUITE_BENCH_END("MonteCarlo Benchmarks");
    return totalBenchmarks;
}
