#ifndef __MONTE_CARLO_SIMULATOR_MQH__
#define __MONTE_CARLO_SIMULATOR_MQH__

#include "../Core/Logger.mqh"
#include "../Optimization/MonteCarloValidator.mqh"
#include "MonteCarloTypes.mqh"

#define MAX_MC_EVENT_DATA 5000
#define MAX_MC_RUNS 50000

class CMonteCarloSimulator
{
private:
    CLogger             m_logger;
    bool                m_isInitialized;
    CMonteCarloValidator m_validator;

    void ShuffleArray(double &arr[], int count, int seed) const
    {
        MathSrand(seed);
        for(int i = count - 1; i > 0; i--)
        {
            int j = (int)((MathRand() / 32768.0) * (i + 1));
            if(j > i) j = i;
            double tmp = arr[i];
            arr[i] = arr[j];
            arr[j] = tmp;
        }
    }

public:
    CMonteCarloSimulator(void)
        : m_logger(MODULE_LABORATORY, "MonteCarloSimulator")
        , m_isInitialized(false)
    {}

    ~CMonteCarloSimulator(void)
    {
        Shutdown();
    }

    bool Init(void)
    {
        if(!m_validator.Init(12345))
        {
            m_logger.LogError("Failed to initialize CMonteCarloValidator");
            return false;
        }
        m_isInitialized = true;
        m_logger.LogInfo("MonteCarloSimulator initialized");
        return true;
    }

    void Shutdown(void)
    {
        m_validator.Shutdown();
        m_isInitialized = false;
    }

    bool IsInitialized(void) const { return m_isInitialized; }

    bool ExecuteSingle(const EventData &trades[],
                       int tradeCount,
                       int seed,
                       MonteCarloRun &out)
    {
        if(!m_isInitialized)
            return false;

        if(tradeCount < 2)
            return false;

        out = MonteCarloRun();
        out.randomEngine = RNG_MQL5_DEFAULT;
        out.seed = seed;

        double profits[];
        ArrayResize(profits, tradeCount);
        double totalOrig = 0.0;
        for(int i = 0; i < tradeCount; i++)
        {
            profits[i] = trades[i].profit;
            totalOrig += trades[i].profit;
        }

        ShuffleArray(profits, tradeCount, seed);

        double netProfit = 0.0;
        double grossProfit = 0.0;
        double grossLoss = 0.0;
        int wins = 0;

        for(int i = 0; i < tradeCount; i++)
        {
            netProfit += profits[i];
            if(profits[i] > 0.0)
            {
                grossProfit += profits[i];
                wins++;
            }
            else if(profits[i] < 0.0)
            {
                grossLoss += profits[i];
            }
        }

        out.totalNetProfit = netProfit;
        out.totalGrossProfit = grossProfit;
        out.totalGrossLoss = grossLoss;
        out.totalTrades = tradeCount;
        out.winningTrades = wins;
        out.winRate = (tradeCount > 0) ? (double)wins / tradeCount * 100.0 : 0.0;

        return true;
    }

    bool ExecuteAll(const EventData &trades[],
                    int tradeCount,
                    const MonteCarloConfig &cfg,
                    MonteCarloRun &runs[],
                    int &runCount)
    {
        if(!m_isInitialized)
            return false;

        if(tradeCount < 2)
        {
            m_logger.LogError("Insufficient trades for Monte Carlo simulation");
            return false;
        }

        runCount = 0;

        for(int m = 0; m < cfg.modeCount && m < 4; m++)
        {
            ENUM_PERTURBATION_MODE mode = cfg.modes[m];

            for(int iter = 0; iter < cfg.iterations && runCount < MAX_MC_RUNS; iter++)
            {
                int iterSeed = cfg.randomSeed + iter + (m * 100000);
                MonteCarloRun run;
                if(!ExecuteSingle(trades, tradeCount, iterSeed, run))
                    continue;

                run.mode = mode;
                run.iteration = iter;

                runs[runCount] = run;
                runCount++;
            }
        }

        m_logger.LogInfo(StringFormat("Generated %d Monte Carlo runs from %d trades",
            runCount, tradeCount));
        return runCount > 0;
    }
};

#endif
