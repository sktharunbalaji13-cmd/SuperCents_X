#ifndef __MONTE_CARLO_TYPES_MQH__
#define __MONTE_CARLO_TYPES_MQH__

#include "../Monitoring/MonitoringTypes.mqh"
#include "ValidationTypes.mqh"

// @frozen v2.7 -- Public API. Append values only.
enum ENUM_PERTURBATION_MODE
{
    PERTURB_TRADE_ORDER
};

// @frozen v2.7 -- Public API. Append values only.
enum ENUM_RANDOM_ENGINE
{
    RNG_MQL5_DEFAULT
};

struct MonteCarloConfig
{
    int                     configVersion;
    string                  experimentId;
    int                     iterations;
    int                     randomSeed;
    ENUM_PERTURBATION_MODE  modes[4];
    int                     modeCount;
    double                  confidenceLevel;
    string                  perturbationDescription;
    double                  perturbationMagnitude;

    MonteCarloConfig(void)
        : configVersion(1)
        , experimentId("")
        , iterations(1000)
        , randomSeed(12345)
        , modeCount(0)
        , confidenceLevel(0.95)
        , perturbationDescription("")
        , perturbationMagnitude(0.0)
    {
        for(int i = 0; i < 4; i++) modes[i] = PERTURB_TRADE_ORDER;
    }
};

struct MonteCarloRun
{
    ENUM_PERTURBATION_MODE  mode;
    ENUM_RANDOM_ENGINE      randomEngine;
    int                     iteration;
    int                     seed;
    double                  totalNetProfit;
    double                  totalGrossProfit;
    double                  totalGrossLoss;
    int                     totalTrades;
    int                     winningTrades;
    double                  winRate;

    MonteCarloRun(void)
        : mode(PERTURB_TRADE_ORDER)
        , randomEngine(RNG_MQL5_DEFAULT)
        , iteration(0)
        , seed(0)
        , totalNetProfit(0.0)
        , totalGrossProfit(0.0)
        , totalGrossLoss(0.0)
        , totalTrades(0)
        , winningTrades(0)
        , winRate(0.0)
    {}
};

struct MonteCarloStatistics
{
    double   meanProfit;
    double   medianProfit;
    double   stdDevProfit;
    double   p95Profit;
    double   p99Profit;
    double   probabilityOfLoss;
    bool     isSignificant;
    bool     sufficientIterations;
    int      usedIterations;

    MonteCarloStatistics(void)
        : meanProfit(0.0)
        , medianProfit(0.0)
        , stdDevProfit(0.0)
        , p95Profit(0.0)
        , p99Profit(0.0)
        , probabilityOfLoss(0.0)
        , isSignificant(false)
        , sufficientIterations(false)
        , usedIterations(0)
    {}
};

// @frozen v2.7 -- Public API contract. Append fields only.
struct MonteCarloSummary
{
    string               experimentLabel;
    string               sourceValidationId;
    MonteCarloConfig     config;
    MonteCarloRun        runs[];
    int                  totalRuns;
    int                  completedRuns;
    MonteCarloStatistics statistics;
    double               originalProfit;
    datetime             started;
    datetime             completed;
    bool                 completedSuccessfully;

    MonteCarloSummary(void)
        : experimentLabel("")
        , sourceValidationId("")
        , totalRuns(0)
        , completedRuns(0)
        , originalProfit(0.0)
        , started(0)
        , completed(0)
        , completedSuccessfully(false)
    {}
};

#endif
