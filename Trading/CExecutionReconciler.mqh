//+------------------------------------------------------------------+
//|                         CExecutionReconciler.mqh                  |
//|                                      Copyright 2026, SuperCents_X|
//|                                                  Sprint 25B B25-03C-B |
//+------------------------------------------------------------------+
//  B25-03C-B - Reconciliation: broker evidence queries + verdicts.
//
//  Verdicts (accepted Phase 6):
//    RESOLVED          - exact deal/order evidence (or DEAL_IN already
//                        recorded) matches the execution.
//    NOT_FOUND         - ONLY when exact executionId correlation (D1
//                        `#<seq>`, UNWIRED) proves exhaustive absence.
//    AMBIGUOUS         - legacy `SCX-*-P<id>` correlation or absence with
//                        no authoritative correlation. NEVER auto-resolves.
//    BROKER_UNAVAILABLE- broker unreachable; keep pending.
//    CORRUPT_LOCAL_STATE- ledger unreadable (recovery.IsExecutionBlocked).
//
//  BLOCK-over-GUESS: a missing broker artifact is NEVER proof of non-
//  execution unless the exact-correlation + exhaustive-absence rule (D1)
//  is met.  With legacy comments, absence => AMBIGUOUS, never NOT_FOUND.
//+------------------------------------------------------------------+
#ifndef __EXECUTION_RECONCILER_MQH__
#define __EXECUTION_RECONCILER_MQH__

#include "CExecutionRecovery.mqh"

//--- pure, deterministic verdict function (unit-testable).
string ReconVerdictFromEvidence(const bool brokerAvailable,
                                const bool hasExactDealOrOrder,
                                const bool hasExactExecutionIdCorrelation,
                                const bool exhaustiveAbsenceVerified,
                                const bool hasLegacyCommentMatch)
{
    if(!brokerAvailable)
        return EXEC_VERDICT_BROKER_UNAVAIL;
    if(hasExactDealOrOrder)
        return EXEC_VERDICT_RESOLVED;
    // NOT_FOUND only with exact executionId correlation (#<seq>, D1) AND
    // a verified exhaustive absence.  Legacy-only correlation never NOT_FOUND.
    if(hasExactExecutionIdCorrelation && exhaustiveAbsenceVerified)
        return EXEC_VERDICT_NOT_FOUND;
    return EXEC_VERDICT_AMBIGUOUS;
}

class CExecutionReconciler
{
private:
    // legacy comment token: "P<decisionId>" inside SCX-<side>-P<id>
    bool HasLegacyCommentMatch(const ExecutionReconState &st, const string symbol, const long magic)
    {
        string token = "P" + IntegerToString(st.decisionId);

        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            string sym = PositionGetSymbol(i);
            if(sym != symbol)
                continue;
            if((long)PositionGetInteger(POSITION_MAGIC) != magic)
                continue;
            if(StringFind(PositionGetString(POSITION_COMMENT), token, 0) >= 0)
                return true;
        }

        for(int i = OrdersTotal() - 1; i >= 0; i--)
        {
            ulong ticket = OrderGetTicket(i);
            if(ticket == 0)
                continue;
            if(OrderGetString(ORDER_SYMBOL) != symbol)
                continue;
            if((long)OrderGetInteger(ORDER_MAGIC) != magic)
                continue;
            if(StringFind(OrderGetString(ORDER_COMMENT), token, 0) >= 0)
                return true;
        }

        datetime from = TimeCurrent() - 7 * 24 * 3600;
        HistorySelect(from, TimeCurrent());
        int total = HistoryOrdersTotal();
        for(int i = total - 1; i >= 0; i--)
        {
            ulong ticket = HistoryOrderGetTicket(i);
            if(ticket == 0)
                continue;
            if(HistoryOrderGetString(ticket, ORDER_SYMBOL) != symbol)
                continue;
            if((long)HistoryOrderGetInteger(ticket, ORDER_MAGIC) != magic)
                continue;
            if(StringFind(HistoryOrderGetString(ticket, ORDER_COMMENT), token, 0) >= 0)
                return true;
        }
        return false;
    }

public:
    string Reconcile(const ExecutionReconState &st)
    {
        bool brokerAvailable = (bool)TerminalInfoInteger(TERMINAL_CONNECTED);
        if(!brokerAvailable)
            return EXEC_VERDICT_BROKER_UNAVAIL;

        // exact deal/order evidence: a DEAL_IN already recorded a deal.
        bool hasExactDealOrOrder = (st.dealCount > 0);
        bool hasLegacy = HasLegacyCommentMatch(st, st.symbol, st.magic);

        // D1 (#<seq>) unwired -> exact executionId correlation never true.
        return ReconVerdictFromEvidence(brokerAvailable, hasExactDealOrOrder,
                                        false, false, hasLegacy);
    }
};

#endif
