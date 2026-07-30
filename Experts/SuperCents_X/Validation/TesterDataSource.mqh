#ifndef __TESTER_DATA_SOURCE_MQH__
#define __TESTER_DATA_SOURCE_MQH__

#include "../Core/Logger.mqh"
#include "../Monitoring/EventBusAdapter.mqh"
#include "../Monitoring/StatisticsReporter.mqh"
#include "IValidationDataSource.mqh"
#include "ValidationEventBus.mqh"
#include "BehavioralMetricsCollector.mqh"

class CTesterDataSource : public IValidationDataSource
{
private:
    CLogger     m_logger;
    bool        m_isInitialized;
    bool        m_isPrepared;

    CStatisticsReporter         *m_statisticsReporter;
    CBehavioralMetricsCollector *m_behavioralCollector;
    CValidationEventBus         *m_eventBus;
    ValidationRequest            m_request;

    bool ValidateRequest(const ValidationRequest &req)
    {
        if(req.symbolCount <= 0)
        {
            m_logger.LogError("ValidationRequest has no symbols");
            return false;
        }
        if(req.timeframeCount <= 0)
        {
            m_logger.LogError("ValidationRequest has no timeframes");
            return false;
        }
        if(req.testStart <= 0 || req.testEnd <= 0)
        {
            m_logger.LogError("ValidationRequest has invalid date range");
            return false;
        }
        if(req.testEnd <= req.testStart)
        {
            m_logger.LogError("ValidationRequest testEnd must be after testStart");
            return false;
        }
        return true;
    }

    void PopulateManifest(ValidationManifest &manifest, const ValidationRequest &req)
    {
        manifest.validationId = StringFormat("val_%s_%s_%s",
            TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS),
            req.symbolCount > 0 ? req.symbols[0] : "unknown",
            EnumToString(req.timeframes[0]));

        manifest.eaVersion = "v2.0-validation-lab";
        manifest.compileTime = TimeCurrent();
        manifest.parameterHash = req.parameterSetId;
        manifest.symbolTested = req.symbolCount > 0 ? req.symbols[0] : "";
        manifest.timeframeTested = EnumToString(req.timeframes[0]);
        manifest.broker = AccountInfoString(ACCOUNT_COMPANY);
        manifest.mt5Build = StringFormat("%d", TerminalInfoInteger(TERMINAL_BUILD));
    }

public:
    CTesterDataSource(void);
    ~CTesterDataSource(void);

    bool Init(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    void SetStatisticsReporter(CStatisticsReporter *reporter) { m_statisticsReporter = reporter; }
    void SetBehavioralCollector(CBehavioralMetricsCollector *collector) { m_behavioralCollector = collector; }
    void SetEventBus(CValidationEventBus *bus) { m_eventBus = bus; }

    bool Prepare(const ValidationRequest &req) override;
    bool Finalize(ValidationResult &outResult) override;
    string GetStatus(void) const override;
};

CTesterDataSource::CTesterDataSource(void)
    : m_logger(MODULE_UNKNOWN, "TesterDataSource")
    , m_isInitialized(false)
    , m_isPrepared(false)
    , m_statisticsReporter(NULL)
    , m_behavioralCollector(NULL)
    , m_eventBus(NULL)
{
}

CTesterDataSource::~CTesterDataSource(void)
{
    Shutdown();
}

bool CTesterDataSource::Init(void)
{
    m_logger.LogInfo("Initializing TesterDataSource...");
    m_isInitialized = true;
    m_logger.LogInfo("TesterDataSource initialized");
    return true;
}

void CTesterDataSource::Shutdown(void)
{
    if(!m_isInitialized)
        return;

    m_isPrepared = false;
    m_statisticsReporter = NULL;
    m_behavioralCollector = NULL;
    m_eventBus = NULL;
    m_isInitialized = false;
    m_logger.LogInfo("TesterDataSource shutdown complete");
}

bool CTesterDataSource::Prepare(const ValidationRequest &req)
{
    if(!m_isInitialized)
    {
        m_logger.LogError("TesterDataSource not initialized");
        return false;
    }

    if(!ValidateRequest(req))
        return false;

    m_request = req;
    m_isPrepared = true;

    m_logger.LogInfo(StringFormat("Prepared for validation: %s %s %s->%s",
        req.symbolCount > 0 ? req.symbols[0] : "?",
        EnumToString(req.timeframes[0]),
        TimeToString(req.testStart),
        TimeToString(req.testEnd)));

    return true;
}

bool CTesterDataSource::Finalize(ValidationResult &outResult)
{
    if(!m_isInitialized || !m_isPrepared)
    {
        m_logger.LogError("TesterDataSource not prepared for finalization");
        return false;
    }

    outResult = ValidationResult();
    outResult.request = m_request;

    PopulateManifest(outResult.manifest, m_request);

    double totalNetProfit = 0.0;
    double grossProfit = 0.0;
    double grossLoss = 0.0;
    int totalTrades = 0;
    int wins = 0;
    int losses = 0;

    if(m_statisticsReporter != NULL && m_statisticsReporter.IsInitialized())
    {
        TradeStatistics stats = m_statisticsReporter.GetStatistics();
        totalTrades = stats.totalTrades;
        wins = stats.wins;
        losses = stats.losses;
        totalNetProfit = stats.totalProfit;
    }

    if(m_behavioralCollector != NULL && m_behavioralCollector.GetObservationCount() > 0)
    {
        m_behavioralCollector.Finalize(outResult.behavior);

        if(outResult.behavior.totalTrades > totalTrades)
            totalTrades = outResult.behavior.totalTrades;
    }

    outResult.strategyReport.totalTrades = totalTrades;
    outResult.strategyReport.winningTrades = wins;
    outResult.strategyReport.losingTrades = losses;
    outResult.strategyReport.totalNetProfit = totalNetProfit;
    outResult.strategyReport.winRate = (totalTrades > 0)
        ? (double)wins / totalTrades * 100.0 : 0.0;
    outResult.strategyReport.expectancy = (totalTrades > 0)
        ? totalNetProfit / totalTrades : 0.0;

    if(m_statisticsReporter != NULL)
    {
        TradeStatistics stats = m_statisticsReporter.GetStatistics();
        outResult.strategyReport.grossProfit = totalNetProfit > 0.0 ? totalNetProfit : 0.0;
        outResult.strategyReport.grossLoss = totalNetProfit < 0.0 ? totalNetProfit : 0.0;
    }

    m_isPrepared = false;

    m_logger.LogInfo(StringFormat(
        "Validation finalize complete: %d trades, net P/L=%.2f",
        totalTrades, totalNetProfit));

    return true;
}

string CTesterDataSource::GetStatus(void) const
{
    if(!m_isInitialized)
        return "Not initialized";
    if(!m_isPrepared)
        return "Idle";
    return StringFormat("Prepared: %s", m_request.experimentLabel);
}

#endif
