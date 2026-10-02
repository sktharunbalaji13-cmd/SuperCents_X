#ifndef __RESEARCH_ENHANCED_RESEARCH_REPORT_MQH__
#define __RESEARCH_ENHANCED_RESEARCH_REPORT_MQH__

#include "../Core/Logger.mqh"
#include "ResearchEvidence.mqh"
#include "BenchmarkFramework.mqh"
#include "RobustnessProfiler.mqh"
#include "StatisticalValidator.mqh"
#include "ConfidenceCalibrator.mqh"

#define MAX_REPORT_LINES 4096

class CEnhancedResearchReport
{
private:
    CLogger m_logger;
    bool    m_isInitialized;

    string m_lines[MAX_REPORT_LINES];
    int    m_lineCount;

    bool Write(const string line);

public:
    CEnhancedResearchReport(void);
    ~CEnhancedResearchReport(void);

    bool Init(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    bool AddBenchmarkSection(const BenchmarkResult results[], int count);
    bool AddRobustnessSection(const RobustnessProfile &profile);
    bool AddCalibrationSection(const ConfidenceCalibrationReport &report);
    bool AddStatisticalSummary(const double data[], int count,
                                const string metricName);

    bool Save(const string filepath);
    bool GetContent(string &out) const;

    void Clear(void);
};

CEnhancedResearchReport::CEnhancedResearchReport(void)
    : m_logger(MODULE_LABORATORY, "EnhancedResearchReport")
    , m_isInitialized(false)
    , m_lineCount(0)
{
}

CEnhancedResearchReport::~CEnhancedResearchReport(void)
{
    Shutdown();
}

bool CEnhancedResearchReport::Init(void)
{
    m_logger.LogInfo("Initializing EnhancedResearchReport...");
    m_lineCount = 0;
    m_isInitialized = true;

    Write("========================================");
    Write("ENHANCED RESEARCH REPORT");
    Write("Capability Release 2.4 — Research Platform");
    Write("========================================");
    Write("");

    return true;
}

void CEnhancedResearchReport::Shutdown(void)
{
    Clear();
    m_isInitialized = false;
}

bool CEnhancedResearchReport::Write(const string line)
{
    if(m_lineCount >= MAX_REPORT_LINES) return false;
    m_lines[m_lineCount] = line;
    m_lineCount++;
    return true;
}

bool CEnhancedResearchReport::AddBenchmarkSection(const BenchmarkResult results[],
                                                    int count)
{
    Write("----------------------------------------");
    Write("BENCHMARK COMPARISONS");
    Write("----------------------------------------");

    for(int i = 0; i < count; i++)
    {
        string typeStr = "";
        switch(results[i].benchmarkType)
        {
            case BENCHMARK_BASELINE: typeStr = "BASELINE"; break;
            case BENCHMARK_PREVIOUS_VERSION: typeStr = "PREVIOUS VERSION"; break;
            case BENCHMARK_PARAMETER_VARIANT: typeStr = "PARAMETER VARIANT"; break;
            case BENCHMARK_MARKET_REGIME: typeStr = "MARKET REGIME"; break;
        }

        Write(StringFormat("  [%d] %s (%s)", i + 1, results[i].strategyId, typeStr));
        Write(StringFormat("       Score: %.4f  vs  Reference: %.4f",
                           results[i].strategyScore, results[i].referenceScore));
        Write(StringFormat("       Delta: %+.4f  (%+.2f%%)",
                           results[i].delta, results[i].deltaPercent));

        for(int j = 0; j < results[i].evidenceCount; j++)
            Write(StringFormat("       Evidence: %s = %.4f (%s)",
                               results[i].evidence[j].dimension,
                               results[i].evidence[j].value,
                               results[i].evidence[j].rationale));
        Write("");
    }

    return true;
}

bool CEnhancedResearchReport::AddRobustnessSection(const RobustnessProfile &profile)
{
    Write("----------------------------------------");
    Write("ROBUSTNESS PROFILE");
    Write("----------------------------------------");
    Write(StringFormat("  Strategy: %s", profile.strategyId));
    Write(StringFormat("  Overall Robustness  : %.2f / 100", profile.overallRobustnessScore));
    Write(StringFormat("  Regime Stability    : %.2f", profile.regimeStability));
    Write(StringFormat("  Volatility Sens.    : %.2f", profile.volatilitySensitivity));
    Write(StringFormat("  Parameter Sens.     : %.2f", profile.parameterSensitivity));
    Write(StringFormat("  Temporal Consist.   : %.2f", profile.temporalConsistency));
    Write(StringFormat("  Trade Distrib.      : %.2f", profile.tradeDistributionStability));

    for(int i = 0; i < profile.evidenceCount; i++)
        Write(StringFormat("  Evidence: %s = %.4f (%s) [%s]",
                           profile.evidence[i].dimension,
                           profile.evidence[i].value,
                           profile.evidence[i].rationale,
                           profile.evidence[i].methodRef));
    Write("");

    return true;
}

bool CEnhancedResearchReport::AddCalibrationSection(const ConfidenceCalibrationReport &report)
{
    Write("----------------------------------------");
    Write("CONFIDENCE CALIBRATION");
    Write("----------------------------------------");
    Write(StringFormat("  Strategy     : %s", report.strategyId));

    string statusStr = "";
    switch(report.status)
    {
        case CALIBRATION_OVERCONFIDENT: statusStr = "OVERCONFIDENT"; break;
        case CALIBRATION_ACCURATE: statusStr = "ACCURATE"; break;
        case CALIBRATION_UNDERCONFIDENT: statusStr = "UNDERCONFIDENT"; break;
        default: statusStr = "INSUFFICIENT DATA"; break;
    }
    Write(StringFormat("  Status       : %s", statusStr));
    Write(StringFormat("  Correlation  : %.4f", report.correlation));
    Write(StringFormat("  Slope        : %.4f", report.calibrationSlope));
    Write("");
    Write("  Tier  Confidence  WinRate  Trades");
    Write("  -----------------------------------");

    for(int i = 0; i < 5; i++)
    {
        int lo = i * 20;
        int hi = (i + 1) * 20 - 1;
        Write(StringFormat("  %s  %6.1f     %6.2f%%  %6d",
                           StringFormat("%3d-%3d", lo, hi),
                           report.confidenceByTier[i],
                           report.winRateByTier[i] * 100.0,
                           report.tradesByTier[i]));
    }

    Write("");
    return true;
}

bool CEnhancedResearchReport::AddStatisticalSummary(const double data[], int count,
                                                      const string metricName)
{
    CStatisticalValidator validator;

    ResearchEvidence evidence[32];
    int evidenceCount = 0;

    if(!validator.Summarize(data, count, metricName, evidence, evidenceCount))
        return false;

    Write("----------------------------------------");
    Write(StringFormat("STATISTICAL SUMMARY: %s", metricName));
    Write("----------------------------------------");

    for(int i = 0; i < evidenceCount; i++)
        Write(StringFormat("  %s = %.4f (%s) [%s]",
                           evidence[i].dimension,
                           evidence[i].value,
                           evidence[i].rationale,
                           evidence[i].methodRef));
    Write("");

    return true;
}

bool CEnhancedResearchReport::Save(const string filepath)
{
    int handle = FileOpen(filepath, FILE_WRITE | FILE_TXT | FILE_COMMON);
    if(handle == INVALID_HANDLE) return false;

    for(int i = 0; i < m_lineCount; i++)
        FileWrite(handle, m_lines[i]);

    FileClose(handle);
    Write(StringFormat("Report saved: %s (%d lines)", filepath, m_lineCount));
    return true;
}

bool CEnhancedResearchReport::GetContent(string &out) const
{
    out = "";
    for(int i = 0; i < m_lineCount; i++)
        out += m_lines[i] + "\n";
    return true;
}

void CEnhancedResearchReport::Clear(void)
{
    m_lineCount = 0;
}

#endif
