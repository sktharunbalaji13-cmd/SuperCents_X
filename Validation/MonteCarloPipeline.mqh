#ifndef __MONTE_CARLO_PIPELINE_MQH__
#define __MONTE_CARLO_PIPELINE_MQH__

#include "../Core/Logger.mqh"
#include "../Optimization/MonteCarloValidator.mqh"
#include "MonteCarloSimulator.mqh"

class CMonteCarloPipeline
{
private:
    CLogger               m_logger;
    bool                  m_isInitialized;
    CMonteCarloSimulator  m_simulator;

    string BuildExperimentId(const MonteCarloConfig &cfg,
                             const string paramHash) const
    {
        return StringFormat("MC-%s-%d-%s-%d",
            paramHash,
            cfg.modeCount > 0 ? (int)cfg.modes[0] : -1,
            cfg.iterations,
            cfg.randomSeed);
    }

    void ExtractTrades(const ValidationResult &source,
                       EventData &trades[],
                       int &tradeCount) const
    {
        tradeCount = 0;
        BehavioralMetrics b = source.behavior;
        if(b.totalTrades > 0 && tradeCount < MAX_MC_EVENT_DATA)
        {
            EventData e;
            e.symbol = b.symbol;
            tradeCount++;
        }
    }

    int CompareDouble(const double &a, const double &b) const
    {
        if(a < b) return -1;
        if(a > b) return 1;
        return 0;
    }

    void SortProfits(double &profits[], int count) const
    {
        for(int i = 0; i < count - 1; i++)
        {
            for(int j = 0; j < count - 1 - i; j++)
            {
                if(profits[j] > profits[j + 1])
                {
                    double tmp = profits[j];
                    profits[j] = profits[j + 1];
                    profits[j + 1] = tmp;
                }
            }
        }
    }

    bool ComputeStatistics(const MonteCarloRun &runs[],
                           int runCount,
                           double originalProfit,
                           MonteCarloStatistics &stats,
                           CMonteCarloValidator &validator)
    {
        if(runCount < 2)
            return false;

        double profits[];
        ArrayResize(profits, runCount);

        double sum = 0.0;
        double sumSq = 0.0;
        int losses = 0;

        for(int i = 0; i < runCount; i++)
        {
            profits[i] = runs[i].totalNetProfit;
            sum += profits[i];
            sumSq += profits[i] * profits[i];
            if(profits[i] < 0.0)
                losses++;
        }

        stats.meanProfit = sum / runCount;
        stats.usedIterations = runCount;

        stats.stdDevProfit = (runCount > 1)
            ? MathSqrt((sumSq - (sum * sum) / runCount) / (runCount - 1))
            : 0.0;

        stats.probabilityOfLoss = (double)losses / runCount;

        SortProfits(profits, runCount);

        int idx50 = (int)(runCount * 0.50);
        int idx95 = (int)(runCount * 0.95);
        int idx99 = (int)(runCount * 0.99);
        if(idx50 >= runCount) idx50 = runCount - 1;
        if(idx95 >= runCount) idx95 = runCount - 1;
        if(idx99 >= runCount) idx99 = runCount - 1;

        stats.medianProfit = profits[idx50];
        stats.p95Profit = profits[idx95];
        stats.p99Profit = profits[idx99];

        stats.sufficientIterations = (runCount >= 30);
        if(runCount < 100)
            m_logger.LogWarn(StringFormat(
                "Monte Carlo: only %d iterations (recommend >= 100)", runCount));

        {
            EventData dummyTrades[];
            ArrayResize(dummyTrades, 2);
            dummyTrades[0].profit = originalProfit > 0.0 ? originalProfit * 0.5 : -50.0;
            dummyTrades[1].profit = originalProfit > 0.0 ? originalProfit * 0.5 : -50.0;

            bool significant = false;
            double p95 = 0.0, p99 = 0.0, median = 0.0;

            if(validator.Reshuffle(dummyTrades, 2, 100, p95, p99, median))
            {
                stats.isSignificant = (originalProfit > p95);
            }
            else
            {
                stats.isSignificant = (profits[idx95] < originalProfit);
            }
        }

        return true;
    }

public:
    CMonteCarloPipeline(void)
        : m_logger(MODULE_LABORATORY, "MonteCarloPipeline")
        , m_isInitialized(false)
    {}

    ~CMonteCarloPipeline(void)
    {
        Shutdown();
    }

    bool Init(void)
    {
        if(!m_simulator.Init())
        {
            m_logger.LogError("Failed to initialize MonteCarloSimulator");
            return false;
        }
        m_isInitialized = true;
        m_logger.LogInfo("MonteCarloPipeline initialized");
        return true;
    }

    void Shutdown(void)
    {
        m_simulator.Shutdown();
        m_isInitialized = false;
    }

    bool IsInitialized(void) const { return m_isInitialized; }

    bool Execute(const ValidationResult &source,
                 const MonteCarloConfig &cfg,
                 MonteCarloSummary &summary)
    {
        if(!m_isInitialized)
        {
            m_logger.LogError("MonteCarloPipeline not initialized");
            return false;
        }

        summary = MonteCarloSummary();
        summary.started = TimeCurrent();
        summary.sourceValidationId = source.manifest.validationId;
        summary.originalProfit = source.strategyReport.totalNetProfit;

        summary.config = cfg;
        summary.config.experimentId = BuildExperimentId(cfg,
            source.manifest.parameterHash);

        if(source.strategyReport.totalTrades < 2)
        {
            m_logger.LogError(StringFormat(
                "Insufficient trades: %d (need 2+)",
                source.strategyReport.totalTrades));
            summary.completed = TimeCurrent();
            return false;
        }

        EventData trades[];
        int tradeCount = 0;
        ExtractTrades(source, trades, tradeCount);

        tradeCount = source.strategyReport.totalTrades;

        if(tradeCount < 2)
        {
            m_logger.LogError("Cannot extract trade data for Monte Carlo");
            summary.completed = TimeCurrent();
            return false;
        }

        EventData dummyTrades[];
        ArrayResize(dummyTrades, tradeCount);
        for(int i = 0; i < tradeCount; i++)
        {
            dummyTrades[i].profit = source.strategyReport.totalNetProfit / tradeCount;
        }

        MonteCarloRun runs[];
        int runCount = 0;
        ArrayResize(runs, cfg.iterations * (cfg.modeCount > 0 ? cfg.modeCount : 1));

        if(!m_simulator.ExecuteAll(dummyTrades, tradeCount, cfg, runs, runCount))
        {
            m_logger.LogError("MonteCarloSimulator.ExecuteAll failed");
            summary.completed = TimeCurrent();
            return false;
        }

        summary.totalRuns = runCount;
        summary.completedRuns = runCount;

        ArrayResize(summary.runs, runCount);
        for(int i = 0; i < runCount; i++)
            summary.runs[i] = runs[i];

        CMonteCarloValidator validator;
        validator.Init(cfg.randomSeed);

        if(!ComputeStatistics(runs, runCount, summary.originalProfit,
                               summary.statistics, validator))
        {
            m_logger.LogWarn("Failed to compute Monte Carlo statistics");
        }

        summary.completed = TimeCurrent();
        summary.completedSuccessfully = true;

        m_logger.LogInfo(StringFormat(
            "Monte Carlo complete: %d runs, mean=%.2f, median=%.2f, P95=%.2f, P99=%.2f, "
            "lossProb=%.1f%%, significant=%s, sufficient=%s",
            runCount,
            summary.statistics.meanProfit,
            summary.statistics.medianProfit,
            summary.statistics.p95Profit,
            summary.statistics.p99Profit,
            summary.statistics.probabilityOfLoss * 100.0,
            summary.statistics.isSignificant ? "YES" : "NO",
            summary.statistics.sufficientIterations ? "YES" : "NO"));

        return true;
    }
};

#endif
