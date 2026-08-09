#ifndef __RESEARCH_ROBUSTNESS_PROFILER_MQH__
#define __RESEARCH_ROBUSTNESS_PROFILER_MQH__

#include "../Core/Logger.mqh"
#include "../Optimization/OptimizationTypes.mqh"
#include "ResearchEvidence.mqh"

class CRobustnessProfiler
{
private:
    CLogger m_logger;
    bool    m_isInitialized;

    double ComputeMean(const double &data[], int count) const
    {
        if(count <= 0) return 0.0;
        double sum = 0.0;
        for(int i = 0; i < count; i++)
            sum += data[i];
        return sum / count;
    }

    double ComputeVariance(const double &data[], int count, double mean) const
    {
        if(count < 2) return 0.0;
        double sum = 0.0;
        for(int i = 0; i < count; i++)
            sum += (data[i] - mean) * (data[i] - mean);
        return sum / (count - 1);
    }

    double ComputeStdDev(const double &data[], int count, double mean) const
    {
        double var = ComputeVariance(data, count, mean);
        return (var > 0.0) ? MathSqrt(var) : 0.0;
    }

    double ComputePearsonCorrelation(const double &x[], const double &y[], int count) const
    {
        if(count < 3)
            return 0.0;

        double mx = ComputeMean(x, count);
        double my = ComputeMean(y, count);
        double sx = ComputeStdDev(x, count, mx);
        double sy = ComputeStdDev(y, count, my);

        if(sx == 0.0 || sy == 0.0)
            return 0.0;

        double cov = 0.0;
        for(int i = 0; i < count; i++)
            cov += (x[i] - mx) * (y[i] - my);
        cov /= (count - 1);

        double r = cov / (sx * sy);
        if(r > 1.0) r = 1.0;
        if(r < -1.0) r = -1.0;
        return r;
    }

    double ClampScore(double score) const
    {
        if(score < 0.0) return 0.0;
        if(score > 100.0) return 100.0;
        return score;
    }

    MetricResult ComputeRegimeStability(const StrategyReport &reports[], int count) const
    {
        if(count < 3)
            return MetricResult();

        double metrics[];
        ArrayResize(metrics, count);

        for(int i = 0; i < count; i++)
        {
            double pf = reports[i].profitFactor;
            if(pf > 0.0 && pf < 999.0)
                metrics[i] = pf;
            else if(reports[i].totalNetProfit > 0.0)
                metrics[i] = 2.0;
            else
                metrics[i] = 0.5;
        }

        double mean = ComputeMean(metrics, count);
        double cv = (mean != 0.0)
            ? ComputeStdDev(metrics, count, mean) / MathAbs(mean)
            : 1.0;

        return MetricResult(ClampScore(100.0 - (cv * 100.0)), ORIGIN_MEASURED);
    }

    MetricResult ComputeVolatilitySensitivity(const StrategyReport &reports[], int count) const
    {
        if(count < 5)
            return MetricResult();

        double ddValues[];
        double pfValues[];
        ArrayResize(ddValues, count);
        ArrayResize(pfValues, count);

        int validCount = 0;
        for(int i = 0; i < count; i++)
        {
            if(reports[i].maxDrawdownPercent > 0.0 && reports[i].profitFactor > 0.0)
            {
                ddValues[validCount] = reports[i].maxDrawdownPercent;
                pfValues[validCount] = MathMin(reports[i].profitFactor, 10.0);
                validCount++;
            }
        }

        if(validCount < 5)
            return MetricResult();

        double r = ComputePearsonCorrelation(ddValues, pfValues, validCount);

        return MetricResult(ClampScore((1.0 - MathAbs(r)) * 100.0), ORIGIN_MEASURED);
    }

    MetricResult ComputeParameterSensitivity(const StrategyReport &reports[], int count) const
    {
        if(count < 3)
            return MetricResult();

        double profits[];
        ArrayResize(profits, count);

        int validCount = 0;
        for(int i = 0; i < count; i++)
        {
            if(reports[i].totalTrades > 0)
            {
                profits[validCount] = reports[i].totalNetProfit;
                validCount++;
            }
        }

        if(validCount < 3)
            return MetricResult();

        double mean = ComputeMean(profits, validCount);
        if(mean == 0.0)
            return MetricResult();

        double cv = ComputeStdDev(profits, validCount, mean) / MathAbs(mean);

        return MetricResult(ClampScore(100.0 - (cv * 100.0)), ORIGIN_MEASURED);
    }

    MetricResult ComputeTemporalConsistency(const StrategyReport &reports[], int count) const
    {
        if(count < 4)
            return MetricResult();

        int validSharpe = 0;
        double sharpeValues[];
        ArrayResize(sharpeValues, count);

        for(int i = 0; i < count; i++)
        {
            if(reports[i].sharpeRatio != 0.0 || reports[i].totalTrades > 0)
            {
                sharpeValues[validSharpe] = reports[i].sharpeRatio;
                validSharpe++;
            }
        }

        if(validSharpe < 4)
            return MetricResult();

        int half = validSharpe / 2;
        double firstHalf = ComputeMean(sharpeValues, half);
        double secondHalf = ComputeMean(sharpeValues, validSharpe - half);

        double diff = MathAbs(firstHalf - secondHalf);

        return MetricResult(ClampScore(100.0 - (diff * 20.0)), ORIGIN_MEASURED);
    }

    MetricResult ComputeTradeDistributionStability(const StrategyReport &reports[], int count) const
    {
        if(count < 3)
            return MetricResult();

        double winRates[];
        ArrayResize(winRates, count);

        int validCount = 0;
        for(int i = 0; i < count; i++)
        {
            if(reports[i].totalTrades > 0)
            {
                winRates[validCount] = reports[i].winRate;
                validCount++;
            }
        }

        if(validCount < 3)
            return MetricResult();

        double mean = ComputeMean(winRates, validCount);
        double stddev = ComputeStdDev(winRates, validCount, mean);

        return MetricResult(ClampScore(100.0 - (stddev * 5.0)), ORIGIN_MEASURED);
    }

public:
    CRobustnessProfiler(void);
    ~CRobustnessProfiler(void);

    bool Init(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    RobustnessProfile Evaluate(const StrategyReport &reports[], int count) const;
    RobustnessProfile EvaluateAcrossWindows(const StrategyReport &windowReports[],
                                             int windowCount) const;
};

CRobustnessProfiler::CRobustnessProfiler(void)
    : m_logger(MODULE_LABORATORY, "RobustnessProfiler")
    , m_isInitialized(false)
{
}

CRobustnessProfiler::~CRobustnessProfiler(void)
{
    Shutdown();
}

bool CRobustnessProfiler::Init(void)
{
    m_logger.LogInfo("Initializing RobustnessProfiler...");
    m_isInitialized = true;
    return true;
}

void CRobustnessProfiler::Shutdown(void)
{
    m_isInitialized = false;
}

RobustnessProfile CRobustnessProfiler::Evaluate(const StrategyReport &reports[],
                                                  int count) const
{
    RobustnessProfile p;
    p.strategyId = (count > 0) ? reports[0].experimentId : "";
    int e = 0;

    p.regimeStability = ComputeRegimeStability(reports, count);
    p.evidence[e].source = "RobustnessProfiler";
    p.evidence[e].dimension = "regimeStability";
    p.evidence[e].value = p.regimeStability.valid ? p.regimeStability.value : -1.0;
    p.evidence[e].rationale = p.regimeStability.valid
        ? "Coefficient of variation of profit factor across reports"
        : "Insufficient data: need 3+ reports";
    p.evidence[e].methodRef = "CV of profit factor across regime segments";
    e++;

    p.volatilitySensitivity = ComputeVolatilitySensitivity(reports, count);
    p.evidence[e].source = "RobustnessProfiler";
    p.evidence[e].dimension = "volatilitySensitivity";
    p.evidence[e].value = p.volatilitySensitivity.valid ? p.volatilitySensitivity.value : -1.0;
    p.evidence[e].rationale = p.volatilitySensitivity.valid
        ? "Pearson correlation of drawdown vs profit factor across reports"
        : "Insufficient data: need 5+ reports with drawdown data";
    p.evidence[e].methodRef = "maxDrawdown vs profitFactor correlation";
    e++;

    p.parameterSensitivity = ComputeParameterSensitivity(reports, count);
    p.evidence[e].source = "RobustnessProfiler";
    p.evidence[e].dimension = "parameterSensitivity";
    p.evidence[e].value = p.parameterSensitivity.valid ? p.parameterSensitivity.value : -1.0;
    p.evidence[e].rationale = p.parameterSensitivity.valid
        ? "Coefficient of variation of net profit across parameter variants"
        : "Insufficient data: need 3+ reports with non-zero net profit";
    p.evidence[e].methodRef = "CV of totalNetProfit across parameter sets";
    e++;

    p.temporalConsistency = ComputeTemporalConsistency(reports, count);
    p.evidence[e].source = "RobustnessProfiler";
    p.evidence[e].dimension = "temporalConsistency";
    p.evidence[e].value = p.temporalConsistency.valid ? p.temporalConsistency.value : -1.0;
    p.evidence[e].rationale = p.temporalConsistency.valid
        ? "Absolute difference in mean Sharpe between first and second half of reports"
        : "Insufficient data: need 4+ reports with Sharpe data";
    p.evidence[e].methodRef = "first-half vs second-half Sharpe comparison";
    e++;

    p.tradeDistributionStability = ComputeTradeDistributionStability(reports, count);
    p.evidence[e].source = "RobustnessProfiler";
    p.evidence[e].dimension = "tradeDistributionStability";
    p.evidence[e].value = p.tradeDistributionStability.valid ? p.tradeDistributionStability.value : -1.0;
    p.evidence[e].rationale = p.tradeDistributionStability.valid
        ? "Standard deviation of win rate across reports"
        : "Insufficient data: need 3+ reports with trade data";
    p.evidence[e].methodRef = "win rate stddev across reports";
    e++;

    p.evidenceCount = e;
    p.hasSufficientData = (p.regimeStability.valid
                        || p.volatilitySensitivity.valid
                        || p.parameterSensitivity.valid
                        || p.temporalConsistency.valid
                        || p.tradeDistributionStability.valid);

    m_logger.LogInfo(StringFormat(
        "Robustness profile: RS=%.1f VS=%.1f PS=%.1f TC=%.1f TD=%.1f hasData=%s",
        p.regimeStability.valid ? p.regimeStability.value : -1.0,
        p.volatilitySensitivity.valid ? p.volatilitySensitivity.value : -1.0,
        p.parameterSensitivity.valid ? p.parameterSensitivity.value : -1.0,
        p.temporalConsistency.valid ? p.temporalConsistency.value : -1.0,
        p.tradeDistributionStability.valid ? p.tradeDistributionStability.value : -1.0,
        p.hasSufficientData ? "YES" : "NO"));

    return p;
}

RobustnessProfile CRobustnessProfiler::EvaluateAcrossWindows(
    const StrategyReport &windowReports[], int windowCount) const
{
    return Evaluate(windowReports, windowCount);
}

#endif
