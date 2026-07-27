#ifndef __RESEARCH_CONFIDENCE_CALIBRATOR_MQH__
#define __RESEARCH_CONFIDENCE_CALIBRATOR_MQH__

#include "../Core/Logger.mqh"
#include "../Optimization/OptimizationTypes.mqh"
#include "../Trading/TradingEvidence.mqh"
#include "ResearchEvidence.mqh"

#define MAX_CALIBRATION_TRADES 1024

class CConfidenceCalibrator
{
private:
    CLogger m_logger;
    bool    m_isInitialized;

public:
    CConfidenceCalibrator(void);
    ~CConfidenceCalibrator(void);

    bool Init(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    ConfidenceCalibrationReport Evaluate(const EntryConfidence &confidences[],
                                          const bool tradeResults[],
                                          int count) const;

private:
    ENUM_CALIBRATION_STATUS DetermineStatus(double correlation,
                                             int tradeCount) const;
};

CConfidenceCalibrator::CConfidenceCalibrator(void)
    : m_logger(MODULE_LABORATORY, "ConfidenceCalibrator")
    , m_isInitialized(false)
{
}

CConfidenceCalibrator::~CConfidenceCalibrator(void)
{
    Shutdown();
}

bool CConfidenceCalibrator::Init(void)
{
    m_logger.LogInfo("Initializing ConfidenceCalibrator...");
    m_isInitialized = true;
    return true;
}

void CConfidenceCalibrator::Shutdown(void)
{
    m_isInitialized = false;
}

ConfidenceCalibrationReport CConfidenceCalibrator::Evaluate(
    const EntryConfidence &confidences[],
    const bool tradeResults[],
    int count) const
{
    ConfidenceCalibrationReport report;
    if(count <= 0) return report;

    report.strategyId = "calibration_analysis";

    for(int i = 0; i < 5; i++)
        report.tradesByTier[i] = 0;

    double sumConf = 0, sumResult = 0, sumConfSq = 0, sumResultSq = 0, sumCR = 0;
    int validTrades = 0;

    for(int i = 0; i < count && i < MAX_CALIBRATION_TRADES; i++)
    {
        double c = confidences[i].overallScore;
        double r = tradeResults[i] ? 1.0 : 0.0;

        int tier = (int)(c / 20);
        if(tier < 0) tier = 0;
        if(tier > 4) tier = 4;

        report.tradesByTier[tier]++;
        report.confidenceByTier[tier] += c;
        report.winRateByTier[tier] += r;

        if(c > 0)
        {
            sumConf += c;
            sumResult += r;
            sumConfSq += c * c;
            sumResultSq += r * r;
            sumCR += c * r;
            validTrades++;
        }
    }

    for(int i = 0; i < 5; i++)
    {
        if(report.tradesByTier[i] > 0)
        {
            report.confidenceByTier[i] /= report.tradesByTier[i];
            report.winRateByTier[i] /= report.tradesByTier[i];
        }
    }

    if(validTrades > 1)
    {
        double numerator = validTrades * sumCR - sumConf * sumResult;
        double denom = MathSqrt((validTrades * sumConfSq - sumConf * sumConf)
                               * (validTrades * sumResultSq - sumResult * sumResult));
        report.correlation = (denom != 0) ? numerator / denom : 0;
    }

    report.calibrationSlope = (report.confidenceByTier[4] - report.confidenceByTier[0] > 0)
        ? (report.winRateByTier[4] - report.winRateByTier[0])
          / ((report.confidenceByTier[4] - report.confidenceByTier[0]) / 100.0)
        : 0;

    report.status = DetermineStatus(report.correlation, validTrades);

    int e = 0;
    report.evidence[e].source = "ConfidenceCalibrator";
    report.evidence[e].dimension = "correlation";
    report.evidence[e].value = report.correlation;
    report.evidence[e].rationale = "Correlation between confidence and trade outcome";
    report.evidence[e].methodRef = "Pearson correlation";
    e++;

    report.evidence[e].source = "ConfidenceCalibrator";
    report.evidence[e].dimension = "calibrationSlope";
    report.evidence[e].value = report.calibrationSlope;
    report.evidence[e].rationale = "Slope of calibration curve";
    report.evidence[e].methodRef = "delta winRate / delta confidence, tier 0 to tier 4";
    e++;

    report.evidence[e].source = "ConfidenceCalibrator";
    report.evidence[e].dimension = "status";
    report.evidence[e].value = (double)report.status;
    report.evidence[e].rationale = "Calibration status classification";
    report.evidence[e].methodRef = "correlation-based tier classification";
    e++;

    report.evidenceCount = e;

    return report;
}

ENUM_CALIBRATION_STATUS CConfidenceCalibrator::DetermineStatus(double correlation,
                                                                 int tradeCount) const
{
    if(tradeCount < 10)
        return CALIBRATION_INSUFFICIENT_DATA;

    if(correlation > 0.3)
        return CALIBRATION_ACCURATE;

    if(correlation < -0.3)
        return CALIBRATION_OVERCONFIDENT;

    if(correlation < 0.1)
        return CALIBRATION_UNDERCONFIDENT;

    return CALIBRATION_ACCURATE;
}

#endif
