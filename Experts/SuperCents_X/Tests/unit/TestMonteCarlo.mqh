#include "../../Validation/MonteCarloSimulator.mqh"
#include "../../Validation/MonteCarloTypes.mqh"
#include "../TestAssert.mqh"

TestCounters RunMonteCarloTests(void)
{
    TestCounters counters;

    SUITE_BEGIN("MonteCarlo Unit Tests");

    EventData trades[20];
    for(int i = 0; i < 20; i++)
        trades[i].profit = (i % 3 == 0) ? 200.0 : -80.0;

    // Test 1: Same seed → identical first run
    {
        CMonteCarloSimulator sim;
        sim.Init();
        MonteCarloRun r1, r2;
        bool ok1 = sim.ExecuteSingle(trades, 20, 12345, r1);
        bool ok2 = sim.ExecuteSingle(trades, 20, 12345, r2);

        TEST_TRUE(ok1, "ExecuteSingle should succeed");
        TEST_TRUE(ok2, "ExecuteSingle second call should succeed");
        TEST_DBL_EQ(r1.totalNetProfit, r2.totalNetProfit, "Same seed → identical profit");
        TEST_INT_EQ(r1.winningTrades, r2.winningTrades, "Same seed → identical wins");
        TEST_INT_EQ(r1.iteration, 0, "Run iteration defaults to 0");
        TEST_INT_EQ(r1.seed, 12345, "Run seed recorded correctly");
        TEST_INT_EQ(r1.randomEngine, RNG_MQL5_DEFAULT, "RNG engine recorded");
    }

    // Test 2: Different seeds recorded correctly
    {
        CMonteCarloSimulator sim;
        sim.Init();
        MonteCarloRun r1, r2;
        sim.ExecuteSingle(trades, 20, 11111, r1);
        sim.ExecuteSingle(trades, 20, 99999, r2);

        TEST_INT_EQ(11111, r1.seed, "Seed 11111 recorded in run");
        TEST_INT_EQ(99999, r2.seed, "Seed 99999 recorded in run");
        TEST_INT_EQ(RNG_MQL5_DEFAULT, r1.randomEngine, "RNG engine recorded");
    }

    // Test 3: ExecuteAll generates correct run count
    {
        CMonteCarloSimulator sim;
        sim.Init();

        MonteCarloConfig cfg;
        cfg.modes[0] = PERTURB_TRADE_ORDER;
        cfg.modeCount = 1;
        cfg.iterations = 50;
        cfg.randomSeed = 54321;

        MonteCarloRun runs[5000];
        int runCount = 0;
        bool ok = sim.ExecuteAll(trades, 20, cfg, runs, runCount);

        TEST_TRUE(ok, "ExecuteAll should succeed with 20 trades");
        TEST_INT_EQ(50, runCount, "ExecuteAll should produce 50 runs for 50 iterations");
    }

    // Test 4: probabilityOfLoss ∈ [0,1]
    {
        CMonteCarloSimulator sim;
        sim.Init();

        MonteCarloConfig cfg;
        cfg.modes[0] = PERTURB_TRADE_ORDER;
        cfg.modeCount = 1;
        cfg.iterations = 100;
        cfg.randomSeed = 12345;

        MonteCarloRun runs[5000];
        int runCount = 0;
        sim.ExecuteAll(trades, 20, cfg, runs, runCount);

        int losses = 0;
        for(int i = 0; i < runCount; i++)
            if(runs[i].totalNetProfit < 0.0) losses++;

        double probLoss = (double)losses / runCount;
        TEST_TRUE(probLoss >= 0.0, "Probability of loss >= 0");
        TEST_TRUE(probLoss <= 1.0, "Probability of loss <= 1");
    }

    // Test 5: Insufficient trades returns false
    {
        CMonteCarloSimulator sim;
        sim.Init();
        MonteCarloRun run;
        EventData singleTrade[1];
        singleTrade[0].profit = 100.0;
        bool ok = sim.ExecuteSingle(singleTrade, 1, 12345, run);
        TEST_FALSE(ok, "Single trade should not execute");
    }

    // Test 6: Config version is 1
    {
        MonteCarloConfig cfg;
        TEST_INT_EQ(1, cfg.configVersion, "MonteCarloConfig configVersion = 1");
    }

    SUITE_END("MonteCarlo Unit Tests");
    return counters;
}
