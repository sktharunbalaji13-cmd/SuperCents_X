#ifndef __OPTIMIZATION_WALK_FORWARD_RUNNER_MQH__
#define __OPTIMIZATION_WALK_FORWARD_RUNNER_MQH__

#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "OptimizationTypes.mqh"
#include "ExperimentManifest.mqh"
#include "StrategyAnalytics.mqh"

#define MAX_WALK_FORWARD_WINDOWS 50

class CWalkForwardRunner
{
private:
    CLogger     m_logger;
    bool        m_isInitialized;

    WindowConfiguration    m_config;
    WalkForwardWindow      m_windows[MAX_WALK_FORWARD_WINDOWS];
    int                    m_windowCount;

public:
    CWalkForwardRunner(void);
    ~CWalkForwardRunner(void);

    bool Init(const WindowConfiguration &config);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    bool GenerateWindows(int totalBars);
    int GetWindowCount(void) const { return m_windowCount; }
    bool GetWindow(int index, WalkForwardWindow &out) const;

    bool RunWindow(const WalkForwardWindow &window,
                   const ParameterSet &params,
                   const ExperimentManifest &manifest,
                   CStrategyAnalytics &analytics,
                   StrategyReport &outReport);

    bool RunAll(const ParameterSet &params,
                const ExperimentManifest &manifest,
                CStrategyAnalytics &analytics,
                StrategyReport &results[]);
};

CWalkForwardRunner::CWalkForwardRunner(void)
    : m_logger(MODULE_UNKNOWN, "WalkForwardRunner")
    , m_isInitialized(false)
    , m_windowCount(0)
{
}

CWalkForwardRunner::~CWalkForwardRunner(void)
{
    Shutdown();
}

bool CWalkForwardRunner::Init(const WindowConfiguration &config)
{
    m_logger.LogInfo("Initializing WalkForwardRunner...");
    m_config = config;
    m_windowCount = 0;
    m_isInitialized = true;
    m_logger.LogInfo("WalkForwardRunner initialized");
    return true;
}

void CWalkForwardRunner::Shutdown(void)
{
    if(!m_isInitialized) return;
    m_windowCount = 0;
    m_isInitialized = false;
}

bool CWalkForwardRunner::GenerateWindows(int totalBars)
{
    if(!m_isInitialized)
        return false;

    m_windowCount = 0;

    if(totalBars <= 0)
        return false;

    double trainPct = (m_config.trainPercent > 0.0) ? m_config.trainPercent : 0.70;
    int windowSize = (int)(totalBars * 0.5);
    int stepSize = (int)(windowSize * 0.5);

    if(windowSize < m_config.minTrainBars + m_config.minTestBars)
        windowSize = m_config.minTrainBars + m_config.minTestBars;
    if(stepSize < 1) stepSize = 1;

    int pos = 0;
    while(pos + windowSize <= totalBars && m_windowCount < MAX_WALK_FORWARD_WINDOWS)
    {
        int trainEnd = pos + (int)(windowSize * trainPct);
        int testEnd = pos + windowSize;

        if(trainEnd - pos < m_config.minTrainBars || testEnd - trainEnd < m_config.minTestBars)
        {
            pos += stepSize;
            continue;
        }

        WalkForwardWindow w;
        w.windowIndex = m_windowCount;
        w.trainStart = 0;
        w.trainEnd = 0;
        w.testStart = 0;
        w.testEnd = 0;
        w.trainBars = trainEnd - pos;
        w.testBars = testEnd - trainEnd;

        m_windows[m_windowCount] = w;
        m_windowCount++;
        pos += stepSize;
    }

    m_logger.LogInfo(StringFormat("Generated %d walk-forward windows from %d bars",
                                  m_windowCount, totalBars));
    return (m_windowCount > 0);
}

bool CWalkForwardRunner::GetWindow(int index, WalkForwardWindow &out) const
{
    if(index < 0 || index >= m_windowCount)
        return false;
    out = m_windows[index];
    return true;
}

bool CWalkForwardRunner::RunWindow(const WalkForwardWindow &window,
                                    const ParameterSet &params,
                                    const ExperimentManifest &manifest,
                                    CStrategyAnalytics &analytics,
                                    StrategyReport &outReport)
{
    if(!m_isInitialized)
        return false;

    analytics.Reset();

    string label = StringFormat("WF-%d Train=%d Test=%d",
                                window.windowIndex, window.trainBars, window.testBars);

    analytics.GenerateReport(manifest, label, outReport);

    m_logger.LogInfo(StringFormat("Walk-forward window %d complete: %s",
                                  window.windowIndex, label));
    return true;
}

bool CWalkForwardRunner::RunAll(const ParameterSet &params,
                                 const ExperimentManifest &manifest,
                                 CStrategyAnalytics &analytics,
                                 StrategyReport &results[])
{
    if(!m_isInitialized || m_windowCount == 0)
        return false;

    for(int i = 0; i < m_windowCount; i++)
    {
        if(!RunWindow(m_windows[i], params, manifest, analytics, results[i]))
            return false;
    }

    m_logger.LogInfo(StringFormat("All %d walk-forward windows completed", m_windowCount));
    return true;
}

#endif
