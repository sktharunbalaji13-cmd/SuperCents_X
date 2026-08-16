//+------------------------------------------------------------------+
//|                          CExecutionRecovery.mqh                   |
//|                                      Copyright 2026, SuperCents_X|
//|                                                  Sprint 25B B25-03C-B |
//+------------------------------------------------------------------+
//  B25-03C-B - Execution Recovery / state model.  Consumes the frozen
//  B25-03C-A ledger core (ExecutionLedger.mqh) and B25-03A identity.
//
//  Responsibilities (read-side):
//    - state strings + the legal-transition whitelist (accepted Phase 4)
//    - RebuildStates(): pure, deterministic fold over ledger events that
//      enforces Invariants 6/7/8/9/11 (one INTENT, deal dedup, filled<=
//      requested, remaining>=0, whitelist transitions)
//    - CExecutionRecovery: startup scan/recover/classify + pending
//      enumeration + AlreadySent (durable broker-visible-submission guard
//      keyed by decisionId) + high-water executionSeq.
//
//  RECONCILING is an IN-MEMORY state only (the 9-event vocabulary has no
//  RECONCILING event); the terminal outcomes are RESOLVED/BLOCKED.
//
//  NON-ATOMICITY: INTENT-before-send + FileFlush does NOT make OrderSend
//  atomic with the post-send event.  R3 broker inspection is mandatory.
//+------------------------------------------------------------------+
#ifndef __EXECUTION_RECOVERY_MQH__
#define __EXECUTION_RECOVERY_MQH__

#include "ExecutionLedger.mqh"
#include "ExecutionIdentity.mqh"
#include "ExecutionTruth.mqh"
#include "TradeManagerRetryPolicy.mqh"

//--- execution state strings (ledger stateFrom / stateTo)
#define EXEC_STATE_INTENT            "INTENT"
#define EXEC_STATE_SUBMITTED         "SUBMITTED"
#define EXEC_STATE_ACCEPTED          "ACCEPTED"
#define EXEC_STATE_PARTIALLY_FILLED  "PARTIALLY_FILLED"
#define EXEC_STATE_FILLED            "FILLED"
#define EXEC_STATE_REJECTED          "REJECTED"
#define EXEC_STATE_UNKNOWN           "UNKNOWN"
#define EXEC_STATE_RESOLVED          "RESOLVED"
#define EXEC_STATE_BLOCKED           "BLOCKED"

//--- reconciliation verdict strings
#define EXEC_VERDICT_RESOLVED         "RESOLVED"
#define EXEC_VERDICT_NOT_FOUND        "NOT_FOUND"
#define EXEC_VERDICT_AMBIGUOUS        "AMBIGUOUS"
#define EXEC_VERDICT_BROKER_UNAVAIL   "BROKER_UNAVAILABLE"
#define EXEC_VERDICT_CORRUPT_LOCAL    "CORRUPT_LOCAL_STATE"

//--- per-executionId reconstructed state
struct ExecutionReconState
{
    string executionId;
    long   decisionId;      // candidateId / executionPlanId (from INTENT payload)
    string symbol;
    string side;
    long   magic;
    string state;           // current state string
    double requestedVolume;
    double filledVolume;
    ulong  dealTickets[];
    int    dealCount;
    bool   brokerVisible;   // reached SUBMITTED/ACCEPTED/PARTIALLY_FILLED/FILLED
    bool   terminal;        // FILLED/REJECTED/RESOLVED/BLOCKED
};

bool IsTerminalState(const string s)
{
    return (s == EXEC_STATE_FILLED || s == EXEC_STATE_REJECTED ||
            s == EXEC_STATE_RESOLVED || s == EXEC_STATE_BLOCKED);
}

bool IsBrokerVisibleState(const string s)
{
    return (s == EXEC_STATE_SUBMITTED || s == EXEC_STATE_ACCEPTED ||
            s == EXEC_STATE_PARTIALLY_FILLED || s == EXEC_STATE_FILLED);
}

//--- legal-transition whitelist (accepted design Phase 4; RECONCILING
//    is in-memory only, so RESOLVED/BLOCKED are reachable directly from
//    any non-terminal state via RECONCILED/BLOCKED events).
bool IsLegalTransition(const string from, const string to)
{
    if(from == to)
        return (from == EXEC_STATE_PARTIALLY_FILLED);

    if(from == EXEC_STATE_INTENT)
        return (to == EXEC_STATE_SUBMITTED || to == EXEC_STATE_REJECTED ||
                to == EXEC_STATE_UNKNOWN || to == EXEC_STATE_ACCEPTED ||
                to == EXEC_STATE_PARTIALLY_FILLED || to == EXEC_STATE_FILLED ||
                to == EXEC_STATE_RESOLVED || to == EXEC_STATE_BLOCKED);
    if(from == EXEC_STATE_SUBMITTED)
        return (to == EXEC_STATE_ACCEPTED || to == EXEC_STATE_PARTIALLY_FILLED ||
                to == EXEC_STATE_FILLED || to == EXEC_STATE_UNKNOWN ||
                to == EXEC_STATE_RESOLVED || to == EXEC_STATE_BLOCKED);
    if(from == EXEC_STATE_ACCEPTED)
        return (to == EXEC_STATE_PARTIALLY_FILLED || to == EXEC_STATE_FILLED ||
                to == EXEC_STATE_REJECTED || to == EXEC_STATE_RESOLVED ||
                to == EXEC_STATE_BLOCKED);
    if(from == EXEC_STATE_PARTIALLY_FILLED)
        return (to == EXEC_STATE_PARTIALLY_FILLED || to == EXEC_STATE_FILLED ||
                to == EXEC_STATE_RESOLVED || to == EXEC_STATE_BLOCKED);
    if(from == EXEC_STATE_UNKNOWN)
        return (to == EXEC_STATE_SUBMITTED || to == EXEC_STATE_ACCEPTED ||
                to == EXEC_STATE_PARTIALLY_FILLED || to == EXEC_STATE_FILLED ||
                to == EXEC_STATE_RESOLVED || to == EXEC_STATE_BLOCKED);
    // FILLED / REJECTED / RESOLVED / BLOCKED are terminal
    return false;
}

//--- lookup helpers over an ExecutionReconState array
int FindStateByExecutionId(const ExecutionReconState &states[], const string executionId)
{
    for(int i = 0; i < ArraySize(states); i++)
        if(states[i].executionId == executionId)
            return i;
    return -1;
}

int FindStateByDecisionId(const ExecutionReconState &states[], const long decisionId)
{
    for(int i = 0; i < ArraySize(states); i++)
        if(states[i].decisionId == decisionId)
            return i;
    return -1;
}

//--- INTENT payload: decisionId|symbol|side|price|volume|sl|tp|magic
bool ParseIntentPayload(const string payload, long &decisionId, string &symbol,
                        string &side, double &requestedVolume, long &magic)
{
    string parts[];
    int n = StringSplit(payload, '|', parts);
    if(n < 8)
        return false;
    decisionId = StringToInteger(parts[0]);
    symbol = parts[1];
    side = parts[2];
    requestedVolume = StringToDouble(parts[4]);
    magic = StringToInteger(parts[7]);
    return true;
}

//--- DEAL_IN payload: dealTicket|orderTicket|positionId|price|volume|dealTime|direction
bool ParseDealInPayload(const string payload, ulong &dealTicket, double &filledVolume)
{
    string parts[];
    int n = StringSplit(payload, '|', parts);
    if(n < 5)
        return false;
    dealTicket = (ulong)StringToInteger(parts[0]);
    filledVolume = StringToDouble(parts[4]);
    return true;
}

bool HasDealTicket(const ExecutionReconState &st, const ulong dealTicket)
{
    for(int i = 0; i < st.dealCount; i++)
        if(st.dealTickets[i] == dealTicket)
            return true;
    return false;
}

//--- pure, deterministic fold over ledger events -> per-executionId state.
//    Enforces Invariants 6 (one INTENT), 7 (deal dedup), 8 (filled<=
//    requested + eps), 9 (remaining>=0), 11 (whitelist transitions).
//    Returns false with `violation` on any invariant break (caller blocks).
bool RebuildStates(const ExecutionLedgerEvent &events[], ExecutionReconState &states[],
                   string &violation, ulong &highWaterSeq)
{
    ArrayResize(states, 0);
    violation = "";
    highWaterSeq = 0;
    int total = ArraySize(events);

    for(int i = 0; i < total; i++)
    {
        string t = events[i].eventType;
        string eid = events[i].executionId;

        // system events carry no execution state
        if(t == LEDGER_EVENT_CORRUPTION || t == LEDGER_EVENT_RUN_END)
            continue;

        int idx = FindStateByExecutionId(states, eid);

        if(t == LEDGER_EVENT_INTENT)
        {
            if(idx >= 0)
            {
                violation = "duplicate INTENT for " + eid;
                return false;
            }
            long decisionId = 0;
            double rv = 0.0;
            string sym = "";
            string sd = "";
            long mg = 0;
            ParseIntentPayload(events[i].payload, decisionId, sym, sd, rv, mg);

            ExecutionReconState st;
            st.executionId = eid;
            st.decisionId = decisionId;
            st.symbol = sym;
            st.side = sd;
            st.magic = mg;
            st.state = EXEC_STATE_INTENT;
            st.requestedVolume = rv;
            st.filledVolume = 0.0;
            st.dealCount = 0;
            st.brokerVisible = false;
            st.terminal = false;
            ArrayResize(st.dealTickets, 0);
            int n = ArraySize(states);
            ArrayResize(states, n + 1);
            states[n] = st;

            ulong seq = LedgerExtractExecutionSeq(eid);
            if(seq > highWaterSeq)
                highWaterSeq = seq;
            continue;
        }

        // any other event requires a prior INTENT for this executionId
        if(idx < 0)
        {
            violation = "event " + t + " without prior INTENT for " + eid;
            return false;
        }
        if(states[idx].state != events[i].stateFrom)
        {
            violation = "stateFrom mismatch for " + eid + ": recorded " + events[i].stateFrom +
                        " != current " + states[idx].state;
            return false;
        }
        if(!IsLegalTransition(events[i].stateFrom, events[i].stateTo))
        {
            violation = "illegal transition " + events[i].stateFrom + "->" + events[i].stateTo +
                        " for " + eid;
            return false;
        }

        if(t == LEDGER_EVENT_DEAL_IN)
        {
            ulong dealTicket = 0;
            double fv = 0.0;
            ParseDealInPayload(events[i].payload, dealTicket, fv);
            if(!HasDealTicket(states[idx], dealTicket))
            {
                double newFilled = states[idx].filledVolume + fv;
                if(newFilled > states[idx].requestedVolume + 1e-8)
                {
                    violation = "filledVolume exceeds requestedVolume for " + eid;
                    return false;
                }
                states[idx].filledVolume = newFilled;
                int dc = states[idx].dealCount;
                ArrayResize(states[idx].dealTickets, dc + 1);
                states[idx].dealTickets[dc] = dealTicket;
                states[idx].dealCount = dc + 1;
            }
        }

        states[idx].state = events[i].stateTo;
        states[idx].brokerVisible = IsBrokerVisibleState(states[idx].state);
        states[idx].terminal = IsTerminalState(states[idx].state);
    }
    return true;
}

//+------------------------------------------------------------------+
//|  CExecutionRecovery - startup replay + pending + verdict surface  |
//+------------------------------------------------------------------+
class CExecutionRecovery
{
private:
    string               m_path;
    ExecutionReconState  m_states[];
    ENUM_LEDGER_SCAN_RESULT m_scan;
    bool                 m_blocked;
    string               m_corruptionInfo;
    ulong                m_highWaterSeq;
    bool                 m_initialized;

public:
    CExecutionRecovery(void) { Reset(); }

    void Reset(void)
    {
        m_path = "";
        ArrayResize(m_states, 0);
        m_scan = LEDGER_SCAN_CLEAN;
        m_blocked = false;
        m_corruptionInfo = "";
        m_highWaterSeq = 0;
        m_initialized = false;
    }

    // Read-only startup pass: scan -> (recover torn tail) -> classify ->
    // fold.  Does NOT create the ledger file (writer owns creation).
    bool Init(const string ledgerPath)
    {
        Reset();
        m_path = ledgerPath;
        m_initialized = true;

        if(!FileIsExist(m_path, FILE_COMMON))
        {
            m_scan = LEDGER_SCAN_CLEAN;
            m_blocked = false;
            return true;
        }

        ExecutionLedgerEvent events[];
        string info = "";
        m_scan = LedgerScan(m_path, events, info);

        if(m_scan == LEDGER_SCAN_TORN_TAIL)
        {
            if(!LedgerRecoverTornTail(m_path, info))
            {
                m_blocked = true;
                m_corruptionInfo = "torn-tail recovery failed: " + info;
                return true;
            }
            m_scan = LedgerScan(m_path, events, info);
        }

        if(m_scan == LEDGER_SCAN_MID_FILE_CORRUPT ||
           m_scan == LEDGER_SCAN_HEADER_CORRUPT ||
           m_scan == LEDGER_SCAN_SEQ_VIOLATION)
        {
            m_blocked = true;
            m_corruptionInfo = info;
            return true;
        }

        string violation = "";
        if(!RebuildStates(events, m_states, violation, m_highWaterSeq))
        {
            m_blocked = true;
            m_corruptionInfo = "replay invariant violation: " + violation;
            return true;
        }
        return true;
    }

    bool IsInitialized(void) const { return m_initialized; }
    bool IsExecutionBlocked(void) const { return m_blocked; }
    ulong HighWaterSeq(void) const { return m_highWaterSeq; }
    string CorruptionInfo(void) const { return m_corruptionInfo; }
    ENUM_LEDGER_SCAN_RESULT ScanResult(void) const { return m_scan; }
    int StateCount(void) const { return ArraySize(m_states); }

    int GetPendingExecutions(ExecutionReconState &pending[])
    {
        ArrayResize(pending, 0);
        for(int i = 0; i < ArraySize(m_states); i++)
        {
            if(!m_states[i].terminal)
            {
                int n = ArraySize(pending);
                ArrayResize(pending, n + 1);
                pending[n] = m_states[i];
            }
        }
        return ArraySize(pending);
    }

    bool GetStateByExecutionId(const string executionId, ExecutionReconState &out) const
    {
        int idx = FindStateByExecutionId(m_states, executionId);
        if(idx < 0)
            return false;
        out = m_states[idx];
        return true;
    }

    // Clarification C1-A: durable broker-visible-submission guard keyed by
    // executionId (the durable execution-attempt identity), NOT candidateId
    // (candidateId is run-local and cannot be a durable dedup authority —
    // accepted design Phase 7).  The executionId-never-reused rule is the
    // separate invariant C1-B / Invariant 6 enforced at the writer.
    bool AlreadySent(const string executionId) const
    {
        int idx = FindStateByExecutionId(m_states, executionId);
        if(idx < 0)
            return false;
        return m_states[idx].brokerVisible;
    }
};

#endif
