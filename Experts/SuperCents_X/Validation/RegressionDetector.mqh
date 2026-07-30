#ifndef __REGRESSION_DETECTOR_MQH__
#define __REGRESSION_DETECTOR_MQH__

#include "../Core/Logger.mqh"
#include "RegressionTypes.mqh"

#define MAX_REGRESSION_FINDINGS 50

class CRegressionDetector
{
private:
    CLogger          m_logger;
    bool             m_isInitialized;
    RegressionConfig m_config;

    string DimensionLabel(ENUM_REGRESSION_DIMENSION dim) const
    {
        switch(dim)
        {
            case REG_DIM_PROFIT_FACTOR:     return "profitFactor";
            case REG_DIM_SHARPE_RATIO:      return "sharpeRatio";
            case REG_DIM_SORTINO_RATIO:     return "sortinoRatio";
            case REG_DIM_CALMAR_RATIO:      return "calmarRatio";
            case REG_DIM_NET_PROFIT:        return "totalNetProfit";
            case REG_DIM_MAX_DRAWDOWN:      return "maxDrawdownPercent";
            case REG_DIM_WIN_RATE:          return "winRate";
            case REG_DIM_EXPECTANCY:        return "expectancy";
            case REG_DIM_TOTAL_TRADES:      return "totalTrades";
            case REG_DIM_AVG_RR:            return "avgRR";
            case REG_DIM_RECOVERY_FACTOR:   return "recoveryFactor";
        }
        return "unknown";
    }

    bool ExtractMetric(const ValidationResult &src,
                        ENUM_REGRESSION_DIMENSION dim,
                        double &value) const
    {
        StrategyReport r = src.strategyReport;
        switch(dim)
        {
            case REG_DIM_PROFIT_FACTOR:     value = r.profitFactor;        return true;
            case REG_DIM_SHARPE_RATIO:      value = r.sharpeRatio;         return true;
            case REG_DIM_SORTINO_RATIO:     value = r.sortinoRatio;        return true;
            case REG_DIM_CALMAR_RATIO:      value = r.calmarRatio;         return true;
            case REG_DIM_NET_PROFIT:        value = r.totalNetProfit;      return true;
            case REG_DIM_MAX_DRAWDOWN:      value = r.maxDrawdownPercent;  return true;
            case REG_DIM_WIN_RATE:          value = r.winRate;             return true;
            case REG_DIM_EXPECTANCY:        value = r.expectancy;          return true;
            case REG_DIM_TOTAL_TRADES:      value = (double)r.totalTrades; return true;
            case REG_DIM_AVG_RR:            value = r.avgRRAchieved;       return true;
            case REG_DIM_RECOVERY_FACTOR:   value = r.recoveryFactor;      return true;
        }
        return false;
    }

    bool EvaluateMetric(const MetricPair &pair,
                         const RegressionThreshold &threshold,
                         RegressionFinding &finding) const
    {
        finding = RegressionFinding();
        finding.dimension = pair.dimension;
        finding.baselineValue = pair.baseline;
        finding.currentValue = pair.current;
        finding.dimensionLabel = DimensionLabel(pair.dimension);
        finding.warnThreshold = threshold.warnPercent;
        finding.failThreshold = threshold.failPercent;

        double baseline = pair.baseline;
        double current = pair.current;
        finding.delta = current - baseline;

        if(baseline == 0.0 && current == 0.0)
        {
            finding.status = REGRESSION_PASS;
            finding.direction = CHANGE_UNCHANGED;
            finding.pctChangeDefined = false;
            finding.message = "Baseline and current are both zero; no change detected";
            return true;
        }

        if(baseline == 0.0)
        {
            finding.status = REGRESSION_INSUFFICIENT_DATA;
            finding.direction = CHANGE_UNCHANGED;
            finding.pctChangeDefined = false;
            finding.message = "Baseline is zero; percentage change undefined";
            return true;
        }

        finding.pctChangeDefined = true;
        finding.deltaPercent = (finding.delta / MathAbs(baseline)) * 100.0;

        if(MathAbs(finding.deltaPercent) <= REGRESSION_EPSILON_PERCENT)
        {
            finding.direction = CHANGE_UNCHANGED;
            finding.status = REGRESSION_PASS;
            finding.message = StringFormat("No material change: %.2f%%", finding.deltaPercent);
            return true;
        }

        bool isDegradation;
        if(threshold.higherIsBetter)
            isDegradation = (finding.deltaPercent < 0.0);
        else
            isDegradation = (finding.deltaPercent > 0.0);

        finding.direction = isDegradation ? CHANGE_DEGRADED : CHANGE_IMPROVED;

        double absDelta = MathAbs(finding.deltaPercent);

        if(absDelta >= threshold.failPercent)
        {
            finding.status = REGRESSION_FAIL;
            if(isDegradation)
                finding.message = StringFormat("Failed: degraded by %.2f%% (threshold: %.1f%%)",
                    absDelta, threshold.failPercent);
            else
                finding.message = StringFormat("Failed: improved by %.2f%% (threshold: %.1f%%)",
                    absDelta, threshold.failPercent);
        }
        else if(absDelta >= threshold.warnPercent)
        {
            finding.status = REGRESSION_WARN;
            if(isDegradation)
                finding.message = StringFormat("Warning: degraded by %.2f%% (threshold: %.1f%%)",
                    absDelta, threshold.warnPercent);
            else
                finding.message = StringFormat("Warning: improved by %.2f%% (threshold: %.1f%%)",
                    absDelta, threshold.warnPercent);
        }
        else
        {
            finding.status = REGRESSION_PASS;
            finding.message = StringFormat("Pass: %.2f%% change within thresholds", absDelta);
        }

        return true;
    }

public:
    CRegressionDetector(void)
        : m_logger(MODULE_LABORATORY, "RegressionDetector")
        , m_isInitialized(false)
    {}

    ~CRegressionDetector(void)
    {
        Shutdown();
    }

    bool Init(const RegressionConfig &cfg)
    {
        m_config = cfg;
        ArrayResize(m_config.thresholds, m_config.thresholdCount);
        m_isInitialized = true;
        m_logger.LogInfo(StringFormat("RegressionDetector initialized: %d thresholds, v%d",
            m_config.thresholdCount, m_config.configVersion));
        return true;
    }

    void Shutdown(void)
    {
        m_isInitialized = false;
    }

    bool IsInitialized(void) const { return m_isInitialized; }

    bool Execute(const ValidationResult &baseline,
                 const ValidationResult &current,
                 RegressionSummary &out)
    {
        if(!m_isInitialized)
        {
            m_logger.LogError("RegressionDetector not initialized");
            return false;
        }

        out = RegressionSummary();
        out.baselineValidationId = baseline.manifest.validationId;
        out.currentValidationId = current.manifest.validationId;
        out.config = m_config;
        out.compared = TimeCurrent();

        int maxFindings = m_config.thresholdCount;
        if(maxFindings > MAX_REGRESSION_FINDINGS)
            maxFindings = MAX_REGRESSION_FINDINGS;

        ArrayResize(out.findings, maxFindings);

        for(int i = 0; i < maxFindings; i++)
        {
            RegressionThreshold t = m_config.thresholds[i];

            double baseVal = 0.0, currVal = 0.0;
            bool baseOk = ExtractMetric(baseline, t.dimension, baseVal);
            bool currOk = ExtractMetric(current, t.dimension, currVal);

            if(!baseOk || !currOk)
            {
                RegressionFinding f;
                f.dimension = t.dimension;
                f.dimensionLabel = DimensionLabel(t.dimension);
                f.status = REGRESSION_INSUFFICIENT_DATA;
                f.baselineValue = baseOk ? baseVal : 0.0;
                f.currentValue = currOk ? currVal : 0.0;
                f.message = "Could not extract metric from ValidationResult";
                out.findings[i] = f;
                out.insufficientChecks++;
                continue;
            }

            MetricPair pair;
            pair.dimension = t.dimension;
            pair.baseline = baseVal;
            pair.current = currVal;
            pair.higherIsBetter = t.higherIsBetter;

            EvaluateMetric(pair, t, out.findings[i]);

            RegressionFinding f = out.findings[i];
            if(f.status == REGRESSION_PASS)
                out.passedChecks++;
            else if(f.status == REGRESSION_WARN)
                out.warnedChecks++;
            else if(f.status == REGRESSION_FAIL)
                out.failedChecks++;
            else if(f.status == REGRESSION_INSUFFICIENT_DATA)
                out.insufficientChecks++;
        }

        out.totalChecks = maxFindings;
        out.completedSuccessfully = true;

        m_logger.LogInfo(StringFormat(
            "Regression complete: %d checks, %d pass, %d warn, %d fail, %d insufficient",
            out.totalChecks, out.passedChecks, out.warnedChecks,
            out.failedChecks, out.insufficientChecks));

        return true;
    }
};

#endif
