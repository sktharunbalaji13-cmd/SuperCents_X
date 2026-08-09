#ifndef __ENTRY_ORCHESTRATOR_MQH__
#define __ENTRY_ORCHESTRATOR_MQH__

#include "EntryTypes.mqh"
#include "EntryDecisionTypes.mqh"
#include "ValidatorRegistry.mqh"
#include "EntryLogger.mqh"

class CEntryOrchestrator
{
private:
    CValidatorRegistry  m_registry;
    CEntryLogger        m_logger;
    EntryDecision       m_lastDecision;
    bool                m_hasDecision;
    bool                m_shadowMode;
    int                 m_shadowTotal;
    int                 m_shadowAgreements;

    bool                m_initialized;

public:
    CEntryOrchestrator(void)
        : m_hasDecision(false)
        , m_shadowMode(false)
        , m_shadowTotal(0)
        , m_shadowAgreements(0)
        , m_initialized(false)
    {}

    void Init()
    {
        m_initialized = true;
        m_hasDecision = false;
        m_shadowTotal = 0;
        m_shadowAgreements = 0;
        Print("[EntryOrchestrator] Initialized");
    }

    void Shutdown()
    {
        if(m_shadowMode && m_shadowTotal > 0)
        {
            double pct = 0.0;
            if(m_shadowTotal > 0)
                pct = (double)m_shadowAgreements / m_shadowTotal * 100.0;
            m_logger.LogShadowSummary(m_shadowTotal, m_shadowAgreements, pct);
        }

        m_registry.Clear();
        m_initialized = false;
        Print("[EntryOrchestrator] Shutdown");
    }

    bool RegisterValidator(IEntryValidator *validator)
    {
        if(!m_initialized)
            return false;
        return m_registry.Register(validator);
    }

    void SetShadowMode(bool enabled)
    {
        m_shadowMode = enabled;
        if(enabled)
        {
            m_shadowTotal = 0;
            m_shadowAgreements = 0;
            Print("[EntryOrchestrator] Shadow mode enabled");
        }
    }

    bool IsShadowMode() const
    {
        return m_shadowMode;
    }

    void RecordShadowComparison(const ShadowComparison &cmp)
    {
        if(!m_shadowMode)
            return;

        m_shadowTotal++;
        if(cmp.decisionMatch)
            m_shadowAgreements++;

        m_logger.LogShadowComparisonStruct(cmp);
    }

    CValidatorRegistry *GetRegistry()
    {
        return &m_registry;
    }

    EntryDecision Evaluate(const ConfluenceResult &confluence,
                            double spread,
                            datetime now,
                            double bid,
                            double ask,
                            int barsSinceSignal,
                            double candidateEntryPrice)
    {
        EntryDecision decision;
        decision.candidateId = 0;
        decision.direction = confluence.direction;
        decision.status = DECISION_CREATED;
        decision.decisionScore = (int)confluence.totalConfidence;
        decision.confidence = confluence.totalConfidence / 100.0;
        decision.rationale = "";
        decision.rejectionCount = 0;
        decision.createdTime = now;
        decision.evidenceCount = confluence.componentCount;
        decision.ruleCount = 0;

        for(int i = 0; i < MAX_ENTRY_FILTERS; i++)
        {
            decision.filters[i].result = FILTER_PASS;
            decision.filters[i].reason = REASON_NONE;
            decision.filters[i].explanation = "";
        }
        decision.filterCount = 0;

        if(!m_initialized || m_registry.Count() == 0)
        {
            decision.status = DECISION_QUALIFIED;
            m_lastDecision = decision;
            m_hasDecision = true;
            return decision;
        }

        EntryContext ctx;
        ctx.spread = spread;
        ctx.now = now;
        ctx.currentBid = bid;
        ctx.currentAsk = ask;
        ctx.barsSinceSignal = barsSinceSignal;
        ctx.candidateEntryPrice = candidateEntryPrice;

        m_logger.LogValidationStart(m_registry.Count());

        bool allPassed = true;
        int filterIdx = 0;

        for(int i = 0; i < m_registry.Count() && filterIdx < MAX_ENTRY_FILTERS; i++)
        {
            IEntryValidator *validator = m_registry.GetValidator(i);
            if(validator == NULL || !m_registry.IsEnabledAt(i))
                continue;

            EntryFilterResult filter;
            validator.Validate(confluence, ctx, filter);

            filter.validatorName = validator.GetName();
            decision.filters[filterIdx] = filter;
            decision.filterCount = filterIdx + 1;
            filterIdx++;

            m_logger.LogFilterResult(filter);

            if(filter.result == FILTER_FAIL)
            {
                allPassed = false;
                if(decision.rejectionCount < MAX_REJECTION_REASONS)
                {
                    decision.rejectionReasons[decision.rejectionCount] = filter.validatorName + ": " + filter.explanation;
                    decision.rejectionCount++;
                }
                break;
            }
        }

        if(allPassed)
        {
            decision.status = DECISION_QUALIFIED;
            decision.rationale = "All validators passed";
        }
        else
        {
            decision.status = DECISION_REJECTED;
            decision.rationale = "Rejected by " + IntegerToString(decision.rejectionCount) + " validator(s)";
        }

        m_lastDecision = decision;
        m_hasDecision = true;
        m_logger.LogDecision(decision);

        return decision;
    }

    void CompareWithLegacy(const EntryDecision &legacyDecision)
    {
        if(!m_shadowMode || !m_hasDecision)
            return;

        m_logger.LogShadowComparison(legacyDecision, m_lastDecision, m_shadowAgreements, m_shadowTotal);
    }

    bool GetLastDecision(EntryDecision &out) const
    {
        if(!m_hasDecision)
            return false;
        out = m_lastDecision;
        return true;
    }

    int GetShadowTotal() const
    {
        return m_shadowTotal;
    }

    int GetShadowAgreements() const
    {
        return m_shadowAgreements;
    }

    double GetShadowAgreementPct() const
    {
        if(m_shadowTotal == 0)
            return 0.0;
        return (double)m_shadowAgreements / m_shadowTotal * 100.0;
    }
};

#endif
