#include "../Validation/WalkForwardScheduler.mqh"
#include "BenchmarkTypes.mqh"

int RunWalkForwardBenchmarks(string &lines[], int &lineIdx)
{
    int totalBenchmarks = 0;

    SUITE_BENCH("WalkForward Benchmarks");

    int warmup = BENCH_WARMUP;
    int measured = BENCH_MEASURED;
    int windowSizes[4] = {10, 50, 100, 500};
    ENUM_WALK_FORWARD_MODE modes[3] = {WF_ROLLING, WF_EXPANDING, WF_ANCHORED};
    string modeLabels[3] = {"Rolling", "Expanding", "Anchored"};

    for(int m = 0; m < 3; m++)
    {
        for(int w = 0; w < 4; w++)
        {
            int targetWindows = windowSizes[w];
            ENUM_WALK_FORWARD_MODE mode = modes[m];
            string modeLabel = modeLabels[m];

            WalkForwardScheduleConfig cfg;
            cfg.overallStart = D'2020.01.01';
            cfg.overallEnd = (datetime)(D'2020.01.01' + (long)targetWindows * 60 * 86400);
            cfg.mode = mode;
            cfg.windowDays = 30;
            cfg.stepDays = 60;
            cfg.trainRatio = 0.70;
            cfg.minTrainDays = 5;
            cfg.minTestDays = 3;

            CWalkForwardScheduler sched;
            sched.Init();

            string label = StringFormat("WalkForward.Scheduler.%s.%d", modeLabel, targetWindows);
            BenchmarkResult br;
            br.Init(label, warmup, measured, targetWindows, "windows");

            for(int run = 0; run < warmup + measured; run++)
            {
                WalkForwardSchedule schedule;
                ulong t0 = GetMicrosecondCount();
                sched.Generate(cfg, schedule);
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

    SUITE_BENCH_END("WalkForward Benchmarks");
    return totalBenchmarks;
}
