#ifndef __RESEARCH_RESEARCH_EVIDENCE_MQH__
#define __RESEARCH_RESEARCH_EVIDENCE_MQH__

#include "../Utils/Constants.mqh"
#include "../Optimization/OptimizationTypes.mqh"

enum ENUM_BENCHMARK_TYPE
{
    BENCHMARK_BASELINE = 0,
    BENCHMARK_PREVIOUS_VERSION,
    BENCHMARK_PARAMETER_VARIANT,
    BENCHMARK_MARKET_REGIME
};

enum ENUM_STABILITY_TIER
{
    STABILITY_VERY_WEAK = 0,
    STABILITY_WEAK,
    STABILITY_MODERATE,
    STABILITY_STRONG,
    STABILITY_EXCEPTIONAL
};

enum ENUM_CALIBRATION_STATUS
{
    CALIBRATION_OVERCONFIDENT = 0,
    CALIBRATION_ACCURATE,
    CALIBRATION_UNDERCONFIDENT,
    CALIBRATION_INSUFFICIENT_DATA
};

struct ResearchEvidence
{
    string   source;
    string   dimension;
    double   value;
    string   rationale;
    string   methodRef;

    ResearchEvidence(void)
        : source(""), dimension(""), value(0.0), rationale(""), methodRef("")
    {}
};

struct BenchmarkResult
{
    string               strategyId;
    ENUM_BENCHMARK_TYPE  benchmarkType;
    double               strategyScore;
    double               referenceScore;
    double               delta;
    double               deltaPercent;
    ResearchEvidence     evidence[16];
    int                  evidenceCount;

    BenchmarkResult(void)
        : strategyId(""), benchmarkType(BENCHMARK_BASELINE),
          strategyScore(0.0), referenceScore(0.0),
          delta(0.0), deltaPercent(0.0), evidenceCount(0)
    {}
};

struct RobustnessProfile
{
    string   strategyId;
    double   regimeStability;
    double   volatilitySensitivity;
    double   parameterSensitivity;
    double   temporalConsistency;
    double   tradeDistributionStability;
    double   overallRobustnessScore;
    ResearchEvidence evidence[32];
    int      evidenceCount;

    RobustnessProfile(void)
        : strategyId(""), regimeStability(0.0),
          volatilitySensitivity(0.0), parameterSensitivity(0.0),
          temporalConsistency(0.0), tradeDistributionStability(0.0),
          overallRobustnessScore(0.0), evidenceCount(0)
    {}
};

struct ConfidenceCalibrationReport
{
    string                  strategyId;
    double                  correlation;
    double                  calibrationSlope;
    double                  calibrationIntercept;
    double                  mse;
    ENUM_CALIBRATION_STATUS status;
    double                  confidenceByTier[5];
    double                  winRateByTier[5];
    int                     tradesByTier[5];
    ResearchEvidence        evidence[32];
    int                     evidenceCount;

    ConfidenceCalibrationReport(void)
        : strategyId(""), correlation(0.0),
          calibrationSlope(0.0), calibrationIntercept(0.0),
          mse(0.0), status(CALIBRATION_INSUFFICIENT_DATA),
          evidenceCount(0)
    {
        for(int i = 0; i < 5; i++)
        {
            confidenceByTier[i] = 0.0;
            winRateByTier[i] = 0.0;
            tradesByTier[i] = 0;
        }
    }
};

#endif
