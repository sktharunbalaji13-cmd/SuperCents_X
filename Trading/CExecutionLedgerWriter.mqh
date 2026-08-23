//+------------------------------------------------------------------+
//|                        CExecutionLedgerWriter.mqh                 |
//|                                      Copyright 2026, SuperCents_X|
//|                                                  Sprint 25B B25-03C-B |
//+------------------------------------------------------------------+
//  B25-03C-B - Execution Ledger Writer (the ONLY appender).
//
//  Responsibilities (write-side):
//    - INTENT-before-send (provision executionId via B25-03A identity,
//      append + flush INTENT, fail closed before OrderSend)
//    - event-after-send driven by the committed H6 policy (consumed, not
//      modified): RECORD->SENT, REJECT_PERMANENT->REJECTED,
//      RETRY_ELIGIBLE->REJECTED, RETRY_HOLD->UNKNOWN
//    - DEAL_IN / RECONCILED / BLOCKED / RUN_END appends
//    - state-machine enforcement (legal-transition whitelist from
//      CExecutionRecovery.mqh) before every append
//    - AlreadySent(executionId): durable broker-visible-submission guard
//      keyed by executionId (Clarification C1-A; candidateId is run-local
//      and is NOT a durable dedup authority), separate from the
//      executionId-never-reused invariant (C1-B / Invariant 6).
//
//  Non-atomicity: INTENT flush does NOT make OrderSend atomic with the
//  post-send event; the R3 window is recovered by CExecutionRecovery.
//+------------------------------------------------------------------+
#ifndef __EXECUTION_LEDGER_WRITER_MQH__
#define __EXECUTION_LEDGER_WRITER_MQH__

#include "CExecutionRecovery.mqh"

//--- P0/1A (integrity): pure, deterministic DEAL_IN admission gate.
//    A broker DEAL_ADD notification may become a DEAL_IN ledger event ONLY
//    when the deal was selectable in history AND it is an ENTRY deal.
//    An OUT / INOUT / OUT_BY deal carries the SAME "SCX-<side>-P<id>" comment
//    as the entry it closes, so without this gate a close would be folded into
//    filledVolume as if it were another fill - breaking Invariant 8 and the
//    "every deal ticket maps to <=1 decision" half of INV-11.
//    Fail closed: anything not provably an entry deal is refused.
bool LedgerAdmitsDealAsEntry(const bool historySelected, const int dealEntry)
{
    if(!historySelected)
        return false;   // no durable evidence of what this deal is -> never record
    return (dealEntry == DEAL_ENTRY_IN);
}

//--- P1-A.1 (observability): admission-outcome labels.
//    The P0 gate above is fail-closed and side-effect-free, which means all of
//    its refusal causes - plus the "no decision token" case downstream - leave
//    the SAME observable: nothing.  A lost fill (HISTORY_UNAVAILABLE) is then
//    indistinguishable from correct, expected, high-frequency behaviour
//    (NOT_ENTRY on every position close; NO_DECISION_TOKEN on every
//    third-party/manual deal).  These labels name the four causes so the
//    disclosure can tell them apart.  They are OBSERVABILITY ONLY: no label
//    participates in any admission, ledger, state or send decision.
#define DEAL_ADMIT_ADMIT              "ADMIT"
#define DEAL_ADMIT_HISTORY_UNAVAIL    "HISTORY_UNAVAILABLE"
#define DEAL_ADMIT_NOT_ENTRY          "NOT_ENTRY"
#define DEAL_ADMIT_NO_DECISION_TOKEN  "NO_DECISION_TOKEN"

//--- P1-A.1: pure, deterministic classification of a DEAL_ADD admission.
//    Precedence mirrors the handler's evaluation order exactly:
//      1. history not selectable        -> HISTORY_UNAVAILABLE (possible lost fill)
//      2. selectable but not an entry   -> NOT_ENTRY           (correct: our close)
//      3. entry but no "-P" token       -> NO_DECISION_TOKEN   (correct: not ours)
//      4. otherwise                     -> ADMIT
//    This function does NOT decide admission.  LedgerAdmitsDealAsEntry remains
//    the sole admission authority; this only labels what happened.
string ClassifyDealAdmission(const bool historySelected, const int dealEntry,
                             const bool hasDecisionToken)
{
    if(!historySelected)
        return DEAL_ADMIT_HISTORY_UNAVAIL;
    if(dealEntry != DEAL_ENTRY_IN)
        return DEAL_ADMIT_NOT_ENTRY;
    if(!hasDecisionToken)
        return DEAL_ADMIT_NO_DECISION_TOKEN;
    return DEAL_ADMIT_ADMIT;
}

//--- P1-A.1: pure classification of the post-admission attribution result.
//    RecordDealByDecisionId returns false when no non-terminal execution carries
//    that decisionId, i.e. an admitted entry deal that cannot be attached to any
//    live decision (orphan attribution).  Its return value was previously
//    discarded, making that case silent.  Reuses the authorised label set - no
//    new event type, no new vocabulary.
string ClassifyDealAttribution(const bool ledgerAccepted)
{
    if(ledgerAccepted)
        return DEAL_ADMIT_ADMIT;
    return DEAL_ADMIT_NO_DECISION_TOKEN;
}

//--- P1-A.1: pure predicate - which labels warrant a diagnostic.  ADMIT is the
//    success path and stays quiet; every other label is a distinct cause that
//    was previously invisible.
bool DealAdmissionRequiresDisclosure(const string label)
{
    return (label != DEAL_ADMIT_ADMIT);
}

//--- P0/F5 (integrity): pure, deterministic fail-closed execution gate.
//    ENTRY_MODE_LEGACY is the only mode that calls OrderSend, and it may do so
//    ONLY when the durable execution infrastructure is actually wired:
//      writer     -> INTENT-before-send (durable intent; Invariant 6)
//      recovery    -> the corrupt/blocked-ledger send gate
//      inspection  -> cross-run duplicate defense (B25-03C-E)
//    CTradeManager treats each of these as "absent -> skip", so a partially
//    wired LEGACY context would send live orders with no durable intent, no
//    duplicate defense and no block gate.  Non-LEGACY modes are dormant by
//    design (the modules are never created) and are unaffected.
bool LedgerWiringPermitsExecution(const bool legacyMode, const bool hasLedgerWriter,
                                  const bool hasRecovery, const bool hasInspection)
{
    if(!legacyMode)
        return true;    // SHADOW / NEW never send: dormancy is not a failure
    return (hasLedgerWriter && hasRecovery && hasInspection);
}

class CExecutionLedgerWriter
{
private:
    string              m_path;
    CExecutionIdentity *m_identity;
    ExecutionReconState m_states[];
    bool                m_initialized;

    int FindIdx(const string executionId) const
    {
        return FindStateByExecutionId(m_states, executionId);
    }

    string CurrentState(const string executionId)
    {
        int idx = FindIdx(executionId);
        if(idx < 0)
            return "";
        return m_states[idx].state;
    }

    double CurrentFilled(const string executionId)
    {
        int idx = FindIdx(executionId);
        if(idx < 0)
            return 0.0;
        return m_states[idx].filledVolume;
    }

    void SetLiveState(const string executionId, const long decisionId,
                      const string state, const double requestedVolume,
                      const double filledVolume)
    {
        int idx = FindIdx(executionId);
        if(idx < 0)
        {
            ExecutionReconState st;
            st.executionId = executionId;
            st.decisionId = decisionId;
            st.state = state;
            st.requestedVolume = requestedVolume;
            st.filledVolume = filledVolume;
            st.dealCount = 0;
            st.brokerVisible = IsBrokerVisibleState(state);
            st.terminal = IsTerminalState(state);
            ArrayResize(st.dealTickets, 0);
            int n = ArraySize(m_states);
            ArrayResize(m_states, n + 1);
            m_states[n] = st;
        }
        else
        {
            m_states[idx].state = state;
            m_states[idx].brokerVisible = IsBrokerVisibleState(state);
            m_states[idx].terminal = IsTerminalState(state);
        }
    }

    bool Append(const string executionId, const string eventType,
                const string stateFrom, const string stateTo,
                const string payload, ulong &eventSeqOut)
    {
        return LedgerAppendEvent(m_path, executionId, eventType, TimeCurrent(),
                                 stateFrom, stateTo, payload, eventSeqOut);
    }

public:
    CExecutionLedgerWriter(void)
    {
        m_path = "";
        m_identity = NULL;
        ArrayResize(m_states, 0);
        m_initialized = false;
    }

    // Creates/validates the ledger, recovers torn tail, folds existing
    // events into the live state map.  Refuses to initialize on
    // MID_FILE_CORRUPT / HEADER_CORRUPT / SEQ_VIOLATION (appends block).
    bool Init(const string ledgerPath, CExecutionIdentity *identity, const string runId, const string buildTag)
    {
        m_path = ledgerPath;
        m_identity = identity;
        m_initialized = false;

        string gitHead = "unknown";
        string terminalBuild = IntegerToString(TerminalInfoInteger(TERMINAL_BUILD));

        if(!LedgerOpenOrCreate(m_path, runId, buildTag, gitHead, terminalBuild))
            return false;

        ExecutionLedgerEvent events[];
        string info = "";
        ENUM_LEDGER_SCAN_RESULT sc = LedgerScan(m_path, events, info);
        if(sc == LEDGER_SCAN_TORN_TAIL)
        {
            if(!LedgerRecoverTornTail(m_path, info))
                return false;
            sc = LedgerScan(m_path, events, info);
        }
        if(sc == LEDGER_SCAN_MID_FILE_CORRUPT ||
           sc == LEDGER_SCAN_HEADER_CORRUPT ||
           sc == LEDGER_SCAN_SEQ_VIOLATION)
            return false;

        string violation = "";
        ulong hw = 0;
        if(!RebuildStates(events, m_states, violation, hw))
            return false;

        m_initialized = true;
        return true;
    }

    bool IsInitialized(void) const { return m_initialized; }

    //--- C1-A: durable broker-visible-submission guard keyed by executionId
    //    (candidateId is run-local; cross-run dedup is broker reconciliation).
    bool AlreadySent(const string executionId) const
    {
        int idx = FindIdx(executionId);
        if(idx < 0)
            return false;
        return m_states[idx].brokerVisible;
    }

    //--- C1-B (Invariant 6): an executionId must never receive a second
    //    INTENT.  BeginExecution always allocates a FRESH executionId.
    //    C1 (plan identity): appends [8..12] = planEntryPrice, structureResolved,
    //    entryPolicy, stopPolicy, targetPolicy.  [3] requestedPrice stays the
    //    live broker-request price (unchanged).
    bool BeginExecution(const long decisionId, const string symbol, const string side,
                        const double requestedPrice, const double requestedVolume,
                        const double sl, const double tp, const long magic,
                        const double planEntryPrice, const int structureResolved,
                        const int entryPolicy, const int stopPolicy, const int targetPolicy,
                        string &executionId)
    {
        executionId = "";
        if(!m_initialized || m_identity == NULL)
            return false;

        ulong seq = 0;
        if(!m_identity.AllocateSeq(seq))
            return false;
        string eid = "";
        if(!m_identity.BuildExecutionId(seq, eid))
            return false;

        string payload = IntegerToString(decisionId) + "|" + symbol + "|" + side + "|" +
                         DoubleToString(requestedPrice, 8) + "|" +
                         DoubleToString(requestedVolume, 8) + "|" +
                         DoubleToString(sl, 8) + "|" + DoubleToString(tp, 8) + "|" +
                         IntegerToString(magic) + "|" +
                         DoubleToString(planEntryPrice, 8) + "|" +
                         IntegerToString(structureResolved) + "|" +
                         IntegerToString(entryPolicy) + "|" +
                         IntegerToString(stopPolicy) + "|" +
                         IntegerToString(targetPolicy);

        ulong eventSeq = 0;
        if(!Append(eid, LEDGER_EVENT_INTENT, "", EXEC_STATE_INTENT, payload, eventSeq))
            return false;

        SetLiveState(eid, decisionId, EXEC_STATE_INTENT, requestedVolume, 0.0);
        executionId = eid;
        return true;
    }

    //--- post-send event driven by the committed H6 policy.
    bool RecordResult(const string executionId, const ExecutionTruthRecord &truth,
                      const ENUM_H6_RETRY_POLICY policy)
    {
        if(!m_initialized)
            return false;

        string from = CurrentState(executionId);
        string eventType = "";
        string to = "";

        if(policy == H6_POLICY_RECORD)
        {
            eventType = LEDGER_EVENT_SENT;
            to = EXEC_STATE_SUBMITTED;
        }
        else if(policy == H6_POLICY_REJECT_PERMANENT || policy == H6_POLICY_RETRY_ELIGIBLE)
        {
            eventType = LEDGER_EVENT_REJECTED;
            to = EXEC_STATE_REJECTED;
        }
        else
        {
            eventType = LEDGER_EVENT_UNKNOWN;
            to = EXEC_STATE_UNKNOWN;
        }

        if(from == "" || !IsLegalTransition(from, to))
            return false;

        string payload;
        if(eventType == LEDGER_EVENT_SENT)
            payload = IntegerToString(truth.requestId) + "|" + IntegerToString(truth.retcode) + "|" +
                      IntegerToString(truth.retcodeExternal) + "|" +
                      IntegerToString(truth.orderTicket) + "|" + IntegerToString((int)truth.outcome);
        else if(eventType == LEDGER_EVENT_REJECTED)
            payload = IntegerToString(truth.retcode) + "|" + IntegerToString(truth.retcodeExternal) + "|rejected";
        else
            payload = IntegerToString(truth.retcode) + "|" + IntegerToString(truth.retcodeExternal) + "|" +
                      DoubleToString(truth.bidAtResult, 8) + "|" + DoubleToString(truth.askAtResult, 8) + "|" +
                      truth.brokerComment;

        ulong eventSeq = 0;
        if(!Append(executionId, eventType, from, to, payload, eventSeq))
            return false;

        int idx = FindIdx(executionId);
        if(idx >= 0)
        {
            m_states[idx].state = to;
            m_states[idx].brokerVisible = IsBrokerVisibleState(to);
            m_states[idx].terminal = IsTerminalState(to);
        }
        return true;
    }

    //--- DEAL_IN: idempotent per dealTicket (Invariant 7).
    bool RecordDeal(const string executionId, const ulong dealTicket, const ulong orderTicket,
                    const ulong positionId, const double filledPrice, const double filledVolume,
                    const datetime dealTime, const int direction)
    {
        if(!m_initialized)
            return false;

        int idx = FindIdx(executionId);
        if(idx < 0)
            return false;

        if(HasDealTicket(m_states[idx], dealTicket))
            return true; // idempotent: already recorded

        double newFilled = m_states[idx].filledVolume + filledVolume;

        //--- P0/1B (Invariant 8): filledVolume <= requestedVolume + 1e-8.
        //    RebuildStates enforces this on replay and REFUSES the whole ledger
        //    when it is violated, so appending an over-fill here would write a
        //    record that the next start cannot read: writer Init returns false
        //    and recovery latches BLOCKED, on an append-only file with no repair
        //    path.  Refuse the append instead (mirrors CExecutionRecovery
        //    RebuildStates); the live state is left untouched.
        if(newFilled > m_states[idx].requestedVolume + 1e-8)
            return false;

        string to = (newFilled + 1e-8 >= m_states[idx].requestedVolume)
                    ? EXEC_STATE_FILLED : EXEC_STATE_PARTIALLY_FILLED;

        string from = m_states[idx].state;
        if(!IsLegalTransition(from, to))
            return false;

        string payload = IntegerToString(dealTicket) + "|" + IntegerToString(orderTicket) + "|" +
                         IntegerToString(positionId) + "|" + DoubleToString(filledPrice, 8) + "|" +
                         DoubleToString(filledVolume, 8) + "|" + TimeToString(dealTime) + "|" +
                         IntegerToString(direction);

        ulong eventSeq = 0;
        if(!Append(executionId, LEDGER_EVENT_DEAL_IN, from, to, payload, eventSeq))
            return false;

        m_states[idx].filledVolume = newFilled;
        int dc = m_states[idx].dealCount;
        ArrayResize(m_states[idx].dealTickets, dc + 1);
        m_states[idx].dealTickets[dc] = dealTicket;
        m_states[idx].dealCount = dc + 1;
        m_states[idx].state = to;
        m_states[idx].brokerVisible = true;
        m_states[idx].terminal = IsTerminalState(to);
        return true;
    }

    bool RecordReconciled(const string executionId, const string verdict, const string detail)
    {
        if(!m_initialized)
            return false;
        string from = CurrentState(executionId);
        if(from == "" || !IsLegalTransition(from, EXEC_STATE_RESOLVED))
            return false;
        string payload = verdict + "|" + detail;
        ulong eventSeq = 0;
        if(!Append(executionId, LEDGER_EVENT_RECONCILED, from, EXEC_STATE_RESOLVED, payload, eventSeq))
            return false;
        int idx = FindIdx(executionId);
        if(idx >= 0)
        {
            m_states[idx].state = EXEC_STATE_RESOLVED;
            m_states[idx].terminal = true;
        }
        return true;
    }

    bool RecordBlocked(const string executionId, const string reason, const string detail)
    {
        if(!m_initialized)
            return false;
        string from = CurrentState(executionId);
        if(from == "" || !IsLegalTransition(from, EXEC_STATE_BLOCKED))
            return false;
        string payload = reason + "|" + detail;
        ulong eventSeq = 0;
        if(!Append(executionId, LEDGER_EVENT_BLOCKED, from, EXEC_STATE_BLOCKED, payload, eventSeq))
            return false;
        int idx = FindIdx(executionId);
        if(idx >= 0)
        {
            m_states[idx].state = EXEC_STATE_BLOCKED;
            m_states[idx].terminal = true;
        }
        return true;
    }

    bool RecordRunEnd(void)
    {
        if(!m_initialized)
            return false;
        string summary = "";
        for(int i = 0; i < ArraySize(m_states); i++)
        {
            if(summary != "")
                summary += ";";
            summary += m_states[i].executionId + "=" + m_states[i].state;
        }
        ulong eventSeq = 0;
        return Append("SYSTEM", LEDGER_EVENT_RUN_END, "", "", summary, eventSeq);
    }

    int StateCount(void) const { return ArraySize(m_states); }

    //--- OTT/E2 DEAL_IN correlation by decisionId: attach a deal to the
    //    most recent non-terminal execution with that decisionId.  Returns
    //    false (no-op) when no matching pending execution exists - never
    //    fabricates an execution.
    bool RecordDealByDecisionId(const long decisionId, const ulong dealTicket, const ulong orderTicket,
                                const ulong positionId, const double filledPrice, const double filledVolume,
                                const datetime dealTime, const int direction)
    {
        int best = -1;
        for(int i = 0; i < ArraySize(m_states); i++)
        {
            if(m_states[i].decisionId == decisionId && !m_states[i].terminal)
                best = i;
        }
        if(best < 0)
            return false;
        return RecordDeal(m_states[best].executionId, dealTicket, orderTicket, positionId,
                          filledPrice, filledVolume, dealTime, direction);
    }
};

#endif
