//+------------------------------------------------------------------+
//|                                    ActualOutcomeSettler.mqh       |
//|                                      Copyright 2026, SuperCents_X|
//|                                            GR02A (Sprint 20)     |
//+------------------------------------------------------------------+
//  GR02A: live-stage observability wiring.  Settles the telemetry
//  columns actualOutcome / actualOutcomeSource (reserved since schema
//  v1, never populated in production) from real trade close events.
//
//  Flow:
//    - CSymbolContext registers (candidateId -> telemetry decisionId)
//      at row-record time (Register).
//    - CPositionLifecycleManager publishes EVENT_POSITION_CLOSED with
//      entryDecisionId (the candidateId parsed from the order comment
//      "SCX-*-P<id>") and the net closed profit (deal history).
//    - This handler (subscribed to the event bus for
//      EVENT_POSITION_CLOSED) looks up the telemetry row and stamps
//      actualOutcome (WIN/LOSS/BREAKEVEN from the signed closed P/L)
//      with actualOutcomeSource = OUTCOME_SOURCE_ACTUAL.
//
//  Discipline:
//    - Simulated fields (outcome/rMultiple/barsHeld/exitReason) are
//      NEVER overwritten — the actual columns are a separate track so
//      simulator-vs-reality can be compared.
//    - Instrumentation only: no routing, no validator, no order-path
//      behavior is touched; in modes without orders the handler is
//      inert (no close events -> no rows change).
//    - Rows are only updated while still buffered in the collector
//      (single flush at Shutdown in the <= 1024-row model).  A position
//      closed after the run end can no longer reach its row — logged,
//      documented boundary (GR02A).
//+------------------------------------------------------------------+
#ifndef __TELEMETRY_ACTUAL_OUTCOME_SETTLER_MQH__
#define __TELEMETRY_ACTUAL_OUTCOME_SETTLER_MQH__

#include "TelemetryTypes.mqh"
#include "TelemetryCollector.mqh"
#include "../Monitoring/EventBusAdapter.mqh"

class CActualOutcomeSettler : public CEventHandler
{
private:
    CLogger           m_logger;
    CTelemetryCollector *m_collector;
    int               m_candidateIds[];
    int               m_decisionIds[];
    int               m_count;

    int LookupDecisionId(const int candidateId) const
    {
        for(int i = 0; i < m_count; i++)
        {
            if(m_candidateIds[i] == candidateId)
                return m_decisionIds[i];
        }
        return 0;
    }

public:
    CActualOutcomeSettler(void)
        : m_logger(MODULE_UNKNOWN, "ActualOutcomeSettler")
        , m_collector(NULL)
        , m_count(0)
    {}

    //--- GR02A: signed closed P/L -> actual outcome classification.
    //    The schema persists only actualOutcome + actualOutcomeSource
    //    (no actual rMultiple column), so classification is profit-sign
    //    based; magnitude is captured by the simulated rMultiple track.
    static int ClassifyActual(const double netProfit)
    {
        if(netProfit > 0.0)
            return (int)TELEMETRY_OUTCOME_WIN;
        if(netProfit < 0.0)
            return (int)TELEMETRY_OUTCOME_LOSS;
        return (int)TELEMETRY_OUTCOME_BREAKEVEN;
    }

    void SetCollector(CTelemetryCollector *collector) { m_collector = collector; }

    //--- Per-run mapping (candidate ids restart each run).  Called by
    //    CSymbolContext at record time; zero ids are ignored.
    void Register(const int candidateId, const int decisionId)
    {
        if(candidateId <= 0 || decisionId <= 0)
            return;
        int idx = m_count;
        if(idx >= ArraySize(m_candidateIds))
        {
            ArrayResize(m_candidateIds, idx + 256);
            ArrayResize(m_decisionIds, idx + 256);
        }
        m_candidateIds[idx] = candidateId;
        m_decisionIds[idx] = decisionId;
        m_count++;
    }

    void Reset(void) { m_count = 0; }

    virtual void HandleEvent(const EventData &data) override
    {
        if(data.eventType != EVENT_POSITION_CLOSED)
            return;
        if(data.entryDecisionId <= 0)
            return;
        if(m_collector == NULL)
            return;

        int decisionId = LookupDecisionId(data.entryDecisionId);
        if(decisionId <= 0)
        {
            m_logger.LogInfo(StringFormat(
                "GR02A: no telemetry row for candidate %d (mode without telemetry or row flushed)",
                data.entryDecisionId));
            return;
        }

        if(m_collector.ApplyActualOutcome(decisionId, ClassifyActual(data.profit)))
        {
            m_logger.LogInfo(StringFormat(
                "GR02A: decision %d (candidate %d) settled actual outcome profit=%.2f",
                decisionId, data.entryDecisionId, data.profit));
        }
        else
        {
            m_logger.LogInfo(StringFormat(
                "GR02A: decision %d (candidate %d) already flushed - actual outcome not applied",
                decisionId, data.entryDecisionId));
        }
    }
};

#endif
