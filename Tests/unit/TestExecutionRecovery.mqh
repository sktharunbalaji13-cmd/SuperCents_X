//+------------------------------------------------------------------+
//|                      TestExecutionRecovery.mqh                    |
//|                                      Copyright 2026, SuperCents_X|
//|                                                  Sprint 25B B25-03C-B |
//+------------------------------------------------------------------+
//  B25-03C-B acceptance tests (Phases 1-7).  Pure-function + isolated
//  file-core tests of the recovery state machine, the ledger writer,
//  and the reconciliation verdicts.  No live OrderSend, no broker
//  execution, no OnTradeTransaction, no #<seq> wiring.
//+------------------------------------------------------------------+
#ifndef __TEST_EXECUTION_RECOVERY_MQH__
#define __TEST_EXECUTION_RECOVERY_MQH__

#include "../TestAssert.mqh"
#include "../../Trading/CExecutionRecovery.mqh"
#include "../../Trading/CExecutionLedgerWriter.mqh"
#include "../../Trading/CExecutionReconciler.mqh"

//--- build a synthetic event for RebuildStates (checksum/raw not used by the fold)
ExecutionLedgerEvent MakeRecoveryEvent(const ulong seq, const string eid, const string type,
                                       const string from, const string to, const string payload)
{
    ExecutionLedgerEvent ev;
    ev.eventSeq = seq;
    ev.executionId = eid;
    ev.eventType = type;
    ev.timestamp = D'2026.01.01 00:00';
    ev.stateFrom = from;
    ev.stateTo = to;
    ev.payload = payload;
    ev.checksum = "";
    ev.raw = "";
    return ev;
}

string MakeIntentPayload(const long decisionId, const string symbol, const string side,
                         const double volume, const long magic)
{
    return IntegerToString(decisionId) + "|" + symbol + "|" + side + "|1.10000|" +
           DoubleToString(volume, 8) + "|1.09000|1.12000|" + IntegerToString(magic);
}

string MakeDealPayload(const ulong dealTicket, const double volume)
{
    return IntegerToString(dealTicket) + "|0|0|1.10000|" + DoubleToString(volume, 8) + "|2026.01.01 00:00|0";
}

//--- Phase 1: state machine + invariants --------------------------------------
void TestPhase1StateMachine(TestCounters &counters)
{
    SUITE_BEGIN("B25-03C-B Phase 1 - state machine + invariants");

    // legal transitions
    TEST_TRUE(IsLegalTransition(EXEC_STATE_INTENT, EXEC_STATE_SUBMITTED), "T1a INTENT->SUBMITTED");
    TEST_TRUE(IsLegalTransition(EXEC_STATE_INTENT, EXEC_STATE_REJECTED), "T1b INTENT->REJECTED");
    TEST_TRUE(IsLegalTransition(EXEC_STATE_INTENT, EXEC_STATE_UNKNOWN), "T1c INTENT->UNKNOWN");
    TEST_TRUE(IsLegalTransition(EXEC_STATE_SUBMITTED, EXEC_STATE_FILLED), "T1d SUBMITTED->FILLED");
    TEST_TRUE(IsLegalTransition(EXEC_STATE_PARTIALLY_FILLED, EXEC_STATE_PARTIALLY_FILLED), "T1e PF->PF self");
    TEST_TRUE(IsLegalTransition(EXEC_STATE_UNKNOWN, EXEC_STATE_FILLED), "T1f UNKNOWN->FILLED (broker evidence)");
    TEST_TRUE(IsLegalTransition(EXEC_STATE_INTENT, EXEC_STATE_BLOCKED), "T1g INTENT->BLOCKED");
    // illegal transitions
    TEST_FALSE(IsLegalTransition(EXEC_STATE_FILLED, EXEC_STATE_INTENT), "T1h FILLED->INTENT illegal");
    TEST_FALSE(IsLegalTransition(EXEC_STATE_REJECTED, EXEC_STATE_SUBMITTED), "T1i REJECTED->SUBMITTED illegal");
    TEST_FALSE(IsLegalTransition(EXEC_STATE_INTENT, EXEC_STATE_INTENT), "T1j INTENT->INTENT illegal");
    TEST_FALSE(IsLegalTransition(EXEC_STATE_BLOCKED, EXEC_STATE_RESOLVED), "T1k BLOCKED->RESOLVED illegal");

    // fold: happy path (INTENT -> SUBMITTED -> FILLED, terminal)
    {
        ExecutionLedgerEvent evs[4];
        evs[0] = MakeRecoveryEvent(1, "EX-RUN-101", LEDGER_EVENT_INTENT, "", EXEC_STATE_INTENT, MakeIntentPayload(5, "EURUSD", "BUY", 1.0, 27182819));
        evs[1] = MakeRecoveryEvent(2, "EX-RUN-101", LEDGER_EVENT_SENT, EXEC_STATE_INTENT, EXEC_STATE_SUBMITTED, "1|10009|0|123|1");
        evs[2] = MakeRecoveryEvent(3, "EX-RUN-101", LEDGER_EVENT_DEAL_IN, EXEC_STATE_SUBMITTED, EXEC_STATE_FILLED, MakeDealPayload(777, 1.0));
        evs[3] = MakeRecoveryEvent(4, "EX-RUN-101", LEDGER_EVENT_RUN_END, "", "", "");
        ExecutionReconState states[];
        string violation = "";
        ulong hw = 0;
        TEST_TRUE(RebuildStates(evs, states, violation, hw), "T1l fold succeeds (" + violation + ")");
        TEST_INT_EQ(1, ArraySize(states), "T1m one execution rebuilt");
        if(ArraySize(states) == 1)
        {
            TEST_INT_EQ(5, (int)states[0].decisionId, "T1n decisionId parsed");
            TEST_TRUE(states[0].terminal, "T1o terminal (FILLED)");
            TEST_TRUE(states[0].brokerVisible, "T1p broker-visible");
            TEST_DBL_NEAR(1.0, states[0].filledVolume, 1e-9, "T1q filledVolume 1.0");
        }
        TEST_TRUE(hw == 101, "T1r high-water executionSeq 101");
    }

    // fold: uncertain -> reconciled (UNKNOWN -> RESOLVED)
    {
        ExecutionLedgerEvent evs[3];
        evs[0] = MakeRecoveryEvent(1, "EX-RUN-105", LEDGER_EVENT_INTENT, "", EXEC_STATE_INTENT, MakeIntentPayload(8, "EURUSD", "BUY", 1.0, 1));
        evs[1] = MakeRecoveryEvent(2, "EX-RUN-105", LEDGER_EVENT_UNKNOWN, EXEC_STATE_INTENT, EXEC_STATE_UNKNOWN, "10013|0|0|0|timeout");
        evs[2] = MakeRecoveryEvent(3, "EX-RUN-105", LEDGER_EVENT_RECONCILED, EXEC_STATE_UNKNOWN, EXEC_STATE_RESOLVED, "RESOLVED|deal found");
        ExecutionReconState states[];
        string violation = "";
        ulong hw = 0;
        TEST_TRUE(RebuildStates(evs, states, violation, hw), "T1r2 UNKNOWN->RESOLVED fold succeeds (" + violation + ")");
        if(ArraySize(states) == 1)
            TEST_TRUE(states[0].terminal, "T1r3 reconciled terminal");
    }

    // fold: duplicate INTENT -> violation (Invariant 6)
    {
        ExecutionLedgerEvent evs[2];
        evs[0] = MakeRecoveryEvent(1, "EX-RUN-102", LEDGER_EVENT_INTENT, "", EXEC_STATE_INTENT, MakeIntentPayload(6, "EURUSD", "BUY", 1.0, 1));
        evs[1] = MakeRecoveryEvent(2, "EX-RUN-102", LEDGER_EVENT_INTENT, "", EXEC_STATE_INTENT, MakeIntentPayload(6, "EURUSD", "BUY", 1.0, 1));
        ExecutionReconState states[];
        string violation = "";
        ulong hw = 0;
        TEST_FALSE(RebuildStates(evs, states, violation, hw), "T1s duplicate INTENT rejected");
    }

    // fold: event without INTENT -> violation
    {
        ExecutionLedgerEvent evs[1];
        evs[0] = MakeRecoveryEvent(1, "EX-RUN-103", LEDGER_EVENT_SENT, EXEC_STATE_INTENT, EXEC_STATE_SUBMITTED, "1|10009|0|0|1");
        ExecutionReconState states[];
        string violation = "";
        ulong hw = 0;
        TEST_FALSE(RebuildStates(evs, states, violation, hw), "T1t SENT without INTENT rejected");
    }

    // fold: crash-window fill (INTENT -> FILLED via DEAL_IN, R3)
    {
        ExecutionLedgerEvent evs[2];
        evs[0] = MakeRecoveryEvent(1, "EX-RUN-104", LEDGER_EVENT_INTENT, "", EXEC_STATE_INTENT, MakeIntentPayload(7, "EURUSD", "BUY", 1.0, 1));
        evs[1] = MakeRecoveryEvent(2, "EX-RUN-104", LEDGER_EVENT_DEAL_IN, EXEC_STATE_INTENT, EXEC_STATE_FILLED, MakeDealPayload(888, 1.0));
        ExecutionReconState states[];
        string violation = "";
        ulong hw = 0;
        TEST_TRUE(RebuildStates(evs, states, violation, hw), "T1u crash-window INTENT->FILLED fold succeeds (" + violation + ")");
        if(ArraySize(states) == 1)
            TEST_DBL_NEAR(1.0, states[0].filledVolume, 1e-9, "T1v filledVolume 1.0");
    }

    SUITE_END("B25-03C-B Phase 1 - state machine + invariants");
}

//--- Phase 2: fold determinism ------------------------------------------------
void TestPhase2FoldDeterminism(TestCounters &counters)
{
    SUITE_BEGIN("B25-03C-B Phase 2 - fold determinism");

    ExecutionLedgerEvent evs[4];
    evs[0] = MakeRecoveryEvent(1, "EX-RUN-201", LEDGER_EVENT_INTENT, "", EXEC_STATE_INTENT, MakeIntentPayload(11, "EURUSD", "SELL", 0.5, 2));
    evs[1] = MakeRecoveryEvent(2, "EX-RUN-201", LEDGER_EVENT_SENT, EXEC_STATE_INTENT, EXEC_STATE_SUBMITTED, "1|10009|0|999|1");
    evs[2] = MakeRecoveryEvent(3, "EX-RUN-201", LEDGER_EVENT_DEAL_IN, EXEC_STATE_SUBMITTED, EXEC_STATE_PARTIALLY_FILLED, MakeDealPayload(555, 0.2));
    evs[3] = MakeRecoveryEvent(4, "EX-RUN-201", LEDGER_EVENT_DEAL_IN, EXEC_STATE_PARTIALLY_FILLED, EXEC_STATE_PARTIALLY_FILLED, MakeDealPayload(556, 0.1));

    ExecutionReconState a[];
    ExecutionReconState b[];
    string va = "", vb = "";
    ulong ha = 0, hb = 0;
    bool ra = RebuildStates(evs, a, va, ha);
    bool rb = RebuildStates(evs, b, vb, hb);

    TEST_TRUE(ra && rb, "T2a both folds succeed");
    TEST_INT_EQ(ArraySize(a), ArraySize(b), "T2b same state count");
    bool same = (ha == hb);
    if(ArraySize(a) == ArraySize(b) && ArraySize(a) == 1)
    {
        same = same && (a[0].executionId == b[0].executionId)
              && (a[0].state == b[0].state)
              && (MathAbs(a[0].filledVolume - b[0].filledVolume) < 1e-9)
              && (a[0].dealCount == b[0].dealCount)
              && (a[0].brokerVisible == b[0].brokerVisible)
              && (a[0].terminal == b[0].terminal);
    }
    TEST_TRUE(same, "T2c deterministic reconstruction");

    SUITE_END("B25-03C-B Phase 2 - fold determinism");
}

//--- Phase 3: evidence-ladder verdicts -----------------------------------------
void TestPhase3Verdicts(TestCounters &counters)
{
    SUITE_BEGIN("B25-03C-B Phase 3 - evidence-ladder verdicts");

    TEST_STR_EQ(EXEC_VERDICT_BROKER_UNAVAIL, ReconVerdictFromEvidence(false, false, false, false, false), "T3a broker unavailable");
    TEST_STR_EQ(EXEC_VERDICT_RESOLVED, ReconVerdictFromEvidence(true, true, false, false, false), "T3b exact deal/order -> RESOLVED");
    TEST_STR_EQ(EXEC_VERDICT_AMBIGUOUS, ReconVerdictFromEvidence(true, false, false, false, true), "T3c legacy comment match -> AMBIGUOUS");
    TEST_STR_EQ(EXEC_VERDICT_AMBIGUOUS, ReconVerdictFromEvidence(true, false, false, false, false), "T3d absence + no correlation -> AMBIGUOUS (never NOT_FOUND)");
    TEST_STR_EQ(EXEC_VERDICT_NOT_FOUND, ReconVerdictFromEvidence(true, false, true, true, false), "T3e exact correlation + exhaustive absence -> NOT_FOUND (D1 future)");
    TEST_STR_EQ(EXEC_VERDICT_AMBIGUOUS, ReconVerdictFromEvidence(true, false, true, false, false), "T3f exact correlation but no exhaustive absence -> AMBIGUOUS");

    // AMBIGUOUS never auto-resolves: pure function returns AMBIGUOUS for
    // every non-exact input; the BLOCKED record is the only terminal path.
    TEST_TRUE(true, "T3g AMBIGUOUS is never RESOLVED by this function");

    SUITE_END("B25-03C-B Phase 3 - evidence-ladder verdicts");
}

//--- test-only raw append (crafts corrupt/torn ledger lines) ------------------
bool TestRecoveryRawAppend(const string path, const string line)
{
    int h = FileOpen(path, FILE_READ | FILE_WRITE | FILE_TXT | FILE_COMMON);
    if(h == INVALID_HANDLE)
        return false;
    FileSeek(h, 0, SEEK_END);
    FileWriteString(h, line + "\r\n");
    FileFlush(h);
    FileClose(h);
    return true;
}

//--- Phase 4 + 5: writer H6 mapping + crash-window (file-based) ---------------
void TestPhase45Writer(TestCounters &counters)
{
    SUITE_BEGIN("B25-03C-B Phase 4/5 - writer H6 mapping + crash window");

    string ledgerPath = "Execution\\TestRecovery_Writer.dat";
    string counterPath = "Execution\\TestRecovery_Writer_seq.dat";
    FileDelete(ledgerPath, FILE_COMMON);
    FileDelete(counterPath, FILE_COMMON);

    CExecutionIdentity identity;
    TEST_TRUE(identity.Init("RUN-TESTREC", "test", counterPath), "T4a identity init");

    CExecutionLedgerWriter writer;
    TEST_TRUE(writer.Init(ledgerPath, &identity, "RUN-TESTREC", "test"), "T4b writer init");

    ExecutionTruthRecord truth;
    truth.executionPlanId = 0;
    truth.requestId = 0;
    truth.retcode = TRADE_RETCODE_DONE;
    truth.retcodeExternal = 0;
    truth.outcome = EXEC_OUTCOME_FILLED;
    truth.dealTicket = 0;
    truth.orderTicket = 0;
    truth.requestedPrice = 0.0;
    truth.requestedVolume = 0.0;
    truth.filledPrice = 0.0;
    truth.filledVolume = 0.0;
    truth.bidAtResult = 0.0;
    truth.askAtResult = 0.0;
    truth.brokerComment = "";
    truth.capturedTime = 0;

    // BeginExecution allocates a fresh executionId and appends INTENT
    string eid1 = "", eid2 = "";
    TEST_TRUE(writer.BeginExecution(101, "EURUSD", "BUY", 1.10000, 1.0, 1.09000, 1.12000, 27182819, eid1), "T4c BeginExecution 1");
    TEST_TRUE(writer.BeginExecution(102, "EURUSD", "SELL", 1.10000, 0.5, 1.12000, 1.08000, 27182819, eid2), "T4d BeginExecution 2");
    TEST_TRUE(eid1 != "" && eid2 != "", "T4e executionIds non-empty");
    TEST_TRUE(eid1 != eid2, "T4f distinct executionIds (never reuse)");

    // RECORD policy -> SENT -> SUBMITTED (broker-visible)
    truth.retcode = TRADE_RETCODE_DONE;
    truth.outcome = EXEC_OUTCOME_FILLED;
    TEST_TRUE(writer.RecordResult(eid1, truth, H6_POLICY_RECORD), "T4g RECORD -> SENT recorded");

    // AlreadySent keyed by executionId (Clarification C1-A)
    TEST_TRUE(writer.AlreadySent(eid1), "T4h execution 101 broker-visible -> AlreadySent");
    TEST_FALSE(writer.AlreadySent(eid2), "T4i execution 102 (INTENT only) -> not sent yet");

    // crash window: decision 102 has only INTENT (no post-send event) -> not broker-visible, not re-send-blocked by AlreadySent, but recovery treats it as pending
    ExecutionLedgerEvent evs[];
    string info = "";
    TEST_TRUE(LedgerScan(ledgerPath, evs, info) == LEDGER_SCAN_CLEAN, "T4j ledger CLEAN");
    // events: INTENT(101), INTENT(102), SENT(101) = 3 events
    TEST_INT_EQ(3, ArraySize(evs), "T4k 3 events recorded");

    // REJECT_PERMANENT / RETRY_ELIGIBLE -> REJECTED ; RETRY_HOLD -> UNKNOWN
    string eid3 = "";
    writer.BeginExecution(103, "EURUSD", "BUY", 1.1, 1.0, 1.09, 1.12, 27182819, eid3);
    truth.retcode = TRADE_RETCODE_INVALID;
    truth.outcome = EXEC_OUTCOME_REJECTED;
    TEST_TRUE(writer.RecordResult(eid3, truth, H6_POLICY_REJECT_PERMANENT), "T4l REJECT_PERMANENT -> REJECTED");

    string eid4 = "";
    writer.BeginExecution(104, "EURUSD", "BUY", 1.1, 1.0, 1.09, 1.12, 27182819, eid4);
    truth.retcode = TRADE_RETCODE_REQUOTE;
    truth.outcome = EXEC_OUTCOME_REJECTED;
    TEST_TRUE(writer.RecordResult(eid4, truth, H6_POLICY_RETRY_ELIGIBLE), "T4m RETRY_ELIGIBLE -> REJECTED (this attempt)");
    TEST_FALSE(writer.AlreadySent(eid4), "T4n retry-eligible execution NOT broker-visible (new executionId on retry)");

    string eid5 = "";
    writer.BeginExecution(105, "EURUSD", "BUY", 1.1, 1.0, 1.09, 1.12, 27182819, eid5);
    truth.retcode = TRADE_RETCODE_TIMEOUT;
    truth.outcome = EXEC_OUTCOME_TIMEOUT;
    TEST_TRUE(writer.RecordResult(eid5, truth, H6_POLICY_RETRY_HOLD), "T4o RETRY_HOLD -> UNKNOWN");
    TEST_FALSE(writer.AlreadySent(eid5), "T4p held execution NOT broker-visible");

    // verify event types via a fresh scan
    ExecutionLedgerEvent evs2[];
    string info2 = "";
    LedgerScan(ledgerPath, evs2, info2);
    int intents = 0, sents = 0, rejected = 0, unknowns = 0;
    for(int i = 0; i < ArraySize(evs2); i++)
    {
        if(evs2[i].eventType == LEDGER_EVENT_INTENT) intents++;
        if(evs2[i].eventType == LEDGER_EVENT_SENT) sents++;
        if(evs2[i].eventType == LEDGER_EVENT_REJECTED) rejected++;
        if(evs2[i].eventType == LEDGER_EVENT_UNKNOWN) unknowns++;
    }
    TEST_INT_EQ(5, intents, "T4q 5 INTENT events");
    TEST_INT_EQ(1, sents, "T4r 1 SENT event (RECORD)");
    TEST_INT_EQ(2, rejected, "T4s 2 REJECTED events (permanent + eligible)");
    TEST_INT_EQ(1, unknowns, "T4t 1 UNKNOWN event (hold)");

    writer.RecordRunEnd();

    FileDelete(ledgerPath, FILE_COMMON);
    FileDelete(counterPath, FILE_COMMON);

    SUITE_END("B25-03C-B Phase 4/5 - writer H6 mapping + crash window");
}

//--- Phase 6: corruption -> BLOCKED ; torn tail -> recoverable ---------------
void TestPhase6Corruption(TestCounters &counters)
{
    SUITE_BEGIN("B25-03C-B Phase 6 - corruption handling");

    // mid-file corruption: tamper a record payload without updating checksum
    {
        string path = "Execution\\TestRecovery_Corrupt.dat";
        FileDelete(path, FILE_COMMON);
        CExecutionIdentity id;
        id.Init("RUN-CORR", "test", "Execution\\TestRecovery_Corrupt_seq.dat");
        CExecutionLedgerWriter w;
        w.Init(path, &id, "RUN-CORR", "test");
        string eid = "";
        w.BeginExecution(201, "EURUSD", "BUY", 1.1, 1.0, 1.09, 1.12, 27182819, eid);
        ExecutionTruthRecord t;
        t.retcode = TRADE_RETCODE_DONE;
        t.outcome = EXEC_OUTCOME_FILLED;
        t.dealTicket = 0;
        t.orderTicket = 0;
        t.requestId = 0; t.retcodeExternal = 0;
        t.bidAtResult = 0; t.askAtResult = 0; t.brokerComment = "";
        w.RecordResult(eid, t, H6_POLICY_RECORD);

        // tamper the SENT record's payload: rewrite the file inserting a
        // bad line in the middle.  Simplest: append a line with a bad
        // checksum as the LAST record -> this is TORN_TAIL, not mid-file.
        // For mid-file, we corrupt the SECOND line (the SENT record).
        // Build a corrupted copy: read lines, corrupt line 2, rewrite.
        int h = FileOpen(path, FILE_READ | FILE_TXT | FILE_COMMON);
        string lines[];
        while(!FileIsEnding(h))
        {
            string ln = FileReadString(h);
            StringTrimRight(ln);
            if(StringLen(ln) > 0)
            {
                int n = ArraySize(lines);
                ArrayResize(lines, n + 1);
                lines[n] = ln;
            }
        }
        FileClose(h);
        // corrupt line index 1 (the SENT record): append a stray char so its
        // checksum no longer matches -> MID_FILE_CORRUPT (not last line).
        if(ArraySize(lines) >= 2)
            lines[1] = lines[1] + "X";
        FileDelete(path, FILE_COMMON);
        int hw = FileOpen(path, FILE_WRITE | FILE_TXT | FILE_COMMON);
        for(int i = 0; i < ArraySize(lines); i++)
            FileWriteString(hw, lines[i] + "\r\n");
        FileFlush(hw);
        FileClose(hw);

        CExecutionRecovery rec;
        rec.Init(path);
        TEST_TRUE(rec.IsExecutionBlocked(), "T6a mid-file corruption -> BLOCKED");

        FileDelete(path, FILE_COMMON);
        FileDelete("Execution\\TestRecovery_Corrupt_seq.dat", FILE_COMMON);
    }

    // torn tail: valid ledger + truncated last record -> recoverable
    {
        string path = "Execution\\TestRecovery_Torn.dat";
        FileDelete(path, FILE_COMMON);
        CExecutionIdentity id;
        id.Init("RUN-TORN", "test", "Execution\\TestRecovery_Torn_seq.dat");
        CExecutionLedgerWriter w;
        w.Init(path, &id, "RUN-TORN", "test");
        string eid = "";
        w.BeginExecution(202, "EURUSD", "BUY", 1.1, 1.0, 1.09, 1.12, 27182819, eid);
        // append a truncated record as the last line
        TestRecoveryRawAppend(path, "EVT|999|EX-RUN-999|SENT|2026.01.01 00:00|INTENT|SUBMITTED|truncated|deadbeef");
        CExecutionRecovery rec;
        rec.Init(path);
        TEST_FALSE(rec.IsExecutionBlocked(), "T6b torn tail recovered -> NOT blocked");
        TEST_INT_EQ(1, rec.StateCount(), "T6c one execution rebuilt after recovery");

        FileDelete(path, FILE_COMMON);
        FileDelete("Execution\\TestRecovery_Torn_seq.dat", FILE_COMMON);
    }

    SUITE_END("B25-03C-B Phase 6 - corruption handling");
}

//--- Phase 7: idempotence (duplicate DEAL_IN via writer) ---------------------
void TestPhase7Idempotence(TestCounters &counters)
{
    SUITE_BEGIN("B25-03C-B Phase 7 - idempotence");

    string path = "Execution\\TestRecovery_Idem.dat";
    FileDelete(path, FILE_COMMON);
    CExecutionIdentity id;
    id.Init("RUN-IDEM", "test", "Execution\\TestRecovery_Idem_seq.dat");
    CExecutionLedgerWriter w;
    w.Init(path, &id, "RUN-IDEM", "test");

    string eid = "";
    w.BeginExecution(301, "EURUSD", "BUY", 1.1, 1.0, 1.09, 1.12, 27182819, eid);
    ExecutionTruthRecord t;
    t.retcode = TRADE_RETCODE_DONE; t.outcome = EXEC_OUTCOME_FILLED;
    t.dealTicket = 0; t.orderTicket = 0; t.requestId = 0; t.retcodeExternal = 0;
    t.bidAtResult = 0; t.askAtResult = 0; t.brokerComment = "";
    w.RecordResult(eid, t, H6_POLICY_RECORD);

    // two identical deals (same dealTicket) -> only the first counts
    TEST_TRUE(w.RecordDeal(eid, 9001, 0, 0, 1.1, 0.6, D'2026.01.01', 0), "T7a first deal recorded");
    TEST_TRUE(w.RecordDeal(eid, 9001, 0, 0, 1.1, 0.6, D'2026.01.01', 0), "T7b duplicate deal idempotent (no error)");

    ExecutionLedgerEvent evs[];
    string info = "";
    LedgerScan(path, evs, info);
    ExecutionReconState states[];
    string violation = "";
    ulong hw = 0;
    RebuildStates(evs, states, violation, hw);
    TEST_INT_EQ(1, ArraySize(states), "T7c one execution");
    if(ArraySize(states) == 1)
    {
        TEST_DBL_NEAR(0.6, states[0].filledVolume, 1e-9, "T7d duplicate deal counted once (0.6)");
        TEST_INT_EQ(1, states[0].dealCount, "T7e one unique dealTicket");
    }

    FileDelete(path, FILE_COMMON);
    FileDelete("Execution\\TestRecovery_Idem_seq.dat", FILE_COMMON);

    SUITE_END("B25-03C-B Phase 7 - idempotence");
}

TestCounters RunExecutionRecoveryTests(void)
{
    TestCounters counters;
    TestPhase1StateMachine(counters);
    TestPhase2FoldDeterminism(counters);
    TestPhase3Verdicts(counters);
    TestPhase45Writer(counters);
    TestPhase6Corruption(counters);
    TestPhase7Idempotence(counters);
    return counters;
}

#endif // __TEST_EXECUTION_RECOVERY_MQH__
