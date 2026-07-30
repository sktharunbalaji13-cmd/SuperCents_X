#ifndef __OPTIMIZATION_OPTIMIZATION_TYPES_MQH__
#define __OPTIMIZATION_OPTIMIZATION_TYPES_MQH__

#include "../Utils/Constants.mqh"
#include "../Monitoring/MonitoringTypes.mqh"

struct StructureParameters
{
    int     swingStrength;
    int     swingLookbackBars;
    int     bosLookbackBars;
    int     chochLookbackBars;
    double  fvgMinBodySizePips;
    double  liquidityEqhTolerancePips;
    double  liquidityEqlTolerancePips;

    StructureParameters(void)
        : swingStrength(2)
        , swingLookbackBars(2)
        , bosLookbackBars(2)
        , chochLookbackBars(1)
        , fvgMinBodySizePips(5.0)
        , liquidityEqhTolerancePips(3.0)
        , liquidityEqlTolerancePips(3.0)
    {}
};

struct ConfluenceParameters
{
    double  confluenceThreshold;
    double  weightTrend;
    double  weightStructure;
    double  weightMomentum;
    double  weightLiquidity;

    ConfluenceParameters(void)
        : confluenceThreshold(3.0)
        , weightTrend(1.0)
        , weightStructure(1.0)
        , weightMomentum(1.0)
        , weightLiquidity(1.0)
    {}
};

struct RiskParameters
{
    double  maxRiskPerTradePercent;
    double  maxDailyRiskPercent;
    double  maxPositionSizePercent;
    double  stopBufferPips;
    double  minStopDistancePips;

    RiskParameters(void)
        : maxRiskPerTradePercent(2.0)
        , maxDailyRiskPercent(10.0)
        , maxPositionSizePercent(5.0)
        , stopBufferPips(3.0)
        , minStopDistancePips(10.0)
    {}
};

struct PortfolioParameters
{
    double  maxPortfolioRiskPercent;
    int     maxConcurrentPositions;
    double  maxCorrelationThreshold;
    double  maxSymbolConcentrationPercent;
    double  maxCapitalUtilizationPercent;
    double  maxDailyLossPercent;

    PortfolioParameters(void)
        : maxPortfolioRiskPercent(10.0)
        , maxConcurrentPositions(10)
        , maxCorrelationThreshold(0.7)
        , maxSymbolConcentrationPercent(30.0)
        , maxCapitalUtilizationPercent(80.0)
        , maxDailyLossPercent(-5.0)
    {}
};

struct OptimizationParameters
{
    int     walkForwardMinTrainBars;
    int     walkForwardMinTestBars;
    double  walkForwardTrainPercent;
    int     monteCarloIterations;
    double  monteCarloConfidenceLevel;
    double  robustnessPerturbationPercent;

    OptimizationParameters(void)
        : walkForwardMinTrainBars(500)
        , walkForwardMinTestBars(200)
        , walkForwardTrainPercent(0.70)
        , monteCarloIterations(1000)
        , monteCarloConfidenceLevel(0.95)
        , robustnessPerturbationPercent(10.0)
    {}
};

struct ParameterSet
{
    string                  id;
    string                  label;
    StructureParameters     structure;
    ConfluenceParameters    confluence;
    RiskParameters          risk;
    PortfolioParameters     portfolio;
    OptimizationParameters  optimization;

    ParameterSet(void)
        : id("")
        , label("")
    {}
};

struct WindowConfiguration
{
    int     totalBars;
    double  trainPercent;
    int     minTrainBars;
    int     minTestBars;

    WindowConfiguration(void)
        : totalBars(0)
        , trainPercent(0.70)
        , minTrainBars(500)
        , minTestBars(200)
    {}
};

struct WalkForwardWindow
{
    int         windowIndex;
    datetime    trainStart;
    datetime    trainEnd;
    datetime    testStart;
    datetime    testEnd;
    int         trainBars;
    int         testBars;

    WalkForwardWindow(void)
        : windowIndex(0)
        , trainStart(0)
        , trainEnd(0)
        , testStart(0)
        , testEnd(0)
        , trainBars(0)
        , testBars(0)
    {}
};

struct SensitivityResult
{
    string              parameter;
    double              baselineValue;
    double              perturbedValue;
    double              profitChangePercent;
    double              metricScore;
    ENUM_METRIC_ORIGIN  origin;

    SensitivityResult(void)
        : parameter("")
        , baselineValue(0.0)
        , perturbedValue(0.0)
        , profitChangePercent(0.0)
        , metricScore(0.0)
        , origin(ORIGIN_ESTIMATED)
    {}
};

struct StrategyReport
{
    string  experimentId;
    string  parameterSetId;
    string  platformVersion;
    string  windowLabel;

    double  totalNetProfit;
    double  grossProfit;
    double  grossLoss;
    int     totalTrades;
    int     winningTrades;
    int     losingTrades;
    double  winRate;

    double  expectancy;
    double  profitFactor;
    double  sharpeRatio;
    double  sortinoRatio;
    double  calmarRatio;
    double  recoveryFactor;

    double  maxDrawdownPercent;
    double  maxDrawdownValue;
    double  avgDrawdownPercent;

    double  avgHoldingTimeSeconds;
    double  avgRRAchieved;
    double  avgStopPips;
    double  avgTargetPips;

    double  avgExposurePercent;
    double  maxExposurePercent;
    double  avgMarginUtilization;

    string  symbolContributions;   // semicolon-delimited "SYM:PF:WR:CNT"

    double  monteCarloConfidence95;
    double  spreadSensitivitySlope;
    double  slippageSensitivitySlope;

    StrategyReport(void)
        : experimentId("")
        , parameterSetId("")
        , platformVersion("")
        , windowLabel("")
        , totalNetProfit(0.0)
        , grossProfit(0.0)
        , grossLoss(0.0)
        , totalTrades(0)
        , winningTrades(0)
        , losingTrades(0)
        , winRate(0.0)
        , expectancy(0.0)
        , profitFactor(0.0)
        , sharpeRatio(0.0)
        , sortinoRatio(0.0)
        , calmarRatio(0.0)
        , recoveryFactor(0.0)
        , maxDrawdownPercent(0.0)
        , maxDrawdownValue(0.0)
        , avgDrawdownPercent(0.0)
        , avgHoldingTimeSeconds(0.0)
        , avgRRAchieved(0.0)
        , avgStopPips(0.0)
        , avgTargetPips(0.0)
        , avgExposurePercent(0.0)
        , maxExposurePercent(0.0)
        , avgMarginUtilization(0.0)
        , symbolContributions("")
        , monteCarloConfidence95(0.0)
        , spreadSensitivitySlope(0.0)
        , slippageSensitivitySlope(0.0)
    {}
};

#endif
